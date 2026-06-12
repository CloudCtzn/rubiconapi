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

variable "rapidapi_secret" {
    description = "RapidAPI proxy secret for request validation"
    type = string
    sensitive = true
}
