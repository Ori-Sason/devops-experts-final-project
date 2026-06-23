terraform {
  backend "s3" {
    bucket = "devops-experts-final-project"
    key    = "terraform/backend"
    region = "us-east-1"
  }
}
