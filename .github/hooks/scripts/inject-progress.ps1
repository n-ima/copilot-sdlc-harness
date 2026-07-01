# SessionStart hook: 現在のフェーズゲート状況(GATE_STATUS)を会話開始時に自動注入する。
$ErrorActionPreference = 'SilentlyContinue'
$progress = "docs/00-overview/progress.md"

if (Test-Path $progress) {
  $lines = Get-Content $progress -Raw
  $match = [regex]::Match($lines, '(?s)<!-- GATE_STATUS.*?-->')
  $block = if ($match.Success) { $match.Value } else { "" }
  $out = @{
    hookSpecificOutput = @{
      hookEventName = "SessionStart"
      additionalContext = "現在のフェーズゲート状況(docs/00-overview/progress.md):`n$block"
    }
  }
} else {
  $out = @{
    hookSpecificOutput = @{
      hookEventName = "SessionStart"
      additionalContext = "docs/00-overview/progress.md が未作成です。まず /00-start-project を実行してください。"
    }
  }
}
$out | ConvertTo-Json -Depth 5 -Compress
