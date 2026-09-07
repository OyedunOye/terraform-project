module "eks" {
    source  = "terraform-aws-modules/eks/aws"
    version = "21.25.0"

    name = "my-app-eks-cluster"
    kubernetes_version = "1.36"

    # references the output of 'my-app-vpc' from vpc.tf file
    subnet_ids = module.my-app-vpc.private_subnets
    vpc_id = module.my-app-vpc.vpc_id

    addons = {
        coredns                = {}
        eks-pod-identity-agent = {
            before_compute = true
        }
        kube-proxy             = {}
        vpc-cni                = {
            before_compute = true
        }
    }

    endpoint_public_access = true
    # Optional: Adds the current caller identity as an administrator via cluster access entry
    enable_cluster_creator_admin_permissions = true

    eks_managed_node_groups = {
        dev = {
            ami_type       = "AL2023_x86_64_STANDARD"
            instance_types = [var.instance_type]

            min_size     = 1
            max_size     = 3
            desired_size = 3
        }
    }

    tags = {
        environment = "development"
        application = "my-app"
    }
}

