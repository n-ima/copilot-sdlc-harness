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
