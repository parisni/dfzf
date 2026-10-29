#!/usr/bin/env bash
# dfzf-focus-toggle: creating the missing target remembers where we came from.
# shellcheck disable=SC2154 # scratch_dir is set by the sourced env.sh
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"

jq '(.. | objects | select(.type == "con") | .focused) |= false
  | (.. | objects | select(.id == 11) | .focused) |= true' "$DFZF_TEST_TREE" >"$DFZF_TEST_TREE_OVERRIDE"

dfzf-focus-toggle term '[app_id="^absent$"]' touch "$scratch_dir/created"
assert_eq "missing target: fallback runs" "yes" "$([[ -e $scratch_dir/created ]] && echo yes)"
assert_eq "missing target: current window marked as origin" '{"op":"mark","id":11,"mark":"_dfzf-origin-term","add":true}' \
	"$(grep -F '_dfzf-origin-term' "$DFZF_TEST_LOG" | grep -F '"op":"mark"')"

: >"$DFZF_TEST_LOG"
dfzf-focus-toggle term '[app_id="^absent$"]'
assert_eq "missing target without fallback: no origin" "" "$(grep -F '"op":"mark"' "$DFZF_TEST_LOG" | grep -F '_dfzf-origin-term')"

# The fake bridge only logs marks: the probe mark is put in the tree by hand.
on_target() {
	jq --argjson origin "$1" '(.. | objects | select(.type == "con") | .focused) |= false
	  | (.. | objects | select(.type == "con") | .marks) |= (if type == "array" then . else [] end
	    | map(select(. != "_dfzf-origin-term")))
	  | (.. | objects | select(.id == 33) | .focused) |= true
	  | (.. | objects | select(.id == 33) | .marks) += ["_dfzf-focus-toggle-probe-term"]
	  | (.. | objects | select(.id == $origin) | .marks) += ["_dfzf-origin-term"]' \
		"$DFZF_TEST_TREE" >"$DFZF_TEST_TREE_OVERRIDE"
	: >"$DFZF_TEST_LOG"
	dfzf-focus-toggle term '[app_id="^dfzf-term$"]'
	grep -F '"op":"focus"' "$DFZF_TEST_LOG"
}

assert_eq "on target: back to the origin" '{"op":"focus","id":44}' "$(on_target 44)"
assert_eq "on target, origin on the target itself: most recent other window" '{"op":"focus","id":11}' "$(on_target 33)"
assert_eq "on target, no origin: most recent other window" '{"op":"focus","id":11}' "$(on_target 999)"

# Several targets: jump to the most recent one, not the last in tree order.
to_targets() {
	jq --argjson recent "$1" '(.. | objects | select(.type == "con") | .focused) |= false
	  | (.. | objects | select(.id == 22) | .focused) |= true
	  | (.. | objects | select(.id == 11 or .id == 44) | .marks) += ["_dfzf-focus-toggle-probe-multi"]
	  | (.. | objects | select(.id == $recent) | .marks) += ["_dfzf-sort-900"]' \
		"$DFZF_TEST_TREE" >"$DFZF_TEST_TREE_OVERRIDE"
	: >"$DFZF_TEST_LOG"
	dfzf-focus-toggle multi '[app_id="^(firefox|dfzf-term)$"]'
	grep -F '"op":"focus"' "$DFZF_TEST_LOG"
}

assert_eq "several targets: the most recent one" '{"op":"focus","id":11}' "$(to_targets 999)"
assert_eq "several targets: the most recent one, last in tree" '{"op":"focus","id":44}' "$(to_targets 44)"

# Native backend: the whole toggle is one focusToggle request.
: >"$DFZF_TEST_LOG"
DFZF_TEST_FOCUS_TOGGLE_REPLY="" dfzf-focus-toggle mail '[app_id="firefox" title="mail\.google"]'
assert_eq "native: a single request" \
	'{"op":"focusToggle","key":"mail","criteria":"[app_id=\"firefox\" title=\"mail\\.google\"]","fallback":false}' \
	"$(cat "$DFZF_TEST_LOG")"

rm -f "$scratch_dir/created"
DFZF_TEST_FOCUS_TOGGLE_REPLY=missing dfzf-focus-toggle term '[app_id="^absent$"]' touch "$scratch_dir/created"
assert_eq "native: missing target runs the fallback" "yes" "$([[ -e $scratch_dir/created ]] && echo yes)"

rm -f "$scratch_dir/created"
DFZF_TEST_FOCUS_TOGGLE_REPLY="" dfzf-focus-toggle term '[app_id="^dfzf-term$"]' touch "$scratch_dir/created"
assert_eq "native: existing target skips the fallback" "" "$([[ -e $scratch_dir/created ]] && echo yes)"

finish
