resource "aws_resourcegroups_group" "platform_group" {
  name        = "ps-ingress-platform-resources"
  description = "Central tracking group for all Public Sector Ingress Platform assets"

  resource_query {
    query = jsonencode({
      ResourceTypeFilters = ["AWS::AllSupported"]
      TagFilters = [
        {
          Key    = "Project"
          Values = ["PublicSectorIngress"]
        }
      ]
    })
  }
}