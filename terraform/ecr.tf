resource "aws_ecr_repository" "app_repo" {
  name                 = "ps-ingress-worker-repo"
  image_tag_mutability = "IMMUTABLE" # Prevents accidental tag overwrites in production

  # Automatically scans our docker images for CVE security vulnerabilities upon push
  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Layer = "Artifact-Storage"
  }
}