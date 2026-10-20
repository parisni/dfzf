#!/usr/bin/env bash
# dfzf-hs: native socket protocol first, `hs -c` fallback.
# shellcheck disable=SC2154 # scratch_dir is set by the sourced env.sh
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"

mkdir -p "$scratch_dir/bin"
cat >"$scratch_dir/bin/hs" <<'HS'
#!/usr/bin/env bash
echo "hs $*" >>"$DFZF_TEST_LOG"
echo "from-hs"
HS
chmod +x "$scratch_dir/bin/hs"
export PATH="$scratch_dir/bin:$macos_tests_dir/fake-bin:$PATH"
client="$repo_dir/macos/bin/dfzf-hs"

socket="$scratch_dir/hs.sock"
python3 -c 'import socket, sys; socket.socket(socket.AF_UNIX).bind(sys.argv[1])' "$socket"
export DFZF_HS_SOCKET="$socket"
request='{"op":"tree"}'

# run <reply> <nc status>: sets out, err, status
run() {
	: >"$DFZF_TEST_LOG"
	out=$(DFZF_TEST_NC_REPLY="$1" DFZF_TEST_NC_STATUS="$2" "$client" "$request" 2>"$scratch_dir/stderr")
	status=$?
	err=$(cat "$scratch_dir/stderr")
}

run 'ok\n{"a":1}\n' 0
assert_eq "ok reply prints the payload" '0 {"a":1}' "$status $out"
assert_eq "request sent as one line on the socket" "nc -U $socket
$request" "$(cat "$DFZF_TEST_LOG")"

run 'ok\n' 0
assert_eq "ok without payload prints nothing" '0 ' "$status $out"

run 'err\ndfzf: no window with id 42\n' 0
assert_eq "err reply goes to stderr with status 1" '1  dfzf: no window with id 42' "$status $out $err"

run '' 1
assert_eq "connection failure falls back to hs -c" '0 from-hs' "$status $out"
assert_eq "fallback runs the spoon ipc" "hs -c spoon.Dfzf:ipc([==[$request]==])" "$(tail -n 1 "$DFZF_TEST_LOG")"

run '' 0
assert_eq "empty reply falls back to hs -c" '0 from-hs' "$status $out"

rm "$socket"
run 'ok\nnever\n' 0
assert_eq "missing socket goes straight to hs -c" "0 from-hs hs -c spoon.Dfzf:ipc([==[$request]==])" \
	"$status $out $(cat "$DFZF_TEST_LOG")"

finish
