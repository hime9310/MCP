# ============================================================
# ✏️ REPLACE_ME: 確定後に書き換えてください
# ============================================================

# AWSリージョン
aws_region = "REPLACE_ME_AWS_REGION" # 例: "ap-northeast-1"

# 環境名
environment = "dev"

# ------------------------------------------------------------
# ネットワーク（既存VPC・サブネット）
# ------------------------------------------------------------

vpc_id = "REPLACE_ME_VPC_ID" # 例: "vpc-0123456789abcdef0"

subnet_ids = [
  "REPLACE_ME_SUBNET_ID_1", # 例: "subnet-0123456789abcdef0"
  # "REPLACE_ME_SUBNET_ID_2",
]

# ------------------------------------------------------------
# コンテナイメージ
# ------------------------------------------------------------

# Marketplace サブスクライブ後にECRリポジトリURIを確認して記載
container_image_uri = "REPLACE_ME_CONTAINER_IMAGE_URI"
# 例: "709825985650.dkr.ecr.us-east-1.amazonaws.com/hashicorp/terraform-mcp-server:latest"

# ============================================================
# 以下はデフォルト値のまま変更不要（必要に応じて上書き）
# ============================================================

ecs_cluster_name = "terraform-mcp-server-cluster"
ecs_service_name = "terraform-mcp-server"
task_family      = "terraform-mcp-server"

task_cpu    = 256
task_memory = 512

transport_mode = "streamable-http"
transport_port = 80
transport_host = "0.0.0.0"
mcp_endpoint   = "/mcp"

log_group_name     = "/ecs/terraform-mcp-server"
log_retention_days = 30

# EventBridgeスケジュール（JST）
schedule_stop_cron  = "cron(0 22 * * ? *)" # 毎日 22:00 JST 停止
schedule_start_cron = "cron(0 8 * * ? *)"  # 毎日 08:00 JST 起動
