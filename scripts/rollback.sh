#!/bin/sh

set -eu

TV="${TV:-lg-tv}"

ASSETS=/usr/palm/applications/com.webos.app.home/data/flutter_assets/assets

echo "Removing Custom Home overlay..."

ssh "$TV" "
    umount '$ASSETS' 2>/dev/null || true
    pkill -f com.webos.app.home || true
"

echo
echo "Overlay removed."
echo "LG's original Home assets are active."
