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

# note how subnet_id is referenced here in the parent module. The output is from subnet child module. The syntax is module.name_given_to_module_in_parent_module.name_given_to_output_in_its_home_module.desired_property_of_the_output
module "my-app-server" {
    source = "./modules/webserver"
    vpc_id = aws_vpc.my-app-vpc.id
    my_ip_range = var.my_ip_range
    env_prefix = var.env_prefix
    ami_name = var.ami_name
    public_ssh_key_location = var.public_ssh_key_location
    instance_type = var.instance_type
    subnet_id = module.my-app-subnet.subnet.id
    avail_zone = var.avail_zone
    }