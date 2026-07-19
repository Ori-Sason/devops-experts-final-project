
variable "region" {
  type = string
}

variable "zone1" {
  type = string
}

variable "ubuntu_ami_id" {
  type = string
}

variable "devops_experts_vpc_id" {
  type = string
}

variable "devops_experts_nat_id" {
  type = string
}

variable "alb_sg_id" {
  type = string
}

variable "web_app_node_port" {
  type = number
}

variable "jenkins_sg_id" {
  type = string
}
