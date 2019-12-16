module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "my-vpc"
  cidr = "10.66.0.0/16"
  enable_dns_hostnames = true

  azs             = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  private_subnets = ["10.66.1.0/24", "10.66.2.0/24", "10.66.3.0/24"]
  public_subnets = ["10.66.11.0/24"]

  enable_nat_gateway = false
  enable_vpn_gateway = false

  tags = {
    Terraform = "true"
    Environment = "devops"
  }
}