# Security Policy

## Supported versions

| Version | Supported |
| ------- | --------- |
| 1.0.x   | ✅ (current stable) |
| 0.2.x   | bug-fix only |
| < 0.2.0 | ❌ |

## Reporting a vulnerability

Please report security vulnerabilities **privately**. Do not open a
public GitHub issue for a suspected vulnerability.

- Open a private advisory at
  <https://github.com/binkapS/photo_gallery_pro/security/advisories/new>,
  or
- Email the maintainer via the repository's public contact information.

Include: affected version, platform/OS, and a minimal reproduction if
possible. Reports that include a proof-of-concept are prioritized.

## Response timeline

- Acknowledgment: within 3 business days
- Triage and fix plan: within 14 days

This plugin is read-only by design (no write/delete operations), and
original-byte loading is scoped to user-initiated requests; please
report any pathway that bypasses the system photo-library permission
model.
