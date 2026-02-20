# ============================================================
# CloudWatch Logs
# ============================================================

resource "aws_cloudwatch_log_group" "mcp" {
  name              = var.log_group_name
  retention_in_days = var.log_retention_days
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
  name               = "${var.ecs_service_name}-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_managed" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ============================================================
# Security Group
# ============================================================

resource "aws_security_group" "mcp" {
  name        = "${var.ecs_service_name}-sg"
  description = "Security group for Terraform MCP Server"
  vpc_id      = var.vpc_id

  # インバウンド: Port 80（Kiro IDEからの接続）
  ingress {
    description = "MCP HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # アウトバウンド: Port 443（Terraform Registry等へのHTTPS通信）
  egress {
    description = "HTTPS outbound"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ============================================================
# ECS Cluster
# ============================================================

resource "aws_ecs_cluster" "mcp" {
  name = var.ecs_cluster_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# ============================================================
# ECS Task Definition
# ============================================================

resource "aws_ecs_task_definition" "mcp" {
  family                   = var.task_family
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name      = "terraform-mcp-server"
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
        { name = "MCP_ENDPOINT", value = var.mcp_endpoint }
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
}

# ============================================================
# ECS Service
# ============================================================

resource "aws_ecs_service" "mcp" {
  name            = var.ecs_service_name
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
  name               = "${var.ecs_service_name}-scheduler-role"
  assume_role_policy = data.aws_iam_policy_document.scheduler_assume_role.json
}

data "aws_iam_policy_document" "scheduler_ecs_policy" {
  statement {
    actions   = ["ecs:UpdateService"]
    resources = [aws_ecs_service.mcp.id]
  }
}

resource "aws_iam_role_policy" "eventbridge_scheduler_ecs" {
  name   = "${var.ecs_service_name}-scheduler-ecs-policy"
  role   = aws_iam_role.eventbridge_scheduler.id
  policy = data.aws_iam_policy_document.scheduler_ecs_policy.json
}

# ============================================================
# EventBridge Scheduler: 停止 (毎日 22:00 JST)
# ============================================================

resource "aws_scheduler_schedule" "mcp_stop" {
  name        = "${var.ecs_service_name}-stop"
  description = "ECSサービス停止: 毎日 22:00 JST"

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

# ============================================================
# EventBridge Scheduler: 起動 (毎日 08:00 JST)
# ============================================================

resource "aws_scheduler_schedule" "mcp_start" {
  name        = "${var.ecs_service_name}-start"
  description = "ECSサービス起動: 毎日 08:00 JST"

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
