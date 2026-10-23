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
# run the manual checklist: docs/release-checklist.md
git tag v0.2.0 && git push origin v0.2.0
```

The [Release workflow](../.github/workflows/release.yml) then runs:

```text
verify tag → tests → archive → sign → notarize app → staple → zip + dmg → sign + notarize dmg → SHA256SUMS → draft GitHub Release
```

It creates a **draft**. Its notes come from `docs/release-notes/<tag>.md` (GitHub's
generated notes when that file is missing). Review the draft and its artifacts, then
publish it on GitHub. Nothing is published automatically.

GitHub Releases are the changelog; there is no separate `CHANGELOG.md`.

## Secrets

Configure in *Settings → Secrets and variables → Actions*. All are optional: without
them the release is ad-hoc signed, its artifacts are suffixed `-unsigned`, and the draft
is marked prerelease. macOS Gatekeeper blocks unsigned apps on first launch.

| Secret | Purpose |
|---|---|
| `DEVELOPER_ID_CERT_P12_BASE64` | Developer ID Application certificate + private key, exported as `.p12`, base64-encoded |
| `DEVELOPER_ID_CERT_PASSWORD` | Password of that `.p12` |
| `DEVELOPER_ID_IDENTITY` | Full identity name, e.g. `Developer ID Application: Jane Doe (ABCDE12345)` |
| `APPLE_TEAM_ID` | Team ID, e.g. `ABCDE12345` |
| `NOTARY_KEY_P8_BASE64` | App Store Connect API key (`.p8`, role *Developer*), base64-encoded |
| `NOTARY_KEY_ID` | Key ID of that API key |
| `NOTARY_ISSUER_ID` | Issuer ID from App Store Connect → Users and Access → Integrations |

Encode files with `base64 -i file.p12 | pbcopy`. Never commit them.

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
Icon Composer file).
