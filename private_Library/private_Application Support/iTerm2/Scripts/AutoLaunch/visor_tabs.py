#!/usr/bin/env python3
"""
Visor tabs: keep the hotkey window ("visor") pinned to two herdr sessions.

  Tab 1  "Visor: eldar" profile     ~/.local/bin/ssh-loop eldar     (herdr on Eldar's VM)
  Tab 2  "Visor: eldar-os" profile  ~/.local/bin/ssh-loop eldar-os  (herdr on eldar-os)

ssh-loop reconnects on its own when the network drops. Both profiles live in
DynamicProfiles/visor.json and inherit their look from "Hotkey Window".

The Hotkey Window profile itself stays a plain local shell, because iTerm
uses it for every new tab (⌘T) in the visor. When the visor is first created,
this script opens the two visor tabs and closes the initial local shell.
Afterwards it re-adds either visor tab if it gets closed.

iTerm has no API to identify the hotkey window, so a window counts as the
visor when one of its sessions uses the Hotkey Window or a visor profile.
"""

import asyncio

import iterm2

HOTKEY_PROFILE = "Hotkey Window"
VISOR_TABS = ["Visor: eldar", "Visor: eldar-os"]  # in tab order

lock = asyncio.Lock()


async def reset_hotkey_profile(connection):
    """Undo an earlier version of this script that made the Hotkey Window
    profile run ssh-loop (which leaked into every new visor tab)."""
    profiles = await iterm2.PartialProfile.async_query(
        connection, properties=["Guid", "Name", "Command", "Custom Command"]
    )
    for profile in profiles:
        if profile.name == HOTKEY_PROFILE and "ssh-loop" in (profile.command or ""):
            await profile.async_set_use_custom_command("No")
            await profile.async_set_command("")


async def session_profiles(window):
    """[(session, profile name)] for every session in the window."""
    result = []
    for tab in window.tabs:
        for session in tab.sessions:
            try:
                result.append((session, (await session.async_get_profile()).name))
            except Exception:
                pass  # session went away mid-scan
    return result


async def ensure_tabs(connection):
    async with lock:
        app = await iterm2.async_get_app(connection)
        for window in app.windows:
            sessions = await session_profiles(window)
            names = {name for _, name in sessions}
            if not names & {HOTKEY_PROFILE, *VISOR_TABS}:
                continue

            # Freshly created visor: just the one local shell from the
            # Hotkey Window profile. Replace it with the visor tabs.
            bootstrap = len(sessions) == 1 and names == {HOTKEY_PROFILE}

            for index, profile in enumerate(VISOR_TABS):
                if profile not in names:
                    await window.async_create_tab(
                        profile=profile, index=index, select=index == 0
                    )

            if bootstrap:
                await sessions[0][0].async_close(force=True)


async def watch(monitor_factory, connection):
    async with monitor_factory(connection) as monitor:
        while True:
            await monitor.async_get()
            await ensure_tabs(connection)


async def main(connection):
    await reset_hotkey_profile(connection)
    await ensure_tabs(connection)
    await asyncio.gather(
        watch(iterm2.LayoutChangeMonitor, connection),
        watch(iterm2.NewSessionMonitor, connection),
        watch(iterm2.SessionTerminationMonitor, connection),
    )


iterm2.run_forever(main)
