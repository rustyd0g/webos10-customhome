# Customizing the LG webOS 10 / webOS25 Homescreen

Customize the LG webOS Home screen by changing its layout, text, and optionally its hero banner, without modifying the original read-only system files.

> **Tested on:** LG webOS 10.2.2 (Rockhopper), EU region
> **Requirements:** Root access, SSH access, Homebrew Channel, and `webosbrew` init.d support

---

# Before / After

## Before

![Homescreen](SCR-20260428-shkq.jpeg)

## After

![Homescreen](webos-dev-tmp-58150897-6906-4e77-a7dd-f994a6e4282a.png)

---

## Background

On webOS 10, the Home app has been rewritten in **Flutter**.

Its layout is controlled by XML files, while UI text comes from locale JSON files contained inside the Home application's Flutter assets directory:

```text
/usr/palm/applications/com.webos.app.home/data/flutter_assets/assets/
```

These files are stored on LG's read-only system filesystem and should not be modified directly.

Instead, this method uses **OverlayFS**.

The original Home assets directory remains the read-only lower layer. A small writable upper layer is created under `/tmp` containing only the files you want to replace.

The result is presented at the original assets path:

```text
LG original assets
       +
custom upper layer
       |
       v
merged Home assets
```

Anything that does not exist in the upper layer continues to come directly from LG's original filesystem.

This means there is no need to copy the entire Flutter asset tree into RAM.

The underlying LG files remain unchanged.

---

## Important `i18n` Detail

The original `i18n` entry inside the Home assets directory is a **symlink** to another read-only location.

OverlayFS handles this differently from an ordinary directory.

When a real directory named `i18n` exists in the upper layer, it shadows the lower-layer symlink completely.

Therefore:

> Your custom `assets/i18n/` directory should contain the complete locale set required by the Home app, not only the JSON files you modify.

The instructions below copy the original locale files into your writable override directory before you make any changes.

---

## Persistent and Temporary Files

Persistent custom files are kept under:

```text
/media/developer/apps/usr/palm/applications/tld.my.customhome/
```

Runtime OverlayFS files are created under:

```text
/tmp/weboshome-overlay-upper/
/tmp/weboshome-overlay-work/
```

The `/tmp` contents and OverlayFS mount disappear after reboot.

This is intentional and provides a simple rollback mechanism.

---

# Initial Setup

Create the custom project directory:

```sh
mkdir -p /media/developer/apps/usr/palm/applications/tld.my.customhome/assets/i18n
```

Banner image directories are only needed if you want to replace the hero banner:

```sh
mkdir -p /media/developer/apps/usr/palm/applications/tld.my.customhome/assets/images/hd
mkdir -p /media/developer/apps/usr/palm/applications/tld.my.customhome/assets/images/2k
mkdir -p /media/developer/apps/usr/palm/applications/tld.my.customhome/assets/images/4k
```

---

## Copy the Original XML Files

> **Initial setup only.**
>
> These commands copy LG's original files into your writable override directory.
> They do **not** modify the originals.
>
> Do not rerun them after editing your custom copies unless you intentionally want to reset your changes.

```sh
cp /usr/palm/applications/com.webos.app.home/data/flutter_assets/assets/home.xml \
   /media/developer/apps/usr/palm/applications/tld.my.customhome/assets/home.xml

cp /usr/palm/applications/com.webos.app.home/data/flutter_assets/assets/home_layoutShelfView.xml \
   /media/developer/apps/usr/palm/applications/tld.my.customhome/assets/home_layoutShelfView.xml
```

---

## Copy the Locale Files

> **Initial setup only.**
>
> Copy the complete locale set before making any modifications.
>
> Rerunning this command later may overwrite locale files you have already customised.

```sh
cp /mnt/lg/wee/ui_l10n/usr/palm/applications/com.webos.app.home/data/flutter_assets/assets/i18n/* \
   /media/developer/apps/usr/palm/applications/tld.my.customhome/assets/i18n/
```

---

# The `apply.sh` Script

The script:

* verifies that the required XML and locale overrides exist
* removes any previous Home asset overlay
* recreates fresh OverlayFS upper and work directories
* copies the two modified XML files
* copies the custom `i18n` directory
* optionally copies banner images if they exist
* mounts the merged OverlayFS view
* restarts the Home app

Create it with:

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

# ---------------------------------------------------------------------------
# Remove an existing overlay from a previous run.
#
# This reveals the original LG assets before the upper layer is rebuilt.
# ---------------------------------------------------------------------------

umount "$ASSETS_DIR" 2>/dev/null || true

# ---------------------------------------------------------------------------
# Recreate temporary OverlayFS directories.
# ---------------------------------------------------------------------------

rm -rf "$UPPER_DIR" "$WORK_DIR"

mkdir -p \
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
# i18n override
#
# The original ASSETS_DIR/i18n entry is a symlink.
# A real i18n directory in upperdir shadows it completely.
#
# Keep a complete locale set under OVERRIDE_DIR/i18n.
#
# BusyBox cp supports -a, which preserves attributes and symlinks inside
# the copied tree.
# ---------------------------------------------------------------------------

cp -a "$OVERRIDE_DIR/i18n/." \
      "$UPPER_DIR/i18n/"

# ---------------------------------------------------------------------------
# Optional banner image overrides
#
# Each resolution is independent.
#
# If a custom file exists, it is added to the upper layer.
# If it does not exist, OverlayFS uses LG's original image automatically.
# ---------------------------------------------------------------------------

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

The `cat ... << 'EOF'` wrapper is only used to create the script from the SSH shell.

The resulting `apply.sh` file begins with:

```sh
#!/bin/sh
```

and does not contain the surrounding `cat`, `EOF`, or `chmod` commands.

---

# Removing Unwanted UI Elements

Edit your copied version:

```text
/media/developer/apps/usr/palm/applications/tld.my.customhome/assets/home.xml
```

Do not edit:

```text
/usr/palm/applications/com.webos.app.home/data/flutter_assets/assets/home.xml
```

directly.

---

## Remove the Recommended Shelf

The `recommendedShelf` is the large recommendation area near the bottom of the Home screen.

Remove it from your override:

```sh
sed -i '/<item id="recommendedShelf"/d' \
    /media/developer/apps/usr/palm/applications/tld.my.customhome/assets/home.xml
```

---

## Remove the Q-Card List

Remove the horizontal Q-Card area:

```sh
sed -i '/<item id="qcardList"/d' \
    /media/developer/apps/usr/palm/applications/tld.my.customhome/assets/home.xml
```

---

## Hide the Global Navigation Menu

The `globalline` element controls the global navigation area.

Removing it completely can cause the Home screen to fail.

Instead, set:

```xml
itemWidth="0"
itemHeight="0"
```

The element should remain after `herobanner` inside the container.

---

## Example `home.xml`

A modified layout with a fullscreen hero area and the application list at the bottom:

```xml
<?xml version="1.0" encoding="utf-8"?>
<home version="2.0">
<layout windowType="overlay" pageType="none" pageCount="1" defaultPage="0">
<page pageBodyType="container">

<item id="margin"
      itemWidth="3840"
      itemHeight="0"
      focusType="none"/>

<item id="container"
      hasChildren="true"
      itemWidth="3840"
      itemHeight="1803"
      focusType="scope">

<item id="herobanner"
      itemWidth="3840"
      itemHeight="1803"
      focusType="scope"
      autoFocus="false"/>

<item id="globalline"
      itemWidth="0"
      itemHeight="0"
      focusType="scope"
      autoFocus="false"/>

</item>

<item id="margin"
      itemWidth="3840"
      itemHeight="50"
      focusType="none"/>

<item id="appList"
      itemWidth="3840"
      itemHeight="248"
      focusType="scope"
      autoFocus="true"/>

<item id="margin"
      itemWidth="3840"
      itemHeight="48"
      focusType="none"/>

<item id="quickGuide"
      itemX="0"
      itemY="0"
      itemWidth="0"
      itemHeight="0"
      focusType="none"/>

</page>
</layout>
</home>
```

The top margin should be:

```xml
itemHeight="0"
```

to avoid a thin black strip along the top edge.

---

# Changing or Removing UI Text

The hero banner includes text such as the headline and CTA button.

These strings can be changed by editing the copies under:

```text
/media/developer/apps/usr/palm/applications/tld.my.customhome/assets/i18n/
```

For example:

```text
de.json
```

To remove text:

```sh
sed -i 's/"Start a new experience with webOS.": "[^"]*"/"Start a new experience with webOS.": ""/' \
    /media/developer/apps/usr/palm/applications/tld.my.customhome/assets/i18n/de.json

sed -i 's/"Go to Apps": "[^"]*"/"Go to Apps": ""/' \
    /media/developer/apps/usr/palm/applications/tld.my.customhome/assets/i18n/de.json
```

Or replace a string:

```sh
sed -i 's/"Start a new experience with webOS.": "[^"]*"/"Start a new experience with webOS.": "Your custom text here"/' \
    /media/developer/apps/usr/palm/applications/tld.my.customhome/assets/i18n/de.json
```

Only your copied files under `/media/developer` are changed.

LG's original locale files remain untouched.

---

# Optional Hero Banner Override

Replacing the banner is optional.

If no custom banner files are present, OverlayFS automatically uses LG's original images.

The banner paths are:

```text
assets/images/hd/bg_banner_img.png
assets/images/2k/bg_banner_img.png
assets/images/4k/bg_banner_img.png
```

To override them, create the directories if necessary:

```sh
mkdir -p /media/developer/apps/usr/palm/applications/tld.my.customhome/assets/images/hd
mkdir -p /media/developer/apps/usr/palm/applications/tld.my.customhome/assets/images/2k
mkdir -p /media/developer/apps/usr/palm/applications/tld.my.customhome/assets/images/4k
```

Then copy your image:

```sh
scp your_image.png \
    root@<TV-IP>:/media/developer/apps/usr/palm/applications/tld.my.customhome/assets/images/4k/bg_banner_img.png

scp your_image.png \
    root@<TV-IP>:/media/developer/apps/usr/palm/applications/tld.my.customhome/assets/images/2k/bg_banner_img.png

scp your_image.png \
    root@<TV-IP>:/media/developer/apps/usr/palm/applications/tld.my.customhome/assets/images/hd/bg_banner_img.png
```

You do not need to provide all three resolutions.

If, for example, only this exists:

```text
assets/images/4k/bg_banner_img.png
```

then only the 4K image is overridden.

The HD and 2K images continue to come from LG's original assets.

For a fullscreen hero banner using:

```xml
itemHeight="1803"
```

a suitable 4K image size is:

```text
3840x1803
```

For the default banner height:

```text
3840x900
```

---

# Testing

Apply the changes manually before enabling autostart:

```sh
sh /media/developer/apps/usr/palm/applications/tld.my.customhome/apply.sh
```

The Home app should restart automatically.

---

## Verify the OverlayFS Mount

Run:

```sh
mount | grep '/usr/palm/applications/com.webos.app.home/data/flutter_assets/assets'
```

You should see an `overlay` mount at that path.

---

## Verify `home.xml`

```sh
cmp \
  /media/developer/apps/usr/palm/applications/tld.my.customhome/assets/home.xml \
  /usr/palm/applications/com.webos.app.home/data/flutter_assets/assets/home.xml
```

No output means the merged view contains your override.

---

## Verify `home_layoutShelfView.xml`

```sh
cmp \
  /media/developer/apps/usr/palm/applications/tld.my.customhome/assets/home_layoutShelfView.xml \
  /usr/palm/applications/com.webos.app.home/data/flutter_assets/assets/home_layoutShelfView.xml
```

Again, no output means the files match.

---

## Verify an Optional Banner Override

If you supplied a custom 4K banner:

```sh
cmp \
  /media/developer/apps/usr/palm/applications/tld.my.customhome/assets/images/4k/bg_banner_img.png \
  /usr/palm/applications/com.webos.app.home/data/flutter_assets/assets/images/4k/bg_banner_img.png
```

No output means OverlayFS is serving your image.

---

# Recovery

If the Home screen becomes unusable, crashes, or displays a black screen:

```sh
reboot
```

The OverlayFS mount disappears during reboot because its upper and work directories live in `/tmp`.

LG's original Home assets then become visible again.

No original system file needs to be restored because none was overwritten.

---

# Making the Customisation Persistent

After testing the script manually, register it with the `webosbrew` init system:

```sh
ln -sf /media/developer/apps/usr/palm/applications/tld.my.customhome/apply.sh \
       /var/lib/webosbrew/init.d/49-custom-homescreen
```

Then reboot:

```sh
reboot
```

After boot, verify the overlay:

```sh
mount | grep '/usr/palm/applications/com.webos.app.home/data/flutter_assets/assets'
```

---

# Removing Autostart

Remove the `webosbrew` startup link:

```sh
rm /var/lib/webosbrew/init.d/49-custom-homescreen
```

Then reboot:

```sh
reboot
```

The TV will return to LG's original Home assets.

Your custom files under `/media/developer` remain available if you want to enable them again later.

---

# Directory Layout

A setup without custom banner images can be as simple as:

```text
/media/developer/apps/usr/palm/applications/tld.my.customhome/
├── apply.sh
└── assets/
    ├── home.xml
    ├── home_layoutShelfView.xml
    └── i18n/
        ├── de.json
        ├── en-GB.json
        └── ...
```

If banner overrides are used:

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

At runtime:

```text
/tmp/weboshome-overlay-upper/
/tmp/weboshome-overlay-work/
```

are created automatically.

---

# How OverlayFS Handles the Overrides

Suppose the original assets contain:

```text
home.xml
home_layoutShelfView.xml
home_lg.xml
fonts/
images/
mock/
i18n -> symlink
```

and the upper layer contains:

```text
home.xml
home_layoutShelfView.xml
i18n/
```

The merged result is effectively:

```text
home.xml                    -> custom upper layer
home_layoutShelfView.xml    -> custom upper layer
i18n/                       -> custom upper layer
home_lg.xml                 -> LG lower layer
fonts/                       -> LG lower layer
images/                      -> LG lower layer
mock/                        -> LG lower layer
```

If a custom image is later added:

```text
images/4k/bg_banner_img.png
```

then the merged image tree becomes:

```text
images/4k/bg_banner_img.png  -> custom upper layer
all other images             -> LG lower layer
```

This is one of the main advantages of OverlayFS.

Only files that are actually being customised need to be copied.

---

# Why OverlayFS?

An earlier version of this method copied the complete Home asset tree into `/tmp` before applying the changes and bind-mounting the resulting directory.

That works, but it is unnecessary.

OverlayFS:

* avoids copying the complete Flutter asset tree
* reduces temporary RAM usage
* reduces unnecessary filesystem reads
* applies faster
* keeps unchanged files directly backed by LG's original filesystem
* clearly separates original and modified files
* makes optional overrides straightforward

The original files remain untouched in both approaches, but OverlayFS is more economical.

---

# BusyBox Compatibility

webOS uses BusyBox for many standard Unix utilities.

GNU-specific command-line options should therefore not be assumed to exist.

For example, older versions of this guide used:

```text
cp -R --no-dereference
```

when copying an entire asset tree.

BusyBox `cp` does not necessarily provide GNU's `--no-dereference` long option.

This OverlayFS version no longer needs to copy the original asset tree at all.

For the recursive `i18n` copy, it uses:

```sh
cp -a
```

which is supported by BusyBox and preserves attributes and symlinks within the copied tree.

---

# What Gets Modified?

The following are **your custom persistent files**:

```text
/media/developer/apps/usr/palm/applications/tld.my.customhome/
```

The script also creates temporary files under:

```text
/tmp/
```

The following are used only as **read-only sources**:

```text
/usr/palm/applications/com.webos.app.home/
/mnt/lg/wee/ui_l10n/
```

The script does not overwrite files in either location.

OverlayFS temporarily changes what is visible through the Home asset pathname, but the underlying LG files remain unchanged.

---

# Notes & Limitations

* XML structure can vary between TV models, regions, and webOS versions.
* Always inspect the original files on your own TV before modifying your copies.
* Test the script manually before enabling autostart.
* A broken `home.xml` can cause a black screen or Home app failure.
* The OverlayFS upper and work directories live in `/tmp` and disappear after reboot.
* The original Home application files are never modified.
* The signed system filesystem should never be written to directly.
* Do not write directly to raw eMMC partitions such as `/dev/mmcblk0p*`.
* `upperdir` and `workdir` must exist on the same writable filesystem. This script places both under `/tmp`.
* The custom `i18n` directory shadows the original `i18n` symlink completely, so it should contain the full locale set.
* Banner images are optional.
* Each banner resolution can be overridden independently.
* BusyBox-compatible shell commands are used.
* Icon size is hardcoded in the Flutter binary (`libapp.so`) and cannot be changed through the XML layout.
* `option="webOS24"` and similar AppList options appear to be ignored.
* A built-in clock component exists in the senior layout (`home_lg.xml`) but does not render outside that layout context.

---

# Credits

Thanks to `/u/really_accidental` for the tip about hiding the global navigation for an even cleaner Home screen.

Thanks to the contributors who tested the OverlayFS approach and BusyBox-compatible `cp -a` handling on rooted LG webOS TVs.
