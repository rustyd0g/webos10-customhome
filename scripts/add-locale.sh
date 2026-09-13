#!/bin/sh

set -eu

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <locale-file>"
    echo "Example: $0 en_GB.json"
    exit 1
fi

LOCALE="$1"

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_DIR=$(dirname "$SCRIPT_DIR")
PARENT_DIR=$(dirname "$REPO_DIR")

STOCK_DIR="${STOCK_DIR:-$PARENT_DIR/webos10-customhome-stock}"

SOURCE="$STOCK_DIR/i18n/$LOCALE"
DEST_DIR="$REPO_DIR/overrides/i18n"
DEST="$DEST_DIR/$LOCALE"

[ -f "$SOURCE" ] || {
    echo "ERROR: Stock locale not found:"
    echo "  $SOURCE"
    exit 1
}

if [ -e "$DEST" ]; then
    echo "ERROR: Locale override already exists:"
    echo "  $DEST"
    echo
    echo "Refusing to overwrite it."
    exit 1
fi

mkdir -p "$DEST_DIR"

cp "$SOURCE" "$DEST"

echo "Created:"
echo "  $DEST"
