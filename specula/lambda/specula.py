import json 
import boto3
import uuid
from datetime import datetime, timezone



comprehend = boto3.client("comprehend")
dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table("rubicon-specula-results")

def response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*"
        },
        "body": json.dumps(body)
    }

def lambda_handler(event, context):
    try:
        body = json.loads(event.get("body", "{}"))
        text = body.get("text", "").strip()
        
        if not text:
            return response(400, {"error": "Missing required field: text"})
        if len(text) > 5000:
            return response(400, {"error": "Text exceeds maximum length of 5,000 characters"})
        

        phrases_result = comprehend.detect_key_phrases(
            Text=text,
            LanguageCode="en"
        )

        entities_result = comprehend.detect_entities(
            Text=text,
            LanguageCode="en"
        )

        key_phrases = sorted(
            phrases_result["KeyPhrases"],
            key=lambda x: x["Score"],
            reverse=True
        )[:10]

        entities = {}
        for entity in entities_result["Entities"]:
            entity_type = entity["Type"]
            entity_text = entity["Text"]
            if entity_type not in entities:
                entities[entity_type] = []
            if entity_text not in entities[entity_type]:
                entities[entity_type].append(entity_text)

        output = {
            "id": str(uuid.uuid4()),
            "key_phrases": [p["Text"] for p in key_phrases],
            "entities": entities,
            "phrase_count": len(phrases_result["KeyPhrases"]),
            "entity_count": len(entities_result["Entities"]),
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "char_count": len(text)
            }
        
        table.put_item(Item=output)
        return response(200, output)
    except Exception as e:
        print(f"Error: {str(e)}")
        return response(500, {"error": "Internal Server Error"})

