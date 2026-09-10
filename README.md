# Terraform AWS EC2 Deployment (Modularized)

Terraform configuration that provisions a VPC, subnet/networking, and an EC2 instance on AWS, refactored into reusable child modules. The instance is bootstrapped via `user_data` to run Docker and serve an nginx container.

## Architecture

The root module (`main.tf`) creates the VPC and delegates networking and compute to two child modules:

- **VPC** — `aws_vpc.my-app-vpc`, created directly in the root module with a configurable CIDR block.

- **`modules/subnet`** - networking:
  - `aws_subnet.my-app-subnet-1` - subnet in the given VPC and availability zone
  - `aws_internet_gateway.my-app-igw` - internet gateway attached to the VPC
  - `aws_default_route_table.main-rtb` - the VPC's default route table, updated with a `0.0.0.0/0` route via the internet gateway
  - Outputs the created `subnet` resource for consumption by the root module

- **`modules/webserver`** — compute:
  - `aws_default_security_group.default-sg` - the VPC's default security group, allowing:
    - inbound SSH (port 22) from a configurable IP range
    - inbound TCP 8080 from anywhere (app traffic)
    - all outbound traffic
  - `data.aws_ami.latest-amazon-linux-image` - looks up an AMI by a configurable name filter (HVM virtualization)
  - `aws_key_pair.ssh-key` - registers an existing local SSH public key for instance access
  - `aws_instance.my-app-server` - the EC2 instance, launched into the subnet created by `modules/subnet`, bootstrapped via `entry-script.sh` (referenced relative to the root module's path)
  - Outputs the AMI ID and the instance's public IP

- **Bootstrap script** (`entry-script.sh`) - runs on instance launch (and re-runs if the script changes, via `user_data_replace_on_change`):
  - Installs and starts Docker
  - Adds `ec2-user` to the `docker` group
  - Runs an `nginx` container, mapping host port `8080` to container port `80`

- **Provider** (`providers.tf`) - pins the AWS provider to `~> 6.0`, declared in both the root module and each child module. AWS credentials/region are read from `~/.aws/credentials` (not configured in code).

## Module dependency flow

```
root (main.tf)
 ├─ aws_vpc.my-app-vpc
 ├─ module.my-app-subnet (modules/subnet)
 │    └─ outputs subnet ──────────────┐
 └─ module.my-app-server (modules/webserver)
      └─ consumes module.my-app-subnet.subnet.id
```

## Outputs

| Output | Source | Description |
|---|---|---|
| `server-public_ip` | root (`outputs.tf`) | Public IP of the EC2 instance, sourced from `modules/webserver` |
| `aws_ami_id` | `modules/webserver` | ID of the AMI used for the instance |
| `ec2-public_ip` | `modules/webserver` | Public IP address of the EC2 instance |

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads) compatible with the AWS provider `~> 6.0`
- An AWS account with credentials configured in `~/.aws/credentials` (or environment variables) and permissions to manage VPC, EC2, and related networking resources
- An existing local SSH key pair to use for instance access

## File structure

| Path | Purpose |
|---|---|
| `main.tf` | Root module: VPC resource, wiring of `subnet` and `webserver` modules |
| `variables.tf` | Root module input variable declarations |
| `outputs.tf` | Root module outputs |
| `providers.tf` | Root module Terraform/AWS provider requirements |
| `entry-script.sh` | Instance bootstrap script (installs Docker, runs nginx) |
| `modules/subnet/` | Child module: subnet, internet gateway, default route table |
| `modules/webserver/` | Child module: security group, AMI lookup, key pair, EC2 instance |
| `terraform.tfvars` | Variable values (gitignored - not committed, contains environment-specific config) |

## Variables

Declared in the root `variables.tf` and passed down into the child modules:

| Name | Description |
|---|---|
| `vpc_cidr_block` | CIDR block for the VPC |
| `subnet_cidr_block` | CIDR block for the subnet |
| `avail_zone` | Availability zone for the subnet and instance |
| `env_prefix` | Prefix used to name/tag resources (e.g. `dev`) |
| `my_ip_range` | CIDR range allowed to SSH into the instance (your IP) |
| `instance_type` | EC2 instance type |
| `public_ssh_key_location` | Path to your local SSH public key file |
| `ami_name` | AMI name filter used to look up the instance image |

`terraform.tfvars` and `*.tfstate*` files are excluded from version control (see `.gitignore`) since they may contain sensitive or environment-specific data. Create your own `terraform.tfvars` before running Terraform, e.g.:

```hcl
vpc_cidr_block           = "10.0.0.0/16"
subnet_cidr_block        = "10.0.1.0/24"
avail_zone               = "us-east-1a"
env_prefix               = "dev"
my_ip_range              = "<your-ip>/32"
instance_type            = "t2.micro"
public_ssh_key_location  = "~/.ssh/id_rsa.pub"
ami_name                 = "al2023-ami-2023*x86_64"
```

## Usage

```bash
# Initialize Terraform and download providers
terraform init

# Review the planned changes
terraform plan

# Apply the configuration
terraform apply

# Tear down the infrastructure when done
terraform destroy
```

Once applied, the nginx container is reachable at `http://<server-public_ip>:8080`, and the instance can be accessed via:

```bash
ssh ec2-user@<server-public_ip>
```

## Notes

- State is currently stored locally (`terraform.tfstate`); consider migrating to a remote backend (e.g. S3 + DynamoDB) for team use.
- The default security group allows inbound traffic on port 8080 from `0.0.0.0/0` — restrict this for anything beyond local testing.
- `modules/subnet/providers.tf` and `modules/webserver/providers.tf` are currently empty; the AWS provider is inherited from the root module.
