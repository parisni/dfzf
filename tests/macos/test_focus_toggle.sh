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

finish
