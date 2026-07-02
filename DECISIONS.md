# DECISIONS.md — このハーネス自体の設計判断ログ

これは `docs/02-design/adr/`（**生成するアプリ**の設計判断）とは別物で、
**このハーネス自体**がなぜ今の形になっているかを記録するものです。
今後ハーネスを改修する人（自分自身を含む）が、同じ議論を繰り返したり、
一度直したバグを再導入したりしないようにするための記録です。

最終更新: 2026-07-02

各項目は「決定」「根拠・出典」「捨てた選択肢」の順で書く（`docs/02-design/adr/adr_template.md` と
同じ形式を踏襲）。

---

## D001: chatmode.md ではなく custom agents(.agent.md) を採用

- **決定**: `.github/chatmodes/*.chatmode.md` ではなく `.github/agents/*.agent.md` を使う。
- **根拠**: VS Code公式ドキュメントで「custom chat modes は custom agents に名称・仕様変更され、
  `.chatmode.md` は非推奨。`.agent.md` にリネームして使う」と明記されている
  ([VS Code Docs: Custom agents](https://code.visualstudio.com/docs/agent-customization/custom-agents))。
  最初のバージョンは学習知識だけで `.chatmode.md` を使っており、実際に調べ直して判明した誤り。
- **捨てた選択肢**: `.chatmode.md` のまま運用（非推奨のため不採用）。

## D002: Agent Skills(SKILL.md) の採用

- **決定**: 要件引き出し・ADR作成・テストケース設計・ゲート判定などの手順を
  `.github/skills/*/SKILL.md` として部品化する。
- **根拠**: VS Code / Copilot CLI / Copilot cloud agent 横断の公開標準（agentskills.io）として
  Agent Skills が存在し、`name`/`description` だけを常時読み込み、本文は関連時のみ読み込む
  「段階的開示」でコンテキスト消費を抑える設計になっている
  ([VS Code Docs: Agent Skills](https://code.visualstudio.com/docs/agent-customization/agent-skills))。
  当初はこの仕組みの存在自体を見落としていた。
- **捨てた選択肢**: 手順をすべて各エージェントファイルの本文に書く（肥大化し、他エージェントから
  再利用できない）。

## D003: Agent Hooks による機械的なゲート強制

- **決定**: `.github/hooks/*.json` + シェルスクリプトで、指示だけでは守られない可能性がある
  ルール（テンプレ直接編集の禁止、危険なgit操作の確認、ハーネス設定自体の保護、
  シークレットのハードコード検知）を機械的に強制する。
- **根拠**: 最初のハーネスは「LLMが指示を守ってくれることを祈るだけ」の強制力ゼロの構成だった
  という指摘を受け、VS Code公式のAgent Hooks（Preview機能）を調査して採用
  ([VS Code Docs: Agent hooks](https://code.visualstudio.com/docs/agent-customization/hooks))。
- **注意**: Preview機能であり、stdin/stdoutのペイロード形状は将来変わりうる。
  スクリプトはパース失敗時に安全側（許可）に倒す設計にしている。

## D004: reviewer サブエージェントによる別セッションレビュー

- **決定**: `test` エージェントは全テスト成功後、リリースに進む前に必ず `runSubagent` で
  `reviewer`（読み取り専用・独立コンテキスト）を1回呼び出す。
- **根拠**: 「実装した本人がそのまま自己レビューして自己承認する」バイアスを避けるため、
  独立したコンテキストでのレビューが公式に推奨されている
  ([VS Code Docs: Subagents](https://code.visualstudio.com/docs/agents/subagents) の
  code-reviewサブエージェント例)。ユーザーからの「レビューは別セッションで行った方がよい」
  という指摘とも一致し、それが単なる思い込みではなく公式ベストプラクティスであることを確認した。
- **捨てた選択肢**: 並列の多視点レビュー（正しさ用・セキュリティ用・品質用を別々に並列実行）は
  精度は上がるがモデル呼び出し回数が視点の数だけ増えてコストが積み上がるため、既定では不採用。
  プロジェクトの重要度に応じてユーザーが明示的に要求した場合のみ有効にする。

## D005: security-review Skill は公式のものを取り込む

- **決定**: セキュリティレビューの手順をゼロから書かず、`github/awesome-copilot` の公式
  `security-review` Skillを参考にして `.github/skills/security-review/SKILL.md` を作成した。
- **根拠**: ユーザーからの「公式のSkillがあれば採用する」という方針に基づき、
  8ステップの手順（スコープ確定→依存監査→シークレットスキャン→脆弱性深掘り→
  クロスファイル解析→自己検証→レポート作成→修正案提示、ただし自動適用はしない）を
  このハーネスのドキュメント構成に合わせて適合させた。
- **横展開**: `skill-authoring` Skill内に「ゼロから書く前に公式/コミュニティ製Skillの
  流用を優先する」という手順として一般化した（デプロイ環境Skill・スタック規約Skillにも適用）。

## D006: ハーネス自体の設定ファイルへの自動編集を禁止

- **決定**: `.github/agents/`, `.github/hooks/`, `AGENTS.md`, `plugin.json`,
  `.vscode/settings.json` へのエージェントによる自動編集を `security-hooks.json` でdenyする。
  `.github/skills/` は動的追加を許すため対象外。
- **根拠**: プロンプトインジェクション等による自己権限昇格・ガードレール解除を防ぐという
  セキュリティガードレールの要求に対応。`.github/CODEOWNERS` テンプレートとブランチ保護の
  組み合わせも合わせて推奨。

## D007: 呼び出し頻度が高いエージェントは `model: auto`

- **決定**: `orchestrator` / `implement` / `test` / `task-worker` は `model: auto`。
  `design` / `release` / `reviewer` はモデルを固定せず、必要に応じてユーザーが強いモデルに
  切り替えることを推奨する（本文にその旨を明記）。
- **根拠**: GitHub Copilotは2026年6月からトークン量に応じた従量課金（GitHub AI Credit）に
  移行しており、「利用可能な中で最も安価なモデルを自動選択するAuto」には追加の割引もある。
  一方、設計判断やレビューの誤りは手戻りコストの方が高くつくため、そこだけは強いモデルを
  検討する価値がある、という非対称な扱いにした。

## D008: プロンプトファイルは `agent:` で明示的にバインドする

- **決定**: `.github/prompts/*.prompt.md` の frontmatterから、旧来の `mode: 'agent'` /
  `tools: [...]` を削除し、`agent: <name>` で対応するCustom Agentに明示的にバインドした。
- **根拠**: 実際に使い方ドキュメントを書きながらシナリオを検証した際に、
  「`agent:` を指定しない場合、プロンプトは選択中の別エージェント/既定モードのツール制限の
  ままで実行される」という仕様（[VS Code Docs: Prompt files](
  https://code.visualstudio.com/docs/agent-customization/prompt-files)）を確認し、
  最初のバージョンではこのバインディングが漏れていたことが判明した。
  これは「ユーザーに言われたから直した」のではなく、シナリオ検証で見つけた実装ミス。

## D009: orchestrator に `edit` 権限を付与（progress.md初回作成のため）

- **決定**: `orchestrator` の `tools` に `edit` を追加。ただし「未着手/進行中」への機械的な
  更新はそのまま行ってよいが、「完了(done)」への変更は必ずユーザー承認を要する、という
  区別を本文に明記。
- **根拠**: 実際にシナリオを辿って検証した際、`orchestrator` が読み取り専用のままだと
  初回起動時に `docs/00-overview/progress.md` を作成できない（`gate-check` Skillの
  「無ければ作成する」という指示を実行する権限がない）というバグを発見した。

## D010: reviewer の発見事項を test-report.md / security-review-report.md に転記する

- **決定**: `reviewer` は読み取り専用（`edit`ツールなし）のため、発見事項をファイルに残すのは
  呼び出し元の `test` エージェントの責務であると明記し、`docs/04-test/security_review_report_template.md`
  を新設した。
- **根拠**: シナリオ検証で「独立レビューの結果が記録に残らず消えてしまう」抜けを発見した
  （全自動区間だからといって人が後から確認できなくなってよいわけではない）。

## D011: 実装ループを `task-worker` サブエージェントに分割（コンテキストロット対策）

- **決定**: `implement` エージェントはコードを直接書かず、タスク1つにつき1回
  `runSubagent` で `task-worker`（独立コンテキスト）を呼び出す方式に変更した。
- **根拠**: Anthropicの公式エンジニアリングブログ
  ([Effective context engineering for AI agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents))
  で報告されている "context rot"（会話が長くなるほど想起精度が落ちる現象）への対策。
  「1タスク1セッション」という経験則は、この現象に対する合理的な対策であることを確認した。
  ユーザーからの疑問がきっかけで調査し、既存の設計（全タスクを1つの会話でノンストップ実装）が
  この観点で弱点であることが判明したため修正した。
- **横展開**: フェーズ間・フェーズ内でも「会話が長くなってきたら新しいセッションを始めて
  `docs/` を読み直す」という原則をAGENTS.md/USAGE.mdに明文化した
  （ドキュメントが記憶であり、会話が記憶ではない、という設計思想の言語化）。

## D012: Hooksスクリプトの実機バグ2件を修正

- **決定/修正内容**:
  1. `guard-secret-leak` の正規表現が、VS CodeのフックペイロードがJSON文字列として
     引用符を `\"` にエスケープすることを考慮しておらず、典型的な `api_key = "..."` の
     漏洩パターンを検知できていなかった。エスケープされた引用符も許容するよう修正。
  2. Windows PowerShell 5.1 は `.ps1` ファイルがBOMなしUTF-8だと日本語文字列を誤読し、
     全PowerShell版フックがパースエラーで起動不能だった。全 `.ps1` をBOM付きUTF-8で
     保存し直して解決。
- **根拠**: 「実機で動かして確認したか」という指摘を受け、実際にbash/PowerShellでhookスクリプトに
  サンプル入力を与えて検証した結果、上記2件が実際に動かないことを確認した
  （机上のレビューだけでは見つからなかった）。
- **教訓**: 日本語（非ASCII）を含むテキストをWindows向けスクリプトに埋め込む場合、
  BOM付きUTF-8での保存を徹底する。JSON経由のペイロードを正規表現で扱う場合、
  エスケープされた引用符を考慮する。

## D013: Playwright（ブラウザ動作確認）をテストフェーズに組み込み

- **決定**: 生成するアプリがブラウザベースのUIを持つ場合、`test` エージェントは
  ユニット/結合テストに加えて、Microsoft公式の Playwright MCP サーバー
  （`@playwright/mcp`）を `.vscode/mcp.json` に追加し、実際にページを表示・操作して
  確認する手順を `test-case-design` Skillに追加した。
- **根拠**: ユーザーからの「ブラウザで確認できるものはPlaywrightも使って表示や動作確認を行う」
  という要求に基づき、Microsoft公式のPlaywright MCPサーバー
  ([microsoft/playwright-mcp](https://github.com/microsoft/playwright-mcp)) の存在と
  VS Codeでの設定方法を確認した上で採用。
- **設計判断**: ハーネス自体には（このテンプレートにはUIが無いため）`.vscode/mcp.json` を
  事前に用意せず、設計フェーズでUIありと判明した時点でテストエージェントが動的に追加する
  （D005の「動的Skill/設定は判明した時点で作る」という方針と一貫させた）。

## D014: ゲート陳腐化検知フックの追加

- **決定**: 承認済み（GATE_STATUSが `done`）のフェーズに対応するファイル
  （`requirements.md`, `architecture.md`, `tasks.md`, `test-report.md`,
  `release-checklist.md`）が編集された場合、`PostToolUse` フックで
  「承認済みだが編集された。後続フェーズとの整合を確認すること」という
  非ブロッキングの `systemMessage` を出す。
- **根拠**: 「要件や設計を手動で直して続けてよいか」という質問に対し、
  「ファイル編集自体は安全（各エージェントは会話ではなくファイルを読み直す設計のため）だが、
  承認後に変更すると下流フェーズとの整合が自動チェックされないままになる」という
  非対称性があったため、機械的なリマインダーを追加して補強した。

## D015: 要求文にEARS記法を採用

- **決定**: `requirements-elicitation` Skillと要件定義書テンプレートに、EARS
  （Easy Approach to Requirements Syntax）記法・INVEST基準・品質特性シナリオ
  （刺激→環境→応答→応答測定の定量NFR）・前提/リスク台帳を追加した。
- **根拠**: EARSはRolls-Royce発で[Airbus/NASA/Intel/Bosch等が採用](https://alistairmavin.com/ears/)する
  業界標準の要求構文であり、AWSのspec駆動開発IDE「Kiro」も中核に採用している。
  「要件定義の専門性が高度なレベルか」という問いに対し、Given/When/Thenだけでは
  要求文自体の曖昧さ（「適切に」「なるべく」等）を排除する仕組みが無かったため補強した。
- **捨てた選択肢**: ISO/IEC/IEEE 29148の完全準拠テンプレート（重すぎて対話型の
  要件定義の良さを損なう。EARSは軽量で訓練コストが低いことが採用理由）。

## D016: spec-critic サブエージェント（上流の独立レビュー）

- **決定**: `reviewer`（コード）と同じ「別セッションでの独立レビュー」パターンを
  要件定義・設計のゲート承認前にも適用する `spec-critic` サブエージェントを新設した。
  既定のサブエージェント経路は4つ（requirements→spec-critic, design→spec-critic,
  implement→task-worker, test→reviewer）になった。
- **根拠**: 欠陥の修正コストは下流ほど大きい（要件の欠陥が実装後に見つかると
  手戻りが最大になる）ため、独立レビューの費用対効果が最も高いのは上流。
  呼び出しは各ゲート1回に限定し、コスト増を最小にしている。

## D017: 成長ループ（learnings / retrospective / 本体還流）

- **決定**: 「使うたびに賢くなるハーネス」を実現する3層の記録構造を導入した。
  1. `docs/00-overview/learnings.md` — 訂正・失敗の都度1行追記する教訓ログ。
     SessionStartフックが自動注入するため、書けば以後の全セッションに確実に効く。
  2. `docs/06-retrospective/` + `/10-retrospective` — リリース後の構造化された振り返り。
     摩擦を「ハーネス改善/プロジェクト固有/一過性」に分類し、改善提案表を作る。
  3. 本体還流 — 改善提案と再利用可能Skillをハーネス本体リポジトリに人間が適用し、
     DECISIONS.mdに根拠つきで記録する。以後の新プロジェクトは改善済みから始まる。
- **根拠**: learnings.md（教訓ファイル）の蓄積は自己改善エージェントの確立された
  パターン。ポイントは「記録が実際に次の入力になる」機構で、
  単に書くだけでなくSessionStartフックでの自動注入まで実装した（注入されない記録は
  存在しないのと同じ）。ハーネス本体はテンプレートとして各プロジェクトにコピーされるため、
  プロジェクト内の学びを本体に還流する明示的な経路（振り返り→改善提案表→人間による適用）を
  定義した。ハーネス設定はセキュリティ上自動編集禁止（D006）のため、還流の適用は
  意図的に人間の作業としている。
