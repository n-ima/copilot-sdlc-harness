# SessionStart hook: フェーズゲート状況(GATE_STATUS)と教訓ログ(learnings)を会話開始時に自動注入する。
$ErrorActionPreference = 'SilentlyContinue'
$progress = "docs/00-overview/progress.md"
$learnings = "docs/00-overview/learnings.md"

$ctx = ""
if (Test-Path $progress) {
  $lines = Get-Content $progress -Raw
  $match = [regex]::Match($lines, '(?s)<!-- GATE_STATUS.*?-->')
  $block = if ($match.Success) { $match.Value } else { "" }
  $ctx = "現在のフェーズゲート状況(docs/00-overview/progress.md):`n$block"
} else {
  $ctx = "docs/00-overview/progress.md が未作成です。まず /00-start-project を実行してください。"
}

if (Test-Path $learnings) {
  # 「## 教訓」以降の箇条書きだけを注入する(先頭50行まで。肥大化してもコンテキストを圧迫しないため)
  $content = Get-Content $learnings
  $flag = $false
  $lessons = @()
  foreach ($line in $content) {
    if ($line -match '^## 教訓') { $flag = $true; continue }
    if ($flag -and $line -match '^- ') { $lessons += $line }
    if ($lessons.Count -ge 50) { break }
  }
  if ($lessons.Count -gt 0) {
    $ctx += "`n`nこのプロジェクトの教訓(docs/00-overview/learnings.md、必ず前提として扱うこと):`n" + ($lessons -join "`n")
  }
}

$out = @{
  hookSpecificOutput = @{
    hookEventName = "SessionStart"
    additionalContext = $ctx
  }
}
$out | ConvertTo-Json -Depth 5 -Compress
