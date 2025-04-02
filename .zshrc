# Enable Powerlevel10k instant prompt
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Oh My Zsh Configuration
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
source $ZSH/oh-my-zsh.sh

# Path Configuration
export PATH=$HOME/bin:/usr/local/bin:/usr/local/sbin:~/bin:$PATH

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
if [[ -f ~/.config/zsh/antigen.zsh ]]; then
    source ~/.config/zsh/antigen.zsh

    antigen theme romkatv/powerlevel10k
    antigen bundles <<EOBUNDLES
        git
        aws
        $(command -v tmux &> /dev/null && echo "tmux")
        $(command -v docker &> /dev/null && echo "docker")
        $(command -v docker-compose &> /dev/null && echo "docker-compose")
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
if [[ $IS_WSL == true ]]; then
    ZSH_TMUX_ITERM2=false
    alias tmux="tmux -CC"
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

## Pyenv (Python)
if command -v pyenv &> /dev/null; then
    export PYENV_ROOT="$HOME/.pyenv"
    command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init -)"
else
    echo "pyenv not found. Install with: brew install pyenv"
fi

## Rbenv (Ruby)
if command -v rbenv &> /dev/null; then
    eval "$(rbenv init - zsh)"
else
    echo "rbenv not found. Install with: brew install rbenv"
fi

# Package Managers
## Homebrew
if command -v brew &> /dev/null; then
    if [[ $IS_LINUX == true ]]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        export PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"
    elif [[ $IS_MAC == true ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
        export PATH="/opt/homebrew/bin:$PATH"
    fi
else
    echo "Homebrew not found. Install from: https://brew.sh"
fi

## PNPM
export PNPM_HOME="$HOME/Library/pnpm"
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
if [[ $IS_MAC == true ]]; then
    export ANDROID_HOME=~/Library/Android/sdk
elif [[ $IS_LINUX == true ]]; then
    export ANDROID_HOME=$HOME/Android/Sdk
fi

if [[ -d "$ANDROID_HOME" ]]; then
    export PATH=$PATH:"$ANDROID_HOME/platform-tools"
    export PATH=$PATH:"$ANDROID_HOME/emulator"
fi

## Java
if [[ $IS_MAC == true ]]; then
    export PATH=$PATH:"/opt/homebrew/opt/openjdk/bin"
    export CPPFLAGS="-I/opt/homebrew/opt/openjdk/include"
fi

## Flutter
[[ -d "$HOME/.pub-cache/bin" ]] && export PATH=$PATH:"$HOME/.pub-cache/bin"

## Go
[[ -n "$(command -v go)" ]] && export PATH=$PATH:$(go env GOPATH)/bin

## Kubernetes
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
for kconfig in $HOME/.kube/config $(find $HOME/.kube/ -iname "*.k8s.config" 2>/dev/null)
do
    if [ -f "$kconfig" ]; then
        export KUBECONFIG=$KUBECONFIG:$kconfig
    fi
done

## Terraform
if [[ $IS_MAC == true ]]; then
    autoload -U +X bashcompinit && bashcompinit
    complete -o nospace -C /opt/homebrew/bin/terraform terraform
    export PATH="/usr/local/opt/libpq/bin:$PATH"
fi

# Custom Aliases
alias vi="nvim"
alias aws='docker run --rm -ti -v ~/.aws:/root/.aws -v $(pwd):/aws amazon/aws-cli'
alias swagger='docker run --rm -it  --user $(id -u):$(id -g) -v $HOME:$HOME -w $PWD ghcr.io/go-swagger/go-swagger'

# Local bin
case ":$PATH:" in
    *":$HOME/bin:"*) ;;
    *) export PATH="$PATH:$HOME/bin" ;;
esac

# Load Powerlevel10k Theme
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Added by Windsurf
export PATH="/Users/riez/.codeium/windsurf/bin:$PATH"
