terraform {
  required_version = "~> 1.17"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.29"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.13"
    }
  }

  # platform アカウントの R2 バケット platform-tfstate に state を置く。
  # 接続先はワークフローが AWS_ENDPOINT_URL_S3 で渡し、認証情報は AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY で渡す。
  backend "s3" {
    bucket       = "platform-tfstate"
    key          = "terraform.tfstate"
    region       = "auto"
    use_lockfile = true

    # R2 は AWS ではないので、AWS 固有の確認を飛ばす
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    use_path_style              = true
  }
}
