# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Fix while SSH using Kitty
[ "$TERM" = "xterm-kitty" ] && alias ssh="kitty +kitten ssh"

ZSH_THEME="powerlevel10k/powerlevel10k"

# # Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# # Initialization code that may require console input (password prompts, [y/n]
# # confirmations, etc.) must go above this block; everything else may go below.
# if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
#   source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
# fi
#
# # If you come from bash you might have to change your $PATH.
# # export PATH=$HOME/bin:/usr/local/bin:$PATH
#
# # Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"
source $ZSH/oh-my-zsh.sh
# # User configuration
#
# # export MANPATH="/usr/local/man:$MANPATH"
#
# # You may need to manually set your language environment
# # export LANG=en_US.UTF-8
#
# # Preferred editor for local and remote sessions
# # if [[ -n $SSH_CONNECTION ]]; then
# #   export EDITOR='vim'
# # else
# #   export EDITOR='mvim'
# # fi
#
# # Compilation flags
# # export ARCHFLAGS="-arch x86_64"
#
# # Set personal aliases, overriding those provided by oh-my-zsh libs,
# # plugins, and themes. Aliases can be placed here, though oh-my-zsh
# # users are encouraged to define aliases within the ZSH_CUSTOM folder.
# # For a full list of active aliases, run `alias`.
# #
# # Example aliases
# # alias zshconfig="mate ~/.zshrc"
# # alias ohmyzsh="mate ~/.oh-my-zsh"
# # linuxbrew
# # # TODO: add logic to check if linux or mac
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
export PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"


# # Custom Alias
alias vi="nvim"
# alias tmux="tmux -CC"
alias aws='docker run --rm -ti -v ~/.aws:/root/.aws -v $(pwd):/aws amazon/aws-cli'
alias swagger='docker run --rm -it  --user $(id -u):$(id -g) -v $HOME:$HOME -w $PWD ghcr.io/go-swagger/go-swagger'
swagger version
#
# # Custom Plugin
source ~/.config/zsh/antigen.zsh
#
# # Antigen Manager
# antigen theme romkatv/powerlevel10k
antigen bundle git
antigen bundle aws
antigen bundle zsh-users/zsh-autosuggestions
antigen bundle zsh-users/zsh-syntax-highlighting
antigen bundle dgnest/zsh-gvm-plugin
antigen bundle agkozak/zsh-z
antigen bundle ahmetb/kubectx
antigen bundle MichaelAquilina/zsh-you-should-use
antigen bundle fdellwing/zsh-bat
antigen bundle tmux
antigen apply

# # Which plugins would you like to load?
# # Standard plugins can be found in $ZSH/plugins/
# # Custom plugins may be added to $ZSH_CUSTOM/plugins/
# # Example format: plugins=(rails git textmate ruby lighthouse)
# # Add wisely, as too many plugins slow down shell startup.
plugins=($plugins aws git tmux)

# # GVM
[[ -s "$HOME/.gvm/scripts/gvm" ]] && source "$HOME/.gvm/scripts/gvm"
# # FNM
eval "$(fnm env --use-on-cd)"

# # Path
export ANDROID_HOME=~/Library/Android/sdk
export PATH=$PATH:"$ANDROID_HOME/platform-tools"
export PATH=$PATH:"$ANDROID_HOME/emulator"
export PATH=$PATH:"/opt/homebrew/opt/openjdk/bin"
export CPPFLAGS="-I/opt/homebrew/opt/openjdk/include"
export PATH=:$PATH:$(pyenv root)/shims
#
# ## Flutter
export PATH=$PATH:"$HOME/.pub-cache/bin"
#
# ## Kube Krew
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
#
# ## GO
export PATH=$PATH:$(go env GOPATH)/bin
#
# # Custom Script
# ## Load Config Kube *.k8s.config
for kconfig in $HOME/.kube/config $(find $HOME/.kube/ -iname "*.k8s.config")
do
         if [ -f "$kconfig" ];then
                 export KUBECONFIG=$KUBECONFIG:$kconfig
         fi
done
#
# #THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
# export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"
#
# # pyenv
export PYENV_ROOT="$HOME/.pyenv"
command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
eval "$(/usr/bin/rbenv init - zsh)"

autoload -U +X bashcompinit && bashcompinit
complete -o nospace -C /opt/homebrew/bin/terraform terraform
export PATH="/usr/local/opt/libpq/bin:$PATH"
#
#
# # bit
case ":$PATH:" in
  *":/Users/riez/bin:"*) ;;
  *) export PATH="$PATH:/Users/riez/bin" ;;
esac
# # bit end
#
# # pnpm
export PNPM_HOME="/Users/riez/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# # pnpm end

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# # ZSH Highlight & Suggestion Setting
# ## Zsh-autosuggestions is designed to be relatively unobtrusive
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=246'
#
# ##These plugins should be sourced at the end of the file and in this order, as per https://github.com/softmoth/zsh-vim-mode and https://github.com/zsh-users/zsh-syntax-highlighting
# source $HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
# source $HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

ZSH_TMUX_ITERM2=false

[[ -s "/home/famtqn/.gvm/scripts/gvm" ]] && source "/home/famtqn/.gvm/scripts/gvm"
