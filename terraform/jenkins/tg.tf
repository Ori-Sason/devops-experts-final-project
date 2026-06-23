resource "aws_lb_target_group" "jenkins_tg" {
  # name     = "devops-experts-jenkins-tg"  # FIX - return the name and remove the lifecycle
  port     = 80 # FIX - 8080
  protocol = "HTTP"
  vpc_id   = var.devops_experts_vpc_id

  health_check {
    enabled             = true
    path                = "/github-webhooks/index.html" # FIX
    port                = "80"                          # FIX - "8080"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    # FIX - try to remove the following line
    matcher             = "200,302,403" # Tells AWS that 200, 302, or 403 all mean "Healthy"
  }

  tags = {
    Name = "devops-experts-jenkins-tg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

output "jenkins_target_group_arn" {
  description = "ARN of Jenkins TG - used in parent"
  value       = aws_lb_target_group.jenkins_tg.arn
}
