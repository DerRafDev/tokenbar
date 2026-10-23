# Contributing to TokenBar

Thanks for helping. TokenBar aims to stay small, native, and easy to read, so
please keep changes focused.

## Before you start

- For anything bigger than a bug fix, open an issue first so we can agree on the
  approach.
- New providers: read [docs/adding-a-provider.md](docs/adding-a-provider.md) and
  [docs/providers.md](docs/providers.md). Document the data source **before**
  writing the code.
- New dependencies need a strong reason. Foundation, SwiftUI, and AppKit usually
  cover what we need.

## Workflow

```text
feature branch → pull request → CI green → review → squash merge into main
```

1. Branch from `main` (`feat/…`, `fix/…`, `docs/…`).
2. Run `scripts/lint.sh` and `scripts/test.sh` locally.
3. Open a pull request. Fill in the template.
4. CI must pass. A maintainer reviews and squash-merges.

## Commit messages

[Conventional Commits](https://www.conventionalcommits.org/):

```text
feat(provider): add Gemini support
fix(menubar): truncate label when many providers are enabled
test(provider): add Claude response fixtures
docs: explain refresh policy
ci: cache SwiftPM build
```

Types: `feat`, `fix`, `refactor`, `perf`, `test`, `docs`, `ci`, `chore`. Since PRs are
squash-merged, the **PR title** becomes the commit message and must follow this format.

## Code style

- `swift format` (bundled with Xcode) is the formatter and linter. Its configuration
  is in [.swift-format](.swift-format). Run `scripts/format.sh` before committing.
- Swift 6 language mode with strict concurrency.
- Follow the module rules in [docs/architecture.md](docs/architecture.md). In
  particular, `TokenBarUI` must not import `TokenBarProviders`.
- User-facing text is English in code (`String(localized:bundle: .module)`) with a
  Portuguese (Brazil) translation in `TokenBarUI/Resources/pt-BR.lproj/Localizable.strings`.
  Plain `.strings` files are used instead of a String Catalog because SwiftPM's
  command-line build on Xcode 26 does not compile catalogs.

## Tests

- Logic changes need unit tests in `apps/macos/TokenBarKit/Tests`.
- Provider tests use **sanitized** fixtures only: no tokens, cookies, emails, or
  account/organization IDs. CI never talks to a real account.

## Definition of done

- Builds without warnings and passes `scripts/lint.sh` and `scripts/test.sh`.
- Errors are handled, not ignored.
- No secrets in code, fixtures, or logs.
- Docs are updated when behavior or architecture changes.

## Maintainers: repository settings

Protect `main` (Settings → Rules → Rulesets):

- Require a pull request before merging (1 approval once there is more than one
  maintainer).
- Require these status checks to pass: **`Lint`**, **`Build & Test`**, **`PR Title`**.
- Require branches to be up to date before merging.
- Block force pushes and deletions.
- Allow squash merging only.

## Code of conduct

This project follows the [Code of Conduct](CODE_OF_CONDUCT.md).
