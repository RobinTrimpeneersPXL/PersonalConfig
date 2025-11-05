#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Function to print messages
info() {
    echo -e "\033[34m[INFO]\033[0m $1"
}

# --- Main Setup ---

# 1. DETECT OS AND SET PACKAGE MANAGER
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "Cannot detect operating system."
    exit 1
fi

if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
    PKG_MANAGER="sudo apt-get install -y"
    sudo apt-get update
elif [ "$OS" = "arch" ]; then
    PKG_MANAGER="sudo pacman -S --noconfirm"
else
    echo "Unsupported operating system: $OS"
    exit 1
fi

# 2. INSTALL DEPENDENCIES
info "Installing dependencies (git, zsh, curl)..."
$PKG_MANAGER git zsh curl

# 3. INSTALL OH MY ZSH
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    info "Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
    info "Oh My Zsh is already installed."
fi

# 4. INSTALL STARSHIP
info "Installing Starship..."
curl -sS https://starship.rs/install.sh | sh -s -- -y

# 5. INSTALL ZSH PLUGINS
ZSH_CUSTOM=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}
info "Installing Zsh plugins..."
[ ! -d "${ZSH_CUSTOM}/plugins/zsh-autosuggestions" ] && git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM}/plugins/zsh-autosuggestions
[ ! -d "${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting" ] && git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting

# 6. CLONE DOTFILES REPO
read -p "Please enter your GitHub username: " GITHUB_USERNAME
DOTFILES_REPO="https://github.com/$GITHUB_USERNAME/dotfiles.git"
DOTFILES_DIR="$HOME/dotfiles"

if [ ! -d "$DOTFILES_DIR" ]; then
    info "Cloning dotfiles repository..."
    git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
else
    info "Dotfiles repository already exists."
fi

# 7. CREATE SYMBOLIC LINKS
info "Creating symbolic links..."
# Back up existing files
[ -f "$HOME/.zshrc" ] && mv "$HOME/.zshrc" "$HOME/.zshrc.bak"
[ -f "$HOME/.config/starship.toml" ] && mv "$HOME/.config/starship.toml" "$HOME/.config/starship.toml.bak"

mkdir -p "$HOME/.config"
ln -s "$DOTFILES_DIR/zsh/.zshrc" "$HOME/.zshrc"
ln -s "$DOTFILES_DIR/starship/starship.toml" "$HOME/.config/starship.toml"

# 8. CHANGE DEFAULT SHELL
if [ "$SHELL" != "$(which zsh)" ]; then
    info "Changing default shell to Zsh..."
    chsh -s "$(which zsh)"
    info "Shell changed successfully. Please log out and back in for the change to take effect."
else
    info "Default shell is already Zsh."
fi

echo -e "\n\033[32m✅ Setup complete! Please log out and log back in to start using Zsh.\033[0m"
