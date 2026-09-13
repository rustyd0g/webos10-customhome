#!/bin/sh

set -eu

TV="${TV:-lg-tv}"

REMOTE_SCRIPT=/media/developer/apps/usr/palm/applications/tld.my.customhome/customhome.sh

echo "Activating Custom Home..."

ssh "$TV" "$REMOTE_SCRIPT"
