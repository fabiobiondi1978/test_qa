variable "Company" {
  description = "The Scope for tagging, example 'QA_POC'."
  type        = string
  default     = "QA"
}


variable "vpc_cidr" {
  description = "the CIDR of the VPC must be a /16"
  type        = string
  validation {
    condition     = cidrnetmask(var.vpc_cidr) == "255.255.0.0"
    error_message = "Not valid. The VPC CIDR must be a /16 network"
  }
}


variable "multi_az" {
  description = "Boolean value: write true if you want a subnet for each Availability Zone; Write false if you want a single Availability Zone with one subnet."
  type        = bool
}


variable "nat_gateway_provisioning" {
  description = "if 'single' = 1 NAT Gateway; if 'multi' = 1 NAT per each Availability Zones"
  type        = string
  validation {
    condition     = contains(["single", "multi"], var.nat_gateway_provisioning)
    error_message = "nat_gateway_provisioning accepted value must be 'single' or 'multi'."
  }
}


variable "tags" {
  description = "Additional tags to apply to all resources."
  type        = map(string)
  default     = { "Environmenr" = "POC", "Company" = "QA" }
}
