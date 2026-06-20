# Rubicon API 
> *Cross it once, you never go back*
A suite of open source text intelligence APIs built on AWS serverless infrastructure. Free to use, free to fork, free to self-host. 
---
## APIs
| APIs | Description | Endpoint |
|------|-------------|----------|
| Augur | Sentiment Analysis | ```POST /augur``` |
| Consul | Text Summarization | ```POST /consul``` |
| Specula | Keyword Extraction | ```POST /specula``` |
---
## What is RubiconAPI?
RubiconAPI is a collection of text intelligence APIs designed for developers who need powerful text analysis without the complexity of managing AI infrastructure. Every API is built on AWS serverless infrastructure using Lambda. API Gateway, DynamoDB, and AWS AI services. 

Each API is independently deployable, open source, and comes with full Terraform IaC so you can spin it up on your own instance in minutes. 
---
## Architecture 
Every API in the suite follows the same service pattern. 

```
POST Request

    ⬇

API Gateway (HTTP API)
    
    ⬇

Lambda (Python 3.12)
    
    ⬇

AWS AI Service (Comprehend / Bedrock)

    ⬇

DynamoDB (Result Storage)

    ⬇

JSON Response
```
---
## Self Hosting 
Each API can be deployed independently to your own AWS account. 

Prequisites: AWS CLI configured, Terraform >= 1.5, Python 3.12
```bash
git clone https://github.com/CloudCtzn/rubiconapi.git

# Deploy Augur
cd rubiconapi/augur/terraform
terraform init
terraform apply

# Deploy Consul
cd ../../consul/terraform 
terraform init
terraform apply

# Deploy Specula
cd ../../specula/terraform
terraform init
terraform apply
```
Your endpoint URLs will print to the terminal when each deploy finishes. 
---
## AWS Services Used 
| Service | Purpose |
|---------|---------|
| AWS Lambda | Serverless Compute |
| API Gateway | HTTP API |
| DynamoDB | Result Persistence | 
| AWS Comprehend | Sentiment analysis and keyword extraction | 
| AWS Bedrock | AI powered text summarization | 
| IAM | Least privilege access control | 
---
## Cost to self-host 
Running all three APIs stays well within the free tier limits for personal or low volume use. 
| Service | Free Tier |
|---------|-----------|
| Lambda | 1M requests/month |
| API Gateway | 1M requests/month |
| Comprehend | 50k units/month for 12 months |
| DynamoDB | 25GB storage forever | 

Estimated cost beyond the free tier: less than $1 per 10k requests
---
## License 
MIT License - free to use, modify, and self-host

If you find this useful, a ⭐ on Github and a mention goes a long way. Built by CLoudCtzn. 
---
## Built With 
- Python 3.12 
- Terraform >= 1.5
- AWS Lambda, API Gateway, DynamoDB, Comprehend, Bedrock.

