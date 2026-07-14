resource "aws_ebs_volume" "jenkins_docker_data" {
  availability_zone = aws_subnet.jenkins_priv.availability_zone
  size              = 20
  type              = "gp3"

  tags = {
    Name = "devops-experts-jenkins-docker-storage"
  }
}

resource "aws_volume_attachment" "jenkins_ebs_attach" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.jenkins_docker_data.id
  instance_id = aws_instance.jenkins_instance.id

  skip_destroy = true
}
