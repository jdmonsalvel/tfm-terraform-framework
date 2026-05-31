variable "zone_id" {
  description = "Cloudflare Zone ID del dominio"
  type        = string
}

variable "records" {
  description = "Mapa de registros DNS a crear/gestionar"
  type = map(object({
    name    = string
    value   = string
    type    = string
    ttl     = optional(number, 1)
    proxied = optional(bool, false)
    comment = optional(string, "managed by terraform")
  }))
  default = {}
}
