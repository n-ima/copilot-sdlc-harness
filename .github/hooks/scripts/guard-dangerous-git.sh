#!/usr/bin/env bash
# PreToolUse hook: push/tag/force系のgit操作は毎回ユーザーに確認(ask)させる。
# denyではなくaskにしているのは、リリースフェーズなど正当なタイミングもあるため。
input=$(cat)
cmd=$(printf '%s' "$input" | grep -oE '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed -E 's/.*:[[:space:]]*"([^"]*)"/\1/')

danger_pattern='git[[:space:]]+(push|tag)|reset[[:space:]]+--hard|push[[:space:]]+(-f|--force)|rm[[:space:]]+-rf'

if printf '%s' "$cmd" | grep -Eiq "$danger_pattern"; then
  printf '%s\n' '{"continue": true, "systemMessage": "push/tag/force系またはrm -rfはAGENTS.mdの方針により都度確認が必要です。", "hookSpecificOutput": {"permissionDecision": "ask", "permissionDecisionReason": "外部/履歴に影響する可能性がある操作のため確認します。"}}'
else
  printf '%s\n' '{"continue": true}'
fi
