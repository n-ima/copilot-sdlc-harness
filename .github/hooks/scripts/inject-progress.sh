#!/usr/bin/env bash
# SessionStart hook: 現在のフェーズゲート状況(GATE_STATUS)を会話開始時に自動注入する。
progress="docs/00-overview/progress.md"

if [[ -f "$progress" ]]; then
  block=$(awk '/<!-- GATE_STATUS/,/-->/' "$progress")
  esc=$(printf '%s' "$block" | sed ':a;N;$!ba;s/\n/\\n/g' | sed 's/"/\\"/g')
  printf '{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": "現在のフェーズゲート状況(docs/00-overview/progress.md):\\n%s"}}\n' "$esc"
else
  printf '%s\n' '{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": "docs/00-overview/progress.md が未作成です。まず /00-start-project を実行してください。"}}'
fi
