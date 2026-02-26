# cms-eng-kiro-dev Terraform MCP Server

AWS Marketplace の Terraform MCP Server を ECS Fargate で稼働させるインフラコードです。

---

## ファイル構成

```
.
├── versions.tf       # Terraformバージョン・プロバイダー・S3バックエンド
├── provider.tf       # AWSプロバイダー設定
├── variables.tf      # 入力変数定義
├── main.tf           # 全リソース定義
├── outputs.tf        # 出力値
└── terraform.tfvars  # パラメータ値
```

---

## リソース命名規則

`{name_prefix}-{env}-{リソース名}` = `cms-eng-kiro-dev-{リソース名}`

| リソース | 名前 |
|---------|------|
| ECS Cluster | cms-eng-kiro-dev-mcp-cluster |
| ECS Service | cms-eng-kiro-dev-mcp-service |
| ECS Task Definition | cms-eng-kiro-dev-mcp-server |
| Security Group | cms-eng-kiro-dev-mcp-sg |
| IAM Role (ECS) | cms-eng-kiro-dev-ecs-task-execution-role |
| IAM Role (Scheduler) | cms-eng-kiro-dev-scheduler-role |
| CloudWatch Logs | /ecs/cms-eng-kiro-dev-mcp-server |
| CloudWatch Alarm (CPU) | cms-eng-kiro-dev-mcp-cpu-high |
| CloudWatch Alarm (Memory) | cms-eng-kiro-dev-mcp-memory-high |
| CloudWatch Alarm (Task) | cms-eng-kiro-dev-mcp-task-count-zero |
| EventBridge Schedule (起動) | cms-eng-kiro-dev-mcp-start |
| EventBridge Schedule (停止) | cms-eng-kiro-dev-mcp-stop |

---

## デプロイ手順

### 1. REPLACE_ME を書き換える

**`versions.tf`**
```hcl
bucket = "your-tfstate-bucket-name"
```

**`terraform.tfvars`**
```hcl
container_image_uri = "xxxx.dkr.ecr.ap-northeast-1.amazonaws.com/..."
```

### 2. 実行

```bash
terraform init
terraform plan
terraform apply
```

---

## 稼働スケジュール

| 曜日 | 動作 |
|------|------|
| 月〜金 | 08:00 JST 自動起動 → 22:00 JST 自動停止 |
| 土・日 | 終日停止（desired_count = 0） |

---

## CloudWatch 監視（dev環境 / SNS通知なし）

| アラーム | メトリクス | しきい値 | 評価期間 |
|---------|-----------|---------|---------|
| CPU使用率 | CPUUtilization | 80%以上 | 5分×2回 |
| メモリ使用率 | MemoryUtilization | 80%以上 | 5分×2回 |
| タスク数 | RunningTaskCount | 1未満 | 5分×1回 |

`treat_missing_data = "notBreaching"` のため土日・夜間の停止中は発報しない。

---

## Security Group

| 方向 | ポート | ソース | 用途 |
|------|--------|--------|------|
| インバウンド | 80 (HTTP) | 10.0.0.0/8 | 社内NW → Fargate（Kiro IDE接続） |
| アウトバウンド | 443 (HTTPS) | 0.0.0.0/0 | Fargate → Terraform Registry（TGW経由） |

---

## Kiro IDE 接続方法

```bash
# タスクのプライベートIPを取得
TASK_ARN=$(aws ecs list-tasks \
  --cluster cms-eng-kiro-dev-mcp-cluster \
  --service-name cms-eng-kiro-dev-mcp-service \
  --query 'taskArns[0]' --output text)

aws ecs describe-tasks \
  --cluster cms-eng-kiro-dev-mcp-cluster \
  --tasks $TASK_ARN \
  --query 'tasks[0].containers[0].networkInterfaces[0].privateIpv4Address' \
  --output text
```

Kiro IDE 設定:
```json
{
  "mcpServers": {
    "terraform-mcp-server": {
      "type": "sse",
      "url": "http://<プライベートIP>:80/mcp"
    }
  }
}
```

> ⚠️ タスク再起動のたびにIPが変わります。再起動後は上記コマンドで再確認してください。

---

## 障害時の復旧手順

ECSはステートレスなコンテナ構成のためバックアップ対象外。
障害発生時は以下を実行してリソースを再構築する。

```bash
terraform apply
```

Terraformステートファイル（S3管理）とコードが正常であれば全リソースを再構築できる。
