data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

resource "aws_iam_role" "lambda_exec" {
  name = "serverless_example_lambda_${var.environment}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

data "tfe_outputs" "shared" {
  organization = "devans10"
  workspace    = "pitt-cicd-demo-shared"
}

# resource "aws_kms_key" "this" {
#   description             = "KMS key"
#   deletion_window_in_days = 10
#   policy                  = data.aws_iam_policy_document.this.json

#   enable_key_rotation = true
# }

resource "aws_lambda_function" "function" {

  function_name = "pitt-cicd-demo-${var.environment}"
  description   = "My awesome lambda function"
  role          = aws_iam_role.lambda_exec.arn
  image_uri     = "${data.tfe_outputs.shared.values.ecr_repository_url}:${var.image_tag}"
  package_type  = "Image"

  environment {
    variables = {
      TableName = aws_dynamodb_table.translations.name
    }
  }

  tracing_config {
    mode = "PassThrough"
  }

}

resource "aws_apigatewayv2_api" "lambda" {
  name          = "serverless-lambda-gw-${var.environment}"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "lambda" {
  api_id = aws_apigatewayv2_api.lambda.id

  name        = var.environment
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw.arn

    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
      }
    )
  }
}

resource "aws_apigatewayv2_integration" "hello_world" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.function.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "hello_world" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "GET /getHello"
  target    = "integrations/${aws_apigatewayv2_integration.hello_world.id}"
}

resource "aws_cloudwatch_log_group" "api_gw" {
  name = "/aws/api_gw/${aws_apigatewayv2_api.lambda.name}"

  retention_in_days = 7

  #kms_key_id = aws_kms_key.this.arn
}

resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.function.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "arn:aws:execute-api:${data.aws_region.current.name}:${data.aws_caller_identity.current.id}:${aws_apigatewayv2_api.lambda.id}/*/*/*"
}

resource "aws_dynamodb_table" "translations" {
  name           = "translations-${var.environment}"
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "lang"

  point_in_time_recovery {
    enabled = true
  }

  attribute {
    name = "lang"
    type = "S"
  }

  # server_side_encryption {
  #   enabled     = true
  #   kms_key_arn = aws_kms_key.this.arn
  # }

}

resource "aws_dynamodb_table_item" "en" {
  table_name = aws_dynamodb_table.translations.name
  hash_key   = aws_dynamodb_table.translations.hash_key

  item = <<ITEM
{
  "lang": {"S": "en"},
  "message": {"S": "Hello World"}
}
ITEM
}

resource "aws_dynamodb_table_item" "es" {
  table_name = aws_dynamodb_table.translations.name
  hash_key   = aws_dynamodb_table.translations.hash_key

  item = <<ITEM
{
  "lang": {"S": "es"},
  "message": {"S": "Hola Mundo"}
}
ITEM
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda_policy"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:BatchGetItem",
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:BatchWriteItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem"
        ]
        Resource = aws_dynamodb_table.translations.arn
      }
    ]
  })
}


data "aws_iam_policy_document" "this" {

  statement {
    sid = "AllowCloudWatchLogs01"

    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*"
    ]

    effect = "Allow"

    principals {
      type = "Service"

      identifiers = [
        format(
          "logs.%s.amazonaws.com",
          data.aws_region.current.name
        )
      ]
    }

    resources = ["*"]
  }
}
