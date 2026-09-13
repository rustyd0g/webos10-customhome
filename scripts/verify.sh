#!/bin/sh

set -eu

TV="${TV:-lg-tv}"

TARGET=/media/developer/apps/usr/palm/applications/tld.my.customhome
ASSETS=/usr/palm/applications/com.webos.app.home/data/flutter_assets/assets

ssh "$TV" "
    set -e

    echo '=== Overlay mount ==='

    mount | grep '$ASSETS' || {
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

    echo 'OK'
"
