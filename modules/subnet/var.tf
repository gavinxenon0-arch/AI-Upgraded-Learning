variable "name" {
  description = "Name prefix for the subnet"
  type        = string
}
variable "vpc_id" {
  description = "The VPC ID for the subnet"
  type        = string
}
variable "cidr_block" {
  description = "CIDR block for the subnet"
  type        = string
}
variable "availability_zone" {
  description = "The availability zone for the subnet"
  type        = string
}
variable "ip" {
  description = "Whether to associate public IP address with subnet"
  type        = bool
}
variable "tags" {
  description = "Extra tags to apply to all resources"
  type        = map(string)
  default     = {}
}
