provider "aws" {
  region = "${var.aws_region}"

  #  shared_credentials_file = "C:/Users/matthias/.aws/credentials"
  #  profile                 = "tfinfrauser"
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = "tf-state-${random_string.userstring.result}"

  versioning {
    enabled = true
  }

  lifecycle {
    #prevent_destroy = true
    ignore_changes = ["tags.tf_created"]
  }

  tags = "${local.common_tags}"
}

resource "aws_dynamodb_table" "terraform_state_lock" {
  name           = "tf-state-${random_string.userstring.result}"
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  lifecycle {
    ignore_changes = ["tags.tf_created"]
  }

  tags = "${local.common_tags}"
}

data "template_file" "tfbackendcfg" {
  template = "${file("tfbackend.tpl")}"

  vars {
    bucket         = "${aws_s3_bucket.terraform_state.id}"
    dynamodb_table = "${aws_dynamodb_table.terraform_state_lock.id}"
    region         = "${var.aws_region}"
  }
}

resource "local_file" "tfbackendcfg" {
  content    = "${data.template_file.tfbackendcfg.rendered}"
  filename   = "${path.module}/cfg/iamcreds"
  depends_on = ["aws_iam_access_key.terrauser"]
}
