# ============================================================
# ECSクラスター・サービス
# ============================================================

output "ecs_cluster_name" {
  description = "ECSクラスター名"
  value       = aws_ecs_cluster.mcp.name
}

output "ecs_cluster_arn" {
  description = "ECSクラスターARN"
  value       = aws_ecs_cluster.mcp.arn
}

output "ecs_service_name" {
  description = "ECSサービス名"
  value       = aws_ecs_service.mcp.name
}

output "ecs_service_id" {
  description = "ECSサービスID"
  value       = aws_ecs_service.mcp.id
}

output "ecs_task_definition_arn" {
  description = "ECSタスク定義ARN（最新リビジョン）"
  value       = aws_ecs_task_definition.mcp.arn
}

# ============================================================
# ネットワーク
# ============================================================

output "security_group_id" {
  description = "MCPサーバのセキュリティグループID"
  value       = aws_security_group.mcp.id
}

# ============================================================
# IAM
# ============================================================

output "task_execution_role_arn" {
  description = "ECSタスク実行ロールのARN"
  value       = aws_iam_role.ecs_task_execution.arn
}

output "eventbridge_scheduler_role_arn" {
  description = "EventBridgeスケジューラーロールのARN"
  value       = aws_iam_role.eventbridge_scheduler.arn
}

# ============================================================
# CloudWatch
# ============================================================

output "sns_topic_arn" {
  description = "CloudWatchアラーム通知用SNS Topic ARN"
  value       = aws_sns_topic.alarm.arn
}

output "log_group_name" {
  description = "CloudWatch Logsグループ名"
  value       = aws_cloudwatch_log_group.mcp.name
}

output "alarm_cpu_name" {
  description = "CPU使用率アラーム名"
  value       = aws_cloudwatch_metric_alarm.cpu_high.alarm_name
}

output "alarm_memory_name" {
  description = "メモリ使用率アラーム名"
  value       = aws_cloudwatch_metric_alarm.memory_high.alarm_name
}

output "alarm_task_count_name" {
  description = "タスク数アラーム名"
  value       = aws_cloudwatch_metric_alarm.task_count_zero.alarm_name
}

# ============================================================
# 接続情報
# ============================================================

output "kiro_connection_note" {
  description = "Kiro IDE接続URL（タスク起動後にプライベートIPを確認して更新）"
  value       = "http://<FargateタスクのプライベートIP>:80/mcp  ※タスク起動後にECSコンソールで確認"
}

output "schedule_note" {
  description = "稼働スケジュール"
  value       = "平日（月〜金）08:00 JST 起動 / 22:00 JST 停止。土日は終日停止。"
}
