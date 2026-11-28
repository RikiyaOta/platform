# 初期構築の手順

Terraform を動かすための前提は、Terraform では作れないので最初だけ手動で用意する。作った秘密はすべて Bitwarden に保存する。

## 1. GitHub

- [ ] このリポジトリを公開リポジトリとして作る
- [ ] シークレットスキャンと push protection を有効にする
- [ ] main のブランチ保護（ruleset）を設定する
  - 直接 push を禁止し、PR を必須にする
  - マージには1件以上の承認を必須にする
- [ ] AI 用の GitHub App を自作する（Settings → Developer settings → GitHub Apps → New GitHub App）
  - Webhook: 無効にする
  - Repository permissions: 次のものだけを付ける。Metadata（Read-only）は自動で付く
    - Contents（Read and write）
    - Pull requests（Read and write）
    - Issues（Read and write）
    - Checks（Read-only）
    - Actions（Read-only）
  - Administration、Workflows、Environments、Secrets は付けない
  - インストール先: Only on this account
- [ ] 自作 App の秘密鍵（`.pem`）を生成して Bitwarden に保存し、このリポジトリにインストールする
  - この App は platform 以外のプロジェクトでも使う（AI の sandbox に本人のトークンを渡さないため）。AI に作業させるリポジトリにも同じ App をインストールする
- [ ] Docker Sandboxes の GitHub 認証に、自作 App のトークンを発行するコマンドを登録する（本人のトークン（`gh auth token`）は登録しない）
- [ ] 公式の Claude GitHub App のアクセス対象から、このリポジトリを外す（[workflow](workflow.md#ai-の動かし方)）
- [ ] fine-grained PAT を2つ作る
  - `GH_ADMIN_TOKEN`: リポジトリの作成・管理、Environments・Secrets・Variables の書き込み
    - Repository access: All repositories（新しいリポジトリを作るため）
    - Repository permissions: Administration（Read and write）、Environments（Read and write）、Secrets（Read and write）、Variables（Read and write）、Metadata（Read-only）
    - Environments は、プロジェクトのリポジトリに main 限定の Environment を作り、そこにプロジェクト用トークンを書き込むために付ける
    - Contents は付けない（各プロジェクトにファイルを配るようになったら追加する）
  - `GH_READ_TOKEN`: 読み取りのみ
    - Repository permissions: Administration、Environments、Secrets、Variables、Metadata をすべて Read-only（plan で管理対象の状態を読むため）

## 2. Cloudflare

### ログイン

- [ ] Cloudflare のログインで2段階認証を有効にする（両方のアカウントを守る最後の砦）

### platform アカウント（新しく作る）

- [ ] platform の state 専用の Cloudflare アカウントを作る
- [ ] R2 を有効にする
- [ ] R2 バケット `platform-tfstate` を作る（Terraform では管理しないので、削除しないよう注意する）
- [ ] `platform-tfstate` 用の R2 キーを2つ作る
  - 読み書き用（apply 用）
  - 読み取り専用（plan 用）
- [ ] このアカウントには、これ以外のものを置かない

### メインアカウント

- [ ] ブートストラップ用 Cloudflare トークンを作る（権限は [secrets](secrets.md) を参照）。メインアカウントだけに効くように作る
- [ ] 読み取り専用の Cloudflare トークンを作る。こちらもメインアカウントだけに効くように作る

## 3. GitHub Environments

- [ ] Environment `platform-plan` を作る
  - required reviewers: なし
  - 使えるブランチ: main のみ
- [ ] Environment `platform-apply` を作る
  - required reviewers: なし（理由は [workflow](workflow.md#apply-に承認ステップを設けない理由)）
  - 使えるブランチ: main のみ
- [ ] それぞれに Secrets を登録する（一覧は [secrets](secrets.md) を参照）
- [ ] リポジトリの Variables に、Cloudflare のアカウント ID を登録する（[secrets](secrets.md#リポジトリの-variables)）

## 4. 最初の PR

- [ ] backend 設定（platform アカウントの `platform-tfstate`）、provider 設定を追加する。plan/apply のワークフローは追加済み（Terraform のファイルがない間は何もせず終了する）
- [ ] `/plan` → マージ → apply が通ることを確認する

ここまでできたら、以降の変更はすべて PR 経由で行う。
