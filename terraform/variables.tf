variable "aws_region" {
  type        = string
  default     = "eu-west-2" # Enforcing the London home-region allocation for public-sector workloads[cite: 1]
  description = "Target deployment region for the platform"
}