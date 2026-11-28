# 既存リソースの取り込み（docs/migration.md）
# apply して state に入ったら、このブロックは消してよい。

# 手動で作った rss-news-site の tfstate 用バケット
# ID の形式: <account_id>/<bucket_name>/<jurisdiction>
import {
  to = module.rss_news_site.cloudflare_r2_bucket.tfstate
  id = "${var.cloudflare_account_id}/rss-news-site-tfstate/default"
}
