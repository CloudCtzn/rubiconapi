variable "aws_region" {
    description = "AWS region to deploy into"
    type = string 
    default = "us-east-1"
}

variable "environment" {
    description = "Deployment Environment"
    type = string
    default = "prod"
}

