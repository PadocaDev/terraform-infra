resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.cluster_name}/${var.app_task_name}"
  retention_in_days = 3
}
