resource "aws_lb_target_group" "jenkins_tg" {
  name     = "devops-experts-jenkins-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = var.devops_experts_vpc_id

  health_check {
    enabled             = true
    path                = "/login"
    port                = "8080"
    protocol            = "HTTP"
    matcher             = "200" # Only 200 means "Healthy"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "devops-experts-jenkins-tg"
  }
}

output "jenkins_target_group_arn" {
  description = "ARN of Jenkins TG - used in parent"
  value       = aws_lb_target_group.jenkins_tg.arn
}
