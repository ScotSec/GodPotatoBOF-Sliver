#!/bin/bash
#
# install.sh - Build GodPotato BOF and install into Sliver
#
# Usage:
#   ./install.sh           Fetch deps + build + install
#   ./install.sh build     Build only
#   ./install.sh install   Install only (assumes already built)
#   ./install.sh fetch     Fetch boflink + apt deps only
#   ./install.sh clean     Remove build artifacts and installed extension
#
# Environment overrides:
#   BOFLINK_VERSION   Pin a specific boflink version (e.g. v0.6.2). Default: latest
#   BOFLINK_TARGET    Override the release target triple
#                     (default: x86_64-unknown-linux-musl, fallback: -gnu)
#   NO_APT=1          Skip auto-install of apt packages
#   NO_FETCH=1        Skip auto-fetch of boflink

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SLIVER_EXT_DIR="$HOME/.sliver-client/extensions"
EXT_NAME="godpotato"
SRC_DIR="$SCRIPT_DIR/sliver-extensions/$EXT_NAME"
DST_DIR="$SLIVER_EXT_DIR/$EXT_NAME"

BOFLINK_REPO="MEhrn00/boflink"
BOFLINK_VERSION="${BOFLINK_VERSION:-latest}"
BOFLINK_TARGET="${BOFLINK_TARGET:-}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

banner() {
    echo ""
    echo -e "${CYAN}  +----------------------------------------------+${NC}"
    echo -e "${CYAN}  |${BOLD}        GodPotato BOF - Build & Install        ${NC}${CYAN}|${NC}"
    echo -e "${CYAN}  |           Sliver C2 Extension Packager       |${NC}"
    echo -e "${CYAN}  +----------------------------------------------+${NC}"
    echo ""
}

# --- apt deps -----------------------------------------------------------------

apt_missing() {
    local missing=()
    if ! command -v x86_64-w64-mingw32-gcc &>/dev/null; then missing+=("mingw-w64"); fi
    if ! command -v i686-w64-mingw32-gcc   &>/dev/null; then missing+=("mingw-w64"); fi
    if ! command -v make                   &>/dev/null; then missing+=("make"); fi
    # Dedupe
    printf "%s\n" "${missing[@]}" | sort -u | tr '\n' ' '
}

install_apt_deps() {
    local pkgs
    pkgs=$(apt_missing)
    pkgs=$(echo -n "$pkgs" | xargs)  # trim
    if [ -z "$pkgs" ]; then
        echo -e "${GREEN}  [+] Compiler deps OK${NC}"
        return 0
    fi

    if [ "${NO_APT:-0}" = "1" ]; then
        echo -e "${RED}  [!] Missing apt packages: $pkgs${NC}"
        echo -e "${YELLOW}      NO_APT=1 set, skipping auto-install${NC}"
        echo -e "${YELLOW}      Install manually: ${BOLD}sudo apt install $pkgs${NC}"
        return 1
    fi

    if ! command -v apt-get &>/dev/null; then
        echo -e "${RED}  [!] Missing: $pkgs${NC}"
        echo -e "${YELLOW}      apt-get not found on this system; install the equivalents manually${NC}"
        return 1
    fi

    echo -e "${YELLOW}  [~] Installing apt packages: $pkgs${NC}"
    local SUDO=""
    if [ "$(id -u)" -ne 0 ]; then
        if ! command -v sudo &>/dev/null; then
            echo -e "${RED}  [!] Not root and sudo unavailable; cannot install packages${NC}"
            return 1
        fi
        SUDO="sudo"
    fi

    DEBIAN_FRONTEND=noninteractive $SUDO apt-get update -qq
    # shellcheck disable=SC2086  # intentional: word-split package list
    DEBIAN_FRONTEND=noninteractive $SUDO apt-get install -y --no-install-recommends $pkgs
    echo -e "${GREEN}  [+] apt deps installed${NC}"
}

# --- boflink ------------------------------------------------------------------

pick_boflink_target() {
    if [ -n "$BOFLINK_TARGET" ]; then
        echo "$BOFLINK_TARGET"
        return
    fi
    local arch
    arch="$(uname -m)"
    case "$arch" in
        x86_64|amd64) echo "x86_64-unknown-linux-musl" ;;
        aarch64|arm64) echo "aarch64-unknown-linux-musl" ;;
        *) echo "x86_64-unknown-linux-musl" ;;
    esac
}

fetch_boflink() {
    if [ "${NO_FETCH:-0}" = "1" ]; then
        echo -e "${YELLOW}  [~] NO_FETCH=1 set, skipping boflink download${NC}"
        return 1
    fi

    if ! command -v curl &>/dev/null; then
        echo -e "${RED}  [!] curl not found, required to fetch boflink${NC}"
        return 1
    fi

    local target tag api_url
    target=$(pick_boflink_target)
    if [ "$BOFLINK_VERSION" = "latest" ]; then
        api_url="https://api.github.com/repos/${BOFLINK_REPO}/releases/latest"
    else
        tag="$BOFLINK_VERSION"
        api_url="https://api.github.com/repos/${BOFLINK_REPO}/releases/tags/${tag}"
    fi

    echo -e "${BOLD}  Fetching boflink (${target})...${NC}"

    local release_json
    release_json=$(curl -fsSL -H "Accept: application/vnd.github+json" "$api_url") || {
        echo -e "${RED}  [!] Failed to query GitHub releases API${NC}"
        return 1
    }

    # Pull the tag name for logging
    tag=$(echo "$release_json" | grep -oP '"tag_name"\s*:\s*"\K[^"]+' | head -n1)
    echo -e "${CYAN}  [*] Release: ${tag:-unknown}${NC}"

    # Find an asset URL matching our target. Prefer .tar.gz, fall back to .zip.
    local asset_url
    asset_url=$(echo "$release_json" \
        | grep -oP '"browser_download_url"\s*:\s*"\K[^"]+' \
        | grep -E "${target}\.(tar\.gz|tgz)$" \
        | head -n1)

    # Fallback: try the gnu target if musl isn't published
    if [ -z "$asset_url" ] && [ -z "$BOFLINK_TARGET" ]; then
        local gnu_target="${target/-musl/-gnu}"
        echo -e "${YELLOW}  [~] No ${target} asset, trying ${gnu_target}${NC}"
        asset_url=$(echo "$release_json" \
            | grep -oP '"browser_download_url"\s*:\s*"\K[^"]+' \
            | grep -E "${gnu_target}\.(tar\.gz|tgz)$" \
            | head -n1)
        target="$gnu_target"
    fi

    if [ -z "$asset_url" ]; then
        echo -e "${RED}  [!] No matching release asset found for ${target}${NC}"
        echo -e "${YELLOW}      Available assets:${NC}"
        echo "$release_json" | grep -oP '"name"\s*:\s*"\K[^"]+' | grep -E '^boflink' | sed 's/^/      - /'
        return 1
    fi

    # Optional matching sha256 sidecar if the release ships one
    local sha_url
    sha_url=$(echo "$release_json" \
        | grep -oP '"browser_download_url"\s*:\s*"\K[^"]+' \
        | grep -E "${target}\.(tar\.gz|tgz)\.sha256$" \
        | head -n1)

    local tmp
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' RETURN

    local archive="$tmp/boflink.tar.gz"
    echo -e "${CYAN}  [*] ${asset_url##*/}${NC}"
    curl -fsSL -o "$archive" "$asset_url" || {
        echo -e "${RED}  [!] Download failed (HTTP error)${NC}"
        return 1
    }

    # Sanity check: make sure we got a real archive, not an HTML error page
    if ! file "$archive" 2>/dev/null | grep -qiE 'gzip|tar archive'; then
        echo -e "${RED}  [!] Downloaded file is not a tarball:${NC}"
        file "$archive" 2>/dev/null | sed 's/^/      /'
        return 1
    fi

    if ! command -v sha256sum &>/dev/null; then
        echo -e "${RED}  [!] sha256sum not available, cannot verify download${NC}"
        echo -e "${YELLOW}      Install coreutils, or set NO_FETCH=1 and place boflink manually${NC}"
        return 1
    fi

    if [ -z "$sha_url" ]; then
        echo -e "${RED}  [!] No .sha256 sidecar published for this asset; refusing to install unverified binary${NC}"
        echo -e "${YELLOW}      Asset: ${asset_url##*/}${NC}"
        echo -e "${YELLOW}      Verify manually and place at $SCRIPT_DIR/boflink, or pin a release that ships sha256s via BOFLINK_VERSION${NC}"
        return 1
    fi

    echo -e "${CYAN}  [*] Verifying sha256...${NC}"
    local sha_file="$tmp/boflink.sha256"
    if ! curl -fsSL -o "$sha_file" "$sha_url"; then
        echo -e "${RED}  [!] Failed to download sha256 sidecar from:${NC}"
        echo -e "      $sha_url"
        return 1
    fi

    local expected actual
    expected=$(awk '{print $1}' "$sha_file")
    actual=$(sha256sum "$archive" | awk '{print $1}')

    if [ -z "$expected" ]; then
        echo -e "${RED}  [!] sha256 sidecar was empty or malformed${NC}"
        return 1
    fi

    if [ "$expected" != "$actual" ]; then
        echo -e "${RED}  [!] sha256 MISMATCH -- aborting${NC}"
        echo -e "      expected: $expected"
        echo -e "      actual:   $actual"
        return 1
    fi

    echo -e "${GREEN}  [+] sha256 OK${NC}"
    echo -e "      ${BOLD}${expected}${NC}"
    echo -e "      (matches ${asset_url##*/}.sha256)"

    tar -xzf "$archive" -C "$tmp"
    local found
    found=$(find "$tmp" -type f -name boflink | head -n1)
    if [ -z "$found" ]; then
        echo -e "${RED}  [!] boflink binary not found inside archive${NC}"
        return 1
    fi

    install -m 0755 "$found" "$SCRIPT_DIR/boflink"
    echo -e "${GREEN}  [+] boflink installed to $SCRIPT_DIR/boflink${NC}"
}

# --- dep check ----------------------------------------------------------------

check_deps() {
    install_apt_deps

    if [ ! -x "$SCRIPT_DIR/boflink" ]; then
        echo -e "${YELLOW}  [~] boflink not present, fetching...${NC}"
        fetch_boflink || {
            echo ""
            echo -e "${RED}  [!] Could not obtain boflink automatically${NC}"
            echo -e "${YELLOW}      Grab it manually: https://github.com/${BOFLINK_REPO}/releases${NC}"
            echo -e "${YELLOW}      Drop the binary at: $SCRIPT_DIR/boflink${NC}"
            echo ""
            exit 1
        }
    else
        echo -e "${GREEN}  [+] boflink present${NC}"
    fi

    chmod +x "$SCRIPT_DIR/boflink" 2>/dev/null || true
    echo -e "${GREEN}  [+] Dependencies OK${NC}"
}

# --- build / install / clean --------------------------------------------------

do_build() {
    echo ""
    echo -e "${BOLD}  Building GodPotato BOF...${NC}"
    echo ""
    cd "$SCRIPT_DIR"
    make clean 2>/dev/null || true
    make sliver
    echo ""
    echo -e "${GREEN}  [+] Build complete${NC}"
    echo ""
    echo -e "${BOLD}  Compiled objects:${NC}"
    for f in "$SRC_DIR"/*.o; do
        [ -f "$f" ] || continue
        size=$(wc -c < "$f" 2>/dev/null | tr -d ' ')
        name=$(basename "$f")
        printf "    %-30s %s bytes\n" "$name" "$size"
    done
    echo ""
}

do_install() {
    echo ""
    echo -e "${BOLD}  Installing extension to Sliver...${NC}"
    echo ""

    if [ ! -f "$SRC_DIR/extension.json" ]; then
        echo -e "  ${RED}[!] Missing extension.json in $SRC_DIR${NC}"
        exit 1
    fi

    local o_count
    o_count=$(find "$SRC_DIR" -name "*.o" 2>/dev/null | wc -l)
    if [ "$o_count" -eq 0 ]; then
        echo -e "  ${RED}[!] No .o files found in $SRC_DIR -- run build first${NC}"
        exit 1
    fi

    local is_update=0
    if [ -d "$DST_DIR" ] && [ -f "$DST_DIR/extension.json" ]; then
        is_update=1
    fi

    mkdir -p "$DST_DIR"
    cp "$SRC_DIR"/* "$DST_DIR"/

    if [ $is_update -eq 1 ]; then
        echo -e "    ${CYAN}[~]${NC} $EXT_NAME ${CYAN}(updated)${NC}"
    else
        echo -e "    ${GREEN}[+]${NC} $EXT_NAME"
    fi

    echo ""
    echo -e "${BOLD}  Installed to:${NC}"
    echo -e "    $DST_DIR"
    echo ""
    echo -e "${BOLD}  Load in Sliver:${NC}"
    echo -e "    ${CYAN}extensions load $DST_DIR${NC}"

    if [ $is_update -eq 1 ]; then
        echo ""
        echo -e "${YELLOW}  [!] Extension was updated. Restart the Sliver client if it was already loaded.${NC}"
    fi
    echo ""
}

do_clean() {
    echo ""
    echo -e "${BOLD}  Cleaning...${NC}"
    cd "$SCRIPT_DIR"
    make clean 2>/dev/null || true
    if [ -d "$DST_DIR" ]; then
        rm -rf "$DST_DIR"
        echo -e "    ${YELLOW}[-]${NC} Removed $DST_DIR"
    else
        echo -e "    ${GREEN}[*]${NC} No installed extension to remove"
    fi
    echo ""
    echo -e "${GREEN}  [+] Clean complete${NC}"
    echo ""
}

# --- Main ---------------------------------------------------------------------

banner

case "${1:-all}" in
    build)
        check_deps
        do_build
        ;;
    install)
        do_install
        ;;
    fetch)
        install_apt_deps
        fetch_boflink
        ;;
    clean)
        do_clean
        ;;
    all|"")
        check_deps
        do_build
        do_install
        ;;
    *)
        echo "  Usage: $0 [build|install|fetch|clean]"
        echo ""
        echo "    build    - Compile BOF only (auto-fetches deps if missing)"
        echo "    install  - Copy to Sliver extension cache only"
        echo "    fetch    - Install apt deps + download boflink"
        echo "    clean    - Remove build artifacts and installed extension"
        echo "    (none)   - Fetch + build + install (default)"
        echo ""
        exit 1
        ;;
esac
