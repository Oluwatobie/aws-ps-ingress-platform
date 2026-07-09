import os
import time
import json
import boto3

# Fetch environment variables injected by ECS Task Definition
QUEUE_URL = os.environ.get("SQS_QUEUE_URL")
AWS_REGION = os.environ.get("AWS_REGION", "eu-west-2")

sqs = boto3.client("sqs", region_name=AWS_REGION)

print(f"[*] Starting Public Sector Ingress Worker Engine...")
print(f"[*] Target Queue: {QUEUE_URL}")

while True:
    try:
        # Long poll SQS queue to minimize API request volume and costs
        response = sqs.receive_message(
            QueueUrl=QUEUE_URL,
            MaxNumberOfMessages=1,
            WaitTimeSeconds=20,  # Enforces long-polling
            VisibilityTimeout=60 # Gives worker 60s to finish before message returns to queue
        )
        
        messages = response.get("Messages", [])
        if not messages:
            print("[*] Queue empty. Sleeping/waiting for incoming ingestion payloads...")
            continue
            
        for msg in messages:
            receipt_handle = msg["ReceiptHandle"]
            body = msg["Body"]
            
            print(f"[+][PROCESSING] Received Payload ID: {msg['MessageId']}")
            
            # --- SIMULATE SECURE GOV DATA PROCESSING ---
            # In a real environment, you would parse, sanitize, and validate fields here
            time.sleep(2) 
            print(f"[+][SUCCESS] Payload validation passed securely.")
            # -------------------------------------------
            
            # Delete message from queue to confirm successful processing
            sqs.delete_message(
                QueueUrl=QUEUE_URL,
                ReceiptHandle=receipt_handle
            )
            print(f"[+][CLEANUP] Message safely deleted from active queue buffer.")
            
    except Exception as e:
        print(f"[-][ERROR] Critical exception caught in worker execution loop: {str(e)}")
        time.sleep(5) # Cooldown before trying again to prevent aggressive crash looping