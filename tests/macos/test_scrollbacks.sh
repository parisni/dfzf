#!/usr/bin/env bash
# dfzf-scrollbacks maps kitty windows to WM windows by platform_window_id.
# shellcheck disable=SC2154 # scratch_dir is set by the sourced env.sh
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"

export PATH="$macos_tests_dir/fake-bin:$PATH"
export DFZF_TEST_KITTY_LS="$macos_tests_dir/fixtures/kitty-ls.json"
socket="$scratch_dir/kitty-500"
python3 -c 'import socket, sys; socket.socket(socket.AF_UNIX).bind(sys.argv[1])' "$socket"
mkdir -p "$HOME/.config/dfzf"
echo "kitty_socket='$scratch_dir/kitty-{pid}'" >"$HOME/.config/dfzf/dfzf.conf"

# fzf stand-in recording its input before picking, to assert the listing.
mkdir -p "$scratch_dir/bin"
cat >"$scratch_dir/bin/fzf" <<EOF
#!/usr/bin/env bash
tee "$scratch_dir/listing" | "$macos_tests_dir/fake-bin/fzf"
EOF
chmod +x "$scratch_dir/bin/fzf"
export PATH="$scratch_dir/bin:$PATH"

: >"$DFZF_TEST_LOG"
DFZF_TEST_PICK="ok id:9" dfzf-scrollbacks

assert_eq "every kitty window of every OS window is listed, tabs included" \
	"22 id:7 22 id:8 44 id:9" \
	"$(perl -ne 's/\e\[[0-9;]*m//g; print "$1 $2\n" if /^(\d+)\t.*\t\d+ clean (id:\d+)/' "$scratch_dir/listing" | sort | tr '\n' ' ' | sed 's/ $//')"
assert_eq "lines are numbered from the bottom of the scrollback" "1 clean id:9" \
	"$(perl -pe 's/\e\[[0-9;]*m//g' "$scratch_dir/listing" | awk -F'\t' '$1 == 44' | head -n1 | cut -f4)"
assert_eq "accepting focuses the kitty window, its OS window, then scrolls to the line" \
	"kitten @ --to unix:$socket focus-window --match id:9 {\"id\":44,\"op\":\"focus\"} kitten @ --to unix:$socket scroll-window --match id:9 1l- " \
	"$(while read -r l; do if [[ $l == kitten* ]]; then printf '%s ' "$l"; else jq -cS . <<<"$l" | tr '\n' ' '; fi; done <"$DFZF_TEST_LOG")"

finish
