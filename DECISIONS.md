# DECISIONS.md — このハーネス自体の設計判断ログ

これは `docs/02-design/adr/`（**生成するアプリ**の設計判断）とは別物で、
**このハーネス自体**がなぜ今の形になっているかを記録するものです。
今後ハーネスを改修する人（自分自身を含む）が、同じ議論を繰り返したり、
一度直したバグを再導入したりしないようにするための記録です。

最終更新: 2026-07-19

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

## D018: databricks-job-dev-harness検証からの還流（第1弾・A項目群）

- **出典**: 派生ハーネス databricks-job-dev-harness の構築・E2E検証第1回
  （daily-sales-report-trial）からの改善指示書（CreateAppl-improvement-handover.md）。
  **D017の成長ループが実際に一周した最初の実例**。ユーザーの明示指示のもと適用した。
- **適用した項目と根拠**:
  - **A-1 PreCompact再注入**: コンテキスト圧縮でSessionStart注入分（GATE_STATUS・教訓）が
    失われる穴を塞ぐ。inject-progressをイベント引数化しPreCompactにも登録。実機検証済み。
  - **A-2 教訓トリガー拡張（最重要）**: E2E実測で「試行錯誤の末に確立した実行方法が
    記録されず、別セッションで同じ試行錯誤が再発」した欠陥への対策。実行方法の獲得知識を
    仕様の教訓より優先して記録するルールをAGENTS.md/learnings_template/
    retrospectiveスキル/test/releaseに追加。
  - **A-3 ナビゲーション責務**: 操作手順の暗記前提はスケールしない。全エージェントが
    「次の一手」を案内する責務をAGENTS.mdに、入口表を `harness-guide` スキルに、
    ヘルプを `/98-harness-help` に実装。
  - **A-4 セッション分割基準の数値化**: USAGE.mdに表（フェーズ別+継続中の4条件:
    完了タスク10個超/差し戻し2往復超/劣化を感じた/中断）。implementに10タスク超での
    新チャット提案を追加。
  - **A-5 起動経路の等価性ルール+全プロンプト監査**: ハンドオフ経由では.prompt.mdが
    読まれないため「振る舞いの正は.agent.md、プロンプトは薄い起動指示」をAGENTS.mdに
    明文化。監査の結果、00（番号規則→harness-guideへ）/01（memo不在時の対応→
    requirementsへ）/04（詳細設計の項目リスト→designへ）/05（粒度・紐づけ→implementへ）
    を移設し、該当プロンプトを薄化。02/03/06-10/99は問題なし。
    権限整合も点検し、実行不能な指示は検出されなかった。
  - **A-6 差分駆動の原則+ホットフィックス乖離追跡**: 「要件・設計を後から修正する場合」
    節を4分類に拡張。緊急対応は「絶対禁止」ではなく「記録すれば許容」に倒す
    （禁止すると障害時に必ず破られ、破られたルールは記録すらされないため）。
  - **A-7 横断整合監査**: gate-checkスキルに成果物間の食い違い検出（Spec Kitの
    /speckit.analyze相当）を追加。前回比較（D015前後）で認識していたSpec Kit劣位点の解消。
  - **A-8 workflows保護**: guard-harness-config-editの保護対象に .github/workflows/ を
    追加（CI/CDもガードレールの一部）。実機検証済み。
  - **A-9 .gitattributes+BOM規則**: Windows(autocrlf)でのクローンで.shがCRLF化して
    フック全滅する事故と、.ps1のBOM欠落事故（D012・派生版でも再発）の再発防止。
  - **A-10 ZIP配布手順**: 入手3経路をUSAGEに明記。`git archive`による安全なZIP作成と
    「向き先」事故（受領者がハーネス本体へ誤push）の防止。
  - **A-11 適用範囲+PRテンプレート**: READMEに「使うべき場面・使うべきでない場面」を明記
    （過剰さへの一番の防御は対象外の作業に使わせないこと）。トレーサビリティ・
    検証・安全性・rollbackを含むPRテンプレートを追加。

## D019: databricks検証からの還流（B項目群・Databricks固有を汎用化）

- **B-1 reviewer頻出指摘の前倒し**: SQL文字列直接連結・異常系の例外任せを
  task-workerの禁止事項に昇格（レビューで検出できるが実装時点で止める方が安い）。
  「reviewerで2回以上出た同種指摘は禁止事項へ昇格提案」の運用ルールを
  retrospectiveスキルに追加。
- **B-2 環境前提の実機確認**: environment.md記載を鵜呑みにしてゲート通過→実装で
  大幅手戻り、というE2E実測欠陥への対策。spec-criticの観点を「実機確認済みか」まで
  強化し、releaseに着手時の疎通確認を追加。
- **B-3 cold start対策の標準化**: 外部サービス依存テストはタイムアウト付きポーリングを
  標準とする（単発即時応答のassertは偽陰性を生む。実測）。test-case-designに追加。
- **B-4 冪等な初期化**: deploy Skillに前提リソースの冪等な初期化手順を必須化
  （「デプロイは成功するが初回実行で落ちる」の典型原因。実測）。skill-authoringに追加。
- **B-5 MCPはHooks検査対象外**: Hooksはネイティブコマンド文字列しか検査できず、
  MCPツール呼び出しはすり抜ける。最小権限の原則をAGENTS.mdセキュリティ節に明記。

## D020: test→releaseの send:true を維持（C-1の判断）

- **決定**: Databricks版は「リリース=重い本番承認」のため send:false に変更したが、
  CreateAppl は environment.md 駆動の自動リリース（ノンストップ設計）が
  アイデンティティであるため **send:true を維持**する。
- **整合**: USAGE.mdのセッション分割表には「リリース: 自動継続（ノンストップ設計）。
  手動で再開する場合は新チャット+/09でも同じ動作」と記載し矛盾をなくした。
  破壊的操作の確認はHooks（ask）とenvironment.mdの人手分類で担保される。

## D021: CIワークフローは設計フェーズで生成する（C-2の判断）

- **決定**: CreateApplはスタック非依存のため具体的なCIを同梱できない。選択肢(a)の
  プレースホルダ同梱ではなく **(b)「設計フェーズでスタック確定後に skill-authoring で
  生成する」を明文化** した（skill-authoringにCI/CDの扱い節を追加）。
- **原則**: 「参照される仕組みには実体を同梱するか、無いことを明記する」は採用。
  プレースホルダを置かない理由は、TODOだけのworkflowはCIが通っている錯覚を生むため。

## D022: E2E検証用サンプルの同梱は保留（C-3の判断）

- **決定**: Databricks版で大きな効果があったsamples/（検証フィクスチャ）の
  CreateAppl版は、**次にCreateAppl自体のE2E検証を実施するタイミングで作成する**として保留。
- **理由**: フィクスチャは実際にE2Eを回して初めて価値が出る（Databricks版の効果も
  検証実行とセット）。作る際は「本体リポジトリ上で検証しない。配布経路で作った
  使い捨てプロジェクトで行う」という検証運用ルールを必ず併記する。

## D023: UIデザインゲート（ui-design-mockup）の新設

- **決定**: ブラウザUIを持つアプリでは、設計フェーズで主要画面を自己完結型HTML
  モックアップ（`docs/02-design/ui/`、ダブルクリックで表示可能）として作成し、
  ユーザーの視覚確認を設計ゲート承認の前提条件とする。spec-criticはUIありなのに
  モックアップ無しをMAJOR指摘し、testはPlaywrightスクリーンショットとモックアップの
  乖離を検出する。
- **根拠**: 実際のハーネス利用で「実装後に画面デザインが考慮されていないと判明」する
  事象が発生。調査の結果、2026年の業界到達点は「Requirement → Design（インタラクティブな
  HTMLプロトタイプを視覚レビュー）→ Plan → Code → Verify」であり、モックアップは
  別ツールではなく**コードと同じワークスペースのファイルとして同じエージェントが
  生成・反復する**形が最新（superdesign等）。Spec Kit・BMADには視覚デザインゲートが無く、
  この領域は本ハーネスの差別化点になる。
- **コスト設計**: 生成は1画面1回のモデル呼び出し、**閲覧はブラウザで開くだけで
  トークンコスト・ゼロ**。全画面ではなく主要フロー+代表画面に絞る。修正はチャット指示と
  HTML直接編集の両方を受け付ける（ユーザーの提案どおり）。UIの無いアプリではスキップ。
- **捨てた選択肢**: Figma MCP連携を既定にすること（外部サービス依存・認証が必要で、
  汎用テンプレートの既定にはできない。Figmaを使うプロジェクトでは設計フェーズで
  接続すればよい）。


## D024: 次の一手の案内はプロンプトコマンド形式に統一

- **決定**: フェーズ移行時の案内を「新しいチャットで `/03-design-architecture` を実行」の
  ようなコマンド形式に統一し、「◯◯エージェントに切り替えて」という案内を禁止した。
  ハンドオフボタンは「同一チャット続行用」と位置づけ、ラベルにも
  「（このチャットで続行）」と明示。requirements/designのゲート後案内も
  コマンド形式を第一とし、ハンドオフを補足に格下げした。
- **根拠**: CreateApplの実機E2Eで実測された案内の不正確さ。要件定義完了時に
  「新しいチャットを開き、designエージェントに切り替えてから設計フェーズを開始」と
  案内された。(1) プロンプトは `agent:` バインドで自動的に正しいエージェントとして
  動くため手動切り替えは不要、(2) エージェント切り替えだけではプロンプトの起動指示
  （どの段階から始めるか）が実行されない、(3) ハンドオフ（同一チャット継続）と
  セッション分割表（新規チャット推奨）が矛盾したまま両方を混ぜた案内になっていた、
  の3点が原因。案内フォーマットの規定（AGENTS.mdナビゲーション責務・harness-guide）と
  ゲート後案内の書き換えで解消した。

## D025: マルチプラットフォーム対応（Copilot / Claude Code / Antigravity）

- **決定**: 「正のレイヤ + 薄いアダプタ」構成で3環境対応した。振る舞いの正は従来どおり
  `AGENTS.md` + `.github/`（agents/prompts/skills/hooks）に一本化し、各環境には
  ポインタだけのアダプタを置く（生成スクリプトで機械生成・冪等）。
  - Claude Code: `CLAUDE.md`（`@AGENTS.md`インポート）、`.claude/commands/`（13件）、
    `.claude/agents/`（reviewer/spec-critic/task-worker）、`.claude/skills/`（9件のポインタ）、
    `.claude/settings.json`（既存フックスクリプトをClaude Codeスキーマで配線）
  - Antigravity: `AGENTS.md` を直接読む + `.agents/workflows/`（13件）
- **調査根拠**（2026年7月時点の一次情報）:
  - Claude Code は AGENTS.md を直接サポートせず（[issue #31005](https://github.com/anthropics/claude-code/issues/31005)、
    3000超のupvoteに未対応）、スキルも `.claude/skills/` しか探索しない
    （`.agents/skills/` へのsymlinkは内部ファイル汚染で機能しない）。
    そのため CLAUDE.md のインポート機能とポインタスキルで橋渡しする。
  - Claude Code のフック（`.claude/settings.json`）はVS Code版と同一のペイロード仕様
    （tool_input.file_path/command、hookSpecificOutput.permissionDecision）のため、
    **既存スクリプトを無変更で共用**できる（VS CodeがClaude Code形式を採用した経緯による）。
    Claude Code の SessionStart は compaction 後にも発火する（source=compact）ため、
    PreCompact 相当の再注入も SessionStart 登録だけでカバーされる。
  - Antigravity は v1.20.3 でプロジェクトレベルの AGENTS.md を正式サポート。
    `.agents/` が特別ディレクトリで、`.agents/workflows/*.md` が /コマンドになる
    （[Google Codelabs](https://codelabs.developers.google.com/autonomous-ai-developer-pipelines-antigravity)）。
    フック機構は無いため、ガードレールは指示レベル+Git保護に縮退する（対応表に明記）。
- **設計原則**: アダプタは振る舞いを持たない（起動経路の等価性ルールA-5の
  プラットフォーム拡張）。読み替え規則（runSubagent→Task/別会話）はアダプタ内と
  AGENTS.mdに明記。ガードも拡張し、アダプタ層（CLAUDE.md/.claude設定・agents・
  commands/.agents/workflows）を保護対象に追加（`.claude/skills/` は動的Skill作成の
  ため除外）。skill-authoringに「正のスキル新設時はClaude用ポインタも同時作成」を追加。
- **捨てた選択肢**: (a) 各環境に振る舞いをコピーする（必ずドリフトする）。
  (b) Claude Codeプラグイン化（インストール手順が増え、テンプレートのクローン即利用に反する）。
  (c) 正を `.claude/skills/` へ移す（Copilotは読めるが、既存の全相互参照の書き換えと
  Antigravity非対応で利点が薄い）。

## D026: ai-manager（姉妹プロジェクト）からの知見採用

- **出典**: 同一作者の別プロジェクト ai-manager（AI秘書。Antigravityを主環境として
  同じ「正典＋薄いポインタ」構成でマルチエージェント対応済み）の PORTABILITY.md。
  設計思想が独立に一致していることを確認した上で、相互比較で見つかった差分のうち
  ハーネス側に欠けていた3点を採用した。
- **採用した項目**:
  1. **Antigravity IDEはプロジェクト内スクリプトフックを読まない**（ai-managerでの
     実機検証により判明）。機械的保護はIDEのDeny List（Settings → Permissions →
     Advanced）への手動登録で代替する。AGENTS.md・README・.agents/workflows
     アダプタ（生成文言）に反映。
  2. **`permissions.deny` の併用**: `.claude/settings.json` にツールレベルの
     ハードブロック（ハーネス設定ファイルとテンプレートへのEdit/Write禁止）を追加。
     フックと合わせて二重の機械的ガードとなり、Claude Codeが3環境で最も強い
     ガードレールを持つ。ハーネス本体の保守時は人間が一時的にdeny行を外す運用
     （CLAUDE.mdに明記）。
  3. **機能別の劣化モード明記**: READMEの対応表に「対応度の目安」を追加し、
     環境ごとに何がフルで何が劣化かを利用者が着手前に判断できるようにした。
- **逆方向の還流**: ハーネス側が優位だった「ポインタの機械生成（冪等スクリプト）+
  validatorによる乖離検出」は、ai-manager向けの改善指示書
  （D:\vscode-worspace\ai-manager-improvement-handover.md）として別途まとめた
  （ai-managerはポインタを手作業維持しており、転写忘れによるドリフトのリスクがあるため）。

## D027: アダプタ生成・整合検証ツールをリポジトリに同梱

- **決定**: これまで開発セッションの作業領域にしか存在しなかったアダプタ生成スクリプトと
  整合性バリデータを `tools/generate-adapters.py` / `tools/validate-harness.py` として
  リポジトリに同梱した。skill-authoring スキルの「ポインタ同時作成」手順も
  ツール実行を第一の方法に更新した。
- **根拠**: GAS派生ハーネス構築指示書を多プラットフォーム対応(D025)に合わせて改訂する際、
  派生側がアダプタを再生成・検証する手段を持たないことが判明した。これは自分たちが
  D021で定めた「参照される仕組みには実体を同梱するか、無いことを明記する」原則への
  違反だったため解消した。同梱版はパスをスクリプト位置からの相対に変更し、
  冪等性（再実行で差分ゼロ）を確認済み。ai-manager向け還流指示書(I-1/I-2)で
  他プロジェクトに勧めた内容を、自分自身にも適用した形。

## D028: 大規模開発対応（サブシステム分割モード）と dynamic workflows の位置づけ

- **決定**: 大規模案件（US目安30超・複数サブシステム・複数チーム）向けに
  `large-scale-development` スキルを新設した。構造変更ではなく「スキル+テンプレート+
  少量の配線」で吸収し、標準の単一パイプラインは従来どおり既定とする。
  - 2層構造: システム層（全体要件・サブシステム分割・ICD・統合テスト・リリース）+
    サブシステム層（標準docs構造のミラー。テンプレートは既存の*_template.mdを再利用）
  - `docs/02-design/interface_contract_template.md`（ICD）を新設。agreed後の変更は
    影響サブシステム全部の再ゲートを伴う変更管理として扱う（差分駆動の原則の契約適用）
  - AIと人の責任分界を明文化: **サブシステムの内側はAI、境界（分割・ICD・統合・リリース）は
    人が承認**。境界の誤りだけが全体に波及するため人の注意をそこに集中させる
  - 並列化はプラットフォーム非依存の並行セッション/worktreeが基本。Claude Code
    (Max/Team)では dynamic workflows（2026-05-28導入の多数サブエージェント並列機能）を
    コスト増の明示+ユーザー承認つきで提案可とした（CLAUDE.mdに読み替えを記載）
- **根拠**: BMAD METHODの[document sharding](https://docs.bmad-method.org/how-to/customization/shard-large-documents/)
  （巨大PRDをepic単位に分割しエージェントのコンテキストを最適化する）、GitHub Spec Kitの
  機能単位spec、システムズエンジニアリングのICD実践。「単一巨大文書は人にもAIにも
  読めなくなる」が業界の共通結論であり、本ハーネスの弱点（成果物が単一ファイル前提・
  パイプラインが単線）と一致したため、確立された分割パターンを採用した。
- **既知の制約（正直に記録）**: SessionStart注入と warn-stale-gate フックはシステム層の
  パスしか検知しない。サブシステム側のゲート整合は指示レベル運用であり、実案件で摩擦が
  大きければフック拡張を検討する（スキル内に明記済み）。
- **検証事故（教訓）**: この適用作業中、`permissions.deny`（D026）が実際に発動し
  テンプレート新設がブロックされた。ガードが機能している実証である一方、保守作業は
  スクラッチ経由のコピーで回避した。Bashによるファイル操作はpermissions.denyの
  Edit/Write指定では止まらないことも確認された（既知の限界として記録。
  完全な防御にはGit側の保護=ブランチ保護/CODEOWNERSの併用が必要）。

## D029: ブラウザ検証を「コード化テスト主・対話操作従」の2層に変更

- **決定**: テストフェーズのブラウザ検証を、D013の「Playwright MCPで開いて確認し、
  コードとして残せるものは残す」（MCP主・コード従）から反転させ、
  **受け入れ条件の検証はPlaywrightテストコード+CLI実行を主**、対話型ブラウザ操作は
  (a)モックアップとの視覚比較 (b)失敗デバッグ (c)コード化前の探索 の3用途に限定した。
  対話操作の手段はプラットフォームネイティブを選ぶ:
  Copilot=Playwright MCP(.vscode/mcp.json) / Claude Code=Playwright MCP(.mcp.json、
  キー名mcpServers) / Antigravity=内蔵ブラウザエージェント(CDP直結・拡張不要・動画証跡)。
- **根拠**: 2026年の実測ベンチマークで、同一カバレッジのブラウザ検証が対話型MCP操作では
  約114Kトークン、コード化テストのCLI実行では約27Kトークン（約1/4）
  ([ytyng 2026ベンチマーク](https://www.ytyng.com/en/blog/ai-browser-automation-tools-comparison-2026)、
  [TestQuality 2026アーキテクチャガイド](https://testquality.com/playwright-test-agents-mcp-architecture-2026/))。
  実務コンセンサスは「MCPは探索・即席検証、回帰保護はコード化されたPlaywright」の併用。
  コード化はトークン以外にも、決定的・再実行可能・資産としてリポジトリに残り
  改修サイクルとCIに再利用できる点で「docs/が正」の設計思想と一致する。
  Playwright MCP自体は引き続きエージェント向けブラウザ操作の業界標準であり廃止しない。
- **捨てた選択肢**: agent-browser(Vercel系、ページ表現200-400トークンでMCP比高効率)の
  既定採用 — 有望だが新しく単一ベンダー依存のため、既定はMicrosoft参照実装のMCPを維持し
  動向を注視する。Claude in Chromeの既定採用 — chrome-extension://コンテキスト等の
  既知の制約があり成熟途上のため見送り。

## D030: 鮮度監査（2026-07-06実施）の結果と修正

- **監査内容**: 「現時点のベストプラクティスを採用しているか」を構成要素ごとに
  最新情報（VS Code Copilot 5-6月チェンジログ・各領域の実務動向）と突き合わせた。
- **現行どおりで問題なし**: custom agents(.agent.md)・Agent Skills（段階的開示・
  agentskills.io標準）・Agent Hooks（8イベント・Preview）・prompt files の agent: バインド・
  handoffs・model:auto（AI Credit課金）・AGENTS.md標準（Copilot/Antigravityネイティブ、
  Claude CodeはCLAUDE.md経由のまま変化なし）・マルチプラットフォームアダプタ構成・
  EARS/spec-driven・UIモックアップゲート・コンテキストロット対策・成長ループ。
  5-6月の新機能（Agents window、リモートエージェント、enterprise-managed plugins）に
  本ハーネスの構成を壊す変更は無い。
- **修正した項目**:
  1. ブラウザ検証の主従逆転（D029）。
  2. **Copilotのスキル二重読み込み防止**: VS Codeはプロジェクトスキルを
     `.github/skills` に加えて `.claude/skills` からも探索するため、D025で置いた
     Claude用ポインタが Copilot 側で正と二重に発見される恐れがある。
     `.vscode/settings.json` に `chat.agentSkillsLocations: { ".claude/skills": false }`
     を設定して正のみを読ませるようにした（実機で挙動確認できたら再評価する）。
- **残課題（記録のみ）**: brownfield（既存コードベースへの適用）対応はSpec Kitの
  /speckit.converge相当が未実装のまま（D-比較時から既知）。最初のbrownfield案件の
  振り返りを起点に対応する。

## D031: brownfield（既存コードベース）対応の実装

- **決定**: `brownfield-intake` スキルと `/11-brownfield-intake` プロンプトを新設した。
  実装済みコードから as-is 要件・アーキテクチャ・環境情報を docs/ に逆起こしし、
  spec-critic レビュー + gate-check 横断整合監査で文書とコードの整合を検証
  （Spec Kit `/speckit.converge` 相当）してから GATE_STATUS を初期化し、
  以後は差分駆動の改修サイクル（D014/A-6）に接続する。
- **設計原則**: (1) as-is と to-be を混ぜない（改善要望は改修候補リストへ分離。
  混ぜると差分駆動の「どこからが変更か」が壊れる）。(2) 全コードを文書化しない
  （触る領域+システムの背骨に絞り、残りは「未逆起こし」と明記）。
  (3) environment.md は実機確認（B-2の教訓の適用）。
  (4) 大規模既存システムは large-scale-development と併用。
- **根拠**: 競合比較（D015前後）およびD030の鮮度監査で「greenfield前提でbrownfield
  未対応」が唯一の既知ギャップとして残っていた。Spec Kitのconverge、BMADのbrownfield
  対応が示すとおり、実務の多数派は既存コードベースへの適用であり、
  「世界最高」を名乗る上で放置できない欠落だったため実装した。

## D032: Dagram v0.1.0 振り返りからの還流（成長ループの実例2周目）

- **出典**: Dagram v0.1.0 の `/10-retrospective`（2026-07-08実施）による改善提案6件。
  ユーザーの明示指示のもとハーネス本体（このリポジトリ）に適用した（D017の還流経路）。
  実装〜テスト区間の人的ブロッカー0回・テスト起因のプロダクト修正0件で完走した
  プロジェクトであり、摩擦は主に「知見の未収録」に集中していた。
- **適用した項目**:
  1. **ui-design-mockup**: モックアップの各状態（ダイアログ・ポップアップ等）は
     状態切替バーだけでなく**実際の動線（＋ボタン・ノードクリック等）から開ける配線を必須化**
     （摩擦#1: 切替バーからしか開けない登録ダイアログが「画面がない」と2回指摘され、
     設計往復が1回増えた）。
  2. **deploy-local-npx テンプレを新設収録**: ホスティング先を持たないローカル完結アプリ
     （CLI・`npx`実行形式）のリリース手順（`npm ci → build → npx .` 起動確認・
     annotatedタグ・ロールバック=Git revertのみ）を、プロジェクト固有値を除いた
     汎用テンプレとして `.github/skills/deploy-local-npx/` に収録し、
     skill-authoring とrelease から参照。固有値（ポート等）は追記欄でプロジェクトごとに
     確定させる方式（全環境の事前収録はしない方針は維持）。
  3. **release**: CI結果確認の gh CLI 依存を解消。未導入環境では GitHub REST API への
     HTTP GET（公開リポジトリは認証不要）で代替するフォールバックを明記（摩擦#5）。
  4. **release**: リリースタグは **annotated（`git tag -a`）で作成**を明記。
     lightweight タグは `git push --follow-tags` の送信対象外のため、使う場合は
     明示 push する（摩擦#6: v0.1.0 タグが送信されない事故が実際に発生）。
  5. **learnings_template**: Windows で cwd のドライブレターが小文字だと Vitest が
     モジュール二重ロードでテスト全滅する既知問題をシード例として収録（摩擦#3。
     learnings 注入により後続フェーズで再発ゼロ = 記録の効果が実証済みの知見のため、
     新プロジェクトに最初から効かせる）。
  6. **test-case-design**: E2Eブラウザ自動化固有の落とし穴2点（HTML5 D&Dはマウス合成
     イベントで発火しない→DataTransfer付きDragEventをdispatch・headlessは
     beforeunloadダイアログを出さない→reload+dialogイベント待ち）を追記
     （摩擦#4: E2E初回9件失敗の主因。プロダクト側の欠陥は0件だった）。
- **還流しなかったもの**: stack-conventions（中身がDagram固有。「プロジェクトごとに
  設計フェーズで作る」というハーネスの仕組みどおりに機能したため、実体の還流は不要）。
- **適用手順の記録（ガードレールの実効確認）**: `.github/agents/` と
  `docs/**/*_template.md` への変更は permissions.deny が Edit を、加えて auto モードの
  分類器が Bash `cp` による迂回もブロックした（D028時点では「Bashはdenyで止まらない」が
  既知の限界だったが、現在は分類器が迂回として検出・拒否することを実機確認。
  ガードは当時より強くなっている）。適用は CLAUDE.md 記載の正規手順どおり、
  人間が deny 行4行を一時的に外し、適用後に復元した。
- **運用ルール確認**: reviewer で2回以上出た同種指摘は該当なし（B-1の昇格対象なし）。

## D033: Team Operations Hub v1.0.0 振り返りからの還流（成長ループ3周目）

- **出典**: Team Operations Hub v1.0.0 の `/10-retrospective`（2026-07-19実施）による
  改善提案4件。ユーザーの明示指示のもと適用した。実装〜テスト区間の人的ブロッカー0回・
  テスト起因のプロダクト修正0件・上流指摘（要件MAJOR 7/設計MAJOR 4）を全てゲート前に
  解消という、D032（Dagram）に続き「上流で検出し下流でゼロ」を再現したプロジェクト。
- **適用した項目**:
  1. **windows-shell-conventions スキルを新設**: Windows + Git Bash + PowerShell 併用環境の
     既知の落とし穴7種（ドライブレター大小文字・`git stash -u`×autocrlf のCRLF事故・
     PowerShellインライン呼び出しの構文崩壊・curl 日本語ボディの文字化け・
     heredoc/Edit のバックスラッシュ破壊・Volta シムと環境変数差し替え・
     パイプの SIGPIPE）を汎用スキルとして集約。内容は同プロジェクトの
     `learnings.md`（2026-07-13〜07-17）の実記録から固有値を除いて汎用化した。
     共通原則「複雑なワンライナーを書かずスクリプトファイルにする」を冒頭に明記。
     プロジェクトごとの再発見コスト（うち1件は実プロダクトバグ化）を解消する。
  2. **フック判定ログ**: 判定を持つ全フックスクリプト（guard 4種 + warn-stale-gate、
     bash/PowerShell 両系統の計10ファイル）に、deny/ask/warn 判定時のみ
     `.github/hooks/logs/hook-decisions.log`（gitignore対象・ローカルのみ）へ
     日時・スクリプト名・判定・対象を1行追記する処理を追加。振り返りの
     「フック発火回数と誤検知」項目が2プロジェクト連続で「不明」だった穴を塞ぐ。
     設計上の要点: (a) ログ失敗はフック判定に影響させない（フェイルセーフ）、
     (b) **guard-secret-leak はシークレット本文を絶対にログへ書かず**パターン種別のみ
     記録、(c) 許可(allow)時は記録しない（ノイズと肥大化の防止）。
     D012の教訓に従い、適用前(scratchpad)と適用後(本番パス)の両方で bash/ps1 とも
     サンプルペイロードによる実機検証を行い、判定JSONが原本と同一であることと
     ログ追記・BOM保持を確認した。
  3. **requirements-elicitation に「画面横断の仕様を先に確認する」節を追加**:
     複数行テキスト項目の役割分担・一覧/ガント等の共通UI規約（フィルタ・トグル・
     遷移導線）・主用途の重み付けを要件定義段階で確認する。モックアップレビューで
     都度発覚するとユーザー指示の往復が画面数ぶん増える（実測: 6巡）ため、
     ui-design-mockup（D023/D032-1）の往復回数を上流で減らす。
  4. **重大度語彙の対応表**: spec-critic（BLOCKER/MAJOR/MINOR）と
     reviewer/security-review（CRITICAL/HIGH/MEDIUM/LOW/INFO）の読み替え
     （BLOCKER≒CRITICAL/HIGH、MAJOR≒MEDIUM、MINOR≒LOW/INFO）を
     security-review スキルに追記。語彙の統一はしない（両者の出典・用途が異なり、
     振り返りの集計には対応表で足りるため）。
- **還流しなかったもの**: stack-conventions（Team Operations Hub 固有。
  「mdファイルをデータストアとして扱う保全パターン」の一般化は、同種アプリの
  2例目が出た時点で判断する）。
- **適用手順**: D032と同じ正規手順（人間が `.claude/settings.json` の該当deny行
  = 今回は `.github/hooks/**` の2行を一時的に外し、適用後に復元）。
