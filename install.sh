#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║  Arch Linux Post-Install Bootstrap Script                       ║
# ║  Hyprland + Noctalia Shell + Alacritty + Zsh                    ║
# ║                                                                  ║
# ║  Usage:                                                          ║
# ║    chmod +x install.sh && ./install.sh                           ║
# ║    ./install.sh --dry-run    (preview without executing)         ║
# ║                                                                  ║
# ║  Run this as a NORMAL USER on a fresh Arch install.              ║
# ║  The script uses sudo when root privileges are needed.           ║
# ╚══════════════════════════════════════════════════════════════════╝

set -euo pipefail

# ── Flags ──────────────────────────────────────────────────────────
DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
fi

# ── Colors & helpers ───────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[  OK]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[FAIL]${NC} $*"; }
step()    { echo -e "\n${CYAN}${BOLD}━━━ $* ━━━${NC}\n"; }

run() {
    if $DRY_RUN; then
        echo -e "  ${YELLOW}[DRY-RUN]${NC} $*"
    else
        # shellcheck disable=SC2294
        eval "$@"
    fi
}

# ── Configuration ─────────────────────────────────────────────────
DOTFILES_REPO="https://github.com/MertYksl03/dot-files.git"
DOTFILES_DIR="$HOME/dot-files"
CONFIG_DIR="$HOME/.config"

# ══════════════════════════════════════════════════════════════════
# 1. PRE-FLIGHT CHECKS
# ══════════════════════════════════════════════════════════════════
step "1/8 · Pre-flight checks"

# Don't run as root
if [[ $EUID -eq 0 ]]; then
    error "Do not run this script as root. Run as a normal user."
    exit 1
fi
success "Running as user: $USER"

# Check internet
if ! ping -c 1 -W 3 archlinux.org &>/dev/null; then
    error "No internet connection. Connect to the internet and try again."
    exit 1
fi
success "Internet connection OK"

if $DRY_RUN; then
    warn "DRY-RUN mode: commands will be printed but not executed."
fi

# ══════════════════════════════════════════════════════════════════
# 2. INSTALL YAY (AUR HELPER)
# ══════════════════════════════════════════════════════════════════
step "2/8 · Installing yay (AUR helper)"

if command -v yay &>/dev/null; then
    success "yay is already installed, skipping."
else
    info "Installing base-devel and git..."
    run "sudo pacman -S --needed --noconfirm base-devel git"

    info "Cloning and building yay..."
    run "git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-build"
    run "cd /tmp/yay-build && makepkg -si --noconfirm"
    run "rm -rf /tmp/yay-build"
    success "yay installed."
fi

# ══════════════════════════════════════════════════════════════════
# 3. INSTALL PACMAN PACKAGES
# ══════════════════════════════════════════════════════════════════
step "3/8 · Installing pacman packages"

PACMAN_PACKAGES=(
    # ── Hyprland & Wayland core ──
    hyprland
    xdg-desktop-portal-hyprland
    xdg-desktop-portal-gtk          # Needed for file dialogs (nautilus)
    qt6-base
    qt6-declarative
    qt6-wayland
    polkit-gnome                     # Authentication agent

    # ── Terminal & shell ──
    alacritty
    zsh

    # ── Desktop utilities ──
    nautilus                         # File manager
    wl-clipboard                     # Clipboard (wl-copy / wl-paste)
    cliphist                         # Clipboard history (noctalia)
    playerctl                        # Media controls
    brightnessctl                    # Brightness control

    # ── Audio ──
    pipewire
    pipewire-pulse
    wireplumber

    # ── Display manager ──
    sddm                             # Login manager

    # ── Networking ──
    networkmanager
    bluez
    bluez-utils

    # ── Fonts ──
    ttf-cascadia-code-nerd           # CaskaydiaCove Nerd Font
    noto-fonts
    noto-fonts-emoji

    # ── CLI tools ──
    git
    curl
    wget
    bat                              # MANPAGER in zshrc
    fastfetch                        # System info (zshrc startup)
    nsxiv                            # Image viewer (wallpaper menu)
    unzip
)

info "Installing ${#PACMAN_PACKAGES[@]} packages via pacman..."
run "sudo pacman -S --needed --noconfirm ${PACMAN_PACKAGES[*]}"
success "Pacman packages installed."

# ══════════════════════════════════════════════════════════════════
# 4. INSTALL AUR PACKAGES
# ══════════════════════════════════════════════════════════════════
step "4/8 · Installing AUR packages"

AUR_PACKAGES=(
    noctalia-shell                   # Desktop shell (bar, panels, lock, widgets)
    google-chrome-stable             # Browser
    spotify                          # Music player
)

info "Installing ${#AUR_PACKAGES[@]} packages via yay..."
for pkg in "${AUR_PACKAGES[@]}"; do
    if pacman -Qi "$pkg" &>/dev/null; then
        success "$pkg is already installed, skipping."
    else
        info "Installing $pkg..."
        run "yay -S --noconfirm --needed $pkg"
    fi
done
success "AUR packages installed."

# ══════════════════════════════════════════════════════════════════
# 5. SETUP ZSH + OH-MY-ZSH + PLUGINS + POWERLEVEL10K
# ══════════════════════════════════════════════════════════════════
step "5/8 · Setting up Zsh, Oh-My-Zsh, plugins & Powerlevel10k"

# Oh-My-Zsh
if [[ -d "$HOME/.oh-my-zsh" ]]; then
    success "Oh-My-Zsh is already installed."
else
    info "Installing Oh-My-Zsh..."
    # shellcheck disable=SC2016
    run 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended'
    success "Oh-My-Zsh installed."
fi

# Zsh plugins
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

if [[ -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]]; then
    success "zsh-autosuggestions already installed."
else
    info "Installing zsh-autosuggestions..."
    run "git clone https://github.com/zsh-users/zsh-autosuggestions $ZSH_CUSTOM/plugins/zsh-autosuggestions"
fi

if [[ -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]]; then
    success "zsh-syntax-highlighting already installed."
else
    info "Installing zsh-syntax-highlighting..."
    run "git clone https://github.com/zsh-users/zsh-syntax-highlighting $ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
fi

# Powerlevel10k
if [[ -d "$ZSH_CUSTOM/themes/powerlevel10k" ]]; then
    success "Powerlevel10k already installed."
else
    info "Installing Powerlevel10k theme..."
    run "git clone --depth=1 https://github.com/romkatv/powerlevel10k.git $ZSH_CUSTOM/themes/powerlevel10k"
fi

# Change default shell to zsh
if [[ "$(basename "$SHELL")" != "zsh" ]]; then
    info "Changing default shell to zsh..."
    run "chsh -s \$(which zsh)"
    success "Default shell changed to zsh."
else
    success "Default shell is already zsh."
fi

# ══════════════════════════════════════════════════════════════════
# 6. CLONE DOTFILES & CREATE SYMLINKS
# ══════════════════════════════════════════════════════════════════
step "6/8 · Cloning dotfiles & creating symlinks"

# Clone the repo if it doesn't exist
if [[ -d "$DOTFILES_DIR" ]]; then
    warn "Dotfiles directory already exists at $DOTFILES_DIR, skipping clone."
    info "Pulling latest changes..."
    run "git -C $DOTFILES_DIR pull --ff-only || true"
else
    info "Cloning dotfiles from $DOTFILES_REPO..."
    run "git clone $DOTFILES_REPO $DOTFILES_DIR"
    success "Dotfiles cloned."
fi

# Helper: create a symlink, backing up existing files
link() {
    local src="$1"
    local dest="$2"

    # Create parent directory if needed
    local parent
    parent=$(dirname "$dest")
    if [[ ! -d "$parent" ]]; then
        run "mkdir -p $parent"
    fi

    # If the destination exists and is NOT already a symlink to src, back it up
    if [[ -e "$dest" || -L "$dest" ]]; then
        if [[ "$(readlink -f "$dest" 2>/dev/null)" == "$(readlink -f "$src" 2>/dev/null)" ]]; then
            success "Already linked: $dest → $src"
            return
        fi
        warn "Backing up existing: $dest → ${dest}.bak"
        run "mv $dest ${dest}.bak"
    fi

    run "ln -sf $src $dest"
    success "Linked: $dest → $src"
}

info "Creating symlinks..."

# ── Hyprland ──
link "$DOTFILES_DIR/hypr" "$CONFIG_DIR/hypr"

# ── Alacritty ──
run "mkdir -p $CONFIG_DIR/alacritty"
link "$DOTFILES_DIR/alacritty/alacritty.toml" "$CONFIG_DIR/alacritty/alacritty.toml"

# ── Dunst ──
run "mkdir -p $CONFIG_DIR/dunst"
link "$DOTFILES_DIR/dunst/dunstrc" "$CONFIG_DIR/dunst/dunstrc"
link "$DOTFILES_DIR/dunst/wal.sh"  "$CONFIG_DIR/dunst/wal.sh"

# ── Rofi ──
link "$DOTFILES_DIR/rofi" "$CONFIG_DIR/rofi"

# ── Noctalia Shell ──
# Noctalia stores its config in ~/.config/noctalia-shell/
run "mkdir -p $CONFIG_DIR/noctalia-shell"
link "$DOTFILES_DIR/noctalia/settings.json"    "$CONFIG_DIR/noctalia-shell/settings.json"
link "$DOTFILES_DIR/noctalia/colors.json"      "$CONFIG_DIR/noctalia-shell/colors.json"
link "$DOTFILES_DIR/noctalia/plugins.json"     "$CONFIG_DIR/noctalia-shell/plugins.json"
if [[ -d "$DOTFILES_DIR/noctalia/colorschemes" ]]; then
    link "$DOTFILES_DIR/noctalia/colorschemes" "$CONFIG_DIR/noctalia-shell/colorschemes"
fi
if [[ -d "$DOTFILES_DIR/noctalia/plugins" ]]; then
    link "$DOTFILES_DIR/noctalia/plugins" "$CONFIG_DIR/noctalia-shell/plugins"
fi

# ── Neofetch ──
run "mkdir -p $CONFIG_DIR/neofetch"
link "$DOTFILES_DIR/neofetch/config.conf" "$CONFIG_DIR/neofetch/config.conf"

# ── Pywal templates & colorschemes ──
run "mkdir -p $CONFIG_DIR/wal"
link "$DOTFILES_DIR/wal/templates"    "$CONFIG_DIR/wal/templates"
link "$DOTFILES_DIR/wal/colorschemes" "$CONFIG_DIR/wal/colorschemes"

# ── Zsh ──
link "$DOTFILES_DIR/zsh/zshrc" "$HOME/.zshrc"

# ── Scripts (make executable) ──
if ! $DRY_RUN; then
    chmod +x "$DOTFILES_DIR/scripts/"* 2>/dev/null || true
    chmod +x "$DOTFILES_DIR/hypr/scripts/"* 2>/dev/null || true
    chmod +x "$DOTFILES_DIR/dunst/wal.sh" 2>/dev/null || true
fi
success "Scripts marked as executable."

# ══════════════════════════════════════════════════════════════════
# 7. CREATE DIRECTORIES & ENABLE SERVICES
# ══════════════════════════════════════════════════════════════════
step "7/8 · Creating directories & enabling services"

# Create wallpaper directory
run "mkdir -p $HOME/Pictures/Wallpapers"
success "Created ~/Pictures/Wallpapers"

# Create a programs directory (referenced in zshrc PATH)
run "mkdir -p $HOME/programs"
success "Created ~/programs"

# Enable services
info "Enabling NetworkManager..."
run "sudo systemctl enable --now NetworkManager.service"

info "Enabling Bluetooth..."
run "sudo systemctl enable --now bluetooth.service"

success "Services enabled."

# ══════════════════════════════════════════════════════════════════
# 8. DONE
# ══════════════════════════════════════════════════════════════════
step "8/8 · Setup complete!"

echo -e "${GREEN}${BOLD}"
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                    Installation Complete! 🎉                    ║"
echo "╠══════════════════════════════════════════════════════════════════╣"
echo "║                                                                 ║"
echo "║  Your Hyprland + Noctalia Shell desktop is ready.               ║"
echo "║                                                                 ║"
echo "║  Next steps:                                                    ║"
echo "║                                                                 ║"
echo "║  1. Log out and select 'Hyprland' from your display manager,    ║"
echo "║     or reboot and start Hyprland from the TTY:                  ║"
echo "║       $ Hyprland                                                ║"
echo "║                                                                 ║"
echo "║  2. On first Zsh launch, run 'p10k configure' to set up        ║"
echo "║     Powerlevel10k prompt (or it will auto-start).               ║"
echo "║                                                                 ║"
echo "║  3. Add wallpapers to ~/Pictures/Wallpapers to enable           ║"
echo "║     the wallpaper menu & pywal theming.                         ║"
echo "║                                                                 ║"
echo "║  4. Noctalia Shell starts automatically with Hyprland via       ║"
echo "║     the autostart config.                                       ║"
echo "║                                                                 ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

if $DRY_RUN; then
    echo -e "${YELLOW}${BOLD}This was a DRY RUN. No changes were made.${NC}"
fi
