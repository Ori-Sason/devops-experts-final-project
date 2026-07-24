# K3S MASTER
resource "aws_security_group" "k3s_master_sg" {
  name        = "devops-experts-k3s-master-sg"
  description = "Security Group for K3s Master Control Plane Node"
  vpc_id      = var.devops_experts_vpc_id

  tags = {
    Name = "devops-experts-k3s-master-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "master_api_from_jenkins" {
  description                  = "API/kubectl requests from Jenkins SG"
  security_group_id            = aws_security_group.k3s_master_sg.id
  referenced_security_group_id = var.jenkins_sg_id
  from_port                    = 6443
  to_port                      = 6443
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "master_api_from_web_workers" {
  description                  = "API requests from Web-App workers to join/communicate (6443)"
  security_group_id            = aws_security_group.k3s_master_sg.id
  referenced_security_group_id = aws_security_group.k3s_web_app_sg.id
  from_port                    = 6443
  to_port                      = 6443
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "master_api_from_monitoring" {
  description                  = "API requests from Monitoring worker to join/communicate (6443)"
  security_group_id            = aws_security_group.k3s_master_sg.id
  referenced_security_group_id = aws_security_group.k3s_monitoring_sg.id
  from_port                    = 6443
  to_port                      = 6443
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "master_vxlan_from_web_workers" {
  description                  = "K3s VXLAN from master node"
  security_group_id            = aws_security_group.k3s_master_sg.id
  referenced_security_group_id = aws_security_group.k3s_web_app_sg.id
  from_port                    = 8472
  to_port                      = 8472
  ip_protocol                  = "udp"
}

resource "aws_vpc_security_group_ingress_rule" "master_vxlan_from_monitoring" {
  description                  = "K3s VXLAN from monitoring node"
  security_group_id            = aws_security_group.k3s_master_sg.id
  referenced_security_group_id = aws_security_group.k3s_monitoring_sg.id
  from_port                    = 8472
  to_port                      = 8472
  ip_protocol                  = "udp"
}

resource "aws_vpc_security_group_egress_rule" "master_outbound_all" {
  description       = "Full internet access for updates and contacting SSM"
  security_group_id = aws_security_group.k3s_master_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}


# WEB-APP WORKERS
resource "aws_security_group" "k3s_web_app_sg" {
  name        = "devops-experts-k3s-web-app-sg"
  description = "Security Group for K3s Web-App Auto Scaled Workers"
  vpc_id      = var.devops_experts_vpc_id

  tags = {
    Name = "devops-experts-k3s-web-app-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "web_worker_http_from_alb" {
  description                  = "HTTP traffic forwarded from the ALB SG"
  security_group_id            = aws_security_group.k3s_web_app_sg.id
  referenced_security_group_id = var.alb_sg_id
  from_port                    = var.web_app_node_port
  to_port                      = var.web_app_node_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "web_worker_kubelet_from_master" {
  description                  = "Kubelet metrics scraping from master SG"
  security_group_id            = aws_security_group.k3s_web_app_sg.id
  referenced_security_group_id = aws_security_group.k3s_master_sg.id
  from_port                    = 10250
  to_port                      = 10250
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "web_worker_vxlan_from_master" {
  description                  = "Flannel VXLAN overlay traffic from master SG"
  security_group_id            = aws_security_group.k3s_web_app_sg.id
  referenced_security_group_id = aws_security_group.k3s_master_sg.id
  from_port                    = 8472
  to_port                      = 8472
  ip_protocol                  = "udp"
}

resource "aws_vpc_security_group_ingress_rule" "web_worker_vxlan_from_self" {
  description                  = "Flannel VXLAN overlay traffic from other web-app workers"
  security_group_id            = aws_security_group.k3s_web_app_sg.id
  referenced_security_group_id = aws_security_group.k3s_web_app_sg.id
  from_port                    = 8472
  to_port                      = 8472
  ip_protocol                  = "udp"
}

resource "aws_vpc_security_group_ingress_rule" "web_worker_vxlan_from_monitoring" {
  description                  = "Flannel VXLAN overlay traffic from Monitoring SG"
  security_group_id            = aws_security_group.k3s_web_app_sg.id
  referenced_security_group_id = aws_security_group.k3s_monitoring_sg.id
  from_port                    = 8472
  to_port                      = 8472
  ip_protocol                  = "udp"
}

resource "aws_vpc_security_group_egress_rule" "web_worker_outbound_all" {
  description       = "Full internet access for updates and pulling container images"
  security_group_id = aws_security_group.k3s_web_app_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

output "k3s_web_app_nodes_sg_id" {
  description = "K3s web-app SG ID - used in RDS SG"
  value       = aws_security_group.k3s_web_app_sg.id
}


# K3S MONITORING
resource "aws_security_group" "k3s_monitoring_sg" {
  name        = "devops-experts-k3s-monitoring-sg"
  description = "Security Group for Dedicated K3s Monitoring Instance"
  vpc_id      = var.devops_experts_vpc_id

  tags = {
    Name = "devops-experts-k3s-monitoring-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "monitoring_kubelet_from_master" {
  description                  = "Kubelet metrics scraping from master SG"
  security_group_id            = aws_security_group.k3s_monitoring_sg.id
  referenced_security_group_id = aws_security_group.k3s_master_sg.id
  from_port                    = 10250
  to_port                      = 10250
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "monitoring_vxlan_from_master" {
  description                  = "Flannel VXLAN overlay traffic from Master SG"
  security_group_id            = aws_security_group.k3s_monitoring_sg.id
  referenced_security_group_id = aws_security_group.k3s_master_sg.id
  from_port                    = 8472
  to_port                      = 8472
  ip_protocol                  = "udp"
}

resource "aws_vpc_security_group_ingress_rule" "monitoring_vxlan_from_web_workers" {
  description                  = "Flannel VXLAN overlay traffic from Web-App workers"
  security_group_id            = aws_security_group.k3s_monitoring_sg.id
  referenced_security_group_id = aws_security_group.k3s_web_app_sg.id
  from_port                    = 8472
  to_port                      = 8472
  ip_protocol                  = "udp"
}

resource "aws_vpc_security_group_egress_rule" "monitoring_outbound_all" {
  security_group_id = aws_security_group.k3s_monitoring_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
