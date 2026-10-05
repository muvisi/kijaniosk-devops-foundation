terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    bucket = "kijanikiosk-tfstate"
    key    = "week4/friday/terraform.tfstate"
    region = "us-east-1"

    endpoints = {
      s3 = "http://127.0.0.1:9000"
    }

    access_key = "minioadmin"
    secret_key = "minioadmin"

    use_path_style              = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
  }
}
