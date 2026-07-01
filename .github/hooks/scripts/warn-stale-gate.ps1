# PostToolUse hook: 承認済み(done)のフェーズ文書が編集されたら、後続フェーズとの
# 整合確認を促す非ブロッキングの警告を出す(手動編集自体は妨げない)。
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

$progress = "docs/00-overview/progress.md"
if (-not $file -or -not (Test-Path $progress)) {
  @{ continue = $true } | ConvertTo-Json -Compress
  exit 0
}

$map = @{
  "docs/01-requirements/requirements.md" = "requirements"
  "docs/02-design/architecture.md"       = "design"
  "docs/03-implementation/tasks.md"      = "implementation"
  "docs/04-test/test-report.md"          = "test"
  "docs/05-release/release-checklist.md" = "release"
}

$normalized = $file -replace '\\', '/'
$phase = $null
foreach ($key in $map.Keys) {
  if ($normalized -like "*$key") {
    $phase = $map[$key]
    break
  }
}

if (-not $phase) {
  @{ continue = $true } | ConvertTo-Json -Compress
  exit 0
}

$progressText = Get-Content -Raw $progress
$status = $null
if ($progressText -match "(?m)^$([regex]::Escape($phase)):\s*(\S+)") {
  $status = $Matches[1]
}

if ($status -eq "done") {
  $out = @{
    continue = $true
    systemMessage = "この文書($phase)は承認済み(done)ですが編集されました。後続フェーズとの整合を確認してください(必要ならdocs/00-overview/progress.mdのGATE_STATUSも見直してください)。"
  }
} else {
  $out = @{ continue = $true }
}
$out | ConvertTo-Json -Compress
