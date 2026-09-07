# creates subnet in newly created vpc. vpc and subnet are being created in the same plan. This apply command also generates a route table
resource "aws_subnet" "my-app-subnet-1" {
    vpc_id            = var.vpc_id
    cidr_block        = var.subnet_cidr_block
    availability_zone = var.avail_zone
    tags = {
        Name: "${var.env_prefix}-subnet-1"
    }
}

# creates an internet gateway that is associated to the external route in default created route table
resource "aws_internet_gateway" "my-app-igw" {
    vpc_id = var.vpc_id
    tags = {
        Name: "${var.env_prefix}-igw"
  }
}

# instead of creating another route table, use the default created on vpc creation and add igw to it
resource "aws_default_route_table" "main-rtb" {
    default_route_table_id = var.default_route_table_id

    route {
        cidr_block = "0.0.0.0/0"
        # since the `aws_internet_gateway is configured in this same module, we can get its id like below, variable not needed for this
        gateway_id = aws_internet_gateway.my-app-igw.id
    }

    tags = {
        Name: "${var.env_prefix}-main-rtb"
    }
}
