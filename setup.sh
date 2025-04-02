#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Function to print status
print_status() {
    echo -e "${GREEN}==> ${1}${NC}"
}

# Function to print warning
print_warning() {
    echo -e "${YELLOW}==> WARNING: ${1}${NC}"
}

# Function to print error
print_error() {
    echo -e "${RED}==> ERROR: ${1}${NC}"
}

# Check for required dependencies
print_status "Checking for required dependencies..."
MISSING_DEPS=false

# Check for sudo
if ! command -v sudo &> /dev/null; then
    print_error "sudo is required but not installed"
    MISSING_DEPS=true
fi

# Check for curl
if ! command -v curl &> /dev/null; then
    print_error "curl is required but not installed"
    MISSING_DEPS=true
fi

# Check for git
if ! command -v git &> /dev/null; then
    print_error "git is required but not installed"
    MISSING_DEPS=true
fi

# Check for zsh
if ! command -v zsh &> /dev/null; then
    print_error "zsh is required but not installed"
    MISSING_DEPS=true
fi

# If on WSL, check for Windows integration tools
if [[ "$(uname)" == "Linux" && -f /proc/version && $(grep -i microsoft /proc/version) ]]; then
    if ! command -v wslvar &> /dev/null || ! command -v wslpath &> /dev/null; then
        print_error "WSL integration tools (wslu) are required but not installed"
        print_warning "Install with: sudo apt install -y wslu"
        MISSING_DEPS=true
    fi
fi

# Exit if any dependencies are missing
if [ "$MISSING_DEPS" = true ]; then
    print_error "Please install the missing dependencies and run the script again"
    exit 1
fi

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

# Set up mise as the unified version manager
print_status "Setting up mise as the unified runtime version manager..."
if command -v mise &> /dev/null; then
    # Configure mise in shell
    echo 'eval "$(mise activate zsh)"' >> "$HOME/.zprofile"
    
    # Install mise plugins
    mise plugins add nodejs
    mise plugins add python
    mise plugins add go
    mise plugins add rust
    mise plugins add java
    mise plugins add ruby
    
    # Create mise config directory
    mkdir -p "$HOME/.config/mise"
    
    # Create base config file if it doesn't exist
    if [ ! -f "$HOME/.config/mise/config.toml" ]; then
        cat > "$HOME/.config/mise/config.toml" << EOF
[settings]
always_keep_download = true
jobs = 4
legacy_version_file = true

[tools]
node = ['lts', '18', '20']
python = ['latest']
go = ['latest']
rust = ['stable']
EOF
    fi
fi

# Install Node.js tools
print_status "Installing Node.js tools..."
brew install oven-sh/bun/bun

# Set up Node.js environment for development with mise
print_status "Setting up Node.js environment with mise..."
if command -v mise &> /dev/null; then
    # Activate mise to use installed Node.js
    eval "$(mise activate bash)"
    
    # Install global development tools using the current Node.js
    print_status "Installing global Node.js development tools..."
    npm install -g npm@latest
    npm install -g yarn
    npm install -g pnpm
    npm install -g typescript
    npm install -g electron
    npm install -g electron-packager
    npm install -g expo-cli
    npm install -g create-react-app
    npm install -g create-react-native-app
fi

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

# Install Rust development tools
print_status "Installing Rust development tools..."
if command -v rustup &> /dev/null; then
    source "$HOME/.cargo/env"
    rustup component add rustfmt clippy rust-analyzer
    cargo install cargo-edit cargo-watch cargo-expand
    
    # Install additional libraries for Rust development
    if [[ "$(uname)" == "Linux" ]]; then
        sudo apt update
        sudo apt install -y pkg-config libssl-dev libsqlite3-dev libpq-dev
    elif [[ "$(uname)" == "Darwin" ]]; then
        brew install openssl@3 sqlite postgresql
    fi
fi

# Install Electron development requirements
print_status "Installing Electron development dependencies..."
if [[ "$(uname)" == "Linux" ]]; then
    sudo apt update
    sudo apt install -y libgtk-3-dev libwebkit2gtk-4.0-dev libxss-dev \
        libgconf-2-4 libnss3-dev libasound2-dev libxtst-dev
    
    # Install Wine for Windows builds (optional)
    sudo apt install -y wine64
elif [[ "$(uname)" == "Darwin" ]]; then
    brew install wine
fi

# Install React Native development requirements
print_status "Installing React Native development dependencies..."
if [[ "$(uname)" == "Linux" ]]; then
    sudo apt update
    sudo apt install -y lib32z1 lib32stdc++6 android-tools-adb
    
    # Install JDK for Android development
    if ! command -v java &> /dev/null; then
        sudo apt install -y openjdk-11-jdk
    fi
    
    # Setup Android SDK path
    mkdir -p "$HOME/Android/Sdk"
    echo 'export ANDROID_HOME="$HOME/Android/Sdk"' >> "$HOME/.zprofile"
    echo 'export PATH="$PATH:$ANDROID_HOME/tools:$ANDROID_HOME/tools/bin:$ANDROID_HOME/platform-tools"' >> "$HOME/.zprofile"
elif [[ "$(uname)" == "Darwin" ]]; then
    brew install --cask android-studio android-platform-tools adoptopenjdk/openjdk/adoptopenjdk11
    echo 'export ANDROID_HOME="$HOME/Library/Android/sdk"' >> "$HOME/.zprofile"
    echo 'export PATH="$PATH:$ANDROID_HOME/tools:$ANDROID_HOME/tools/bin:$ANDROID_HOME/platform-tools"' >> "$HOME/.zprofile"
fi

# Install React Native CLI
print_status "Installing React Native CLI..."
npm install -g react-native-cli

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

# Install Flutter with OS-specific method
print_status "Installing Flutter..."
if [[ "$(uname)" == "Linux" ]]; then
    # For Linux/WSL2, use the recommended approach
    if [ ! -d "$HOME/flutter" ]; then
        print_status "Downloading Flutter SDK for Linux..."
        mkdir -p "$HOME/development"
        cd "$HOME/development"
        curl -O https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.19.4-stable.tar.xz
        tar xf flutter_linux_*.tar.xz
        rm flutter_linux_*.tar.xz
        echo 'export PATH="$PATH:$HOME/development/flutter/bin"' >> "$HOME/.zprofile"
        cd "$HOME"
    else
        print_status "Flutter SDK already installed"
    fi
elif [[ "$(uname)" == "Darwin" ]]; then
    # For macOS, use Homebrew cask
    brew install --cask flutter
fi

# Final setup
print_status "Performing final setup..."

# Copy our zshrc if it exists in the same directory
if [ -f "./zshrc" ]; then
    cp ./zshrc "$HOME/.zshrc"
fi

# WSL2-specific optimizations
if [[ "$(uname)" == "Linux" && -f /proc/version && $(grep -i microsoft /proc/version) ]]; then
    print_status "Applying WSL2-specific optimizations..."
    
    # Check if Windows integration is working properly
    if ! WINDOWS_HOME=$(wslpath "$(wslvar USERPROFILE)" 2>/dev/null); then
        print_warning "Cannot access Windows home directory. WSL integration might not be properly set up."
        print_warning "Some features may not work correctly."
        # Try alternative method to find Windows home
        if [ -d "/mnt/c/Users" ]; then
            # Find the most likely Windows username by listing directories in /mnt/c/Users
            WIN_USER=$(ls -la /mnt/c/Users/ | grep -v "Public\|Default\|All Users\|Default User\|desktop.ini" | tail -1 | awk '{print $9}')
            if [ -n "$WIN_USER" ]; then
                WINDOWS_HOME="/mnt/c/Users/$WIN_USER"
                print_status "Using alternative Windows home path: $WINDOWS_HOME"
            else
                WINDOWS_HOME="/mnt/c/Users"
                print_warning "Could not determine Windows username, using $WINDOWS_HOME"
            fi
        else
            print_error "Windows C: drive not accessible. Your WSL setup might have issues."
            WINDOWS_HOME="$HOME"
        fi
    fi
    
    # Create .wslconfig in Windows home if it doesn't exist
    if [ ! -f "$WINDOWS_HOME/.wslconfig" ]; then
        print_status "Creating .wslconfig for better WSL2 performance..."
        cat > "$WINDOWS_HOME/.wslconfig" << EOF
[wsl2]
memory=8GB
processors=4
localhostForwarding=true
kernelCommandLine=net.ifnames=0
EOF
    fi
    
    # Add WSL-specific settings to .zprofile
    cat >> "$HOME/.zprofile" << EOF

# WSL2-specific settings
export BROWSER=wslview
export DISPLAY=:0
# Improve Docker performance on WSL2
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1
EOF

    # Check for common WSL2 issues
    print_status "Checking for common WSL2 issues..."
    
    # Check if Windows Firewall might be blocking connections
    if ! curl -s https://api.github.com > /dev/null; then
        print_warning "Network connectivity issues detected. Windows Firewall might be blocking WSL2 connections."
        print_warning "You may need to add a Windows Firewall rule to allow WSL2 traffic."
    fi
    
    # Check for Windows path in PATH variable
    if echo $PATH | grep -q "/mnt/c/Windows"; then
        print_warning "Windows paths detected in your PATH. This can cause slowdowns and compatibility issues."
        print_warning "Consider removing Windows paths from your PATH variable in Linux environment."
    fi
    
    # Check disk space on WSL2 virtual disk
    DISK_SPACE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$DISK_SPACE" -gt 80 ]; then
        print_warning "WSL2 virtual disk usage is high (${DISK_SPACE}%). Consider cleaning up or expanding the virtual disk."
    fi
fi

# Install database development tools
print_status "Installing database development tools..."
if [[ "$(uname)" == "Linux" ]]; then
    sudo apt update
    sudo apt install -y postgresql postgresql-contrib mysql-server redis-server
    sudo service postgresql start
    sudo service mysql start
    sudo service redis-server start
    
    # Install MongoDB
    wget -qO - https://www.mongodb.org/static/pgp/server-6.0.asc | sudo apt-key add -
    echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu $(lsb_release -cs)/mongodb-org/6.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-6.0.list
    sudo apt update
    sudo apt install -y mongodb-org
    sudo service mongod start
elif [[ "$(uname)" == "Darwin" ]]; then
    brew install postgresql mysql redis mongodb-community
    brew services start postgresql
    brew services start mysql
    brew services start redis
    brew services start mongodb-community
fi

# Install database management tools
print_status "Installing database management tools..."
if command -v npm &> /dev/null; then
    npm install -g prisma
    npm install -g sequelize-cli
    npm install -g typeorm
fi

# Setup VSCode and Cursor extensions if accessible
print_status "Setting up code editor extensions if available..."

# Setup VSCode extensions
if command -v code &> /dev/null; then
    print_status "Installing recommended VSCode extensions for development..."
    
    # Rust extensions
    code --install-extension rust-lang.rust-analyzer
    code --install-extension serayuzgur.crates
    code --install-extension vadimcn.vscode-lldb
    
    # JavaScript/TypeScript extensions
    code --install-extension dbaeumer.vscode-eslint
    code --install-extension esbenp.prettier-vscode
    code --install-extension ms-vscode.vscode-typescript-next
    
    # React & React Native extensions
    code --install-extension dsznajder.es7-react-js-snippets
    code --install-extension msjsdiag.vscode-react-native
    
    # Electron extensions
    code --install-extension dsznajder.es7-react-js-snippets
    
    # Flutter/Dart extensions
    code --install-extension dart-code.dart-code
    code --install-extension dart-code.flutter
    
    # WSL integration
    if [[ "$(uname)" == "Linux" && -f /proc/version && $(grep -i microsoft /proc/version) ]]; then
        print_status "Setting up WSL-specific integrations for VSCode..."
        code --install-extension ms-vscode-remote.remote-wsl
    fi
    
    # General development extensions
    code --install-extension github.copilot
    code --install-extension eamodio.gitlens
    code --install-extension ms-azuretools.vscode-docker
    code --install-extension christian-kohler.path-intellisense
    code --install-extension ms-vscode.cmake-tools
fi

# Setup Cursor IDE if available
if command -v cursor &> /dev/null; then
    print_status "Installing recommended Cursor extensions for development..."
    
    # Rust extensions
    cursor --install-extension rust-lang.rust-analyzer
    cursor --install-extension serayuzgur.crates
    cursor --install-extension vadimcn.vscode-lldb
    
    # JavaScript/TypeScript extensions
    cursor --install-extension dbaeumer.vscode-eslint
    cursor --install-extension esbenp.prettier-vscode
    cursor --install-extension ms-vscode.vscode-typescript-next
    
    # React & React Native extensions
    cursor --install-extension dsznajder.es7-react-js-snippets
    cursor --install-extension msjsdiag.vscode-react-native
    
    # Electron extensions
    cursor --install-extension dsznajder.es7-react-js-snippets
    
    # Flutter/Dart extensions
    cursor --install-extension dart-code.dart-code
    cursor --install-extension dart-code.flutter
    
    # WSL integration
    if [[ "$(uname)" == "Linux" && -f /proc/version && $(grep -i microsoft /proc/version) ]]; then
        print_status "Setting up WSL-specific integrations for Cursor..."
        cursor --install-extension ms-vscode-remote.remote-wsl
    fi
    
    # General development extensions
    cursor --install-extension github.copilot
    cursor --install-extension eamodio.gitlens
    cursor --install-extension ms-azuretools.vscode-docker
    cursor --install-extension christian-kohler.path-intellisense
    cursor --install-extension ms-vscode.cmake-tools
fi

# Install Cursor if not installed (WSL2 specific)
if [[ "$(uname)" == "Linux" && -f /proc/version && $(grep -i microsoft /proc/version) ]]; then
    if ! command -v cursor &> /dev/null; then
        print_status "Cursor IDE not found. Providing installation instructions..."
        print_warning "Since you're using WSL2, you should install Cursor on the Windows side:"
        print_warning "1. Download Cursor from https://cursor.sh/"
        print_warning "2. Install on Windows"
        print_warning "3. In WSL, you can run 'cursor' command to launch it if WSL integration is properly set up"
    fi
elif [[ "$(uname)" == "Darwin" ]]; then
    if ! command -v cursor &> /dev/null; then
        print_status "Installing Cursor IDE for macOS..."
        brew install --cask cursor
    fi
fi

# Verify installation
print_status "Verifying installation..."

# Check critical tools
INSTALLATION_ISSUES=false

verify_tool() {
    if command -v $1 &> /dev/null; then
        print_status "$1 is successfully installed"
        return 0
    else
        print_error "$1 installation failed or not in PATH"
        INSTALLATION_ISSUES=true
        return 1
    fi
}

# Check shell tools
verify_tool zsh
verify_tool git
verify_tool neovim
verify_tool tmux

# Check runtime managers
verify_tool mise

# Check if node is available through mise
if command -v mise &> /dev/null; then
    if mise which node &> /dev/null; then
        print_status "Node.js is available through mise"
        NODE_VERSION=$(node -v)
        print_status "Node.js version: $NODE_VERSION"
    else
        print_warning "Node.js not available through mise. Try running: mise install nodejs@lts"
        INSTALLATION_ISSUES=true
    fi
fi

# Check editors
if command -v code &> /dev/null; then
    print_status "VSCode is installed"
else
    print_warning "VSCode is not installed or not in PATH"
fi

if command -v cursor &> /dev/null; then
    print_status "Cursor IDE is installed"
else
    print_warning "Cursor IDE is not installed or not in PATH"
fi

# Final message
if [ "$INSTALLATION_ISSUES" = true ]; then
    print_warning "Some issues were detected with your installation. Please review the warnings above."
    print_status "You may need to restart your terminal or run 'source ~/.zprofile' to apply all changes."
else
    print_status "Installation verification complete! All critical components are installed."
fi

print_status "Setup complete! Please restart your terminal and run 'p10k configure' to set up your prompt."
