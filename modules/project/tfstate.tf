locals {
  tfstate_bucket_name = coalesce(var.tfstate_bucket_name, "${var.name}-tfstate")
}

# プロジェクトの tfstate 専用のバケット（メインアカウント）
resource "cloudflare_r2_bucket" "tfstate" {
  account_id = var.cloudflare_account_id
  name       = local.tfstate_bucket_name

  # location は指定しない。指定した値が既存のバケットと食い違うと作り直しになるため。
  # 指定しなければ、新しく作るときは Cloudflare が決め、取り込むときは既存の値がそのまま使われる。
  jurisdiction  = "default"
  storage_class = "Standard"

  lifecycle {
    prevent_destroy = true
  }
}
