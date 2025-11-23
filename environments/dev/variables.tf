variable "project" {}
variable "region" {}
variable "vpc_cidr" {}
variable "public_subnets" {
  type = list(string)
}

variable "domain_name" {
  type = string
}

variable "hosted_zone_id" {
  type = string
}

variable "my_ip_cidr" {
  type = string
}

variable "private_subnets" {
  type = list(string)
}

