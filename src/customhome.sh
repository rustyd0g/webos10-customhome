#!/bin/sh

# TV-side entry point that assembles, mounts and activates the custom Home overlay.
# Usage: customhome.sh (no arguments; installed and normally run via activate.sh).

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

# Remove every existing overlay from a previous activation before touching
# its upper and work directories. A failed unmount must not be ignored: those
# directories are unsafe to reuse while an OverlayFS mount still references
# them.

read_mount_state() {
    # Return the state as text so an inspection error cannot mean "not mounted".
    MOUNT_STATE=$(awk -v target="$ASSETS_DIR" '
        $2 == target {
            mounted = 1
            if ($3 != "overlay") foreign = 1
        }
        END {
            if (foreign) print "foreign"
            else if (mounted) print "overlay"
            else print "none"
        }
    ' /proc/mounts) || {
        echo "ERROR: Could not inspect Home assets mounts" >&2
        exit 1
    }

    case "$MOUNT_STATE" in
        none|overlay) ;;
        foreign)
            echo "ERROR: Home assets path is occupied by a non-OverlayFS mount" >&2
            exit 1
            ;;
        *)
            echo "ERROR: Unexpected Home assets mount state: $MOUNT_STATE" >&2
            exit 1
            ;;
    esac
}

ATTEMPTS=0

while :; do
    read_mount_state
    [ "$MOUNT_STATE" = none ] && break

    if umount "$ASSETS_DIR"; then
        continue
    fi

    # Home may still have assets open. Stop it, then retry the unmount.
    pkill -f '[c]om[.]webos[.]app[.]home' || true

    ATTEMPTS=$((ATTEMPTS + 1))

    if [ "$ATTEMPTS" -ge 5 ]; then
        echo "ERROR: Could not remove the existing Home overlay"
        exit 1
    fi

    sleep 1
done

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

for RESOLUTION in hd 2k 4k; do
    IMAGE="$OVERRIDE_DIR/images/$RESOLUTION/bg_banner_img.png"

    if [ -f "$IMAGE" ]; then
        mkdir -p "$UPPER_DIR/images/$RESOLUTION"

        cp "$IMAGE" \
           "$UPPER_DIR/images/$RESOLUTION/bg_banner_img.png"
    fi
done

# Mount the merged Home assets view.

mount -t overlay overlay \
    -o lowerdir="$ASSETS_DIR",upperdir="$UPPER_DIR",workdir="$WORK_DIR" \
    "$ASSETS_DIR"

# Restart Home so it reloads the assets.

pkill -f '[c]om[.]webos[.]app[.]home' || true
