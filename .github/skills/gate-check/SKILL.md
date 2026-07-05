---
name: gate-check
description: docs/00-overview/progress.md の状態を読み書きしてフェーズゲート(未着手/進行中/ゲート承認待ち/完了)を判定・更新する手順。オーケストレーターや各フェーズエージェントが進捗確認・更新するときに使う。
---

# ゲート判定スキル

## 状態の正

`docs/00-overview/progress.md` の先頭にある機械可読ブロックが正。人間向けの表と
必ず一致させる。

```
<!-- GATE_STATUS
requirements: not_started | in_progress | pending_approval | done
design: not_started | in_progress | pending_approval | done
implementation: not_started | in_progress | pending_approval | done
test: not_started | in_progress | pending_approval | done
release: not_started | in_progress | pending_approval | done
-->
```

## 判定手順

1. `docs/00-overview/progress.md` が無ければ `progress_template.md` から作成する。
2. 各フェーズについて、対応する成果物ファイルの有無から実態を推測する。
   - requirements: `docs/01-requirements/requirements.md` が無ければ `not_started`。
     あれば `in_progress`。「未確定事項」欄が空でユーザー承認を得ていれば `done`。
   - design: `docs/02-design/architecture.md`
   - implementation: `docs/03-implementation/tasks.md`（全チェックボックス完了で`done`）
   - test: `docs/04-test/test-report.md`
   - release: `docs/05-release/release-checklist.md`
3. GATE_STATUSブロックと実態がずれていれば、ユーザーに更新してよいか確認してから書き換える
   （エージェントが黙って `done` にしない。ユーザーの明示的な承認発言があって初めて `done` にする）。
4. `.github/hooks/scripts/` のゲート系フックはこのGATE_STATUSブロックを直接パースするため、
   フォーマット（インデント・キー名）を崩さない。

## 改修サイクル（リリース後の修正時）

AGENTS.md「差分駆動の原則」の4分類に基づき、改修の起点に応じて該当フェーズを
`in_progress` へ戻す。

- 要件・設計の変更を伴う改修 → 該当する上流フェーズ（requirements または design）から
- 変更を伴わないバグ修正 → implementation から
- 戻すのは**該当フェーズ以降のみ**（全フェーズのやり直しはしない）
- 改修理由を `progress.md` の「未確定事項・申し送り」に1行記録する

## 横断整合監査（ユーザーが「整合チェック」「監査」を求めたとき）

フェーズ判定は個々の成果物の有無を見るが、この監査は**成果物間の食い違い**を検出する。
改修が数回重なった後に特に効く。以下を突き合わせ、食い違いを表で報告する（修正はしない）。

1. `requirements.md` の要求ID ↔ 設計のトレーサビリティ表（対応漏れ）
2. `architecture.md` / 詳細設計 ↔ `tasks.md` のタスク
   （設計にない実装・実装されない設計）
3. `tasks.md` ↔ テスト計画/レポートのケース対応
4. 文書中の実装ファイル・テストへの参照 ↔ 実在するか（削除・リネーム漏れ）
5. GATE_STATUS ↔ 各成果物の実態
6. 「実装乖離あり」注記 ↔ 解消期限切れがないか
