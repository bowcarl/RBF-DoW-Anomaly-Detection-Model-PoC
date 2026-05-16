import boto3
import csv
import io
import os
from decimal import Decimal

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ['FINGERPRINT_TABLE'])

s3 = boto3.client("s3")
S3_BUCKET = os.environ['S3_BUCKET']
S3_KEY = os.environ.get('S3_KEY', 'fingerprint_dataset.csv')

AGGREGATE_KEYS = [
    'checkoutToLoginRatio',
    'cartToSearchRatio',
    'highMemFraction',
    'totalEstimatedCost',
    'invocationEntropy',
    'totalInvocations',
    'hour_of_day',
]

PER_FUNCTION_KEYS = [
    'invocations_login',
    'invocations_search',
    'invocations_product',
    'invocations_cart',
    'invocations_checkout',
    'avgDurationMs_login',
    'avgDurationMs_search',
    'avgDurationMs_product',
    'avgDurationMs_cart',
    'avgDurationMs_checkout',
    'estimatedCost_login',
    'estimatedCost_search',
    'estimatedCost_product',
    'estimatedCost_cart',
    'estimatedCost_checkout',
]

FEATURE_KEYS = AGGREGATE_KEYS + PER_FUNCTION_KEYS


def decimal_to_float(val):
    if isinstance(val, Decimal):
        return float(val)
    return val


def lambda_handler(event, context):
    items = []
    response = table.scan()
    items.extend(response.get('Items', []))

    while 'LastEvaluatedKey' in response:
        response = table.scan(ExclusiveStartKey=response['LastEvaluatedKey'])
        items.extend(response.get('Items', []))

    # Sort chronologically — required for delta calculation
    items.sort(key=lambda x: x.get('windowStart', ''))

    output = io.StringIO()
    writer = csv.writer(output)

    # windowStart and anomalyTier added to header
    header = ['windowStart'] + FEATURE_KEYS + [
        'deltaTotalInvocations',
        'deltaTotalEstimatedCost',
        'anomaly',
        'anomalyScore',
        'anomalyTier',
    ]
    writer.writerow(header)

    exported_count = 0
    skipped_count  = 0
    prev_inv  = None
    prev_cost = None

    for item in items:
        if item.get('windowStart') is None:
            skipped_count += 1
            continue

        curr_inv  = decimal_to_float(item.get('totalInvocations', 0))
        curr_cost = decimal_to_float(item.get('totalEstimatedCost', 0))

        delta_inv  = (curr_inv  - prev_inv)  if prev_inv  is not None else 0.0
        delta_cost = (curr_cost - prev_cost) if prev_cost is not None else 0.0

        prev_inv  = curr_inv
        prev_cost = curr_cost

        row = [item.get('windowStart', '')]
        row += [decimal_to_float(item.get(key, 0)) for key in FEATURE_KEYS]
        row.append(delta_inv)
        row.append(delta_cost)
        row.append(0)
        row.append(0.0)
        row.append(item.get('anomalyTier', ''))   # NORMAL / WARNING / ALERT

        writer.writerow(row)
        exported_count += 1

    output.seek(0)
    s3.put_object(
        Bucket=S3_BUCKET,
        Key=S3_KEY,
        Body=output.getvalue()
    )

    print(f"Exported {exported_count} records, skipped {skipped_count} corrupted records")

    return {
        "statusCode": 200,
        "body": f"{exported_count} fingerprint records exported to S3"
    }
