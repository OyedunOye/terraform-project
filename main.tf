# region, access_key and secret_key were configured in ~/.aws/credentials file
provider "aws" {}

variable "vpc_cidr_block" {}
variable "subnet_cidr_block" {}
variable avail_zone {}
variable "env_prefix" {}

resource "aws_vpc" "my-app-vpc" {
  cidr_block = vpc_cidr_block
  tags = {
    Name: "${var.env_prefix}-vpc"
  }
}

# creates subnet in newly created vpc. vpc and subnet are being created in the same plan
resource "aws_subnet" "my-app-subnet-1" {
    vpc_id            = aws_vpc.my-app-vpc.id
    cidr_block        = var.subnet_cidr_blocks
    availability_zone = var.avail_zone
    tags = {
        Name: "${var.env_prefix}-subnet-1"
    }
}

# define output in one per output block as follows
output "my-dev-subnet-id" {
    value = aws_subnet.my-app-subnet-1.id
}

output "my-dev-vpc-id" {
    value = aws_vpc.my-app-vpc.id
}