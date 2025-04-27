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
    print_warning "Install with: apt update && apt install -y sudo"
    MISSING_DEPS=true
fi

# Check for curl
if ! command -v curl &> /dev/null; then
    print_error "curl is required but not installed"
    print_warning "Install with: sudo apt update && sudo apt install -y curl"
    MISSING_DEPS=true
fi

# Check for git
if ! command -v git &> /dev/null; then
    print_error "git is required but not installed"
    print_warning "Install with: sudo apt update && sudo apt install -y git"
    MISSING_DEPS=true
fi

# Check for zsh
if ! command -v zsh &> /dev/null; then
    print_error "zsh is required but not installed"
    print_warning "Install with: sudo apt update && sudo apt install -y zsh"
    MISSING_DEPS=true
fi

# If on WSL, check for Windows integration tools
if [[ "$(uname)" == "Linux" && -f /proc/version && $(grep -i microsoft /proc/version) ]]; then
    if ! command -v wslvar &> /dev/null || ! command -v wslpath &> /dev/null; then
        print_error "WSL integration tools (wslu) are required but not installed"
        print_warning "Install with: sudo apt update && sudo apt install -y wslu"
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
        BREW_PATH="/home/linuxbrew/.linuxbrew/bin/brew"
        if ! grep -q "eval \\\"\\$(\\$BREW_PATH shellenv)\\\"" "$HOME/.zprofile"; then
            echo 'eval "$('$BREW_PATH' shellenv)"' >> "$HOME/.zprofile"
        fi
        eval "$($BREW_PATH shellenv)"
    elif [[ "$(uname)" == "Darwin" ]]; then
        BREW_PATH="/opt/homebrew/bin/brew"
        if ! grep -q "eval \\\"\\$(\\$BREW_PATH shellenv)\\\"" "$HOME/.zprofile"; then
            echo 'eval "$('$BREW_PATH' shellenv)"' >> "$HOME/.zprofile"
        fi
        eval "$($BREW_PATH shellenv)"
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
    tmux \
    git

# Install mise directly
print_status "Installing mise directly..."
if ! command -v mise &> /dev/null; then
    curl -fsSL https://mise.run | sh
    # Ensure mise is available in the current session's PATH
    export PATH="$HOME/.local/bin:$PATH"
else
    print_status "mise is already installed."
fi

# Install Neovim with multiple fallback methods
print_status "Installing Neovim..."
NEOVIM_INSTALLED=false

# Method 1: Try with Homebrew
if ! $NEOVIM_INSTALLED; then
    print_status "Attempting to install Neovim with Homebrew..."
    brew install neovim
    if command -v nvim &> /dev/null; then
        NEOVIM_INSTALLED=true
        print_status "Neovim installed successfully with Homebrew!"
    fi
fi

# Method 2: Try with system package manager
if ! $NEOVIM_INSTALLED && [[ "$(uname)" == "Linux" ]]; then
    print_status "Attempting to install Neovim with system package manager..."
    
    # For Ubuntu/Debian systems
    if command -v apt &> /dev/null; then
        print_status "Using apt to install Neovim..."
        sudo apt update
        sudo apt install -y neovim
    # For RHEL/CentOS systems
    elif command -v yum &> /dev/null; then
        print_status "Using yum to install Neovim..."
        sudo yum install -y neovim
    fi
    
    if command -v nvim &> /dev/null; then
        NEOVIM_INSTALLED=true
        print_status "Neovim installed successfully with system package manager!"
    fi
fi

# Method 3: Try with snap (for Ubuntu)
if ! $NEOVIM_INSTALLED && [[ "$(uname)" == "Linux" ]] && command -v snap &> /dev/null; then
    print_status "Attempting to install Neovim with snap..."
    sudo snap install --classic nvim
    
    if command -v nvim &> /dev/null; then
        NEOVIM_INSTALLED=true
        print_status "Neovim installed successfully with snap!"
    fi
fi

# Method 4: Install from AppImage (Linux only)
if ! $NEOVIM_INSTALLED && [[ "$(uname)" == "Linux" ]]; then
    print_status "Attempting to install Neovim using AppImage..."
    mkdir -p "$HOME/bin"
    cd "$HOME/bin"
    curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim.appimage
    chmod u+x nvim.appimage
    
    # Try to extract AppImage if fuse is not available
    if ! ./nvim.appimage --version &> /dev/null; then
        print_status "Extracting AppImage (fuse may not be available)..."
        ./nvim.appimage --appimage-extract
        # Create wrapper script
        echo '#!/bin/bash' > nvim
        echo "$(pwd)/squashfs-root/usr/bin/nvim \"\$@\"" >> nvim
        chmod +x nvim
    else
        # Create symlink
        ln -sf "$(pwd)/nvim.appimage" "$(pwd)/nvim"
    fi
    
    # Add to PATH if not already there
    if ! grep -q 'export PATH="$HOME/bin:$PATH"' "$HOME/.zprofile"; then
        echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.zprofile"
    fi
    
    # Source immediately for the current session
    export PATH="$HOME/bin:$PATH"
    
    if command -v nvim &> /dev/null || [ -f "$HOME/bin/nvim" ]; then
        NEOVIM_INSTALLED=true
        print_status "Neovim installed successfully using AppImage!"
    fi
fi

# Method 5: Install from source as a last resort
if ! $NEOVIM_INSTALLED && [[ "$(uname)" == "Linux" ]]; then
    print_status "Attempting to install Neovim from source (this may take a while)..."
    
    # Install build dependencies
    if command -v apt &> /dev/null; then
        sudo apt update
        sudo apt install -y ninja-build gettext libtool libtool-bin autoconf automake cmake g++ pkg-config unzip curl
    elif command -v yum &> /dev/null; then
        sudo yum install -y ninja-build libtool autoconf automake cmake gcc gcc-c++ make pkgconfig unzip patch gettext curl
    fi
    
    # Clone and build neovim
    cd /tmp
    rm -rf neovim
    git clone https://github.com/neovim/neovim
    cd neovim
    git checkout stable
    make CMAKE_BUILD_TYPE=RelWithDebInfo
    sudo make install
    
    if command -v nvim &> /dev/null; then
        NEOVIM_INSTALLED=true
        print_status "Neovim installed successfully from source!"
    fi
fi

# Verify Neovim installation and display version
if command -v nvim &> /dev/null; then
    NVIM_VERSION=$(nvim --version | head -n 1)
    print_status "Neovim is installed: $NVIM_VERSION"
    
    # Create Neovim configuration directory
    print_status "Setting up Neovim configuration directory..."
    mkdir -p "$HOME/.config/nvim"
else
    print_error "Failed to install Neovim through multiple methods."
    print_warning "Please install Neovim manually after the script completes."
    print_warning "You can visit https://github.com/neovim/neovim/wiki/Installing-Neovim for installation instructions."
fi

# Set up mise as the unified version manager
print_status "Setting up mise as the unified runtime version manager..."
if command -v mise &> /dev/null; then
    # Configure mise in shell if not already configured
    if ! grep -q 'eval "$(mise activate zsh)"' "$HOME/.zprofile"; then
        echo 'eval "$(mise activate zsh)"' >> "$HOME/.zprofile"
    fi
    
    # Create mise config directory with proper permissions
    mkdir -p "$HOME/.config" || sudo mkdir -p "$HOME/.config"
    sudo chown -R $(whoami):$(whoami) "$HOME/.config"
    mkdir -p "$HOME/.config/mise"
    
    # Create base config file if it doesn't exist
    if [ ! -f "$HOME/.config/mise/config.toml" ]; then
        cat > "$HOME/.config/mise/config.toml" << EOF
[settings]
always_keep_download = true
jobs = 4
legacy_version_file = true

[tools]
# Node.js versions
node = ['lts']

# Python versions
python = ['3.12']

# Go versions - use the specific version that's being requested
go = ['1.24.2']

# Rust versions
rust = ['stable']
EOF
    else
        # If config already exists, update Go version in it
        print_status "Updating Go version in mise config..."
        sed -i 's/go = \[.*\]/go = \["1.24.2"\]/' "$HOME/.config/mise/config.toml"
    fi
    
    # Install runtimes with mise
    print_status "Installing Node.js with mise..."
    mise install node@lts
    mise use --global node@lts
    
    # Explicitly install the specific Go version with mise
    print_status "Installing Go 1.24.2 with mise..."
    mise install go@1.24.2
    mise use --global go@1.24.2
    
    # Install global Node.js tools
    if mise which node &> /dev/null; then
        eval "$(mise activate bash)"
        
        print_status "Installing global Node.js development tools..."
        if command -v npm &> /dev/null; then
            npm install -g npm@latest
            npm install -g yarn
            npm install -g pnpm
            npm install -g typescript
            npm install -g electron
            npm install -g electron-packager
            npm install -g expo-cli
            npm install -g create-react-app
            npm install -g create-react-native-app
        else
            print_error "npm not found after Node.js installation. Skipping global tools."
        fi
    else
        print_error "Node.js installation with mise failed. Skipping global tools."
    fi
fi

# Add cloud tools paths to .zprofile for persistence across sessions
print_status "Configuring cloud development environment paths..."

# Create or append to .zprofile
touch "$HOME/.zprofile"

# AWS paths
if [ -d "$HOME/.aws" ]; then
    if ! grep -q "AWS_CONFIG_FILE" "$HOME/.zprofile"; then
        echo '# AWS configuration' >> "$HOME/.zprofile"
        echo 'export AWS_CONFIG_FILE="$HOME/.aws/config"' >> "$HOME/.zprofile"
        echo 'export AWS_SHARED_CREDENTIALS_FILE="$HOME/.aws/credentials"' >> "$HOME/.zprofile"
    fi
fi

# Google Cloud SDK paths
if [[ "$(uname)" == "Linux" ]]; then
    # For Linux
    if [ -d "/usr/lib/google-cloud-sdk" ] && ! grep -q "google-cloud-sdk" "$HOME/.zprofile"; then
        echo '# Google Cloud SDK configuration' >> "$HOME/.zprofile"
        echo 'export CLOUDSDK_ROOT_DIR="/usr/lib/google-cloud-sdk"' >> "$HOME/.zprofile"
        echo 'export PATH="$PATH:/usr/lib/google-cloud-sdk/bin"' >> "$HOME/.zprofile"
    fi
elif [[ "$(uname)" == "Darwin" ]]; then
    # For macOS
    if [ -d "/usr/local/Caskroom/google-cloud-sdk" ] && ! grep -q "google-cloud-sdk" "$HOME/.zprofile"; then
        echo '# Google Cloud SDK configuration' >> "$HOME/.zprofile"
        echo 'export CLOUDSDK_ROOT_DIR="/usr/local/Caskroom/google-cloud-sdk"' >> "$HOME/.zprofile"
        echo 'source "/usr/local/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/path.zsh.inc"' >> "$HOME/.zprofile"
        echo 'source "/usr/local/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/completion.zsh.inc"' >> "$HOME/.zprofile"
    fi
fi

# Azure paths and environment variables
if ! grep -q "AZURE_CONFIG_DIR" "$HOME/.zprofile"; then
    echo '# Azure CLI configuration' >> "$HOME/.zprofile"
    echo 'export AZURE_CONFIG_DIR="$HOME/.azure"' >> "$HOME/.zprofile"
fi

# Firebase config
if command -v firebase &> /dev/null && ! grep -q "FIREBASE_CONFIG" "$HOME/.zprofile"; then
    echo '# Firebase configuration' >> "$HOME/.zprofile"
    echo 'export FIREBASE_CONFIG="$HOME/.config/firebase"' >> "$HOME/.zprofile"
fi

# Install Python tools
print_status "Installing Python tools..."
brew install pyenv
brew install pipx

# Install Go tools
print_status "Installing Go tools..."
brew install go

# Install required packages for SDKMAN
print_status "Installing required packages for SDKMAN..."
if [[ "$(uname)" == "Linux" ]]; then
    sudo apt update
    sudo apt install -y zip unzip
elif [[ "$(uname)" == "Darwin" ]]; then
    brew install zip unzip
fi

# Install SDKMAN if not installed
if [ ! -d "$HOME/.sdkman" ]; then
    print_status "Installing SDKMAN..."
    curl -s "https://get.sdkman.io" | bash
fi

# Install gvm for managing Go versions
print_status "Installing gvm for managing multiple Go versions..."
if [ ! -d "$HOME/.gvm" ]; then
    # Install gvm dependencies
    if [[ "$(uname)" == "Linux" ]]; then
        sudo apt update
        sudo apt install -y bison
    elif [[ "$(uname)" == "Darwin" ]]; then
        brew install bison
    fi
    
    # Install gvm
    bash < <(curl -s -S -L https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer)
    
    # Source gvm
    [[ -s "$HOME/.gvm/scripts/gvm" ]] && source "$HOME/.gvm/scripts/gvm"
    
    # Install latest stable Go version
    print_status "Installing stable Go version with gvm..."
    # First install Go 1.4 (bootstrap version)
    gvm install go1.4 -B
    gvm use go1.4
    # Then install latest stable Go
    gvm install go1.20
    gvm use go1.20 --default
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
    # Use available packages for Ubuntu Noble (24.04)
    sudo apt install -y libgtk-3-dev libwebkit2gtk-4.1-dev libxss-dev \
                       libnss3-dev libasound2-dev libxtst-dev
    
    # Install Wine for Windows builds (optional)
    sudo apt install -y wine64
elif [[ "$(uname)" == "Darwin" ]]; then
    brew install wine
fi

# Install React Native development requirements
print_status "Installing React Native development dependencies..."
if [[ "$(uname)" == "Linux" ]]; then
    sudo apt update
    sudo apt install -y lib32z1 lib32stdc++6 adb
    
    # Install JDK for Android development
    if ! command -v java &> /dev/null; then
        sudo apt install -y openjdk-17-jdk
    fi
    
    # Setup Android SDK path
    mkdir -p "$HOME/Android/Sdk"
    if ! grep -q 'export ANDROID_HOME="$HOME/Android/Sdk"' "$HOME/.zprofile"; then
        echo 'export ANDROID_HOME="$HOME/Android/Sdk"' >> "$HOME/.zprofile"
        echo 'export PATH="$PATH:$ANDROID_HOME/tools:$ANDROID_HOME/tools/bin:$ANDROID_HOME/platform-tools"' >> "$HOME/.zprofile"
    fi
elif [[ "$(uname)" == "Darwin" ]]; then
    brew install --cask android-studio android-platform-tools adoptopenjdk/openjdk/adoptopenjdk11
    if ! grep -q 'export ANDROID_HOME="$HOME/Library/Android/sdk"' "$HOME/.zprofile"; then
        echo 'export ANDROID_HOME="$HOME/Library/Android/sdk"' >> "$HOME/.zprofile"
        echo 'export PATH="$PATH:$ANDROID_HOME/tools:$ANDROID_HOME/tools/bin:$ANDROID_HOME/platform-tools"' >> "$HOME/.zprofile"
    fi
fi

# Install React Native CLI
print_status "Installing React Native CLI..."
if command -v npm &> /dev/null; then
    npm install -g react-native-cli
else
    print_warning "npm not found. Skipping React Native CLI installation."
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

# Install Flutter with OS-specific method
print_status "Installing Flutter..."
if [[ "$(uname)" == "Linux" ]]; then
    # First check and install Flutter dependencies
    sudo apt update
    sudo apt install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-12-dev

    # For Linux/WSL2, use the recommended approach
    if [ ! -d "$HOME/development/flutter" ]; then
        print_status "Downloading Flutter SDK for Linux..."
        mkdir -p "$HOME/development"
        cd "$HOME/development"
        curl -O https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.19.4-stable.tar.xz
        tar xf flutter_linux_*.tar.xz
        rm flutter_linux_*.tar.xz
        FLUTTER_PATH="$HOME/development/flutter/bin"
        if ! grep -q "export PATH=\\\".*${FLUTTER_PATH}.*\\\"" "$HOME/.zprofile"; then
             echo "export PATH=\\"\\$PATH:${FLUTTER_PATH}\\"" >> "$HOME/.zprofile"
        fi

        # Configure Flutter to use proper display
        if [[ -f /proc/version && $(grep -i microsoft /proc/version) ]]; then
            print_status "Configuring Flutter for WSL environment..."
            cd flutter
            bin/flutter config --no-analytics
            bin/flutter config --enable-web
        fi
        
        cd "$HOME"
        print_status "Flutter SDK installed to $HOME/development/flutter"
    else
        print_status "Flutter SDK already installed"
    fi
elif [[ "$(uname)" == "Darwin" ]]; then
    # For macOS, use Homebrew cask
    brew install --cask flutter
fi

# Install database development tools (modified for Ubuntu 24.04)
print_status "Installing database development tools..."
if [[ "$(uname)" == "Linux" ]]; then
    sudo apt update
    
    # PostgreSQL
    print_status "Installing PostgreSQL..."
    sudo apt install -y postgresql postgresql-contrib
    
    # MySQL
    print_status "Installing MySQL..."
    sudo apt install -y mysql-server
    
    # Redis
    print_status "Installing Redis..."
    sudo apt install -y redis-server
    
    # MongoDB installation for Ubuntu (completely rewritten to fix repository issues)
    print_status "Setting up MongoDB..."
    
    # First, remove any existing MongoDB repository files
    print_status "Removing any existing MongoDB repository configurations..."
    sudo rm -f /etc/apt/sources.list.d/mongodb*.list
    
    # Also check and remove any references in the main sources.list
    if grep -q "mongodb" /etc/apt/sources.list; then
        print_status "Removing MongoDB references from main sources.list..."
        sudo sed -i '/mongodb/d' /etc/apt/sources.list
    fi
    
    # Update package lists after removing old repositories
    sudo apt update
    
    # Create a fresh temporary directory for MongoDB setup
    MONGO_TEMP_DIR=$(mktemp -d)
    cd "$MONGO_TEMP_DIR"
    
    # Install MongoDB 6.0 using the jammy repository
    print_status "Adding MongoDB 6.0 GPG key..."
    curl -fsSL https://pgp.mongodb.com/server-6.0.asc | \
        sudo gpg -o /usr/share/keyrings/mongodb-server-6.0.gpg \
        --dearmor
    
    print_status "Adding MongoDB 6.0 repository for jammy..."
    echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-6.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/6.0 multiverse" | \
        sudo tee /etc/apt/sources.list.d/mongodb-org-6.0.list
    
    # Ensure package lists are updated from the new repository
    print_status "Updating package lists with new MongoDB repository..."
    sudo apt update
    
    # Install MongoDB packages
    print_status "Installing MongoDB 6.0..."
    sudo apt install -y mongodb-org
    
    # Clean up
    cd "$HOME"
    rm -rf "$MONGO_TEMP_DIR"
    
    # Don't try to start services in WSL as they may not work with systemd
    if [[ -f /proc/version && ! $(grep -i microsoft /proc/version) ]]; then
        sudo systemctl enable postgresql
        sudo systemctl start postgresql
        sudo systemctl enable mysql
        sudo systemctl start mysql
        sudo systemctl enable redis-server
        sudo systemctl start redis-server
        sudo systemctl enable mongod
        sudo systemctl start mongod
    else
        print_warning "Running in WSL environment. Database services will need to be started manually:"
        print_warning "  PostgreSQL: sudo service postgresql start"
        print_warning "  MySQL: sudo service mysql start"
        print_warning "  Redis: sudo service redis-server start"
        print_warning "  MongoDB: sudo service mongod start"
    fi
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

# Install Firebase tools
print_status "Installing Firebase tools and development environment..."
if command -v npm &> /dev/null; then
    npm install -g firebase-tools
    npm install -g @firebase/cli

    # Initialize Firebase
    print_status "Setting up Firebase configuration directory..."
    mkdir -p "$HOME/.config/firebase"
fi

# Install AWS CLI and development tools
print_status "Installing AWS CLI and development tools..."
if [[ "$(uname)" == "Linux" ]]; then
    # Install AWS CLI v2
    print_status "Installing AWS CLI v2..."
    cd /tmp
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip -q awscliv2.zip
    sudo ./aws/install
    rm -rf aws awscliv2.zip
    
    # Install AWS SAM CLI
    print_status "Installing AWS SAM CLI..."
    # Install prerequisites
    sudo apt update
    sudo apt install -y python3-pip
    pip3 install aws-sam-cli
    
    # Install AWS CDK
    print_status "Installing AWS CDK..."
    if command -v npm &> /dev/null; then
        npm install -g aws-cdk
    fi
    
    # Install AWS Amplify CLI
    print_status "Installing AWS Amplify CLI..."
    if command -v npm &> /dev/null; then
        npm install -g @aws-amplify/cli
    fi
    
    # Install additional AWS tools
    print_status "Installing additional AWS development tools..."
    pip3 install boto3 awscli-local

elif [[ "$(uname)" == "Darwin" ]]; then
    # Install AWS tools via Homebrew
    brew install awscli
    brew install aws-sam-cli
    
    # Install AWS CDK and Amplify via npm
    if command -v npm &> /dev/null; then
        npm install -g aws-cdk
        npm install -g @aws-amplify/cli
    fi
    
    # Install additional AWS tools
    pip3 install boto3 awscli-local
fi

# Create AWS config directory
mkdir -p "$HOME/.aws"

# Install Google Cloud SDK
print_status "Installing Google Cloud SDK..."
if [[ "$(uname)" == "Linux" ]]; then
    # Install dependencies
    sudo apt update
    sudo apt install -y apt-transport-https ca-certificates gnupg curl
    
    # Add Google Cloud SDK distribution URI as a package source
    print_status "Adding Google Cloud SDK repository..."
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
    
    # Import Google Cloud public key
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
    
    # Update and install the SDK
    sudo apt update
    sudo apt install -y google-cloud-sdk google-cloud-sdk-app-engine-python google-cloud-sdk-app-engine-python-extras google-cloud-sdk-datastore-emulator google-cloud-sdk-pubsub-emulator
    
    # Install Firebase emulator dependencies
    sudo apt install -y openjdk-17-jdk
    
elif [[ "$(uname)" == "Darwin" ]]; then
    # Install Google Cloud SDK via Homebrew
    brew install --cask google-cloud-sdk
fi

# Initialize gcloud directory
mkdir -p "$HOME/.config/gcloud"

# Install Firebase emulators if npm is available
if command -v npm &> /dev/null && command -v firebase &> /dev/null; then
    print_status "Setting up Firebase emulators..."
    firebase setup:emulators:firestore
    firebase setup:emulators:database
    firebase setup:emulators:pubsub
    firebase setup:emulators:storage
    firebase setup:emulators:ui
fi

# Install Azure CLI and development tools
print_status "Installing Azure CLI and development tools..."
if [[ "$(uname)" == "Linux" ]]; then
    # Install dependencies
    sudo apt update
    sudo apt install -y ca-certificates curl apt-transport-https lsb-release gnupg
    
    # Download and install the Microsoft signing key
    print_status "Adding Microsoft repository..."
    curl -sL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/microsoft.gpg > /dev/null
    
    # Add the Azure CLI software repository
    AZ_REPO=$(lsb_release -cs)
    if [[ "$AZ_REPO" == "noble" ]]; then
        # Use jammy repo for noble (24.04) until dedicated repo is available
        AZ_REPO="jammy"
    fi
    echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" | sudo tee /etc/apt/sources.list.d/azure-cli.list
    
    # Update repository and install Azure CLI
    sudo apt update
    sudo apt install -y azure-cli
    
    # Install Azure Functions Core Tools
    print_status "Installing Azure Functions Core Tools..."
    curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
    sudo mv microsoft.gpg /etc/apt/trusted.gpg.d/microsoft.gpg
    sudo sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/microsoft-ubuntu-$(lsb_release -cs)-prod $(lsb_release -cs) main" > /etc/apt/sources.list.d/dotnetdev.list'
    sudo apt update
    sudo apt install -y azure-functions-core-tools-4
    
    # Install Azure Dev CLI
    print_status "Installing Azure Dev CLI..."
    curl -fsSL https://aka.ms/install-azd.sh | bash
    
    # Install Azure Static Web Apps CLI
    if command -v npm &> /dev/null; then
        npm install -g @azure/static-web-apps-cli
    fi
    
elif [[ "$(uname)" == "Darwin" ]]; then
    # Install Azure CLI via Homebrew
    brew install azure-cli
    
    # Install Azure Functions Core Tools
    brew tap azure/functions
    brew install azure-functions-core-tools@4
    
    # Install Azure Dev CLI
    brew install azure/azd/azd
    
    # Install Azure Static Web Apps CLI
    if command -v npm &> /dev/null; then
        npm install -g @azure/static-web-apps-cli
    fi
fi

# Create Azure config directory
mkdir -p "$HOME/.azure"

# Create aliases for cloud development
print_status "Creating cloud development aliases..."
cat > "$HOME/.config/zsh/cloud_aliases.zsh" << EOF
# Firebase aliases
alias fb='firebase'
alias fbdeploy='firebase deploy'
alias fbserve='firebase serve'
alias fbemu='firebase emulators:start'

# AWS aliases
alias awsp='aws --profile'
alias cdks='cdk synth'
alias cdkd='cdk deploy'
alias cdkdiff='cdk diff'
alias samd='sam deploy'
alias samb='sam build'
alias saml='sam local'

# Google Cloud aliases
alias gcl='gcloud'
alias gcauth='gcloud auth login'
alias gcconf='gcloud config'
alias gcproj='gcloud config set project'

# Azure aliases
alias azl='az login'
alias azacct='az account show'
alias azgroup='az group'
alias azfunc='func'
alias azdeploy='az deployment'
EOF

# Add cloud aliases to zshrc if not already included
if [ -f "$HOME/.zshrc" ]; then
    if ! grep -q "source \$HOME/.config/zsh/cloud_aliases.zsh" "$HOME/.zshrc"; then
        echo '# Load cloud development aliases' >> "$HOME/.zshrc"
        echo 'if [ -f "$HOME/.config/zsh/cloud_aliases.zsh" ]; then' >> "$HOME/.zshrc"
        echo '  source $HOME/.config/zsh/cloud_aliases.zsh' >> "$HOME/.zshrc"
        echo 'fi' >> "$HOME/.zshrc"
    fi
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
    
    # Add WSL-specific settings to .zprofile if not already present
    if ! grep -q "# WSL2-specific settings" "$HOME/.zprofile"; then
        cat >> "$HOME/.zprofile" << EOF

# WSL2-specific settings
export BROWSER=wslview
export DISPLAY=:0
# Improve Docker performance on WSL2
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1
EOF
    fi

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
        print_warning "You may need to restart your terminal or run 'source ~/.zprofile' to update PATH"
        INSTALLATION_ISSUES=true
        return 1
    fi
}

# Check shell tools
verify_tool zsh
verify_tool git
verify_tool nvim
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

# Check cloud development tools
print_status "Verifying cloud development tools..."

# Check Firebase tools
if verify_tool firebase; then
    FIREBASE_VERSION=$(firebase --version)
    print_status "Firebase CLI version: $FIREBASE_VERSION"
else
    print_warning "Firebase CLI not found. You may need to restart your terminal or run 'npm install -g firebase-tools'"
fi

# Check AWS CLI
if verify_tool aws; then
    AWS_VERSION=$(aws --version)
    print_status "AWS CLI version: $AWS_VERSION"
    
    # Check AWS CDK
    if verify_tool cdk; then
        CDK_VERSION=$(cdk --version)
        print_status "AWS CDK version: $CDK_VERSION"
    fi
    
    # Check AWS SAM CLI
    if verify_tool sam; then
        SAM_VERSION=$(sam --version)
        print_status "AWS SAM CLI version: $SAM_VERSION"
    fi
    
    # Check AWS Amplify CLI
    if verify_tool amplify; then
        AMPLIFY_VERSION=$(amplify --version)
        print_status "AWS Amplify CLI version: $AMPLIFY_VERSION"
    fi
else
    print_warning "AWS CLI not found. You may need to restart your terminal or check the AWS installation"
fi

# Check Google Cloud SDK
if verify_tool gcloud; then
    GCLOUD_VERSION=$(gcloud --version | head -n 1)
    print_status "Google Cloud SDK: $GCLOUD_VERSION"
else
    print_warning "Google Cloud SDK not found. You may need to restart your terminal or check the gcloud installation"
fi

# Check Azure CLI
if verify_tool az; then
    AZ_VERSION=$(az --version | grep "azure-cli" | head -n 1)
    print_status "Azure CLI: $AZ_VERSION"
    
    # Check Azure Functions Core Tools
    if verify_tool func; then
        FUNC_VERSION=$(func --version)
        print_status "Azure Functions Core Tools version: $FUNC_VERSION"
    fi
    
    # Check Azure Developer CLI
    if verify_tool azd; then
        AZD_VERSION=$(azd version)
        print_status "Azure Developer CLI version: $AZD_VERSION"
    fi
else
    print_warning "Azure CLI not found. You may need to restart your terminal or check the Azure CLI installation"
fi

# Final message
if [ "$INSTALLATION_ISSUES" = true ]; then
    print_warning "Some issues were detected with your installation. Please review the warnings above."
    print_status "You may need to restart your terminal or run 'source ~/.zprofile' to apply all changes."
else
    print_status "Installation verification complete! All critical components are installed."
fi

print_status "Setup complete! Please restart your terminal and run 'p10k configure' to set up your prompt."
