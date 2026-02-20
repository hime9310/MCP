# Terraform MCP Server on ECS Fargate

AWS Marketplace の Terraform MCP Server を ECS Fargate で稼働させるための Terraform コードです。

---

## ファイル構成

```
.
├── versions.tf       # Terraformバージョン・プロバイダー・S3バックエンド定義
├── provider.tf       # AWSプロバイダー設定
├── variables.tf      # 入力変数定義
├── main.tf           # IAM / SG / ECS / EventBridge（全リソース）
├── outputs.tf        # 出力値
└── terraform.tfvars  # パラメータ値（要: REPLACE_MEの書き換え）
```

---

## 事前準備

1. **S3バケット（リモートステート用）** が作成済みであること
2. **AWS Marketplace** で Terraform MCP Server をサブスクライブ済みであること
3. **既存VPC・サブネット** の ID を確認済みであること

---

## デプロイ手順

### 1. REPLACE_ME プレースホルダーを書き換える

以下の2ファイルの `REPLACE_ME_*` を実際の値に変更します。

**`versions.tf`**
```hcl
backend "s3" {
  bucket = "your-tfstate-bucket-name"
  key    = "terraform-mcp-server/terraform.tfstate"
  region = "ap-northeast-1"
}
```

**`terraform.tfvars`**
```hcl
aws_region          = "ap-northeast-1"
vpc_id              = "vpc-xxxxxxxxxxxxxxxxx"
subnet_ids          = ["subnet-xxxxxxxxxxxxxxxxx"]
container_image_uri = "xxxxxxxxxx.dkr.ecr.ap-northeast-1.amazonaws.com/..."
```

### 2. Terraformを実行する

```bash
terraform init
terraform plan
terraform apply
```

---

## Kiro IDE との接続

タスク起動後、ECSコンソールまたはCLIでタスクのパブリックIPを確認します。

```bash
# タスクのENI情報からパブリックIPを取得する例
TASK_ARN=$(aws ecs list-tasks \
  --cluster terraform-mcp-server-cluster \
  --service-name terraform-mcp-server \
  --query 'taskArns[0]' --output text)

ENI_ID=$(aws ecs describe-tasks \
  --cluster terraform-mcp-server-cluster \
  --tasks $TASK_ARN \
  --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' \
  --output text)

aws ec2 describe-network-interfaces \
  --network-interface-ids $ENI_ID \
  --query 'NetworkInterfaces[0].Association.PublicIp' \
  --output text
```

Kiro IDE の MCP 設定に以下を追加します：

```json
{
  "mcpServers": {
    "terraform-mcp-server": {
      "type": "sse",
      "url": "http://<取得したパブリックIP>:80/mcp"
    }
  }
}
```

> ⚠️ タスクが再起動するたびにIPが変わります。再起動後は上記コマンドでIPを再確認し、Kiroの設定を更新してください。

---

## EventBridgeスケジュール

| スケジュール | JST | 動作 |
|---|---|---|
| 起動 | 毎日 08:00 | `desired_count = 1` |
| 停止 | 毎日 22:00 | `desired_count = 0` |

EventBridge Scheduler の `schedule_expression_timezone = "Asia/Tokyo"` を使用しているため、cron式はJST時刻で記載しています。

---

## 削除

```bash
terraform destroy
```
