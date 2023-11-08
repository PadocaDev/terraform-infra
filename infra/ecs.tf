resource "aws_ecs_cluster" "this" {
  name = "${var.cluster_name}"
}

resource "aws_ecs_task_definition" "app" {
  family = "app-task"
  container_definitions = jsonencode([
    {
      name      = var.app_container_name
      image     = var.app_container_image
      cpu       = var.cpu
      memory    = var.memory
      essential = true
      portMappings = [
        {
          name = "app"
          containerPort = var.app_container_port
          hostPort      = var.app_container_port
          protocol = "tcp",
          appProtocol = "http"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.app.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])

  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  memory                   = var.memory
  cpu                      = var.cpu
  execution_role_arn       = aws_iam_role.ecsTaskExecutionRole.arn
  task_role_arn = aws_iam_role.ecsTaskExecutionRole.arn

  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }
}

resource "aws_iam_role" "ecsTaskExecutionRole" {
  name               = "ecsTaskExecutionRole"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRole_policy" {
  role       = aws_iam_role.ecsTaskExecutionRole.name
  count      = "${length(var.iam_policy_arn)}"
  policy_arn = "${var.iam_policy_arn[count.index]}"
}

resource "aws_service_discovery_http_namespace" "this" {
  name        = "internal"
  description = "Descorberta para serviços ECS"
}

resource "aws_ecs_service" "app" {
  name                = "app-service"
  cluster             = aws_ecs_cluster.this.id
  task_definition     = aws_ecs_task_definition.app.arn
  launch_type         = "FARGATE"
  scheduling_strategy = "REPLICA"
  desired_count       = 1
  depends_on = [aws_lb.alb, aws_db_instance.rds]
  enable_execute_command = true

  load_balancer {
    target_group_arn = aws_lb_target_group.target_group_alb.arn
    container_name   = var.app_container_name
    container_port   = var.app_container_port
  }

  network_configuration {
    subnets          = aws_subnet.private_subnet.*.id
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = true
  }

  deployment_controller {
    type = "ECS"
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  service_connect_configuration {
    enabled = true
    namespace = aws_service_discovery_http_namespace.this.arn
    service {
      port_name      = "app"
      discovery_name = "app-padoca"
      client_alias {
        dns_name = "app-padoca"
        port     = 8080
      }
    }
  }
}

resource "aws_security_group" "ecs" {
  name        = "${var.cluster_name}-ecs-task-sg"
  description = "Security Group for ECS Task"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    protocol        = "tcp"
    from_port       = var.app_container_port
    to_port         = var.app_container_port
    security_groups = [aws_security_group.security_group_alb.id]
    cidr_blocks = ["192.168.0.0/16"]
  }
  
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}