# region, access_key and secret_key were configured in ~/.aws/credentials file
provider "aws" {}

variable "vpc_cidr_block" {}
variable "subnet_cidr_block" {}
variable "avail_zone" {}
variable "env_prefix" {}
variable "my_ip_range" {}
variable "instance_type" {}
variable "public_ssh_key_location" {}
variable "private_ssh_key_location" {}

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

# creates an internet gateway that is associated to the external route in default created route table
resource "aws_internet_gateway" "my-app-igw" {
    vpc_id = aws_vpc.my-app-vpc.id
    tags = {
        Name: "${var.env_prefix}-igw"
  }
}

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

output "aws_ami_id" {
    value = data.aws_ami.latest-amazon-linux-image.id
}

# using an existing ssh key pair on my computer
resource "aws_key_pair" "ssh-key" {
    key_name = "server-key"
    public_key = file(var.public_ssh_key_location)

}

resource "aws_instance" "my-app-server" {
    ami = data.aws_ami.latest-amazon-linux-image.id
    instance_type = var.instance_type
    subnet_id = aws_subnet.my-app-subnet-1.id
    vpc_security_group_ids = [aws_default_security_group.default-sg.id]
    availability_zone = var.avail_zone

    associate_public_ip_address = true
    key_name = aws_key_pair.ssh-key.key_name

    # runs bash commands on the server once, only on server creation
    user_data = file("entry-script.sh")

    # forces recreation of server, and in-turn re-run of entry point shell cmds that run once on server creation
    user_data_replace_on_change = true

    # creates ssh login to server so that provisioners can run on the server after server provisioning
    connection {
        type = "ssh"
        host = self.public_ip
        user = "ec2-user"
        private_key = file(var.private_ssh_key_location)
    }

    # copy files or directories from local to newly created resource
    provisioner "file" {
        source = "entry-script.sh"
        destination = "/home/ec2-user/entry-script-on-ec2.sh"
    }

    # connects to a remote resource (using connection) and invokes script on it. Note that the execution is inside the instance, therefore, the file to be executed must be on the provisioned server!
    provisioner "remote-exec" {
        inline = ["/home/ec2-user/entry-script-on-ec2.sh"]
        # a cleaner way to execute a script remotely on provisioned server is using script attribute as follows. In this case, we won't need the provisioner "file" block because script copies and executes file in a single command
        # inline = "entry-script.sh"
    }

    # j
    provisioner "local-exec" {
        command = "echo ${self.public_ip} > output.txt"
    }

    tags = {
        Name: "${var.env_prefix}-server"
    }
}

output "ec2-public_ip" {
  value = aws_instance.my-app-server.public_ip
}
