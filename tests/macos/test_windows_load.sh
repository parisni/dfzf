#!/usr/bin/env bash
# End to end: unchanged dfzf-windows-load over the tree served by dfzf-hs-msg.
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"

# dfzf-windows-load reads global toggles from /tmp: an active filter would make
# the expected listing wrong, so skip rather than report a false failure.
if compgen -G '/tmp/dfzf-windows-color-*' >/dev/null || [[ -e /tmp/dfzf-windows-show-hidden ]]; then
	echo "skip: dfzf-windows color/hidden filter active in /tmp"
	exit 0
fi

listing=$(dfzf-hs-msg -t get_tree | dfzf-windows-load --input-json -)
ids=$(perl -ne 'print "$1 " if /#([0-9]+)/' <<<"$listing")
assert_eq "popup hidden, sorted by recency" "11 44 22 " "$ids"

terminal_only=$(dfzf-hs-msg -t get_tree | dfzf-windows-load --input-json - --app dfzf-term)
assert_eq "--app filter" "44 " "$(perl -ne 'print "$1 " if /#([0-9]+)/' <<<"$terminal_only")"

# The persistent switcher is a dfzf window: never listed, even as the most recent.
jq '(.. | objects | select(.type == "workspace" and .name == "1") | .nodes) += [{"type": "con", "id": 99,
  "app_id": "dfzf-switcher", "name": "dfzf-switcher", "marks": ["_dfzf-sort-9999999999999"]}]' \
	"$DFZF_TEST_TREE" >"$DFZF_TEST_TREE_OVERRIDE"
listing=$(dfzf-hs-msg -t get_tree | dfzf-windows-load --input-json -)
assert_eq "switcher hidden" "11 44 22 " "$(perl -ne 'print "$1 " if /#([0-9]+)/' <<<"$listing")"

finish
