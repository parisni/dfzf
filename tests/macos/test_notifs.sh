#!/usr/bin/env bash
# dfzf-notifs on macOS: Notification Center through a fake notif CLI.
# shellcheck disable=SC2154 # scratch_dir is set by the sourced env.sh
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"

export PATH="$macos_tests_dir/fake-bin:$PATH"
export DFZF_TEST_NOTIFS="$scratch_dir/notifs"
tab=$'\t'

notifs() { printf '%s\n' "$@" >"$DFZF_TEST_NOTIFS"; }
notif_calls() { grep '^notif' "$DFZF_TEST_LOG" | tr '\n' ' '; }

notifs "[1] Slack (group, collapsed)" \
	"[2] Mail: Meeting — first line" \
	"second line" \
	"[3] Slack (2 notifications, expanded)" \
	"  [3.1] Slack: #general — lunch?" \
	"  [3.2] Slack: DM — hey"
assert_eq "lists entries, joining multi-line bodies and keeping sub-indexes" \
	"1${tab}Slack (group, collapsed)|2${tab}Mail: Meeting — first line second line|3${tab}Slack (2 notifications, expanded)|3.1${tab}Slack: #general — lunch?|3.2${tab}Slack: DM — hey|" \
	"$(dfzf-notifs-macos --list | tr '\n' '|')"

notifs "No notifications."
assert_eq "empty Notification Center lists nothing" "" "$(dfzf-notifs-macos --list)"

notifs "[1] Mail: Meeting — slides" "[2] Slack: DM — hey"
: >"$DFZF_TEST_LOG"
DFZF_TEST_PICK=Slack dfzf-notifs
assert_eq "enter clicks the pick" "notif click 2 " "$(notif_calls)"

: >"$DFZF_TEST_LOG"
dfzf-notifs-macos --dismiss "2${tab}Slack: DM — hey"
assert_eq "ctrl-k dismisses the pick" "notif dismiss 2 " "$(notif_calls)"

notifs "[1] New: arrived — meanwhile" "[2] Mail: Meeting — slides" "[3] Slack: DM — hey"
: >"$DFZF_TEST_LOG"
dfzf-notifs-macos --click "2${tab}Slack: DM — hey"
assert_eq "shifted index: acts on the picked text, not the stale index" "notif click 3 " "$(notif_calls)"

notifs "[1] Slack: DM — hey" "[2] Slack: DM — hey"
: >"$DFZF_TEST_LOG"
dfzf-notifs-macos --dismiss "2${tab}Slack: DM — hey"
assert_eq "duplicate text: keeps the picked index" "notif dismiss 2 " "$(notif_calls)"

notifs "[1] Mail: Meeting — slides"
: >"$DFZF_TEST_LOG"
if dfzf-notifs-macos --click "2${tab}Slack: DM — hey" 2>/dev/null; then
	fail "gone notification: fails"
else
	assert_eq "gone notification: fails without acting" "" "$(notif_calls)"
fi

: >"$DFZF_TEST_LOG"
if DFZF_TEST_PICK=nothing-matches dfzf-notifs; then
	assert_eq "cancel clicks nothing" "" "$(notif_calls)"
else
	fail "cancel exits cleanly"
fi

finish
