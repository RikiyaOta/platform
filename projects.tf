module "rss_news_site" {
  source = "./modules/project"

  name                  = "rss-news-site"
  cloudflare_account_id = var.cloudflare_account_id
}

module "kaidoki" {
  source = "./modules/project"

  name                  = "kaidoki"
  cloudflare_account_id = var.cloudflare_account_id

  github_repository = {
    description = "近所のスーパーのチラシを解析して自分用オススメ情報を教えるシステム。"
    visibility  = "public"
  }

  # kaidoki の CI（Terraform と wrangler deploy）で使う
  cloudflare_token_permissions = {
    account = [
      "Access: Apps and Policies Write", # Access アプリケーション
      "Workers Scripts Write",           # wrangler deploy、独自ドメインの割り当て
      "Workers R2 Storage Write",        # アプリ用バケット kaidoki-data の作成と読み出し（decisions 10）
    ]
    zones = {
      "rikiyaota.kyoto" = [
        "Zone Read",
        "DNS Write",
        "Workers Routes Write", # 独自ドメイン
      ]
    }
  }
  token_expires_on = "2027-12-01T00:00:00Z"
}
