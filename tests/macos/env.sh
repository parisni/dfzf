#!/usr/bin/env bash
# Common setup for macOS backend tests (sourced): fake Hammerspoon bridge first
# in PATH, then the repo scripts; isolated HOME so no user dfzf.conf leaks in.

macos_tests_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd "$macos_tests_dir/../.." && pwd)"
source "$repo_dir/tests/lib.sh"

scratch_dir="$(mktemp -d)"
trap 'rm -r "$scratch_dir"' EXIT

export PATH="$macos_tests_dir/fake-hs:$repo_dir/macos/bin:$repo_dir/bin:$PATH"
export HOME="$scratch_dir"
export DFZF_TEST_TREE="$macos_tests_dir/fixtures/tree.json"
export DFZF_TEST_LOG="$scratch_dir/requests.log"
# dfzf-exec prefers a live sway/i3: never let a test reach the user's session.
unset SWAYSOCK I3SOCK
