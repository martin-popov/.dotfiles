# vi mode (before plugins so fzf binds into the right keymaps)
bindkey -v

# node (fnm)
eval "$(fnm env --use-on-cd)"

# plugins
source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source <(fzf --zsh)

# editor
export EDITOR=nvim
alias vim=nvim

# history
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt SHARE_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_SPACE

# paths: pnpm, rust, go (default GOPATH), uv tools
export PNPM_HOME="$HOME/Library/pnpm"
export PATH="$PNPM_HOME:$HOME/.cargo/bin:$HOME/go/bin:$HOME/.local/bin:$PATH"

# prompt
eval "$(starship init zsh)"
