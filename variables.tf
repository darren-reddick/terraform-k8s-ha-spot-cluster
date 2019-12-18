variable "ami_nat" {
    default = "ami-024107e3e3217a248"
}

variable "stackname" {
    default = "k8s-ha-recovery"
}

variable "k8s_version" {
    default = "1.15.7"
}

variable "key_name" {
    default = "ha-key"
}

variable "my_public_ip" {
    default = "212.139.189.130/32"
}

data "aws_ami" "nat" {
  most_recent      = true
  name_regex       = "amzn-ami-vpc-nat-hvm-2018*"
  owners           = ["amazon"]

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}



data "aws_ami" "centos" {
  most_recent      = true
  name_regex       = "CentOS Linux 7 x86_64 HVM EBS ENA 1901_01*"
  owners           = ["aws-marketplace"]

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
