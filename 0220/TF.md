要件を「既存モジュールを使用せず、単一のディレクトリ（main.tf等）で全ての構成を完結させる」形に整理しました。

これにより、モジュール間での変数受け渡しがなくなり、デバッグやEventBridgeによる自動停止設定の紐付けがよりシンプルになります。

---

### 1. システム構成・要件まとめ

#### 【基盤・製品】

* **製品**: AWS Marketplsce Terraform MCP Server 
* **実行環境**: Amazon ECS Fargate (1タスク構成)
* **ステート管理**: 事前作成済みのS3バケットによるリモートバックエンド管理

#### 【ネットワーク・ポート設計】

* **インバウンド**: Port 80 (TCP)
* Local PCからFargateへ直接接続
* ソースIP制限なし（`0.0.0.0/0` 全開）


* **アウトバウンド**: Port 443 (TCP)
* Terraform Registry＆Drawio MCPサーバ等への通信（HTTPS）


#### 【コンテナ動作設定 (Environment Variables)】

製品仕様に基づき、Port 80でリッスンさせるための変数を定義します。

* `TRANSPORT_MODE=streamable-http`
* `TRANSPORT_PORT=80`
* `TRANSPORT_HOST=0.0.0.0`
* `MCP_ENDPOINT=/mcp`

#### 【自動停止・起動スケジュール (EventBridge)】

ECSサービスの `desired_count` を操作してコストを削減します。

* **停止**: 毎日 22:00 (JST) → `desired_count = 0`
* **起動**: 毎日 08:00 (JST) → `desired_count = 1`
* ※JST（日本標準時）とUTC（世界標準時）の差を考慮して設定します。

#### 【Kiro IDE 連携】

* **接続URL**: `http://[FargateタスクのプライベートIP]:80/mcp`
* **接続タイプ**: SSE (Server-Sent Events)
* **留意事項**: 再起動のたびにIPが変わることを受容し、手動でKiroの設定を更新する。

---

### 2. ファイル構成案

単一構成（モジュール非使用）として以下のファイル一式を作成します。

1. **`versions.tf`**: Terraformバージョン、プロバイダー、S3バックエンド定義
2. **`provider.tf`**: AWSプロバイダー設定
3. **`variables.tf`**: VPC ID、サブネットID、イメージURI等の入力変数
4. **`main.tf`**: IAM、SG、ECS、EventBridgeスケジュール（全てのメインリソース）
5. **`outputs.tf`**: ECSサービス名やSG ID等の出力
6. **`terraform.tfvars`**: 具体的なパラメータ値　（VPCとサブネットは既存利用）

---