import os
import json
import time
from datetime import datetime
import uuid
import boto3

# Initialize AWS clients
sqs = boto3.client('sqs', region_name='eu-west-2')
s3 = boto3.client('s3', region_name='eu-west-2')

QUEUE_URL = os.getenv('SQS_QUEUE_URL', 'https://sqs.eu-west-2.amazonaws.com/753229898853/ps-ingress-data-queue')
# We will pass this new env variable via Terraform or default it
BUCKET_NAME = os.getenv('DATA_LAKE_BUCKET', 'ps-ingress-data-lake-global') 

print("[*] Starting Public Sector Ingress Worker Engine...")
print(f"[*] Target Queue: {QUEUE_URL}")

while True:
    try:
        # Long-poll SQS for messages
        response = sqs.receive_message(
            QueueUrl=QUEUE_URL,
            MaxNumberOfMessages=1,
            WaitTimeSeconds=20
        )
        
        if 'Messages' not in response:
            print("[*] Queue empty. Sleeping/waiting for incoming ingestion payloads...")
            continue
            
        for message in response['Messages']:
            message_id = message['MessageId']
            body_raw = message['Body']
            
            print(f"[+][PROCESSING] Received Payload ID: {message_id}")
            
            # 1. Parse and validate the incoming record
            payload = json.loads(body_raw)
            record_id = payload.get("record_id", f"UNKNOWN-{uuid.uuid4().hex[:6]}")
            
            # 2. Generate Hive-style date partitions dynamically
            now = datetime.utcnow()
            partition_path = f"records/year={now.year}/month={now.strftime('%m')}/day={now.strftime('%d')}"
            file_name = f"{record_id}-{message_id}.json"
            s3_key = f"{partition_path}/{file_name}"
            
            # 3. Stream the JSON record directly to the S3 Data Lake
            s3.put_object(
                Bucket=BUCKET_NAME,
                Key=s3_key,
                Body=json.dumps(payload),
                ContentType='application/json'
            )
            print(f"[+][STORAGE] Successfully committed record to Data Lake: {s3_key}")
            
            # 4. Remove message from SQS buffer to prevent double processing
            sqs.delete_message(
                QueueUrl=QUEUE_URL,
                ReceiptHandle=message['ReceiptHandle']
            )
            print("[+][CLEANUP] Message safely deleted from active queue buffer.\n")
            
    except Exception as e:
        print(f"[-] [ERROR] Critical processing anomaly: {str(e)}")
        time.sleep(5)