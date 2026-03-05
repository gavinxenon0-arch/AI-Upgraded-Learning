output "certificate_arn" {
  description = "ARN of the ACM certificate"
  value       = aws_acm_certificate.hidden_target_group2.arn
}

output "certificate_domain_name" {
  description = "Primary domain name for the ACM certificate"
  value       = aws_acm_certificate.hidden_target_group2.domain_name
}

output "certificate_status" {
  description = "Current validation status of the ACM certificate"
  value       = aws_acm_certificate.hidden_target_group2.status
}

output "certificate_validation_arn" {
  description = "Validated certificate ARN after ACM validation completes"
  value       = aws_acm_certificate_validation.hidden_target_group2.certificate_arn
}

output "certificate_validation_record_fqdns" {
  description = "FQDNs of Route53 DNS validation records"
  value       = [for record in aws_route53_record.cert_validation : record.fqdn]
}

output "certificate_validation_records" {
  description = "Full Route53 validation records created for ACM validation"
  value = {
    for k, record in aws_route53_record.cert_validation :
    k => {
      name = record.name
      type = record.type
      fqdn = record.fqdn
    }
  }
}

output "domain_validation_options" {
  description = "ACM domain validation options used to generate DNS records"
  value       = aws_acm_certificate.hidden_target_group2.domain_validation_options
}