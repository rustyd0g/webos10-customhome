# Customizing the LG webOS 10 / webOS25 Homescreen

How to replace the background image, remove unwanted UI elements, and change system text on your LG TV, without making permanent changes to the read-only filesystem.

> **Tested on:** LG webOS 10.2.2 (Rockhopper), EU region
> **Requirements:** Root access, active SSH connection, Homebrew Channel with `webosbrew` init.d support

---

# Before / After

## Before

![Homescreen](SCR-20260428-shkq.jpeg)

## After

![Homescreen](webos-dev-tmp-58150897-6906-4e77-a7dd-f994a6e4282a.png)

---

## Background

On webOS 10, the Home app has been completely rewritten in **Flutter**, unlike older versions which used QML.

The layout is controlled by XML files, and UI text comes from locale JSON files, all inside the app's Flutter assets directory:

```text
/usr/palm/applications/com.webos.app.home/data/flutter_assets/assets/
```

This directory is on a read-only, cryptographically signed filesystem, so the original files should not be edited directly.

Instead, this method uses **OverlayFS**.

The original Home assets directory remains the read-only lower layer, while a small writable upper layer in `/tmp` contains only the files that need to be replaced.

Unmodified files continue to be served directly from LG's original filesystem.

This avoids copying the complete Flutter asset tree into RAM every time the customisation is applied.

One important detail is that the `i18n` entry inside the original assets directory is a **symlink** to another read-only location.

OverlayFS handles this cleanly. A real `i18n` directory placed in the upper layer shadows the lower-layer symlink by name.

Because the original symlink is hidden completely, the custom `i18n` directory should contain the full locale set required by the Home app, not only the locale files you modify.

The OverlayFS upper and work directories are created under `/tmp`, so the overlay itself is intentionally temporary.

A normal reboot removes the overlay and restores the stock Home app unless the apply script is registered with `webosbrew` init.d.

---

## Directory Structure

Create the working directory on the writable developer partition:

```sh
mkdir -p /media/developer/apps/usr/palm/applications/tld.my.customhome/assets/images/hd
mkdir -p /media/developer/apps/usr/palm/applications/tld.my.customhome/assets/images/2k
mkdir -p /media/developer/apps/usr/palm/applications/tld.my.customhome/assets/images/4k
mkdir -p /media/developer/apps/usr/palm/applications/tld.my.customhome/assets/i18n
```

---

## The `apply.sh` Script

This script:

* checks that the required override files exist
* removes any previous Home asset overlay
* creates fresh OverlayFS upper and work directories under `/tmp`
* copies only the modified XML, image and locale files into the upper layer
* mounts the merged OverlayFS view over the original Home assets directory
* restarts the Home app

Unmodified files remain available directly from LG's original read-only filesystem.

```sh
cat > /media/developer/apps/usr/palm/applications/tld.my.customhome/apply.sh << 'EOF'
#!/bin/sh

set -e -x

ASSETS_DIR=/usr/palm/applications/com.webos.app.home/data/flutter_assets/assets
OVERRIDE_DIR=/media/developer/apps/usr/palm/applications/tld.my.customhome/assets

UPPER_DIR=/tmp/weboshome-overlay-upper
WORK_DIR=/tmp/weboshome-overlay-work

# ---------------------------------------------------------------------------
# Sanity checks
# ---------------------------------------------------------------------------

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

[ -f "$OVERRIDE_DIR/images/hd/bg_banner_img.png" ] || {
    echo "ERROR: Missing HD banner image"
    exit 1
}

[ -f "$OVERRIDE_DIR/images/2k/bg_banner_img.png" ] || {
    echo "ERROR: Missing 2K banner image"
    exit 1
}

[ -f "$OVERRIDE_DIR/images/4k/bg_banner_img.png" ] || {
    echo "ERROR: Missing 4K banner image"
    exit 1
}

# ---------------------------------------------------------------------------
# Remove an existing overlay from a previous run.
#
# This exposes the original LG assets before rebuilding the upper layer.
# ---------------------------------------------------------------------------

umount "$ASSETS_DIR" 2>/dev/null || true

# ---------------------------------------------------------------------------
# Recreate temporary OverlayFS directories.
#
# These live under /tmp and disappear after a reboot.
# ---------------------------------------------------------------------------

rm -rf "$UPPER_DIR" "$WORK_DIR"

mkdir -p \
    "$UPPER_DIR/images/hd" \
    "$UPPER_DIR/images/2k" \
    "$UPPER_DIR/images/4k" \
    "$UPPER_DIR/i18n" \
    "$WORK_DIR"

# ---------------------------------------------------------------------------
# XML overrides
# ---------------------------------------------------------------------------

cp "$OVERRIDE_DIR/home.xml" \
   "$UPPER_DIR/home.xml"

cp "$OVERRIDE_DIR/home_layoutShelfView.xml" \
   "$UPPER_DIR/home_layoutShelfView.xml"

# ---------------------------------------------------------------------------
# Banner image overrides
#
# Only these files are stored in the upper layer.
# Other images continue to come from LG's original assets directory.
# ---------------------------------------------------------------------------

cp "$OVERRIDE_DIR/images/hd/bg_banner_img.png" \
   "$UPPER_DIR/images/hd/bg_banner_img.png"

cp "$OVERRIDE_DIR/images/2k/bg_banner_img.png" \
   "$UPPER_DIR/images/2k/bg_banner_img.png"

cp "$OVERRIDE_DIR/images/4k/bg_banner_img.png" \
   "$UPPER_DIR/images/4k/bg_banner_img.png"

# ---------------------------------------------------------------------------
# i18n override
#
# The original ASSETS_DIR/i18n is a symlink.
# A real i18n directory in the OverlayFS upper layer shadows that symlink.
#
# BusyBox cp supports -a, which preserves attributes and symlinks within
# the override tree.
# ---------------------------------------------------------------------------

cp -a "$OVERRIDE_DIR/i18n/." "$UPPER_DIR/i18n/"

# ---------------------------------------------------------------------------
# Mount the merged OverlayFS view.
#
# lowerdir = original LG read-only assets
# upperdir = changed files only
# workdir  = OverlayFS working directory
#
# upperdir and workdir are both under /tmp.
# ---------------------------------------------------------------------------

mount -t overlay overlay \
    -o lowerdir="$ASSETS_DIR",upperdir="$UPPER_DIR",workdir="$WORK_DIR" \
    "$ASSETS_DIR"

# ---------------------------------------------------------------------------
# Restart Home so it reloads the modified assets.
# ---------------------------------------------------------------------------

pkill -f com.webos.app.home || true

EOF

chmod +x /media/developer/apps/usr/palm/applications/tld.my.customhome/apply.sh
```

The `umount` at the start makes the script safe to run repeatedly.

The original LG files are never modified.

---

## Removing Unwanted UI Elements

The layout is defined in two XML files.

Copy them into the override directory first:

```sh
cp /usr/palm/applications/com.webos.app.home/data/flutter_assets/assets/home.xml \
   /media/developer/apps/usr/palm/applications/tld.my.customhome/assets/home.xml

cp /usr/palm/applications/com.webos.app.home/data/flutter_assets/assets/home_layoutShelfView.xml \
   /media/developer/apps/usr/palm/applications/tld.my.customhome/assets/home_layoutShelfView.xml
```

### Remove the Recommended Shelf

The `recommendedShelf` is the large content recommendation strip at the bottom of the screen, loaded dynamically from LG's servers.

```sh
sed -i '/<item id="recommendedShelf"/d' \
    /media/developer/apps/usr/palm/applications/tld.my.customhome/assets/home.xml
```

### Remove the Q-Card List

The `qcardList` is the horizontal card strip shown above the app list.

```sh
sed -i '/<item id="qcardList"/d' \
    /media/developer/apps/usr/palm/applications/tld.my.customhome/assets/home.xml
```

### Hide the Global Navigation Menu

The `globalline` is the vertical icon menu on the side.

Setting its size to zero hides it without breaking the layout.

Do not remove the element completely, as doing so can result in a black screen.

In `home.xml`, set the `globalline` item to width and height `0`.

It should come **after** `herobanner` inside the container so that it does not push other content.

### Example `home.xml`

A fully modified `home.xml` with a fullscreen hero banner and the app list positioned at the bottom can look like this:

```xml
<?xml version="1.0" encoding="utf-8"?>
<home version="2.0">
<layout windowType="overlay" pageType="none" pageCount="1" defaultPage="0">
<page pageBodyType="container">
<item id="margin" itemWidth="3840" itemHeight="0" focusType="none"/>
<item id="container" hasChildren="true" itemWidth="3840" itemHeight="1803" focusType="scope">
<item id="herobanner" itemWidth="3840" itemHeight="1803" focusType="scope" autoFocus="false"/>
<item id="globalline" itemWidth="0" itemHeight="0" focusType="scope" autoFocus="false"/>
</item>
<item id="margin" itemWidth="3840" itemHeight="50" focusType="none"/>
<item id="appList" itemWidth="3840" itemHeight="248" focusType="scope" autoFocus="true"/>
<item id="margin" itemWidth="3840" itemHeight="48" focusType="none"/>
<item id="quickGuide" itemX="0" itemY="0" itemWidth="0" itemHeight="0" focusType="none"/>
</page>
</layout>
</home>
```

> The top margin should be `itemHeight="0"` to avoid a thin black bar at the top.

---

## Replacing the Hero Banner Image

The hero banner background image exists in three resolutions:

```text
assets/images/hd/bg_banner_img.png
assets/images/2k/bg_banner_img.png
assets/images/4k/bg_banner_img.png
```

If you use a fullscreen hero banner with:

```text
itemHeight="1803"
```

the recommended image dimensions are:

```text
3840x1803
```

For the default banner size, use:

```text
3840x900
```

Copy the image to the TV:

```sh
scp your_image.png root@<TV-IP>:/media/developer/apps/usr/palm/applications/tld.my.customhome/assets/images/4k/bg_banner_img.png

scp your_image.png root@<TV-IP>:/media/developer/apps/usr/palm/applications/tld.my.customhome/assets/images/2k/bg_banner_img.png

scp your_image.png root@<TV-IP>:/media/developer/apps/usr/palm/applications/tld.my.customhome/assets/images/hd/bg_banner_img.png
```

Only these three files are placed in the OverlayFS upper layer.

Other image assets continue to come directly from LG's original Home application.

---

## Changing or Removing UI Text

The hero banner contains text such as the headline and CTA button.

These strings can be changed or removed by modifying the locale JSON files.

First copy the complete locale set into the override directory:

```sh
cp /mnt/lg/wee/ui_l10n/usr/palm/applications/com.webos.app.home/data/flutter_assets/assets/i18n/* \
   /media/developer/apps/usr/palm/applications/tld.my.customhome/assets/i18n/
```

This is important because the custom upper-layer `i18n` directory shadows the original `i18n` symlink completely.

The override directory therefore needs to contain all locale files that the Home app may need.

Then edit the required locale file.

For example:

```text
de.json
```

To remove text completely:

```sh
sed -i 's/"Start a new experience with webOS.": "[^"]*"/"Start a new experience with webOS.": ""/' \
    /media/developer/apps/usr/palm/applications/tld.my.customhome/assets/i18n/de.json

sed -i 's/"Go to Apps": "[^"]*"/"Go to Apps": ""/' \
    /media/developer/apps/usr/palm/applications/tld.my.customhome/assets/i18n/de.json
```

Or replace it with custom text:

```sh
sed -i 's/"Start a new experience with webOS.": "[^"]*"/"Start a new experience with webOS.": "Your custom text here"/' \
    /media/developer/apps/usr/palm/applications/tld.my.customhome/assets/i18n/de.json
```

---

## Testing

Apply the changes manually first:

```sh
sh /media/developer/apps/usr/palm/applications/tld.my.customhome/apply.sh
```

The Home app should restart automatically.

Check that OverlayFS is mounted over the assets directory:

```sh
mount | grep '/usr/palm/applications/com.webos.app.home/data/flutter_assets/assets'
```

You should see an `overlay` mount for the Home assets path.

### Verify the XML Overrides

Check `home.xml`:

```sh
cmp \
  /media/developer/apps/usr/palm/applications/tld.my.customhome/assets/home.xml \
  /usr/palm/applications/com.webos.app.home/data/flutter_assets/assets/home.xml
```

Check `home_layoutShelfView.xml`:

```sh
cmp \
  /media/developer/apps/usr/palm/applications/tld.my.customhome/assets/home_layoutShelfView.xml \
  /usr/palm/applications/com.webos.app.home/data/flutter_assets/assets/home_layoutShelfView.xml
```

No output from `cmp` means the files match.

### Verify a Banner Override

For example:

```sh
cmp \
  /media/developer/apps/usr/palm/applications/tld.my.customhome/assets/images/4k/bg_banner_img.png \
  /usr/palm/applications/com.webos.app.home/data/flutter_assets/assets/images/4k/bg_banner_img.png
```

Again, no output means the merged view is serving the override.

### Recovery

If something goes wrong, such as a black screen or Home app crash, reboot the TV.

The OverlayFS mount and its upper/work directories are under `/tmp` and are not persistent across reboot.

The original LG files will become visible again automatically.

---

## Making Changes Persistent

Once the customisation has been tested successfully, register the script with the `webosbrew` init system:

```sh
ln -sf /media/developer/apps/usr/palm/applications/tld.my.customhome/apply.sh \
       /var/lib/webosbrew/init.d/49-custom-homescreen
```

Then reboot:

```sh
reboot
```

After reboot, verify that the overlay is present:

```sh
mount | grep '/usr/palm/applications/com.webos.app.home/data/flutter_assets/assets'
```

---

## Removing the Autostart

To stop automatically applying the customisation:

```sh
rm /var/lib/webosbrew/init.d/49-custom-homescreen
```

Then reboot:

```sh
reboot
```

Because the actual Home application files were never changed, the TV will return to the stock Home assets.

---

## Final Directory Layout

The persistent custom files should look like this:

```text
/media/developer/apps/usr/palm/applications/tld.my.customhome/
├── apply.sh
└── assets/
    ├── home.xml
    ├── home_layoutShelfView.xml
    ├── i18n/
    │   ├── de.json
    │   ├── en-GB.json
    │   └── ...
    └── images/
        ├── hd/
        │   └── bg_banner_img.png
        ├── 2k/
        │   └── bg_banner_img.png
        └── 4k/
            └── bg_banner_img.png
```

At runtime, the script creates:

```text
/tmp/weboshome-overlay-upper/
/tmp/weboshome-overlay-work/
```

The upper layer contains only the files being overridden.

Everything else is served from the original Home assets directory.

---

## How the Overlay Works

Conceptually, the merged Home assets look like this:

```text
Original LG assets
        +
Custom upper layer
        |
        v
Merged Home assets
```

For ordinary files such as:

```text
home.xml
home_layoutShelfView.xml
images/4k/bg_banner_img.png
```

the file from the upper layer replaces the same path from the lower layer.

For directories such as:

```text
images/
```

the directory trees are merged.

This means only the changed banner files need to exist in the upper layer. Unmodified images remain visible from the lower layer.

The `i18n` entry behaves differently because the lower-layer entry is a symlink while the upper-layer entry is a real directory.

The upper directory shadows the lower symlink completely.

This is why the custom `i18n` directory should contain the complete locale set.

---

## Why OverlayFS Instead of Copying the Entire Assets Directory?

An earlier version of this method copied the complete Home assets directory into `/tmp` before applying the changes and bind-mounting the copied tree over the original directory.

That works, but it performs unnecessary work.

Using OverlayFS:

* avoids copying the full Flutter asset tree
* reduces temporary RAM usage
* reduces unnecessary reads
* applies more quickly
* keeps unchanged assets directly backed by LG's original filesystem
* makes it clearer which files are actually being overridden

Only the customised files need to exist in the writable upper layer.

---

## BusyBox Compatibility

webOS uses BusyBox for many standard shell utilities.

Avoid assuming that GNU-specific long options are available.

For recursive copies in this guide, the script uses:

```sh
cp -a
```

for the `i18n` tree.

This avoids relying on GNU-specific options such as:

```text
--no-dereference
```

The individual XML and PNG files are copied using normal `cp`.

---

## Notes & Limitations

* XML element names and file structures may differ between TV models, regions and webOS versions. Inspect the original files on your own TV first.
* The OverlayFS upper and work directories are stored in `/tmp` and disappear on reboot.
* The original Home application files are never modified.
* The signed system filesystem and underlying partitions should not be written to directly.
* `upperdir` and `workdir` must be on the same writable filesystem. This script places both under `/tmp`.
* The upper-layer `i18n` directory shadows the original `i18n` symlink completely, so keep a complete locale set in the override directory.
* BusyBox `cp` supports `-a`; this is preferable to GNU-specific long options for recursive copies.
* Icon size is hardcoded in the Flutter binary (`libapp.so`) and cannot be changed through the XML layout.
* `option="webOS24"` and similar values on the AppList item are ignored.
* A built-in clock component exists in the senior layout (`home_lg.xml`) but does not render outside that layout context.
* A bad Home layout can cause the Home app to fail or display a black screen. Test manually before enabling autostart.
* Reboot recovery works because the overlay is temporary and the original read-only files remain unchanged.

---

## Credits

Thanks to `/u/really_accidental` for the tip about hiding the global navigation for an even cleaner look.

Thanks also to the contributors who tested the OverlayFS approach and BusyBox-compatible `cp -a` handling on rooted LG webOS TVs.
