import json 
import boto3
import uuid
from datetime import datetime, timezone

bedrock = boto3.client("bedrock-runtime", region_name="us-east-1")
dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table("rubicon-consul-results")

def build_prompt(text):
    return f"""You are a professional text summarization engine. Analyze the following text and respond ONLY with a valid JSON object, no preamble, no explanation, no markdown backticks

The JSON must follow this exact structure:
{{
    "summary": "A concise 2-3 sentence summary of the text",
    "key_points": ["First key point", "Second key point", "Third key point"]
}}

Text to analyze:
{text}"""

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
        if len(text) > 10000:
            return response(400, {"error": "Text exceeds maximum length of 10000 characters"})
        
        bedrock_response = bedrock.invoke_model(
            modelId="us.anthropic.claude-haiku-4-5-20251001-v1:0",
            body=json.dumps({
                "anthropic_version": "bedrock-2023-05-31",
                "max_tokens": 1024,
                "messages": [
                    {
                        "role": "user",
                        "content": build_prompt(text)
                    }
                ]
            })  
        )

        bedrock_body = json.loads(bedrock_response["body"].read())
        raw_text = bedrock_body["content"][0]["text"].strip()
        print(f"Raw AI response: {raw_text}")
        raw_text = raw_text.replace("```json", "").replace("```", "").strip()
        ai_output = json.loads(raw_text)

        original_word_count = len(text.split())
        summary_word_count = len(ai_output["summary"].split())
        reduction = round((1 - summary_word_count / original_word_count) * 100, 1)

        output = {
            "id": str(uuid.uuid4()),
            "summary": ai_output["summary"],
            "key_points": ai_output["key_points"],
            "word_count_original": original_word_count,
            "word_count_summary": summary_word_count,
            "reduction_percentage": f"{reduction}%",
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "char_count": len(text)
        }

        table.put_item(Item=output)
        return response(200, output)
    
    except json.JSONDecodeError:
        return response(500, {"error": "Failed to parse AI response"})
    except Exception as e:
        print(f"Error: {str(e)}")
        return response(500, {"error": "Internal Server Error"})

