output "nat_instance_public_ip" {
  value       = aws_eip.nat_eip.public_ip
}

output "s3_bucket_name" {
  value = aws_s3_bucket.receipt_bucket.id
}

output "textract_lambda_arn" {
  value = aws_lambda_function.textract_lambda.arn
}

output "db_reader_lambda_arn" {
  value = aws_lambda_function.receipt_db_reader.arn
}


output "frontend_api_url" {
  value = "${aws_api_gateway_stage.prod.invoke_url}/receipts"
}