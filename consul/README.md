# Consul

Text summarization API — part of the RubiconAPI suite.

Send text, get back a structured summary. Consul condenses long form content 
into a concise summary, extracts key points, and tells you exactly how much 
the text was reduced — all in a single API call.

Built on AWS Lambda, Bedrock, API Gateway, and DynamoDB. 
Fully serverless, scales automatically with your usage.

---

## Endpoint

POST https://{your-api-gateway-url}/prod/consul

To get access to the hosted version, grab an API key on RapidAPI.
To self-host, follow the deploy instructions below.

---

## Request

Content-Type: application/json

{
  "text": "Your text here — up to 10000 characters"
}

---

## Response

{
  "id": "b7f2d914-3c8a-4e61-9d05-a2c6f8e04b31
",
  "summary": "A concise 2-3 sentence summary of your text.",
  "key_points": [
    "First key point extracted from the text",
    "Second key point extracted from the text",
    "Third key point extracted from the text"
  ],
  "word_count_original": 59,
  "word_count_summary": 43,
  "reduction_percentage": "27.1%",
  "timestamp": "2026-06-12T02:12:23.280066+00:00",
  "char_count": 400
}

| Field                | Description                                          |
|----------------------|------------------------------------------------------|
| id                   | Unique identifier for this summarization             |
| summary              | Concise 2-3 sentence summary of the input text       |
| key_points           | Array of the three most important points             |
| word_count_original  | Word count of the original text                      |
| word_count_summary   | Word count of the generated summary                  |
| reduction_percentage | How much the text was condensed                      |
| timestamp            | UTC timestamp of when the summary was generated      |
| char_count           | Number of characters analyzed                        |

---

## Error Codes

| Status | Message                                          |
|--------|--------------------------------------------------|
| 400    | Missing required field: text                     |
| 400    | Text exceeds maximum length of 10000 characters  |
| 500    | Internal Server Error                            |
| 500    | Failed to parse AI response                      |

---

## Deploy It Yourself

Prerequisites: AWS CLI configured, Terraform >= 1.5, Python 3.12

git clone https://github.com/CloudCtzn/rubiconapi.git
cd rubiconapi/consul/terraform
terraform init
terraform plan
terraform apply

Your endpoint URL will print to the terminal when it finishes.

---

## Architecture

API Gateway → Lambda (Python 3.12) → AWS Bedrock (Claude) → DynamoDB

---

## Part of the RubiconAPI Suite

| API     | Description           | Status         |
|---------|-----------------------|----------------|
| Augur   | Sentiment Analysis    | ✅ Live        |
| Consul  | Text Summarization    | ✅ Live        |
| Specula | Keyword Extraction    | 🔜 Coming Soon |

---

Built by CloudCtzn