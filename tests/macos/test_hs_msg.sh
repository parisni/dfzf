#!/usr/bin/env bash
# dfzf-hs-msg: i3 command subset -> spoon requests, everything else rejected.
# shellcheck disable=SC2154 # scratch_dir is set by the sourced env.sh
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"

# expect_request <name> <expected request json> <dfzf-hs-msg args...>
expect_request() {
	local name="$1" expected="$2"
	shift 2
	: >"$DFZF_TEST_LOG"
	if ! dfzf-hs-msg "$@" 2>"$scratch_dir/stderr"; then
		fail "$name"
		sed 's/^/  /' "$scratch_dir/stderr"
		return
	fi
	assert_eq "$name" "$(jq -cS . <<<"$expected")" "$(jq -cS . "$DFZF_TEST_LOG")"
}

# expect_error <name> <stderr substring> <dfzf-hs-msg args...>
expect_error() {
	local name="$1" message="$2"
	shift 2
	if dfzf-hs-msg "$@" 2>"$scratch_dir/stderr"; then
		fail "$name (succeeded)"
	elif grep -qF "$message" "$scratch_dir/stderr"; then
		pass "$name"
	else
		fail "$name"
		sed 's/^/  /' "$scratch_dir/stderr"
	fi
}

assert_eq "get_tree normalizes empty lists" '[[],[],[],[]]' \
	"$(dfzf-hs-msg -t get_tree --raw | jq -c '[.marks, (.. | objects | select(.id == 22) | .marks, .nodes),
	  (.. | objects | select(.name == "__i3_scratch") | .nodes)]')"
# Native backend: lists already encoded as lists, the tree is passed through as is
# (jq would have pretty-printed it).
jq -c '(.. | objects | select(has("marks")) | .marks, .nodes, .floating_nodes) |= (if type == "array" then . else [] end)' \
	"$DFZF_TEST_TREE" >"$DFZF_TEST_TREE_OVERRIDE"
assert_eq "get_tree skips jq without empty objects" "$(cat "$DFZF_TEST_TREE_OVERRIDE")" "$(dfzf-hs-msg -t get_tree)"
rm "$DFZF_TEST_TREE_OVERRIDE"
assert_eq "get_outputs" '1000' "$(dfzf-hs-msg -t get_outputs | jq '.[0].rect.width')"

expect_request "focus, criteria and action split" '{"op":"focus","id":22}' -q '[con_id=22]' focus
expect_request "focus, single string" '{"op":"focus","id":22}' -q '[con_id=22] focus'
expect_request "focus by app_id regex" '{"op":"focus","id":33}' -q '[app_id="^dfzf-popup$"]' focus
expect_request "class is an app_id alias" '{"op":"focus","id":33}' -q '[class="^dfzf-popup$"]' focus
expect_request "escaped quotes in criteria" '{"op":"focus","id":44}' -q '[title="term \"q\""] focus'
expect_request "no criteria targets focused window" '{"op":"close","ids":[33]}' -q kill
expect_request "kill" '{"op":"close","ids":[11]}' -q '[con_id=11] kill'
expect_request "multiple criteria" \
	'{"op":"mark","id":11,"mark":"_probe","add":true}' \
	-q '[app_id="firefox" title="mail.google.com"] mark --add _probe'
expect_request "mark without --add replaces" '{"op":"mark","id":33,"mark":"_x","add":false}' -q 'mark _x'
expect_request "unmark by con_mark" '{"op":"unmark","mark":"_dfzf-origin-term","ids":[44]}' \
	-q '[con_mark="^_dfzf-origin-term$"] unmark _dfzf-origin-term'
expect_request "bare unmark targets every window" '{"op":"unmark","mark":"_dfzf-origin-term"}' \
	-q 'unmark _dfzf-origin-term'
expect_request "urgent toggle" '{"op":"urgent","ids":[11],"mode":"toggle"}' -q '[con_id=11] urgent toggle'
expect_request "move scratchpad hides" '{"op":"hide","ids":[44]}' -q '[app_id="dfzf-term"] move scratchpad'
expect_request "scratchpad show" '{"op":"show","id":44}' -q '[app_id="dfzf-term"] scratchpad show'
expect_request "scratchpad creation chain shows" '{"op":"show","id":44}' \
	-q '[app_id="dfzf-term"] move scratchpad, scratchpad show'
expect_request "resize set" '{"op":"resize","id":22,"w":900,"h":720}' -q '[con_id=22] resize set 900px 720px'
expect_request "move position" '{"op":"move","id":22,"x":50,"y":40}' -q '[con_id=22] move position 50 40'

: >"$DFZF_TEST_LOG"
dfzf-hs-msg -q '[con_id=11] floating disable'
assert_eq "floating is a no-op" "" "$(cat "$DFZF_TEST_LOG")"

expect_error "no match is an error (fallback chains)" "No matching node" -q '[con_id=99] focus'

# Bare con_id: mark/unmark/kill skip the tree lookup (id 7 is not in the fixture,
# a lookup would fail), focus still checks the window exists.
expect_request "con_id mark skips the tree" '{"op":"mark","id":7,"mark":"_o","add":true}' -q '[con_id=7] mark --add _o'
expect_request "con_id unmark skips the tree" '{"op":"unmark","mark":"_o","ids":[7]}' -q '[con_id=7] unmark _o'
expect_request "con_id kill skips the tree" '{"op":"close","ids":[7]}' -q '[con_id=7] kill'
expect_error "con_id focus still checks the window" "No matching node" -q '[con_id=7] focus'
expect_request "mark is JSON-escaped" '{"op":"mark","id":7,"mark":"_a\"b\\c","add":false}' -q '[con_id=7] mark _a"b\c'
expect_error "workspaces unsupported" "unsupported on macOS" -q 'workspace 2'
expect_error "command chains unsupported" "unsupported on macOS" -q '[con_id=11] move to workspace 2, focus'
expect_error "other moves unsupported" "unsupported on macOS" -q 'move left'
expect_error "other message types unsupported" "unsupported on macOS" -t get_workspaces
expect_error "unknown criteria key" "criteria key 'foo'" -q '[foo=bar] focus'

: >"$DFZF_TEST_LOG"
dfzf-mark --con-id 22 --mark _dfzf-red --append-ts
assert_eq "dfzf-mark sends markToggle" \
	'{"appendTs":true,"id":22,"op":"markToggle","prefix":"_dfzf-red"}' "$(jq -cS . "$DFZF_TEST_LOG")"
if dfzf-mark --con-id x --mark _m 2>/dev/null; then
	fail "dfzf-mark rejects a non-numeric id"
else
	pass "dfzf-mark rejects a non-numeric id"
fi

finish
