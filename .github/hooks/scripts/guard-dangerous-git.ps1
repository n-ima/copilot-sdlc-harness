# PreToolUse hook: push/tag/force系のgit操作は毎回ユーザーに確認(ask)させる。
# denyではなくaskにしているのは、リリースフェーズなど正当なタイミングもあるため。
$ErrorActionPreference = 'SilentlyContinue'
$raw = [Console]::In.ReadToEnd()
$cmd = $null
try {
  $obj = $raw | ConvertFrom-Json
  $cmd = $obj.tool_input.command
} catch {
  if ($raw -match '"command"\s*:\s*"([^"]*)"') {
    $cmd = $Matches[1]
  }
}

$dangerPattern = 'git\s+(push|tag)|reset\s+--hard|push\s+(-f|--force)|rm\s+-rf'

if ($cmd -and ($cmd -match $dangerPattern)) {
  $out = @{
    continue = $true
    systemMessage = "push/tag/force系またはrm -rfはAGENTS.mdの方針により都度確認が必要です。"
    hookSpecificOutput = @{
      permissionDecision = "ask"
      permissionDecisionReason = "外部/履歴に影響する可能性がある操作のため確認します。"
    }
  }
} else {
  $out = @{ continue = $true }
}
$out | ConvertTo-Json -Depth 5 -Compress
