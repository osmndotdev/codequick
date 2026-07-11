# CodeQuick Zsh wrapper
# Add this to your .zshrc to enable 'cq cd' to change your shell's working directory:
# source <path-to-codequick>/contrib/cq.zsh

# Resolve the cq binary relative to this file's location ($0 is the sourced
# file's path thanks to zsh's default FUNCTION_ARGZERO option).
typeset -g _CQ_BIN="${0:A:h:h}/bin/cq"

cq() {
  if [[ "$1" == cd ]]; then
    shift
    local destination
    destination="$($_CQ_BIN _cd "$@")"
    [[ -n "$destination" ]] && builtin cd "$destination"
    return
  fi

  # If not 'cd', just run the command as usual
  $_CQ_BIN "$@"
}
