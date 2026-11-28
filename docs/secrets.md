# 秘密の一覧

秘密は2種類ある。

- **手動で管理する秘密**: Terraform を動かすために必要なもの。Bitwarden を正本とし、GitHub の Environment Secrets に一度だけ登録する。
- **自動で発行する秘密**: platform が Terraform で発行し、各プロジェクトのリポジトリに書き込むもの。人間が触ることはない。

## 前提: 発行したトークンは tfstate に残る

Terraform で発行したトークンの値は tfstate に平文で入る。これは受け入れたうえで、state の置き場所（`platform-tfstate`）を別の Cloudflare アカウント（platform アカウント）に置いて守る（経緯は [decisions](decisions.md)）。

## アカウントごとの鍵の分け方

- **platform アカウントの鍵**: `platform-tfstate` 用の R2 キーだけ。platform の Environments 以外には置かない。
- **メインアカウントの鍵**: それ以外すべて。メインアカウントだけに効くように作り、platform アカウントには届かないようにする。

## 手動で管理する秘密

### Environment `platform-apply`（apply 用。強い権限）

| Secret 名 | 中身 | 権限 |
| --- | --- | --- |
| `CLOUDFLARE_API_TOKEN` | ブートストラップ用 Cloudflare トークン（メインアカウントのみ） | API トークンの編集（トークン発行用）、R2 の編集、ゾーン・DNS の編集、Access の編集など、platform で扱うもの全部 |
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | `platform-tfstate` 用の R2 キー（platform アカウント） | `platform-tfstate` の読み書き |
| `GH_ADMIN_TOKEN` | GitHub の fine-grained PAT（Repository access: All repositories） | Administration（Read and write）、Secrets（Read and write）、Variables（Read and write）、Contents（Read and write）、Metadata（Read-only）。Environments は付けない |

### Environment `platform-plan`（plan 用。読み取り専用）

| Secret 名 | 中身 | 権限 |
| --- | --- | --- |
| `CLOUDFLARE_API_TOKEN` | 読み取り専用 Cloudflare トークン（メインアカウントのみ） | platform で扱うものの読み取りのみ |
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | `platform-tfstate` 用の R2 キー（platform アカウント） | `platform-tfstate` の読み取りのみ（plan は `-lock=false` で実行する） |
| `GH_READ_TOKEN` | GitHub の fine-grained PAT | 管理対象リポジトリの読み取りのみ |

`GH_ADMIN_TOKEN` の補足:

- Repository access を All repositories にするのは、新しいリポジトリを作るため。
- Environments の権限は付けない。プロジェクト用トークンは、プロジェクトのリポジトリの Environment ではなく Actions Secrets に書き込むため。

plan 用を読み取り専用に分けておけば、万一 PR のコードが悪さをしても、トークンの新規発行やリソースの削除まではできない。ただし state は読めてしまう（＝プロジェクト用トークンは見える）ので、plan 前の差分確認は省略しない。

### 個人情報を含む変数

Access ポリシーで許可するメールアドレスなどは、コードに書かずに両方の Environment の Secret から渡す。

| Secret 名 | 中身 |
| --- | --- |
| `TF_VAR_access_allowed_emails` | Access で許可するメールアドレスのリスト（JSON 形式） |

Terraform 側では `sensitive = true` を付けた変数として受け取る。こうすると plan の出力でも伏せ字になる。

## 自動で発行する秘密（プロジェクトごと）

platform がプロジェクトのリポジトリに書き込む Secrets:

| Secret 名 | 中身 |
| --- | --- |
| `CLOUDFLARE_API_TOKEN` | そのプロジェクト専用の Cloudflare トークン（最小権限） |
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | `<project>-tfstate` だけを読み書きできる R2 キー |

アカウント ID のような秘密でない値は、Secrets ではなく Variables として書き込む。

どちらもメインアカウントのアカウントトークン（`cloudflare_account_token`）として発行する。トークンを作れる権限は渡さない（詳細は [architecture](architecture.md#プロジェクト用トークンのルール)）。

## Cloudflare のログイン

メインアカウントと platform アカウントは同じユーザーでログインして管理する。2段階認証を必ず有効にする。ここが破られると両方のアカウントに届くので、最後の砦になる。

## ローテーション

- 自動発行のトークン: 有効期限を設定し、期限が近づいたら `terraform apply -replace=...` で作り直す（Secrets も自動で更新される）。
- 手動管理の秘密: 作り直したら Bitwarden と GitHub の Environment Secrets の両方を更新する。
