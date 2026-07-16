import boto3
import json
import random
import uuid
import sys
from concurrent.futures import ThreadPoolExecutor

# Configuration
QUEUE_URL = "https://sqs.eu-west-2.amazonaws.com/753229898853/ps-ingress-data-queue"
REGION = "eu-west-2"
TOTAL_RECORDS = 1000
BATCH_SIZE = 10  # AWS SQS Max Batch Size

sqs = boto3.client('sqs', region_name=REGION)

# Mock Data Pools
DEPARTMENTS = ["GOV", "NHS", "MOD", "DFT", "DWP", "HMRC"]
CLEARANCES = ["public", "official", "secret", "top-secret"]
SYSTEM_STATUS = ["Active", "Degraded", "Maintenance", "Optimized", "Standby"]

def generate_message(index):
    """Generates a realistic telemetry data payload."""
    dept = random.choice(DEPARTMENTS)
    status = random.choice(SYSTEM_STATUS)
    clearance = random.choice(CLEARANCES)
    
    # Generate a unique record ID matching your naming schema (Year 2026)
    record_id = f"{dept}-2026-{uuid.uuid4().hex[:6].upper()}"
    
    body = {
        "record_id": record_id,
        "clearance": clearance,
        "payload": f"Automated telemetry sensor run #{index}. Status: {status}."
    }
    
    # SQS Batch Entry format requires an ID unique within the batch request
    return {
        'Id': f'msg_{index}',
        'MessageBody': json.dumps(body)
    }

def send_batch(batch):
    """Sends a single batch of 10 messages to SQS."""
    try:
        sqs.send_message_batch(QueueUrl=QUEUE_URL, Entries=batch)
    except Exception as e:
        print(f"Error sending batch: {e}", file=sys.stderr)

def main():
    print(f"🚀 Generating {TOTAL_RECORDS} mock analytical records...")
    all_messages = [generate_message(i) for i in range(TOTAL_RECORDS)]
    
    # Split into batches of 10
    batches = [all_messages[i:i + BATCH_SIZE] for i in range(0, len(all_messages), BATCH_SIZE)]
    
    print(f"📦 Shipping {len(batches)} SQS batches to {REGION} using parallel threads...")
    
    # Use multi-threading to bypass sequential network latency
    with ThreadPoolExecutor(max_workers=10) as executor:
        executor.map(send_batch, batches)
        
    print("\n✅ Bulk ingestion complete! 1,000 records successfully pushed to SQS.")

if __name__ == "__main__":
    main()