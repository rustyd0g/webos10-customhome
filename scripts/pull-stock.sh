#!/bin/sh

# Downloads a complete stock Home asset snapshot without replacing existing files.
# Usage: scripts/pull-stock.sh (no arguments; set TV or STOCK_DIR if needed).

set -eu

TV="${TV:-lg-tv}"

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_DIR=$(dirname "$SCRIPT_DIR")
PARENT_DIR=$(dirname "$REPO_DIR")

STOCK_DIR="${STOCK_DIR:-$PARENT_DIR/webos10-customhome-stock}"

REMOTE_ASSETS=/usr/palm/applications/com.webos.app.home/data/flutter_assets/assets
REMOTE_I18N=/mnt/lg/wee/ui_l10n/usr/palm/applications/com.webos.app.home/data/flutter_assets/assets/i18n

# A complete older snapshot may be extended with files that it does not yet
# contain. Existing files are never replaced.

MODE=create

if [ -e "$STOCK_DIR" ] || [ -L "$STOCK_DIR" ]; then
    if [ -d "$STOCK_DIR" ] &&
       [ -f "$STOCK_DIR/home.xml" ] &&
       [ -f "$STOCK_DIR/home_layoutShelfView.xml" ] &&
       [ -d "$STOCK_DIR/i18n" ]; then

        MODE=extend
    else
        echo "ERROR: Incomplete or invalid stock snapshot:"
        echo "  $STOCK_DIR"
        echo
        echo "Refusing to overwrite it."
        exit 1
    fi
fi

# Reading the assets path while Custom Home is active would capture the merged
# OverlayFS view instead of LG's original files.

MOUNT_STATE=$(ssh "$TV" "
    awk -v target='$REMOTE_ASSETS' '
        \$2 == target {
            mounted = 1
            if (\$3 != \"overlay\") foreign = 1
        }
        END {
            if (foreign) print \"foreign\"
            else if (mounted) print \"overlay\"
            else print \"none\"
        }
    ' /proc/mounts
") || {
    echo "ERROR: Could not inspect Home assets mounts on $TV" >&2
    exit 1
}

case "$MOUNT_STATE" in
    none) ;;
    overlay)
        echo "ERROR: Custom Home is active on $TV."
        echo "Run scripts/rollback.sh before pulling a stock snapshot."
        exit 1
        ;;
    *)
        echo "ERROR: Home assets mount state is not confirmed clear: $MOUNT_STATE" >&2
        exit 1
        ;;
esac

# Download into a sibling staging directory. A failed transfer is cleaned up,
# so it cannot leave a partial snapshot that blocks the next attempt.

mkdir -p "$(dirname "$STOCK_DIR")"

STAGE_DIR=$(mktemp -d "$STOCK_DIR.tmp.XXXXXX")

cleanup() {
    rm -rf "$STAGE_DIR"
}

trap cleanup 0 1 2 15

echo "Pulling complete stock asset tree..."

scp -r \
    "$TV:$REMOTE_ASSETS" \
    "$STAGE_DIR/"

ASSET_STAGE="$STAGE_DIR/assets"

[ -d "$ASSET_STAGE" ] || {
    echo "ERROR: Stock asset tree was not downloaded"
    exit 1
}

# The asset tree contains an absolute i18n symlink. Replace the local copy with
# a real directory so locale files can be inspected and copied for editing.

rm -rf "$ASSET_STAGE/i18n"

echo "Pulling resolved stock i18n directory..."

scp -r \
    "$TV:$REMOTE_I18N" \
    "$ASSET_STAGE/"

[ -f "$ASSET_STAGE/home.xml" ] || {
    echo "ERROR: Stock home.xml was not downloaded"
    exit 1
}

[ -f "$ASSET_STAGE/home_layoutShelfView.xml" ] || {
    echo "ERROR: Stock home_layoutShelfView.xml was not downloaded"
    exit 1
}

[ -d "$ASSET_STAGE/i18n" ] && [ ! -L "$ASSET_STAGE/i18n" ] || {
    echo "ERROR: Resolved stock i18n directory was not downloaded"
    exit 1
}

for RESOLUTION in hd 2k 4k; do
    [ -f "$ASSET_STAGE/images/$RESOLUTION/bg_banner_img.png" ] || {
        echo "ERROR: Stock $RESOLUTION banner image was not downloaded"
        exit 1
    }
done

# Recursively add missing files to an older snapshot without replacing any
# existing file, directory, or symlink.

merge_missing_tree() (
    SOURCE_DIR=$1
    DEST_DIR=$2

    mkdir -p "$DEST_DIR"

    for ITEM in \
        "$SOURCE_DIR"/* \
        "$SOURCE_DIR"/.[!.]* \
        "$SOURCE_DIR"/..?*; do

        [ -e "$ITEM" ] || [ -L "$ITEM" ] || continue

        NAME=${ITEM##*/}
        TARGET="$DEST_DIR/$NAME"

        if [ -d "$ITEM" ] && [ ! -L "$ITEM" ]; then
            if [ -e "$TARGET" ] || [ -L "$TARGET" ]; then
                if [ -d "$TARGET" ] && [ ! -L "$TARGET" ]; then
                    merge_missing_tree "$ITEM" "$TARGET"
                fi
            else
                mv "$ITEM" "$TARGET"
            fi
        elif [ ! -e "$TARGET" ] && [ ! -L "$TARGET" ]; then
            mv "$ITEM" "$TARGET"
        fi
    done
)

if [ "$MODE" = extend ]; then
    merge_missing_tree "$ASSET_STAGE" "$STOCK_DIR"
    cleanup
else
    mv "$ASSET_STAGE" "$STOCK_DIR"
    cleanup
fi

trap - 0 1 2 15

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
echo "Stock asset snapshot:"
echo "  $STOCK_DIR"
echo
echo "Banner starting points:"
echo "  $STOCK_DIR/images"
echo
echo "Editable overrides:"
echo "  $REPO_DIR/overrides"
