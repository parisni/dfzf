#!/usr/bin/env bash
# dfzf-detach: portable `setsid -f` used by dfzf-mail compose bindings.
# shellcheck disable=SC2154 # scratch_dir and repo_dir are set by the sourced env.sh
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"

out="$scratch_dir/detached"
# The child reports whether it leads its own session, then waits for a go file:
# dfzf-detach returning while the child is still blocked proves it does not wait.
dfzf-detach perl -MPOSIX -e '
	my $leader = (POSIX::getpgrp() == $$) ? "leader" : "member";
	select(undef, undef, undef, 0.1) until -e $ARGV[1];
	open(my $fh, ">", $ARGV[0]) or die; print $fh "$leader\n";
' "$out" "$scratch_dir/go"
assert_eq "returns before the command ends" "0 absent" "$? $([[ -e $out ]] && echo present || echo absent)"

touch "$scratch_dir/go"
for _ in $(seq 50); do
	[[ -s $out ]] && break
	sleep 0.1
done
assert_eq "runs the command in a new session" "leader" "$(cat "$out" 2>/dev/null)"

dfzf-detach 2>/dev/null
assert_eq "no command: usage error" "2" "$?"

assert_eq "dfzf-mail no longer calls setsid" "" "$(grep -n 'setsid' "$repo_dir/bin/dfzf-mail")"

finish
