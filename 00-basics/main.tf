terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "lab_bucket" {
  bucket = "tf-lab-stephon-001"
}

output "bucket_name" {
  value = aws_s3_bucket.lab_bucket.bucket
}
