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
    # REQUIRED: Update these values before using
    bucket         = "crossplane-demo-tfstate-REPLACE-WITH-UNIQUE-ID"  # Must be globally unique
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    
    # Security & State Management
    encrypt        = true                           # Enable encryption at rest
    dynamodb_table = "terraform-locks"              # Table for state locking (prevents concurrent applies)
  }
}

# Optional: Create DynamoDB table for state locking with this command:
# aws dynamodb create-table \
#   --table-name terraform-locks \
#   --attribute-definitions AttributeName=LockID,AttributeType=S \
#   --key-schema AttributeName=LockID,KeyType=HASH \
#   --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
#   --region us-east-1
