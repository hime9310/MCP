terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    # ✏️ 以下の値を環境に合わせて変更してください
    bucket = "REPLACE_ME_TFSTATE_BUCKET_NAME"
    key    = "terraform-mcp-server/terraform.tfstate"
    region = "REPLACE_ME_AWS_REGION" # 例: ap-northeast-1
  }
}
