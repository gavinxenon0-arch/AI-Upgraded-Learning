resource "aws_acm_certificate" "hidden_target_group2" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  tags = {
    Name = var.tags
  }
}
# Create DNS validation records for all domains in the cert (domain + SANs)
resource "aws_route53_record" "cert_validation" {
  for_each = (
    var.certificate_validation_method == "DNS" &&
    length(aws_acm_certificate.hidden_target_group2.domain_validation_options) > 0
    ) ? {
    for dvo in aws_acm_certificate.hidden_target_group2.domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  } : {}

  zone_id = var.zone
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]


  # Helps when re-issuing certs (ACM can reuse/replace validation records)
  allow_overwrite = true

}
# This resource tells ACM to check DNS and finish validation
resource "aws_acm_certificate_validation" "hidden_target_group2" {
  certificate_arn = aws_acm_certificate.hidden_target_group2.arn

  validation_record_fqdns = [
    for r in aws_route53_record.cert_validation : r.fqdn
  ]
}