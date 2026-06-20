# RubiconAPI - Troubleshooting Guide 
A documented record of every error encountered building the RubiconAPI suite and how each one was resolved. Written for developers who run into the same walls. 

---

## Table of Contents 
1. DynamoDB Float Serialization Error
2. API Gateway Route Key Format
3. Terraform Not Detecting Code Changes / API Gateway Breaking on Lambda Replace
4. Bedrock Model ID and Inference Profile
5. AWS Marketplace Subscription Expiry
6. Claude Ignorng JSON Format Instructions 
7. KMS Encryption on Lambda Recreation 
8. Terraform IAM Policy Not Applying Correctly
9. Comprehend Method and Parameter Typos 


---

## 1. DynamoDB Float Serialization Error 
**The Error**

```Error: Float types are not supported. Use Decimal types instead.```

**What Caused It**

AWS Comprehend returns sentiment confidence scores as Python float values (e.g ```0.987```). When I tried to store these directly in DynamoDB, it rejected them. DynamoDB does not support Pythons native float type. 

**The Fix**

Import Python's ```Decimal``` type and wrap every float value before storing it. 

```Python
from decimal import Decimal

"confindence": Decimal(str(dominant_score)),
"scores": {
    "positive": Decimal(str(round(scores["Positive"] * 100, 1))),
    "negative": Decimal(str(round(scores["Negative"] * 100, 1))),
    "neutral": Decimal(str(round(scores["Neutral"] * 100, 1))),
    "mixed": Decimal(str(round(scores["Mixed"] * 100, 1)))
}
```
The ```str()``` wrapper before ```Decimal``` is important, converting float directly to Decimal can introduce floating point precison errors. Converting to string first avoids that. 

**Bonus Issue** 

Even after fixing DynamoDB storage. ```json.dumps()``` in the response function also chokes on Decimal types. Fix that by adding ```default=str```to your response serializer.

```python
"body": json.dumps(body, default=str)
```

---

## 2. API Gateway Route Key Format

**The Error**

```Error: creating API Gateway v2 Route: operation error ApiGatewayV2: CreateRoute, https response error StatusCode: 400, BadRequestException: The provided route key is not formatted properly for HTTP protocol. Format should be "[HTTP METHOD] /[RESOURCE PATH]" or "$default"```

**What Caused It**

A simple typo in the Terraform route key, missing a space between the HTTP method and the path:

```
hcl 

route_key = "POST/augur" # ❌ wrong, no space
```

**The Fix**

API Gateway requires an exact space between the method and the path:

```
hcl 

route_key = "POST /augur" # ✅ correct 
```

A single missing character broke the entire deploy. Always double check route keys character by character, Terraform's error message tells you exactly what's wrong, but it's easy to skim past a missing space. 

---

## 3. Terraform Not Detecting Code Changes / API Gateway Breaking on Replace

**The Error**

After fixing code and running ```terraform apply```, the Lambda would update but the API would suddenly return ```Internal Server Error``` with no logs at all, meaning the Lambda wasn't even being invoked.

**What Caused It**

Two related issues:
1. Sometimes plain ```terraform apply``` doesn't pick up Lambda code change if the archive hash isn't recalculated properly in the Terraform state.
2. When forcing a fix with ```terraform apply -replace=aws_lambda_function.x```, Terraform destroys and recreates the Lambda with a **new ARN**. The existing API Gateway integration is still pointing at the old ARN, so requests silently fail with no logs, because API Gateway can't reach the Lambda at all. 

**The Fix**

When you must replace a Lambda function, replace the entire chain in the same command so everything reconnects correctly:
```bash
terraform apply \ 
    -replace=aws_lambda_function.augur \
    -replace=aws_apigatewayv2_api.rubicon \
    -replace=aws_apigatewayv2_stage.rubicon \
    -replace=aws_apigatewayv2_integration.augur \
    -replace=aws_apugatewatv2_route.augur \
    -replace=aws_lambda_permission.augur_apigw
```

This forces Terraform to rebuild the Lambda, the API Gateway, the integration, the route, and the permission together so all the ARNs stay in sync. A new API endpoint URL will be generated each time this runs, expect to update any place that references the old URL. 

**Lesson Learned** 

Whenever possible, prefer letting Terraform do an in-place update (```terraform apply``` with no flags) instead of forcing a ```-replace```. In-place updates preserve the Lambda ARN and never break the API Gateway connection. 

---

## 4. Bedrock Model ID and Inference Profile Confusion

**The Error (multiple, in sequence)**

```ValidationException: The provided model identifier is invalid.```

```ValidationException: Invocation of model ID anthropic.claude-haiku-4-5-20251001-v1:0 with on-demand throughput isn't supported. Retry your request with the ID or ARN of an inference profile that contains this model```

```AccessDeniedException: ... not authorized to perform: bedrock:InvokeModel on resource: arn:aws:bedrock:us-east-1::foundation-model/... because no identity-based policy allows the bedrock:InvokeModel action```

**What Caused It**

This was the single hardest issue of the whole build. Several layered problems stacked on top of each other. 
1. Some Bedrock model IDs are marked ```LEGACY``` and can no longer be invoked, only ```Active``` models work. Check available models with:
```bash
aws bedrock list-foundation-models --query 'modelSummaries[?contains(modelId, 'anthropic')].[modelId,modelLifecycle.status]' --output table
```

2. Some active models require **on-demand throughput via an inference profile**, meaning the model ID in code needs a ```us.``` regional prefix:
```bash
modelId="us.anthropic.claude-haiku-4-5-20251001-v1:0"
```

3. The IAM policy ARM format for an inference profile is different from a standard foundational model ARN, and AWS's actual resolved ARN didn't always match wbat the documentaiton implied (sometimes with an account ID, sometimes without). 

**The Fix**

After multiple failed attempts at the "exact" inference-profile ARN format, the pragmatic fix was to scope the IAM policy with a wildcard resource for this specific action:
``` 
hcl 

{
    Effect = "Allow"
    Action = ["bedrock:InvokeModel"]
    Resource = "*"
}
```

Combind with th ```us.``` prefix in the modelId, this finally worked reliably. 

**Lesson Learned**

Bedrock's model access model (foundation models vs. inference profiles vs. marketplace subscriptions) has several moving parts that don't always match the error messages exactly. When fighting an ARN format for more than two or three attempts, scoping to a wildcard and tightening later is a reasonable pragmatic choice to keep moving. 

---

## 5. AWS Marketplace Subscription Expiry / Billing 

**The Error**

```AccessDeniedException: Model access is denied due to INVALID_PAYMENT_INSTRUMENT: A valid payment instrument must must be provided. Your AWS Marketplace subscription for this model cannot be completed at this time.```

**What Caused It**

Anthropic models on Bedrock are distributed through AWS Marketplace, which requires:
1. A valid payment method on the AWS account
2. No outstanding balance on the account 
3. A one-time "use case details" form submitted to Anthropic before first use

In this case, an overdue AWS bill cause the Marketplace subscription to fail silently, even though IAM permissions and the model ID were both correct. 

**The Fix**

1. Pay any outstanding AWS balance 
2. Go to **Billing -> Payment Methods** and confirm a valid card is on file
3. Submit the Anthropic use case form if prompted (**Bedrock -> Model Catalog -> select model -> Submit use case details**)
4. Wait several minutes for the subscription to activate, then retry

**Bonus Error Encounterd Along the Way**

```AccessDeniedException: ... is not authorized to perform the required AWS Marketplace actions (aws-marketplace:ViewSubscriptions, aws-marketplace:Subscribe)```

This required attaching the AWS managed policy to the IAM user making the call:

```bash
aws iam attach-user-policy \
    --user-name <your-username> \
    --policy-arn arn:aws:iam::aws:policy/AWSMarketplaceFullAccess
```

**Lesson Learned**

When a Bedrock model that previously had access suddenly returns AccessDenied with no code changes, check billing status before assuming it's an IAM or code issue.

---

## 6. Claude Ignoring JSON Format Instructions 

**The Error**

```{"error": "Failed to parse AI response"}```

**What Caused It**

Despite an explicit prompt instruction to "respond ONLY with a valid JSON object, no preamble, no explanantion, no markdown backticks," Claude still wrapped its response in markdown code fences:


`````
```json 
{
    "summary": "...",
    "key_points": [...]
}
```
`````

```json.loads()``` fails immediately on a string that starts with ````` ```json ````` instead of ```{```

**The Fix**

Strip markdown formatting from the response before attempting to parse it, as a defensive measure regardless of what the prompt says:

```python

raw_text = bedrock_body["content"][0]["text"].strip()
raw_text = raw_text.replace("```json", "").replace("```", "").strip()
ai_output = json.loads(raw_text)
```

**Lesson Learned**

NEver fully trust an LLM to follow formatting instructions 100% of the time, even with explicit, repeated instructions. When parsing structured output from an LLM in production code, always add a defensive cleanup step before parsing rather than assuming the raw output will be clean. 

---

## 7. KMS Encryption Error on Lambda Recreation

**The Error**

```KMSAccessDeniedException: Lambda was unable to decrypt the environment variables because KMS access was denied. ... User: ... is not authorized to perform: kms:Decrypt on resource: arn:aws:kms:us-east-1:...:key/...```

**What Caused It**

After recreating the IAM role tied to the Lambda function (via ```-replace```), the new role lost the implicit KMS grant that AWS had previously set up to decrypt that Lambda's environment variables. Lambda automatically encrypts environment variables at rest using a KMS key, and the execution role needs ```kms:Decrypt``` permission on that specific key, a permission that isn't always re-granted automatically when a role is recreated. 

**The Fix** 

Since this project didn't have a specific need for KMS encrypted environment variables, the simplest fix was to disable customer-managed KMS encryption on the Lambda function entirely:

```
hcl 

resource "aws_lambda_function" "consul" {
    # ...
    kms_key_arn = null
}
```

This tells Lambda to use its own default service-managed encryption instead of requiring a specific decrypt grant on the execution role. 

**Lesson Learned**

Recreating IAM roles tied to existing resources (Lambda, in this case) can silently break permissions that were previously implicit or auto-granted. When an IAM role is destroyed and recreated, treat every permission the resource needs, including ones AWS usually handles invisibly, as something that may need to be explicitly re-verified. 

---

## 8. Terraform IAM Policy Reverting After Manual Fixes 

**The Error**

The same ```AccessDeniedException``` for Bedrock kept reappearing even after manually patching the IAM policy directly via AWS CLI:

```bash
aws iam put-role-policy --role-name ... --policy-name ... --policy-document '...'
```

The manual fix would work, then a few minutes later the exact same error would return. 

**What Caused It**

Terraform is the source of truth for any resources it manages. Manually patching a policy with the AWS CLI works temporarily, but the change only exists outside of Terraform's state. The next time ```terraform apply``` runs, even for an unrelated change elsewhere in the same file, Terraform detects "drift" between its stored state and reality, and silently reverts the policy back to whatever is defined in ```main.tf```.

**The Fix**

Any manual CLI fix has to also be reflected in the actual Terraform ```.tf``` file, not just applied via CLI. The correct sequence was:
1. Fix the resource ARN directly in ```main.tf```
2. Run ```terraform apply``` (not a manual CLI patch) so Terraform's state matches the file
3. If Terraform still showed "no changes" despite a real difference in AWS, force a refresh of just that resource:

```bash
terraform apply -replace=aws_iam_role_policy.consul_lambda_policy
```

**Lesson Learned**

Never patch a Terraform-managed resource directly through the AWS CLI as a "permanent" fix, it will get silently overwritten on the next apply. CLI patches are useful only as a temporary diagnostic step to confirm what configuration actually works, then that exact configuration needs to be written back into the ```.tf``` file as the real fix. 

---

## 9. Comprehend Method and Parameter Typos 

**The Errors**

```Error: 'Comprehend' object has no attribute 'detect_key_phrase'```

```Parameter validation failed: Missing required parameter in input: "LanguageCode" Unknown parameter in input: "LangaugeCode", must be one of: Text, LanguageCode```

**What Caused It**

Two simple typos while typing out the boto3 Comprehend calls by hand:
1. ```detect_key_phrase``` instead of the actual method name ```detect_key_phrases``` (missing the trailing ```s```)
2. ```LangaugeCode``` instead of ```LanguageCode```(transposed letters)

**The Fix**

```python
# Wrong 
comprehend.detect_key_phrase(Text=text, LangaugeCode='en')

# Correct
comprehend.detect_key_phrases(Text=text, LanguageCode='en')
```

**Lesson Learned**

boto3's error messages for parameter validation are extremely precise, when AWS says "Unknown parameter in input," it will tell you exactly what you typed wrong and exactly what is expected. Reading the full error message character by character (rather than skimming) catches these typos immediately instead guessing at the cause. 

---

## General Lessons Learned

A few patterns showed up repeatedly across nearly every issue in this build, worth calling out on their own. 

**Read the entire error message, not just the first line.** AWS and boto3 error messages are unusually precise, they frequently tell you the exact resource ARN, exact parameter name, or exact permission that's missing. Several hours of debugging in this project came down to a single typo'd character that was visible in the error text the whole time

**Terraform state is the source of truth, respect it.** Manually patching AWS resources outside of Terraform (via the CLI or console) feels faster in the moment, but Terraform will silently revert those changes on the next apply unless the ```.tf``` file itself is updated to match. Any fix discovered through manaual CLI testing needs to be written back into code immediately. 

**Replacing one resource can silently break resources that depend on it.** Lambda functions, IAM roles, and API Gateway integrations are more interconnected than they first appear. Recreating Lambda breaks its API Gateway connection. Recreating an IAM role breaks implicit KMS grants. When forcing a ```-replace```, consider replacing the entire dependency chain together rather than one resource in isolation. 

**AI model behavior is not 100% deterministic, even with explicit instructions.** Prompting an LLM to "only respond with JSON" reduces the frequency of malformed output, but doesn't eliminate it. Production code that parses LLM output should always include a defensive cleanup step before parsing, regardless of how carefully the prompt is written. 

**Billing and account-level issues can masquerade as code or permissions issues.** An AccessDenied error doesn't always mean a broken IAM policy, it can also mean an unpaid bill, a missing Marketplace subscription, or a missing use case approval. When an error appears despite correct-looking code and permissions, check the account level before debugging the code. 

**NONE of these errors were exotic.** Every single one was a small, fixable issue, a missing space, a transposed letter, a stale ARN format, and unpaid invoice. Building real infrastructure means running into a long sequence of small, ordinary problems and working through them one at a time, not avoiding them entirely. 