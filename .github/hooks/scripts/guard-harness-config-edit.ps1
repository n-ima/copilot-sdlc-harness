# PreToolUse hook: ハーネス自体の運用ルール(エージェント定義/フック/AGENTS.md等)への
# 無断編集をdenyする。プロンプトインジェクションによる自己権限昇格・ガードレール解除を防ぐ。
# 注意: .github/skills/ は動的なSkill追加を許容するため対象外にしている。
$ErrorActionPreference = 'SilentlyContinue'
$raw = [Console]::In.ReadToEnd()
$file = $null
try {
  $obj = $raw | ConvertFrom-Json
  $file = $obj.tool_input.file_path
  if (-not $file) { $file = $obj.tool_input.filePath }
  if (-not $file) { $file = $obj.tool_input.path }
} catch {
  if ($raw -match '"(file_path|filePath|path)"\s*:\s*"([^"]*)"') {
    $file = $Matches[2]
  }
}

$protectedPattern = '(^|[\\/])\.github[\\/]agents[\\/]|(^|[\\/])\.github[\\/]hooks[\\/]|(^|[\\/])\.github[\\/]workflows[\\/]|(^|[\\/])AGENTS\.md$|(^|[\\/])CLAUDE\.md$|(^|[\\/])plugin\.json$|(^|[\\/])\.vscode[\\/]settings\.json$|(^|[\\/])\.claude[\\/]settings\.json$|(^|[\\/])\.claude[\\/]agents[\\/]|(^|[\\/])\.claude[\\/]commands[\\/]|(^|[\\/])\.agents[\\/]workflows[\\/]'

if ($file -and ($file -match $protectedPattern)) {
  $out = @{
    continue = $true
    hookSpecificOutput = @{
      permissionDecision = "deny"
      permissionDecisionReason = "ハーネスの運用ルール自体(agents/hooks/workflows/commands/AGENTS.md/CLAUDE.md/plugin.json/settings.json)はエージェントが自動で書き換えません。変更が必要な場合は人間が直接編集するか、明示的な指示のもとで行ってください。"
    }
  }
} else {
  $out = @{ continue = $true }
}
$out | ConvertTo-Json -Depth 5 -Compress
