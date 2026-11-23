#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
STAGE="$ROOT/build/root"
CONTROL="$ROOT/build/control"
VERSION="1.1.2"
PKG="warp-masque"
ARCH="x86_64"

command -v tar >/dev/null 2>&1 || { echo "tar is required" >&2; exit 1; }
test -x "$ROOT/usque" || { echo "usque binary missing" >&2; exit 1; }

rm -rf "$ROOT/build"
mkdir -p "$STAGE/usr/bin" "$STAGE/etc/config" "$STAGE/etc/init.d" \
  "$STAGE/usr/lib/lua/luci/controller" "$STAGE/usr/lib/lua/luci/model/cbi/warp" \
  "$STAGE/usr/share/rpcd/acl.d" "$STAGE/usr/share/licenses/$PKG" "$CONTROL"

install -m 0755 "$ROOT/usque" "$STAGE/usr/bin/usque"
install -m 0755 "$ROOT/files/usr/bin/warpctl" "$STAGE/usr/bin/warpctl"
install -m 0755 "$ROOT/files/usr/bin/warp-route" "$STAGE/usr/bin/warp-route"
install -m 0755 "$ROOT/files/etc/init.d/warp" "$STAGE/etc/init.d/warp"
install -m 0644 "$ROOT/files/etc/config/warp" "$STAGE/etc/config/warp"
install -m 0644 "$ROOT/files/usr/lib/lua/luci/controller/warp.lua" "$STAGE/usr/lib/lua/luci/controller/warp.lua"
install -m 0644 "$ROOT/files/usr/lib/lua/luci/model/cbi/warp/main.lua" "$STAGE/usr/lib/lua/luci/model/cbi/warp/main.lua"
install -m 0644 "$ROOT/files/usr/share/rpcd/acl.d/luci-app-warp.json" "$STAGE/usr/share/rpcd/acl.d/luci-app-warp.json"

# Include the project license and upstream client license in every binary package.
test -s "$ROOT/LICENSE" || { echo "project LICENSE missing" >&2; exit 1; }
test -s "$ROOT/LICENSES/usque-MIT.txt" || { echo "usque license missing" >&2; exit 1; }
test -s "$ROOT/THIRD_PARTY_NOTICES.md" || { echo "third-party notices missing" >&2; exit 1; }
test -s "$ROOT/go-dependency-licenses/GO_DEPENDENCY_LICENSES.csv" || { echo "Go dependency license report missing" >&2; exit 1; }
test -d "$ROOT/go-dependency-licenses" || { echo "Go dependency license directory missing" >&2; exit 1; }
install -m 0644 "$ROOT/LICENSE" "$STAGE/usr/share/licenses/$PKG/LICENSE"
install -m 0644 "$ROOT/LICENSES/usque-MIT.txt" "$STAGE/usr/share/licenses/$PKG/usque-MIT.txt"
install -m 0644 "$ROOT/THIRD_PARTY_NOTICES.md" "$STAGE/usr/share/licenses/$PKG/THIRD_PARTY_NOTICES.md"
mkdir -p "$STAGE/usr/share/licenses/$PKG/go-dependencies"
cp -R "$ROOT/go-dependency-licenses/." "$STAGE/usr/share/licenses/$PKG/go-dependencies/"

cat > "$CONTROL/control" <<EOF
Package: $PKG
Version: $VERSION-1
Depends: libc, luci-base, luci-compat, ca-bundle, ip-full
Architecture: $ARCH
License: MIT
Section: net
Priority: optional
Maintainer: mengxianbo
Description: Cloudflare WARP MASQUE SOCKS5 and HTTP proxy with LuCI
EOF
cat > "$CONTROL/conffiles" <<EOF
/etc/config/warp
EOF

(
  cd "$CONTROL"
  tar --numeric-owner --owner=0 --group=0 -czf "$ROOT/build/control.tar.gz" .
)
(
  cd "$STAGE"
  tar --numeric-owner --owner=0 --group=0 -czf "$ROOT/build/data.tar.gz" .
)
printf '2.0\n' > "$ROOT/build/debian-binary"
tar -czf "$ROOT/${PKG}_${VERSION}-1_${ARCH}.ipk" -C "$ROOT/build" ./debian-binary ./control.tar.gz ./data.tar.gz
echo "Created ${ROOT}/${PKG}_${VERSION}-1_${ARCH}.ipk"
