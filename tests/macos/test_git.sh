#!/usr/bin/env bash
# dfzf-git on macOS: lazygit scratchpad toggle through the shim (create / show / hide).
# shellcheck disable=SC2154 # scratch_dir is set by the sourced env.sh
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"

export PATH="$macos_tests_dir/fake-bin:$PATH"
fixtures="$macos_tests_dir/fixtures"
repo="$scratch_dir/repo"
mkdir -p "$repo/sub"
git -C "$repo" init -q

# Spoon requests logged by the fake bridge, one compact sorted JSON per item.
requests() { jq -cS . "$DFZF_TEST_LOG" | tr '\n' ' '; }

reset() {
	: >"$DFZF_TEST_LOG"
	rm -f "$DFZF_TEST_TREE_OVERRIDE"
}

show_and_resize='{"id":55,"op":"show"} {"h":720,"id":55,"op":"resize","w":900} {"id":55,"op":"move","x":50,"y":40} '

reset
(cd "$repo/sub" && DFZF_TEST_TREE="$fixtures/git-absent.json" DFZF_TEST_TREE_ON_LAUNCH="$fixtures/git-focused.json" \
	DFZF_TEST_TREE_ON_SHOW="$fixtures/git-focused.json" dfzf-git)
assert_eq "absent: launches lazygit at the repo root" \
	"kitty -1 --title dfzf-git -d $repo -e lazygit" "$(grep '^kitty' "$DFZF_TEST_LOG")"
assert_eq "absent: then shows and centers it at 90%" "$show_and_resize" \
	"$(grep -v '^kitty' "$DFZF_TEST_LOG" | jq -cS . | tr '\n' ' ')"

reset
DFZF_TEST_TREE="$fixtures/git-hidden.json" DFZF_TEST_TREE_ON_SHOW="$fixtures/git-focused.json" dfzf-git
assert_eq "hidden: shown and centered at 90%" "$show_and_resize" "$(requests)"

reset
DFZF_TEST_TREE="$fixtures/git-focused.json" dfzf-git
assert_eq "visible: hidden again" '{"ids":[55],"op":"hide"} ' "$(requests)"

finish
