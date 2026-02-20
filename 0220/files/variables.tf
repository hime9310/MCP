# ============================================================
# 基本設定
# ============================================================

variable "aws_region" {
  description = "AWSリージョン"
  type        = string
}

variable "environment" {
  description = "環境名（タグ付け用）"
  type        = string
  default     = "dev"
}

# ============================================================
# ネットワーク（既存VPC・サブネットを使用）
# ============================================================

variable "vpc_id" {
  description = "既存VPCのID"
  type        = string
}

variable "subnet_ids" {
  description = "ECSタスクを配置するパブリックサブネットのIDリスト"
  type        = list(string)
}

# ============================================================
# コンテナイメージ
# ============================================================

variable "container_image_uri" {
  description = "AWS MarketplaceのTerraform MCP ServerコンテナイメージURI"
  type        = string
}

# ============================================================
# ECSリソース設定
# ============================================================

variable "ecs_cluster_name" {
  description = "ECSクラスター名"
  type        = string
  default     = "terraform-mcp-server-cluster"
}

variable "ecs_service_name" {
  description = "ECSサービス名"
  type        = string
  default     = "terraform-mcp-server"
}

variable "task_family" {
  description = "ECSタスク定義のファミリー名"
  type        = string
  default     = "terraform-mcp-server"
}

variable "task_cpu" {
  description = "タスクに割り当てるCPUユニット数"
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "タスクに割り当てるメモリ（MiB）"
  type        = number
  default     = 512
}

# ============================================================
# コンテナ動作設定
# ============================================================

variable "transport_mode" {
  description = "MCPトランスポートモード"
  type        = string
  default     = "streamable-http"
}

variable "transport_port" {
  description = "コンテナがリッスンするポート番号"
  type        = number
  default     = 80
}

variable "transport_host" {
  description = "コンテナがバインドするホスト"
  type        = string
  default     = "0.0.0.0"
}

variable "mcp_endpoint" {
  description = "MCPエンドポイントパス"
  type        = string
  default     = "/mcp"
}

# ============================================================
# CloudWatch Logs
# ============================================================

variable "log_group_name" {
  description = "CloudWatch LogsグループName"
  type        = string
  default     = "/ecs/terraform-mcp-server"
}

variable "log_retention_days" {
  description = "ログの保持期間（日）"
  type        = number
  default     = 30
}

# ============================================================
# EventBridgeスケジュール（JST → UTC変換済み）
# ============================================================

variable "schedule_stop_cron" {
  description = "ECSサービス停止スケジュール（UTC）。デフォルトは毎日22:00 JSTに停止 → UTC 13:00"
  type        = string
  default     = "cron(0 13 * * ? *)"
}

variable "schedule_start_cron" {
  description = "ECSサービス起動スケジュール（UTC）。デフォルトは毎日08:00 JSTに起動 → UTC 23:00 (前日)"
  type        = string
  default     = "cron(0 23 * * ? *)"
}
