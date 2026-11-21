case "$(uname -s)" in
  Darwin)
    if [[ -d "/Applications/Obsidian.app/Contents/MacOS" ]]; then
      export PATH="$PATH:/Applications/Obsidian.app/Contents/MacOS"
    fi

    if [[ -x "/opt/homebrew/bin/brew" ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
    ;;
  Linux)
    if [[ $- == *i* ]] && [[ -o login ]] && [[ -z "${SSH_CONNECTION:-}" ]] && [[ -z "${DISPLAY:-}" ]] && [[ -z "${WAYLAND_DISPLAY:-}" ]] && [[ "${XDG_VTNR:-}" == "1" ]]; then
      if command -v uwsm >/dev/null 2>&1; then
        exec uwsm start hyprland.desktop
      elif command -v start-hyprland >/dev/null 2>&1; then
        exec start-hyprland
      fi
    fi
    ;;
esac

# Created by `pipx` on 2026-04-16 00:31:38
if [[ "$OSTYPE" == darwin* ]]; then
  export PATH="$PATH:/Users/iragonforce/.local/bin"
fi
export HOMEBREW_NO_ENV_HINTS=1

if [[ $- == *i* ]] && [[ -o login ]] && [[ -z "${TMUX:-}" ]] && [[ -t 0 ]] && [[ -t 1 ]] && [[ -x "$HOME/.config/tmux/session" ]]; then
  if [[ ${TERM:-dumb} == dumb ]]; then
    export TERM=xterm-256color
  fi
  export TMUX_LOGIN_BOOTSTRAPPED=1
  "$HOME/.config/tmux/session"
  if [[ -n "${SSH_TTY:-}" ]]; then
    builtin exit
  fi
fi
