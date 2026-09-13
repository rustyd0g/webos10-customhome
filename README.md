# webOS 10 Custom Home

Customise the LG webOS 10 / webOS25 Home screen without modifying LG's original read-only system files.

This project uses **OverlayFS** to present customised Home assets over the original LG files. Development is done locally, custom files are version-controlled in Git, and pristine files copied from the TV are kept separately outside the repository.

> **Requirements**
>
> * Rooted LG webOS TV
> * Homebrew Channel / webOSbrew
> * SSH access to the TV
> * macOS or Linux development machine
> * Git
> * `scp` and `ssh`
> * VS Code is optional

---

# How It Works

The LG Home application's Flutter assets are located at:

```text
/usr/palm/applications/com.webos.app.home/data/flutter_assets/assets/
```

These files are on LG's read-only system filesystem.

This project does **not** modify them.

Instead, it creates an OverlayFS mount:

```text
LG original Home assets
        +
temporary custom upper layer
        |
        v
merged Home assets
```

Files supplied by this project replace the corresponding LG files in the merged view.

Anything not replaced continues to come directly from LG's original filesystem.

The underlying system files remain unchanged.

---

# Project Structure

The recommended local layout is:

```text
~/Projects/
├── webos10-customhome/                  # Git repository
│   ├── README.md
│   ├── LICENSE
│   ├── src/
│   │   └── apply.sh
│   ├── overrides/
│   │   ├── home.xml
│   │   ├── home_layoutShelfView.xml
│   │   ├── i18n/
│   │   │   └── en_GB.json
│   │   └── images/
│   │       ├── hd/
│   │       ├── 2k/
│   │       └── 4k/
│   ├── scripts/
│   │   ├── pull-stock.sh
│   │   ├── add-locale.sh
│   │   ├── build.sh
│   │   ├── deploy.sh
│   │   ├── apply.sh
│   │   ├── verify.sh
│   │   └── rollback.sh
│   └── .build/                          # generated, ignored by Git
│
└── webos10-customhome-stock/            # pristine LG files, not Git
    ├── home.xml
    ├── home_layoutShelfView.xml
    └── i18n/
        ├── en_GB.json
        ├── en_US.json
        ├── de_DE.json
        └── ...
```

There are therefore three distinct layers:

```text
webos10-customhome-stock
        ↓
pristine LG source files

webos10-customhome
        ↓
your version-controlled customisations

TV /media/developer/...
        ↓
deployed runtime files
```

---

# Repository Branch

Development can be kept on a dedicated branch:

```text
customhome
```

For example:

```sh
git switch customhome
```

The fork's `main` branch can then remain available for tracking upstream changes.

---

# Initial Mac Setup

Create a projects directory:

```sh
mkdir -p ~/Projects
cd ~/Projects
```

Clone the repository:

```sh
git clone git@github.com:rustyd0g/webos10-customhome.git
cd webos10-customhome
```

Switch to the development branch:

```sh
git switch customhome
```

If the branch does not yet exist locally:

```sh
git switch -c customhome
git push -u origin customhome
```

---

# SSH Configuration

It is convenient to give the TV an SSH alias.

Edit:

```text
~/.ssh/config
```

and add:

```text
Host lg-tv
    HostName 192.168.30.122
    User root
```

Test it:

```sh
ssh lg-tv
```

All project scripts use `lg-tv` by default.

The target can be overridden for an individual command with:

```sh
TV=some-other-host ./scripts/deploy.sh
```

---

# Stock Files

Pristine files copied from the TV are stored outside Git at:

```text
~/Projects/webos10-customhome-stock/
```

These are reference files and should not normally be edited.

The repository contains the files you actually customise under:

```text
overrides/
```

---

# Scripts

The `scripts/` directory contains the local development and deployment tools.

Typical workflow:

```text
pull-stock.sh
      ↓
add-locale.sh
      ↓
edit overrides/
      ↓
build.sh
      ↓
deploy.sh
      ↓
apply.sh
      ↓
verify.sh
```

If something goes wrong:

```text
rollback.sh
```

---

## `scripts/pull-stock.sh`

### Purpose

Copies the pristine Home files from the TV to:

```text
~/Projects/webos10-customhome-stock/
```

It retrieves:

```text
home.xml
home_layoutShelfView.xml
i18n/
```

It also creates the initial editable XML copies:

```text
overrides/home.xml
overrides/home_layoutShelfView.xml
```

### Usage

Run once during initial setup:

```sh
./scripts/pull-stock.sh
```

### Remote sources

The XML files are read from:

```text
/usr/palm/applications/com.webos.app.home/data/flutter_assets/assets/
```

The complete locale set is read from:

```text
/mnt/lg/wee/ui_l10n/usr/palm/applications/com.webos.app.home/data/flutter_assets/assets/i18n/
```

These are only read.

Nothing at either LG path is modified.

### Safety

The script refuses to overwrite an existing stock snapshot.

If:

```text
~/Projects/webos10-customhome-stock/
```

already contains the stock files, `pull-stock.sh` exits instead of replacing them.

This prevents accidentally replacing your known-good reference copy.

### Custom stock location

The default location can be changed:

```sh
STOCK_DIR=/some/other/path ./scripts/pull-stock.sh
```

---

## `scripts/add-locale.sh`

### Purpose

Copies a single locale from the pristine stock directory into:

```text
overrides/i18n/
```

This allows only the locale files you actually customise to be stored in Git.

### Example

LG uses underscore-based locale filenames.

For British English:

```sh
./scripts/add-locale.sh en_GB.json
```

This creates:

```text
overrides/i18n/en_GB.json
```

You can then edit it normally.

### Important

Use the exact filename present on your TV.

For example:

```text
en_GB.json
```

not:

```text
en-GB.json
```

To see available English locales:

```sh
ls -1 ~/Projects/webos10-customhome-stock/i18n | grep '^en'
```

### Safety

`add-locale.sh` refuses to overwrite a locale override that already exists.

If:

```text
overrides/i18n/en_GB.json
```

already exists, the script exits instead of replacing your modifications.

---

## `scripts/build.sh`

### Purpose

Creates a complete deployment tree locally.

The result is:

```text
.build/tld.my.customhome/
```

The `.build/` directory is generated and should be ignored by Git.

### Why a build step is required

The original Home `i18n` entry is a symlink.

When the custom OverlayFS upper layer contains a real directory named:

```text
i18n/
```

that directory shadows the original lower-layer symlink completely.

Therefore the deployed `i18n` directory must contain the **complete locale set**, not only the locales you modified.

`build.sh` handles this automatically.

### Build process

It:

1. creates a clean `.build/tld.my.customhome/`
2. copies `src/apply.sh`
3. copies your custom XML files
4. copies every pristine LG locale from the external stock directory
5. overlays any custom locales from `overrides/i18n/`
6. includes optional banner images if they exist

The result is approximately:

```text
.build/tld.my.customhome/
├── apply.sh
└── assets/
    ├── home.xml
    ├── home_layoutShelfView.xml
    ├── i18n/
    │   ├── all stock locale files
    │   └── custom versions replacing selected locales
    └── images/
        └── optional custom banners
```

### Usage

```sh
./scripts/build.sh
```

### Important

Do not manually edit files under:

```text
.build/
```

They are generated and will be deleted on the next build.

Edit:

```text
overrides/
```

instead.

---

## `scripts/deploy.sh`

### Purpose

Builds the project and safely copies it to the TV.

### Usage

```sh
./scripts/deploy.sh
```

You do **not** need to run `build.sh` first.

`deploy.sh` automatically runs:

```text
build.sh
```

before uploading anything.

### Remote deployment location

The active deployment is stored at:

```text
/media/developer/apps/usr/palm/applications/tld.my.customhome/
```

### Staged deployment

Files are initially uploaded to:

```text
/media/developer/apps/usr/palm/applications/tld.my.customhome.new
```

Only after the upload succeeds is the directory moved into the active location.

This avoids leaving a partially uploaded deployment in place.

### Previous deployment

The previous version is retained as:

```text
/media/developer/apps/usr/palm/applications/tld.my.customhome.previous
```

This provides an additional recovery copy of the previous deployment.

### Important

Deploying does **not** enable the custom Home screen.

It only copies the files.

Run:

```sh
./scripts/apply.sh
```

after deployment to activate them.

---

## `scripts/apply.sh`

### Purpose

Runs the deployed TV-side OverlayFS script.

### Usage

```sh
./scripts/apply.sh
```

This executes:

```text
/media/developer/apps/usr/palm/applications/tld.my.customhome/apply.sh
```

on the TV over SSH.

The Home app is restarted after the overlay is mounted.

---

## `src/apply.sh`

This is different from:

```text
scripts/apply.sh
```

The distinction is important.

### `scripts/apply.sh`

Runs **on your Mac** and tells the TV to start the deployment.

### `src/apply.sh`

Runs **on the TV** and actually creates the OverlayFS mount.

During the build process:

```text
src/apply.sh
```

becomes:

```text
.build/tld.my.customhome/apply.sh
```

and is then deployed to:

```text
/media/developer/apps/usr/palm/applications/tld.my.customhome/apply.sh
```

---

# TV-side OverlayFS Process

The TV-side `apply.sh` defines:

```text
ASSETS_DIR
/usr/palm/applications/com.webos.app.home/data/flutter_assets/assets

OVERRIDE_DIR
/media/developer/apps/usr/palm/applications/tld.my.customhome/assets

UPPER_DIR
/tmp/weboshome-overlay-upper

WORK_DIR
/tmp/weboshome-overlay-work
```

It then:

1. validates the required files
2. removes any existing Home OverlayFS mount
3. recreates the temporary upper and work directories
4. copies the custom XML files into the upper layer
5. copies the complete built `i18n` tree
6. copies optional banner images if supplied
7. mounts OverlayFS over the original Home assets path
8. restarts `com.webos.app.home`

The original LG filesystem remains unchanged.

---

## `scripts/verify.sh`

### Purpose

Checks that the customisation is actually active.

### Usage

```sh
./scripts/verify.sh
```

The script checks:

* an overlay is mounted over the Home asset directory
* the active `home.xml` matches the deployed custom version
* the active `home_layoutShelfView.xml` matches the deployed version
* the merged `i18n` directory exists

Typical successful output contains:

```text
=== Overlay mount ===
...

=== home.xml ===
OK

=== home_layoutShelfView.xml ===
OK

=== i18n ===
OK
```

A successful verification should still be followed by checking the Home screen visually.

---

## `scripts/rollback.sh`

### Purpose

Immediately removes the Home OverlayFS mount.

### Usage

```sh
./scripts/rollback.sh
```

This:

```text
unmounts the OverlayFS
        ↓
restarts the Home app
        ↓
reveals LG's original Home assets again
```

It does **not** delete:

```text
/media/developer/apps/usr/palm/applications/tld.my.customhome/
```

so your deployed files remain available for further testing.

A reboot also removes the runtime overlay because the OverlayFS upper and work directories are under `/tmp`.

---

# Editing the Home Layout

Your editable layout files are:

```text
overrides/home.xml
overrides/home_layoutShelfView.xml
```

Do not edit the copies under:

```text
~/Projects/webos10-customhome-stock/
```

and do not edit the LG originals under:

```text
/usr/palm/applications/com.webos.app.home/
```

---

# Comparing Custom and Stock XML

To inspect your changes:

```sh
diff -u \
    ~/Projects/webos10-customhome-stock/home.xml \
    overrides/home.xml
```

Or using VS Code:

```sh
code --diff \
    ~/Projects/webos10-customhome-stock/home.xml \
    overrides/home.xml
```

For the second layout file:

```sh
code --diff \
    ~/Projects/webos10-customhome-stock/home_layoutShelfView.xml \
    overrides/home_layoutShelfView.xml
```

---

# Validate XML Before Deployment

macOS includes `xmllint`.

Validate:

```sh
xmllint --noout overrides/home.xml
```

and:

```sh
xmllint --noout overrides/home_layoutShelfView.xml
```

No output means the XML parser found no syntax error.

This does not guarantee that the layout is semantically valid for LG Home, but it catches malformed XML before deployment.

---

# Localisation

Only locales that you modify need to exist under:

```text
overrides/i18n/
```

For example:

```sh
./scripts/add-locale.sh en_GB.json
```

Then edit:

```text
overrides/i18n/en_GB.json
```

Validate the JSON:

```sh
python3 -m json.tool \
    overrides/i18n/en_GB.json \
    >/dev/null
```

No output means the JSON parsed successfully.

---

# Changing Home Text

Strings displayed by Home can be changed in the appropriate locale file.

For a UK-configured TV this will commonly be:

```text
overrides/i18n/en_GB.json
```

For example, a string can be replaced or changed to an empty string.

Always edit the copy under:

```text
overrides/i18n/
```

rather than the pristine stock version.

---

# Optional Banner Images

Banner replacement is optional.

If no banner override exists, OverlayFS uses LG's original image automatically.

Supported override paths are:

```text
overrides/images/hd/bg_banner_img.png
overrides/images/2k/bg_banner_img.png
overrides/images/4k/bg_banner_img.png
```

You may provide only the resolution you require.

For example:

```text
overrides/images/4k/bg_banner_img.png
```

will replace only the 4K version.

The HD and 2K files continue to come from LG's original assets.

Create the directory only if required:

```sh
mkdir -p overrides/images/4k
```

Then copy your image into:

```text
overrides/images/4k/bg_banner_img.png
```

The next build will include it automatically.

---

# Removing Unwanted Home Elements

Edit:

```text
overrides/home.xml
```

For example, to remove the recommendation shelf:

```sh
sed -i '' '/<item id="recommendedShelf"/d' overrides/home.xml
```

On GNU/Linux the equivalent is normally:

```sh
sed -i '/<item id="recommendedShelf"/d' overrides/home.xml
```

To remove the Q-Card list:

```sh
sed -i '' '/<item id="qcardList"/d' overrides/home.xml
```

Be careful when changing the overall Home structure.

Removing some elements completely may cause the Home application to fail.

---

# Global Navigation

The `globalline` item controls the global navigation area.

Removing the element completely can cause problems.

A safer way of hiding it is to retain the item but set:

```xml
itemWidth="0"
itemHeight="0"
```

---

# Development Workflow

Once initial setup is complete, the normal workflow is:

```sh
cd ~/Projects/webos10-customhome
code .
```

Edit:

```text
overrides/
```

Then validate the files.

For example:

```sh
xmllint --noout overrides/home.xml
xmllint --noout overrides/home_layoutShelfView.xml
```

If modifying British English:

```sh
python3 -m json.tool \
    overrides/i18n/en_GB.json \
    >/dev/null
```

Review changes:

```sh
git diff
```

Deploy:

```sh
./scripts/deploy.sh
```

Apply:

```sh
./scripts/apply.sh
```

Verify:

```sh
./scripts/verify.sh
```

Then inspect the TV visually.

---

# Development Cycle

The complete cycle is:

```text
edit overrides/
       ↓
validate XML / JSON
       ↓
git diff
       ↓
deploy.sh
       ↓
build.sh runs automatically
       ↓
deployment copied to TV
       ↓
apply.sh
       ↓
OverlayFS enabled
       ↓
Home restarts
       ↓
verify.sh
       ↓
visual test
```

If the result is bad:

```sh
./scripts/rollback.sh
```

Then make another local change and repeat.

---

# Git Workflow

Review:

```sh
git status
git diff
```

Then commit your custom files and tooling:

```sh
git add \
    src \
    scripts \
    overrides \
    README.md \
    .gitignore
```

Commit:

```sh
git commit -m "Update custom Home configuration"
```

Push:

```sh
git push
```

Generated files under:

```text
.build/
```

should not be committed.

Pristine LG files under:

```text
~/Projects/webos10-customhome-stock/
```

are outside the Git repository entirely.

---

# Generated Build Directory

The build directory is:

```text
.build/tld.my.customhome/
```

It is temporary.

A typical result is:

```text
.build/tld.my.customhome/
├── apply.sh
└── assets/
    ├── home.xml
    ├── home_layoutShelfView.xml
    ├── i18n/
    │   ├── en_AM.json
    │   ├── en_AU.json
    │   ├── en_CA.json
    │   ├── en_GB.json
    │   ├── ...
    │   └── en.json
    └── images/
        └── ... optional overrides
```

The complete locale set comes from:

```text
~/Projects/webos10-customhome-stock/i18n/
```

Custom locales from:

```text
overrides/i18n/
```

replace their stock equivalents during the build.

---

# Enabling Automatic Startup

Do this only after manual deployment and testing are working reliably.

Create the webOSbrew init link:

```sh
ssh lg-tv \
    'ln -sf /media/developer/apps/usr/palm/applications/tld.my.customhome/apply.sh /var/lib/webosbrew/init.d/49-custom-homescreen'
```

Verify:

```sh
ssh lg-tv \
    'ls -l /var/lib/webosbrew/init.d/49-custom-homescreen'
```

Then reboot:

```sh
ssh lg-tv reboot
```

After the TV comes back:

```sh
./scripts/verify.sh
```

---

# Disabling Automatic Startup

Remove the startup link:

```sh
ssh lg-tv \
    'rm -f /var/lib/webosbrew/init.d/49-custom-homescreen'
```

Then either reboot:

```sh
ssh lg-tv reboot
```

or remove the active runtime overlay:

```sh
./scripts/rollback.sh
```

---

# Recovery

The customisation does not overwrite LG's original Home assets.

If Home becomes unusable:

```sh
./scripts/rollback.sh
```

or reboot:

```sh
ssh lg-tv reboot
```

Because:

```text
/tmp/weboshome-overlay-upper
/tmp/weboshome-overlay-work
```

are temporary, the runtime overlay disappears after reboot.

LG's original Home assets become visible again.

If autostart itself is causing a problem, remove:

```text
/var/lib/webosbrew/init.d/49-custom-homescreen
```

before the next normal boot where possible.

---

# Why OverlayFS?

An earlier approach copied the complete Flutter asset tree into `/tmp` and bind-mounted the resulting directory over the original assets.

OverlayFS avoids that unnecessary copy.

It provides:

* fewer filesystem reads
* less temporary RAM use
* faster application
* clear separation between stock and custom files
* automatic fallback to LG files that are not overridden
* straightforward optional image overrides
* simple reboot rollback

Only files that genuinely need replacement are placed in the upper layer.

---

# The `i18n` Symlink

This is an important implementation detail.

The original:

```text
/usr/palm/applications/com.webos.app.home/data/flutter_assets/assets/i18n
```

is a symlink into another read-only LG filesystem.

OverlayFS cannot merge individual custom files through that lower-layer symlink in the way it can merge ordinary directories.

The project therefore builds a complete real `i18n` directory for the upper layer.

That is why:

```text
overrides/i18n/
```

contains only your changed locale files, while:

```text
.build/.../assets/i18n/
```

contains every locale.

---

# BusyBox Compatibility

webOS uses BusyBox implementations of many Unix tools.

Do not assume GNU-specific command options are available on the TV.

For example, older approaches used:

```text
cp -R --no-dereference
```

which is not appropriate to assume on BusyBox.

The TV-side script uses:

```sh
cp -a
```

for its recursive locale copy.

The complete original Flutter asset tree is not copied at all.

---

# Files That Are Safe to Work With

Project deployment:

```text
/media/developer/apps/usr/palm/applications/tld.my.customhome/
```

Temporary OverlayFS runtime:

```text
/tmp/weboshome-overlay-upper/
/tmp/weboshome-overlay-work/
```

webOSbrew startup link:

```text
/var/lib/webosbrew/init.d/49-custom-homescreen
```

---

# Files That Should Not Be Modified Directly

Do not directly edit LG's Home files under:

```text
/usr/palm/applications/com.webos.app.home/
```

Do not directly edit locale source files under:

```text
/mnt/lg/wee/
```

Do not write to raw eMMC devices such as:

```text
/dev/mmcblk0p*
```

This project requires none of those operations.

---

# Summary of Scripts

| Script                  | Runs on | Purpose                                            |
| ----------------------- | ------- | -------------------------------------------------- |
| `scripts/pull-stock.sh` | Mac     | Pull pristine XML and locale files from the TV     |
| `scripts/add-locale.sh` | Mac     | Add one stock locale to Git for customisation      |
| `scripts/build.sh`      | Mac     | Build a complete deployable tree                   |
| `scripts/deploy.sh`     | Mac     | Build and safely upload the deployment to the TV   |
| `scripts/apply.sh`      | Mac     | Tell the TV to activate the deployed customisation |
| `scripts/verify.sh`     | Mac     | Verify the active OverlayFS and custom XML         |
| `scripts/rollback.sh`   | Mac     | Remove the runtime overlay and restore stock Home  |
| `src/apply.sh`          | TV      | Create the actual OverlayFS mount and restart Home |

---

# Quick Reference

Initial setup:

```sh
./scripts/pull-stock.sh
./scripts/add-locale.sh en_GB.json
```

Edit:

```text
overrides/home.xml
overrides/home_layoutShelfView.xml
overrides/i18n/en_GB.json
```

Validate:

```sh
xmllint --noout overrides/home.xml
xmllint --noout overrides/home_layoutShelfView.xml

python3 -m json.tool \
    overrides/i18n/en_GB.json \
    >/dev/null
```

Deploy and test:

```sh
./scripts/deploy.sh
./scripts/apply.sh
./scripts/verify.sh
```

Rollback:

```sh
./scripts/rollback.sh
```

Commit:

```sh
git status
git diff
git add .
git commit -m "Update custom Home configuration"
git push
```

---

# Notes

* XML structures may vary between TV models, regions and webOS versions.
* Always retain a pristine stock snapshot from the TV being customised.
* Test manually before enabling autostart.
* A syntactically valid XML file can still contain a layout that LG Home cannot render correctly.
* Banner overrides are optional.
* Individual banner resolutions can be overridden independently.
* Locale filenames use LG's naming, for example `en_GB.json`.
* The complete locale set is assembled automatically at build time.
* The original LG Home application remains untouched.
* Rebooting removes the temporary OverlayFS runtime state.
* Icon sizing may be hardcoded in the Home application's Flutter binary rather than controlled by XML.

---

# Credits

Based on the original webOS 10 Home-screen customisation work and subsequent testing of OverlayFS and BusyBox-compatible handling on rooted LG webOS TVs.
