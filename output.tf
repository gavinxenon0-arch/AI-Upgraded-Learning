output "invoke_url" {
  value = try("${aws_api_gateway_stage.prod.invoke_url}/chat", "Not available yet")
}
output "instance_public_ip" {
  value = try("${aws_instance.web[0].public_ip}","Not Created")
}