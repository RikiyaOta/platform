variable "name" {
  description = "プロジェクト名。リソース名の接頭辞に使う（例: example-app）"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.name))
    error_message = "name は英小文字・数字・ハイフンだけにし、先頭と末尾は英小文字か数字にすること。"
  }
}

variable "cloudflare_account_id" {
  description = "リソースを作るメインアカウントの Cloudflare アカウント ID"
  type        = string
}

variable "tfstate_bucket_name" {
  description = "tfstate 用バケットの名前。null なら \"<name>-tfstate\"。既存のバケットを取り込むときに、名前を合わせるために使う"
  type        = string
  default     = null
}
