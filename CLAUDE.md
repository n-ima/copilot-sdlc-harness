# Claude Code 用エントリポイント

このハーネスの共通指示の正は AGENTS.md（下でインポート）。ここには内容を書かない
（Claude Code は AGENTS.md を直接読まないため、このファイルが橋渡しをする）。

@AGENTS.md

## Claude Code 固有の対応表

- フェーズの起動: `.claude/commands/` のスラッシュコマンド（`/03-design-architecture` 等）を
  使う。各コマンドは `.github/agents/*.agent.md` の役割定義と `.github/prompts/` の
  起動指示を読み込む薄いアダプタで、Copilot 側と同じ振る舞いになる。
- サブエージェント: AGENTS.md の `runSubagent` は Claude Code では **Task ツール**で
  `.claude/agents/` の同名サブエージェント（reviewer / task-worker / spec-critic）を
  呼ぶことに読み替える。
- スキル: `.claude/skills/` の各スキルは `.github/skills/` の正へのポインタ。
  新しいスキルを作るときは正（`.github/skills/`）とポインタの両方を作る
  （`skill-authoring` スキル参照）。
- ハンドオフボタンは Claude Code には無い。フェーズ移行は案内どおり
  「新しいセッションで該当スラッシュコマンドを実行」する。
- フックは `.claude/settings.json` に定義済み（Copilot 側と同じスクリプトを共用。
  Windows では Git Bash が必要）。
