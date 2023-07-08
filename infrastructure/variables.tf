variable "region" {
  description = "The AWS region to create resources in"
  default     = "eu-central-1"
}

variable "stage_name" {
  default = "prod"
  type    = string
}