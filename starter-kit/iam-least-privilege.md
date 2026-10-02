# KijaniKiosk IAM Least Privilege Design

## Use Case

The KijaniKiosk application needs to upload product images to an Amazon S3 bucket.

The application does not require administrator access to AWS.

It should only be able to upload objects into the required product image location.

## IAM Policy

The following policy demonstrates the principle of least privilege:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "UploadKijaniKioskProductImages",
      "Effect": "Allow",
      "Action": [
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::kijaniosk-product-images/uploads/*"
    }
  ]
}
