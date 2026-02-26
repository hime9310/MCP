output "ecs_cluster_name" {
  description = "ECSクラスター名"
  value       = aws_ecs_cluster.mcp.name
}

output "ecs_service_name" {
  description = "ECSサービス名"
  value       = aws_ecs_service.mcp.name
}

output "ecs_task_definition_arn" {
  description = "ECSタスク定義ARN（最新リビジョン）"
  value       = aws_ecs_task_definition.mcp.arn
}

output "security_group_id" {
  description = "MCPサーバのセキュリティグループID"
  value       = aws_security_group.mcp.id
}

output "task_execution_role_arn" {
  description = "ECSタスク実行ロールARN"
  value       = aws_iam_role.ecs_task_execution.arn
}

output "log_group_name" {
  description = "CloudWatch Logsグループ名"
  value       = aws_cloudwatch_log_group.mcp.name
}

output "alarm_names" {
  description = "CloudWatchアラーム名一覧"
  value = {
    cpu_high        = aws_cloudwatch_metric_alarm.cpu_high.alarm_name
    memory_high     = aws_cloudwatch_metric_alarm.memory_high.alarm_name
    task_count_zero = aws_cloudwatch_metric_alarm.task_count_zero.alarm_name
  }
}

output "schedule_note" {
  description = "稼働スケジュール"
  value       = "平日（月〜金）08:00 JST 起動 / 22:00 JST 停止。土日祝は終日停止。"
}

output "kiro_connection_note" {
  description = "Kiro IDE接続URL（タスク起動後にプライベートIPを確認）"
  value       = "http://<FargateタスクのプライベートIP>:80/mcp"
}
