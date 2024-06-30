# Setup Script for Initiate new Machine

# Install OhMyZSH
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Check if using yum or apt
PKG_MAN=$(command -v yum || command -v apt) || echo "Neither yum nor apt found"

PKG_MAN install build-essential curl file git tmux -y
PKG_MAN openssl -y

# procps on Fedora, Centos, Arch Linux or Redhat is procps-ng
PKG_MAN install procps -y

# Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

brew install neovim

# Install Antigen ZSH
curl -L git.io/antigen > $HOME/.opts/antigen.zsh

# Kubernetes Related
brew install minikube
brew install kubectx
brew install kubectl
brew install derailed/k9s/k9s

# Node Related
brew install node
brew install fnm
brew install oven-sh/bun/bun

# Golang Related
PKG_MAN install bison
brew install go
## Install GVM
zsh < <(curl -s -S -L https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer)

# Flutter Related
brew install flutter

# Python Related
brew install python
brew install pyenv

# Rust Related
brew install rust
