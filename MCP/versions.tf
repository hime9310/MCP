terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "REPLACE_ME_TFSTATE_BUCKET_NAME"
    key    = "cms-eng-kiro/dev/terraform.tfstate"
    region = "ap-northeast-1"
  }
}
