#!/usr/bin/env python3
"""
Claude Code: Image Paste (bracketed) — iTerm2 edition.

Paste a clipboard image into Claude Code running over SSH in iTerm2 and have
Claude render it inline as [Image N]. Port of the VS Code extension
`claude-image-paste-bracketed`; same three conditions have to hold:

  1. The path arrives framed as a bracketed paste (ESC[200~ … ESC[201~).
     Claude's image-path detector lives inside its paste handler.
  2. The whole (trimmed) payload is a path matching /\.(png|jpe?g|gif|webp)$/i.
  3. The path resolves to a readable file on the machine Claude runs on.

How each is satisfied here:

  - (3) We find the `ssh` process in the foreground of the focused session's
    tty, re-use its exact argv (host alias, -p, -i, -J … all carry over) and
    stream the PNG to the remote with `cat >`. Use ControlMaster in
    ~/.ssh/config and this rides the existing connection with no new auth.
    If the session isn't running ssh, the image is written locally instead.
  - (1)+(2) `session.async_send_text()` writes ESC[200~<path>ESC[201~ into
    the session as input, which ssh forwards verbatim to the remote pty.

Registered RPCs (bind with Settings → Keys → Key Bindings → "Invoke Script Function"):

  claude_smart_paste(session_id: id)   Cmd+V  — text pastes normally, images go to Claude
  claude_image_paste(session_id: id)   Cmd+⌥V — always treat the clipboard as an image
"""

import asyncio
import ctypes
import datetime
import os
import re
import secrets
import shlex
import subprocess
import sys
import tempfile

# --- Settings ---------------------------------------------------------------

# Where pasted images are written. On the remote this is relative to $HOME;
# locally it's relative to ~.
IMAGE_DIRECTORY = ".claude-images"

# "bracketedPaste" (recommended) or "plain" (types the bare path — Claude
# usually will NOT render it inline; for A/B debugging only).
INSERTION_MODE = "bracketedPaste"

# Best-effort delete of previously pasted images older than this many days
# (0 = never delete).
CLEANUP_AFTER_DAYS = 7

# Seconds to wait for the ssh upload before giving up.
UPLOAD_TIMEOUT_S = 20

# ---------------------------------------------------------------------------

ESC = "\x1b"
PASTE_START = f"{ESC}[200~"
PASTE_END = f"{ESC}[201~"
FILENAME_PREFIX = "clipboard-"
NOTIFY_TITLE = "Claude Image Paste"

# ssh options that consume the following argument (from ssh(1) SYNOPSIS).
SSH_OPTS_WITH_ARG = set("BbcDEeFIiJLlmOoPpQRSWw")


class PasteError(Exception):
    pass


# --- Clipboard --------------------------------------------------------------


def clipboard_has_text():
    """In-process-cheap text check (pbpaste is ~10ms). Mirrors the extension's
    fast path: text is the overwhelmingly common case, so never spawn the
    slower AppleScript image reader when there's text."""
    try:
        out = subprocess.run(
            ["pbpaste", "-Prefer", "txt"], capture_output=True, timeout=5
        ).stdout
    except Exception:
        return False
    return len(out) > 0


def read_clipboard_image():
    """Read the clipboard as PNG via AppleScript (`«class PNGf»`), falling back
    to TIFF + `sips` conversion. No pngpaste or other dependencies.
    Returns PNG bytes, or None if the clipboard holds no image."""
    tmp_dir = tempfile.mkdtemp(prefix="claude-img-")
    tmp_file = os.path.join(tmp_dir, "clipboard.png")
    script = "\n".join(
        [
            f"set outFile to (POSIX file {applescript_string(tmp_file)})",
            "try",
            "  set imgData to (the clipboard as «class PNGf»)",
            "  set fh to open for access outFile with write permission",
            "  set eof fh to 0",
            "  write imgData to fh",
            "  close access fh",
            '  return "png"',
            "on error",
            "  try",
            "    close access outFile",
            "  end try",
            "  try",
            "    set imgData to (the clipboard as «class TIFF»)",
            "    set fh to open for access outFile with write permission",
            "    set eof fh to 0",
            "    write imgData to fh",
            "    close access fh",
            '    do shell script "sips -s format png " & quoted form of (POSIX path of outFile) & " --out " & quoted form of (POSIX path of outFile)',
            '    return "png"',
            "  on error",
            '    return "none"',
            "  end try",
            "end try",
        ]
    )
    try:
        result = subprocess.run(
            ["osascript", "-e", script], capture_output=True, text=True, timeout=10
        ).stdout.strip()
        if result != "png" or not os.path.exists(tmp_file):
            return None
        with open(tmp_file, "rb") as fh:
            data = fh.read()
        return data or None
    finally:
        subprocess.run(["rm", "-rf", tmp_dir])


def applescript_string(value):
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


# --- Finding the ssh connection ---------------------------------------------


def proc_argv(pid):
    """Exact argv of a process via sysctl(KERN_PROCARGS2) — unlike `ps args`,
    this preserves arguments that contain spaces (e.g. -o 'ProxyCommand …')."""
    CTL_KERN, KERN_PROCARGS2 = 1, 49
    libc = ctypes.CDLL(None, use_errno=True)
    mib = (ctypes.c_int * 3)(CTL_KERN, KERN_PROCARGS2, pid)
    size = ctypes.c_size_t(0)
    if libc.sysctl(mib, 3, None, ctypes.byref(size), None, 0) != 0:
        return None
    buf = ctypes.create_string_buffer(size.value)
    if libc.sysctl(mib, 3, buf, ctypes.byref(size), None, 0) != 0:
        return None
    raw = buf.raw[: size.value]
    argc = int.from_bytes(raw[:4], sys.byteorder)
    rest = raw[4:]
    rest = rest[rest.index(b"\0") :].lstrip(b"\0")  # skip exec path + padding
    return [a.decode("utf-8", "replace") for a in rest.split(b"\0")[:argc]]


def find_foreground_ssh(tty):
    """Return the argv of the ssh client in the foreground of `tty`, or None.

    Picks the outermost ssh, so a ProxyCommand/ProxyJump child ssh on the same
    tty is ignored."""
    tty_name = os.path.basename(tty or "")
    if not tty_name:
        return None
    out = subprocess.run(
        ["ps", "-t", tty_name, "-o", "pid=,ppid=,stat=,comm="],
        capture_output=True,
        text=True,
    ).stdout
    procs = {}
    for line in out.splitlines():
        parts = line.split(None, 3)
        if len(parts) == 4:
            pid, ppid, stat, comm = parts
            procs[int(pid)] = (int(ppid), stat, os.path.basename(comm))
    ssh_pids = [
        pid
        for pid, (ppid, stat, comm) in procs.items()
        if comm == "ssh" and "+" in stat
    ]
    outer = [p for p in ssh_pids if procs[p][0] not in ssh_pids]
    if not outer:
        return None
    pid = min(outer)
    argv = proc_argv(pid)
    if not argv:
        argv = subprocess.run(
            ["ps", "-p", str(pid), "-o", "args="], capture_output=True, text=True
        ).stdout.split()
    return argv or None


def split_ssh_argv(argv):
    """Split an ssh argv into (options, destination), dropping any remote
    command. Returns (opts, None) if no destination was found."""
    args = argv[1:]
    i = 0
    while i < len(args):
        arg = args[i]
        if arg == "--":
            return args[:i], args[i + 1] if i + 1 < len(args) else None
        if arg.startswith("-") and len(arg) > 1:
            for j, ch in enumerate(arg[1:], start=1):
                if ch in SSH_OPTS_WITH_ARG:
                    if j == len(arg) - 1:
                        i += 1  # value is the next argument
                    break  # value is attached (e.g. -p2222) or consumed
            i += 1
            continue
        return args[:i], arg
    return args, None


# --- Writing the image ------------------------------------------------------


def image_filename():
    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    return f"{FILENAME_PREFIX}{stamp}-{secrets.token_hex(4)}.png"


def remote_write_script(name):
    """POSIX sh run on the remote: write stdin to the image dir, print the
    absolute path, then best-effort cleanup. One round trip."""
    cleanup = ""
    if CLEANUP_AFTER_DAYS > 0:
        cleanup = (
            f'find "$d" -maxdepth 1 -type f -name {shlex.quote(FILENAME_PREFIX + "*")} '
            f"-mtime +{int(CLEANUP_AFTER_DAYS)} -exec rm -f {{}} + 2>/dev/null; "
        )
    return (
        f'd="$HOME"/{shlex.quote(IMAGE_DIRECTORY)}; '
        'mkdir -p "$d" || exit 1; '
        "[ -e \"$d/.gitignore\" ] || printf '*\\n' > \"$d/.gitignore\"; "
        f'f="$d"/{shlex.quote(name)}; '
        'cat > "$f" || exit 1; '
        "printf '%s\\n' \"$f\"; "
        f"{cleanup}"
        "exit 0"
    )


async def upload_over_ssh(ssh_argv, png):
    opts, dest = split_ssh_argv(ssh_argv)
    if not dest:
        raise PasteError(f"couldn't find the host in: {' '.join(ssh_argv)}")
    cmd = [
        ssh_argv[0],
        *opts,
        # Overrides come last so they win over the session's own flags:
        "-T",  # no pty — we're streaming bytes over stdin
        # A host whose ~/.ssh/config entry sets RemoteCommand (e.g. to attach
        # a multiplexer) would refuse our command: "Cannot execute
        # command-line and remote command".
        "-o", "RemoteCommand=none",
        "-o", "BatchMode=yes",  # never prompt; fail fast instead
        "-o", "ClearAllForwardings=yes",  # don't re-bind the session's -L/-R/-D
        "-o", "ConnectTimeout=5",
        dest,
        "sh -c " + shlex.quote(remote_write_script(image_filename())),
    ]
    proc = await asyncio.create_subprocess_exec(
        *cmd,
        stdin=asyncio.subprocess.PIPE,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    try:
        out, err = await asyncio.wait_for(proc.communicate(png), UPLOAD_TIMEOUT_S)
    except asyncio.TimeoutError:
        proc.kill()
        raise PasteError(f"upload to {dest} timed out")
    path = out.decode("utf-8", "replace").strip().splitlines()
    if proc.returncode != 0 or not path:
        detail = err.decode("utf-8", "replace").strip().splitlines()
        hint = detail[-1] if detail else f"exit {proc.returncode}"
        if "Permission denied" in hint or "passphrase" in hint:
            hint += " — enable ControlMaster in ~/.ssh/config (see README)"
        raise PasteError(f"upload to {dest} failed: {hint}")
    return path[-1]


def write_locally(png):
    d = os.path.join(os.path.expanduser("~"), IMAGE_DIRECTORY)
    os.makedirs(d, exist_ok=True)
    gitignore = os.path.join(d, ".gitignore")
    if not os.path.exists(gitignore):
        with open(gitignore, "w") as fh:
            fh.write("*\n")
    path = os.path.join(d, image_filename())
    with open(path, "wb") as fh:
        fh.write(png)
    cleanup_local(d)
    return path


def cleanup_local(d):
    if CLEANUP_AFTER_DAYS <= 0:
        return
    cutoff = datetime.datetime.now().timestamp() - CLEANUP_AFTER_DAYS * 86400
    try:
        for name in os.listdir(d):
            p = os.path.join(d, name)
            if name.startswith(FILENAME_PREFIX) and os.path.getmtime(p) < cutoff:
                os.remove(p)
    except OSError:
        pass


# --- Inserting the path -----------------------------------------------------


def format_path(absolute_path):
    """A clean path matches Claude's `$`-anchored detector directly, so send it
    raw. Only single-quote paths with shell-special characters (cmux does the
    same, and Claude un-quotes before testing)."""
    if re.fullmatch(r"[A-Za-z0-9_@%+=:,./-]+", absolute_path):
        return absolute_path
    return "'" + absolute_path.replace("'", "'\\''") + "'"


def paste_payload(absolute_path):
    """No trailing newline: the path lands in the prompt buffer and the user
    keeps typing, exactly like a native paste."""
    payload = format_path(absolute_path)
    if INSERTION_MODE == "plain":
        return payload
    return f"{PASTE_START}{payload}{PASTE_END}"


# --- Feedback ---------------------------------------------------------------


def notify(message):
    script = (
        f"display notification {applescript_string(message)} "
        f"with title {applescript_string(NOTIFY_TITLE)}"
    )
    subprocess.Popen(
        ["osascript", "-e", script],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


# --- iTerm2 glue ------------------------------------------------------------


async def perform_image_paste(session, announce_no_image):
    """Returns "pasted", "no-image" or "error"."""
    png = await asyncio.to_thread(read_clipboard_image)
    if not png:
        if announce_no_image:
            notify("No image found on the clipboard.")
        return "no-image"
    try:
        tty = await session.async_get_variable("tty")
        ssh_argv = await asyncio.to_thread(find_foreground_ssh, tty)
        if ssh_argv:
            path = await upload_over_ssh(ssh_argv, png)
        else:
            path = await asyncio.to_thread(write_locally, png)
        await session.async_send_text(paste_payload(path), suppress_broadcast=True)
    except Exception as err:
        notify(str(err))
        return "error"
    return "pasted"


async def main(connection):
    import iterm2

    app = await iterm2.async_get_app(connection)

    async def native_paste():
        await iterm2.MainMenu.async_select_menu_item(connection, "Paste")

    @iterm2.RPC
    async def claude_image_paste(session_id=iterm2.Reference("id")):
        """Always treat the clipboard as an image."""
        session = app.get_session_by_id(session_id)
        if session:
            await perform_image_paste(session, announce_no_image=True)

    @iterm2.RPC
    async def claude_smart_paste(session_id=iterm2.Reference("id")):
        """Cmd+V replacement. A key binding can't see the clipboard, so branch
        here:
          text on clipboard  -> iTerm's own Paste (unchanged behaviour)
          no text, an image  -> bracketed-paste image flow
          neither / failure  -> iTerm's own Paste (never a dead key)"""
        session = app.get_session_by_id(session_id)
        if not session or await asyncio.to_thread(clipboard_has_text):
            await native_paste()
            return
        if await perform_image_paste(session, announce_no_image=False) != "pasted":
            await native_paste()

    await claude_image_paste.async_register(connection, timeout=60)
    await claude_smart_paste.async_register(connection, timeout=60)


if __name__ == "__main__":
    import iterm2

    iterm2.run_forever(main)
