# ~/.bashrc — GrgOS
# Interactive-only guard.
[[ $- != *i* ]] && return

# ---- history ----------------------------------------------------------------
HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoreboth:erasedups
shopt -s histappend checkwinsize

# ---- PATH -------------------------------------------------------------------
# pipx apps, user-local bins, npm globals.
export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"
export NPM_CONFIG_PREFIX="$HOME/.npm-global"

# ---- editor -----------------------------------------------------------------
export EDITOR=nvim
export VISUAL=nvim

# ---- Wayland / theming hints for CLI-launched GUI apps ----------------------
export MOZ_ENABLE_WAYLAND=1
export QT_QPA_PLATFORMTHEME=qt6ct
export GTK_THEME=Adwaita:dark

# ---- aliases ----------------------------------------------------------------
if command -v eza >/dev/null 2>&1; then
  alias ls='eza --group-directories-first --icons=auto'
  alias ll='eza -lah --group-directories-first --icons=auto --git'
  alias tree='eza --tree --icons=auto'
else
  alias ls='ls --color=auto'
  alias ll='ls -lah'
fi
command -v bat >/dev/null 2>&1 && alias cat='bat --style=plain --paging=never'
alias grep='grep --color=auto'
alias ..='cd ..'
alias ...='cd ../..'
alias gs='git status'
alias gl='git log --oneline --graph --decorate --all'
alias grgos-setup='sudo /usr/local/share/grgos/scripts/install.sh'

# ---- prompt (starship) ------------------------------------------------------
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init bash)"
else
  PS1='\[\e[1;35m\]\u@grgos\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\]\$ '
fi

# ---- fzf keybindings (if installed) -----------------------------------------
[[ -f /usr/share/fzf/key-bindings.bash ]] && . /usr/share/fzf/key-bindings.bash
[[ -f /usr/share/fzf/completion.bash ]]   && . /usr/share/fzf/completion.bash

# ---- a friendly greeting in a plain login shell -----------------------------
if [[ -z "${WAYLAND_DISPLAY:-}" ]] && command -v fastfetch >/dev/null 2>&1; then
  fastfetch
fi
