locals {
  region             = var.region
  availability_zones = data.aws_availability_zones.available.names
}


variable "region" {
  description = "The AWS region to deploy resources in"
  type        = string
  default     = "us-east-1"
}
variable "Environment" {
  description = "The AWS region to deploy resources in"
  type        = string
  default     = "Dev"
}
variable "vpc_name" {
  description = "The name of the VPC"
  type        = string
  default     = "ai_magic"
}
variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  type        = string
  default     = "10.150.0.0/16"
}
variable "public_subnet_cidr" {
  description = "The CIDR block for the public subnet"
  type        = string
  default     = "10.150.1.0/24"
}
variable "private_subnet_cidr" {
  description = "The CIDR block for the private subnet"
  type        = string
  default     = "10.150.10.0/24"
}
variable "public_cidr" {
  description = "The public CIDR block for the VPC"
  type        = string
  default     = "0.0.0.0/0"
}

variable "public_ip" {
  description = "Whether to assign public IP addresses to instances in the public subnet"
  type        = bool
  default     = true
}

variable "private_ip" {
  description = "Whether to assign private IP addresses to instances in the private subnet"
  type        = bool
  default     = false
}
variable "embedding_model_arn" {
  description = "The ARN of the embedding model to use for generating vector embeddings"
  type        = string
  default     = "arn:aws:bedrock:us-east-1::foundation-model/amazon.titan-embed-text-v2:0"
}
variable "claude_model_arn" {
  description = "The ARN of the Claude model to use for generating responses"
  type        = string
  default     = "arn:aws:bedrock:us-east-1::foundation-model/amazon.nova-lite-v1:0"
}
variable "root_domain_name" {
  description = "The domain name"
  type        = string
  default     = "unshieldedhollow"
}
variable "registered_domain" {
  description = "The domain name"
  type        = string
  default     = "unshieldedhollow.click"
}
variable "certificate_validation_method" {
  description = "Turn on Domain"
  type        = string
  default     = "DNS"
}

data "aws_availability_zones" "available" {
  state = "available"
}
data "aws_caller_identity" "current" {}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
