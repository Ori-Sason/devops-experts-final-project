resource "aws_launch_template" "web_app_worker_template" {
  name_prefix   = "devops-experts-web-app-worker-template"
  image_id      = var.ubuntu_ami_id
  instance_type = "t3.micro"

  iam_instance_profile {
    name = aws_iam_instance_profile.k3s_worker_profile.name
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.k3s_web_app_sg.id]
  }

  user_data = base64encode(templatefile("${path.module}/scripts/worker_provision.sh", {
    aws_region      = var.region,
    node_role_label = "web-app"
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "devops-experts-k3s-web-app"
      Role = "k3s-web-app"
    }
  }
}

resource "aws_autoscaling_group" "web_app_worker_asg" {
  name                = "devops-experts-web-app-asg"
  vpc_zone_identifier = [aws_subnet.k3s_priv.id]
  desired_capacity    = 1
  min_size            = 1
  max_size            = 2

  target_group_arns = [aws_lb_target_group.web_app_tg.arn]

  launch_template {
    id      = aws_launch_template.web_app_worker_template.id
    version = "$Latest"
  }

  depends_on = [
    aws_route_table_association.devops_experts_k3s_priv_sub
  ]
}

resource "aws_autoscaling_policy" "web_app_cpu_policy" {
  name                      = "devops-experts-web-app-cpu-target-tracking"
  autoscaling_group_name    = aws_autoscaling_group.web_app_worker_asg.name
  policy_type               = "TargetTrackingScaling"
  estimated_instance_warmup = 180

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 70.0 # Target 70% CPU usage across the ASG
    disable_scale_in = true # Didn't add support in K3s cluster, yet
  }
}
