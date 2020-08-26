terraform {
  required_providers {

    aws = {
      source  = "hashicorp/aws"
      version = ">= 2.7.0"
    }

    tls = {
      source  = "hashicorp/tls"
      version = ">= 2.2"
    }

    template = {
      source  = "hashicorp/template"
      version = ">= 2.1.2"
    }
  }
}