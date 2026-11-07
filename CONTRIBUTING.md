# Contributing to photo_gallery_pro

Thank you for your interest in contributing! Please read this guide before
opening a pull request.

## Development setup

- Flutter `>=3.22.0` (stable). The CI pins `3.47.7`.
- Run `flutter pub get` before anything else.

## Workflow

1. Fork the repository and create a feature branch from `main`.
2. Make your change, keeping the method-channel contract in
   `plan.md` Appendix B as the source of truth for cross-platform behavior.
3. Before pushing, run the same gates as CI:
   ```sh
   dart format --set-exit-if-changed .
   flutter analyze
   flutter test
   flutter pub publish --dry-run
   ```
4. Open a PR describing the change, the platform(s) affected, and whether
   you tested on a real device/emulator. Aim for one phase per PR.

## Code conventions

- Every public symbol needs a `///` doc comment (enforced by
  `public_member_api_docs` in `analysis_options.yaml`).
- No `print` in `lib/` — use `debugPrint` guarded by `kDebugMode`.
- New native methods must be added on **all** supported platforms
  (Android, iOS, Linux) or documented as platform-specific in the README.
- Update `CHANGELOG.md` with an entry referencing your PR.

## Reporting bugs

Use the issue templates in `.github/ISSUE_TEMPLATE/`. Include the platform,
OS version, plugin version, and any Flutter error output.

## Reporting security issues

See `SECURITY.md`. Please do not open public issues for security reports.
