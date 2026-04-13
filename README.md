# RBF-DoW Anomaly Detection Model - PoC

A Proof of Concept for detecting Denial-of-Wallet (DoW) attacks using anomaly detection with machine learning (RBF/scikit-learn) on AWS serverless infrastructure.

## Overview

This project monitors API traffic patterns and automatically detects and mitigates DoW attacks — attacks that exploit pay-per-use cloud services to drive up costs. When an anomaly is detected, an SNS alert is sent and mitigation is triggered automatically.

## Architecture

| Service | Purpose |
|---|---|
| **Lambda** | Core logic — aggregation, detection, mitigation, API handlers |
| **DynamoDB** | Stores fingerprint data and mitigation logs |
| **S3** | Stores fingerprint datasets and mitigation exports |
| **EventBridge** | Triggers the fingerprint aggregator every 5 minutes |
| **SNS** | Sends alerts when an anomaly is detected |
| **API Gateway** | Exposes REST endpoints (login, cart, checkout, search, product) |
| **IAM** | Roles and policies for each Lambda function |

## Lambda Functions

| Function | Description |
|---|---|
| `fingerprint-aggregator` | Aggregates traffic fingerprints and runs anomaly detection |
| `FingerprintS3Builder` | Exports fingerprint data to S3 |
| `mitigation` | Applies throttling to affected Lambda functions |
| `mitigation_config` | Configures mitigation parameters |
| `mitigation_log_exporter` | Exports mitigation logs to S3 |
| `login` | API handler — user login |
| `cart` | API handler — shopping cart |
| `checkout` | API handler — checkout |
| `search` | API handler — product search |
| `product` | API handler — product details |

## Infrastructure as Code

The AWS environment is defined in `environment.tf` and was exported using [Former2](https://former2.com).

### Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.0
- AWS CLI configured with appropriate credentials
- AWS account access to `eu-north-1` (Stockholm)

### Deploy

```bash
# 1. Initialize Terraform
terraform init

# 2. Preview changes
terraform plan

# 3. Apply infrastructure
terraform apply
```

### Destroy

```bash
terraform destroy
```

## Region

All resources are deployed in **eu-north-1 (Stockholm)**.

## Alerts

SNS alerts are sent to the configured email on anomaly detection. Confirm the subscription in your email after first deployment.
