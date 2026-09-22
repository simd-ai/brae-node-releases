#!/bin/sh
# brae-node installer.
#
#   curl -fsSL https://api.brae.sh/node.sh | sh
#
# Downloads the agent for this machine's architecture, checks it against the published SHA-256, and installs
# it to /usr/local/bin/brae-node. It does not register anything and it starts no service: run
# `brae-node init` and then `brae-node join --token <TOKEN>` yourself, so nothing touches the network until
# you ask it to.
#
# Optional overrides:
#   BRAE_NODE_VERSION   release tag to install (default: latest)
#   PREFIX              install prefix (default: /usr/local)
set -eu

REPO="${BRAE_NODE_REPO:-simd-ai/brae-node-releases}"
PREFIX="${PREFIX:-/usr/local}"
BINDIR="$PREFIX/bin"

if [ -t 1 ]; then B=$(printf '\033[1m'); G=$(printf '\033[32m'); Y=$(printf '\033[33m'); N=$(printf '\033[0m')
else B=''; G=''; Y=''; N=''; fi
say()  { printf '%s==>%s %s\n' "$G$B" "$N" "$*"; }
warn() { printf '%s!! %s%s\n' "$Y$B" "$*" "$N" >&2; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

[ "$(uname -s)" = "Linux" ] || die "brae-node runs on Linux; this is $(uname -s)."
case "$(uname -m)" in
    x86_64)  TARGET=x86_64-unknown-linux-gnu ;;
    aarch64) TARGET=aarch64-unknown-linux-gnu ;;
    *) die "unsupported architecture $(uname -m) (x86_64 and aarch64 are published)" ;;
esac

have curl || have wget || die "need curl or wget"
fetch() { # url -> stdout
    if have curl; then curl -fsSL "$1"; else wget -qO- "$1"; fi
}

VERSION="${BRAE_NODE_VERSION:-}"
if [ -z "$VERSION" ]; then
    say "finding the latest release"
    VERSION=$(fetch "https://api.github.com/repos/$REPO/releases/latest" \
        | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
    [ -n "$VERSION" ] || die "could not determine the latest release of $REPO"
fi
BASE="https://github.com/$REPO/releases/download/$VERSION"

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT INT TERM
say "downloading brae-node $VERSION for $TARGET"
fetch "$BASE/brae-node-$TARGET" > "$TMP/brae-node" || die "download failed: $BASE/brae-node-$TARGET"
fetch "$BASE/SHA256SUMS" > "$TMP/SHA256SUMS" || die "could not download the checksums"

# Verify before anything is installed. A binary that will run as a service on your machine is not something
# to take on trust from a redirect.
expected=$(sed -n "s/^\([0-9a-f]\{64\}\)[[:space:]][[:space:]]*brae-node-$TARGET$/\1/p" "$TMP/SHA256SUMS" | head -n1)
[ -n "$expected" ] || die "no checksum published for brae-node-$TARGET"
if have sha256sum; then actual=$(sha256sum "$TMP/brae-node" | cut -d' ' -f1)
elif have shasum;   then actual=$(shasum -a 256 "$TMP/brae-node" | cut -d' ' -f1)
else die "need sha256sum or shasum to verify the download"; fi
[ "$actual" = "$expected" ] || die "checksum mismatch: refusing to install
  expected $expected
  actual   $actual"
say "checksum verified"

SUDO=''
if [ "$(id -u)" -ne 0 ]; then
    have sudo || die "need root (or sudo) to install into $BINDIR; set PREFIX=\$HOME/.local to install for yourself"
    SUDO=sudo
fi
$SUDO mkdir -p "$BINDIR"
$SUDO install -m 0755 "$TMP/brae-node" "$BINDIR/brae-node"
say "installed $BINDIR/brae-node ($("$BINDIR/brae-node" --version 2>/dev/null || echo 'version unknown'))"

case ":$PATH:" in
    *":$BINDIR:"*) ;;
    *) warn "$BINDIR is not on your PATH" ;;
esac

if ! [ -e /dev/nvidiactl ]; then
    warn "no NVIDIA device found on this machine — brae-node init will tell you what is missing"
fi

cat <<EOF

${B}brae-node is installed.${N} Two steps, neither of which sends anything yet:

    brae-node init                      look at this machine, create its identity
    brae-node join --token <TOKEN>      join the network with the token from app.brae.sh

EOF
