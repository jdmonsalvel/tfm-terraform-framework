variable "vpc_ids" {
  type = map(string)
}

variable "tags" {
  type    = map(string)
  default = {}
}
variable "internet_gateways" {
  type = map(object({
    name     = string
    vpc_name = string
    tags     = optional(map(string))
  }))
}
variable "name_prefix" {
  description = "Prefix applied to resource names: project-environment"
  type        = string
  default     = ""
}
