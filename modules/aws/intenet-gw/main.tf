resource "aws_internet_gateway" "internet_gateway" {
  for_each = var.internet_gateways

  vpc_id = var.vpc_ids[each.value.vpc_name]

  tags = merge(
    var.tags,
    {
      Name = var.name_prefix != "" ? "${var.name_prefix}-${each.value.name}" : each.value.name
    }
  )
}
