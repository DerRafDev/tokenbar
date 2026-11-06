# Releasing

TokenBar uses [Semantic Versioning](https://semver.org). While in `0.x`, minor
versions may contain breaking changes.

## Version source of truth

`apps/macos/Config/Version.xcconfig` holds `MARKETING_VERSION` (e.g. `0.2.0`, shown as
the app version) and `CURRENT_PROJECT_VERSION` (build number, always increasing). The
release workflow refuses a tag that does not match `MARKETING_VERSION`, so the tag and
the app can never disagree.

## Steps

```sh
git switch -c chore/release-0.2.0
scripts/bump-version.sh 0.2.0                 # sets the version, increments the build number
$EDITOR docs/release-notes/v0.2.0.md          # user-facing notes for the GitHub Release
git commit -am "chore(release): prepare TokenBar 0.2.0"
# open PR → CI green → merge
git switch main && git pull
scripts/test-update.sh build                  # in-app update test, see below
gh workflow run release.yml --ref main        # dry run: review its artifact, see below
# run the manual checklist: docs/release-checklist.md
git tag v0.2.0 && git push origin v0.2.0
```

The [Release workflow](../.github/workflows/release.yml) then runs:

```text
build:          verify tag → tests → archive → sign (app + Sparkle) → notarize app → staple → zip + dmg → sign + notarize dmg → EdDSA-sign zip → appcast.xml → SHA256SUMS → upload dist/ artifact
draft-release:  download that artifact → draft GitHub Release
```

It creates a **draft**. Its notes come from `docs/release-notes/<tag>.md` (GitHub's
generated notes when that file is missing). Review the draft and its artifacts, then
publish it on GitHub. Nothing is published automatically.

**Publishing is what ships the update.** Installed copies read
`releases/latest/download/appcast.xml`, which is the `appcast.xml` attached to the latest
published, non-prerelease GitHub Release. A draft or a pre-release is invisible to them;
the moment you publish (as latest), every TokenBar that checks for updates is offered it.

GitHub Releases are the changelog; there is no separate `CHANGELOG.md`.

## Dry run: build a release without publishing

Running the Release workflow by hand (`workflow_dispatch`) runs the same `build` job as a tag
push, with the same secrets and the same `scripts/release.sh`, and stops after uploading
`dist/` as an Actions artifact. It creates no tag and no release, and does not change the
update feed (installed copies only read releases that are published). The job has a
read-only token; only the tag-only `draft-release` job can write to the repository.

**Before you can run it:**

- The workflow file with `workflow_dispatch` must be on the **default branch** (`main`).
  GitHub offers *Run workflow* and accepts `gh workflow run` only for workflows that exist
  there. Once it is merged, you can run it on any branch or tag; the run uses the workflow
  file and the code of the ref you choose. Until then, not even this branch can trigger it.
- The ref must have `SPARKLE_PUBLIC_ED_KEY` set, and the `SPARKLE_PRIVATE_KEY` secret must
  exist; otherwise the run fails, as a tag release would.

**Run it**, either in the browser (*Actions › Release › Run workflow*, pick the branch, *Run
workflow*) or:

```sh
gh workflow run release.yml --ref main         # or a release branch
gh run watch "$(gh run list --workflow release.yml --limit 1 --json databaseId -q '.[0].databaseId')"
```

The run summary shows the version and commit it built (`Building TokenBar 0.2.0 from main
(abc1234)`), and the artifact `TokenBar-<version>-<commit>`, kept for 14 days.

**Download and check it:**

```sh
run=$(gh run list --workflow release.yml --limit 1 --json databaseId -q '.[0].databaseId')
gh run download "$run" -D review/              # unpacks to review/TokenBar-<version>-<commit>/
cd review/TokenBar-*/
ls                                             # TokenBar-<v>[-unsigned].zip, .dmg, appcast.xml, SHA256SUMS.txt
shasum -a 256 -c SHA256SUMS.txt                # zip and dmg match their checksums
xmllint --noout appcast.xml                    # well-formed
grep -E 'sparkle:(version|shortVersionString|minimumSystemVersion)|enclosure' appcast.xml
```

In `appcast.xml`, check:

- `sparkle:shortVersionString` is the version, and `sparkle:version` the build number, both
  higher than the release currently published.
- The `enclosure` URL is
  `https://github.com/DerRafDev/tokenbar/releases/download/v<version>/<the zip's file name>`.
  It only resolves once that release is published; a 404 now is expected.
- `length` equals `stat -f %z TokenBar-<version>*.zip`.
- The release notes in `<description>` are `docs/release-notes/v<version>.md`.

Then check the zip's signature, and that the app inside trusts your production key:

```sh
bin=~/Documents/programming/tokenbar/build/SourcePackages/artifacts/sparkle/Sparkle/bin
sig=$(sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p' appcast.xml)
$bin/sign_update --verify TokenBar-*.zip "$sig"      # uses the key in your Keychain; silent on success
ditto -x -k TokenBar-*.zip app/
plutil -extract SUPublicEDKey raw app/TokenBar.app/Contents/Info.plist   # = $bin/generate_keys -p
plutil -extract SUFeedURL raw app/TokenBar.app/Contents/Info.plist      # the public feed
codesign --verify --deep --strict --verbose=2 app/TokenBar.app
```

With Developer ID and notarization configured, also `spctl -a -vv app/TokenBar.app`
(`source=Notarized Developer ID`) and `xcrun stapler validate app/TokenBar.app`.

A dry run proves the pipeline and the inputs, but the tag push builds again, so the draft's
files are new bytes (new signatures and timestamps). Check the draft's `appcast.xml` the
same way before publishing.

## Secrets

Configure in *Settings → Secrets and variables → Actions*. The signing and notarization
secrets are optional: without them the release is ad-hoc signed, its artifacts are suffixed `-unsigned`, and the draft
is marked prerelease. macOS Gatekeeper blocks unsigned apps on first launch.

To ship an unsigned build as the main release (as 0.1.0 does), untick *Set as a
pre-release* and tick *Set as the latest release* before publishing the draft. GitHub's
`/releases/latest` link, used by the README, skips pre-releases.

| Secret | Purpose |
|---|---|
| `DEVELOPER_ID_CERT_P12_BASE64` | Developer ID Application certificate + private key, exported as `.p12`, base64-encoded |
| `DEVELOPER_ID_CERT_PASSWORD` | Password of that `.p12` |
| `DEVELOPER_ID_IDENTITY` | Full identity name, e.g. `Developer ID Application: Jane Doe (ABCDE12345)` |
| `APPLE_TEAM_ID` | Team ID, e.g. `ABCDE12345` |
| `NOTARY_KEY_P8_BASE64` | App Store Connect API key (`.p8`, role *Developer*), base64-encoded |
| `NOTARY_KEY_ID` | Key ID of that API key |
| `NOTARY_ISSUER_ID` | Issuer ID from App Store Connect → Users and Access → Integrations |
| `SPARKLE_PRIVATE_KEY` | **Required.** EdDSA private key that signs updates (see [Sparkle](#sparkle-in-app-updates)) |

Encode files with `base64 -i file.p12 | pbcopy`. Never commit them. The Developer ID and
notary secrets are optional; `SPARKLE_PRIVATE_KEY` is not: without it the workflow stops
before building, because a release without a signed appcast could not be installed by the
updater.

Getting them requires a paid Apple Developer Program membership: create a *Developer ID
Application* certificate in Xcode (Settings → Accounts → Manage Certificates) or the
developer portal and export it with its private key from Keychain Access; create the API
key in App Store Connect.

Signing matters beyond Gatekeeper: macOS ties Keychain *Always Allow* to the code
signature. Developer ID builds keep Claude's Keychain permission across updates; ad-hoc
builds ask again after every update.

## Building a release locally

```sh
scripts/release.sh           # ad-hoc signed, output in dist/
```

Export the same variables as the table above (with `NOTARY_KEY_PATH` pointing at the
`.p8` file) to sign and notarize locally. Requires Xcode 26 or later (the app icon is an
Icon Composer file). Locally, the Sparkle key is read from your login Keychain, so
`SPARKLE_PRIVATE_KEY` is not needed there.

## Sparkle (in-app updates)

TokenBar updates itself with [Sparkle 2](https://sparkle-project.org), added through Swift
Package Manager to the app target. The user opens the gear menu, chooses **Check for
Updates…**, and Sparkle's standard dialogs do the rest (release notes, download, **Install
and Relaunch**). There are no background checks.

| Piece | Where |
|---|---|
| Feed URL | `SPARKLE_FEED_URL` in `apps/macos/Config/TokenBar.xcconfig`: `https://github.com/DerRafDev/tokenbar/releases/latest/download/appcast.xml` |
| Public key | `SPARKLE_PUBLIC_ED_KEY` in the same file, written to `SUPublicEDKey` |
| Other Sparkle settings | `apps/macos/Config/Info.plist` (merged into the generated Info.plist) |
| Update archive | `TokenBar-<version>[-unsigned].zip`, the same zip users can download |
| Appcast | `dist/appcast.xml`, written by `scripts/appcast.sh`, one item: the new version, its EdDSA signature, minimum macOS, and `docs/release-notes/v<version>.md` as Markdown |
| Private key | Your login Keychain (local) and the `SPARKLE_PRIVATE_KEY` Actions secret. **Never** in the repository. |

`scripts/release.sh` signs the zip, then checks the signature against the public key inside
the app it just built, and stops if they are not a pair. It also refuses to build while
`SPARKLE_PUBLIC_ED_KEY` is empty.

### One-time setup: the signing key

```sh
xcodebuild -resolvePackageDependencies -project apps/macos/TokenBar.xcodeproj \
    -clonedSourcePackagesDirPath build/SourcePackages
bin=build/SourcePackages/artifacts/sparkle/Sparkle/bin

$bin/generate_keys                    # creates the key in your login Keychain, prints the public key
$bin/generate_keys -x sparkle-key.txt # exports the private key to a file, for the secret
```

1. Put the printed public key in `SPARKLE_PUBLIC_ED_KEY` (`TokenBar.xcconfig`) and commit it.
   It is not a secret.
2. Paste the contents of `sparkle-key.txt` into the `SPARKLE_PRIVATE_KEY` Actions secret,
   then delete the file (`rm -P sparkle-key.txt`).
3. Back up the Keychain item *Private key for signing Sparkle updates* (for example in your
   password manager). **If the key is lost, installed copies can never be updated again**:
   users would have to install the next version by hand. Sparkle can rotate keys only while
   the Apple code signing identity stays the same, which ad-hoc builds do not have.

### Signing, notarization and the first updater release

What the project has today: the pipeline signs with Developer ID, uses the hardened runtime,
notarizes and staples the app and the DMG, but only when the secrets exist. None are
configured and this Mac has no Developer ID identity, so 0.1.0 and any release built now is
ad-hoc signed (`-unsigned`).

The updater works either way. Sparkle accepts an update when its EdDSA signature matches,
even if the Apple signing identity changes, so going from an ad-hoc build to a Developer ID
build later is a normal update. Ad-hoc builds carry one extra entitlement,
`com.apple.security.cs.disable-library-validation` (`Config/TokenBar-AdHoc.entitlements`),
because the hardened runtime otherwise refuses to load Sparkle.framework without a Team ID;
Developer ID builds do not need it and do not get it. Sparkle removes the quarantine flag
from what it installs, so an unsigned update does not go through *Open Anyway* again, but
macOS asks again for Claude's Keychain item after each unsigned update.

What is missing to ship the first version with the updater:

- [ ] `SPARKLE_PUBLIC_ED_KEY` committed and `SPARKLE_PRIVATE_KEY` secret set (above). Required.
- [ ] Optional but recommended: the Developer ID and notary secrets. With them, the release
      script re-signs Sparkle's helpers (`Autoupdate`, `Updater.app`, the XPC services) with
      the Developer ID and the hardened runtime, as notarization requires. This path cannot be
      tested without a certificate; check the first notarized release's log.
- [ ] Release notes for the version, telling 0.1.0 users to install it by hand (README ›
      Updating).
- [ ] An unsigned draft is marked pre-release; untick that and tick *Set as the latest release*
      before publishing, or the feed keeps pointing at the previous release.

### Testing an update locally

`scripts/test-update.sh` runs the real release script twice with test settings: versions
0.90.0 and 0.91.0, bundle ID `io.github.derrafdev.TokenBar.updatetest` (your TokenBar
preferences are not touched), a throwaway EdDSA key, and a feed on
`http://127.0.0.1:8765`. Nothing is published and no real key is used.

```sh
scripts/test-update.sh build                 # ~3 min; everything goes to build/update-test/
scripts/test-update.sh serve                 # in a second terminal; keep it running
scripts/test-update.sh install               # installs and opens 0.90.0
defaults write io.github.derrafdev.TokenBar.updatetest menuBarDisplay detailed
```

Quit and reopen the test app (from `build/update-test/Installed/`) so it reads that
preference. A second TokenBar icon appears in the menu bar; it is the test copy. Then:

1. **Update.** Gear menu › **Check for Updates…** → the dialog offers 0.91.0 with the test
   notes → **Install Update** → **Install and Relaunch**. TokenBar reopens;
   `plutil -extract CFBundleShortVersionString raw build/update-test/Installed/TokenBar.app/Contents/Info.plist`
   says `0.91.0`, and `defaults read io.github.derrafdev.TokenBar.updatetest` still has
   `menuBarDisplay = detailed`.
2. **No update.** `scripts/test-update.sh install`, `scripts/test-update.sh feed none`,
   check again → "You're up to date!".
3. **Bad signature.** `scripts/test-update.sh install`, `scripts/test-update.sh feed bad-signature`,
   check, **Install Update** → Sparkle refuses ("The update is improperly signed…") and
   0.90.0 stays installed.

`scripts/test-update.sh feed update` restores the good feed. `scripts/test-update.sh clean`
quits the test app and deletes it with its preferences.

To test the actual release candidate instead of the test builds, build it with
`scripts/release.sh` and check that `dist/appcast.xml` has the right version, download URL
and notes, and that `sign_update --verify dist/TokenBar-<version>.zip <signature>` passes.
