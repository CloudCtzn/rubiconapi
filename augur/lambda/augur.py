import json
import boto3
import uuid
from datetime import datetime, timezone 
from decimal import Decimal
import os 

RAPIDAPI_SECRET = os.environ.get("RAPIDAPI_SECRET")

#Section 1 - AWS Clients 
comprehend = boto3.client("comprehend")
dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table("rubicon-augur-results")

def build_summary(sentiment, confidence):
    summaries = {
        "positive": f"Text carries a positive tone with {confidence}% confidence",
        "negative": f"Text carries a negative tone with {confidence}% confidence",
        "neutral": f"Text is largely neutral with {confidence}% confidence",
        "mixed": f"Test carries a mixed sentiment with {confidence}% confidence"
    }
    return summaries.get(sentiment, "Unable to determine sentiment")

def response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*"
        },
        "body": json.dumps(body, default=str),
    }

#Section 2 - The Handler 
def lambda_handler(event, context):
    try:
        headers = event.get("headers", {})
        proxy_secret = headers.get("x-rapidapi-proxy-secret")

        if not proxy_secret or proxy_secret != RAPIDAPI_SECRET:
            return response(403, {"error": "Forbidden"})
        
        body = json.loads(event.get("body", "{}"))
        text = body.get("text", "").strip()

        if not text:
            return response(400, {"error": "Missing required field: text"})
        if len(text) > 5000:
            return response(400, {"error": "Text exceeds maximum length of 5000 characters"})
        
        result = comprehend.detect_sentiment(Text=text, LanguageCode="en")
        scores = result["SentimentScore"]
        sentiment = result["Sentiment"].lower()
        dominant_score = round(scores[result["Sentiment"].title()] * 100, 1)

        output = {
            "id": str(uuid.uuid4()),
            "sentiment": sentiment,
            "confidence": Decimal(str(dominant_score)),
            "scores": {
                "positive": Decimal(str(round(scores["Positive"] * 100, 1))),
                "negative": Decimal(str(round(scores["Negative"] * 100, 1))),
                "neutral": Decimal(str(round(scores["Neutral"] * 100, 1))),
                "mixed": Decimal(str(round(scores["Mixed"] * 100, 1)))
            },
            "summary": build_summary(sentiment, dominant_score),
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "char_count": len(text)
        }

        table.put_item(Item=output)
        return response(200, output)
    
    except comprehend.exceptions.TextSizeLimitExceededException:
        return response(400, {"error": "Text is too large for analysis"})
    except Exception as e:
        print(f"Error: {str(e)}")
        return response(500, {"error": "Internal Server Error"})
    