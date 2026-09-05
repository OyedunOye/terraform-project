# region, access_key and secret_key were configured in ~/.aws/credentials file
provider "aws" {}

variable "vpc_cidr_block" {}
variable "subnet_cidr_block" {}
variable "avail_zone" {}
variable "env_prefix" {}
variable "my_ip_range" {}

resource "aws_vpc" "my-app-vpc" {
  cidr_block = var.vpc_cidr_block
  tags = {
    Name: "${var.env_prefix}-vpc"
  }
}

# creates subnet in newly created vpc. vpc and subnet are being created in the same plan. This apply command also generates a route table
resource "aws_subnet" "my-app-subnet-1" {
    vpc_id            = aws_vpc.my-app-vpc.id
    cidr_block        = var.subnet_cidr_block
    availability_zone = var.avail_zone
    tags = {
        Name: "${var.env_prefix}-subnet-1"
    }
}

# explicit creation of another route table which will not only have the local auto created route, but also the internet gateway route for internet access to the vpc
# resource "aws_route_table" "my-app-route-table" {
#     vpc_id = aws_vpc.my-app-vpc.id
#     route {
#         cidr_block = "0.0.0.0/0"
#         gateway_id = aws_internet_gateway.my-app-igw.id
#     }

#     tags = {
#         Name: "${var.env_prefix}-rtb"
#     }
# }

# creates an internet gateway that is associated to the external route in explicitly created route table
resource "aws_internet_gateway" "my-app-igw" {
    vpc_id = aws_vpc.my-app-vpc.id

}

# links route table to the created subnet, must be defined explicitly only for route table which is not main
# resource "aws_route_table_association" "a-rtb-subnet" {
#     subnet_id = aws_subnet.my-app-subnet-1.id
#     route_table_id = aws_route_table.my-app-route-table.id
# }

# instead of creating another route table, use the default created on vpc creation and add igw to it
resource "aws_default_route_table" "main-rtb" {
    default_route_table_id = aws_vpc.my-app-vpc.default_route_table_id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.my-app-igw.id
    }

    tags = {
        Name: "${var.env_prefix}-main-rtb"
    }
}

# this is where incoming (ingress) and outgoing (egress) traffic via ports are defined for server instance level.
resource "aws_security_group" "my-app-sg" {
    name = "my-app-sg"
    vpc_id = aws_vpc.my-app-vpc.id

    ingress {
        from_port = 22
        to_port = 22
        protocol = "TCP"
        cidr_blocks = var.my_ip_range
    }

    ingress {
        from_port = 8080
        to_port = 8080
        protocol = "TCP"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
        prefix_list_ids = []
    }

    tags = {
        Name: "${var.env_prefix}-sg"
    }
}

# define output in one per output block as follows
# output "my-dev-subnet-id" {
#     value = aws_subnet.my-app-subnet-1.id
# }

# output "my-dev-vpc-id" {
#     value = aws_vpc.my-app-vpc.id
# }