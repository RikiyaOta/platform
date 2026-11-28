# 認証情報はワークフローが環境変数で渡す
# - cloudflare: CLOUDFLARE_API_TOKEN
# - github: GITHUB_TOKEN
provider "cloudflare" {}

provider "github" {
  owner = "RikiyaOta"
}
