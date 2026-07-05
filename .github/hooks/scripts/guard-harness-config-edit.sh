#!/usr/bin/env bash
# PreToolUse hook: ハーネス自体の運用ルール(エージェント定義/フック/AGENTS.md等)への
# 無断編集をdenyする。プロンプトインジェクションによる自己権限昇格・ガードレール解除を防ぐ。
# 注意: .github/skills/ は動的なSkill追加を許容するため対象外にしている。
input=$(cat)
file=$(printf '%s' "$input" | grep -oE '"(file_path|filePath|path)"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed -E 's/.*:[[:space:]]*"([^"]*)"/\1/')

protected_pattern='(^|/)\.github/agents/|(^|/)\.github/hooks/|(^|/)\.github/workflows/|(^|/)AGENTS\.md$|(^|/)plugin\.json$|(^|/)\.vscode/settings\.json$'

if [[ -n "$file" ]] && printf '%s' "$file" | grep -Eiq "$protected_pattern"; then
  printf '%s\n' '{"continue": true, "hookSpecificOutput": {"permissionDecision": "deny", "permissionDecisionReason": "ハーネスの運用ルール自体(agents/hooks/workflows/AGENTS.md/plugin.json/settings.json)はエージェントが自動で書き換えません。変更が必要な場合は人間が直接編集するか、明示的な指示のもとで行ってください。"}}'
else
  printf '%s\n' '{"continue": true}'
fi
