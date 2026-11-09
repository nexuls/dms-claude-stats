#!/usr/bin/env bash
# Tests for the claude-activity-hook state machine
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$SCRIPT_DIR/claude-activity-hook"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export CLAUDE_STATS_STATE="$TMP/state.json"

PASS=0
FAIL=0
pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1" >&2; }

# send <json>: runs the hook, fails if it prints anything (UserPromptSubmit stdout reaches the model)
send() {
    local out
    out=$(printf '%s' "$1" | bash "$HOOK")
    [ -z "$out" ] || fail "hook printed output: $out"
}

state_of() {
    jq -r --arg id "$1" '.sessions[$id].state // "absent"' "$CLAUDE_STATS_STATE" 2>/dev/null || echo absent
}

echo "=== Test 1: event to state matrix ==="
while IFS='|' read -r event expected label; do
    send "{\"session_id\":\"s1\",\"cwd\":\"/home/u/proj\",$event}"
    actual=$(state_of s1)
    if [ "$actual" = "$expected" ]; then pass "$label"; else fail "$label (expected $expected, got $actual)"; fi
done <<'CASES'
"hook_event_name":"SessionStart"|idle|SessionStart is idle
"hook_event_name":"UserPromptSubmit","prompt":"hi"|working|prompt starts work
"hook_event_name":"PreToolUse","tool_name":"AskUserQuestion"|asking|AskUserQuestion asks
"hook_event_name":"PostToolUse","tool_name":"AskUserQuestion"|working|answer resumes work
"hook_event_name":"PreToolUse","tool_name":"ExitPlanMode"|asking|plan approval asks
"hook_event_name":"PreToolUse","tool_name":"Bash"|working|ordinary tool is work
"hook_event_name":"PermissionRequest","tool_name":"Bash"|asking|permission dialog asks
"hook_event_name":"PostToolUse","tool_name":"Bash"|working|approved tool resumes work
"hook_event_name":"Notification","notification_type":"permission_prompt"|asking|permission notification asks
"hook_event_name":"Stop"|done|Stop is done
"hook_event_name":"Notification","notification_type":"idle_prompt"|done|idle notification keeps done
"hook_event_name":"SessionEnd"|absent|SessionEnd removes the session
CASES

echo "=== Test 2: repeated events do not rewrite the file ==="
send '{"session_id":"s2","hook_event_name":"UserPromptSubmit"}'
before=$(stat -c %i "$CLAUDE_STATS_STATE")
send '{"session_id":"s2","hook_event_name":"PreToolUse","tool_name":"Read"}'
after=$(stat -c %i "$CLAUDE_STATS_STATE")
if [ "$before" = "$after" ]; then pass "same state skips the write"; else fail "same state rewrote the file"; fi

echo "=== Test 3: prune drops dead sessions only ==="
sleep 600 &
LIVE=$!
cat >"$CLAUDE_STATS_STATE" <<JSON
{"sessions":{"dead":{"state":"working","pid":999999999},"live":{"state":"working","pid":$LIVE},"unknown":{"state":"working","pid":0}}}
JSON
bash "$HOOK" prune
kill "$LIVE" 2>/dev/null || true
for pair in dead:absent live:working unknown:working; do
    id=${pair%%:*}
    expected=${pair#*:}
    actual=$(state_of "$id")
    if [ "$actual" = "$expected" ]; then pass "prune leaves $id $expected"; else fail "prune left $id $actual, expected $expected"; fi
done

echo "=== Test 4: garbage input and corrupt state are ignored ==="
printf 'not json' >"$CLAUDE_STATS_STATE"
send 'not json'
send '{"session_id":"s3","hook_event_name":"Stop"}'
actual=$(state_of s3)
if [ "$actual" = "done" ]; then pass "corrupt state file is replaced"; else fail "corrupt state file (got $actual)"; fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
