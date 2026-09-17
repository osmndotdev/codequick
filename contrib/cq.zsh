# CodeQuick Zsh wrapper
# Add this to your .zshrc to enable 'cq cd' (changes your shell's working
# directory), 'cq open cc' (calls your 'cc' shell function), and tab
# completion:
# source <path-to-codequick>/contrib/cq.zsh

# Resolve the cq binary relative to this file's location ($0 is the sourced
# file's path thanks to zsh's default FUNCTION_ARGZERO option).
typeset -g _CQ_BIN="${0:A:h:h}/bin/cq"

# Tab completion (contrib/completions/_cq). Sourcing this file before
# compinit is enough: compinit picks up #compdef files from fpath. If compinit
# has already run, register the completer directly instead.
typeset -gU fpath
fpath=("${0:A:h}/completions" $fpath)
if (( $+functions[compdef] )); then
  autoload -Uz _cq
  compdef _cq cq
fi

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

  # `cc` is a shell function (see the Claude Code section of the README), so
  # a subprocess can't call it: _open_cc prints the project's real path and
  # we hand it to `cc` here.
  if [[ "$1" == open && "$2" == cc ]]; then
    shift 2
    if ! (( $+functions[cc] )); then
      print -u2 "cq open cc: no 'cc' shell function defined"
      return 1
    fi
    local real_path
    real_path="$($_CQ_BIN _open_cc "$@")" || return
    if [[ -n "$real_path" ]]; then
      cc "$real_path"
    fi
    return
  fi

  # Otherwise, just run the command as usual
  $_CQ_BIN "$@"
}
