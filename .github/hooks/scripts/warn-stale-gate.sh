#!/usr/bin/env bash
# PostToolUse hook: 承認済み(done)のフェーズ文書が編集されたら、後続フェーズとの
# 整合確認を促す非ブロッキングの警告を出す(手動編集自体は妨げない)。
input=$(cat)
file=$(printf '%s' "$input" | grep -oE '"(file_path|filePath|path)"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed -E 's/.*:[[:space:]]*"([^"]*)"/\1/')

# 判定ログ(ローカルのみ・gitignore対象)。ログ失敗はフック判定に影響させない。
hook_log() {
  { d="$(dirname "$0")/../logs" && mkdir -p "$d" &&
    printf '%s\t%s\t%s\t%s\n' "$(date +%Y-%m-%dT%H:%M:%S)" "$(basename "$0")" "$1" "$2" >>"$d/hook-decisions.log"; } 2>/dev/null || true
}

progress="docs/00-overview/progress.md"
if [[ -z "$file" || ! -f "$progress" ]]; then
  printf '%s\n' '{"continue": true}'
  exit 0
fi

phase=""
case "$file" in
  *docs/01-requirements/requirements.md) phase="requirements" ;;
  *docs/02-design/architecture.md) phase="design" ;;
  *docs/03-implementation/tasks.md) phase="implementation" ;;
  *docs/04-test/test-report.md) phase="test" ;;
  *docs/05-release/release-checklist.md) phase="release" ;;
esac

if [[ -z "$phase" ]]; then
  printf '%s\n' '{"continue": true}'
  exit 0
fi

status=$(grep -E "^${phase}:" "$progress" | head -1 | sed -E "s/^${phase}:[[:space:]]*//")

if [[ "$status" == "done" ]]; then
  hook_log warn "$file"
  printf '{"continue": true, "systemMessage": "この文書(%s)は承認済み(done)ですが編集されました。後続フェーズとの整合を確認してください（必要ならdocs/00-overview/progress.mdのGATE_STATUSも見直してください）。"}\n' "$phase"
else
  printf '%s\n' '{"continue": true}'
fi
