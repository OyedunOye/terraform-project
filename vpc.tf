provider "aws" {}

# data "aws_availability_zones" "azs" {}

module "my-app-vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.7.2"

  name = "my-app-vpc"
  cidr = var.vpc_cidr_block
  private_subnets = var.private_subnet_cidr_blocks
  public_subnets = var.public_subnet_cidr_blocks
  azs = var.aws_availability_zones

  enable_nat_gateway = true
  single_nat_gateway  = true
  enable_dns_hostnames = true

  tags ={
    "kubernetes.io/cluster/my-app-eks-cluster" = "shared"
  }
  private_subnet_tags ={
    "kubernetes.io/cluster/my-app-eks-cluster" = "shared"
    "kubernetes.io/role/internal-elb" = 1
  }
  public_subnet_tags ={
    "kubernetes.io/cluster/my-app-eks-cluster" = "shared"
    "kubernetes.io/role/elb" = 1
  }
}