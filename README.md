# Terraform AWS EC2 Deployment (Provisioners)

Terraform configuration that provisions a VPC and a single EC2 instance on AWS, and demonstrates using `connection` + `provisioner` blocks to interact with the instance after it's created, alongside the existing `user_data` bootstrap.

## Architecture

Defined in `main.tf`:

- **VPC & networking**
  - `aws_vpc.my-app-vpc` - a VPC with a configurable CIDR block
  - `aws_subnet.my-app-subnet-1` - a single subnet in a configurable availability zone
  - `aws_internet_gateway.my-app-igw` - internet gateway attached to the VPC
  - `aws_default_route_table.main-rtb` - the VPC's default route table, updated with a `0.0.0.0/0` route via the internet gateway
  - `aws_default_security_group.default-sg` - the VPC's default security group, allowing:
    - inbound SSH (port 22) from a configurable IP range
    - inbound TCP 8080 from anywhere (app traffic)
    - all outbound traffic

- **Compute**
  - `data.aws_ami.latest-amazon-linux-image` - looks up the latest Amazon Linux 2023 (x86_64, HVM) AMI
  - `aws_key_pair.ssh-key` - registers an existing local SSH public key for instance access
  - `aws_instance.my-app-server` - the EC2 instance, launched with a public IP and bootstrapped via `entry-script.sh` through `user_data`

- **Provisioners** - on top of the `user_data` bootstrap, the instance resource defines a post-creation SSH workflow:
  - `connection` block - opens an SSH connection to the instance's public IP as `ec2-user`, authenticating with a configurable private key
  - `provisioner "file"` - copies `entry-script.sh` from the local machine to `/home/ec2-user/entry-script-on-ec2.sh` on the instance
  - `provisioner "remote-exec"` - runs the copied script on the instance over the SSH connection
  - A `provisioner "local-exec"` that wrote the instance's public IP to a local `output.txt` was removed (left commented out in `main.tf`) — that file was never actually read after being generated, so it was just unnecessary clutter on whatever machine ran `apply`.

  > These provisioners are illustrative: the `entry-script.sh` logic already runs once via `user_data`, so the `file`/`remote-exec` pair effectively re-runs the same bootstrap steps a second time, over SSH, after boot.

- **Bootstrap script** (`entry-script.sh`) - runs on instance launch (and re-runs if the script changes, via `user_data_replace_on_change`), and is also copied/re-executed remotely by the provisioners above:
  - Installs and starts Docker
  - Adds `ec2-user` to the `docker` group
  - Runs an `nginx` container, mapping host port `8080` to container port `80`

- **Provider** (`providers.tf`) - pins the AWS provider to `~> 6.0`. AWS credentials/region are read from `~/.aws/credentials` (not configured in code).

## Outputs

| Output | Description |
|---|---|
| `aws_ami_id` | ID of the AMI used for the instance |
| `ec2-public_ip` | Public IP address of the EC2 instance |

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads) compatible with the AWS provider `~> 6.0`
- An AWS account with credentials configured in `~/.aws/credentials` (or environment variables) and permissions to manage VPC, EC2, and related networking resources
- An existing local SSH key pair (public **and** private key) — the private key must be reachable by Terraform to open the provisioner's SSH connection, and the instance's security group must allow inbound SSH from the machine running `terraform apply`

## File structure

| File | Purpose |
|---|---|
| `main.tf` | VPC, networking, security group, AMI lookup, key pair, EC2 instance, and provisioners |
| `providers.tf` | Terraform and AWS provider version requirements |
| `entry-script.sh` | Bootstrap script (installs Docker, runs nginx) — used both by `user_data` and by the `file`/`remote-exec` provisioners |
| `terraform.tfvars` | Variable values (gitignored — not committed, contains environment-specific config) |

## Variables

Declared in `main.tf` and supplied via `terraform.tfvars`:

| Name | Description |
|---|---|
| `vpc_cidr_block` | CIDR block for the VPC |
| `subnet_cidr_block` | CIDR block for the subnet |
| `avail_zone` | Availability zone for the subnet and instance |
| `env_prefix` | Prefix used to name/tag resources (e.g. `dev`) |
| `my_ip_range` | CIDR range allowed to SSH into the instance (your IP) |
| `instance_type` | EC2 instance type |
| `public_ssh_key_location` | Path to your local SSH public key file (registered as the instance's key pair) |
| `private_ssh_key_location` | Path to your local SSH private key file (used by the `connection` block for provisioners) |

`terraform.tfvars` and `*.tfstate*` files are excluded from version control (see `.gitignore`) since they may contain sensitive or environment-specific data. Create your own `terraform.tfvars` before running Terraform, e.g.:

```hcl
vpc_cidr_block            = "10.0.0.0/16"
subnet_cidr_block         = "10.0.1.0/24"
avail_zone                = "us-east-1a"
env_prefix                = "dev"
my_ip_range               = "<your-ip>/32"
instance_type             = "t2.micro"
public_ssh_key_location   = "~/.ssh/id_rsa.pub"
private_ssh_key_location  = "~/.ssh/id_rsa"
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

During `apply`, Terraform will wait for SSH to become available on the instance before running the `file` and `remote-exec` provisioners. This can add noticeable time to the apply compared to `user_data`-only setups. Once applied:

- The nginx container is reachable at `http://<ec2-public_ip>:8080`
- The instance can be accessed via `ssh ec2-user@<ec2-public_ip>`

## Notes

- Provisioners are a Terraform "last resort" per HashiCorp's own guidance — they aren't tracked in state the way resources are, and failures can leave the instance created but the provisioner step incomplete. Prefer `user_data`, custom AMIs (e.g. via Packer), or a configuration management tool where possible.
