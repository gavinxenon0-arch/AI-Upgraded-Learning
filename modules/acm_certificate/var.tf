variable "certificate_validation_method" {
  description = "This is the domain name for your route 53"
  type        = string
  default     = "DNS"
}

variable "domain_name" {
  description = "This is for the domain name"
  type        = string
}
variable "zone" {
  description = "This is for the zone id for the hosted zone"
  type        = string
}
variable "tags" {
  description = "Tags for the environment"
  type        = string
}
