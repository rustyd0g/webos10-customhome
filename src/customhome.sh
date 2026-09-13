#!/bin/sh

set -e -x

ASSETS_DIR=/usr/palm/applications/com.webos.app.home/data/flutter_assets/assets
OVERRIDE_DIR=/media/developer/apps/usr/palm/applications/tld.my.customhome/assets

UPPER_DIR=/tmp/weboshome-overlay-upper
WORK_DIR=/tmp/weboshome-overlay-work

# Required paths and files.

[ -d "$ASSETS_DIR" ] || {
    echo "ERROR: Home assets directory not found: $ASSETS_DIR"
    exit 1
}

[ -d "$OVERRIDE_DIR" ] || {
    echo "ERROR: Override directory not found: $OVERRIDE_DIR"
    exit 1
}

[ -f "$OVERRIDE_DIR/home.xml" ] || {
    echo "ERROR: Missing home.xml"
    exit 1
}

[ -f "$OVERRIDE_DIR/home_layoutShelfView.xml" ] || {
    echo "ERROR: Missing home_layoutShelfView.xml"
    exit 1
}

[ -d "$OVERRIDE_DIR/i18n" ] || {
    echo "ERROR: Missing i18n directory"
    exit 1
}

# Remove an existing overlay from a previous activation.

umount "$ASSETS_DIR" 2>/dev/null || true

# Recreate temporary OverlayFS directories.

rm -rf "$UPPER_DIR" "$WORK_DIR"

mkdir -p \
    "$UPPER_DIR/i18n" \
    "$WORK_DIR"

# XML overrides.

cp "$OVERRIDE_DIR/home.xml" \
   "$UPPER_DIR/home.xml"

cp "$OVERRIDE_DIR/home_layoutShelfView.xml" \
   "$UPPER_DIR/home_layoutShelfView.xml"

# Complete i18n tree.
#
# The original i18n entry is a symlink. A real i18n directory in the
# upper layer shadows it completely, so the deployed directory must
# contain the full locale set.

cp -a "$OVERRIDE_DIR/i18n/." \
      "$UPPER_DIR/i18n/"

# Optional banner overrides.
#
# If an override does not exist, OverlayFS falls through to LG's
# original image.

if [ -f "$OVERRIDE_DIR/images/hd/bg_banner_img.png" ]; then
    mkdir -p "$UPPER_DIR/images/hd"

    cp "$OVERRIDE_DIR/images/hd/bg_banner_img.png" \
       "$UPPER_DIR/images/hd/bg_banner_img.png"
fi

if [ -f "$OVERRIDE_DIR/images/2k/bg_banner_img.png" ]; then
    mkdir -p "$UPPER_DIR/images/2k"

    cp "$OVERRIDE_DIR/images/2k/bg_banner_img.png" \
       "$UPPER_DIR/images/2k/bg_banner_img.png"
fi

if [ -f "$OVERRIDE_DIR/images/4k/bg_banner_img.png" ]; then
    mkdir -p "$UPPER_DIR/images/4k"

    cp "$OVERRIDE_DIR/images/4k/bg_banner_img.png" \
       "$UPPER_DIR/images/4k/bg_banner_img.png"
fi

# Mount the merged Home assets view.

mount -t overlay overlay \
    -o lowerdir="$ASSETS_DIR",upperdir="$UPPER_DIR",workdir="$WORK_DIR" \
    "$ASSETS_DIR"

# Restart Home so it reloads the assets.

pkill -f com.webos.app.home || true
