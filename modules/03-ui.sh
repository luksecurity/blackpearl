#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
source "$ROOT_DIR/lib.sh"

install_dotfiles() {
    log "Copying dotfiles..."
    mkdir -p ~/.config/{i3,compton,rofi,alacritty}
    if [ -d "$ROOT_DIR/.config" ]; then
        cp -r "$ROOT_DIR/.config/." ~/.config/
    else
        log "No .config directory in $ROOT_DIR, skipping"
    fi
    if [ -f "$ROOT_DIR/.fehbg" ]; then
        cp "$ROOT_DIR/.fehbg" ~/
    fi
}

install_fonts() {
    log "Installing Nerd Fonts..."
    local VERSION TMP
    VERSION=$(get_latest_release "ryanoasis/nerd-fonts") || return
    mkdir -p "$HOME/.local/share/fonts"
    TMP=$(mktemp -d)
    for font in Iosevka RobotoMono; do
        if wget -qO "$TMP/${font}.zip" \
            "https://github.com/ryanoasis/nerd-fonts/releases/download/${VERSION}/${font}.zip"; then
            unzip -oq "$TMP/${font}.zip" -d "$HOME/.local/share/fonts"
        else
            log "Failed to download ${font}"
        fi
    done
    rm -rf "$TMP"
    fc-cache -f
}

install_alacritty() {
    if command -v alacritty &>/dev/null; then
        return
    fi
    log "Installing Alacritty..."
    local URL TMP_DEB
    URL=$(curl -s https://api.github.com/repos/barnumbirr/alacritty-debian/releases/latest | \
        grep "browser_download_url.*amd64_bullseye.deb" | cut -d '"' -f 4 | head -n 1) || true
    if [ -z "$URL" ]; then
        log "Failed to fetch Alacritty URL"
        return
    fi
    TMP_DEB=$(mktemp --suffix=.deb)
    wget -qO "$TMP_DEB" "$URL"
    sudo dpkg -i "$TMP_DEB" || sudo apt install -f -y
    rm -f "$TMP_DEB"
}

install_wallpaper() {
    log "Setting wallpaper..."
    local SRC="$ROOT_DIR/assets/wallpaper/23.jpg"
    local DEST_DIR="$HOME/.wallpaper"
    local DEST="$DEST_DIR/23.jpg"
    if [ ! -f "$SRC" ]; then
        log "Wallpaper not found at $SRC"
        return
    fi
    mkdir -p "$DEST_DIR"
    if [ ! -f "$DEST" ] || ! cmp -s "$SRC" "$DEST"; then
        cp "$SRC" "$DEST"
        log "Wallpaper copied."
    fi
    if ! command -v feh &>/dev/null; then
        sudo apt install -y feh
    fi
    feh --bg-fill "$DEST"
    local I3_CONFIG="$HOME/.config/i3/config"
    mkdir -p "$(dirname "$I3_CONFIG")"
    if ! grep -q "exec_always --no-startup-id ~/.fehbg" "$I3_CONFIG" 2>/dev/null; then
        echo 'exec_always --no-startup-id ~/.fehbg' >> "$I3_CONFIG"
        log "Wallpaper persistence added to i3 config"
    fi
    log "Wallpaper applied ✅"
}

run_step dotfiles   install_dotfiles
run_step fonts      install_fonts
run_step alacritty  install_alacritty
run_step wallpaper  install_wallpaper
