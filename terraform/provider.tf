provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project = "devops-experts-final-project"
    }
  }
}
