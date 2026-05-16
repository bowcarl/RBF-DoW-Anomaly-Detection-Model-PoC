# cart.py
import json
from common import simulate_latency, random_error

def lambda_handler(event, context):

    print({
        "function": "cart",
        "userAgent": event.get("headers", {}).get("User-Agent", "unknown")
    })

    simulate_latency(0.15, 0.07)
    random_error(0.015)

    return {
        "statusCode": 200,
        "body": json.dumps({"cart": "updated"})
    }
