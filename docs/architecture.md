# 全体構成

## 2層構成

```
┌──────────────────────────────────────────────┐
│ platform リポジトリ（このリポジトリ）          │
│  - アカウント共有: ゾーン、Access IdP/共有ポリシー │
│  - プロジェクトの土台を発行                     │
│  - state は platform アカウントに置く            │
└──────────────────────┬───────────────────────┘
                       │ プロジェクトごとに作成・発行
                       ▼
┌──────────────────────────────────────────────┐
│ 各プロジェクトのリポジトリ（例: example-app）    │
│  - アプリ固有: Worker、D1、KV、R2、Access アプリ等 │
│  - 自分の CI で terraform apply                 │
│  - state はメインアカウントに置く                │
└──────────────────────────────────────────────┘
```

## Cloudflare アカウントは2つ使う

| アカウント | 中身 | このアカウントの鍵を持つもの |
| --- | --- | --- |
| メインアカウント | ゾーン、Access、各プロジェクトのリソース、`<project>-tfstate` バケット | platform の CI、各プロジェクトの CI |
| platform アカウント | `platform-tfstate` バケットだけ | platform の CI だけ |

鍵の持ち方で見ると、次のようになる。

- **platform の CI**: 両方のアカウントの鍵を持つ。platform アカウントの R2 キー（`platform-tfstate` を読み書きする）と、メインアカウントの強いトークン（トークンの発行もできる）。いちばん強い権限を持つので、[workflow](workflow.md) の手順で守る。
- **各プロジェクトの CI**: メインアカウントの鍵だけを持つ。platform アカウントの鍵は持たないので、どんな権限の組み合わせでも `platform-tfstate` には届かない。

アカウント自体が他のアカウントに対して権限を持つことはない。権限を持つのは、それぞれのアカウントで発行した鍵だけ。

アカウントを分ける理由: platform の state には全プロジェクトのトークン値が入っている。メインアカウントに置くと、R2 の Admin 権限や Worker のバインディングを使えるプロジェクトから読めてしまう（経緯は [decisions](decisions.md)）。

platform アカウントは Terraform で管理しない。中身は手動で作った `platform-tfstate` バケットと、それを読み書きする R2 キーだけにする。

### 分け方の基準

- **platform に置く**: 複数のプロジェクトにまたがるもの、プロジェクトを始める前に必要なもの
- **各プロジェクトに置く**: コードと一緒に変わるもの

Cloudflare Access は、ログイン方法（IdP）、チームドメイン、使い回すポリシー（例: 「家族だけ許可」）を platform に置く。Access アプリケーション（どのホスト名を守るか）とアプリ専用のポリシーは各プロジェクトに置く。

## プロジェクト1つあたりに platform が作るもの

プロジェクトは `modules/project` モジュールを1つ追加することで作る想定。

```hcl
module "example_app" {
  source = "./modules/project"
  name   = "example-app"
  # 必要な Cloudflare 権限など
}
```

このモジュールが作るもの:

| リソース | 内容 |
| --- | --- |
| GitHub リポジトリ | `archive_on_destroy = true` と `prevent_destroy` を必ず付ける |
| ブランチ保護 | main への直接 push 禁止など |
| R2 バケット `<name>-tfstate` | そのプロジェクトの tfstate 専用 |
| R2 用トークン | `<name>-tfstate` バケットだけを読み書きできる |
| Cloudflare API トークン | そのプロジェクトのリソースだけを触れる最小権限 |
| GitHub Actions Secrets | 上のトークンをプロジェクトのリポジトリに書き込む |

### R2 バケットの作り分け

| バケット | 誰が作るか | 置き場所 |
| --- | --- | --- |
| `platform-tfstate` | 手動 | platform アカウント |
| `<project>-tfstate`（各プロジェクトの state） | platform | メインアカウント |
| アプリ用のバケット（アプリのロジックが使うもの） | 各プロジェクト | メインアカウント |

- アプリ用のバケットは、Worker や D1 と同じくプロジェクト側の Terraform で作る。必要なプロジェクトには R2 の Admin 権限を渡す（[decisions](decisions.md#10-r2-バケットの作り分け)）。
- R2 の Admin 権限やバインディングを使えば、他のプロジェクトのバケットにも届いてしまう。これは受け入れたうえで、Worker のバインディングは自分のプロジェクトのリソースだけに向けるルールと、plan の確認で守る（[decisions](decisions.md#11-プロジェクト同士はバインディングで筒抜けになることを受け入れる)）。

R2 の S3 認証情報は Cloudflare API トークンから作れる。Access Key ID がトークンの ID、Secret Access Key がトークン値の SHA-256 ハッシュになる。そのため、Terraform の `sha256()` で変換して Secrets に書き込む。

### プロジェクト用トークンのルール

- **メインアカウントのアカウントトークン（`cloudflare_account_token`）として発行する。** ユーザートークンは設定次第で複数のアカウントにまたがるので使わない。
- **トークンを作れる権限は渡さない。** `API Tokens Edit`（User）、`Account API Tokens Edit`、メンバー管理、アカウント設定の編集権限など、権限を広げられるものはプロジェクトに渡さない。
- **R2 の Admin 権限（`Workers R2 Storage Write`）は、アプリ用のバケットを作るプロジェクトにだけ渡す。** アカウント内の全バケットに効くので、必要のないプロジェクトには渡さない。

### プロジェクト側の state に強い秘密を置かない

Worker をデプロイできるプロジェクトは、バインディング経由で同じアカウント内のどのバケットにも届く（[decisions](decisions.md#11-プロジェクト同士はバインディングで筒抜けになることを受け入れる)）。つまり、他のプロジェクトの state は読まれうる。そのため、強い秘密は platform で作って渡す。プロジェクト側の Terraform では次のものを作らない。

- Cloudflare の API トークン
- Access のサービストークン
- Worker 用のシークレット
- `random_password` などで生成するパスワードや鍵

## tfstate の置き場所

| バケット | アカウント | 用途 | 作り方 |
| --- | --- | --- | --- |
| `platform-tfstate` | platform アカウント | platform 自身の state | 手動で作る。Terraform では管理しない |
| `<project>-tfstate` | メインアカウント | 各プロジェクトの state | platform が作る |

- platform の state には全プロジェクトのトークン値が平文で入る。そのため `platform-tfstate` は別アカウントに置き、platform の CI 以外から触れないようにする。
- プロジェクトの state をバケットごとに分ける理由: R2 の通常のトークンはバケット単位でしか権限を絞れない。各プロジェクトの CI が、state 用の R2 キーで他のプロジェクトの state を読めないようにする。ただし、R2 の Admin 権限や Worker のバインディング経由では届くので、完全な分離ではない（[decisions](decisions.md#11-プロジェクト同士はバインディングで筒抜けになることを受け入れる)）。
- ロックは S3 backend の `use_lockfile = true` を使う（R2 の条件付き書き込みで動く）。

backend の具体的な設定は、Terraform のコード（`backend` ブロック）を正とする。

## Provider

- `cloudflare/cloudflare`（トークン系のリソースは過去に破壊的変更があったので、新しめの版を使う）
- `integrations/github`
