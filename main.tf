provider "aws" {
  region  = var.aws_region
  version = "~> 2.70"
}

provider "tls" {
  version = "~> 2.2"
}

provider "template" {
  version = "~> 2.1.2"
}
