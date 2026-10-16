#!/usr/bin/env bash
# kittyx companion shells listed by dfzf-windows-load and driven by dfzf-windows-line.
# shellcheck disable=SC2154 # scratch_dir is set by the sourced env.sh
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"

export PATH="$macos_tests_dir/fake-bin:$PATH"
export DFZF_TEST_KITTY_LS="$macos_tests_dir/fixtures/kitty-ls.json"
socket="$scratch_dir/kitty-500"
python3 -c 'import socket, sys; socket.socket(socket.AF_UNIX).bind(sys.argv[1])' "$socket"
mkdir -p "$HOME/.config/dfzf"
echo "kitty_socket='$scratch_dir/kitty-{pid}'" >"$HOME/.config/dfzf/dfzf.conf"

assert_eq "companions are opt-in" "0" \
	"$(dfzf-hs-msg -t get_tree | dfzf-windows-load --input-json - | grep -cF '~k')"

listing=$(dfzf-hs-msg -t get_tree | DFZF_WINDOWS_KITTY_COMPANIONS=true dfzf-windows-load --input-json -)
companion=$(grep -F '~k' <<<"$listing" || true)
assert_eq "companion listed once, attached to its host by title" "1" "$(grep -c . <<<"$companion")"
assert_eq "companion line targets host con and kitty window" "#22 ~k500.8" \
	"$(perl -ne 'print "$1" if /(#\d+ ~k[\d.]+)/' <<<"$companion")"
assert_eq "companion title is prefixed" "1" "$(grep -c '↳ zsh' <<<"$companion")"

: >"$DFZF_TEST_LOG"
dfzf-windows-line focus "$companion"
assert_eq "focus switches kitty then the WM window" \
	"kitten @ --to unix:$socket focus-window --match id:8 {\"id\":22,\"op\":\"focus\"} " \
	"$(while read -r l; do if [[ $l == kitten* ]]; then printf '%s ' "$l"; else jq -cS . <<<"$l" | tr '\n' ' '; fi; done <"$DFZF_TEST_LOG")"

: >"$DFZF_TEST_LOG"
dfzf-windows-line kill "$companion"
assert_eq "kill closes only the companion" "kitten @ --to unix:$socket close-window --match id:8" "$(cat "$DFZF_TEST_LOG")"

: >"$DFZF_TEST_LOG"
dfzf-windows-line focus "$(grep -F '#11' <<<"$listing")"
assert_eq "regular line focuses the WM window only" '{"id":11,"op":"focus"}' "$(jq -cS . "$DFZF_TEST_LOG")"

finish
