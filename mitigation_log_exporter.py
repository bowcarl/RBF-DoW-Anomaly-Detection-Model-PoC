"""
mitigation_log_exporter.py
──────────────────────────
Exports the MitigationLog DynamoDB table to a CSV in S3.
Deploy as a separate Lambda function with these environment variables:
    MITIGATION_TABLE  — DynamoDB table name (e.g. MitigationLog)
    S3_BUCKET         — same bucket as your fingerprint exporter
    S3_KEY            — output filename (e.g. mitigation_log.csv)
"""

import boto3
import csv
import io
import os
from decimal import Decimal

dynamodb = boto3.resource("dynamodb")
table    = dynamodb.Table(os.environ['MITIGATION_TABLE'])

s3        = boto3.client("s3")
S3_BUCKET = os.environ['S3_BUCKET']
S3_KEY    = os.environ.get('S3_KEY', 'mitigation_log.csv')

def decimal_to_float(val):
    if isinstance(val, Decimal):
        return float(val)
    return val

def lambda_handler(event, context):
    # ── Scan full table ───────────────────────────────────────────
    items    = []
    response = table.scan()
    items.extend(response.get('Items', []))

    while 'LastEvaluatedKey' in response:
        response = table.scan(ExclusiveStartKey=response['LastEvaluatedKey'])
        items.extend(response.get('Items', []))

    if not items:
        print("No items found in MitigationLog table.")
        return {'statusCode': 200, 'body': '0 records exported'}

    # ── Sort chronologically ──────────────────────────────────────
    items.sort(key=lambda x: x.get('timestamp', ''))

    # ── Build CSV ─────────────────────────────────────────────────
    # Collect all unique keys across all items so no column is missed
    all_keys = set()
    for item in items:
        all_keys.update(item.keys())

    # Put important columns first, rest alphabetically
    priority = ['timestamp', 'event_type', 'if_score', 'dry_run',
                'targets', 'failed', 'checkoutToLoginRatio', 'cartToSearchRatio']
    ordered_keys = priority + sorted(k for k in all_keys if k not in priority)

    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(ordered_keys)

    exported_count = 0
    for item in items:
        row = []
        for key in ordered_keys:
            val = item.get(key, '')
            row.append(decimal_to_float(val) if isinstance(val, Decimal) else val)
        writer.writerow(row)
        exported_count += 1

    # ── Upload to S3 ──────────────────────────────────────────────
    output.seek(0)
    s3.put_object(
        Bucket=S3_BUCKET,
        Key=S3_KEY,
        Body=output.getvalue()
    )

    print(f"Exported {exported_count} mitigation log records to s3://{S3_BUCKET}/{S3_KEY}")

    return {
        'statusCode': 200,
        'body': f"{exported_count} mitigation log records exported to S3"
    }