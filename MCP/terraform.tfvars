# ============================================================
# ✏️ REPLACE_ME: 確定後に書き換えてください
# ============================================================

# Marketplace サブスクライブ後にECRリポジトリURIを確認して記載
container_image_uri = "REPLACE_ME_CONTAINER_IMAGE_URI"
# 例: "709825985650.dkr.ecr.us-east-1.amazonaws.com/hashicorp/terraform-mcp-server:latest"

# ============================================================
# 確定済み設定（変更不要）
# ============================================================

aws_region  = "ap-northeast-1"
name_prefix = "cms-eng-kiro"
env         = "dev"

# ネットワーク
vpc_id   = "vpc-0c0130a3c16934ca1" # AWS-apnortheast1-STD-NPD-VPC-04
vpc_cidr = "10.0.0.0/8"            # 社内NW全体（SGインバウンド制限）

subnet_ids = [
  "subnet-0b885ae963507b1b5", # AWS-apnortheast1-STD-NPD-SBN-09
  "subnet-025bdda24d36bc235", # AWS-apnortheast1-STD-NPD-SBN-08
]

# ECSリソース
task_cpu    = 256
task_memory = 512

# コンテナ動作
transport_mode = "streamable-http"
transport_port = 80
transport_host = "0.0.0.0"
mcp_endpoint   = "/mcp"

# CloudWatch Logs
log_retention_days = 30

# CloudWatch アラームしきい値（SNS通知なし / dev環境）
alarm_cpu_threshold    = 80
alarm_memory_threshold = 80

# EventBridgeスケジュール（平日のみ / JST）
schedule_start_cron = "cron(0 8 ? * MON-FRI *)"  # 平日 08:00 JST 起動
schedule_stop_cron  = "cron(0 22 ? * MON-FRI *)" # 平日 22:00 JST 停止
