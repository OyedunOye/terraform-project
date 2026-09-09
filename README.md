# Terraform AWS EKS Infrastructure

Terraform configuration that provisions a VPC and an Amazon EKS cluster on AWS, ready for application deployment.

## Architecture

- **VPC** (`vpc.tf`) — built with the [`terraform-aws-modules/vpc/aws`](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest) module (`my-app-vpc`):
  - Public and private subnets spread across multiple availability zones
  - A single NAT gateway for private subnet egress
  - DNS hostnames enabled
  - Subnets tagged for Kubernetes / ELB discovery (`kubernetes.io/cluster/...`, `kubernetes.io/role/internal-elb`, `kubernetes.io/role/elb`)

- **EKS Cluster** (`eks-cluster.tf`) — built with the [`terraform-aws-modules/eks/aws`](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest) module (`my-app-eks-cluster`):
  - Runs in the VPC's private subnets
  - Kubernetes version `1.36`
  - Public API endpoint access enabled
  - Cluster creator granted admin access via cluster access entry
  - Managed node group `dev` (AL2023 x86_64) with configurable instance type, auto-scaling between 1 and 3 nodes (desired: 3)
  - Add-ons: `coredns`, `kube-proxy`, `vpc-cni`, `eks-pod-identity-agent`

- **Provider** (`providers.tf`) pins the AWS provider to `~> 6.59`.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads) (version compatible with the AWS provider `~> 6.59` and modules used here)
- An AWS account and credentials configured (e.g. via `aws configure`, environment variables, or an IAM role) with permissions to manage VPC, EC2, and EKS resources
- [`kubectl`](https://kubernetes.io/docs/tasks/tools/#kubectl) and the [AWS CLI](https://docs.aws.amazon.com/cli/) if you plan to interact with the cluster after it's created

## File structure

| File | Purpose |
|---|---|
| `providers.tf` | Terraform and provider version requirements |
| `vpc.tf` | VPC, subnets, and networking configuration |
| `eks-cluster.tf` | EKS cluster and managed node group configuration |
| `variables.tf` | Input variable declarations |
| `terraform.tfvars` | Variable values (gitignored, contains environment-specific config) |

## Variables

Defined in `variables.tf` and supplied via `terraform.tfvars`:

| Name | Type | Description |
|---|---|---|
| `vpc_cidr_block` | `string` | CIDR block for the VPC |
| `private_subnet_cidr_blocks` | `list(string)` | CIDR blocks for private subnets |
| `public_subnet_cidr_blocks` | `list(string)` | CIDR blocks for public subnets |
| `aws_availability_zones` | `list(string)` | Availability zones to spread subnets across |
| `instance_type` | `string` | EC2 instance type used by the EKS managed node group |

`terraform.tfvars` and `*.tfstate*` files are excluded from version control (see `.gitignore`) since they may contain sensitive or environment-specific data. Create your own `terraform.tfvars` before running Terraform, e.g.:

```hcl
vpc_cidr_block             = "10.0.0.0/16"
private_subnet_cidr_blocks = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
public_subnet_cidr_blocks  = ["10.0.6.0/24", "10.0.7.0/24", "10.0.8.0/24"]
aws_availability_zones     = ["us-east-1a", "us-east-1b", "us-east-1c"]
instance_type              = "t2.small"
```

## Usage

```bash
# Initialize Terraform and download providers/modules
terraform init

# Review the planned changes
terraform plan

# Apply the configuration
terraform apply

# Tear down the infrastructure when done
terraform destroy
```

After the cluster is created, configure `kubectl` access with:

```bash
aws eks update-kubeconfig --name my-app-eks-cluster --region <your-region>
```

## Notes

- The node group is sized for a development environment (`environment = "development"` tag). Adjust `min_size`/`max_size`/`desired_size` and `instance_type` for other environments.
