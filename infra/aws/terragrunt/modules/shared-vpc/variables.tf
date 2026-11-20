variable "name_prefix" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "availability_zone_ids" {
  description = "Availability Zone IDs (e.g. use2-az1) to place private subnets in. Append only; reordering shifts subnet CIDRs."
  type        = list(string)

  validation {
    condition     = length(var.availability_zone_ids) > 0
    error_message = "Provide at least one Availability Zone ID."
  }
}

variable "ssm_prefix" {
  type = string
}

variable "publish_ssm_parameters" {
  type    = bool
  default = true
}
