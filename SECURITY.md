# Security Policy

## Supported versions

Security fixes are applied to the latest release line.

## Reporting a vulnerability

Please do not open a public issue for security vulnerabilities.

Report them privately by email to the maintainer listed in the repository
profile, or use GitHub's private vulnerability reporting if it is enabled.

Include:

- Affected plugin and scanner versions
- Description of the issue
- Reproduction steps or proof of concept
- Potential impact

## Download security

The plugin downloads the scanner JAR from a pinned GitHub Release URL:

- HTTPS is required by the default URL.
- The version is pinned by default.
- The download is written to a temporary file.
- The SHA-256 checksum from `<jar-url>.sha256` is verified.
- The file is moved into place atomically only after verification.
- The previous valid JAR is kept when an update fails.

If you need stricter supply-chain controls, configure `scanner.jar` with a
locally audited build and disable `scanner.auto_download`.
