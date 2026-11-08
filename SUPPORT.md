# Support

## Supported versions

| Version | Supported |
|---------|-----------|
| `1.x` (current) | ✅ Bug fixes + security updates |
| `0.2.x` | ⚠️ Critical security fixes only |
| `< 0.2.0` | ❌ Upgrade to `1.x` (see `MIGRATION.md`) |

## Platforms

Android (API 21+), iOS (16+), and Linux (GTK 3) are supported.
macOS, Windows, and web are not yet supported — see `plan.md` §12.11.

## Getting help

- **Bugs / feature requests:** [GitHub issues](https://github.com/binkapS/photo_gallery_pro/issues)
  — include the plugin version, Flutter/Dart versions, platform + OS version,
  and a minimal reproduction.
- **Security issues:** see `SECURITY.md` (do not open a public issue).
- **Contributing:** see `CONTRIBUTING.md`.

## Before you file an issue

1. Confirm you are on the latest `1.x` release.
2. Check `README.md` → Troubleshooting (permissions, scoped storage,
   iCloud-only media, Limited photo access).
3. Run the example app — if it reproduces there, it is a plugin bug;
   if not, it is likely host-app configuration (manifest / Info.plist).
