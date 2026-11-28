# PR から apply までの流れ

手元で terraform を実行せず、すべて GitHub Actions で行う。

## 流れ

1. **AI がコードを書いて PR を作る**
   - AI は自分とは別のアカウント（自作の AI 用 GitHub App）で動かす。権限は push、PR と Issue の作成・コメント、CI の結果の読み取りだけ。詳しくは [AI の動かし方](#ai-の動かし方)。
2. **自分が差分を確認する**
   - 特に [plan 前に確認すること](#plan-前に確認すること) を見る。
3. **PR に `/plan` とコメントする**
   - `issue_comment` トリガーで plan のワークフローが動く。このトリガーは PR ブランチではなく main にあるワークフローを実行するので、PR でワークフローを書き換えられても影響しない。
   - ワークフローは次の場合に何もせず終了する:
     - コメントしたのが自分（`author_association == 'OWNER'`）でない
     - PR のブランチがフォークから来ている
   - plan ジョブは Environment `platform-plan` の Secrets を使う。plan には実行前の承認ステップを設けていないので、コメントするとすぐに動く（理由は [plan に承認ステップを設けない理由](#plan-に承認ステップを設けない理由)）。
4. **plan の結果を確認する**
   - 結果は PR にコメントされる。`destroy` や `replace` が出ていたら、必ず理由を確認する。
   - `/plan` から時間が経った場合や、別の PR を先にマージした場合は、マージ前にもう一度 `/plan` して、最新の状態で確認する（理由は [apply に承認ステップを設けない理由](#apply-に承認ステップを設けない理由)）。
5. **自分が承認してマージする**
   - main は保護されていて、マージには自分の承認が必要。AI は自分で作った PR を承認できない。
6. **main への push で apply**
   - apply ジョブは Environment `platform-apply` の Secrets を使う。apply には実行前の承認ステップを設けていないので、マージするとすぐに動く（理由は [apply に承認ステップを設けない理由](#apply-に承認ステップを設けない理由)）。
   - apply は改めて plan してから実行する。マージ前の `/plan` で、最新の状態の plan を確認しておく。

## AI の動かし方

`/plan` の関門とマージの承認は、「AI が自分とは別のアカウントで、絞った権限で動く」ことを前提にしている。AI が本人名義で動くと、AI が自分で `/plan` とコメントでき、ブランチ保護や Environments も変えられてしまう。

| 動かし方 | GitHub 上の名義 | platform で使うか |
| --- | --- | --- |
| ターミナルの Claude Code（Docker Sandboxes の中）＋自作 App のトークン | 自作 App の bot | **使う** |
| ターミナルの Claude Code（手元の `gh` や git の認証のまま） | 本人 | 使わない |
| web 版の Claude Code、claude.ai のチャット（公式の Claude GitHub App 経由） | 本人 | 使わない |

- platform の作業は、Docker Sandboxes の中で、自作 App のトークンだけを渡した Claude Code で行う。トークンは sandbox のプロキシがホスト側で注入するので、Claude 自身はトークンを見ない。
- 公式の Claude GitHub App のアクセス対象から platform リポジトリを外しておく。web 版の Claude Code が platform に push できないようにするため。
- 他の個人プロジェクトでは、web 版を含めてどの動かし方でもよい。
- コミット一覧で作成者が「claude」と表示されても、それはコミットに書かれたメールアドレスから表示されているだけで、push や PR 作成の名義とは関係ない。名義は push や PR の actor で確認する。

経緯は [decisions](decisions.md#12-ai-は自作の-github-app-で動かしweb-版の-claude-code-は-platform-で使わない)。

## plan に承認ステップを設けない理由

毎回のクリックを減らすため、plan では Environment の承認を省いている。それでも鍵は次の仕組みで守られる。

- `/plan` は自分（OWNER）のコメントでしか動かず、フォークの PR は plan しない。
- `platform-plan` の Secrets は main で動くワークフローにしか渡らない（PR でワークフローを書き換えても取り出せない）。
- plan 用の鍵は読み取り専用なので、トークンの発行やリソースの削除はできない。

ただし、plan でも `platform-tfstate` は読める（＝プロジェクト用トークンは見える）。そのため、`/plan` の前の差分確認は省略しない。

## apply に承認ステップを設けない理由

以前は `platform-apply` に required reviewers（自分）を設定していたが、外した。

- Environment の承認はジョブが始まる前に求められるので、承認の時点では、実際に適用される plan を見られない。見ないまま押すだけの確認になっていた。
- main への変更は PR 経由でしか入らず、マージ前に `/plan` で確認している。承認が防いでいたものは少ない。

代わりに、`/plan` から時間が経った場合や、別の PR を先にマージした場合は、マージ前にもう一度 `/plan` して、最新の状態で確認する。

`platform-apply` の Secrets が main 以外から使えないのは、使えるブランチ（main のみ）の制限で守る。経緯は [decisions](decisions.md#13-apply-には承認ステップを設けない)。

## plan 前に確認すること

plan は PR のコードをある程度実行する（外部コマンドを実行する data source や、任意の provider が動く）。そのため、次のような変更がないかを plan 前に確認する。

- `.github/` 以下の変更（action を固定している `.github/workflows/actions.lock` を含む）
- `mise.toml`、`mise.lock` の変更（plan は PR 側の `mise.toml` と `mise.lock` でツールを入れるので、ここを書き換えると plan で動くツールを差し替えられる）
- 新しい provider や module の追加、バージョンの変更（`.terraform.lock.hcl` の変更）
- `data "external"`、`local-exec`、`remote-exec`、`http` data source の追加
- `output` に秘密を出していないか

## Environment の設定

| Environment | required reviewers | 使えるブランチ |
| --- | --- | --- |
| `platform-plan` | なし | main のみ（`issue_comment` は main で動くので問題ない） |
| `platform-apply` | なし | main のみ |

この設定は platform 自身では管理せず、手動で行う。

## 公開リポジトリとしてのルール

このリポジトリは公開されている（GitHub Free でも Environments を使うため）。

- 秘密や個人情報（メールアドレスなど）をコードに書かない。変数にして、値は Environment Secrets から渡し、`sensitive = true` を付ける。
- PR へのコメントや Actions のログも公開される。plan の出力に個人情報が出ないことを確認する。
- シークレットスキャン（push protection）を有効にしておく。
- フォークからの PR のコードは絶対に plan しない。
