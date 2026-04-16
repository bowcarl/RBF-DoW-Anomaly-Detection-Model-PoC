terraform {
    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "~> 3.0"
        }
    }
}

provider "aws" {
    region = "eu-north-1"
}

# Resolves the deploying account ID automatically.
# No hardcoded account numbers anywhere in this file.
data "aws_caller_identity" "current" {}

# ─── Variables ────────────────────────────────────────────────────────────────

variable "alert_email" {
    description = "Email address to receive DoW alert notifications via SNS"
    type        = string
}

variable "fingerprint_bucket_name" {
    description = "Globally unique S3 bucket name for fingerprint dataset storage"
    type        = string
    default     = "fingerprint-dataset-bucket"
}

variable "mitigation_bucket_name" {
    description = "Globally unique S3 bucket name for mitigation log storage"
    type        = string
    default     = "mitigation-bucket"
}

# ─── S3 Buckets ───────────────────────────────────────────────────────────────

resource "aws_s3_bucket" "S3Bucket" {
    bucket = var.fingerprint_bucket_name
}

resource "aws_s3_bucket" "S3Bucket2" {
    bucket = var.mitigation_bucket_name
}

# Explicit public access blocks on both buckets.
# Model artefacts and mitigation logs must never be publicly accessible.
resource "aws_s3_bucket_public_access_block" "fingerprint_bucket" {
    bucket                  = aws_s3_bucket.S3Bucket.id
    block_public_acls       = true
    block_public_policy     = true
    ignore_public_acls      = true
    restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "mitigation_bucket" {
    bucket                  = aws_s3_bucket.S3Bucket2.id
    block_public_acls       = true
    block_public_policy     = true
    ignore_public_acls      = true
    restrict_public_buckets = true
}

# ─── DynamoDB Tables ──────────────────────────────────────────────────────────

resource "aws_dynamodb_table" "DynamoDBTable" {
    name         = "fingerprints"
    billing_mode = "PAY_PER_REQUEST"
    hash_key     = "windowStart"

    attribute {
        name = "windowStart"
        type = "S"
    }
}

resource "aws_dynamodb_table" "DynamoDBTable2" {
    name         = "MitigationLog"
    billing_mode = "PAY_PER_REQUEST"
    hash_key     = "timestamp"

    attribute {
        name = "timestamp"
        type = "S"
    }
}

# ─── SNS ──────────────────────────────────────────────────────────────────────

resource "aws_sns_topic" "SNSTopic" {
    name         = "DoWAlerts"
    display_name = ""
}

# FIXED: Replaced wildcard Principal ("AWS": "*") with the specific IAM role
# ARN of the fingerprint-aggregator. The original policy allowed any IAM entity
# in the account to Publish, Subscribe, DeleteTopic and more. Now only the
# fingerprint-aggregator can publish alerts; no other principal has access.
resource "aws_sns_topic_policy" "SNSTopicPolicy" {
    arn = aws_sns_topic.SNSTopic.arn
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Sid    = "AllowFingerprintAggregatorPublish"
                Effect = "Allow"
                Principal = {
                    AWS = aws_iam_role.IAMRole7.arn
                }
                Action   = "SNS:Publish"
                Resource = aws_sns_topic.SNSTopic.arn
            }
        ]
    })
}

resource "aws_sns_topic_subscription" "SNSSubscription" {
    topic_arn = aws_sns_topic.SNSTopic.arn
    protocol  = "email"
    endpoint  = var.alert_email
}

# ─── EventBridge ──────────────────────────────────────────────────────────────

resource "aws_cloudwatch_event_rule" "EventsRule" {
    name                = "triggerRate"
    description         = "Schedules the fingerprint-aggregator to run every five minutes"
    schedule_expression = "rate(5 minutes)"
}

resource "aws_cloudwatch_event_target" "CloudWatchEventTarget" {
    rule      = aws_cloudwatch_event_rule.EventsRule.name
    target_id = "LambdaTarget"
    arn       = aws_lambda_function.LambdaFunction.arn
}

# ─── Lambda Layers ────────────────────────────────────────────────────────────
# NOTE: These layer S3 keys point to the original account's internal artefact
# store (awslambda-eu-n-1-layers). In a fresh account these will not resolve.
# You will need to re-publish the layers by uploading their zip packages and
# updating the s3_bucket/s3_key values, or use the filename argument instead.

resource "aws_lambda_layer_version" "LambdaLayerVersion" {
    compatible_runtimes = ["python3.11"]
    layer_name          = "common-utils"
    s3_bucket           = "awslambda-eu-n-1-layers"
    s3_key              = "/snapshots/${data.aws_caller_identity.current.account_id}/common-utils-43f01da8-60fe-49ac-a367-67c00ba25e7f"
}

resource "aws_lambda_layer_version" "LambdaLayerVersion2" {
    compatible_runtimes = ["python3.11"]
    layer_name          = "scikit-learn"
    s3_bucket           = "awslambda-eu-n-1-layers"
    s3_key              = "/snapshots/${data.aws_caller_identity.current.account_id}/scikit-learn-351cd47b-5109-420d-a2ce-6856e0a3bf37"
}

resource "aws_lambda_layer_version" "LambdaLayerVersion3" {
    compatible_runtimes = ["python3.11"]
    layer_name          = "common-utils"
    s3_bucket           = "awslambda-eu-n-1-layers"
    s3_key              = "/snapshots/${data.aws_caller_identity.current.account_id}/common-utils-5a79f6f5-3d03-467f-8657-cb10203545f2"
}

resource "aws_lambda_layer_version" "LambdaLayerVersion4" {
    compatible_runtimes = ["python3.11"]
    layer_name          = "scikit-learn-py311"
    s3_bucket           = "awslambda-eu-n-1-layers"
    s3_key              = "/snapshots/${data.aws_caller_identity.current.account_id}/scikit-learn-py311-4c6df160-fe73-4d09-bc56-de7bb324593c"
}

resource "aws_lambda_layer_version" "LambdaLayerVersion5" {
    compatible_runtimes = ["python3.11"]
    layer_name          = "scikit-learn-161"
    s3_bucket           = "awslambda-eu-n-1-layers"
    s3_key              = "/snapshots/${data.aws_caller_identity.current.account_id}/scikit-learn-161-3c7617be-0169-4451-912e-050f57c692e1"
}

# ─── Lambda Functions ─────────────────────────────────────────────────────────
# NOTE: s3_bucket/s3_key/s3_object_version reference the original account's
# internal Lambda deployment artefact store (awslambda-eu-n-1-tasks). These are
# not transferable to another account. Before running terraform apply in a fresh
# account, replace each s3_key with your own uploaded zip path, or switch to
# the filename argument pointing to a local zip package.

resource "aws_lambda_function" "LambdaFunction" {
    function_name = "fingerprint-aggregator"
    description   = ""
    handler       = "lambda_function.lambda_handler"
    architectures = ["x86_64"]
    memory_size   = 512
    role          = aws_iam_role.IAMRole7.arn
    runtime       = "python3.11"
    timeout       = 60

    environment {
        variables = {
            SNS_TOPIC_ARN = aws_sns_topic.SNSTopic.arn
            MODEL_BUCKET  = aws_s3_bucket.S3Bucket.id
        }
    }

    s3_bucket         = "awslambda-eu-n-1-tasks"
    s3_key            = "/snapshots/${data.aws_caller_identity.current.account_id}/fingerprint-aggregator-60e0a812-2e7c-4a59-b2b4-129d994a390e"
    s3_object_version = ".rrTjcFc0aTAj_94jzb6lSGgLA_2YWfT"

    tracing_config { mode = "PassThrough" }

    layers = [
        "arn:aws:lambda:eu-north-1:${data.aws_caller_identity.current.account_id}:layer:scikit-learn-161:1"
    ]
}

resource "aws_lambda_function" "LambdaFunction2" {
    function_name = "login"
    description   = ""
    handler       = "lambda_function.lambda_handler"
    architectures = ["x86_64"]
    memory_size   = 128
    role          = aws_iam_role.IAMRole6.arn
    runtime       = "python3.11"
    timeout       = 3

    s3_bucket         = "awslambda-eu-n-1-tasks"
    s3_key            = "/snapshots/${data.aws_caller_identity.current.account_id}/login-548c0af4-a3df-4b57-8812-71d7019737d6"
    s3_object_version = "C6dehCmiCC.SJFLCjQR79wDCnRgBFgTC"

    tracing_config { mode = "PassThrough" }

    layers = [
        "arn:aws:lambda:eu-north-1:${data.aws_caller_identity.current.account_id}:layer:common-utils:2"
    ]
}

resource "aws_lambda_function" "LambdaFunction3" {
    function_name = "mitigation_config"
    description   = ""
    handler       = "lambda_function.lambda_handler"
    architectures = ["x86_64"]
    memory_size   = 128
    role          = aws_iam_role.IAMRole10.arn
    runtime       = "python3.11"
    timeout       = 3

    s3_bucket         = "awslambda-eu-n-1-tasks"
    s3_key            = "/snapshots/${data.aws_caller_identity.current.account_id}/mitigation_config-3f3815d0-ce90-406a-93e4-7f674516edd0"
    s3_object_version = "68KS5QOIcoM29.Dkw4gKtIjNcaLSFFO_"

    tracing_config { mode = "PassThrough" }
}

resource "aws_lambda_function" "LambdaFunction4" {
    function_name = "checkout"
    description   = ""
    handler       = "lambda_function.lambda_handler"
    architectures = ["x86_64"]
    memory_size   = 512
    role          = aws_iam_role.IAMRole2.arn
    runtime       = "python3.11"
    timeout       = 3

    s3_bucket         = "awslambda-eu-n-1-tasks"
    s3_key            = "/snapshots/${data.aws_caller_identity.current.account_id}/checkout-e0a5c630-33fd-4b0b-a803-16ae5dd1d9b5"
    s3_object_version = "x6nvf4LBnKlxzkxWSLfnOus3mf_yNcsC"

    tracing_config { mode = "PassThrough" }

    layers = [
        "arn:aws:lambda:eu-north-1:${data.aws_caller_identity.current.account_id}:layer:common-utils:2"
    ]
}

resource "aws_lambda_function" "LambdaFunction5" {
    function_name = "mitigation"
    description   = ""
    handler       = "lambda_function.lambda_handler"
    architectures = ["x86_64"]
    memory_size   = 128
    role          = aws_iam_role.IAMRole9.arn
    runtime       = "python3.11"
    timeout       = 3

    s3_bucket         = "awslambda-eu-n-1-tasks"
    s3_key            = "/snapshots/${data.aws_caller_identity.current.account_id}/mitigation-07d01436-8f31-42d2-8568-2c34db10d863"
    s3_object_version = "w3cX2ODrUt6i4lYn.CJkxtC_e77W2fG8"

    tracing_config { mode = "PassThrough" }
}

resource "aws_lambda_function" "LambdaFunction6" {
    function_name = "cart"
    description   = ""
    handler       = "lambda_function.lambda_handler"
    architectures = ["x86_64"]
    memory_size   = 256
    role          = aws_iam_role.IAMRole.arn
    runtime       = "python3.11"
    timeout       = 3

    s3_bucket         = "awslambda-eu-n-1-tasks"
    s3_key            = "/snapshots/${data.aws_caller_identity.current.account_id}/cart-4f674470-5fe1-4a49-ba54-3bd84c89085a"
    s3_object_version = "x9GeGX1jwO3uyzL56Y5Fu_ozBaTUbC0y"

    tracing_config { mode = "PassThrough" }

    layers = [
        "arn:aws:lambda:eu-north-1:${data.aws_caller_identity.current.account_id}:layer:common-utils:2"
    ]
}

resource "aws_lambda_function" "LambdaFunction7" {
    function_name = "search"
    description   = ""
    handler       = "lambda_function.lambda_handler"
    architectures = ["x86_64"]
    memory_size   = 256
    role          = aws_iam_role.IAMRole12.arn
    runtime       = "python3.11"
    timeout       = 3

    s3_bucket         = "awslambda-eu-n-1-tasks"
    s3_key            = "/snapshots/${data.aws_caller_identity.current.account_id}/search-80e02647-adb2-4bf2-8ead-43352e8bd966"
    s3_object_version = "Hyxfeek.aAtr5jy22RTGPj95D_Ram_sP"

    tracing_config { mode = "PassThrough" }

    layers = [
        "arn:aws:lambda:eu-north-1:${data.aws_caller_identity.current.account_id}:layer:common-utils:2"
    ]
}

resource "aws_lambda_function" "LambdaFunction8" {
    function_name = "mitigation_log_exporter"
    description   = ""
    handler       = "lambda_function.lambda_handler"
    architectures = ["x86_64"]
    memory_size   = 128
    role          = aws_iam_role.IAMRole11.arn
    runtime       = "python3.11"
    timeout       = 3

    environment {
        variables = {
            S3_BUCKET        = aws_s3_bucket.S3Bucket2.id
            MITIGATION_TABLE = "MitigationLog"
            S3_KEY           = "mitigation_log.csv"
        }
    }

    s3_bucket         = "awslambda-eu-n-1-tasks"
    s3_key            = "/snapshots/${data.aws_caller_identity.current.account_id}/mitigation_log_exporter-929cd488-93a2-47f2-aca0-75c02bd7424c"
    s3_object_version = "5A226wUL_HpLiPyfaUHtiZU3kXOFVwpm"

    tracing_config { mode = "PassThrough" }
}

resource "aws_lambda_function" "LambdaFunction9" {
    function_name = "product"
    description   = ""
    handler       = "lambda_function.lambda_handler"
    architectures = ["x86_64"]
    memory_size   = 256
    role          = aws_iam_role.IAMRole13.arn
    runtime       = "python3.11"
    timeout       = 3

    s3_bucket         = "awslambda-eu-n-1-tasks"
    s3_key            = "/snapshots/${data.aws_caller_identity.current.account_id}/product-98d73da9-f00c-49be-bf4f-3c1b4fa3eb50"
    s3_object_version = "IRTwJkKLOOMwgOqZaumW_JOZ9W.g3Kae"

    tracing_config { mode = "PassThrough" }

    layers = [
        "arn:aws:lambda:eu-north-1:${data.aws_caller_identity.current.account_id}:layer:common-utils:2"
    ]
}

resource "aws_lambda_function" "LambdaFunction10" {
    function_name = "FingerprintS3Builder"
    description   = ""
    handler       = "lambda_function.lambda_handler"
    architectures = ["x86_64"]
    memory_size   = 128
    role          = aws_iam_role.IAMRole8.arn
    runtime       = "python3.11"
    timeout       = 3

    environment {
        variables = {
            FINGERPRINT_TABLE = "fingerprints"
            S3_BUCKET         = aws_s3_bucket.S3Bucket.id
            S3_KEY            = "fingerprint_dataset.csv"
        }
    }

    s3_bucket         = "awslambda-eu-n-1-tasks"
    s3_key            = "/snapshots/${data.aws_caller_identity.current.account_id}/FingerprintS3Builder-a06e94a2-6385-4b84-98ef-465fd9cccc5d"
    s3_object_version = "Zt_F3Yh3UPDQcQtjcWpscJ2lPjjvu0BX"

    tracing_config { mode = "PassThrough" }
}

# ─── Lambda Permissions ───────────────────────────────────────────────────────

resource "aws_lambda_permission" "LambdaPermission" {
    action        = "lambda:InvokeFunction"
    function_name = aws_lambda_function.LambdaFunction.arn
    principal     = "events.amazonaws.com"
    source_arn    = aws_cloudwatch_event_rule.EventsRule.arn
}

resource "aws_lambda_permission" "LambdaPermission2" {
    action        = "lambda:InvokeFunction"
    function_name = aws_lambda_function.LambdaFunction2.arn
    principal     = "apigateway.amazonaws.com"
    source_arn    = "arn:aws:execute-api:eu-north-1:${data.aws_caller_identity.current.account_id}:ezrgx1xle1/*/*/login"
}

resource "aws_lambda_permission" "LambdaPermission3" {
    action        = "lambda:InvokeFunction"
    function_name = aws_lambda_function.LambdaFunction4.arn
    principal     = "apigateway.amazonaws.com"
    source_arn    = "arn:aws:execute-api:eu-north-1:${data.aws_caller_identity.current.account_id}:ezrgx1xle1/*/*/checkout"
}

resource "aws_lambda_permission" "LambdaPermission4" {
    action        = "lambda:InvokeFunction"
    function_name = aws_lambda_function.LambdaFunction6.arn
    principal     = "apigateway.amazonaws.com"
    source_arn    = "arn:aws:execute-api:eu-north-1:${data.aws_caller_identity.current.account_id}:ezrgx1xle1/*/*/cart"
}

resource "aws_lambda_permission" "LambdaPermission5" {
    action        = "lambda:InvokeFunction"
    function_name = aws_lambda_function.LambdaFunction7.arn
    principal     = "apigateway.amazonaws.com"
    source_arn    = "arn:aws:execute-api:eu-north-1:${data.aws_caller_identity.current.account_id}:ezrgx1xle1/*/*/search"
}

resource "aws_lambda_permission" "LambdaPermission6" {
    action        = "lambda:InvokeFunction"
    function_name = aws_lambda_function.LambdaFunction9.arn
    principal     = "apigateway.amazonaws.com"
    source_arn    = "arn:aws:execute-api:eu-north-1:${data.aws_caller_identity.current.account_id}:ezrgx1xle1/*/*/product"
}

# ─── IAM Roles ────────────────────────────────────────────────────────────────

resource "aws_iam_role" "IAMRole" {
    name                 = "cart-role-l0u83hcc"
    path                 = "/service-role/"
    max_session_duration = 3600
    assume_role_policy   = jsonencode({
        Version = "2012-10-17"
        Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }]
    })
}

resource "aws_iam_role" "IAMRole2" {
    name                 = "checkout-role-gpbdome1"
    path                 = "/service-role/"
    max_session_duration = 3600
    assume_role_policy   = jsonencode({
        Version = "2012-10-17"
        Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }]
    })
}

resource "aws_iam_role" "IAMRole3" {
    name                 = "ec2-k6-experiment-role"
    path                 = "/"
    max_session_duration = 3600
    assume_role_policy   = jsonencode({
        Version = "2012-10-17"
        Statement = [{ Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }]
    })
}

resource "aws_iam_role" "IAMRole4" {
    name                 = "DoWTestFunction-role-ozcs319p"
    path                 = "/service-role/"
    max_session_duration = 3600
    assume_role_policy   = jsonencode({
        Version = "2012-10-17"
        Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }]
    })
}

resource "aws_iam_role" "IAMRole5" {
    name                 = "FingerprintAggregator-role-ndkkgd8p"
    path                 = "/service-role/"
    max_session_duration = 3600
    assume_role_policy   = jsonencode({
        Version = "2012-10-17"
        Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }]
    })
}

resource "aws_iam_role" "IAMRole6" {
    name                 = "login-role-g5i74shi"
    path                 = "/service-role/"
    max_session_duration = 3600
    assume_role_policy   = jsonencode({
        Version = "2012-10-17"
        Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }]
    })
}

resource "aws_iam_role" "IAMRole7" {
    name                 = "fingerprint-aggregator-role-d7yn24tz"
    path                 = "/service-role/"
    max_session_duration = 3600
    assume_role_policy   = jsonencode({
        Version = "2012-10-17"
        Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }]
    })
}

resource "aws_iam_role" "IAMRole8" {
    name                 = "FingerprintS3Builder-role-6uwewnl8"
    path                 = "/service-role/"
    max_session_duration = 3600
    assume_role_policy   = jsonencode({
        Version = "2012-10-17"
        Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }]
    })
}

resource "aws_iam_role" "IAMRole9" {
    name                 = "mitigation-role-yriq8qt5"
    path                 = "/service-role/"
    max_session_duration = 3600
    assume_role_policy   = jsonencode({
        Version = "2012-10-17"
        Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }]
    })
}

resource "aws_iam_role" "IAMRole10" {
    name                 = "mitigation_config-role-ale90h3l"
    path                 = "/service-role/"
    max_session_duration = 3600
    assume_role_policy   = jsonencode({
        Version = "2012-10-17"
        Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }]
    })
}

resource "aws_iam_role" "IAMRole11" {
    name                 = "mitigation_log_exporter-role-efnvblfh"
    path                 = "/service-role/"
    max_session_duration = 3600
    assume_role_policy   = jsonencode({
        Version = "2012-10-17"
        Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }]
    })
}

resource "aws_iam_role" "IAMRole12" {
    name                 = "search-role-59g3btxc"
    path                 = "/service-role/"
    max_session_duration = 3600
    assume_role_policy   = jsonencode({
        Version = "2012-10-17"
        Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }]
    })
}

resource "aws_iam_role" "IAMRole13" {
    name                 = "product-role-mesoh1zb"
    path                 = "/service-role/"
    max_session_duration = 3600
    assume_role_policy   = jsonencode({
        Version = "2012-10-17"
        Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }]
    })
}

resource "aws_iam_instance_profile" "IAMInstanceProfile" {
    name  = aws_iam_role.IAMRole3.name
    path  = "/"
    roles = [aws_iam_role.IAMRole3.name]
}

# ─── Basic Execution Managed Policies ─────────────────────────────────────────
# Each policy grants one Lambda function the ability to create its log group
# and write log events to CloudWatch Logs. This is the minimum required for
# any Lambda function to run — without it the runtime itself errors on startup.

resource "aws_iam_policy" "IAMManagedPolicy" {
    name = "AWSLambdaBasicExecutionRole-8234de80-e347-48df-b019-6e6f7bd5cda9"
    path = "/service-role/"
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            { Effect = "Allow", Action = "logs:CreateLogGroup",
              Resource = "arn:aws:logs:eu-north-1:${data.aws_caller_identity.current.account_id}:*" },
            { Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents"],
              Resource = "arn:aws:logs:eu-north-1:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/mitigation_log_exporter:*" }
        ]
    })
}

resource "aws_iam_policy" "IAMManagedPolicy2" {
    name = "AWSLambdaBasicExecutionRole-4dba5c0e-44f8-49d7-ba42-dc7a0fb78995"
    path = "/service-role/"
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            { Effect = "Allow", Action = "logs:CreateLogGroup",
              Resource = "arn:aws:logs:eu-north-1:${data.aws_caller_identity.current.account_id}:*" },
            { Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents"],
              Resource = "arn:aws:logs:eu-north-1:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/mitigation_config:*" }
        ]
    })
}

resource "aws_iam_policy" "IAMManagedPolicy3" {
    name = "AWSLambdaBasicExecutionRole-ccda8ec8-dbd8-4d87-a845-0e5d9c38f7ad"
    path = "/service-role/"
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            { Effect = "Allow", Action = "logs:CreateLogGroup",
              Resource = "arn:aws:logs:eu-north-1:${data.aws_caller_identity.current.account_id}:*" },
            { Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents"],
              Resource = "arn:aws:logs:eu-north-1:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/FingerprintAggregator:*" }
        ]
    })
}

resource "aws_iam_policy" "IAMManagedPolicy4" {
    name = "AWSLambdaBasicExecutionRole-00dfe418-cd68-4ee2-ac72-b3cdf7cd6733"
    path = "/service-role/"
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            { Effect = "Allow", Action = "logs:CreateLogGroup",
              Resource = "arn:aws:logs:eu-north-1:${data.aws_caller_identity.current.account_id}:*" },
            { Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents"],
              Resource = "arn:aws:logs:eu-north-1:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/cart:*" }
        ]
    })
}

resource "aws_iam_policy" "IAMManagedPolicy5" {
    name = "AWSLambdaBasicExecutionRole-8eb43f76-a7ad-4e21-8e26-b31878a2c143"
    path = "/service-role/"
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            { Effect = "Allow", Action = "logs:CreateLogGroup",
              Resource = "arn:aws:logs:eu-north-1:${data.aws_caller_identity.current.account_id}:*" },
            { Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents"],
              Resource = "arn:aws:logs:eu-north-1:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/fingerprint-aggregator:*" }
        ]
    })
}

resource "aws_iam_policy" "IAMManagedPolicy6" {
    name = "AWSLambdaBasicExecutionRole-856622ce-fa5e-406f-a5d6-428c102528d0"
    path = "/service-role/"
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            { Effect = "Allow", Action = "logs:CreateLogGroup",
              Resource = "arn:aws:logs:eu-north-1:${data.aws_caller_identity.current.account_id}:*" },
            { Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents"],
              Resource = "arn:aws:logs:eu-north-1:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/mitigation:*" }
        ]
    })
}

resource "aws_iam_policy" "IAMManagedPolicy7" {
    name = "AWSLambdaBasicExecutionRole-39949ed6-014a-4f11-962e-18cae5c82711"
    path = "/service-role/"
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            { Effect = "Allow", Action = "logs:CreateLogGroup",
              Resource = "arn:aws:logs:eu-north-1:${data.aws_caller_identity.current.account_id}:*" },
            { Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents"],
              Resource = "arn:aws:logs:eu-north-1:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/DoWTestFunction:*" }
        ]
    })
}

resource "aws_iam_policy" "IAMManagedPolicy8" {
    name = "AWSLambdaBasicExecutionRole-eabb01e0-5bd2-4150-9556-eaada8d9d55f"
    path = "/service-role/"
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            { Effect = "Allow", Action = "logs:CreateLogGroup",
              Resource = "arn:aws:logs:eu-north-1:${data.aws_caller_identity.current.account_id}:*" },
            { Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents"],
              Resource = "arn:aws:logs:eu-north-1:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/login:*" }
        ]
    })
}

resource "aws_iam_policy" "IAMManagedPolicy9" {
    name = "ec2-k6-experiment-rolePolicy"
    path = "/"
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            { Effect = "Allow", Action = ["events:EnableRule", "events:DisableRule"],
              Resource = aws_cloudwatch_event_rule.EventsRule.arn }
        ]
    })
}

resource "aws_iam_policy" "IAMManagedPolicy10" {
    name = "AWSLambdaBasicExecutionRole-fe31e2bd-b069-4b94-ac5d-06312d8ceb27"
    path = "/service-role/"
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            { Effect = "Allow", Action = "logs:CreateLogGroup",
              Resource = "arn:aws:logs:eu-north-1:${data.aws_caller_identity.current.account_id}:*" },
            { Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents"],
              Resource = "arn:aws:logs:eu-north-1:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/FingerprintS3Builder:*" }
        ]
    })
}

resource "aws_iam_policy" "IAMManagedPolicy11" {
    name = "AWSLambdaBasicExecutionRole-486704db-5476-4b56-baeb-50732e3583e2"
    path = "/service-role/"
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            { Effect = "Allow", Action = "logs:CreateLogGroup",
              Resource = "arn:aws:logs:eu-north-1:${data.aws_caller_identity.current.account_id}:*" },
            { Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents"],
              Resource = "arn:aws:logs:eu-north-1:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/checkout:*" }
        ]
    })
}

resource "aws_iam_policy" "IAMManagedPolicy12" {
    name = "AWSLambdaBasicExecutionRole-8e0bae94-a14d-46ab-b923-b0506235c92d"
    path = "/service-role/"
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            { Effect = "Allow", Action = "logs:CreateLogGroup",
              Resource = "arn:aws:logs:eu-north-1:${data.aws_caller_identity.current.account_id}:*" },
            { Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents"],
              Resource = "arn:aws:logs:eu-north-1:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/search:*" }
        ]
    })
}

resource "aws_iam_policy" "IAMManagedPolicy13" {
    name = "AWSLambdaBasicExecutionRole-c602eff8-d901-4529-870d-d608c567bb15"
    path = "/service-role/"
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            { Effect = "Allow", Action = "logs:CreateLogGroup",
              Resource = "arn:aws:logs:eu-north-1:${data.aws_caller_identity.current.account_id}:*" },
            { Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents"],
              Resource = "arn:aws:logs:eu-north-1:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/product:*" }
        ]
    })
}

# ─── Managed Policy Attachments ───────────────────────────────────────────────
# Former2 exported the policy documents but missed the attachments that connect
# them to their roles. Without these resources the policies exist in IAM but are
# inert — no role inherits them. Every Lambda invocation would fail immediately
# because the runtime cannot write its startup log line to CloudWatch Logs.

resource "aws_iam_role_policy_attachment" "attach_exec_cart" {
    role       = aws_iam_role.IAMRole.name
    policy_arn = aws_iam_policy.IAMManagedPolicy4.arn
}

resource "aws_iam_role_policy_attachment" "attach_exec_checkout" {
    role       = aws_iam_role.IAMRole2.name
    policy_arn = aws_iam_policy.IAMManagedPolicy11.arn
}

resource "aws_iam_role_policy_attachment" "attach_ec2_eventbridge" {
    role       = aws_iam_role.IAMRole3.name
    policy_arn = aws_iam_policy.IAMManagedPolicy9.arn
}

resource "aws_iam_role_policy_attachment" "attach_exec_dowtest" {
    role       = aws_iam_role.IAMRole4.name
    policy_arn = aws_iam_policy.IAMManagedPolicy7.arn
}

resource "aws_iam_role_policy_attachment" "attach_exec_aggregator_old_role" {
    role       = aws_iam_role.IAMRole5.name
    policy_arn = aws_iam_policy.IAMManagedPolicy3.arn
}

resource "aws_iam_role_policy_attachment" "attach_exec_login" {
    role       = aws_iam_role.IAMRole6.name
    policy_arn = aws_iam_policy.IAMManagedPolicy8.arn
}

resource "aws_iam_role_policy_attachment" "attach_exec_fingerprint_aggregator" {
    role       = aws_iam_role.IAMRole7.name
    policy_arn = aws_iam_policy.IAMManagedPolicy5.arn
}

resource "aws_iam_role_policy_attachment" "attach_exec_s3builder" {
    role       = aws_iam_role.IAMRole8.name
    policy_arn = aws_iam_policy.IAMManagedPolicy10.arn
}

resource "aws_iam_role_policy_attachment" "attach_exec_mitigation" {
    role       = aws_iam_role.IAMRole9.name
    policy_arn = aws_iam_policy.IAMManagedPolicy6.arn
}

resource "aws_iam_role_policy_attachment" "attach_exec_mitigation_config" {
    role       = aws_iam_role.IAMRole10.name
    policy_arn = aws_iam_policy.IAMManagedPolicy2.arn
}

resource "aws_iam_role_policy_attachment" "attach_exec_mitigation_log_exporter" {
    role       = aws_iam_role.IAMRole11.name
    policy_arn = aws_iam_policy.IAMManagedPolicy.arn
}

resource "aws_iam_role_policy_attachment" "attach_exec_search" {
    role       = aws_iam_role.IAMRole12.name
    policy_arn = aws_iam_policy.IAMManagedPolicy12.arn
}

resource "aws_iam_role_policy_attachment" "attach_exec_product" {
    role       = aws_iam_role.IAMRole13.name
    policy_arn = aws_iam_policy.IAMManagedPolicy13.arn
}

# ─── Inline Role Policies ─────────────────────────────────────────────────────

# EC2 / k6 traffic generator.
# FIXED: Removed dynamodb:CreateTable and dynamodb:DeleteTable. The k6 EC2
# instance only needs to toggle the EventBridge rule to pause and resume traffic
# generation. Allowing it to create or delete the live fingerprints and
# MitigationLog tables would let a compromised instance wipe all stored
# training data and audit logs with a single API call.
resource "aws_iam_role_policy" "IAMPolicy" {
    role = aws_iam_role.IAMRole3.name
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Sid      = "EventBridgeControl"
                Effect   = "Allow"
                Action   = ["events:EnableRule", "events:DisableRule"]
                Resource = aws_cloudwatch_event_rule.EventsRule.arn
            }
        ]
    })
}

# fingerprint-aggregator: publish ALERT and WARNING notifications to SNS.
resource "aws_iam_role_policy" "IAMPolicy2" {
    role = aws_iam_role.IAMRole7.name
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Effect   = "Allow"
            Action   = ["sns:Publish"]
            Resource = aws_sns_topic.SNSTopic.arn
        }]
    })
}

# mitigation Lambda: the only role permitted to throttle production endpoints.
# PutFunctionConcurrency sets a concurrency cap on checkout and cart during an
# attack. DeleteFunctionConcurrency lifts the cap when the attack subsides.
# GetFunctionConcurrency reads the current cap to decide whether to act.
# PutItem writes each throttle decision to the MitigationLog audit table.
resource "aws_iam_role_policy" "IAMPolicy3" {
    role = aws_iam_role.IAMRole9.name
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Sid    = "MitigationThrottling"
                Effect = "Allow"
                Action = [
                    "lambda:PutFunctionConcurrency",
                    "lambda:DeleteFunctionConcurrency",
                    "lambda:GetFunctionConcurrency"
                ]
                Resource = [
                    aws_lambda_function.LambdaFunction4.arn,
                    aws_lambda_function.LambdaFunction6.arn
                ]
            },
            {
                Sid      = "MitigationLogging"
                Effect   = "Allow"
                Action   = ["dynamodb:PutItem"]
                Resource = aws_dynamodb_table.DynamoDBTable2.arn
            }
        ]
    })
}

# fingerprint-aggregator: load the trained Isolation Forest .pkl model from S3
# at the start of each 5-minute evaluation run.
resource "aws_iam_role_policy" "IAMPolicy4" {
    role = aws_iam_role.IAMRole7.name
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Effect   = "Allow"
            Action   = ["s3:GetObject"]
            Resource = "${aws_s3_bucket.S3Bucket.arn}/*"
        }]
    })
}

# FIXED: Replaced duplicate Lambda throttling (PutFunctionConcurrency /
# DeleteFunctionConcurrency) with lambda:InvokeFunction scoped to the
# mitigation Lambda only. The original IAMPolicy5 gave the fingerprint-aggregator
# the same throttling authority as the dedicated mitigation role, meaning two
# separate functions could independently cap production endpoints. Now the
# fingerprint-aggregator signals an attack by invoking the mitigation Lambda,
# which is the single authorised principal for applying concurrency limits.
resource "aws_iam_role_policy" "IAMPolicy5" {
    role = aws_iam_role.IAMRole7.name
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Sid      = "InvokeMitigationLambda"
            Effect   = "Allow"
            Action   = ["lambda:InvokeFunction"]
            Resource = aws_lambda_function.LambdaFunction5.arn
        }]
    })
}

# ADDED: fingerprint-aggregator telemetry and storage permissions.
#
# cloudwatch:GetMetricData — allows the function to pull invocation count,
# average duration, and error rate metrics for all 5 Lambda functions from
# CloudWatch every 5 minutes. Without this, the function has no telemetry to
# compute cross-function ratios from; every run returns empty data and no
# fingerprint or anomaly score is ever produced. The Resource is "*" because
# CloudWatch metric reads are account-wide and cannot be scoped to a specific
# resource ARN.
#
# dynamodb:PutItem on fingerprints — allows the function to write each computed
# 5-minute behavioral fingerprint window to the fingerprints DynamoDB table.
# Without this, computed fingerprints are discarded in memory and the ML
# pipeline has no stored windows to evaluate.
resource "aws_iam_role_policy" "IAMPolicy_aggregator_telemetry" {
    role = aws_iam_role.IAMRole7.name
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Sid      = "ReadLambdaMetrics"
                Effect   = "Allow"
                Action   = ["cloudwatch:GetMetricData"]
                Resource = "*"
            },
            {
                Sid      = "WriteFingerprintWindows"
                Effect   = "Allow"
                Action   = ["dynamodb:PutItem"]
                Resource = aws_dynamodb_table.DynamoDBTable.arn
            }
        ]
    })
}

# ADDED: FingerprintS3Builder data export permissions.
#
# dynamodb:Scan on fingerprints — allows the function to read all stored
# fingerprint windows from DynamoDB to build the training dataset CSV. Without
# this the export fails with AccessDenied before reading a single row, and the
# Isolation Forest model can never be trained on new data.
#
# s3:PutObject on fingerprint-dataset-bucket — allows the function to write the
# exported fingerprint_dataset.csv to S3. Without this the CSV never reaches the
# bucket and the training script that reads it has nothing to consume.
resource "aws_iam_role_policy" "IAMPolicy_s3builder" {
    role = aws_iam_role.IAMRole8.name
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Sid      = "ReadFingerprintTable"
                Effect   = "Allow"
                Action   = ["dynamodb:Scan"]
                Resource = aws_dynamodb_table.DynamoDBTable.arn
            },
            {
                Sid      = "WriteDatasetCSV"
                Effect   = "Allow"
                Action   = ["s3:PutObject"]
                Resource = "${aws_s3_bucket.S3Bucket.arn}/*"
            }
        ]
    })
}

# ADDED: mitigation_log_exporter audit export permissions.
#
# dynamodb:Scan on MitigationLog — allows the function to read all recorded
# throttle decisions from the MitigationLog table. Without this the read fails
# immediately and no export is produced.
#
# s3:PutObject on mitigation-bucket — allows the function to write
# mitigation_log.csv to S3. Without this the mitigation audit trail is never
# persisted outside DynamoDB and cannot be retrieved for offline analysis.
resource "aws_iam_role_policy" "IAMPolicy_mitigation_log_exporter" {
    role = aws_iam_role.IAMRole11.name
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Sid      = "ReadMitigationLog"
                Effect   = "Allow"
                Action   = ["dynamodb:Scan"]
                Resource = aws_dynamodb_table.DynamoDBTable2.arn
            },
            {
                Sid      = "WriteMitigationCSV"
                Effect   = "Allow"
                Action   = ["s3:PutObject"]
                Resource = "${aws_s3_bucket.S3Bucket2.arn}/*"
            }
        ]
    })
}
