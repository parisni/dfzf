#!/usr/bin/env bash
# dfzf-kill-bro: macOS leaves popup cleanup to Dfzf.spoon, sway keeps the
# focused popup and never kills when nothing is focused.
# shellcheck disable=SC2154 # scratch_dir is set by the sourced env.sh
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"

# Fixture popup 33 is focused: add an unfocused popup 55 and a variant where the
# focus is still on a regular window, as when a popup has just been spawned.
two_popups="$scratch_dir/two-popups.json"
jq '.nodes[0].nodes += [.nodes[0].nodes[] | select(.id == 33) | .id = 55 | .focused = false]' \
	"$DFZF_TEST_TREE" >"$two_popups"
focus_elsewhere="$scratch_dir/focus-elsewhere.json"
jq '(.. | objects | select(.type == "con") | .focused) |= false
  | (.. | objects | select(.id == 11) | .focused) |= true' "$two_popups" >"$focus_elsewhere"
no_focus="$scratch_dir/no-focus.json"
jq '(.. | objects | select(.type == "con") | .focused) |= false' "$two_popups" >"$no_focus"

cp "$focus_elsewhere" "$DFZF_TEST_TREE_OVERRIDE"
tree=$(dfzf-kill-bro)
assert_eq "macos: popups left to the spoon" "" "$(cat "$DFZF_TEST_LOG" 2>/dev/null)"
assert_eq "macos: tree passed through" "11 22 33 44 55" \
	"$(jq -r '[.. | objects | select(.type == "con") | .id] | join(" ")' <<<"$tree")"

fake_sway="$scratch_dir/sway-bin"
mkdir -p "$fake_sway"
cat >"$fake_sway/swaymsg" <<'EOF'
#!/usr/bin/env bash
if [[ $1 == -t && $2 == get_tree ]]; then
	cat "$SWAY_TEST_TREE"
else
	echo "$*" >>"$SWAY_TEST_LOG"
fi
EOF
chmod +x "$fake_sway/swaymsg"
export SWAY_TEST_LOG="$scratch_dir/sway.log"

sway_kill_bro() {
	: >"$SWAY_TEST_LOG"
	SWAYSOCK=/dev/null SWAY_TEST_TREE="$1" PATH="$fake_sway:$PATH" dfzf-kill-bro >/dev/null
}

sway_kill_bro "$two_popups"
assert_eq "sway: kills the other popup" "-q [con_id=55] kill" "$(cat "$SWAY_TEST_LOG")"
sway_kill_bro "$no_focus"
assert_eq "sway: nothing focused, nothing killed" "" "$(cat "$SWAY_TEST_LOG")"

finish
