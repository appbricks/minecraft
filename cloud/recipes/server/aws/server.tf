#
# Minecraft Instance
#

resource "aws_instance" "minecraft" {

  instance_type = var.minecraft_instance_type
  ami           = data.aws_ami.ubuntu.id
  key_name      = var.cb_default_ssh_key_pair
  subnet_id     = data.aws_subnet.deployment.id

  vpc_security_group_ids = [var.cb_deployment_security_group]

  iam_instance_profile = aws_iam_instance_profile.minecraft.id

  tags = {
    Name = "${var.cb_vpc_name}: ${var.name} server"
  }

  user_data_base64 = module.app-config.app_cloud_init_config
}

#
# IAM Role for Minecraft server
#

resource "aws_iam_role" "minecraft" {
  name   = "${var.cb_vpc_name}-${var.name}"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "minecraft" {
  name = "${var.cb_vpc_name}-${var.name}"
  role = aws_iam_role.minecraft.name
}

#
# Ubuntu AMI
#

locals {
  ami_arch = startswith(var.minecraft_instance_type, "t4g.") ? "arm64" : "amd64"
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-${local.ami_arch}-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}
