# Contributing

Thank you for considering a contribution to OpenWrt Cloudflare WARP MASQUE.

## Scope

- Keep this package focused on Cloudflare WARP MASQUE / Connect-IP.
- Preserve the default SOCKS5 port (32500) and HTTP CONNECT port (32511)
  unless a change is explicitly discussed.
- Keep LuCI user-facing text in Simplified Chinese and update documentation
  when behavior or installation steps change.
- Do not add WireGuard-based WARP functionality to this project.

## Before submitting

1. Explain the problem and the proposed change.
2. Test shell scripts with `sh -n` and validate Lua syntax where tooling is available.
3. Build the IPK using the repository workflow or `scripts/build-ipk.sh`.
4. Verify that no credentials, private keys, device configuration, or personal
   logs are included.

## Pull requests

Keep changes focused, describe the OpenWrt version and architecture tested,
include relevant logs with secrets redacted, and update README documentation.
