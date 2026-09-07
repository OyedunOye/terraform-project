output "aws_ami_id" {
    value = data.aws_ami.latest-amazon-linux-image.id
}

output "ec2-public_ip" {
  value = aws_instance.my-app-server.public_ip
}
