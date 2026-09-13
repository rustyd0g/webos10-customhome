#!/bin/sh

# Removes the active Custom Home overlay and restores LG's original Home assets.
# Usage: scripts/rollback.sh (no arguments; set TV to override the SSH host).

set -eu

TV="${TV:-lg-tv}"

ASSETS=/usr/palm/applications/com.webos.app.home/data/flutter_assets/assets

echo "Removing Custom Home overlay..."

ssh "$TV" "
    set -e

    read_mount_state() {
        # A failed inspection must never be treated as an absent overlay.
        MOUNT_STATE=\$(awk -v target='$ASSETS' '
            \$2 == target {
                mounted = 1
                if (\$3 != \"overlay\") foreign = 1
            }
            END {
                if (foreign) print \"foreign\"
                else if (mounted) print \"overlay\"
                else print \"none\"
            }
        ' /proc/mounts) || {
            echo 'ERROR: Could not inspect Home assets mounts' >&2
            exit 1
        }

        case \"\$MOUNT_STATE\" in
            none|overlay) ;;
            foreign)
                echo 'ERROR: Home assets path is occupied by a non-OverlayFS mount' >&2
                exit 1
                ;;
            *)
                echo 'ERROR: Unexpected Home assets mount state' >&2
                exit 1
                ;;
        esac
    }

    ATTEMPTS=0

    while :; do
        read_mount_state
        [ \"\$MOUNT_STATE\" = none ] && break

        if umount '$ASSETS'; then
            continue
        fi

        pkill -f '[c]om[.]webos[.]app[.]home' || true

        ATTEMPTS=\$((ATTEMPTS + 1))

        if [ \"\$ATTEMPTS\" -ge 5 ]; then
            echo 'ERROR: Could not remove the Home overlay'
            exit 1
        fi

        sleep 1
    done

    # Restart Home only after the original assets are visible again.
    pkill -f '[c]om[.]webos[.]app[.]home' || true
"

echo
echo "Overlay removed."
echo "LG's original Home assets are active."
