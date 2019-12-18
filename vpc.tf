module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "my-vpc"
  cidr = "10.66.0.0/16"
  enable_dns_hostnames = true

  azs             = [data.aws_availability_zones.available.names[0], data.aws_availability_zones.available.names[1], data.aws_availability_zones.available.names[2]]
  private_subnets = ["10.66.1.0/24", "10.66.2.0/24", "10.66.3.0/24"]
  public_subnets = ["10.66.11.0/24"]

  enable_nat_gateway = false
  enable_vpn_gateway = false

  tags = {
    Terraform = "true"
    Environment = "devops"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}