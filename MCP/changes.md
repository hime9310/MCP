# 変更点まとめ

対象ブランチ / 作業日: 2026-02-26  
変更概要: SNS追加・EventBridgeスケジュール時刻変更

---

## 変更ファイル一覧

| ファイル | 変更種別 | 内容概要 |
|---------|---------|---------|
| `variables.tf` | 追記 | SNS Topic名・メールアドレス変数を追加 |
| `main.tf` | 追記・修正 | SNSリソース2つ追加、アラームにalarm_actions追加、停止スケジュール時刻変更 |
| `terraform.tfvars` | 追記・修正 | SNS変数の値を追加、停止cronを変更 |

---

## 1. `variables.tf`

### 追記箇所
`# CloudWatch アラーム` セクションの直前に以下を追加する。

```hcl
# ============================================================
# SNS（アラーム通知）
# ============================================================

variable "alarm_notification_email" {
  description = "CloudWatchアラーム通知先メールアドレス"
  type        = string
}
```

> `default` は設定しない。具体的なメールアドレスは `terraform.tfvars` のみで管理する。

---

## 2. `main.tf`

### 追記①: SNSリソースを追加
`# ============================================================`  
`# CloudWatch Logs`  
の行の**直前**に以下のブロックを丸ごと追加する。

```hcl
# ============================================================
# SNS Topic（CloudWatchアラーム通知用）
# ============================================================

resource "aws_sns_topic" "alarm" {
  name = "${local.prefix}-mcp-alarm"

  tags = {
    Name = "${local.prefix}-mcp-alarm"
    Env  = var.env
  }
}

resource "aws_sns_topic_subscription" "alarm_email" {
  topic_arn = aws_sns_topic.alarm.arn
  protocol  = "email"
  endpoint  = var.alarm_notification_email
}
```

---

### 追記②: 各アラームに `alarm_actions` / `ok_actions` を追加
3つのアラーム（`cpu_high` / `memory_high` / `task_count_zero`）それぞれの  
`treat_missing_data = "notBreaching"` の行の**直後**に以下2行を追加する。  
3つのアラーム全てに同じ内容を追加すること。

```hcl
  alarm_actions = [aws_sns_topic.alarm.arn]
  ok_actions    = [aws_sns_topic.alarm.arn]
```

追加後のイメージ（cpu_highを例に）:

```hcl
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  ...
  treat_missing_data  = "notBreaching"
  alarm_actions = [aws_sns_topic.alarm.arn]   # ← 追加
  ok_actions    = [aws_sns_topic.alarm.arn]   # ← 追加

  dimensions = {
  ...
```

---

### 修正③: 停止スケジュールのcron式を変更
`aws_scheduler_schedule` `"mcp_stop"` リソース内の以下の行を修正する。

**修正前**
```hcl
  schedule_expression          = var.schedule_stop_cron
  description = "ECSサービス停止: 平日 22:00 JST（月〜金）"
```

**修正後**
```hcl
  schedule_expression          = var.schedule_stop_cron
  description = "ECSサービス停止: 平日 21:00 JST（月〜金）"
```

> `schedule_expression` 自体は変数参照のため `terraform.tfvars` 側で変更する（下記参照）。descriptionの時刻表記も合わせて修正すること。

---

## 3. `terraform.tfvars`

### 追記: SNS通知先メールアドレスを追加
`# 確定済み設定（変更不要）` セクション内、`env = "dev"` の行の**直後**に以下を追加する。

```hcl
# SNS アラーム通知先
alarm_notification_email = "xiaji@tomatsu.co.jp"
```

---

### 修正: 停止スケジュールのcron式を変更
以下の行を修正する。

**修正前**
```hcl
schedule_stop_cron  = "cron(0 22 ? * MON-FRI *)" # 平日 22:00 JST 停止
```

**修正後**
```hcl
schedule_stop_cron  = "cron(0 21 ? * MON-FRI *)" # 平日 21:00 JST 停止
```

---

## 修正後の確認事項

### `terraform apply` 前
- [ ] `variables.tf` に `alarm_notification_email` 変数が追加されているか
- [ ] `main.tf` にSNSリソース2つが追加されているか
- [ ] 3つのアラーム全てに `alarm_actions` / `ok_actions` が追加されているか
- [ ] `mcp_stop` の description が「21:00」になっているか
- [ ] `terraform.tfvars` の `schedule_stop_cron` が `cron(0 21 ? * MON-FRI *)` になっているか

### `terraform apply` 後
- [ ] `cms-eng-kiro-dev-mcp-alarm` SNS Topicが作成されていること
- [ ] `xiaji@tomatsu.co.jp` 宛にサブスクリプション確認メールが届いていること
- [ ] **メール内の「Confirm subscription」リンクをクリックすること**（未承認だとアラームメールが届かない）
- [ ] EventBridgeスケジュール `mcp_stop` の実行時刻が21:00 JSTになっていること

---

## 変更後のスケジュール・アラーム設定まとめ

### EventBridgeスケジュール

| スケジュール名 | 動作 | 時刻（JST） | 対象曜日 |
|-------------|------|-----------|---------|
| `cms-eng-kiro-dev-mcp-start` | 起動（desired_count=1） | 08:00 | 月〜金 |
| `cms-eng-kiro-dev-mcp-stop` | 停止（desired_count=0） | **21:00**（変更） | 月〜金 |

### SNS・アラーム通知

| 項目 | 設定値 |
|-----|-------|
| SNS Topic名 | `cms-eng-kiro-dev-mcp-alarm` |
| 通知先メールアドレス | `xiaji@tomatsu.co.jp` |
| 通知タイミング | アラーム発報時・OK復帰時 |
