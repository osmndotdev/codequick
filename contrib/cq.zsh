# CodeQuick Zsh wrapper
# Add this to your .zshrc to enable 'cq cd' to change your shell's working directory:
# source <path-to-codequick>/contrib/cq.zsh

# Resolve the cq binary relative to this file's location ($0 is the sourced
# file's path thanks to zsh's default FUNCTION_ARGZERO option).
typeset -g _CQ_BIN="${0:A:h:h}/bin/cq"

cq() {
  # cd and mkcd must change the calling shell's directory, which a
  # subprocess can't do: the _cd/_mkcd internal commands print the
  # destination on stdout and we cd here.
  if [[ "$1" == cd || "$1" == mkcd ]]; then
    local subcmd="_$1"
    shift
    local destination
    destination="$($_CQ_BIN "$subcmd" "$@")" || return
    if [[ -n "$destination" ]]; then
      builtin cd "$destination"
    fi
    return
  fi

  # Otherwise, just run the command as usual
  $_CQ_BIN "$@"
}
