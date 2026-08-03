resource "aws_lb_target_group" "web_app_tg" {
  name     = "devops-experts-web-app-tg"
  port     = var.web_app_node_port
  protocol = "HTTP"
  vpc_id   = var.devops_experts_vpc_id

  health_check {
    enabled             = true
    path                = "/health"
    port                = var.web_app_node_port
    protocol            = "HTTP"
    matcher             = "200" # Only 200 means "Healthy"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "devops-experts-web-app-tg"
  }
}

output "web_app_target_group_arn" {
  description = "ARN of Web App TG - used in parent"
  value       = aws_lb_target_group.web_app_tg.arn
}
