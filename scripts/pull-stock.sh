#!/bin/sh

set -eu

TV="${TV:-lg-tv}"

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_DIR=$(dirname "$SCRIPT_DIR")
PARENT_DIR=$(dirname "$REPO_DIR")

STOCK_DIR="${STOCK_DIR:-$PARENT_DIR/webos10-customhome-stock}"

REMOTE_ASSETS=/usr/palm/applications/com.webos.app.home/data/flutter_assets/assets
REMOTE_I18N=/mnt/lg/wee/ui_l10n/usr/palm/applications/com.webos.app.home/data/flutter_assets/assets/i18n

# Refuse to overwrite an existing stock snapshot.

if [ -e "$STOCK_DIR/home.xml" ] ||
   [ -e "$STOCK_DIR/home_layoutShelfView.xml" ] ||
   [ -d "$STOCK_DIR/i18n" ]; then

    echo "ERROR: Stock snapshot already exists:"
    echo "  $STOCK_DIR"
    echo
    echo "Refusing to overwrite it."
    exit 1
fi

mkdir -p "$STOCK_DIR"

echo "Pulling home.xml..."

scp \
    "$TV:$REMOTE_ASSETS/home.xml" \
    "$STOCK_DIR/home.xml"

echo "Pulling home_layoutShelfView.xml..."

scp \
    "$TV:$REMOTE_ASSETS/home_layoutShelfView.xml" \
    "$STOCK_DIR/home_layoutShelfView.xml"

echo "Pulling complete stock i18n directory..."

scp -r \
    "$TV:$REMOTE_I18N" \
    "$STOCK_DIR/"

# Create editable XML copies only if they do not already exist.

mkdir -p "$REPO_DIR/overrides/i18n"

if [ ! -e "$REPO_DIR/overrides/home.xml" ]; then
    cp "$STOCK_DIR/home.xml" \
       "$REPO_DIR/overrides/home.xml"

    echo "Created overrides/home.xml"
else
    echo "Leaving existing overrides/home.xml unchanged"
fi

if [ ! -e "$REPO_DIR/overrides/home_layoutShelfView.xml" ]; then
    cp "$STOCK_DIR/home_layoutShelfView.xml" \
       "$REPO_DIR/overrides/home_layoutShelfView.xml"

    echo "Created overrides/home_layoutShelfView.xml"
else
    echo "Leaving existing overrides/home_layoutShelfView.xml unchanged"
fi

echo
echo "Stock snapshot:"
echo "  $STOCK_DIR"
echo
echo "Editable overrides:"
echo "  $REPO_DIR/overrides"
