#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Function to print status
print_status() {
    echo -e "${GREEN}==> ${1}${NC}"
}

# Function to check and install packages based on OS
install_packages() {
    if [[ "$(uname)" == "Linux" ]]; then
        if command -v apt &> /dev/null; then
            sudo apt update
            sudo apt install -y build-essential curl file git tmux openssl procps
        elif command -v yum &> /dev/null; then
            sudo yum groupinstall -y 'Development Tools'
            sudo yum install -y curl file git tmux openssl procps-ng
        else
            echo -e "${RED}No supported package manager found${NC}"
            exit 1
        fi
    elif [[ "$(uname)" == "Darwin" ]]; then
        if ! command -v xcode-select &> /dev/null; then
            print_status "Installing Command Line Tools for Xcode..."
            xcode-select --install
        fi
    fi
}

# Create necessary directories
print_status "Creating directories..."
mkdir -p "$HOME/.config/zsh"
mkdir -p "$HOME/bin"
mkdir -p "$HOME/.kube"

# Install base packages
print_status "Installing base packages..."
install_packages

# Install Homebrew if not installed
if ! command -v brew &> /dev/null; then
    print_status "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add Homebrew to PATH based on OS
    if [[ "$(uname)" == "Linux" ]]; then
        echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    elif [[ "$(uname)" == "Darwin" ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
fi

# Install Oh My Zsh if not installed
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    print_status "Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Install Antigen
print_status "Installing Antigen..."
curl -L git.io/antigen > "$HOME/.config/zsh/antigen.zsh"

# Install Powerlevel10k theme
print_status "Installing Powerlevel10k theme..."
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

# Install core tools with Homebrew
print_status "Installing core tools..."
brew install \
    neovim \
    tmux \
    mise \
    git

# Install Node.js tools
print_status "Installing Node.js tools..."
brew install fnm
brew install oven-sh/bun/bun

# Install Python tools
print_status "Installing Python tools..."
brew install pyenv
brew install pipx

# Install Go tools
print_status "Installing Go tools..."
brew install go
if [ ! -d "$HOME/.gvm" ]; then
    bash < <(curl -s -S -L https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer)
fi

# Install Rust
print_status "Installing Rust..."
if ! command -v rustc &> /dev/null; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
fi

# Install Ruby tools
print_status "Installing Ruby tools..."
brew install rbenv

# Install Kubernetes tools
print_status "Installing Kubernetes tools..."
brew install \
    minikube \
    kubectx \
    kubectl \
    derailed/k9s/k9s

# Install SDKMAN if not installed
if [ ! -d "$HOME/.sdkman" ]; then
    print_status "Installing SDKMAN..."
    curl -s "https://get.sdkman.io" | bash
fi

# Install Flutter
print_status "Installing Flutter..."
brew install --cask flutter

# Final setup
print_status "Performing final setup..."

# Copy our zshrc if it exists in the same directory
if [ -f "./zshrc" ]; then
    cp ./zshrc "$HOME/.zshrc"
fi

# Create initial mise config
if command -v mise &> /dev/null; then
    mise install node@latest python@latest go@latest
fi

print_status "Setup complete! Please restart your terminal and run 'p10k configure' to set up your prompt."
