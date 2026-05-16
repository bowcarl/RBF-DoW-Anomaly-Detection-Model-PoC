# product.py
import json
from common import simulate_latency, random_error

def lambda_handler(event, context):

    print({
        "function": "product",
        "userAgent": event.get("headers", {}).get("User-Agent", "unknown")
    })
    
    simulate_latency(0.10, 0.05)
    random_error(0.01)

    return {
        "statusCode": 200,
        "body": json.dumps({"product": "example"})
    }
