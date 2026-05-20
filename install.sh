#!/bin/bash
#
# install.sh - Build GodPotato BOF and install into Sliver
#
# Usage:
#   ./install.sh              Build + install
#   ./install.sh build        Build only
#   ./install.sh install      Install only (assumes already built)
#   ./install.sh clean        Remove build artifacts and installed extension
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SLIVER_EXT_DIR="$HOME/.sliver-client/extensions"
EXT_NAME="godpotato"
SRC_DIR="$SCRIPT_DIR/sliver-extensions/$EXT_NAME"
DST_DIR="$SLIVER_EXT_DIR/$EXT_NAME"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

banner() {
    echo ""
    echo -e "${CYAN}  +----------------------------------------------+${NC}"
    echo -e "${CYAN}  |${BOLD}   GodPotato BOF - Build & Install            ${NC}${CYAN}|${NC}"
    echo -e "${CYAN}  |   Sliver C2 Extension Packager               |${NC}"
    echo -e "${CYAN}  +----------------------------------------------+${NC}"
    echo ""
}

check_deps() {
    local missing=0

    if ! command -v x86_64-w64-mingw32-gcc &>/dev/null; then
        echo -e "${RED}  [!] Missing: x86_64-w64-mingw32-gcc${NC}"
        missing=1
    fi

    if ! command -v i686-w64-mingw32-gcc &>/dev/null; then
        echo -e "${RED}  [!] Missing: i686-w64-mingw32-gcc${NC}"
        missing=1
    fi

    if ! command -v make &>/dev/null; then
        echo -e "${RED}  [!] Missing: make${NC}"
        missing=1
    fi

    if [ ! -x "$SCRIPT_DIR/boflink" ]; then
        echo -e "${RED}  [!] Missing: boflink (expected at $SCRIPT_DIR/boflink)${NC}"
        echo -e "${YELLOW}      Get it from: https://github.com/MEhrn00/boflink${NC}"
        missing=1
    fi

    if [ $missing -eq 1 ]; then
        echo ""
        echo -e "${YELLOW}  Install compiler dependencies:${NC}"
        echo -e "    ${BOLD}apt install mingw-w64 make${NC}"
        echo ""
        exit 1
    fi

    echo -e "${GREEN}  [+] Dependencies OK${NC}"
}

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

# --- Main ---

banner

case "${1:-all}" in
    build)
        check_deps
        do_build
        ;;
    install)
        do_install
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
        echo "  Usage: $0 [build|install|clean]"
        echo ""
        echo "    build    - Compile BOF only"
        echo "    install  - Copy to Sliver extension cache only"
        echo "    clean    - Remove build artifacts and installed extension"
        echo "    (none)   - Build + install (default)"
        echo ""
        exit 1
        ;;
esac
