resource "cloudflare_record" "this" {
  for_each = var.records

  zone_id = var.zone_id
  name    = each.value.name
  content = each.value.value
  type    = each.value.type
  ttl     = each.value.proxied ? 1 : each.value.ttl
  proxied = each.value.proxied
  comment = each.value.comment
}
