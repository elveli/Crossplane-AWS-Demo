# Terraform Backend Configuration for Remote State Management
# This stores Terraform state in AWS S3 with encryption and locking
#
# To use this backend:
# 1. Create an S3 bucket: aws s3api create-bucket --bucket crossplane-demo-tfstate-$(date +%s) --region us-east-1
# 2. Enable versioning: aws s3api put-bucket-versioning --bucket <bucket-name> --versioning-config Status=Enabled
# 3. Create DynamoDB table for state locking (see below)
# 4. Update the bucket name and region below
# 5. Run: terraform init

terraform {
  backend "s3" {
    bucket         = "crossplane-demo-tfstate"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}

# Optional: Create DynamoDB table for state locking with this command:
# aws dynamodb create-table \
#   --table-name terraform-locks \
#   --attribute-definitions AttributeName=LockID,AttributeType=S \
#   --key-schema AttributeName=LockID,KeyType=HASH \
#   --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
#   --region us-east-1
