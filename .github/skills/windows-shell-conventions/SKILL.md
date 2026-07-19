---
name: windows-shell-conventions
description: Windows + Git Bash + PowerShell 併用環境でコマンド実行するときの既知の落とし穴集。ドライブレター大文字小文字、autocrlfとgit stashのCRLF事故、PowerShellインライン呼び出しの構文崩壊、curlの日本語文字化け、heredoc/Editのバックスラッシュ破壊、Voltaシム、パイプのSIGPIPEなど。Windows環境で実装・テスト・リリースのコマンドを実行する全エージェントが使う。
---

# Windows シェル規約（Git Bash / PowerShell 併用環境の既知の落とし穴）

Windows 上で Git Bash と PowerShell を併用する開発環境には、プロジェクトを問わず
再発する実行時の落とし穴がある。複数の実プロジェクトで試行錯誤の末に確立された
回避策の集約であり、**該当環境ではこの一覧を前提にしてから**コマンドを実行する
（同じ発見コストを二度払わない）。プロジェクト固有の確定コマンドは従来どおり
`docs/00-overview/learnings.md` に記録する。

## 共通原則: 複雑なワンライナーを書かない

以下の落とし穴の多くは「シェルのワンライナーに特殊文字・複合手順を詰め込む」ことで
発生する。**パイプライン・特殊文字・複数行ロジックを含む処理は、スクリプトファイル
（`.ps1` / `.sh` / `.mjs`）に書いてファイル実行する**のが最も確実な共通回避策。

## 1. ドライブレターは大文字で（テストランナーのモジュール二重ロード）

cwd が小文字ドライブ（`d:\...`）だと、Vitest 等がモジュール解決の不一致
（同一ファイルの二重ロード）を起こしテストが全滅する
（例: vitest projects 実行が全ファイルで `TypeError: ... (reading 'config')`）。

- **回避**: npm scripts は必ず大文字ドライブパスへ `cd` してから実行する。
  例: `cd "D:/path/to/project" && npm run check`

## 2. `git stash -u` と autocrlf の相性（未追跡ファイルのCRLF化）

`core.autocrlf` 有効時に `git stash -u` を使うと、未追跡ファイルが stash 復元時に
LF→CRLF 変換され、Prettier 等のフォーマットチェックが大量に落ちる。

- **回避**: 未追跡ファイルが多いリポジトリでは `git stash -u` を使わない。
  落ちた場合はフォーマッタの一括適用（例: `npm run format`）で復旧できる。

## 3. Git Bash から PowerShell をインラインで呼ばない

Git Bash から PowerShell をインライン（`powershell -Command "... $_ ..."`）で呼ぶと、
`$_` 等が Bash 側の展開（extglob）に干渉して構文エラーになる。

- **回避**: パイプラインを使う PowerShell は `.ps1` ファイルに書いて
  `powershell -File script.ps1` で実行する。
- **応用（プロセス停止）**: `npm run dev` 等で concurrently 配下に複数の node が残る場合、
  PID 単発 kill では止まらない。`.ps1` で `Get-CimInstance Win32_Process` の
  CommandLine からプロジェクト名を含む node プロセスを特定し、
  `taskkill /F /T /PID <pid>`（`/T` でツリーごと）で停止する。

## 4. curl の日本語ボディは直書きしない（Content-Length 不一致）

Git Bash の curl で日本語を含む JSON を `-d '{"title":"日本語"}'` と直書きすると、
コマンドライン経由の文字コード変換で Content-Length が不一致になり
400（バリデーションエラー）になる。

- **回避**: ボディを UTF-8 でファイルに書き、`curl --data-binary @body.json` で送る。

## 5. heredoc / Edit ツールのバックスラッシュ破壊

Bash ツール経由の heredoc は `\\` が `\` に潰れることがあり、Edit ツールは文中の
`\uXXXX` 表記を実文字に変換して書き込むことがある（NUL 文字リテラルの混入という
実バグの原因になった実例あり）。

- **回避**: バックスラッシュを含む文字列は
  `String.fromCharCode(92) + 'u0000'` のように文字コードで組み立てる。
  複数行の node 実行は `node -e` でなくスクリプトファイルに書く
  （複数行 `node -e` は出力が丸ごと消えることがある）。
- **検証**: エスケープが重要なファイルを書いた後は、意図した文字が入ったか
  `grep` やバイト確認で検証する（見た目では気づけない）。

## 6. Volta シムと環境変数差し替えの組み合わせ

`HOME`/`USERPROFILE` を一時フォルダへ差し替えて node を起動すると、Volta のシム
`node` は `Volta error: Could not determine LocalAppData directory` で起動できない。

- **回避**: 先に `REAL_NODE=$(node -e "console.log(process.execPath)")` で実体の
  node.exe を解決し、それを直接実行する。
- **注意**: `A && B & PID=$!` の形は `&` が行全体を背景化して変数代入ごと子シェルに
  行くため意図どおり動かない。起動→疎通確認のような複合手順はスクリプトファイルにする。

## 7. テスト実行の出力を `head` 等へパイプしない（SIGPIPE で中断）

`npx playwright test | head` のようにパイプ先が先に閉じると SIGPIPE で
テストランナー自体が中断され、結果ファイル（test-results 等）が消える。

- **回避**: 長い出力はファイルへリダイレクト（`> result.log 2>&1`）してから読む。

## 運用

- ここに無い落とし穴を新たに確立したら、まずプロジェクトの `learnings.md` に記録し、
  振り返り（/10-retrospective）で汎用性があると判断されたらこのスキルへ還流する。
- 各回避策は「成功したコマンドの形」をそのまま使う（形を変えると別の穴を踏む）。
