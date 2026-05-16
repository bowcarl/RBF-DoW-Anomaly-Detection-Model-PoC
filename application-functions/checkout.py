# checkout.py
import json
from common import simulate_latency, random_error

def lambda_handler(event, context):
    
    print({
        "function": "checkout",
        "userAgent": event.get("headers", {}).get("User-Agent", "unknown")
    })

    simulate_latency(0.4, 0.2)   # heavy
    random_error(0.03)

    return {
        "statusCode": 200,
        "body": json.dumps({"payment": "processed"})
    }
