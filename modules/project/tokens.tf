# プロジェクト用のトークン。どちらもメインアカウントのアカウントトークンとして発行する（AGENTS.md）。

locals {
  manage_project_token = local.manage_repository && var.cloudflare_token_permissions != null

  # 権限グループの名前 => ID。同じ名前が複数あれば one() がエラーにする（取り違えを防ぐ）
  permission_group_ids = local.manage_repository ? {
    for g in data.cloudflare_account_api_token_permission_groups_list.all[0].result : g.name => g.id...
  } : {}

  account_resource = "com.cloudflare.api.account.${var.cloudflare_account_id}"

  # R2 のバケット単位の権限で使うリソース名（jurisdiction は default）
  tfstate_bucket_resource = "com.cloudflare.edge.r2.bucket.${var.cloudflare_account_id}_default_${cloudflare_r2_bucket.tfstate.name}"

  token_account_permissions = local.manage_project_token ? var.cloudflare_token_permissions.account : []
  token_zone_permissions    = local.manage_project_token ? var.cloudflare_token_permissions.zones : {}
}

data "cloudflare_account_api_token_permission_groups_list" "all" {
  count = local.manage_repository ? 1 : 0

  account_id = var.cloudflare_account_id
}

data "cloudflare_zone" "token" {
  for_each = local.token_zone_permissions

  filter = {
    name = each.key
  }
}

# tfstate 用の R2 キー。<name>-tfstate バケットのオブジェクトの読み書きだけができる。
# S3 の Access Key ID はトークンの ID、Secret Access Key はトークン値の SHA-256（docs/architecture.md）
resource "cloudflare_account_token" "tfstate" {
  count = local.manage_repository ? 1 : 0

  account_id = var.cloudflare_account_id
  name       = "${var.name}-tfstate"
  expires_on = var.token_expires_on

  policies = [{
    effect = "allow"
    permission_groups = [{
      id = one(local.permission_group_ids["Workers R2 Storage Bucket Item Write"])
    }]
    resources = jsonencode({
      (local.tfstate_bucket_resource) = "*"
    })
  }]
}

# プロジェクトの CI 用 Cloudflare トークン
resource "cloudflare_account_token" "project" {
  count = local.manage_project_token ? 1 : 0

  account_id = var.cloudflare_account_id
  name       = "${var.name}-ci"
  expires_on = var.token_expires_on

  policies = concat(
    length(local.token_account_permissions) == 0 ? [] : [{
      effect = "allow"
      permission_groups = [
        for p in local.token_account_permissions : { id = one(local.permission_group_ids[p]) }
      ]
      resources = jsonencode({
        (local.account_resource) = "*"
      })
    }],
    [for zone, perms in local.token_zone_permissions : {
      effect = "allow"
      permission_groups = [
        for p in perms : { id = one(local.permission_group_ids[p]) }
      ]
      resources = jsonencode({
        "com.cloudflare.api.account.zone.${data.cloudflare_zone.token[zone].zone_id}" = "*"
      })
    }],
  )

  lifecycle {
    precondition {
      condition = length(setintersection(
        toset(concat(local.token_account_permissions, flatten(values(local.token_zone_permissions)))),
        toset(local.forbidden_permissions),
      )) == 0
      error_message = "プロジェクト用トークンに、トークンやメンバー・アカウント設定を編集できる権限は付けられない（AGENTS.md）。"
    }
  }
}

locals {
  # プロジェクトに渡してはいけない権限（AGENTS.md「トークンを作れる権限を付けない」）
  forbidden_permissions = [
    "API Tokens Write",
    "Account API Tokens Write",
    "Account Settings Write",
    "Memberships Write",
  ]
}
