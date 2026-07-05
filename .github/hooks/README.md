# .github/hooks/ について

VS Code の Agent Hooks（Preview機能）を使って、フェーズゲート運用を
「LLMの善意」ではなく機械的に補強するためのフック定義です。

## 含まれるフック

| ファイル | イベント | スクリプト | 動作 |
|---|---|---|---|
| `gate-hooks.json` | PreToolUse | `guard-template-edit.*` | `*_template.md` への直接編集を **deny**（コピーして実体ファイルを作るよう強制） |
| `gate-hooks.json` | PreToolUse | `guard-dangerous-git.*` | `git push` / `git tag` / `--force` / `reset --hard` / `rm -rf` を **ask**（毎回ユーザー確認） |
| `gate-hooks.json` | SessionStart | `inject-progress.*` | セッション開始時に `docs/00-overview/progress.md` のGATE_STATUSを自動でコンテキスト注入 |
| `gate-hooks.json` | PostToolUse | `warn-stale-gate.*` | 承認済み(done)のフェーズ文書（requirements.md等）が編集されたら、後続フェーズとの整合確認を促す非ブロッキングの警告を出す |
| `security-hooks.json` | PreToolUse | `guard-harness-config-edit.*` | `.github/agents/`, `.github/hooks/`, `AGENTS.md`, `plugin.json`, `.vscode/settings.json` への編集を **deny**（自己権限昇格・ガードレール解除の防止。`.github/skills/`は動的追加を許すため対象外） |
| `security-hooks.json` | PreToolUse | `guard-secret-leak.*` | クラウド鍵/秘密鍵ヘッダ等の高確度パターンは **deny**、汎用的な `api_key=...` 等は **ask** |
| `gate-hooks.json` | PreCompact | `inject-progress.* PreCompact` | コンテキスト圧縮前にGATE_STATUS・教訓を再注入（圧縮でSessionStart注入分が失われる穴を塞ぐ） |

## スクリプトの編集規則（事故防止）

- **`.ps1` はUTF-8 BOM付きが必須。** Windows PowerShell 5.1はBOMなしUTF-8の日本語を
  パースできず、フックが全滅する（派生ハーネスの初版で実際に発生した事故）。
  編集後の確認: `head -c 3 <file> | xxd` の出力が `efbbbf` であること。
- `.sh` はLF改行必須（`.gitattributes` で強制済み。CRLF化するとbashが実行できない）。

## 前提・注意点（正直な情報）

- Agent Hooksは執筆時点（2026年7月）で **Preview機能** であり、設定フォーマットや
  stdin/stdoutのペイロード形状は今後変わる可能性があります。
- スクリプトはペイロードのキー名を複数パターン（`file_path`/`filePath`/`path`、`command`等）で
  緩く探索し、**パース失敗時は安全側（`continue: true`、ブロックしない）に倒す**設計にしています。
  実際の挙動確認後、ペイロード形状に合わせて調整してください。
- 組織によっては `chat.useCustomAgentHooks` や関連設定が組織管理下で無効化されている場合があり、
  その場合フックは発火しません。フックが効かなくても、`AGENTS.md` の指示レベルのルールは
  引き続き有効です（二重の安全網という位置づけ）。
- Windowsでは `windows` フィールドのPowerShellスクリプトが、Git Bash/Linux/macでは
  `command`/`linux`/`osx` のbashスクリプトが使われます。

## 動作確認方法

`/hooks` をCopilot Chatで実行すると、GUIでフックの一覧・有効状態を確認できます。
