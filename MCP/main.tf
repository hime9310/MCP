locals {
  prefix = "${var.name_prefix}-${var.env}"
}

# ============================================================
# CloudWatch Logs
# ============================================================

resource "aws_cloudwatch_log_group" "mcp" {
  name              = "/ecs/${local.prefix}-mcp-server"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${local.prefix}-mcp-server-log-group"
    Env  = var.env
  }
}

# ============================================================
# IAM: ECS Task Execution Role
# ============================================================

data "aws_iam_policy_document" "ecs_task_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task_execution" {
  name               = "${local.prefix}-ecs-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json

  tags = {
    Name = "${local.prefix}-ecs-task-execution-role"
    Env  = var.env
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_managed" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ============================================================
# IAM: EventBridge Scheduler Role
# ============================================================

data "aws_iam_policy_document" "scheduler_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eventbridge_scheduler" {
  name               = "${local.prefix}-scheduler-role"
  assume_role_policy = data.aws_iam_policy_document.scheduler_assume_role.json

  tags = {
    Name = "${local.prefix}-scheduler-role"
    Env  = var.env
  }
}

data "aws_iam_policy_document" "scheduler_ecs_policy" {
  statement {
    actions   = ["ecs:UpdateService"]
    resources = [aws_ecs_service.mcp.id]
  }
}

resource "aws_iam_role_policy" "eventbridge_scheduler_ecs" {
  name   = "${local.prefix}-scheduler-ecs-policy"
  role   = aws_iam_role.eventbridge_scheduler.id
  policy = data.aws_iam_policy_document.scheduler_ecs_policy.json
}

# ============================================================
# Security Group
# ============================================================

resource "aws_security_group" "mcp" {
  name        = "${local.prefix}-mcp-sg"
  description = "Security group for ${local.prefix} MCP Server"
  vpc_id      = var.vpc_id

  # インバウンド: Port 80（社内NW 10.0.0.0/8 からのアクセスのみ許可）
  ingress {
    description = "MCP HTTP from corporate network"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # アウトバウンド: Port 443（Terraform Registry等への通信）
  egress {
    description = "HTTPS outbound to Terraform Registry"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.prefix}-mcp-sg"
    Env  = var.env
  }
}

# ============================================================
# ECS Cluster
# ============================================================

resource "aws_ecs_cluster" "mcp" {
  name = "${local.prefix}-mcp-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${local.prefix}-mcp-cluster"
    Env  = var.env
  }
}

# ============================================================
# ECS Task Definition
# ============================================================

resource "aws_ecs_task_definition" "mcp" {
  family                   = "${local.prefix}-mcp-server"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name      = "${local.prefix}-mcp-server"
      image     = var.container_image_uri
      essential = true

      portMappings = [
        {
          containerPort = var.transport_port
          protocol      = "tcp"
        }
      ]

      environment = [
        { name = "TRANSPORT_MODE", value = var.transport_mode },
        { name = "TRANSPORT_PORT", value = tostring(var.transport_port) },
        { name = "TRANSPORT_HOST", value = var.transport_host },
        { name = "MCP_ENDPOINT",   value = var.mcp_endpoint }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.mcp.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = {
    Name = "${local.prefix}-mcp-server"
    Env  = var.env
  }
}

# ============================================================
# ECS Service
# ============================================================

resource "aws_ecs_service" "mcp" {
  name            = "${local.prefix}-mcp-service"
  cluster         = aws_ecs_cluster.mcp.id
  task_definition = aws_ecs_task_definition.mcp.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.mcp.id]
    assign_public_ip = false
  }

  # EventBridgeによるdesired_count変更をTerraformが上書きしないようにする
  lifecycle {
    ignore_changes = [desired_count]
  }

  tags = {
    Name = "${local.prefix}-mcp-service"
    Env  = var.env
  }
}

# ============================================================
# CloudWatch Alarms（dev環境: 通知先SNSなし・記録のみ）
# ============================================================

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${local.prefix}-mcp-cpu-high"
  alarm_description   = "ECS CPU使用率が${var.alarm_cpu_threshold}%を超過"
  namespace           = "AWS/ECS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = var.alarm_cpu_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = aws_ecs_cluster.mcp.name
    ServiceName = aws_ecs_service.mcp.name
  }

  tags = {
    Name = "${local.prefix}-mcp-cpu-high"
    Env  = var.env
  }
}

resource "aws_cloudwatch_metric_alarm" "memory_high" {
  alarm_name          = "${local.prefix}-mcp-memory-high"
  alarm_description   = "ECS メモリ使用率が${var.alarm_memory_threshold}%を超過"
  namespace           = "AWS/ECS"
  metric_name         = "MemoryUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = var.alarm_memory_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = aws_ecs_cluster.mcp.name
    ServiceName = aws_ecs_service.mcp.name
  }

  tags = {
    Name = "${local.prefix}-mcp-memory-high"
    Env  = var.env
  }
}

resource "aws_cloudwatch_metric_alarm" "task_count_zero" {
  alarm_name          = "${local.prefix}-mcp-task-count-zero"
  alarm_description   = "ECS 実行中タスク数が0（平日稼働時間中の障害検知用）"
  namespace           = "ECS/ContainerInsights"
  metric_name         = "RunningTaskCount"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = aws_ecs_cluster.mcp.name
    ServiceName = aws_ecs_service.mcp.name
  }

  tags = {
    Name = "${local.prefix}-mcp-task-count-zero"
    Env  = var.env
  }
}

# ============================================================
# EventBridge Scheduler: 起動（平日 08:00 JST）
# ============================================================

resource "aws_scheduler_schedule" "mcp_start" {
  name        = "${local.prefix}-mcp-start"
  description = "ECSサービス起動: 平日 08:00 JST（月〜金）"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression          = var.schedule_start_cron
  schedule_expression_timezone = "Asia/Tokyo"

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:ecs:updateService"
    role_arn = aws_iam_role.eventbridge_scheduler.arn

    input = jsonencode({
      Cluster      = aws_ecs_cluster.mcp.name
      Service      = aws_ecs_service.mcp.name
      DesiredCount = 1
    })
  }
}

# ============================================================
# EventBridge Scheduler: 停止（平日 22:00 JST）
# ============================================================

resource "aws_scheduler_schedule" "mcp_stop" {
  name        = "${local.prefix}-mcp-stop"
  description = "ECSサービス停止: 平日 22:00 JST（月〜金）"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression          = var.schedule_stop_cron
  schedule_expression_timezone = "Asia/Tokyo"

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:ecs:updateService"
    role_arn = aws_iam_role.eventbridge_scheduler.arn

    input = jsonencode({
      Cluster      = aws_ecs_cluster.mcp.name
      Service      = aws_ecs_service.mcp.name
      DesiredCount = 0
    })
  }
}
