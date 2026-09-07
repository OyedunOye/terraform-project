terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.59"
    }
    # cloudinit {
    #   source = "hashicorp/cloudinit"
    #   version = "~>2.0"
    # },
    # null {
    #   source = "hashicorp/null"
    #   version = "~>3.0"
    # },
    # time {
    #   source = "hashicorp/time"
    #   version = "~>0.9"
    # },
    # tls {
    #   source = "hashicorp/tls"
    #   version = "~>4.0"
    # }
  }
}