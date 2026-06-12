# Specula

Keyword extraction API — part of the RubiconAPI suite.

Send text, get back the most important phrases and named entities — 
people, organizations, locations, dates — automatically categorized 
and deduplicated. No more manually reading through content to find 
what matters.

Built on AWS Lambda, Comprehend, API Gateway, and DynamoDB.
Fully serverless, scales automatically with your usage.

---

## Endpoint

POST https://{your-api-gateway-url}/prod/specula

To get access to the hosted version, grab an API key on RapidAPI.
To self-host, follow the deploy instructions below.

---

## Request

Content-Type: application/json

{
  "text": "Your text here — up to 5000 characters"
}

---

## Response

{
  "id": "b7f2d914-3c8a-4e61-9d05-a2c6f8e04b31
",
  "key_phrases": [
    "Amazon Web Services",
    "cloud computing platform",
    "wide range of services",
    "millions of businesses",
    "high availability"
  ],
  "entities": {
    "ORGANIZATION": ["Amazon Web Services", "AWS"],
    "QUANTITY": ["millions of businesses"]
  },
  "phrase_count": 14,
  "entity_count": 3,
  "timestamp": "2026-06-12T04:57:36.721317+00:00",
  "char_count": 400
}

| Field        | Description                                              |
|--------------|----------------------------------------------------------|
| id           | Unique identifier for this extraction                    |
| key_phrases  | Top 10 key phrases ranked by confidence score            |
| entities     | Named entities categorized by type                       |
| phrase_count | Total number of phrases detected before ranking          |
| entity_count | Total number of entities detected                        |
| timestamp    | UTC timestamp of when the extraction was run             |
| char_count   | Number of characters analyzed                            |

## Entity Types

Comprehend can detect the following entity types:

| Type         | Description                        |
|--------------|------------------------------------|
| PERSON       | People's names                     |
| ORGANIZATION | Companies, agencies, institutions  |
| LOCATION     | Physical locations                 |
| DATE         | Dates and time periods             |
| QUANTITY     | Measurements and amounts           |
| EVENT        | Named events                       |
| TITLE        | Titles of works                    |

---

## Error Codes

| Status | Message                                          |
|--------|--------------------------------------------------|
| 400    | Missing required field: text                     |
| 400    | Text exceeds maximum length of 5000 characters   |
| 500    | Inter