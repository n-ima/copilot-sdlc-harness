#!/usr/bin/env bash
# PreToolUse hook: *_template.md への直接編集をブロックする。
# 想定外のペイロード形状でも安全側(継続許可)に倒す。
input=$(cat)
file=$(printf '%s' "$input" | grep -oE '"(file_path|filePath|path)"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed -E 's/.*:[[:space:]]*"([^"]*)"/\1/')

# 判定ログ(ローカルのみ・gitignore対象)。ログ失敗はフック判定に影響させない。
hook_log() {
  { d="$(dirname "$0")/../logs" && mkdir -p "$d" &&
    printf '%s\t%s\t%s\t%s\n' "$(date +%Y-%m-%dT%H:%M:%S)" "$(basename "$0")" "$1" "$2" >>"$d/hook-decisions.log"; } 2>/dev/null || true
}

if [[ "$file" == *_template.md ]]; then
  hook_log deny "$file"
  printf '%s\n' '{"continue": true, "hookSpecificOutput": {"permissionDecision": "deny", "permissionDecisionReason": "テンプレートファイルは直接編集せず、コピーして実体ファイル(例: requirements_template.md -> requirements.md)を作成してください。"}}'
else
  printf '%s\n' '{"continue": true}'
fi
