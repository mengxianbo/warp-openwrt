# Third-party notices

This repository builds an OpenWrt package around the following upstream
software. The notices below identify upstream projects; they do not imply
endorsement or affiliation.

## usque

- Project: https://github.com/Diniboy1123/usque
- Version used by the GitHub Actions workflow: v3.0.1
- Purpose: Cloudflare WARP MASQUE / Connect-IP client
- License: MIT
- Copyright: © 2025 Diniboy1123

The upstream MIT license text is preserved in [LICENSES/usque-MIT.txt](LICENSES/usque-MIT.txt).
The build workflow compiles usque from its upstream source; it does not vendor
or modify the usque source code in this repository.

usque itself depends on other Go modules. Their respective copyright and
license terms remain applicable. Consult the upstream usque repository and its
dependency metadata for the complete dependency/license inventory.

## OpenWrt and LuCI

This package targets OpenWrt and integrates with LuCI. OpenWrt, LuCI, Lua,
and any runtime libraries remain subject to their own respective licenses.
This repository does not relicense those components.

## Cloudflare

Cloudflare and WARP are trademarks and services of Cloudflare, Inc. This is
an independent, unofficial community project and is not affiliated with,
endorsed by, or sponsored by Cloudflare.
