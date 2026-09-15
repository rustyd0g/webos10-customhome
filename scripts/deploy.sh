#!/bin/sh

# Builds and uploads Custom Home to the TV while retaining the previous deployment.
# Usage: scripts/deploy.sh (no arguments; set TV to override the SSH host).

set -eu

TV="${TV:-lg-tv}"

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_DIR=$(dirname "$SCRIPT_DIR")

BUILD_DIR="$REPO_DIR/.build/tld.my.customhome"

TARGET=/media/developer/apps/usr/palm/applications/tld.my.customhome
STAGE=/media/developer/apps/usr/palm/applications/tld.my.customhome.new
PREVIOUS=/media/developer/apps/usr/palm/applications/tld.my.customhome.previous

# Always build immediately before deployment.

"$SCRIPT_DIR/build.sh"

echo
echo "Creating remote staging directory..."

ssh "$TV" "
    set -e

    rm -rf '$STAGE'
    mkdir -p '$STAGE'
"

echo "Uploading deployment..."

scp -r \
    "$BUILD_DIR/." \
    "$TV:$STAGE/"

echo "Installing uploaded files..."

ssh "$TV" "
    set -e

    chmod 755 '$STAGE/customhome.sh'

    rm -rf '$PREVIOUS'

    if [ -d '$TARGET' ]; then
        mv '$TARGET' '$PREVIOUS'
    fi

    mv '$STAGE' '$TARGET'
"

echo
echo "Deployment complete."
echo
echo "Current deployment:"
echo "  $TARGET"
echo
echo "Previous deployment:"
echo "  $PREVIOUS"
echo
echo "Run scripts/activate.sh to activate the new deployment."
