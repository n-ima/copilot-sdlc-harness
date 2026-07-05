#!/usr/bin/env bash
# SessionStart/PreCompact hook: フェーズゲート状況(GATE_STATUS)と教訓ログ(learnings)を
# 会話開始時およびコンテキスト圧縮前に自動注入する(圧縮で注入済み情報が失われる穴を塞ぐ)。
event="${1:-SessionStart}"
progress="docs/00-overview/progress.md"
learnings="docs/00-overview/learnings.md"

ctx=""
if [[ -f "$progress" ]]; then
  block=$(awk '/<!-- GATE_STATUS/,/-->/' "$progress")
  ctx="現在のフェーズゲート状況(docs/00-overview/progress.md):\n${block}"
else
  ctx="docs/00-overview/progress.md が未作成です。まず /00-start-project を実行してください。"
fi

if [[ -f "$learnings" ]]; then
  # 「## 教訓」以降の箇条書きだけを注入する(先頭50行まで。肥大化してもコンテキストを圧迫しないため)
  lessons=$(awk '/^## 教訓/{flag=1;next}flag' "$learnings" | grep -E '^- ' | head -50)
  if [[ -n "$lessons" ]]; then
    ctx="${ctx}\n\nこのプロジェクトの教訓(docs/00-overview/learnings.md、必ず前提として扱うこと):\n${lessons}"
  fi
fi

esc=$(printf '%b' "$ctx" | sed ':a;N;$!ba;s/\n/\\n/g' | sed 's/"/\\"/g')
printf '{"hookSpecificOutput": {"hookEventName": "%s", "additionalContext": "%s"}}\n' "$event" "$esc"
