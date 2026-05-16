# search.py
import json
import random
from common import simulate_latency, random_error

def lambda_handler(event, context):

    print({
        "function": "search",
        "userAgent": event.get("headers", {}).get("User-Agent", "unknown")
    })

    simulate_latency(0.12, 0.08)
    random_error(0.02)

    results = random.randint(0, 50)

    return {
        "statusCode": 200,
        "body": json.dumps({"results": results})
    }
