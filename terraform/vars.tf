variable "region" {
  default = "us-east-1"
}

variable "zone1" {
  default = "us-east-1a"
}

variable "zone2" {
  default = "us-east-1b"
}

variable "ubuntu_ami_id" {
  default = "ami-0b6d9d3d33ba97d99"
}

variable "web_app_node_port" {
  default = 32080
}

variable "db_username" {
  type        = string
  description = "Database administrator username"
  sensitive   = true
}

variable "db_password" {
  type        = string
  description = "Database administrator password"
  sensitive   = true
}
