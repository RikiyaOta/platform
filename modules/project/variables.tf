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

variable "github_repository" {
  description = <<-EOT
    プロジェクトの GitHub リポジトリ（リポジトリ名は name と同じ）。null ならリポジトリを管理せず、
    tfstate 用の R2 キー・プロジェクト用トークン・Secrets も作らない（書き込む先がないため）。
    - environment: 鍵を書き込む Environment の名前。main ブランチのワークフローからだけ使える
  EOT
  type = object({
    description = string
    visibility  = optional(string, "public")
    environment = optional(string, "production")
  })
  default = null

  validation {
    condition     = var.github_repository == null ? true : contains(["public", "private"], var.github_repository.visibility)
    error_message = "visibility は public か private にすること。"
  }
}

variable "cloudflare_token_permissions" {
  description = <<-EOT
    プロジェクトの CI 用 Cloudflare トークン（Secrets の CLOUDFLARE_API_TOKEN）に付ける権限。
    権限グループの名前で書く（例: "Workers Scripts Write"）。null ならトークンを作らない。
    - account: メインアカウント全体に効く権限
    - zones:   ゾーン名 => そのゾーンにだけ効く権限
    トークンを作れる権限（API Tokens Write など）は付けないこと（AGENTS.md）。
  EOT
  type = object({
    account = optional(list(string), [])
    zones   = optional(map(list(string)), {})
  })
  default = null
}

variable "token_expires_on" {
  description = "プロジェクト用トークン（Cloudflare のトークンと tfstate 用の R2 キー）の有効期限（RFC 3339）。null なら期限なし"
  type        = string
  default     = null
}
