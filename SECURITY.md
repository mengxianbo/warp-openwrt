# Security policy

## Reporting a vulnerability

Please do not publish working exploits, WARP device credentials, private keys,
or unredacted configuration files in public issues.

Report security issues privately through GitHub's
[private vulnerability reporting](https://github.com/mengxianbo/warp-openwrt/security/advisories/new)
when available. If that feature is unavailable, contact the repository
maintainer through the GitHub profile.

## Sensitive files and data

Never commit or share:

- /etc/usque/config.json
- WARP device credentials, private keys, registration tokens, or account data
- Proxy usernames/passwords
- Unredacted system logs or network captures that contain secrets

The package stores device configuration on the router. Protect it with
restrictive file permissions and keep proxy ports off untrusted networks.
