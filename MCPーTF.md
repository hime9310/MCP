# TF作成

## gaiyou
インバウンドは **80**、アウトバウンドは **443** という決定事項を反映し、PoC（dev環境）向けの構成をまとめました。

既存のFargateモジュールについては、汎用性を維持しつつ、今回の制約（443限定など）に対応するための最小限の修正案を提示します。


### 1. 既存Fargateモジュールの修正箇所

`Fargate/main.tf` 内の3箇所を修正します。

```hcl
# Fargate/main.tf

# 修正箇所①：タスク定義の循環参照エラー回避
resource "aws_ecs_task_definition" "this" {
  # ... (略)
  # [修正理由] 既存コードにあった depends_on = [aws_ecs_task_definition.this] は
  # 自分自身を参照しておりTerraformの循環参照エラーになるため削除します。
}

# 修正箇所②：アウトバウンド通信の制限 (443限定)
resource "aws_security_group_rule" "ecs_egress" {
  type              = "egress"
  from_port         = 443   # [修正] 0 から 443 へ
  to_port           = 443   # [修正] 0 から 443 へ
  protocol          = "tcp" # [修正] "-1"(ALL) から "tcp" へ
  security_group_id = aws_security_group.this.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow HTTPS outbound traffic only" 
  # [修正理由] 決定事項に基づき、Marketplaceイメージの取得やログ送信に必要な443ポートのみに制限します。
}

# 修正箇所③：セキュリティグループルールの変数名修正
resource "aws_security_group_rule" "ecs_ingress_alb" {
  count = var.lb_type == "ALB" ? 1 : 0
  # ... (略)
  # [修正] source_security_group_id = aws_lb_security_group_id 
  source_security_group_id = var.lb_security_group_id 
  # [修正理由] 既存コードでは「var.」が抜けており、未定義のリソース参照エラーになるため修正します。
}

```

---

### 2. デプロイ用ルートモジュール一式 (dev環境用)

既存の `Fargate` フォルダと同じ階層に以下のファイルを配置してください。

#### ① `main.tf`

決定事項であるポート80の利用と、Local PCからのアクセス許可を追加した構成です。

```hcl
provider "aws" {
  region = "ap-northeast-1"
}

# MCPサーバ(Fargate)のデプロイ
module "mcp_server_dev" {
  source = "./Fargate"

  # 基本設定
  name_prefix = "mcp-server"
  env         = "dev"
  name_suffix = "01"

  # コンテナ設定 (決定事項: 80ポート)
  container_image_name_or_uri = var.marketplace_image_uri
  container_port              = 80
  host_port                   = 80
  container_cpu               = var.cpu
  container_memory            = var.memory
  
  # ネットワーク・ログ設定
  vpc_id             = var.vpc_id
  ecs_subnet_id_list = var.subnet_ids
  ecs_log_group      = "/aws/ecs/mcp-server-dev"

  # PoCのためオートスケーリングはOFF
  auto_scaling_enabled = false
}

# 追加：Local PC(社内NW)からPort 80で直接アクセスするためのSGルール
resource "aws_security_group_rule" "ingress_from_local" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = module.mcp_server_dev.security_group_id_ecs
  cidr_blocks       = var.allowed_cidr_list # 社内NWの帯域
  description       = "Allow inbound from Local PC on port 80"
}

```

#### ② `variables.tf`

```hcl
variable "marketplace_image_uri" { type = string }
variable "vpc_id"               { type = string }
variable "subnet_ids"           { type = list(string) }
variable "allowed_cidr_list"    { type = list(string) }
variable "cpu"                  { type = number; default = 512 }
variable "memory"               { type = number; default = 1024 }

```

#### ③ `outputs.tf`

```hcl
output "ecs_service_name" { value = module.mcp_server_dev.ecs_service_name }
output "security_group_id" { value = module.mcp_server_dev.security_group_id_ecs }

```

#### ④ `terraform.tfvars`

```hcl
# AWS Marketplaceの製品ドキュメントに従い、適宜書き換えてください
marketplace_image_uri = "709825985650.dkr.ecr.us-east-1.amazonaws.com/amazon/kiro-mcp-server:latest"

# 既存環境の情報
vpc_id            = "XXXXXXXXXXXX"
subnet_ids        = ["XXXXXXXXXXXX", "XXXXXXXXXXXX"]
allowed_cidr_list = ["XXXXXXXXXXXX"] # Local PCの属する社内NWセグメント

```

### 運用のポイント

* **Port 80への変更**: Marketplace製品側でデフォルトリッスンポートが8000等の場合、コンテナの起動引数（`container_command`）や環境変数でポートを80に変更する設定を製品ドキュメントに沿って追加してください。
* **アウトバウンド**: 443に絞っているため、万が一コンテナがHTTP(80)で外部通信を行おうとするとブロックされます。