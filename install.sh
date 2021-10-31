#!/bin/bash

exit 1

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

echo "install.sh ran at $(date) from $SCRIPT_DIR" >> ~/install.log

sudo $SCRIPT_DIR/system_install.sh
$SCRIPT_DIR/user_install.sh