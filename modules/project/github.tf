locals {
  manage_repository = var.github_repository != null
}

# プロジェクトの GitHub リポジトリ
resource "github_repository" "this" {
  count = local.manage_repository ? 1 : 0

  name        = var.name
  description = var.github_repository.description
  visibility  = var.github_repository.visibility

  has_issues      = true
  has_projects    = false
  has_wiki        = false
  has_discussions = false

  allow_merge_commit     = true
  allow_squash_merge     = true
  allow_rebase_merge     = true
  delete_branch_on_merge = true

  # main を作っておく（ブランチ保護があるので、中身は PR で入れる）。作成時にしか効かない
  auto_init = true

  # 誤って destroy されても消さずにアーカイブする（AGENTS.md）
  archive_on_destroy = true

  # シークレットスキャンと push protection（公開リポジトリなら無料）。
  # 注意: provider は visibility より先にこれを更新するので、既存の private リポジトリを public に変える
  # apply では有効にできない。そのときは visibility の変更を先に apply してから足す。
  dynamic "security_and_analysis" {
    for_each = var.github_repository.visibility == "public" ? [1] : []
    content {
      secret_scanning {
        status = "enabled"
      }
      secret_scanning_push_protection {
        status = "enabled"
      }
    }
  }

  lifecycle {
    prevent_destroy = true
  }
}

# main のブランチ保護（platform リポジトリと同じ内容）
# - 直接 push・force push・削除を禁止し、PR を必須にする
# - マージには1件以上の承認が必要（AI 用の GitHub App は自分の PR を承認できない）
resource "github_repository_ruleset" "main" {
  count = local.manage_repository ? 1 : 0

  name        = "main"
  repository  = github_repository.this[0].name
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["~DEFAULT_BRANCH"]
      exclude = []
    }
  }

  rules {
    deletion         = true
    non_fast_forward = true

    pull_request {
      allowed_merge_methods           = ["merge", "squash"]
      required_approving_review_count = 1
    }
  }

  # 無料プランの private リポジトリでは ruleset を作れないので、visibility の変更が済んでから作る
  depends_on = [github_repository.this]
}

# プロジェクトの CI に鍵を渡す Environment。main のワークフローからしか使えないようにする。
# PR のブランチや AI が push したブランチのワークフローからは、鍵を読めない。
resource "github_repository_environment" "ci" {
  count = local.manage_repository ? 1 : 0

  repository  = github_repository.this[0].name
  environment = var.github_repository.environment

  deployment_branch_policy {
    protected_branches     = false
    custom_branch_policies = true
  }

  # 無料プランの private リポジトリでは Environment を作れないので、visibility の変更が済んでから作る
  depends_on = [github_repository.this]
}

resource "github_repository_environment_deployment_policy" "ci_main" {
  count = local.manage_repository ? 1 : 0

  repository     = github_repository.this[0].name
  environment    = github_repository_environment.ci[0].environment
  branch_pattern = "main"
}

# アカウント ID は秘密ではないので Variables に置く（docs/secrets.md）
resource "github_actions_environment_variable" "cloudflare_account_id" {
  count = local.manage_repository ? 1 : 0

  repository    = github_repository.this[0].name
  environment   = github_repository_environment.ci[0].environment
  variable_name = "CLOUDFLARE_ACCOUNT_ID"
  value         = var.cloudflare_account_id
}

# tfstate 用の R2 キー（S3 互換の認証情報）
resource "github_actions_environment_secret" "tfstate_access_key_id" {
  count = local.manage_repository ? 1 : 0

  repository  = github_repository.this[0].name
  environment = github_repository_environment.ci[0].environment
  secret_name = "AWS_ACCESS_KEY_ID"
  value       = cloudflare_account_token.tfstate[0].id
}

resource "github_actions_environment_secret" "tfstate_secret_access_key" {
  count = local.manage_repository ? 1 : 0

  repository  = github_repository.this[0].name
  environment = github_repository_environment.ci[0].environment
  secret_name = "AWS_SECRET_ACCESS_KEY"
  value       = sha256(cloudflare_account_token.tfstate[0].value)
}

# プロジェクトの CI 用 Cloudflare トークン
resource "github_actions_environment_secret" "cloudflare_api_token" {
  count = local.manage_project_token ? 1 : 0

  repository  = github_repository.this[0].name
  environment = github_repository_environment.ci[0].environment
  secret_name = "CLOUDFLARE_API_TOKEN"
  value       = cloudflare_account_token.project[0].value
}
