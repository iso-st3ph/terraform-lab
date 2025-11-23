terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      
    }
  }
    backend "s3" {
    bucket         = "tf-state-ayoskip-lab"     # <-- from output
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tf-state-locks-ayoskip"   # <-- from output
    encrypt        = true
  }

}

provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "tf_state" {
  bucket = "tf-state-ayoskip-lab"  # <-- must be globally unique
}

resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.tf_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "enc" {
  bucket = aws_s3_bucket.tf_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_dynamodb_table" "tf_locks" {
  name         = "tf-state-locks-ayoskip"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

output "bucket_name" {
  value = aws_s3_bucket.tf_state.bucket
}

output "dynamodb_table" {
  value = aws_dynamodb_table.tf_locks.name
}
