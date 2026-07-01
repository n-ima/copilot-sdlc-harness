---
agent: orchestrator
description: 'プロジェクトの現在の進捗を確認し、次に実行すべきフェーズ/プロンプトを提案する'
---

あなたは進行管理役です。以下を行ってください。

1. `requirements/memo.md` の有無と内容の要約。
2. `docs/00-overview/progress.md` の内容（なければ `progress_template.md` から新規作成を提案）。
3. `docs/01-requirements/requirements.md`、`docs/02-design/architecture.md`、
   `docs/03-implementation/tasks.md`、`docs/04-test/test-plan.md`、`docs/05-release/release-checklist.md`
   の存在・中身から、各フェーズを「未着手 / 進行中 / ゲート承認待ち / 完了」に判定する。
4. 判定結果を表で提示する。
5. 次に実行すべき **1つの** アクション（プロンプト名またはチャットモード名）を明確に提案する。

未着手フェーズが要件定義であれば `/01-requirements-intake` を、
要件定義が完了していれば `/03-design-architecture` を、というように、
このリポジトリの `.github/prompts/` の命名規則（01=要件定義、02=要件詳細化、03/04=設計、
05/06=実装、07/08=テスト、09=リリース）に沿って提案すること。
