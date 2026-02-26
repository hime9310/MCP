# ============================================================
# 基本設定
# ============================================================

variable "aws_region" {
  description = "AWSリージョン"
  type        = string
  default     = "ap-northeast-1"
}

variable "name_prefix" {
  description = "リソース名のプレフィックス"
  type        = string
  default     = "cms-eng-kiro"
}

variable "env" {
  description = "環境名"
  type        = string
  default     = "dev"
}

# ============================================================
# ネットワーク（既存VPC・サブネットを使用）
# ============================================================

variable "vpc_id" {
  description = "既存VPCのID"
  type        = string
  default     = "vpc-0c0130a3c16934ca1"
}

variable "vpc_cidr" {
  description = "SGインバウンド許可CIDR（社内NW全体）"
  type        = string
  default     = "10.0.0.0/8"
}

variable "subnet_ids" {
  description = "ECSタスクを配置するサブネットのIDリスト"
  type        = list(string)
  default = [
    "subnet-0b885ae963507b1b5",
    "subnet-025bdda24d36bc235",
  ]
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

variable "log_retention_days" {
  description = "ログの保持期間（日）"
  type        = number
  default     = 30
}

# ============================================================
# CloudWatch アラーム
# ============================================================

variable "alarm_cpu_threshold" {
  description = "CPUアラームのしきい値（%）"
  type        = number
  default     = 80
}

variable "alarm_memory_threshold" {
  description = "メモリアラームのしきい値（%）"
  type        = number
  default     = 80
}

# ============================================================
# EventBridgeスケジュール（平日のみ）
# ============================================================

variable "schedule_start_cron" {
  description = "ECSサービス起動スケジュール（JST）平日 08:00"
  type        = string
  default     = "cron(0 8 ? * MON-FRI *)"
}

variable "schedule_stop_cron" {
  description = "ECSサービス停止スケジュール（JST）平日 22:00"
  type        = string
  default     = "cron(0 22 ? * MON-FRI *)"
}
