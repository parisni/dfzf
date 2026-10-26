#!/usr/bin/env bash
# Common setup for macOS backend tests (sourced): fake Hammerspoon bridge first
# in PATH, then the repo scripts; isolated HOME so no user dfzf.conf leaks in.

macos_tests_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd "$macos_tests_dir/../.." && pwd)"
source "$repo_dir/tests/lib.sh"

scratch_dir="$(mktemp -d)"
trap 'rm -r "$scratch_dir"' EXIT

export PATH="$macos_tests_dir/fake-hs:$repo_dir/macos/bin:$repo_dir/bin:$PATH"
# Tools like jq may be mise shims: keep mise on the real HOME's installs, else
# it finds its config through XDG_CONFIG_HOME but installs every tool afresh.
export MISE_DATA_DIR="${MISE_DATA_DIR:-$HOME/.local/share/mise}"
export MISE_CACHE_DIR="${MISE_CACHE_DIR:-$HOME/.cache/mise}"
export MISE_STATE_DIR="${MISE_STATE_DIR:-$HOME/.local/state/mise}"
# Scripts on the hot path test $OSTYPE rather than uname (fake-bin/uname): bash
# honours an inherited OSTYPE, so the Darwin code paths also run on linux CI.
export OSTYPE=darwin
export HOME="$scratch_dir"
export DFZF_TEST_TREE="$macos_tests_dir/fixtures/tree.json"
export DFZF_TEST_LOG="$scratch_dir/requests.log"
export DFZF_TEST_TREE_OVERRIDE="$scratch_dir/tree-override.json"
# dfzf-exec prefers a live sway/i3: never let a test reach the user's session.
unset SWAYSOCK I3SOCK
# Scripts append their own flags to DFZF_TERM: a session value would leak into
# the asserted commands, so tests use each script's default.
unset DFZF_TERM
