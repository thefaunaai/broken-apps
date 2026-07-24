data "aws_route53_zone" "selected" {
  name         = local.hosted_zone_name
  private_zone = false
}

resource "aws_acm_certificate" "gatehouse" {
  domain_name       = local.hostname
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true

    precondition {
      condition     = local.hostname == local.hosted_zone_name || endswith(local.hostname, ".${local.hosted_zone_name}")
      error_message = "hostname must belong to hosted_zone_name."
    }
  }
}

resource "aws_route53_record" "certificate_validation" {
  for_each = {
    for option in aws_acm_certificate.gatehouse.domain_validation_options :
    option.domain_name => {
      name   = option.resource_record_name
      record = option.resource_record_value
      type   = option.resource_record_type
    }
  }

  zone_id = data.aws_route53_zone.selected.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "gatehouse" {
  certificate_arn = aws_acm_certificate.gatehouse.arn
  validation_record_fqdns = [
    for record in aws_route53_record.certificate_validation : record.fqdn
  ]
}

resource "aws_route53_record" "gatehouse" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = local.hostname
  type    = "A"

  alias {
    name                   = aws_lb.gatehouse.dns_name
    zone_id                = aws_lb.gatehouse.zone_id
    evaluate_target_health = true
  }
}
