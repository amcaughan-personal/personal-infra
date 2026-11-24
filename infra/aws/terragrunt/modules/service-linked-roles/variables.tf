variable "services" {
  description = "Service principals to create a service-linked role for, e.g. spot.amazonaws.com."
  type        = list(string)
}
