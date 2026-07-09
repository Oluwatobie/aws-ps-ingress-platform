# Dead Letter Queue (DLQ) to capture unprocessable payloads for forensic analysis
resource "aws_sqs_queue" "ps_ingress_dlq" {
  name                      = "ps-ingress-queue-dlq"
  message_retention_seconds = 1209600 # Hold un-parsed data for 14 days
  sqs_managed_sse_enabled   = true    # Enforce default Server-Side Encryption at Rest

  tags = { Tier = "Messaging-DLQ" }
}

# Primary Ingestion Message Buffer Queue 
resource "aws_sqs_queue" "ps_ingress_queue" {
  name                       = "ps-ingress-data-queue"
  delay_seconds              = 0
  max_message_size           = 262144 # 256 KB Limit per item payload
  message_retention_seconds  = 345600 # 4 Days Retention buffer
  receive_wait_time_seconds  = 20     # Enforce long-polling to minimize compute polling cost
  visibility_timeout_seconds = 60     # 60s processing timeout window before retry
  sqs_managed_sse_enabled    = true   # Enforce Server-Side Encryption at Rest

  # Automatic quarantine routing after 3 consecutive failures
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.ps_ingress_dlq.arn
    maxReceiveCount     = 3
  })

  tags = { Tier = "Messaging-Buffer" }
}