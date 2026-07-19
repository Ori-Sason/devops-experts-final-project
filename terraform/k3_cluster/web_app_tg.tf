resource "aws_lb_target_group" "web_app_tg" {
  name     = "devops-experts-web-app-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.devops_experts_vpc_id

  # FIX - update health check
  health_check {
    path                = "/"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags = {
    Name = "devops-experts-web-app-tg"
  }
}

output "web_app_target_group_arn" {
  description = "ARN of Web App TG - used in parent"
  value       = aws_lb_target_group.web_app_tg.arn
}
