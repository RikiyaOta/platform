# AI エージェント向けルール

このリポジトリは、個人プロジェクト群のインフラ（Cloudflare と GitHub）を Terraform で管理している。作業前に [README](README.md) と [docs/](docs/) を読むこと。

## 絶対に守ること

- **秘密や個人情報をコミットしない。** このリポジトリは公開されている。メールアドレスなどは変数にして `sensitive = true` を付け、値は Environment Secrets から渡す。
- **`.github/` を変更する場合は、PR の説明の冒頭でそのことを明記する。**
- **次のものを追加する場合は、PR の説明で理由を説明する。**
  - 新しい provider や module、バージョンの変更
  - `data "external"`、`local-exec`、`remote-exec`、`http` data source
- **秘密を `output` に出さない。** どうしても必要な場合は `sensitive = true` を付ける。
- **platform リポジトリ自身の GitHub 設定（ブランチ保護、Environments）を Terraform で管理しない。**
- **削除されると困るリソース（GitHub リポジトリ、tfstate 用バケット）には `prevent_destroy` を付ける。** GitHub リポジトリには `archive_on_destroy = true` も付ける。
- **state アカウントを Terraform で扱わない。** state アカウントには `tfstate-platform` バケットと R2 キーしか置かない。
- **プロジェクト用の Cloudflare トークンは、メインアカウントのアカウントトークン（`cloudflare_account_token`）として発行する。** ユーザートークンは使わない。
- **プロジェクト用トークンに、トークンを作れる権限を付けない。** `API Tokens Edit`、`Account API Tokens Edit`、メンバー管理、アカウント設定の編集などは渡さない。
- **R2 バケットはすべて platform で作る。プロジェクト用トークンに R2 の Admin 権限（`Workers R2 Storage Write` / `Read`）を付けない。** プロジェクトがバケットを必要とするときは、`modules/project` の `r2_buckets` に追加する。
- **プロジェクトの Worker がバインディングするのは、そのプロジェクトのリソースだけにする。** 権限上は同じアカウント内のどのバケットにも向けられてしまうので、ルールで守る（[docs/decisions.md](docs/decisions.md) の決定 11）。
- **プロジェクト側の Terraform で強い秘密を作らせない。** API トークン、Access のサービストークン、Worker 用のシークレット、生成したパスワードなどは platform で作って渡す。

## PR の書き方

- 何を追加・変更・削除するつもりか、期待する plan の内容（追加・変更・削除の件数と対象）を書く。
- `destroy` や `replace` が起きる変更は、その理由を書く。
- 1つの PR では1つの目的だけを扱う。

## 新しいプロジェクトを追加するとき

`modules/project` モジュールを1つ追加する。モジュールが作るものは [docs/architecture.md](docs/architecture.md) を参照。

## 既存リソースを取り込むとき

[docs/migration.md](docs/migration.md) の手順に従う。プロジェクト側から移す場合は、platform 側の import を先にマージしてから、プロジェクト側で `removed` ブロックを使う。
