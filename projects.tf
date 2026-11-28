module "rss_news_site" {
  source = "./modules/project"

  name                  = "rss-news-site"
  cloudflare_account_id = var.cloudflare_account_id
}
