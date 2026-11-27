# platform

個人プロジェクト群のインフラ（Cloudflare と GitHub）を Terraform で一元管理するリポジトリ。

各プロジェクトを始めるのに必要な「土台」（リポジトリ、tfstate 置き場、トークン、Secrets）をここで作り、アプリ固有のリソースは各プロジェクトのリポジトリで管理する。

## 管理するもの

| 区分 | リソース |
| --- | --- |
| プロジェクトの土台 | GitHub リポジトリ、ブランチ保護、tfstate 用 R2 バケット、そのバケット専用の R2 キー、プロジェクト用 Cloudflare API トークン、それらを渡す GitHub Actions Secrets |
| アカウント共有 | ゾーン、Cloudflare Access のログイン方法（IdP）、使い回す Access ポリシー |

## 管理しないもの

- 各プロジェクトのアプリ固有リソース（Worker、D1、KV、アプリ用の R2 バケット、Access アプリケーションなど）→ 各プロジェクトのリポジトリで管理
- この platform リポジトリ自身の GitHub 設定（ブランチ保護、Environments）→ 手動で設定する（理由は [decisions](docs/decisions.md)）
- platform の state を置く Cloudflare アカウント（state アカウント）→ 手動で管理する。中身は `platform-tfstate` バケットと R2 キーだけ（[architecture](docs/architecture.md)）

## 変更の流れ

```
AI がコードを書いて PR を作成
  → 自分が差分を確認して `/plan` とコメント
  → Environment の承認 → plan 結果が PR にコメントされる
  → 自分が承認してマージ
  → main への push で apply（Environment の承認後に実行）
```

詳細は [docs/workflow.md](docs/workflow.md)。

## ドキュメント

- [docs/architecture.md](docs/architecture.md) — 全体構成と責任範囲
- [docs/secrets.md](docs/secrets.md) — 手動で管理する秘密と、自動で発行する秘密の一覧
- [docs/workflow.md](docs/workflow.md) — PR から apply までの流れとセキュリティ上のルール
- [docs/bootstrap.md](docs/bootstrap.md) — 最初に手動でやる初期構築の手順
- [docs/migration.md](docs/migration.md) — 既存リソースの取り込み方
- [docs/decisions.md](docs/decisions.md) — 設計判断とその理由
- [AGENTS.md](AGENTS.md) — このリポジトリで作業する AI 向けのルール

## このリポジトリは公開されている

コード、PR、Actions のログはすべて公開される。メールアドレスなどの個人情報や秘密は、コードにもログにも出さないこと（[docs/workflow.md](docs/workflow.md#公開リポジトリとしてのルール)）。
