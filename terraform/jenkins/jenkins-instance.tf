resource "aws_instance" "jenkins_instance" {
  ami                    = var.t3_micro_ami_id
  instance_type          = "t3.medium" # FIX - minikube - if we need Minikube, it should be t3.large and maybe with more SSD
  subnet_id              = aws_subnet.jenkins_priv.id
  vpc_security_group_ids = [aws_security_group.jenkins_sg.id]

  iam_instance_profile = aws_iam_instance_profile.jenkins_profile.name

  # Enforce IMDSv2 token for metadata security
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  user_data = templatefile("${path.module}/scripts/ec2_provision.sh", {})

  tags = {
    Name = "devops-experts-jenkins"
  }
}

resource "aws_lb_target_group_attachment" "jenkins_attach" {
  target_group_arn = aws_lb_target_group.jenkins_tg.arn
  target_id        = aws_instance.jenkins_instance.id
  port             = 8080
}
