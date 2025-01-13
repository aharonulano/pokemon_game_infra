variable "account" {
  description = "(Required) account ID"
  type        = string
}

variable "profile_name" {
  description = "(Required) profile name"
  type        = string
  default     = "au-test"
}

variable "aws_region" {
  type    = string
  default = "eu-west-1"
}

