#!/usr/bin/env bash
# Minimal assertion helpers shared by the test files (sourced, not run).

fail_count=0

pass() { printf 'ok   %s\n' "$1"; }

fail() {
	printf 'FAIL %s\n' "$1"
	fail_count=$((fail_count + 1))
}

assert_eq() {
	local name="$1" expected="$2" actual="$3"
	if [[ $expected == "$actual" ]]; then
		pass "$name"
	else
		fail "$name"
		printf '  expected: %s\n  actual:   %s\n' "$expected" "$actual"
	fi
}

finish() {
	((fail_count == 0))
}
