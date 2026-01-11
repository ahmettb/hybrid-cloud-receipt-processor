variable "project_name" {
  type    = string
  default = "receipt-processor"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "availability_zones" {
  type    = string
  default = "us-east-1a"
}

variable "s3_bucket_name" {
  type        = string
}

variable "instance_type" {
  type    = string
  default = "t2.micro"
}

variable "my_ip" {
  type        = string
  default     = "OWN_IP/32" 
  description = "for ssh access"
}



variable "db_user" { type = string }
variable "db_password" { type = string }
variable "db_dsn" { type = string }
variable "wallet_password" { type = string }