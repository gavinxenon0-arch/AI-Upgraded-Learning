import os
import json
import boto3

REGION = os.environ["AWS_REGION"]
KB_ID = os.environ["KB_ID"]
MODEL_ID = os.environ["CLAUDE_MODEL_ID"]

agent_rt = boto3.client("bedrock-agent-runtime", region_name=REGION)
brt = boto3.client("bedrock-runtime", region_name=REGION)

CORS_HEADERS = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "Content-Type,Authorization,X-Amz-Date,X-Api-Key,X-Amz-Security-Token",
    "Access-Control-Allow-Methods": "OPTIONS,POST",
    "Access-Control-Max-Age": "600",
}

def _resp(status_code: int, body_obj: dict):
    return {
        "statusCode": status_code,
        "headers": {**CORS_HEADERS, "content-type": "application/json"},
        "body": json.dumps(body_obj),
    }

def lambda_handler(event, context):
    # Handle browser CORS preflight
    if event.get("httpMethod") == "OPTIONS":
        return _resp(200, {})

    body = event.get("body") or "{}"
    try:
        payload = json.loads(body)
    except json.JSONDecodeError:
        return _resp(400, {"error": "Invalid JSON body"})

    question = (payload.get("question") or "").strip()
    if not question:
        return _resp(400, {"error": "question is required"})

    # 1) Retrieve from Knowledge Base
    r = agent_rt.retrieve(
        knowledgeBaseId=KB_ID,
        retrievalQuery={"text": question},
        retrievalConfiguration={"vectorSearchConfiguration": {"numberOfResults": 5}},
    )

    chunks = []
    for res in r.get("retrievalResults", []):
        txt = (res.get("content") or {}).get("text", "")
        if txt:
            chunks.append(txt)

    context_text = "\n\n---\n\n".join(chunks[:6])

    # 2) Generate with Nova via Converse
    user_text = (
        "Use ONLY the context. If missing, say you don't know.\n\n"
        f"CONTEXT:\n{context_text}\n\nQUESTION:\n{question}"
    )

    try:
        model_resp = brt.converse(
            modelId=MODEL_ID,
            messages=[{"role": "user", "content": [{"text": user_text}]}],
            inferenceConfig={
                "maxTokens": 700,
                "temperature": 0.2,
                "topP": 0.9,
            },
        )
    except Exception as e:
        return _resp(500, {"error": str(e)})

    answer = ""
    try:
        answer = model_resp["output"]["message"]["content"][0]["text"]
    except Exception:
        answer = ""

    return _resp(200, {"answer": answer})