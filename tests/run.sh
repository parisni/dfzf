#!/usr/bin/env bash
set -uo pipefail

# Runs every test file under tests/; exits non-zero if any of them fails.
tests_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
status=0

for test in "$tests_dir"/*/test_*.sh; do
	echo "# ${test#"$tests_dir"/}"
	bash "$test" || status=1
done

for test in "$tests_dir"/*/test_*.lua; do
	echo "# ${test#"$tests_dir"/}"
	(cd "$(dirname "$test")" && lua "$(basename "$test")") || status=1
done

exit "$status"
