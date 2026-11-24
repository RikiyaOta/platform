# PR から apply までの流れ

手元で terraform を実行せず、すべて GitHub Actions で行う。

## 流れ

1. **AI がコードを書いて PR を作る**
   - AI は自分とは別のアカウント（AI 用の GitHub App）で動かす。権限は push と PR 作成だけ。
2. **自分が差分を確認する**
   - 特に [plan 前に確認すること](#plan-前に確認すること) を見る。
3. **PR に `/plan` とコメントする**
   - `issue_comment` トリガーで plan のワークフローが動く。このトリガーは PR ブランチではなく main にあるワークフローを実行するので、PR でワークフローを書き換えられても影響しない。
   - ワークフローは次の場合に何もせず終了する:
     - コメントしたのが自分（`author_association == 'OWNER'`）でない
     - PR のブランチがフォークから来ている
4. **Environment `platform-plan` の承認**
   - required reviewers（自分）の承認後に、Secrets がジョブに渡る。
5. **plan の結果を確認する**
   - 結果は PR にコメントされる。`destroy` や `replace` が出ていたら、必ず理由を確認する。
6. **自分が承認してマージする**
   - main は保護されていて、マージには自分の承認が必要。AI は自分で作った PR を承認できない。
7. **main への push で apply**
   - Environment `platform-apply` の承認後に実行する。
   - apply は改めて plan してから実行するので、マージ後に `/plan` 時点と差分が出ていないか確認する。

## plan 前に確認すること

plan は PR のコードをある程度実行する（外部コマンドを実行する data source や、任意の provider が動く）。そのため、次のような変更がないかを plan 前に確認する。

- `.github/` 以下の変更
- 新しい provider や module の追加、バージョンの変更（`.terraform.lock.hcl` の変更）
- `data "external"`、`local-exec`、`remote-exec`、`http` data source の追加
- `output` に秘密を出していないか

## Environment の設定

| Environment | required reviewers | 使えるブランチ |
| --- | --- | --- |
| `platform-plan` | 自分 | main のみ（`issue_comment` は main で動くので問題ない） |
| `platform-apply` | 自分 | main のみ |

この設定は platform 自身では管理せず、手動で行う。

## 公開リポジトリとしてのルール

このリポジトリは公開されている（GitHub Free でも Environments と required reviewers を使うため）。

- 秘密や個人情報（メールアドレスなど）をコードに書かない。変数にして、値は Environment Secrets から渡し、`sensitive = true` を付ける。
- PR へのコメントや Actions のログも公開される。plan の出力に個人情報が出ないことを確認する。
- シークレットスキャン（push protection）を有効にしておく。
- フォークからの PR のコードは絶対に plan しない。
