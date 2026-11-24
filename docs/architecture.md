# 全体構成

## 2層構成

```
┌──────────────────────────────────────────────┐
│ platform リポジトリ（このリポジトリ）          │
│  - アカウント共有: ゾーン、Access IdP/共有ポリシー │
│  - プロジェクトの土台を発行                     │
└──────────────────────┬───────────────────────┘
                       │ プロジェクトごとに作成・発行
                       ▼
┌──────────────────────────────────────────────┐
│ 各プロジェクトのリポジトリ（例: kaidoki）        │
│  - アプリ固有: Worker、D1、KV、Access アプリ等   │
│  - 自分の CI で terraform apply                 │
└──────────────────────────────────────────────┘
```

### 分け方の基準

- **platform に置く**: 複数のプロジェクトにまたがるもの、プロジェクトを始める前に必要なもの
- **各プロジェクトに置く**: コードと一緒に変わるもの

Cloudflare Access は、ログイン方法（IdP）、チームドメイン、使い回すポリシー（例: 「家族だけ許可」）を platform に置く。Access アプリケーション（どのホスト名を守るか）とアプリ専用のポリシーは各プロジェクトに置く。

## プロジェクト1つあたりに platform が作るもの

プロジェクトは `modules/project` モジュールを1つ追加することで作る想定。

```hcl
module "kaidoki" {
  source = "./modules/project"
  name   = "kaidoki"
  # 必要な Cloudflare 権限など
}
```

このモジュールが作るもの:

| リソース | 内容 |
| --- | --- |
| GitHub リポジトリ | `archive_on_destroy = true` と `prevent_destroy` を必ず付ける |
| ブランチ保護 | main への直接 push 禁止など |
| R2 バケット `tfstate-<name>` | そのプロジェクトの tfstate 専用 |
| R2 用トークン | `tfstate-<name>` バケットだけを読み書きできる |
| Cloudflare API トークン | そのプロジェクトのリソースだけを触れる最小権限 |
| GitHub Actions Secrets | 上の2つのトークンをプロジェクトのリポジトリに書き込む |

R2 の S3 認証情報は Cloudflare API トークンから作れる。Access Key ID がトークンの ID、Secret Access Key がトークン値の SHA-256 ハッシュになる。そのため、Terraform の `sha256()` で変換して Secrets に書き込む。

## tfstate の置き場所

| バケット | 用途 | 作り方 |
| --- | --- | --- |
| `tfstate-platform` | platform 自身の state | 最初だけ手動で作り、あとで import して `prevent_destroy` を付ける |
| `tfstate-<project>` | 各プロジェクトの state | platform が作る |

- バケットをプロジェクトごとに分ける理由: R2 の通常のトークンはバケット単位でしか権限を絞れない。各プロジェクトの CI が他のプロジェクトの state を読めないように、バケットごと分ける。
- platform の state には全プロジェクトのトークン値が平文で入る。そのため `tfstate-platform` は platform の CI 以外から触れないようにする。
- ロックは S3 backend の `use_lockfile = true` を使う（R2 の条件付き書き込みで動く。Terraform 1.10 以降）。

backend 設定の例:

```hcl
terraform {
  backend "s3" {
    bucket                      = "tfstate-platform"
    key                         = "platform/terraform.tfstate"
    region                      = "auto"
    endpoints                   = { s3 = "https://<ACCOUNT_ID>.r2.cloudflarestorage.com" }
    use_lockfile                = true
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
  }
}
```

## Provider

- `cloudflare/cloudflare` v5 系（トークン系リソースは 5.13 で破壊的変更があったので、それ以降を使う）
- `integrations/github`
