# ~/.bash_profile — GrgOS
[[ -f ~/.bashrc ]] && . ~/.bashrc

# Auto-start Hyprland on the first virtual terminal (no display manager needed).
if [[ -z "${WAYLAND_DISPLAY:-}" ]] && [[ "${XDG_VTNR:-}" == "1" ]]; then
  exec Hyprland
fi
