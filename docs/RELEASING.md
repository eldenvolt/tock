# Releasing

This repository uses GitHub Actions to build and publish an unsigned macOS DMG when a version tag is pushed.

The local steps exist to sanity-check the build. The CI artifact is the canonical release users receive.

## Prerequisites

- Xcode installed.
- `Tock` scheme is shared in Xcode (Xcode → Manage Schemes → Shared).
- GitHub CLI (`gh`) for creating/editing release notes from the terminal.

## Development

Open `Tock.xcodeproj`, select the `Tock` scheme, and run from Xcode.

## Pre-release (local)

Run a local DMG build to catch obvious issues before tagging a release.

1. Build the unsigned app and DMG.

     ```bash
     cd /path/to/tock
     rm -rf build dist
     mkdir -p dist
     VERSION="$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//')"
     xcodebuild -scheme Tock -configuration Release -destination 'generic/platform=macOS' -derivedDataPath build CODE_SIGNING_ALLOWED=NO MARKETING_VERSION="${VERSION}"
     ./scripts/make-dmg.sh "build/Build/Products/Release/Tock.app" "dist/Tock.dmg"
     ```

2. Install: open `dist/Tock.dmg` and drag `Tock.app` to `/Applications`.
3. Verify: launch the app and test core behavior, notifications, settings, and shortcuts.

## Publish a release (CI)

1. Commit and push all release changes.
2. Create and push a lightweight tag with the next sequential version number.
   - `git tag v0.1.0`
   - `git push origin v0.1.0`
3. A GitHub Release is created automatically by CI and is named after the tag.
4. Add or update release notes.
   - `gh release edit v0.1.0 --notes $'Highlights:\n- First item\n- Second item'`
   - If you see “release not found”, wait for CI to finish.
5. Download and install the DMG from the GitHub Release.
   - This DMG is the **exact artifact users receive**.
   - If macOS blocks launch:  
     `xattr -dr com.apple.quarantine /Applications/Tock.app`

### If CI fails after tagging

1. Delete the bad tag locally and remotely.
   - `git tag -d v0.1.0 || true && git push origin :v0.1.0`
2. Fix the issue.
3. Re-tag and push again.

## Post-release usage

Use the app installed from the GitHub Release in `/Applications`.

To update, download and reinstall the latest DMG from the Releases page.
