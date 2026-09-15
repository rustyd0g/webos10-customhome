#!/bin/sh

# Verifies that the deployed files are active through OverlayFS on the TV.
# Usage: scripts/verify.sh (no arguments; set TV to override the SSH host).

set -eu

TV="${TV:-lg-tv}"

TARGET=/media/developer/apps/usr/palm/applications/tld.my.customhome
ASSETS=/usr/palm/applications/com.webos.app.home/data/flutter_assets/assets

ssh "$TV" "
    set -e

    echo '=== Overlay mount ==='

    awk -v target='$ASSETS' '\$2 == target && \$3 == \"overlay\" { found = 1 } END { exit !found }' /proc/mounts || {
        echo 'ERROR: Home assets OverlayFS mount not found'
        exit 1
    }

    echo
    echo '=== home.xml ==='

    cmp \
        '$TARGET/assets/home.xml' \
        '$ASSETS/home.xml'

    echo 'OK'

    echo
    echo '=== home_layoutShelfView.xml ==='

    cmp \
        '$TARGET/assets/home_layoutShelfView.xml' \
        '$ASSETS/home_layoutShelfView.xml'

    echo 'OK'

    echo
    echo '=== i18n ==='

    test -d '$ASSETS/i18n'

    if [ -L '$ASSETS/i18n' ]; then
        echo 'ERROR: Active i18n path is still the stock symlink'
        exit 1
    fi

    for FILE in '$TARGET/assets/i18n/'*.json; do
        [ -f \"\$FILE\" ] || continue

        NAME=\${FILE##*/}

        cmp \"\$FILE\" '$ASSETS/i18n/'\"\$NAME\" || {
            echo \"ERROR: Active locale does not match deployment: \$NAME\"
            exit 1
        }
    done

    echo 'OK'

    echo
    echo '=== Banner overrides ==='

    for RESOLUTION in hd 2k 4k; do
        IMAGE=images/\$RESOLUTION/bg_banner_img.png
        [ -f '$TARGET/assets/'\"\$IMAGE\" ] || continue

        cmp '$TARGET/assets/'\"\$IMAGE\" '$ASSETS/'\"\$IMAGE\" || {
            echo \"ERROR: Active banner does not match deployment: \$RESOLUTION\"
            exit 1
        }
    done

    echo 'OK'
"
