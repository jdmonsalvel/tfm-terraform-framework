output "record_ids" {
  description = "Mapa nombre → ID del registro Cloudflare"
  value       = { for k, v in cloudflare_record.this : k => v.id }
}

output "record_hostnames" {
  description = "Mapa nombre → hostname FQDN resultante"
  value       = { for k, v in cloudflare_record.this : k => v.hostname }
}
