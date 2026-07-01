# PreToolUse hook: ハードコードされた認証情報っぽい文字列の書き込みを検知する。
# 高確度パターン(クラウドの鍵形式・秘密鍵ヘッダ等)はdeny、
# 汎用パターン(api_key=... 等、誤検知しうる)はaskに留める。
$ErrorActionPreference = 'SilentlyContinue'
$raw = [Console]::In.ReadToEnd()

$highConfidence = 'AKIA[0-9A-Z]{16}|-----BEGIN( RSA| EC| OPENSSH)? PRIVATE KEY-----|gh[pousr]_[A-Za-z0-9]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}'
$generic = '(api[_-]?key|secret|token|password)\\?[''"]?\s*[:=]\s*\\?[''"][A-Za-z0-9/+=_-]{16,}\\?[''"]'

if ($raw -match $highConfidence) {
  $out = @{
    continue = $true
    hookSpecificOutput = @{
      permissionDecision = "deny"
      permissionDecisionReason = "クラウド認証情報/秘密鍵とみられる文字列を検出しました。認証情報はコードやドキュメントに直接書かず、environment.mdに記載したシークレット管理先(GitHub Secrets等)を参照してください。"
    }
  }
} elseif ($raw -match $generic) {
  $out = @{
    continue = $true
    systemMessage = "ハードコードされた認証情報らしき文字列を検出しました(誤検知の可能性もあります)。意図した内容か確認してください。"
    hookSpecificOutput = @{
      permissionDecision = "ask"
      permissionDecisionReason = "認証情報らしきパターンを検出したため確認します。"
    }
  }
} else {
  $out = @{ continue = $true }
}
$out | ConvertTo-Json -Depth 5 -Compress
