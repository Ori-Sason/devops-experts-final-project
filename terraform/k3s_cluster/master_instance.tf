resource "aws_instance" "k3s_master" {
  ami                    = var.ubuntu_ami_id
  instance_type          = "t3.small"
  subnet_id              = aws_route_table_association.devops_experts_k3s_priv_sub.subnet_id # Making sure NAT GW is available before creating the instance
  iam_instance_profile   = aws_iam_instance_profile.k3s_master_profile.name
  vpc_security_group_ids = [aws_security_group.k3s_master_sg.id]

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2 # Allows ESO pods/containers to reach IMDS
  }

  user_data = templatefile("${path.module}/scripts/master_provision.sh", {
    aws_region = var.region
  })

  tags = {
    Name = "devops-experts-k3s-master"
    Role = "k3s-master" # Worker nodes use this specific tag value to lookup the Private IP on boot
  }
}
