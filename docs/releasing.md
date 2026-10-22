# Releasing

TokenBar uses [Semantic Versioning](https://semver.org). While in `0.x`, minor
versions may contain breaking changes.

## Version source of truth

`apps/macos/Config/Version.xcconfig` holds `MARKETING_VERSION` (e.g. `0.2.0`) and
`CURRENT_PROJECT_VERSION` (build number, always increasing). The release workflow
refuses a tag that does not match `MARKETING_VERSION`.

## Steps

```sh
git switch -c chore/release-0.2.0
scripts/bump-version.sh 0.2.0
git commit -am "chore: release 0.2.0"
# open PR → CI green → merge
git switch main && git pull
git tag v0.2.0 && git push origin v0.2.0
```

The [Release workflow](../.github/workflows/release.yml) then runs:

```text
verify tag → tests → archive → sign → notarize → zip + dmg → SHA256SUMS → draft GitHub Release
```

Review the draft release notes on GitHub and publish.

## Secrets

Configure in *Settings → Secrets and variables → Actions*. All are optional: without
them the release is ad-hoc signed, suffixed `-unsigned`, and marked prerelease.

| Secret | Purpose |
|---|---|
| `DEVELOPER_ID_CERT_P12_BASE64` | Developer ID Application certificate + private key, exported as `.p12`, base64-encoded |
| `DEVELOPER_ID_CERT_PASSWORD` | Password of that `.p12` |
| `DEVELOPER_ID_IDENTITY` | Full identity name, e.g. `Developer ID Application: Jane Doe (ABCDE12345)` |
| `APPLE_TEAM_ID` | Team ID, e.g. `ABCDE12345` |
| `NOTARY_KEY_P8_BASE64` | App Store Connect API key (`.p8`, role *Developer*), base64-encoded |
| `NOTARY_KEY_ID` | Key ID of that API key |
| `NOTARY_ISSUER_ID` | Issuer ID from App Store Connect → Users and Access → Integrations |

Encode files with `base64 -i file.p12 | pbcopy`.

## Building a release locally

```sh
scripts/release.sh           # ad-hoc signed, output in dist/
```

Export the same variables as the table above (with `NOTARY_KEY_PATH` pointing at the
`.p8` file) to sign and notarize locally.
