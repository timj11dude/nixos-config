# used in interactive shells

# Path to your oh-my-zsh installation.
export ZSH="/home/timj/.oh-my-zsh"
ZSH_THEME="agnoster-custom"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

plugins=(git docker)

source $ZSH/oh-my-zsh.sh

# User configuration

# Added by serverless binary installer
export PATH="$HOME/.serverless/bin:$PATH"

export PATH="$HOME/.poetry/bin:$PATH"

# sdkman could be unnecessary once nix is properly configured
#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="/home/timj/.sdkman"
[[ -s "/home/timj/.sdkman/bin/sdkman-init.sh" ]] && source "/home/timj/.sdkman/bin/sdkman-init.sh"

# my aliases
source ~/.zsh_aliases

# GPG SSH AGENT
export GPG_TTY=$(tty)
unset SSH_AGENT_PID
if [ "${gnupg_SSH_AUTH_SOCK_by:-0}" -ne $$ ]; then
  export SSH_AUTH_SOCK="$(gpgconf --list-dirs agent-ssh-socket)"
fi
