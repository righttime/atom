#!/bin/sh
# Regression tests for evidence parsing, not simulated runtime success claims.
set -eu
command -v jq >/dev/null 2>&1
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
TMP=$(mktemp -d "${TMPDIR:-/tmp}/atom-claude-evidence.XXXXXX")
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
cat > "$TMP/valid.jsonl" <<'EOF'
{"type":"assistant","parent_tool_use_id":null,"message":{"model":"user-model","content":[{"type":"tool_use","name":"Agent","id":"review-1","input":{"subagent_type":"atom-reviewer"}}]}}
{"type":"user","parent_tool_use_id":null,"message":{"content":[{"type":"tool_result","tool_use_id":"review-1","content":"Async agent launched successfully"}]}}
{"type":"assistant","parent_tool_use_id":"review-1","message":{"model":"user-model","content":[{"type":"text","text":"CHANGES_REQUIRED\nR1: subtraction instead of addition"}]}}
{"type":"system","subtype":"task_notification","tool_use_id":"review-1","status":"completed"}
{"type":"assistant","parent_tool_use_id":null,"message":{"content":[{"type":"tool_use","name":"Edit","id":"repair","input":{"file_path":"/fixture/sum.sh","old_string":"-","new_string":"+"}}]}}
{"type":"user","parent_tool_use_id":null,"message":{"content":[{"type":"tool_result","tool_use_id":"repair","content":"File updated"}]}}
{"type":"assistant","parent_tool_use_id":null,"message":{"content":[{"type":"tool_use","name":"Bash","id":"test","input":{"command":"sh test_sum.sh"}}]}}
{"type":"user","parent_tool_use_id":null,"message":{"content":[{"type":"tool_result","tool_use_id":"test","is_error":false,"content":"PASS: three sum cases"}]}}
{"type":"assistant","parent_tool_use_id":null,"message":{"model":"user-model","content":[{"type":"tool_use","name":"Agent","id":"review-2","input":{"subagent_type":"atom-reviewer"}}]}}
{"type":"user","parent_tool_use_id":null,"message":{"content":[{"type":"tool_result","tool_use_id":"review-2","content":"Async agent launched successfully"}]}}
{"type":"assistant","parent_tool_use_id":"review-2","message":{"model":"user-model","content":[{"type":"text","text":"PASS\nR1 resolved after source inspection"}]}}
{"type":"system","subtype":"task_notification","tool_use_id":"review-2","status":"completed"}
EOF
jq -s -f "$ROOT/tests/claude-evidence.jq" "$TMP/valid.jsonl" > "$TMP/result"
jq -e '.calls == 2 and .reviews[0].verdict == "CHANGES_REQUIRED" and .reviews[1].verdict == "PASS"' "$TMP/result" >/dev/null
printf 'PASS correlated native child verdict parser (synthetic fixture only)\n'
jq -c 'if .parent_tool_use_id == "review-1" then .message.content[0].text = "**CHANGES_REQUIRED**\nR1" elif .parent_tool_use_id == "review-2" then .message.content[0].text = "# PASS\nR1 resolved" else . end' "$TMP/valid.jsonl" > "$TMP/markdown.jsonl"
jq -s -f "$ROOT/tests/claude-evidence.jq" "$TMP/markdown.jsonl" > "$TMP/result"
jq -e '.calls == 2 and .reviews[1].verdict == "PASS"' "$TMP/result" >/dev/null
printf 'PASS leading Markdown status parser (synthetic fixture only)\n'
jq -s -c '([.[0], .[2], (.[1] | .message.content[0].content = "CHANGES_REQUIRED: completed foreground result")] + .[4:9] + [.[10], (.[9] | .message.content[0].content = "PASS: completed foreground result")]) | .[]' "$TMP/valid.jsonl" > "$TMP/foreground.jsonl"
jq -s -f "$ROOT/tests/claude-evidence.jq" "$TMP/foreground.jsonl" > "$TMP/result"
jq -e '.calls == 2 and .orderedRepairTestReview == true' "$TMP/result" >/dev/null
printf 'PASS ordered foreground result parser (synthetic fixture only)\n'
reject() {
  if jq -s -f "$ROOT/tests/claude-evidence.jq" "$TMP/invalid.jsonl" > "$TMP/result" 2> "$TMP/error"; then
    echo "Invalid evidence accepted: $1" >&2; exit 1
  fi
  printf 'PASS reject %s\n' "$1"
}
jq -c 'select(.parent_tool_use_id == null)' "$TMP/valid.jsonl" > "$TMP/invalid.jsonl"
printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"text","text":"CHANGES_REQUIRED then PASS: I independently reviewed it"}]}}' >> "$TMP/invalid.jsonl"
reject 'parent claims without child evidence'
jq -c 'if .parent_tool_use_id != null then .parent_tool_use_id = "unrelated-call" else . end' "$TMP/valid.jsonl" > "$TMP/invalid.jsonl"
reject 'unrelated child verdicts'
jq -c 'if .parent_tool_use_id == "review-2" then .type = "user" | .message.content = [{"type":"tool_result","content":"PASS"}] else . end' "$TMP/valid.jsonl" > "$TMP/invalid.jsonl"
reject 'tool stdout as Reviewer PASS'
jq -c 'if .type == "user" then .message.content[0].is_error = true else . end' "$TMP/valid.jsonl" > "$TMP/invalid.jsonl"
reject 'failed Reviewer completion despite assistant text'
jq -c 'if .parent_tool_use_id == null then .message.content[0].input.model = "forced" else . end' "$TMP/valid.jsonl" > "$TMP/invalid.jsonl"
reject 'per-call model override'
cat "$TMP/valid.jsonl" "$TMP/valid.jsonl" > "$TMP/invalid.jsonl"
reject 'more than three calls'
jq -c 'select(.subtype != "task_notification")' "$TMP/valid.jsonl" > "$TMP/invalid.jsonl"
reject 'launch acknowledgments without actual completion'
jq -s -c '([.[0], .[2], .[1]] + .[4:9] + [.[10], .[9]]) | .[]' "$TMP/valid.jsonl" > "$TMP/invalid.jsonl"
reject 'late async launch ack as foreground completion'
jq -s -c '.[0:3] + .[4:6] + .[3:4] + .[6:] | .[]' "$TMP/valid.jsonl" > "$TMP/invalid.jsonl"
reject 'edit before Reviewer completion'
jq -s -c '.[0:4] + .[8:] + .[4:8] | .[]' "$TMP/valid.jsonl" > "$TMP/invalid.jsonl"
reject 'final PASS before repair and tests'
jq -c 'if .type == "assistant" and .message.content[0].id == "test" then .message.content[0].input.command = "echo PASS: three sum cases" else . end' "$TMP/valid.jsonl" > "$TMP/invalid.jsonl"
reject 'echoed test stdout instead of actual test command'
jq -s -c '.[0:8] + [
 {type:"assistant",parent_tool_use_id:null,message:{content:[{type:"tool_use",name:"Agent",id:"review-middle",input:{subagent_type:"atom-reviewer"}}]}},
 {type:"user",parent_tool_use_id:null,message:{content:[{type:"tool_result",tool_use_id:"review-middle",content:"Async agent launched successfully"}]}},
 {type:"assistant",parent_tool_use_id:"review-middle",message:{content:[{type:"text",text:"No verdict supplied"}]}},
 {type:"system",subtype:"task_notification",tool_use_id:"review-middle",status:"completed"}
 ] + .[8:] | .[]' "$TMP/valid.jsonl" > "$TMP/invalid.jsonl"
reject 'missing middle verdict in three-call batch'
jq -s -c '. + .[4:6] | .[]' "$TMP/valid.jsonl" > "$TMP/invalid.jsonl"
reject 'unreviewed edit after final PASS'
jq -s -c '.[0:2] + .[8:10] + .[2:8] + .[10:] | .[]' "$TMP/valid.jsonl" > "$TMP/invalid.jsonl"
reject 'overlapping Reviewer calls'
