#!/bin/bash

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

[ -f "$SCRIPT_DIR/install.log" ] && { echo >&2 "Dotfiles have already installed. Exiting!"; exit 1; }

echo "install.sh ran at $(date) from $SCRIPT_DIR" >> $SCRIPT_DIR/install.log

sudo $SCRIPT_DIR/system_install.sh
$SCRIPT_DIR/user_install.sh