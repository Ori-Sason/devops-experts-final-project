resource "aws_lb" "devops_experts_alb" {
  name               = "devops-experts-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets = [
    aws_subnet.pub_sub_1.id,
    aws_subnet.pub_sub_2.id
  ]

  enable_deletion_protection = false

  tags = {
    Name = "devops-experts-alb"
  }
}

resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "alb-sg"
  vpc_id      = aws_vpc.devops_experts_vpc.id
  tags = {
    Name = "devops-experts-alb-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_sg_inbound_allow_all_80" {
  security_group_id = aws_security_group.alb_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "alb_sg_outbound_allow_all" {
  security_group_id = aws_security_group.alb_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_lb_listener" "alb_listener_80" {
  load_balancer_arn = aws_lb.devops_experts_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = module.k3s_cluster.web_app_target_group_arn
  }
}

resource "aws_lb_listener_rule" "jenkins_rule" {
  listener_arn = aws_lb_listener.alb_listener_80.arn
  priority     = 10 # Lower number means higher evaluation priority

  action {
    type             = "forward"
    target_group_arn = module.jenkins.jenkins_target_group_arn
  }

  condition {
    path_pattern {
      values = [
        "/github-webhook", "/github-webhook/*",
        "/generic-webhook-trigger", "/generic-webhook-trigger/*",
      ]
    }
  }

  condition {
    http_request_method { values = ["POST"] }
  }
}

resource "aws_lb_listener_rule" "k3s_rule" {
  listener_arn = aws_lb_listener.alb_listener_80.arn
  priority     = 20

  action {
    type             = "forward"
    target_group_arn = module.k3s_cluster.web_app_target_group_arn
  }

  condition {
    path_pattern {
      values = ["*"]
    }
  }
}
