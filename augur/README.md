# Augur
Sentiment Analysis API - part of the RubiconAPI suite. 

Send text, get back a full sentiment breakdown. Positive, negative, neutral, or mixed - Augur tells you what the words actually mean emotionally, with confidence scores and plain English summaries included. 

Built on AWS Lambda, Comprehend, API Gateway, and DynamoDB. 

---

## Endpoint 

POST https://{your-api-gateway-url}/prod/augur

To get access to the hosted version, grab an API key on RapidAPI.
To self-host, follow the deploy instructions below. 

---

## Request 
Content-Type: application/json

{
  "id": "194cb022-36ea-4168-8b46-63b640f5cf9f",
  "sentiment": "positive",
  "confidence": "100.0",
  "scores": {
    "positive": "100.0",
    "negative": "0.0",
    "neutral": "0.0",
    "mixed": "0.0"
  },
  "summary": "Text carries a positive tone with 100.0% confidence",
  "timestamp": "2026-05-29T05:33:23.655845+00:00",
  "char_count": 46
}

| Field       | Description                                      |
|-------------|--------------------------------------------------|
| id          | Unique identifier for this analysis              |
| sentiment   | Overall sentiment — positive, negative, neutral, mixed |
| confidence  | Confidence score for the dominant sentiment (%)  |
| scores      | Breakdown of all four sentiment scores           |
| summary     | Plain English summary of the result              |
| timestamp   | UTC timestamp of when the analysis was run       |
| char_count  | Number of characters analyzed                    |

---

## Error Codes

| Status | Message                                    |
|--------|--------------------------------------------|
| 400    | Missing required field: text               |
| 400    | Text exceeds maximum length of 5000 characters |
| 500    | Internal Server Error                      |

---

## Deploy It Yourself

Prerequisites: AWS CLI configured, Terraform >= 1.5, Python 3.12

git clone https://github.com/CloudCtzn/rubiconapi.git
cd rubiconapi/augur/terraform
terraform init
terraform plan
terraform apply

Your endpoint URL will print to the terminal when it finishes.

---

## Architecture

API Gateway → Lambda (Python 3.12) → AWS Comprehend → DynamoDB

---

## Part of the RubiconAPI Suite

| API     | Description           | Status      |
|---------|-----------------------|-------------|
| Augur   | Sentiment Analysis    | ✅ Live     |
| Consul  | Text Summarization    | 🔜 Coming Soon |
| Specula | Keyword Extraction    | 🔜 Coming Soon |

---

Built by CloudCtzn ☁️