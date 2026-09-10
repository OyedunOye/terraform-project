# Provisioning AWS Resources with Terraform - Infrastructure as Code (IaC)
IaC is simply scripting the creation and configuration of infrastructure. Terraform is a declarative popular IaC tool that helps to automate and keep track of all existing resources. It promotes easy reproduction of infrastructure. This project focuses on creation of a vpc, a subnet, necessary networking needed for an ec2 instance to be reachable from outside the vpc via an internet gateway. List of resources created as code:
- a vpc
- a subnet
- an internet gateway
- configuration of default route table adding internet gateway to the local route created by default
- configure default security group to open port 22 for ssh access to ec2 instance that will live within the subnet, and also port 8080 to access app to be deployed on ec2 instance
- configure locally created ssh key pair for accessing the ec2 instance
- an ec2 instance, using data attribute to pull instance image directly from aws

The configuration has been parameterized to make it highly resuable and hide away sensitive variables in variables.tfvars. Therefore, entirely different parameters could be used to create similar but different group of resources.

For terraform to communicate with aws and create the declared resources to work, providers config in providers.tf.

## Relevant Terraform Commands Used in The project

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

## Project Structure
terraform-project/
├── .gitignore
├── .terraform.lock.hcl
├── terraform.tfvars
├── README.md
├── main.tf
└── providers.tf


## Branches in This Project
- feature/deploy-to-ec2-default-components: includes a script that runs on ec2 instance on its creation to install docker and run a docker container.
- feature/provisioners: explore how provisioners are used to configure provisioned servers
- feature/modules: explore organizing of my infrastructure code into related groups called modules
- feature/eks: explores provisioning of a full eks cluster using existing modules from terraform registry.


