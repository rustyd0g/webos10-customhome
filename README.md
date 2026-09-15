# webOS 10 Custom Home

Customise the LG webOS 10 / webOS25 Home screen without changing LG's
read-only system files.

The project places selected Home assets in a temporary OverlayFS upper layer.
LG's original assets remain the lower layer and are used whenever no override
exists.

> [!WARNING]
> This project requires a rooted TV, Homebrew Channel/webOSbrew, and root SSH
> access. Layout files vary between models, regions, and webOS releases. Create
> a local stock snapshot for reference, and test manually before
> enabling automatic startup.

## What can be changed?

The repository supports four kinds of customisation:

| Area | Override | Examples |
| --- | --- | --- |
| Home structure | `overrides/home.xml` | Hide navigation, remove shelves, change item sizes |
| Shelf layout | `overrides/home_layoutShelfView.xml` | Reposition the hero, cards, apps, or advertising shelf |
| Interface text | `overrides/i18n/<locale>.json` | Rename labels or adjust regional wording |
| Hero artwork | `overrides/images/<resolution>/bg_banner_img.png` | Replace the HD, 2K, or 4K banner independently |

### Layout examples

Edit `overrides/home.xml`. To remove the recommendation shelf or the Q-Card
strip above the apps, delete the corresponding item (either or both):

```xml
<item id="recommendedShelf" itemWidth="3798" itemHeight="531" focusType="scope" autoFocus="false"/>
<item id="qcardList" itemWidth="3840" itemHeight="180" focusType="scope" autoFocus="false"/>
```

To hide global navigation, retain `globalline`, set its width and height to
zero, and place it **after `herobanner` inside the same container**:

```xml
<item id="globalline" itemWidth="0" itemHeight="0" focusType="scope" autoFocus="false"/>
```

The original guide reports a black screen when `globalline` is removed entirely.

<details>
<summary>Full example: expanded hero with apps at the bottom</summary>

This complete `overrides/home.xml` example comes from the original guide,
reported tested on webOS 10.2.2 (EU). It removes both shelves, hides navigation,
and gives the hero a 3840×1803 area. The first margin has height `0` to avoid
a thin black strip at the top. Adapt it to the stock layout for your firmware.

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

</details>

In `overrides/home_layoutShelfView.xml`, position and dimension attributes
can be adjusted to change spacing or move a component, for example:

```xml
<item type="AppList" itemX="24" itemY="850" itemWidth="1872" itemHeight="173" focus="true" option="webOS24"/>
```

The accepted elements and attributes are not a public API. Make one change at
a time, keep the XML well formed, and be prepared to roll back if Home cannot
render a modified layout.

### Text examples

Edit the relevant locale under `overrides/i18n/`, such as `en_GB.json` or
`de.json`. Keep each key unchanged and edit only its value. These snippets show
individual entries to change; retain the other entries in the locale file.

Rename labels:

```json
{
  "Channel": "Programme",
  "Frequently Viewed Channels": "Frequently Viewed Programmes"
}
```

Hide the hero headline and button text by setting their values to empty strings:

```json
{
  "Start a new experience with webOS.": "",
  "Go to Apps": ""
}
```

Blanking a label does not necessarily remove its button or reserved space.
To use a custom headline instead:

```json
{
  "Start a new experience with webOS.": "Your custom text here"
}
```

Preserve placeholders such as `{arg1}`, `{arg2}`, `{%TV_model}`, and
`{AI_icon}` because Home substitutes them at runtime.

### Banner examples

`pull-stock.sh` downloads the original banners as editing references:

```text
../webos10-customhome-stock/images/hd/bg_banner_img.png
../webos10-customhome-stock/images/2k/bg_banner_img.png
../webos10-customhome-stock/images/4k/bg_banner_img.png
```

Copy only the resolutions you want to replace into the repository. For
example, to start from LG's 4K banner:

```sh
mkdir -p overrides/images/4k
cp ../webos10-customhome-stock/images/4k/bg_banner_img.png \
    overrides/images/4k/bg_banner_img.png
```

Supported override paths are:

```text
overrides/images/hd/bg_banner_img.png
overrides/images/2k/bg_banner_img.png
overrides/images/4k/bg_banner_img.png
```

Missing resolutions continue to use LG's original image.

For an unchanged layout, match the dimensions of each downloaded PNG. One
stock snapshot has these sizes; check your own files because firmware varies:

| Profile | Stock `bg_banner_img.png` dimensions |
| --- | --- |
| HD | 1264×326 |
| 2K | 1746×450 |
| 4K | 3492×900 |

For the expanded 3840×1803 hero example above, use 3840×1803 artwork for the
4K override. The original guide's 3840×900 suggestion assumes a 3840-wide hero;
it is not a universal stock image size. Size other resolution variants for
their layout rather than assuming every profile uses the same dimensions.

## How it works

```text
LG read-only Home assets
          +
temporary overrides in /tmp
          |
          v
merged Home assets seen by the Home app
```

The merged view is mounted at:

```text
/usr/palm/applications/com.webos.app.home/data/flutter_assets/assets
```

Mounting over this path does not write to the underlying directory. The
OverlayFS upper and work directories are stored under `/tmp` and disappear on
reboot.

## Requirements

- A rooted LG webOS 10/webOS25 TV
- Homebrew Channel and webOSbrew
- Root SSH access to the TV
- A Unix-like development environment with Git, `ssh`, and `scp`
- An XML parser and JSON parser for validation

## Repository layout

```text
webos10-customhome/
├── overrides/                 # files you edit
│   ├── home.xml
│   ├── home_layoutShelfView.xml
│   ├── i18n/
│   └── images/                # optional
├── scripts/                   # commands run on the development machine
│   ├── pull-stock.sh
│   ├── build.sh
│   ├── deploy.sh
│   ├── activate.sh
│   ├── verify.sh
│   └── rollback.sh
├── src/
│   └── customhome.sh          # runs on the TV
└── .build/                    # generated and ignored by Git
```

By default, a local stock snapshot is stored beside the repository:

```text
parent-directory/
├── webos10-customhome/
└── webos10-customhome-stock/
    ├── home.xml
    ├── home_layoutShelfView.xml
    ├── home_lg.xml
    ├── home_senior.xml
    ├── home_wee.xml
    ├── i18n/
    ├── i18n_0/
    ├── images/
    └── mock/
```

The exact contents vary by TV and software version.

Set `STOCK_DIR` when running `pull-stock.sh` to use a different location.

This snapshot is an editing reference, not a build requirement or recovery backup.
LG's originals remain untouched on the TV, and `rollback.sh` reveals them by
removing the overlay. Activation reads the complete locale set directly from
the TV. The snapshot's banner images are starting points for artwork overrides.

The complete snapshot is for local reference; it is not copied wholesale into
the OverlayFS upper layer. Builds include only the two supported XML files,
customised locale JSON files, supported banner overrides, and the activation script.

## Setup

Clone or download the repository, then run the following commands from its
root directory.

### 1. Configure SSH

The scripts use the SSH host `lg-tv` by default. A typical SSH configuration
entry is:

```sshconfig
Host lg-tv
    HostName tv-address-or-ip
    User root
```

Test the connection:

```sh
ssh lg-tv
```

To use another SSH host without changing the scripts:

```sh
TV=other-tv ./scripts/verify.sh
```

### 2. Create the local stock snapshot

Run this before making changes to capture the complete Home asset tree for
reference. Building existing overrides does not require a snapshot:

```sh
./scripts/pull-stock.sh
```

It reads:

```text
/usr/palm/applications/com.webos.app.home/data/flutter_assets/assets/
/mnt/lg/wee/ui_l10n/usr/palm/applications/com.webos.app.home/data/flutter_assets/assets/i18n/
```

The script does not modify these paths. It also:

- refuses to overwrite existing stock files;
- refuses to copy assets while the Custom Home overlay is active;
- replaces the snapshot's absolute `i18n` symlink with a real locale directory;
- stages downloads and removes incomplete snapshots after a failure; and
- creates initial XML files under `overrides/` when they do not exist.

Rerunning the command against an older valid snapshot adds files and directories
that are missing from it. Existing XML, locales, images, and symlinks are never
replaced.

To choose another stock location:

```sh
STOCK_DIR=/path/to/stock ./scripts/pull-stock.sh
```

### 3. Add locales to customise

Only modified locale files belong in `overrides/i18n/`. Copy one from the stock
snapshot with its exact filename:

```sh
cp ../webos10-customhome-stock/i18n/en_GB.json overrides/i18n/
```

## Edit and validate

Edit files under `overrides/`, never the stock snapshot or LG's original
directories.

Compare an override with its stock version:

```sh
diff -u ../webos10-customhome-stock/home.xml overrides/home.xml
```

Validate XML:

```sh
xmllint --noout overrides/home.xml
xmllint --noout overrides/home_layoutShelfView.xml
```

Validate a locale with any JSON parser, for example:

```sh
python3 -m json.tool overrides/i18n/en_GB.json >/dev/null
```

Syntax validation cannot prove that Home supports a particular layout change;
the TV must still be tested visually.

## Build, deploy, and activate

The usual development cycle is:

```sh
./scripts/deploy.sh
./scripts/activate.sh
./scripts/verify.sh
```

`deploy.sh` runs the build automatically. To build without contacting the TV:

```sh
./scripts/build.sh
```

The generated deployment is placed in:

```text
.build/tld.my.customhome/
├── customhome.sh
└── assets/
    ├── home.xml
    ├── home_layoutShelfView.xml
    ├── i18n/                # customised JSON files only; may be empty
    └── images/              # present only when overridden
```

Deployment uses a staging directory on the TV and keeps the previous deployed
version at:

```text
/media/developer/apps/usr/palm/applications/tld.my.customhome.previous
```

Deploying copies files but does not activate them. `activate.sh` mounts the
merged view and restarts Home. `verify.sh` then checks the OverlayFS mount, both
XML files, the real upper-layer `i18n` directory, every deployed locale, and
each deployed banner override.

## Rollback and recovery

Use rollback whenever a layout fails, Home behaves incorrectly, or you want to
return temporarily to the unmodified interface:

```sh
./scripts/rollback.sh
```

For a TV configured under another SSH host:

```sh
TV=other-tv ./scripts/rollback.sh
```

The script:

1. checks for an OverlayFS mount over the Home assets;
2. unmounts it, stopping Home and retrying if the mount is busy;
3. confirms that the overlay has gone; and
4. restarts Home against LG's original files.

Rollback does not copy files from the local stock snapshot. It also does not:

- modify or delete LG's original files;
- delete the deployment under `/media/developer/`;
- discard anything under `overrides/`; or
- disable automatic startup.

The deployed customisation can therefore be enabled again with:

```sh
./scripts/activate.sh
./scripts/verify.sh
```

After rollback, `verify.sh` is expected to fail until the overlay is activated
again because its purpose is to verify the custom deployment.

A reboot also clears the temporary runtime overlay. If automatic startup is
enabled, the overlay will be applied again during boot. For a persistent
rollback, disable the startup link and then run `rollback.sh` or reboot.

## Automatic startup

Enable this only after manual activation and verification work reliably.

```sh
ssh lg-tv \
    'ln -sf /media/developer/apps/usr/palm/applications/tld.my.customhome/customhome.sh /var/lib/webosbrew/init.d/49-custom-homescreen'
```

Disable it with:

```sh
ssh lg-tv \
    'rm -f /var/lib/webosbrew/init.d/49-custom-homescreen'
```

Then reboot or run `./scripts/rollback.sh`.

## Safety boundaries

Project scripts write only to these TV locations:

```text
/media/developer/apps/usr/palm/applications/tld.my.customhome/
/media/developer/apps/usr/palm/applications/tld.my.customhome.new
/media/developer/apps/usr/palm/applications/tld.my.customhome.previous
/tmp/weboshome-overlay-upper/
/tmp/weboshome-overlay-work/
```

The optional automatic-startup command manages this link:

```text
/var/lib/webosbrew/init.d/49-custom-homescreen
```

The scripts read from, but never write into:

```text
/usr/palm/applications/com.webos.app.home/
/mnt/lg/wee/
```

No operation in this project needs to write to a raw storage device such as
`/dev/mmcblk0p*`.

## How locale overrides work

LG's original `i18n` entry is a symlink into another read-only filesystem. A
real `i18n` directory in the OverlayFS upper layer hides that symlink rather
than merging individual files through it.

The build uploads only edited JSON files from `overrides/i18n/`. On activation,
after unmounting any previous overlay, the script copies the TV's current stock
locale tree into `/tmp/weboshome-overlay-upper/i18n/`, then applies those edits.
The original locale files are only read; all changes stay in the temporary tree.

Customised JSON files still replace whole locale files, not individual keys.
After a firmware update, review those files for new or changed translations.

## Script reference

| Script | Runs on | Purpose |
| --- | --- | --- |
| `scripts/pull-stock.sh` | Development machine | Capture the complete pristine asset tree |
| `scripts/build.sh` | Development machine | Assemble a complete deployment |
| `scripts/deploy.sh` | Development machine | Build and stage files on the TV |
| `scripts/activate.sh` | Development machine | Run the deployed OverlayFS script |
| `scripts/verify.sh` | Development machine | Verify the active XML, locales, and banners |
| `scripts/rollback.sh` | Development machine | Remove the runtime overlay |
| `src/customhome.sh` | TV | Create the OverlayFS mount and restart Home |

## Notes

- BusyBox tools on webOS may support fewer options than GNU utilities.
- A valid XML document can still contain a layout that Home cannot render.
- The original guide (webOS 10.2.2, EU) reports that app icon size is hardcoded
  in `libapp.so`, and AppList `option` values such as `webOS24` are ignored.
  Changing row dimensions should not be assumed to resize app icons.
- That guide also reports that the clock in the senior section of `home_lg.xml`
  does not render outside its layout context. These observations may vary
  with firmware.
- Runtime changes are temporary unless automatic startup is enabled.

## Credits

Based on the original webOS 10 Home-screen customisation work and subsequent
testing of OverlayFS and BusyBox-compatible asset handling on rooted LG TVs.
