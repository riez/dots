export LANG=en_US.UTF-8

# Set default TERM if not set to avoid tput errors
export TERM=${TERM:-xterm-256color}

# Disable gitstatus debug logging to prevent initialization errors
# GITSTATUS_LOG_LEVEL=DEBUG

# Enable Powerlevel10k instant prompt
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  # Fix for bogus screen size issue
  export COLUMNS=80
  export LINES=24
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

[[ "$TERM_PROGRAM" == "vscode" ]] && . "$(code-insiders --locate-shell-integration-path zsh)"


# Oh My Zsh Configuration
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

# Disable monitor mode to prevent setopt errors in non-interactive contexts
if [[ -o interactive ]]; then
    setopt monitor
fi

# Only source Oh My Zsh if the directory exists and we're in a proper shell
if [[ -d "$ZSH" && -n "$ZSH_VERSION" ]]; then
    source $ZSH/oh-my-zsh.sh
fi

# Path Configuration
export PATH="$HOME/bin:/usr/local/bin:/usr/local/sbin:~/bin:$PATH"

# System Detection
IS_LINUX=false
IS_MAC=false
IS_WSL=false

if [[ "$(uname)" == "Linux" ]]; then
    IS_LINUX=true
    if grep -qEi "(Microsoft|WSL)" /proc/version &> /dev/null; then
        IS_WSL=true
    fi
elif [[ "$(uname)" == "Darwin" ]]; then
    IS_MAC=true
fi

# Antigen Plugin Manager
if [[ -f "$HOME/.config/zsh/antigen.zsh" ]]; then
    source "$HOME/.config/zsh/antigen.zsh"

    antigen bundles <<EOBUNDLES
        git
        aws
        tmux
        docker
        docker-compose
        zsh-users/zsh-autosuggestions
        zsh-users/zsh-syntax-highlighting
        dgnest/zsh-gvm-plugin
        agkozak/zsh-z
        ahmetb/kubectx
        MichaelAquilina/zsh-you-should-use
        fdellwing/zsh-bat
EOBUNDLES
    antigen apply
else
    echo "antigen not found. Install with: mkdir -p ~/.config/zsh && curl -L git.io/antigen > ~/.config/zsh/antigen.zsh"
fi

# Terminal Settings
[ "$TERM" = "xterm-kitty" ] && alias ssh="kitty +kitten ssh"
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=246'

# WSL-specific settings
if [[ "$IS_WSL" == true ]]; then
    ZSH_TMUX_ITERM2=false
    alias tmux="tmux -CC"
    # Add Rancher Desktop to PATH if installed
    if [[ -d "/mnt/c/Users" ]]; then
        # Get Windows username by finding the first directory that isn't Public or Default
        WIN_USERNAME=$(ls -1 /mnt/c/Users/ | grep -v "Public\|Default\|All Users\|Default User\|desktop.ini" | head -1)
        if [[ -n "$WIN_USERNAME" ]]; then
            # Construct the potential Rancher Desktop path
            POTENTIAL_RANCHER_PATH="/mnt/c/Users/$WIN_USERNAME/AppData/Local/Programs/Rancher Desktop/resources/resources/linux"

            # Check if the Rancher Desktop path actually exists
            if [[ -d "$POTENTIAL_RANCHER_PATH" ]]; then
                export RANCHER_PATH="$POTENTIAL_RANCHER_PATH"

                # Add Rancher Desktop directories to PATH
                export PATH="$PATH:$RANCHER_PATH/bin"
                export PATH="$PATH:$RANCHER_PATH/docker-cli-plugins"
                export PATH="$PATH:$RANCHER_PATH/internal" # Add internal if needed, be cautious

                # Create links to binaries in a location without spaces ($HOME/bin)
                mkdir -p "$HOME/bin"

                # Link binaries from the bin directory
                for file in "$RANCHER_PATH/bin"/*; do
                    if [[ -f "$file" && -x "$file" ]]; then
                        binary_name=$(basename "$file")
                        ln -sf "$file" "$HOME/bin/$binary_name" 2>/dev/null
                    fi
                done

                # Link binaries from docker-cli-plugins directory
                if [[ -d "$RANCHER_PATH/docker-cli-plugins" ]]; then
                    for file in "$RANCHER_PATH/docker-cli-plugins"/*; do
                        if [[ -f "$file" && -x "$file" ]]; then
                            binary_name=$(basename "$file")
                            ln -sf "$file" "$HOME/bin/$binary_name" 2>/dev/null
                        fi
                    done
                fi

                # Link specific important binaries from internal directory if needed
                if [[ -d "$RANCHER_PATH/internal" ]]; then
                    for file in "$RANCHER_PATH/internal"/*; do
                        if [[ -f "$file" && -x "$file" ]]; then
                            binary_name=$(basename "$file")
                            # Only link specific internal binaries as needed
                            if [[ "$binary_name" == "containerd" || "$binary_name" == "nerdctl" || "$binary_name" == "ctr" ]]; then
                                ln -sf "$file" "$HOME/bin/$binary_name" 2>/dev/null
                            fi
                        fi
                    done
                fi

                # Configure Docker to use Rancher Desktop properly
                DOCKER_BIN="$HOME/bin/docker"
                if [[ -x "$DOCKER_BIN" ]]; then
                    # Make sure we're not using DOCKER_HOST variable which can override the context
                    unset DOCKER_HOST

                    # Find the Rancher Desktop Docker socket from possible locations
                    SOCKET_PATHS=(
                        "$HOME/.rd/docker.sock"                                 # Standard path
                        "/run/rancher-desktop/docker.sock"                      # Alternative path
                        "/run/user/$(id -u)/docker.sock"                        # User-specific path
                        "/mnt/wsl/rancher-desktop/run/docker.sock"              # WSL-specific Rancher path 
                        "/mnt/wsl/docker-desktop/docker.sock"                   # Docker Desktop path (fallback)
                    )
                    
                    # Try to find the socket from standard locations
                    RD_SOCKET=""
                    for sock in "${SOCKET_PATHS[@]}"; do
                        if [[ -S "$sock" ]]; then
                            RD_SOCKET="$sock"
                            break
                        fi
                    done
                    
                    # If not found in standard locations, check Windows paths
                    if [[ -z "$RD_SOCKET" ]]; then
                        # Try to find it in Windows paths
                        if [[ -n "$WIN_USERNAME" ]]; then
                            WIN_SOCKET_PATHS=(
                                "/mnt/c/Users/$WIN_USERNAME/.rd/docker.sock"
                                "/mnt/c/Users/$WIN_USERNAME/AppData/Local/rancher-desktop/run/docker.sock"
                                "/mnt/c/Users/$WIN_USERNAME/AppData/Roaming/rancher-desktop/run/docker.sock"
                            )
                            
                            for sock in "${WIN_SOCKET_PATHS[@]}"; do
                                if [[ -S "$sock" ]]; then
                                    RD_SOCKET="$sock"
                                    break
                                fi
                            done
                        fi
                    fi
                    
                    # Handle case when no socket is found
                    if [[ -z "$RD_SOCKET" ]]; then
                        echo "Error: No Docker socket found. Ensure Rancher Desktop is running with WSL integration enabled."
                    else
                        # Fix socket permissions if needed
                        if ! $DOCKER_BIN --host "unix://$RD_SOCKET" info &>/dev/null; then
                            echo "Permission denied on socket: $RD_SOCKET - attempting to fix..."
                            
                            # Try to fix permissions with sudo
                            if command -v sudo &>/dev/null; then
                                # Create docker group and add user if needed
                                if ! groups | grep -q docker; then
                                    sudo groupadd docker 2>/dev/null || true
                                    sudo usermod -aG docker $(whoami)
                                    echo "Added user to docker group. You may need to restart your terminal session for this to take effect."
                                fi
                                
                                # Temporarily fix socket permissions
                                sudo chmod 666 "$RD_SOCKET" 2>/dev/null || echo "Failed to adjust permissions."
                            fi
                        fi
                        
                        # Set DOCKER_HOST explicitly to ensure all Docker commands use this socket
                        export DOCKER_HOST="unix://$RD_SOCKET"
                        
                    fi
                fi

                # Fix Docker credential helper if config doesn't exist
                mkdir -p "$HOME/.docker"
                if [[ ! -f "$HOME/.docker/config.json" ]]; then
                    echo '{
  "auths": {},
  "currentContext": "rancher-desktop",
  "credsStore": "desktop"
}' > "$HOME/.docker/config.json"
                elif ! grep -q '"currentContext": "rancher-desktop"' "$HOME/.docker/config.json"; then
                     # If config exists but doesn't have the context set, update it (simple approach)
                     # A more robust solution would parse and modify the JSON properly
                     sed -i 's/"currentContext": "[^"]*"/"currentContext": "rancher-desktop"/' "$HOME/.docker/config.json"
                fi

            else
                 echo "Rancher Desktop path not found for user $WIN_USERNAME at $POTENTIAL_RANCHER_PATH"
            fi
        else
            echo "Could not determine Windows username in /mnt/c/Users/"
        fi
    fi
    # Add any other WSL-specific configurations here
fi

# Version Managers
## GVM (Go)
[[ -s "$HOME/.gvm/scripts/gvm" ]] && source "$HOME/.gvm/scripts/gvm"

## FNM (Node.js)
if command -v fnm &> /dev/null; then
    eval "$(fnm env --use-on-cd)"
else
    echo "fnm not found. Install with: brew install fnm"
fi

## Mise (Runtime Manager)
if command -v mise &> /dev/null; then
    eval "$(mise activate zsh)"
else
    echo "mise not found. Install with: brew install mise"
fi

# ## Pyenv (Python)
# if command -v pyenv &> /dev/null; then
#     export PYENV_ROOT="$HOME/.pyenv"
#     command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
#     eval "$(pyenv init -)"
# else
#     echo "pyenv not found. Install with: brew install pyenv"
# fi

# ## Rbenv (Ruby)
# if command -v rbenv &> /dev/null; then
#     eval "$(rbenv init - zsh)"
# else
#     echo "rbenv not found. Install with: brew install rbenv"
# fi

# Package Managers
## Homebrew
if command -v brew &> /dev/null; then
    if [[ "$IS_LINUX" == true ]]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        export PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"
    elif [[ "$IS_MAC" == true ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
        export PATH="/opt/homebrew/bin:$PATH"
    fi
else
    echo "Homebrew not found. Install from: https://brew.sh"
fi

## PNPM
export PNPM_HOME=""
case ":$PATH:" in
    *":$PNPM_HOME:"*) ;;
    *) export PATH="$PNPM_HOME:$PATH" ;;
esac

## Bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

## SDKMAN
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"

## Pipx
export PATH="$PATH:$HOME/.local/bin"

## Cargo (Rust)
[[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"

# Development Tools
## Android
if [[ "$IS_MAC" == true ]]; then
    export ANDROID_HOME=~/Library/Android/sdk
elif [[ "$IS_LINUX" == true ]]; then
    export ANDROID_HOME=$HOME/Android/Sdk
fi

if [[ -d "$ANDROID_HOME" ]]; then
    export PATH=$PATH:"$ANDROID_HOME/platform-tools"
    export PATH=$PATH:"$ANDROID_HOME/emulator"
fi

## Java
if [[ "$IS_MAC" == true ]]; then
    export PATH=$PATH:"/opt/homebrew/opt/openjdk/bin"
    export CPPFLAGS="-I/opt/homebrew/opt/openjdk/include"
fi

## Flutter
[[ -d "$HOME/.pub-cache/bin" ]] && export PATH=$PATH:"$HOME/.pub-cache/bin"

## Go
[[ -n "$(command -v go)" ]] && export PATH=$PATH:$(go env GOPATH)/bin

## Kubernetes
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
for kconfig in $HOME/.kube/config $(find $HOME/.kube/ -iname "*.k8s.config" 2>/dev/null); do
    if [ -f "$kconfig" ]; then
        export KUBECONFIG=$KUBECONFIG:$kconfig
    fi
done

## Terraform
if [[ "$IS_MAC" == true ]]; then
    autoload -U +X bashcompinit && bashcompinit
    complete -o nospace -C /opt/homebrew/bin/terraform terraform
    export PATH="/usr/local/opt/libpq/bin:$PATH"
fi

# Custom Aliases
alias vi="nvim"

# Docker-dependent aliases - only define if Docker is available
# if command -v docker &> /dev/null; then
#     alias aws='docker run --rm -ti -v ~/.aws:/root/.aws -v $(pwd):/aws amazon/aws-cli'
#     alias swagger='docker run --rm -it  --user $(id -u):$(id -g) -v $HOME:$HOME -w $PWD ghcr.io/go-swagger/go-swagger'
# else
#     echo "Docker not found. Some aliases requiring Docker were not defined."
# fi

# Local bin
case ":$PATH:" in
    *":$HOME/bin:"*) ;;
    *) export PATH="$PATH:$HOME/bin" ;;
esac

# Load Powerlevel10k Theme with gitstatus safeguards
if [[ -f ~/.p10k.zsh ]]; then
    # Set gitstatus environment variables to prevent errors
    export GITSTATUS_LOG_LEVEL=${GITSTATUS_LOG_LEVEL:-INFO}
    export GITSTATUS_NUM_THREADS=${GITSTATUS_NUM_THREADS:-2}
    
    source ~/.p10k.zsh
fi

# Added by Windsurf
export PATH="$HOME/.codeium/windsurf/bin:$PATH"

# Google Cloud SDK Configuration
# Check if the Google Cloud SDK is installed in the default location ($HOME/google-cloud-sdk)
# or if GCLOUD_SDK_PATH is set manually.
_GCLOUD_SDK_PATH="${GCLOUD_SDK_PATH:-$HOME/google-cloud-sdk}"

if [ -d "$_GCLOUD_SDK_PATH" ]; then
    # Update PATH for the Google Cloud SDK.
    if [ -f "$_GCLOUD_SDK_PATH/path.zsh.inc" ]; then
        . "$_GCLOUD_SDK_PATH/path.zsh.inc"
    fi

    # Enable shell command completion for gcloud.
    if [ -f "$_GCLOUD_SDK_PATH/completion.zsh.inc" ]; then
        . "$_GCLOUD_SDK_PATH/completion.zsh.inc"
    fi
fi
# Clean up temporary variable
unset _GCLOUD_SDK_PATH
# Load cloud development aliases
if [ -f "$HOME/.config/zsh/cloud_aliases.zsh" ]; then
  source $HOME/.config/zsh/cloud_aliases.zsh
fi
# The following lines have been added by Docker Desktop to enable Docker CLI completions.
fpath=($HOME/.docker/completions $fpath)
autoload -Uz compinit
compinit
# End of Docker CLI completions
