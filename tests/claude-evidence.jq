# Test-only parser for this fixture's native Edit/Write + sh test_sum.sh loop.
# Unsupported/opaque traces fail closed; this is not a shell sandbox or runtime.
def verdict:
  [capture("^\\s*[#*` ]*(?<verdict>PASS|CHANGES_REQUIRED|INCOMPLETE)(?:\\s|[*`]|$)").verdict]
  | first // error("Missing native child verdict");

to_entries | map({i: .key, event: .value}) as $events
| [$events[] | .i as $i | .event
   | select(.type == "assistant" and .parent_tool_use_id == null)
   | .message.content[]? | select(.type == "tool_use") | {i: $i, tool: .}] as $uses
| [$events[] | .i as $i | .event
   | select(.type == "user" and .parent_tool_use_id == null)
   | .message.content[]? | select(.type == "tool_result") | {i: $i, result: .}] as $results
| [$uses[] | select(.tool.name == "Agent" and .tool.input.subagent_type == "atom-reviewer")] as $calls
| if ($calls | length) < 2 or ($calls | length) > 3
  then error("Expected 2–3 native atom-reviewer Agent calls") else . end
| [$calls[] | . as $call
   | if (.tool.input | has("model")) then error("ATOM must not pass a review model") else . end
   | [$results[] | select(.result.tool_use_id == $call.tool.id)] as $returns
   | if ($returns | length) != 1 or any($returns[]; .result.is_error == true)
     then error("Missing or failed native Agent result") else . end
   | [$events[] | .i as $i | .event
      | select(.type == "assistant" and .parent_tool_use_id == $call.tool.id)
      | .message.content[]? | select(.type == "text" and (.text | length) > 0)
      | {i: $i, text: .text}] | last as $final
   | ($final.text // "" | verdict) as $verdict
   # Foreground return follows the child verdict. A background launch ack does
   # not: require the host's completed task_notification correlated by tool ID.
   | (if $returns[0].i > $final.i
          and (($returns[0].result.content | tostring | contains("Async agent launched")) | not)
          and (any($events[]; .event.type == "system" and .event.subtype == "task_started" and .event.tool_use_id == $call.tool.id) | not)
      then $returns[0].i
      else [$events[] | select(.event.type == "system" and .event.subtype == "task_notification"
             and .event.tool_use_id == $call.tool.id and .event.status == "completed" and .i > $final.i)]
           | first.i // error("Missing actual background Reviewer completion") end) as $done
   | {id: $call.tool.id, verdict: $verdict, start: $call.i, done: $done,
      models: ([$events[] | .event | select(.type == "assistant" and .parent_tool_use_id == $call.tool.id) | .message.model // empty] | unique)}] as $reviews
| if $reviews[0].verdict != "CHANGES_REQUIRED" or $reviews[-1].verdict != "PASS"
  then error("Expected native child CHANGES_REQUIRED → PASS") else . end
| if any(range(1; $reviews | length); . as $n | $reviews[$n].start <= $reviews[$n - 1].done)
  then error("Reviewer calls overlap") else . end
| [$uses[] | select(.tool.name == "Edit" or .tool.name == "Write" or .tool.name == "NotebookEdit")] as $edits
| if any($edits[]; . as $edit | any($reviews[]; $edit.i >= .start and $edit.i <= .done))
  then error("Edit occurred while Reviewer was running") else . end
| if any($edits[]; .i > $reviews[-1].done)
  then error("Unreviewed edit after final PASS") else . end
| [$edits[] | . as $edit
   | select(.tool.name == "Edit" or .tool.name == "Write")
   | select(.tool.input.file_path | endswith("/sum.sh"))
   | $results[] | select(.result.tool_use_id == $edit.tool.id and .result.is_error != true)
   | {start: $edit.i, done: .i}] as $repairs
| [$uses[] | . as $test | select(.tool.name == "Bash" and (.tool.input.command | test("^sh (\\./)?test_sum\\.sh$")))
   | $results[] | select(.result.tool_use_id == $test.tool.id and .result.is_error == false)
   | select(.result.content | tostring | contains("PASS: three sum cases"))
   | {start: $test.i, done: .i}] as $tests
| if any(range(1; $reviews | length); . as $n
    | $reviews[$n - 1].verdict == "CHANGES_REQUIRED"
      and (any($repairs[]; . as $repair
        | $repair.start > $reviews[$n - 1].done
          and any($tests[]; .start > $repair.done and .done < $reviews[$n].start)) | not))
  then error("Missing ordered Reviewer completion → successful repair → test → re-review") else . end
| {calls: ($calls | length), reviews: $reviews, orderedRepairTestReview: true,
   parentModels: ([$events[] | .event | select(.type == "assistant" and .parent_tool_use_id == null) | .message.model // empty] | unique)}
