#!/bin/zsh
# Smoke test for CodeQuick. Exercises the non-interactive command paths
# against a throwaway CQ_ROOT, with pbcopy/trash/fzf stubbed out so the
# test never touches the clipboard, the Trash, or the terminal.
#
# Usage: zsh test/smoke.zsh

emulate -L zsh
set -u

SCRIPT_DIR="${0:A:h}"
CQ="$SCRIPT_DIR/../bin/cq"

SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/cq-smoke-XXXXXX")"
export CQ_ROOT="$SANDBOX/root"

# Stubs: pbcopy captures to a file, trash moves into the sandbox, and fzf
# fails fast (reaching fzf means a test unexpectedly hit the interactive
# path, which would otherwise hang waiting for the terminal).
STUBS="$SANDBOX/stubs"
TRASHED="$SANDBOX/trashed"
CLIPBOARD="$SANDBOX/clipboard"
mkdir -p "$STUBS" "$TRASHED"
printf '#!/bin/zsh\ncat > "%s"\n' "$CLIPBOARD" > "$STUBS/pbcopy"
printf '#!/bin/zsh\nmv "$@" "%s/"\n' "$TRASHED" > "$STUBS/trash"
printf '#!/bin/zsh\necho "fzf invoked" >&2\nexit 130\n' > "$STUBS/fzf"
chmod +x "$STUBS"/*
export PATH="$STUBS:$PATH"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); }
fail() { FAIL=$((FAIL + 1)); print -u2 "FAIL: $1"; }

assert_eq() {  # label actual expected
  if [[ "$2" == "$3" ]]; then pass; else fail "$1: expected '$3', got '$2'"; fi
}
assert_status() {  # label actual expected
  assert_eq "$1 (exit status)" "$2" "$3"
}
assert_exists() {  # label path
  if [[ -e "$2" || -L "$2" ]]; then pass; else fail "$1: expected $2 to exist"; fi
}
assert_gone() {  # label path
  if [[ -e "$2" || -L "$2" ]]; then fail "$1: expected $2 to be gone"; else pass; fi
}

# -- mk --
mk_out=$("$CQ" mk "My Test Project" 2>/dev/null)
assert_status "mk" $? 0
assert_exists "mk creates link" "$CQ_ROOT/links/my-test-project"
if [[ -L "$CQ_ROOT/links/my-test-project" ]]; then pass; else fail "mk link is a symlink"; fi

real=$("$CQ" path my-test-project)
assert_status "path" $? 0
assert_eq "mk prints real path on last line" "${mk_out##*$'\n'}" "$real"
if [[ -d "$real" ]]; then pass; else fail "real dir exists: $real"; fi
assert_eq "mk sets window title" \
  "$(jq -r '."window.title"' "$real/.vscode/settings.json")" "my-test-project"

"$CQ" mk my-test-project >/dev/null 2>&1
assert_status "mk duplicate rejected" $? 1
"$CQ" mk '!!!' >/dev/null 2>&1
assert_status "mk unsanitizable name rejected" $? 2
"$CQ" mk >/dev/null 2>&1
assert_status "mk missing arg rejected" $? 2

# -- mkcd (internal _mkcd; the wrapper cds into what it prints) --
mkcd_out=$("$CQ" _mkcd "CD Target" 2>/dev/null)
assert_status "_mkcd" $? 0
assert_eq "_mkcd prints link path" "$mkcd_out" "$CQ_ROOT/links/cd-target"
assert_exists "_mkcd creates link" "$CQ_ROOT/links/cd-target"
"$CQ" _mkcd >/dev/null 2>&1
assert_status "_mkcd missing arg rejected" $? 2

# -- path --
"$CQ" path nonexistent >/dev/null 2>&1
assert_status "path nonexistent rejected" $? 1

# -- cp --
echo marker > "$real/marker.txt"
"$CQ" cp my-test-project "Backup 1" >/dev/null 2>&1
assert_status "cp" $? 0
assert_exists "cp creates suffixed link" "$CQ_ROOT/links/my-test-project__backup-1"
copy_real=$("$CQ" path my-test-project__backup-1)
assert_eq "cp copies contents" "$(cat "$copy_real/marker.txt" 2>/dev/null)" "marker"
if [[ "$copy_real" != "$real" ]]; then pass; else fail "cp creates a new real dir"; fi
assert_eq "cp sets window title" \
  "$(jq -r '."window.title"' "$copy_real/.vscode/settings.json")" "my-test-project__backup-1"

# -- rename --
"$CQ" rename my-test-project__backup-1 renamed-proj >/dev/null 2>&1
assert_status "rename" $? 0
assert_gone "rename removes old link" "$CQ_ROOT/links/my-test-project__backup-1"
assert_exists "rename creates new link" "$CQ_ROOT/links/renamed-proj"
assert_eq "rename keeps real dir" "$("$CQ" path renamed-proj)" "$copy_real"
assert_eq "rename updates window title" \
  "$(jq -r '."window.title"' "$copy_real/.vscode/settings.json")" "renamed-proj"
"$CQ" rename renamed-proj my-test-project >/dev/null 2>&1
assert_status "rename onto existing name rejected" $? 1

# -- JSONC settings degrade gracefully --
print '{\n  // comment\n  "window.title": "renamed-proj"\n}' > "$copy_real/.vscode/settings.json"
before=$(cat "$copy_real/.vscode/settings.json")
"$CQ" rename renamed-proj renamed-again >/dev/null 2>&1
assert_status "rename with JSONC settings still succeeds" $? 0
assert_eq "JSONC settings left untouched" "$(cat "$copy_real/.vscode/settings.json")" "$before"
assert_gone "no tmp file left behind" "$copy_real/.vscode/settings.json.tmp"

# -- direct-name selection (must never reach the fzf stub) --
"$CQ" ls my-test-project >/dev/null 2>&1
assert_status "ls with exact name" $? 0
assert_eq "ls copies name to clipboard" "$(cat "$CLIPBOARD")" "my-test-project"
"$CQ" lookup my-test-project >/dev/null 2>&1
assert_status "lookup with exact name" $? 0
assert_eq "lookup copies real id" "$(cat "$CLIPBOARD")" "$(basename "$real")"
assert_eq "_cd prints link path" \
  "$("$CQ" _cd my-test-project 2>/dev/null)" "$CQ_ROOT/links/my-test-project"

"$CQ" ls a b >/dev/null 2>&1
assert_status "ls usage error" $? 2

# A non-matching name falls through to fzf (stub exits 130 -> command fails)
"$CQ" _cd zzz-no-match >/dev/null 2>&1
assert_status "_cd non-matching name falls through to fzf" $? 1

# -- rm --
"$CQ" rm renamed-again >/dev/null 2>&1
assert_status "rm" $? 0
assert_gone "rm removes link" "$CQ_ROOT/links/renamed-again"
assert_gone "rm removes real dir" "$copy_real"
assert_exists "rm trashes real dir" "$TRASHED/$(basename "$copy_real")"
assert_exists "rm trashes link" "$TRASHED/renamed-again"
"$CQ" rm nonexistent >/dev/null 2>&1
assert_status "rm nonexistent rejected" $? 1

print ""
print "passed: $PASS, failed: $FAIL"
rm -rf "$SANDBOX"
exit $(( FAIL > 0 ))
