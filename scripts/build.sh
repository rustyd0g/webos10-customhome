#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_DIR=$(dirname "$SCRIPT_DIR")
PARENT_DIR=$(dirname "$REPO_DIR")

STOCK_DIR="${STOCK_DIR:-$PARENT_DIR/webos10-customhome-stock}"

OVERRIDES="$REPO_DIR/overrides"
BUILD_DIR="$REPO_DIR/.build/tld.my.customhome"

[ -f "$REPO_DIR/src/customhome.sh" ] || {
    echo "ERROR: Missing src/customhome.sh"
    exit 1
}

[ -f "$OVERRIDES/home.xml" ] || {
    echo "ERROR: Missing overrides/home.xml"
    exit 1
}

[ -f "$OVERRIDES/home_layoutShelfView.xml" ] || {
    echo "ERROR: Missing overrides/home_layoutShelfView.xml"
    exit 1
}

[ -d "$STOCK_DIR/i18n" ] || {
    echo "ERROR: Missing stock i18n directory:"
    echo "  $STOCK_DIR/i18n"
    echo
    echo "Run scripts/pull-stock.sh first."
    exit 1
}

# Start with a completely clean build.

rm -rf "$BUILD_DIR"

mkdir -p "$BUILD_DIR/assets/i18n"

# TV-side OverlayFS script.

cp "$REPO_DIR/src/customhome.sh" \
   "$BUILD_DIR/customhome.sh"

chmod +x "$BUILD_DIR/customhome.sh"

# Custom XML files.

cp "$OVERRIDES/home.xml" \
   "$BUILD_DIR/assets/home.xml"

cp "$OVERRIDES/home_layoutShelfView.xml" \
   "$BUILD_DIR/assets/home_layoutShelfView.xml"

# Complete stock locale set.

cp -R "$STOCK_DIR/i18n/." \
      "$BUILD_DIR/assets/i18n/"

# Replace stock locales with customised versions.

if [ -d "$OVERRIDES/i18n" ]; then
    for FILE in "$OVERRIDES"/i18n/*; do
        [ -f "$FILE" ] || continue

        cp "$FILE" \
           "$BUILD_DIR/assets/i18n/"
    done
fi

# Optional banner overrides.

for RESOLUTION in hd 2k 4k; do
    IMAGE="$OVERRIDES/images/$RESOLUTION/bg_banner_img.png"

    if [ -f "$IMAGE" ]; then
        mkdir -p "$BUILD_DIR/assets/images/$RESOLUTION"

        cp "$IMAGE" \
           "$BUILD_DIR/assets/images/$RESOLUTION/bg_banner_img.png"
    fi
done

echo
echo "Build complete:"
echo "  $BUILD_DIR"
