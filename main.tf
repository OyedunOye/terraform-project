# region, access_key and secret_key were configured in ~/.aws/credentials file
provider "aws" {}

resource "aws_vpc" "my-app-vpc" {
  cidr_block = var.vpc_cidr_block
  tags = {
    Name: "${var.env_prefix}-vpc"
  }
}

# use the subnet module, note that where we used `.var` to pull variable values, the variables must be defined in variables.tf of both the module and the root directory.
module "my-app-subnet" {
    source = "./modules/subnet"
    subnet_cidr_block = var.subnet_cidr_block
    avail_zone = var.avail_zone
    env_prefix = var.avail_zone
    vpc_id = aws_vpc.my-app-vpc.id
    default_route_table_id = aws_vpc.my-app-vpc.default_route_table_id
}

# this is where incoming (ingress) and outgoing (egress) traffic via ports are defined for server instance level. This modifies the default sg in the current vpc
resource "aws_default_security_group" "default-sg" {
    vpc_id = aws_vpc.my-app-vpc.id

    ingress {
        from_port = 22
        to_port = 22
        protocol = "TCP"
        cidr_blocks = [var.my_ip_range]
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
        Name: "${var.env_prefix}-default-sg"
    }
}

data "aws_ami" "latest-amazon-linux-image" {
    most_recent = true
    owners = ["amazon"]
    filter {
        name = "name"
        values = ["al2023-ami-2023*x86_64"]
    }

    filter {
        name = "virtualization-type"
        values = ["hvm"]
    }
}

# using an existing ssh key pair on my computer
resource "aws_key_pair" "ssh-key" {
    key_name = "server-key"
    public_key = file(var.public_ssh_key_location)

}

# note how subnet_id references the output from child module: module.name_given_to_module_in_this_parent_module.output_name_in_child_module.id
resource "aws_instance" "my-app-server" {
    ami = data.aws_ami.latest-amazon-linux-image.id
    instance_type = var.instance_type
    subnet_id = module.my-app-subnet.subnet.id
    vpc_security_group_ids = [aws_default_security_group.default-sg.id]
    availability_zone = var.avail_zone

    associate_public_ip_address = true
    key_name = aws_key_pair.ssh-key.key_name

    user_data = file("entry-script.sh")

    user_data_replace_on_change = true
    tags = {
        Name: "${var.env_prefix}-server"
    }
}
