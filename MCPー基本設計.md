決定事項である「インバウンドPort 80」「アウトバウンドPort 443限定」を反映した、MCPサーバ（dev環境）の基本設計書案を作成しました。

---

# 基本設計書：MCPサーバ（PoC/dev環境）

## 1. 構成概要

本設計は、AWS Marketplaceの公式コンテナイメージを利用し、Amazon Kiro IDEからアクセス可能なMCPサーバをAWS ECS Fargate上に構築するものである。社内ネットワークのポート制限を考慮し、PoC段階ではPort 80を利用した通信経路を確保する。

## 2. 修正方針（既存モジュール：Fargate）

既存のFargateモジュールに対し、制約事項を反映するための修正を以下の通り行う。

* **タスク定義の修正**:
* `depends_on = [aws_ecs_task_definition.this]` の記述を削除する。
* 【理由】自己参照によるTerraformの循環参照エラーを回避するため。


* **セキュリティグループ（アウトバウンド）の制限**:
* `aws_security_group_rule.ecs_egress` の設定を修正する。
* `from_port`, `to_port` を `443`、`protocol` を `tcp` に変更する。
* 【理由】決定事項に基づき、イメージの取得やログ送信に必要なHTTPS通信のみに許可を限定するため。


* **不具合修正（変数名）**:
* `aws_security_group_rule.ecs_ingress_alb` 内の `source_security_group_id` を `var.lb_security_group_id` に修正する。
* 【理由】既存コードでの参照エラー（var.の欠落）を解消するため。



## 3. 作成リソース一覧

| カテゴリ | リソース名 | 用途・役割 |
| --- | --- | --- |
| **Compute** | ECS Cluster | MCPサーバの実行基盤 |
|  | ECS Service | タスクの維持、ネットワーク設定、Port 80でのリッスン |
|  | ECS Task Definition | Marketplaceイメージの指定、CPU(512)/Memory(1024)の定義 |
| **Network** | Security Group | ECSタスク用。インバウンド80 / アウトバウンド443の制御 |
| **IAM** | Task Execution Role | ECRからのイメージ取得、CloudWatchへのログ出力権限 |
|  | Task Role | MCPサーバが他のAWSサービスを利用するための権限 |
| **Storage** | CloudWatch Log Group | コンテナの標準出力ログを保存 |

## 4. パラメータシート（dev環境用）

### 4.1 ECSタスク/サービス定義

| 項目 | 設定値 | 備考 |
| --- | --- | --- |
| **env** | dev | 環境識別子 |
| **name_prefix** | mcp-server | リソース名の接頭辞 |
| **container_port** | 80 | Kiroからのアクセス用 |
| **host_port** | 80 | Fargate(awsvpc)のためコンテナポートと一致 |
| **container_cpu** | 512 | PoC用最小スペック |
| **container_memory** | 1024 | PoC用最小スペック |
| **container_count** | 1 | 可用性よりコスト重視 |
| **assign_public_ip** | false | 社内NW(DCS Hub)経由のため不要 |

### 4.2 セキュリティグループ設計

| 方向 | プロトコル | ポート | ソース/宛先 | 備考 |
| --- | --- | --- | --- | --- |
| **Ingress** | TCP | 80 | 社内NW(Local PC) CIDR | Kiro IDEからの接続用 |
| **Egress** | TCP | 443 | 0.0.0.0/0 | ECR/Logs/S3エンドポイントへの通信 |

## 5. 運用上の特記事項

* **IP変動への対応**: 本PoCフェーズではLBを配置しないため、再起動によりタスクのプライベートIPが変動する。変動時は、Kiroの接続先設定（json）を手動で更新する運用とする。
* **ポートの整合性**: Marketplaceイメージ側が80以外でリッスンしている場合、コンテナの環境変数等でリッスンポートを80へ変更する設定が必要となる場合がある。