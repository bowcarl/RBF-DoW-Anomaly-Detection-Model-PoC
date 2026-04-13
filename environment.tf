terraform {
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~> 3.0"
        }
    }
}

provider "aws" {
    region = "eu-north-1"
}

resource "aws_s3_bucket" "S3Bucket" {
    bucket = "fingerprint-dataset-bucket"
}

resource "aws_s3_bucket" "S3Bucket2" {
    bucket = "mitigation-bucket"
}

resource "aws_lambda_function" "LambdaFunction" {
    description = ""
    environment {
        variables {
            SNS_TOPIC_ARN = "arn:aws:sns:eu-north-1:821814521025:DoWAlerts"
            MODEL_BUCKET = "${aws_s3_bucket.S3Bucket.id}"
        }
    }
    function_name = "fingerprint-aggregator"
    handler = "lambda_function.lambda_handler"
    architectures = [
        "x86_64"
    ]
    s3_bucket = "awslambda-eu-n-1-tasks"
    s3_key = "/snapshots/821814521025/fingerprint-aggregator-60e0a812-2e7c-4a59-b2b4-129d994a390e"
    s3_object_version = ".rrTjcFc0aTAj_94jzb6lSGgLA_2YWfT"
    memory_size = 512
    role = "${aws_iam_role.IAMRole7.arn}"
    runtime = "python3.11"
    timeout = 60
    tracing_config {
        mode = "PassThrough"
    }
    layers = [
        "arn:aws:lambda:eu-north-1:821814521025:layer:scikit-learn-161:1"
    ]
}

resource "aws_lambda_function" "LambdaFunction2" {
    description = ""
    function_name = "login"
    handler = "lambda_function.lambda_handler"
    architectures = [
        "x86_64"
    ]
    s3_bucket = "awslambda-eu-n-1-tasks"
    s3_key = "/snapshots/821814521025/login-548c0af4-a3df-4b57-8812-71d7019737d6"
    s3_object_version = "C6dehCmiCC.SJFLCjQR79wDCnRgBFgTC"
    memory_size = 128
    role = "${aws_iam_role.IAMRole6.arn}"
    runtime = "python3.11"
    timeout = 3
    tracing_config {
        mode = "PassThrough"
    }
    layers = [
        "arn:aws:lambda:eu-north-1:821814521025:layer:common-utils:2"
    ]
}

resource "aws_lambda_function" "LambdaFunction3" {
    description = ""
    function_name = "mitigation_config"
    handler = "lambda_function.lambda_handler"
    architectures = [
        "x86_64"
    ]
    s3_bucket = "awslambda-eu-n-1-tasks"
    s3_key = "/snapshots/821814521025/mitigation_config-3f3815d0-ce90-406a-93e4-7f674516edd0"
    s3_object_version = "68KS5QOIcoM29.Dkw4gKtIjNcaLSFFO_"
    memory_size = 128
    role = "${aws_iam_role.IAMRole10.arn}"
    runtime = "python3.11"
    timeout = 3
    tracing_config {
        mode = "PassThrough"
    }
}

resource "aws_lambda_function" "LambdaFunction4" {
    description = ""
    function_name = "checkout"
    handler = "lambda_function.lambda_handler"
    architectures = [
        "x86_64"
    ]
    s3_bucket = "awslambda-eu-n-1-tasks"
    s3_key = "/snapshots/821814521025/checkout-e0a5c630-33fd-4b0b-a803-16ae5dd1d9b5"
    s3_object_version = "x6nvf4LBnKlxzkxWSLfnOus3mf_yNcsC"
    memory_size = 512
    role = "${aws_iam_role.IAMRole2.arn}"
    runtime = "python3.11"
    timeout = 3
    tracing_config {
        mode = "PassThrough"
    }
    layers = [
        "arn:aws:lambda:eu-north-1:821814521025:layer:common-utils:2"
    ]
}

resource "aws_lambda_function" "LambdaFunction5" {
    description = ""
    function_name = "mitigation"
    handler = "lambda_function.lambda_handler"
    architectures = [
        "x86_64"
    ]
    s3_bucket = "awslambda-eu-n-1-tasks"
    s3_key = "/snapshots/821814521025/mitigation-07d01436-8f31-42d2-8568-2c34db10d863"
    s3_object_version = "w3cX2ODrUt6i4lYn.CJkxtC_e77W2fG8"
    memory_size = 128
    role = "${aws_iam_role.IAMRole9.arn}"
    runtime = "python3.11"
    timeout = 3
    tracing_config {
        mode = "PassThrough"
    }
}

resource "aws_lambda_function" "LambdaFunction6" {
    description = ""
    function_name = "cart"
    handler = "lambda_function.lambda_handler"
    architectures = [
        "x86_64"
    ]
    s3_bucket = "awslambda-eu-n-1-tasks"
    s3_key = "/snapshots/821814521025/cart-4f674470-5fe1-4a49-ba54-3bd84c89085a"
    s3_object_version = "x9GeGX1jwO3uyzL56Y5Fu_ozBaTUbC0y"
    memory_size = 256
    role = "${aws_iam_role.IAMRole.arn}"
    runtime = "python3.11"
    timeout = 3
    tracing_config {
        mode = "PassThrough"
    }
    layers = [
        "arn:aws:lambda:eu-north-1:821814521025:layer:common-utils:2"
    ]
}

resource "aws_lambda_function" "LambdaFunction7" {
    description = ""
    function_name = "search"
    handler = "lambda_function.lambda_handler"
    architectures = [
        "x86_64"
    ]
    s3_bucket = "awslambda-eu-n-1-tasks"
    s3_key = "/snapshots/821814521025/search-80e02647-adb2-4bf2-8ead-43352e8bd966"
    s3_object_version = "Hyxfeek.aAtr5jy22RTGPj95D_Ram_sP"
    memory_size = 256
    role = "${aws_iam_role.IAMRole12.arn}"
    runtime = "python3.11"
    timeout = 3
    tracing_config {
        mode = "PassThrough"
    }
    layers = [
        "arn:aws:lambda:eu-north-1:821814521025:layer:common-utils:2"
    ]
}

resource "aws_lambda_function" "LambdaFunction8" {
    description = ""
    environment {
        variables {
            S3_BUCKET = "${aws_s3_bucket.S3Bucket2.id}"
            MITIGATION_TABLE = "MitigationLog"
            S3_KEY = "mitigation_log.csv"
        }
    }
    function_name = "mitigation_log_exporter"
    handler = "lambda_function.lambda_handler"
    architectures = [
        "x86_64"
    ]
    s3_bucket = "awslambda-eu-n-1-tasks"
    s3_key = "/snapshots/821814521025/mitigation_log_exporter-929cd488-93a2-47f2-aca0-75c02bd7424c"
    s3_object_version = "5A226wUL_HpLiPyfaUHtiZU3kXOFVwpm"
    memory_size = 128
    role = "${aws_iam_role.IAMRole11.arn}"
    runtime = "python3.11"
    timeout = 3
    tracing_config {
        mode = "PassThrough"
    }
}

resource "aws_lambda_function" "LambdaFunction9" {
    description = ""
    function_name = "product"
    handler = "lambda_function.lambda_handler"
    architectures = [
        "x86_64"
    ]
    s3_bucket = "awslambda-eu-n-1-tasks"
    s3_key = "/snapshots/821814521025/product-98d73da9-f00c-49be-bf4f-3c1b4fa3eb50"
    s3_object_version = "IRTwJkKLOOMwgOqZaumW_JOZ9W.g3Kae"
    memory_size = 256
    role = "${aws_iam_role.IAMRole13.arn}"
    runtime = "python3.11"
    timeout = 3
    tracing_config {
        mode = "PassThrough"
    }
    layers = [
        "arn:aws:lambda:eu-north-1:821814521025:layer:common-utils:2"
    ]
}

resource "aws_lambda_function" "LambdaFunction10" {
    description = ""
    environment {
        variables {
            FINGERPRINT_TABLE = "fingerprints"
            S3_BUCKET = "${aws_s3_bucket.S3Bucket.id}"
            S3_KEY = "fingerprint_dataset.csv"
        }
    }
    function_name = "FingerprintS3Builder"
    handler = "lambda_function.lambda_handler"
    architectures = [
        "x86_64"
    ]
    s3_bucket = "awslambda-eu-n-1-tasks"
    s3_key = "/snapshots/821814521025/FingerprintS3Builder-a06e94a2-6385-4b84-98ef-465fd9cccc5d"
    s3_object_version = "Zt_F3Yh3UPDQcQtjcWpscJ2lPjjvu0BX"
    memory_size = 128
    role = "${aws_iam_role.IAMRole8.arn}"
    runtime = "python3.11"
    timeout = 3
    tracing_config {
        mode = "PassThrough"
    }
}

resource "aws_lambda_permission" "LambdaPermission" {
    action = "lambda:InvokeFunction"
    function_name = "${aws_lambda_function.LambdaFunction.arn}"
    principal = "events.amazonaws.com"
    source_arn = "arn:aws:events:eu-north-1:821814521025:rule/triggerRate"
}

resource "aws_lambda_permission" "LambdaPermission2" {
    action = "lambda:InvokeFunction"
    function_name = "${aws_lambda_function.LambdaFunction2.arn}"
    principal = "apigateway.amazonaws.com"
    source_arn = "arn:aws:execute-api:eu-north-1:821814521025:ezrgx1xle1/*/*/login"
}

resource "aws_lambda_permission" "LambdaPermission3" {
    action = "lambda:InvokeFunction"
    function_name = "${aws_lambda_function.LambdaFunction4.arn}"
    principal = "apigateway.amazonaws.com"
    source_arn = "arn:aws:execute-api:eu-north-1:821814521025:ezrgx1xle1/*/*/checkout"
}

resource "aws_lambda_permission" "LambdaPermission4" {
    action = "lambda:InvokeFunction"
    function_name = "${aws_lambda_function.LambdaFunction6.arn}"
    principal = "apigateway.amazonaws.com"
    source_arn = "arn:aws:execute-api:eu-north-1:821814521025:ezrgx1xle1/*/*/cart"
}

resource "aws_lambda_permission" "LambdaPermission5" {
    action = "lambda:InvokeFunction"
    function_name = "${aws_lambda_function.LambdaFunction7.arn}"
    principal = "apigateway.amazonaws.com"
    source_arn = "arn:aws:execute-api:eu-north-1:821814521025:ezrgx1xle1/*/*/search"
}

resource "aws_lambda_permission" "LambdaPermission6" {
    action = "lambda:InvokeFunction"
    function_name = "${aws_lambda_function.LambdaFunction9.arn}"
    principal = "apigateway.amazonaws.com"
    source_arn = "arn:aws:execute-api:eu-north-1:821814521025:ezrgx1xle1/*/*/product"
}

resource "aws_lambda_layer_version" "LambdaLayerVersion" {
    description = ""
    compatible_runtimes = [
        "python3.11"
    ]
    layer_name = "common-utils"
    s3_bucket = "awslambda-eu-n-1-layers"
    s3_key = "/snapshots/821814521025/common-utils-43f01da8-60fe-49ac-a367-67c00ba25e7f"
}

resource "aws_lambda_layer_version" "LambdaLayerVersion2" {
    description = ""
    compatible_runtimes = [
        "python3.11"
    ]
    layer_name = "scikit-learn"
    s3_bucket = "awslambda-eu-n-1-layers"
    s3_key = "/snapshots/821814521025/scikit-learn-351cd47b-5109-420d-a2ce-6856e0a3bf37"
}

resource "aws_lambda_layer_version" "LambdaLayerVersion3" {
    description = ""
    layer_name = "common-utils"
    s3_bucket = "awslambda-eu-n-1-layers"
    s3_key = "/snapshots/821814521025/common-utils-5a79f6f5-3d03-467f-8657-cb10203545f2"
}

resource "aws_lambda_layer_version" "LambdaLayerVersion4" {
    description = ""
    compatible_runtimes = [
        "python3.11"
    ]
    layer_name = "scikit-learn-py311"
    s3_bucket = "awslambda-eu-n-1-layers"
    s3_key = "/snapshots/821814521025/scikit-learn-py311-4c6df160-fe73-4d09-bc56-de7bb324593c"
}

resource "aws_lambda_layer_version" "LambdaLayerVersion5" {
    description = ""
    compatible_runtimes = [
        "python3.11"
    ]
    layer_name = "scikit-learn-161"
    s3_bucket = "awslambda-eu-n-1-layers"
    s3_key = "/snapshots/821814521025/scikit-learn-161-3c7617be-0169-4451-912e-050f57c692e1"
}

resource "aws_dynamodb_table" "DynamoDBTable" {
    attribute {
        name = "windowStart"
        type = "S"
    }
    billing_mode = "PAY_PER_REQUEST"
    name = "fingerprints"
    hash_key = "windowStart"
}

resource "aws_dynamodb_table" "DynamoDBTable2" {
    attribute {
        name = "timestamp"
        type = "S"
    }
    billing_mode = "PAY_PER_REQUEST"
    name = "MitigationLog"
    hash_key = "timestamp"
}

resource "aws_iam_role" "IAMRole" {
    path = "/service-role/"
    name = "cart-role-l0u83hcc"
    assume_role_policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"lambda.amazonaws.com\"},\"Action\":\"sts:AssumeRole\"}]}"
    max_session_duration = 3600
    tags = {}
}

resource "aws_iam_role" "IAMRole2" {
    path = "/service-role/"
    name = "checkout-role-gpbdome1"
    assume_role_policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"lambda.amazonaws.com\"},\"Action\":\"sts:AssumeRole\"}]}"
    max_session_duration = 3600
    tags = {}
}

resource "aws_iam_role" "IAMRole3" {
    path = "/"
    name = "ec2-k6-experiment-role"
    assume_role_policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"ec2.amazonaws.com\"},\"Action\":\"sts:AssumeRole\"}]}"
    max_session_duration = 3600
    tags = {}
}

resource "aws_iam_role" "IAMRole4" {
    path = "/service-role/"
    name = "DoWTestFunction-role-ozcs319p"
    assume_role_policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"lambda.amazonaws.com\"},\"Action\":\"sts:AssumeRole\"}]}"
    max_session_duration = 3600
    tags = {}
}

resource "aws_iam_role" "IAMRole5" {
    path = "/service-role/"
    name = "FingerprintAggregator-role-ndkkgd8p"
    assume_role_policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"lambda.amazonaws.com\"},\"Action\":\"sts:AssumeRole\"}]}"
    max_session_duration = 3600
    tags = {}
}

resource "aws_iam_role" "IAMRole6" {
    path = "/service-role/"
    name = "login-role-g5i74shi"
    assume_role_policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"lambda.amazonaws.com\"},\"Action\":\"sts:AssumeRole\"}]}"
    max_session_duration = 3600
    tags = {}
}

resource "aws_iam_role" "IAMRole7" {
    path = "/service-role/"
    name = "fingerprint-aggregator-role-d7yn24tz"
    assume_role_policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"lambda.amazonaws.com\"},\"Action\":\"sts:AssumeRole\"}]}"
    max_session_duration = 3600
    tags = {}
}

resource "aws_iam_role" "IAMRole8" {
    path = "/service-role/"
    name = "FingerprintS3Builder-role-6uwewnl8"
    assume_role_policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"lambda.amazonaws.com\"},\"Action\":\"sts:AssumeRole\"}]}"
    max_session_duration = 3600
    tags = {}
}

resource "aws_iam_role" "IAMRole9" {
    path = "/service-role/"
    name = "mitigation-role-yriq8qt5"
    assume_role_policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"lambda.amazonaws.com\"},\"Action\":\"sts:AssumeRole\"}]}"
    max_session_duration = 3600
    tags = {}
}

resource "aws_iam_role" "IAMRole10" {
    path = "/service-role/"
    name = "mitigation_config-role-ale90h3l"
    assume_role_policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"lambda.amazonaws.com\"},\"Action\":\"sts:AssumeRole\"}]}"
    max_session_duration = 3600
    tags = {}
}

resource "aws_iam_role" "IAMRole11" {
    path = "/service-role/"
    name = "mitigation_log_exporter-role-efnvblfh"
    assume_role_policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"lambda.amazonaws.com\"},\"Action\":\"sts:AssumeRole\"}]}"
    max_session_duration = 3600
    tags = {}
}

resource "aws_iam_role" "IAMRole12" {
    path = "/service-role/"
    name = "search-role-59g3btxc"
    assume_role_policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"lambda.amazonaws.com\"},\"Action\":\"sts:AssumeRole\"}]}"
    max_session_duration = 3600
    tags = {}
}

resource "aws_iam_role" "IAMRole13" {
    path = "/service-role/"
    name = "product-role-mesoh1zb"
    assume_role_policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"lambda.amazonaws.com\"},\"Action\":\"sts:AssumeRole\"}]}"
    max_session_duration = 3600
    tags = {}
}

resource "aws_iam_service_linked_role" "IAMServiceLinkedRole" {
    aws_service_name = "ops.apigateway.amazonaws.com"
    description = "The Service Linked Role is used by Amazon API Gateway."
}

resource "aws_iam_service_linked_role" "IAMServiceLinkedRole2" {
    aws_service_name = "resource-explorer-2.amazonaws.com"
}

resource "aws_iam_policy" "IAMManagedPolicy" {
    name = "AWSLambdaBasicExecutionRole-8234de80-e347-48df-b019-6e6f7bd5cda9"
    path = "/service-role/"
    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "logs:CreateLogGroup",
            "Resource": "arn:aws:logs:eu-north-1:821814521025:*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": [
                "arn:aws:logs:eu-north-1:821814521025:log-group:/aws/lambda/mitigation_log_exporter:*"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_policy" "IAMManagedPolicy2" {
    name = "AWSLambdaBasicExecutionRole-4dba5c0e-44f8-49d7-ba42-dc7a0fb78995"
    path = "/service-role/"
    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "logs:CreateLogGroup",
            "Resource": "arn:aws:logs:eu-north-1:821814521025:*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": [
                "arn:aws:logs:eu-north-1:821814521025:log-group:/aws/lambda/mitigation_config:*"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_policy" "IAMManagedPolicy3" {
    name = "AWSLambdaBasicExecutionRole-ccda8ec8-dbd8-4d87-a845-0e5d9c38f7ad"
    path = "/service-role/"
    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "logs:CreateLogGroup",
            "Resource": "arn:aws:logs:eu-north-1:821814521025:*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": [
                "arn:aws:logs:eu-north-1:821814521025:log-group:/aws/lambda/FingerprintAggregator:*"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_policy" "IAMManagedPolicy4" {
    name = "AWSLambdaBasicExecutionRole-00dfe418-cd68-4ee2-ac72-b3cdf7cd6733"
    path = "/service-role/"
    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "logs:CreateLogGroup",
            "Resource": "arn:aws:logs:eu-north-1:821814521025:*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": [
                "arn:aws:logs:eu-north-1:821814521025:log-group:/aws/lambda/cart:*"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_policy" "IAMManagedPolicy5" {
    name = "AWSLambdaBasicExecutionRole-8eb43f76-a7ad-4e21-8e26-b31878a2c143"
    path = "/service-role/"
    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "logs:CreateLogGroup",
            "Resource": "arn:aws:logs:eu-north-1:821814521025:*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": [
                "arn:aws:logs:eu-north-1:821814521025:log-group:/aws/lambda/fingerprint-aggregator:*"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_policy" "IAMManagedPolicy6" {
    name = "AWSLambdaBasicExecutionRole-856622ce-fa5e-406f-a5d6-428c102528d0"
    path = "/service-role/"
    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "logs:CreateLogGroup",
            "Resource": "arn:aws:logs:eu-north-1:821814521025:*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": [
                "arn:aws:logs:eu-north-1:821814521025:log-group:/aws/lambda/mitigation:*"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_policy" "IAMManagedPolicy7" {
    name = "AWSLambdaBasicExecutionRole-39949ed6-014a-4f11-962e-18cae5c82711"
    path = "/service-role/"
    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "logs:CreateLogGroup",
            "Resource": "arn:aws:logs:eu-north-1:821814521025:*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": [
                "arn:aws:logs:eu-north-1:821814521025:log-group:/aws/lambda/DoWTestFunction:*"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_policy" "IAMManagedPolicy8" {
    name = "AWSLambdaBasicExecutionRole-eabb01e0-5bd2-4150-9556-eaada8d9d55f"
    path = "/service-role/"
    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "logs:CreateLogGroup",
            "Resource": "arn:aws:logs:eu-north-1:821814521025:*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": [
                "arn:aws:logs:eu-north-1:821814521025:log-group:/aws/lambda/login:*"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_policy" "IAMManagedPolicy9" {
    name = "ec2-k6-experiment-rolePolicy"
    path = "/"
    policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":[\"events:EnableRule\",\"events:DisableRule\"],\"Resource\":\"arn:aws:events:eu-north-1:821814521025:rule/triggerRate\"}]}"
}

resource "aws_iam_policy" "IAMManagedPolicy10" {
    name = "AWSLambdaBasicExecutionRole-fe31e2bd-b069-4b94-ac5d-06312d8ceb27"
    path = "/service-role/"
    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "logs:CreateLogGroup",
            "Resource": "arn:aws:logs:eu-north-1:821814521025:*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": [
                "arn:aws:logs:eu-north-1:821814521025:log-group:/aws/lambda/FingerprintS3Builder:*"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_policy" "IAMManagedPolicy11" {
    name = "AWSLambdaBasicExecutionRole-486704db-5476-4b56-baeb-50732e3583e2"
    path = "/service-role/"
    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "logs:CreateLogGroup",
            "Resource": "arn:aws:logs:eu-north-1:821814521025:*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": [
                "arn:aws:logs:eu-north-1:821814521025:log-group:/aws/lambda/checkout:*"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_policy" "IAMManagedPolicy12" {
    name = "AWSLambdaBasicExecutionRole-8e0bae94-a14d-46ab-b923-b0506235c92d"
    path = "/service-role/"
    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "logs:CreateLogGroup",
            "Resource": "arn:aws:logs:eu-north-1:821814521025:*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": [
                "arn:aws:logs:eu-north-1:821814521025:log-group:/aws/lambda/search:*"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_policy" "IAMManagedPolicy13" {
    name = "AWSLambdaBasicExecutionRole-c602eff8-d901-4529-870d-d608c567bb15"
    path = "/service-role/"
    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "logs:CreateLogGroup",
            "Resource": "arn:aws:logs:eu-north-1:821814521025:*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": [
                "arn:aws:logs:eu-north-1:821814521025:log-group:/aws/lambda/product:*"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_role_policy" "IAMPolicy" {
    policy = <<EOF
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Sid": "DynamoDBTableManagement",
			"Effect": "Allow",
			"Action": [
				"dynamodb:CreateTable",
				"dynamodb:DeleteTable",
				"dynamodb:DescribeTable"
			],
			"Resource": [
				"arn:aws:dynamodb:eu-north-1:821814521025:table/fingerprints",
				"arn:aws:dynamodb:eu-north-1:821814521025:table/MitigationLog"
			]
		},
		{
			"Sid": "EventBridgeControl",
			"Effect": "Allow",
			"Action": [
				"events:EnableRule",
				"events:DisableRule"
			],
			"Resource": "arn:aws:events:eu-north-1:821814521045:rule/triggerRate"
		}
	]
}
EOF
    role = "${aws_iam_role.IAMRole3.name}"
}

resource "aws_iam_role_policy" "IAMPolicy2" {
    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Action": ["sns:Publish"],
      "Resource": "arn:aws:sns:eu-north-1:821814521025:DoWAlerts"
    }]
  }
EOF
    role = "${aws_iam_role.IAMRole7.name}"
}

resource "aws_iam_role_policy" "IAMPolicy3" {
    policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "MitigationThrottling",
      "Effect": "Allow",
      "Action": [
        "lambda:PutFunctionConcurrency",
        "lambda:DeleteFunctionConcurrency",
        "lambda:GetFunctionConcurrency"
      ],
      "Resource": [
        "arn:aws:lambda:eu-north-1:821814521025:function:checkout",
        "arn:aws:lambda:eu-north-1:821814521025:function:cart"
      ]
    },
    {
      "Sid": "MitigationLogging",
      "Effect": "Allow",
      "Action": ["dynamodb:PutItem"],
      "Resource": "arn:aws:dynamodb:eu-north-1:821814521025:table/MitigationLog"
    }
  ]
}
EOF
    role = "${aws_iam_role.IAMRole9.name}"
}

resource "aws_iam_role_policy" "IAMPolicy4" {
    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Action": ["s3:GetObject"],
      "Resource": "arn:aws:s3:::fingerprint-dataset-bucket/*"
    }]
  }
EOF
    role = "${aws_iam_role.IAMRole7.name}"
}

resource "aws_iam_role_policy" "IAMPolicy5" {
    policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "MitigationThrottling",
      "Effect": "Allow",
      "Action": [
        "lambda:PutFunctionConcurrency",
        "lambda:DeleteFunctionConcurrency",
        "lambda:GetFunctionConcurrency"
      ],
      "Resource": [
        "arn:aws:lambda:eu-north-1:821814521025:function:checkout",
        "arn:aws:lambda:eu-north-1:821814521025:function:cart"
      ]
    }
  ]
}
EOF
    role = "${aws_iam_role.IAMRole7.name}"
}

resource "aws_iam_instance_profile" "IAMInstanceProfile" {
    path = "/"
    name = "${aws_iam_role.IAMRole3.name}"
    roles = [
        "${aws_iam_role.IAMRole3.name}"
    ]
}

resource "aws_cloudwatch_event_rule" "EventsRule" {
    name = "triggerRate"
    description = "Scheduales the program to run the functions every five minutes"
    schedule_expression = "rate(5 minutes)"
}

resource "aws_cloudwatch_event_target" "CloudWatchEventTarget" {
    rule = "triggerRate"
    arn = "arn:aws:events:eu-north-1:821814521025:rule/triggerRate"
}

resource "aws_sns_topic" "SNSTopic" {
    display_name = ""
    name = "DoWAlerts"
}

resource "aws_sns_topic_policy" "SNSTopicPolicy" {
    policy = "{\"Version\":\"2008-10-17\",\"Id\":\"__default_policy_ID\",\"Statement\":[{\"Sid\":\"__default_statement_ID\",\"Effect\":\"Allow\",\"Principal\":{\"AWS\":\"*\"},\"Action\":[\"SNS:GetTopicAttributes\",\"SNS:SetTopicAttributes\",\"SNS:AddPermission\",\"SNS:RemovePermission\",\"SNS:DeleteTopic\",\"SNS:Subscribe\",\"SNS:ListSubscriptionsByTopic\",\"SNS:Publish\"],\"Resource\":\"arn:aws:sns:eu-north-1:821814521025:DoWAlerts\",\"Condition\":{\"StringEquals\":{\"AWS:SourceOwner\":\"821814521025\"}}}]}"
    arn = "arn:aws:sns:eu-north-1:821814521025:DoWAlerts"
}

resource "aws_sns_topic_subscription" "SNSSubscription" {
    topic_arn = "arn:aws:sns:eu-north-1:821814521025:DoWAlerts"
    endpoint = "carlpettermr1@gmail.com"
    protocol = "email"
}
