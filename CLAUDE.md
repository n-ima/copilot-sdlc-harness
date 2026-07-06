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
  Windows では Git Bash が必要）。加えて `permissions.deny` でハーネス設定ファイル
  （agents/hooks/commands/AGENTS.md等）とテンプレートへの Edit/Write を
  ツールレベルでハードブロックしている（フックと二重の機械的ガード）。
  **ハーネス本体リポジトリを保守する場合**（このテンプレート自体の改修）は、
  人間が一時的に `.claude/settings.json` の該当deny行を外して作業し、終わったら戻す。
- 大規模作業（タスク数十超の実装、コードベース全体の監査・移行）では、Max/Teamプラン
  環境なら **dynamic workflows**（多数サブエージェントの並列実行）の利用を、速度向上の
  理由と**トークンコスト増**を添えてユーザーに提案してよい（承認なしに使わない）。
  結果の記録先（tasks.md・docs/へのレポート保存）は通常フローと同じにし、
  「docs/が正」の原則を崩さない。詳細は `large-scale-development` スキル参照。
