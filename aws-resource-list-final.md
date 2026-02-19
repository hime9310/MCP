# Terraform MCP Server 構築 — AWS リソース一覧（最終版）

> **環境**: DCS Hub (AWS) Tokyo Region  
> **VPC**: AWS-apnortheast1-STD-NPD-VPC-04 (vpc-0c0130a3c16934ca1) / 10.191.75.0/26  
> **前提**: 同サブネットで CodePipeline + EC2 によるインターネット通信の実績あり  
> **最終更新**: 2026年2月

---

## サマリ

| 区分 | 新規作成 | 既存利用 | 未決定 | 合計 |
|---|---|---|---|---|
| IAM | 2 | 0 | 0 | 2 |
| ネットワーク (SG) | 2 | 0 | 0 | 2 |
| ネットワーク (VPC Endpoint) | 0〜2 | 0〜2 | 要確認 | 2 |
| ロードバランサ | 3 | 0 | 0 | 3 |
| 証明書 | 1 | 0 | 0 | 1 |
| コンピュート (ECS) | 3 | 0 | 0 | 3 |
| 監視 | 1 | 0 | 0 | 1 |
| State 管理 | 0 | 0 | 2 | 2 |
| **合計** | **12〜14** | **0〜2** | **2〜4** | **16** |

---

## 1. IAM リソース（新規作成: 2）

### 1-1. ECS タスク実行ロール

| 項目 | 値 |
|---|---|
| リソース種別 | IAM Role |
| リソース名 | mcp-server-execution-role |
| 信頼ポリシー | `ecs-tasks.amazonaws.com` |
| 用途 | ECS がコンテナを起動するための権限 |

**権限ポリシー:**

| 権限 | 対象 | 説明 |
|---|---|---|
| ecr:GetAuthorizationToken | * | Marketplace イメージ pull 用の認証トークン取得 |
| ecr:BatchCheckLayerAvailability | * | イメージレイヤー確認 |
| ecr:GetDownloadUrlForLayer | * | イメージレイヤーダウンロード |
| ecr:BatchGetImage | * | イメージ取得 |
| logs:CreateLogStream | /ecs/terraform-mcp-server | ログストリーム作成 |
| logs:PutLogEvents | /ecs/terraform-mcp-server | ログ書き込み |

### 1-2. ECS タスクロール

| 項目 | 値 |
|---|---|
| リソース種別 | IAM Role |
| リソース名 | mcp-server-task-role |
| 信頼ポリシー | `ecs-tasks.amazonaws.com` |
| 用途 | MCP サーバが Terraform 操作を行うための権限 |

**権限ポリシー（S3 + DynamoDB State 管理の場合）:**

| 権限 | 対象 | 説明 |
|---|---|---|
| s3:GetObject / PutObject / DeleteObject | State バケット | Terraform State 読み書き |
| s3:ListBucket | State バケット | バケット一覧 |
| dynamodb:GetItem / PutItem / DeleteItem | State Lock テーブル | State Lock 操作 |
| sts:AssumeRole | Spoke Account ロール | Spoke Account 操作時（パターン B/C） |
| (操作対象に応じた権限) | (未決定) | 最小権限で設定 |

> ⚠️ 操作対象（同一アカウント / Spoke Account / 両方）が確定次第、権限を最終化する

---

## 2. ネットワークリソース — セキュリティグループ（新規作成: 2）

### 2-1. ALB 用セキュリティグループ

| 項目 | 値 |
|---|---|
| リソース種別 | Security Group |
| リソース名 | mcp-alb-sg |
| VPC | vpc-0c0130a3c16934ca1 |

**ルール:**

| 方向 | プロトコル | ポート | ソース/宛先 | 説明 |
|---|---|---|---|---|
| Inbound | TCP | 443 | 社内NW CIDR | Kiro IDE / VS Code からの HTTPS |
| Outbound | ALL | ALL | 0.0.0.0/0 | 全開（社内ポリシー） |

### 2-2. ECS タスク用セキュリティグループ

| 項目 | 値 |
|---|---|
| リソース種別 | Security Group |
| リソース名 | mcp-ecs-sg |
| VPC | vpc-0c0130a3c16934ca1 |

**ルール:**

| 方向 | プロトコル | ポート | ソース/宛先 | 説明 |
|---|---|---|---|---|
| Inbound | TCP | 8080 | mcp-alb-sg | ALB からの MCP トラフィックのみ |
| Outbound | ALL | ALL | 0.0.0.0/0 | 全開（Registry / AWS API / TGW 経由） |

---

## 3. ネットワークリソース — VPC Endpoint（0〜2 新規作成）

> 以前の CodePipeline 環境で VPC Endpoint が残っている場合は再利用可能。  
> インターネット経路（TGW → Hub FW → IGW）が確認済みのため、**VPC Endpoint は必須ではない**が、Gateway 型は無料なので推奨。

### 3-1. S3 Gateway Endpoint

| 項目 | 値 |
|---|---|
| リソース種別 | VPC Endpoint (Gateway) |
| サービス名 | com.amazonaws.ap-northeast-1.s3 |
| 関連付け | ルートテーブル rtb-0f71587542ac329f7 |
| コスト | **無料** |
| 用途 | ECR イメージレイヤー取得 / Terraform State 読み書き |
| 既存確認 | **CodePipeline 時に作成済みの可能性あり → 要確認** |

### 3-2. DynamoDB Gateway Endpoint

| 項目 | 値 |
|---|---|
| リソース種別 | VPC Endpoint (Gateway) |
| サービス名 | com.amazonaws.ap-northeast-1.dynamodb |
| 関連付け | ルートテーブル rtb-0f71587542ac329f7 |
| コスト | **無料** |
| 用途 | Terraform State Lock |
| 既存確認 | **CodePipeline 時に作成済みの可能性あり → 要確認** |

> Interface 型 Endpoint（ecr.dkr / ecr.api / logs / sts）はインターネット経由で到達可能なため不要。コスト最適化で後から追加も可。

---

## 4. ロードバランサリソース（新規作成: 3）

### 4-1. Application Load Balancer

| 項目 | 値 |
|---|---|
| リソース種別 | ALB |
| リソース名 | mcp-server-alb |
| スキーム | **internal**（インターネット非公開） |
| サブネット | SBN-08 (1a) + SBN-09 (1c) |
| セキュリティグループ | mcp-alb-sg |

### 4-2. ターゲットグループ

| 項目 | 値 |
|---|---|
| リソース種別 | Target Group |
| リソース名 | mcp-server-tg |
| ターゲットタイプ | ip（Fargate awsvpc 必須） |
| プロトコル / ポート | HTTP / 8080 |
| ヘルスチェックパス | /mcp |
| VPC | vpc-0c0130a3c16934ca1 |

### 4-3. ALB リスナー

| 項目 | 値 |
|---|---|
| リソース種別 | ALB Listener |
| プロトコル / ポート | HTTPS / 443 |
| SSL 証明書 | ACM Certificate（#5-1 参照） |
| デフォルトアクション | Forward → mcp-server-tg |

---

## 5. 証明書リソース（新規作成: 1）

### 5-1. SSL 証明書

| 項目 | 値 |
|---|---|
| リソース種別 | ACM Certificate |
| 用途 | ALB の HTTPS リスナーに紐付け |
| 発行方法 | 社内 CA（Venafi 連携）or ACM 発行 |

> 既存の Venafi → ACM 自動更新フローがあればそれを利用。

---

## 6. コンピュートリソース — ECS（新規作成: 3）

### 6-1. ECS クラスタ

| 項目 | 値 |
|---|---|
| リソース種別 | ECS Cluster |
| リソース名 | terraform-mcp-cluster |
| キャパシティプロバイダ | FARGATE |

### 6-2. ECS サービス

| 項目 | 値 |
|---|---|
| リソース種別 | ECS Service |
| リソース名 | terraform-mcp-service |
| クラスタ | terraform-mcp-cluster |
| タスク数 | desired_count: 2 |
| 起動タイプ | FARGATE |
| サブネット | **SBN-08 (1a) のみ** |
| セキュリティグループ | mcp-ecs-sg |
| パブリック IP | DISABLED |
| ロードバランサ | mcp-server-tg (port 8080) |

### 6-3. ECS タスク定義

| 項目 | 値 |
|---|---|
| リソース種別 | ECS Task Definition |
| ファミリー名 | terraform-mcp-server |
| ネットワークモード | awsvpc |
| CPU / Memory | 512 / 1024 |
| 実行ロール | mcp-server-execution-role |
| タスクロール | mcp-server-task-role |

**コンテナ定義:**

| 項目 | 値 |
|---|---|
| コンテナ名 | terraform-mcp-server |
| イメージ | **AWS Marketplace URI**（自前ビルド / ECR 不要） |
| コマンド | `streamable-http --transport-port 8080 --transport-host 0.0.0.0 --mcp-endpoint /mcp` |
| ポートマッピング | 8080/tcp |
| 環境変数: MCP_TRANSPORT | streamable-http |
| 環境変数: MCP_ALLOWED_ORIGINS | （空文字列） |
| 環境変数: MCP_STATELESS | true |
| ログドライバ | awslogs → /ecs/terraform-mcp-server |
| ヘルスチェック | `wget -q -O /dev/null http://localhost:8080/mcp` |

---

## 7. 監視リソース（新規作成: 1）

### 7-1. CloudWatch Log Group

| 項目 | 値 |
|---|---|
| リソース種別 | CloudWatch Logs Log Group |
| ロググループ名 | /ecs/terraform-mcp-server |
| 保持期間 | 90日 |
| 用途 | MCP サーバのコンテナログ / 監査ログ |

---

## 8. State 管理リソース（未決定: 2）

> State 管理方式確定後に作成。推奨は S3 + DynamoDB。

### 8-1. S3 バケット

| 項目 | 値 |
|---|---|
| リソース種別 | S3 Bucket |
| リソース名 | (チーム名)-terraform-state |
| バージョニング | 有効 |
| 暗号化 | SSE-S3 or SSE-KMS |
| 用途 | Terraform State ファイル保存 |

### 8-2. DynamoDB テーブル

| 項目 | 値 |
|---|---|
| リソース種別 | DynamoDB Table |
| テーブル名 | terraform-state-lock |
| パーティションキー | LockID (String) |
| 課金モード | オンデマンド |
| 用途 | Terraform State Lock |

---

## 9. 既存利用リソース（新規作成不要）

| # | リソース | 名前 / ID | 備考 |
|---|---|---|---|
| 1 | VPC | AWS-apnortheast1-STD-NPD-VPC-04 / vpc-0c0130a3c16934ca1 | 10.191.75.0/26 |
| 2 | Subnet (1a) | AWS-apnortheast1-STD-NPD-SBN-08 | 10.191.75.0/27 / ECS + ALB 配置 |
| 3 | Subnet (1c) | AWS-apnortheast1-STD-NPD-SBN-09 | 10.191.75.32/27 / ALB 2AZ 要件のみ |
| 4 | Route Table | AWS-apnortheast1-STD-NPD-VPC-04-RT / rtb-0f71587542ac329f7 | 0.0.0.0/0 → TGW |
| 5 | Transit Gateway | tgw-066fa59889d41b1ac | インターネット + Spoke 接続 |
| 6 | インターネット経路 | TGW → Hub FW → IGW | 443/80 は 0.0.0.0/0 全許可（実績あり） |

---

## 10. 不要と判断したリソース

| リソース | 理由 |
|---|---|
| ECR リポジトリ | AWS Marketplace イメージを直接参照 |
| NAT Gateway | Transit GW 経由でインターネット到達可能（実績あり） |
| Interface 型 VPC Endpoint (ecr.dkr / ecr.api / logs / sts) | インターネット経由で到達可能。コスト最適化時に検討 |
| PrivateSubnet1-1c への VPC Endpoint | ALB 2AZ 要件のみ。構成図の通り設定しない |

---

## 11. 要確認事項

| # | 確認事項 | 確認先 | 影響 |
|---|---|---|---|
| 1 | CodePipeline 時の VPC Endpoint（S3/DynamoDB）が残っているか | AWS コンソール | 残っていれば再利用（新規作成不要） |
| 2 | Terraform State 管理方式 | チーム内 | S3 + DynamoDB 推奨。確定後に #8-1, #8-2 を作成 |
| 3 | MCP サーバの操作対象（Hub内 / Spoke / 両方） | チーム内 | タスクロール（#1-2）の権限範囲が変わる |
| 4 | SSL 証明書の発行方法 | セキュリティチーム | Venafi 連携 or ACM 発行 |
| 5 | 社内 NW CIDR（SG Inbound 用） | NW チーム | mcp-alb-sg の Inbound ルールに設定 |

---

## 12. 通信フロー（最終版）

```
Kiro IDE / VS Code (社内PC)
  │ HTTPS :443
  ▼
DCS Hub Shared Service → Direct Connect → Transit GW
  │
  ▼
ALB (mcp-server-alb) ← internal / HTTPS :443 / SSL証明書
  │ HTTP :8080
  ▼
ECS Fargate Task (terraform-mcp-server)
  │ StreamableHTTP /mcp endpoint
  │
  ├──→ Transit GW → Hub FW → IGW → registry.terraform.io (HTTPS:443)
  ├──→ Transit GW → Hub FW → IGW → releases.hashicorp.com (HTTPS:443)
  ├──→ (VPC Endpoint or TGW) → S3 (State)
  ├──→ (VPC Endpoint or TGW) → DynamoDB (State Lock)
  ├──→ Transit GW → Spoke Account (操作対象 / AssumeRole)
  └──→ CloudWatch Logs (監査ログ)
```

---

## 13. IP アドレス消費見込み

| サブネット | /27 利用可能 | 消費見込み | 残り |
|---|---|---|---|
| SBN-08 (1a) | 27 | ALB: ~2 + Fargate: 2 = **~4** | **~23** |
| SBN-09 (1c) | 27 | ALB: ~1 = **~1** | **~26** |

> ⚠️ desired_count を大幅に増やす場合は IP 枯渇リスクあり
