#!/bin/sh

# Activates the deployed Custom Home OverlayFS setup on the TV.
# Usage: scripts/activate.sh (no arguments; set TV to override the SSH host).

set -eu

TV="${TV:-lg-tv}"

REMOTE_SCRIPT=/media/developer/apps/usr/palm/applications/tld.my.customhome/customhome.sh

echo "Activating Custom Home..."

ssh "$TV" "$REMOTE_SCRIPT"
