#!/usr/bin/env bash
# dfzf-launcher on macOS: delegates to dfzf-launcher-macos, which opens .app bundles.
# shellcheck disable=SC2154 # scratch_dir is set by the sourced env.sh
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"

export PATH="$macos_tests_dir/fake-bin:$PATH"
apps="$scratch_dir/apps"
mkdir -p "$apps/A/Firefox.app" "$apps/A/kitty.app" "$apps/B/Firefox.app" "$apps/B/Notes.app"
touch "$apps/A/not-an-app.txt"
mkdir -p "$HOME/.config/dfzf"
echo "launcher_app_dirs=(\"$apps/A\" \"$apps/B\" \"$apps/missing\")" >"$HOME/.config/dfzf/dfzf.conf"

assert_eq "lists .app bundles once, sorted, case-insensitive" \
	"Firefox kitty Notes " "$(dfzf-launcher-macos --list | cut -f1 | tr '\n' ' ')"

: >"$DFZF_TEST_LOG"
DFZF_TEST_PICK=Notes dfzf-launcher
assert_eq "dfzf-launcher delegates and opens the pick" "open $apps/B/Notes.app" "$(grep '^open' "$DFZF_TEST_LOG")"

: >"$DFZF_TEST_LOG"
if DFZF_TEST_PICK=nothing-matches dfzf-launcher; then
	assert_eq "cancel opens nothing" "" "$(grep '^open' "$DFZF_TEST_LOG" || true)"
else
	fail "cancel exits cleanly"
fi

finish
