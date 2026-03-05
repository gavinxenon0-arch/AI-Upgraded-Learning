terraform {
  required_version = "~> 1.14.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.33.0"
    }
  }
}

provider "aws" {
  region = var.region
}
# This is the terraform backend Bucket

# This is the terraform backend bucket assignment to the backend
terraform {
  backend "s3" {
    bucket       = "backend-extra-unique-2"
    key          = "terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}
# This bucket is for the RAG project to store the data and the vector database files. It is not used for terraform state management.
resource "aws_s3_bucket" "Retrieval-Augmented-Generation" {
  bucket        = "backend-extra-unique${random_id.suffix.hex}"
  force_destroy = true
  tags = {
    Name        = "Retrieval-Augmented-Generation"
    Environment = "Dev"
  }
}
# Upload a whole folder (recursively) using fileset()
resource "aws_s3_object" "uploads" {
  for_each = fileset("${path.module}/RAG_Documents", "**")

  bucket = aws_s3_bucket.Retrieval-Augmented-Generation.id
  key    = each.value
  source = "${path.module}/RAG_Documents/${each.value}"

  # Helps Terraform detect changes in file contents
  etag = filemd5("${path.module}/RAG_Documents/${each.value}")
}
# This is for the VPC Creation and the Internet Gateway Creation
module "vpc1" {
  source = "./modules/vpc"

  name       = var.vpc_name
  cidr_block = var.vpc_cidr

  tags = {
    Name        = var.vpc_name
    Environment = "dev"
  }
}
# This is for the Public Subnet Creation
module "subnet1" {
  source = "./modules/subnet"

  cidr_block        = var.public_subnet_cidr
  availability_zone = data.aws_availability_zones.available.names[0]
  name              = var.vpc_name
  vpc_id            = module.vpc1.vpc_id
  ip                = var.public_ip

  tags = {
    Name        = "${var.vpc_name}-public-subnet"
    Environment = "dev"
  }
}
# This is for the Private Subnet Creation
module "subnet2" {
  source = "./modules/subnet"

  cidr_block        = var.private_subnet_cidr
  availability_zone = data.aws_availability_zones.available.names[1]
  name              = var.vpc_name
  vpc_id            = module.vpc1.vpc_id
  ip                = var.private_ip

  tags = {
    Name        = "${var.vpc_name}-private-subnet"
    Environment = "dev"
  }
}


# This is for the route table for the public subnet
resource "aws_route_table" "public" {
  vpc_id = module.vpc1.vpc_id

  route {
    cidr_block = var.public_cidr
    gateway_id = module.vpc1.internet_gateway_id
  }

  tags = {
    Name = "Public Route Table"
  }
}
# This is for the association of the public route table with the public subnet
# resource "aws_main_route_table_association" "public" {
#   vpc_id         = module.vpc1.vpc_id
#   route_table_id = aws_route_table.public.id
# }
resource "aws_route_table_association" "public_subnet" {
  subnet_id      = module.subnet1.subnet_id
  route_table_id = aws_route_table.public.id
}

# This is for the route table for the private subnet
resource "aws_route_table" "private" {
  vpc_id = module.vpc1.vpc_id

  route {
    cidr_block = var.vpc_cidr
    gateway_id = "local"
  }

  tags = {
    Name = "Private Route Table"
  }
}
# This is for the association of the private route table with the private subnet
# resource "aws_main_route_table_association" "private" {
#   vpc_id         = module.vpc1.vpc_id
#   route_table_id = aws_route_table.private.id
# }
resource "aws_route_table_association" "private_subnet" {
  subnet_id      = module.subnet2.subnet_id
  route_table_id = aws_route_table.private.id
}


#S3 Vector Database Creation using Cloud Control API
resource "aws_cloudcontrolapi_resource" "vector_bucket" {
  type_name = "AWS::S3Vectors::VectorBucket"

  desired_state = jsonencode({
    VectorBucketName = "kb-vectors-${random_id.suffix.hex}"
    # EncryptionConfiguration is optional; defaults are supported in CFN docs
  })
}
resource "random_id" "suffix" {
  byte_length = 3
}

resource "aws_cloudcontrolapi_resource" "vector_index" {
  type_name = "AWS::S3Vectors::Index"

  desired_state = jsonencode({
    IndexName       = "kb-index"
    VectorBucketArn = jsondecode(aws_cloudcontrolapi_resource.vector_bucket.properties).VectorBucketArn
    Dimension       = 1024 #This is the dimension for the Titan Text Embeddings V2
    DistanceMetric  = "cosine"
    DataType        = "float32"

    MetadataConfiguration = {
      NonFilterableMetadataKeys = ["AMAZON_BEDROCK_TEXT"]
    }
  })

}

# This is for the IAM Role and Policy Creation for Bedrock to access the S3 bucket and the embedding model
data "aws_iam_policy_document" "bedrock_kb_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["bedrock.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "bedrock_kb_role" {
  name               = "bedrock-kb-role-${random_id.suffix.hex}"
  assume_role_policy = data.aws_iam_policy_document.bedrock_kb_assume.json
}

data "aws_iam_policy_document" "bedrock_kb_policy" {

  statement {
    sid     = "ListDocsBucket"
    effect  = "Allow"
    actions = ["s3:ListBucket"]
    resources = [
      "arn:aws:s3:::${aws_s3_bucket.Retrieval-Augmented-Generation.bucket}"
    ]
  }

  statement {
    sid     = "ReadDocsObjects"
    effect  = "Allow"
    actions = ["s3:GetObject"]
    resources = [
      "arn:aws:s3:::${aws_s3_bucket.Retrieval-Augmented-Generation.bucket}/*"
    ]
  }

  statement {
    sid       = "S3VectorsAccess"
    effect    = "Allow"
    actions   = ["s3vectors:*"]
    resources = ["*"]
  }

  statement {
    sid       = "InvokeEmbeddingModel"
    effect    = "Allow"
    actions   = ["bedrock:InvokeModel"]
    resources = [var.embedding_model_arn]
  }
}

resource "aws_iam_policy" "bedrock_kb_policy" {
  name   = "bedrock-kb-policy-${random_id.suffix.hex}"
  policy = data.aws_iam_policy_document.bedrock_kb_policy.json
}

resource "aws_iam_role_policy_attachment" "bedrock_kb_attach" {
  role       = aws_iam_role.bedrock_kb_role.name
  policy_arn = aws_iam_policy.bedrock_kb_policy.arn
}

# There is a race condition error herre so this is my solution to it.
resource "time_sleep" "wait_30_seconds" {
  depends_on = [
    aws_cloudcontrolapi_resource.vector_bucket,
    aws_cloudcontrolapi_resource.vector_index,
    aws_iam_role_policy_attachment.bedrock_kb_attach
  ]

  create_duration = "30s"
}


# This is for creating the knowledge base for the RAG system using the Cloud Control API, and linking it to the S3 bucket and the embedding model
resource "aws_cloudcontrolapi_resource" "kb" {
  type_name = "AWS::Bedrock::KnowledgeBase"

  desired_state = jsonencode({
    Name    = "kb-${random_id.suffix.hex}"
    RoleArn = aws_iam_role.bedrock_kb_role.arn

    KnowledgeBaseConfiguration = {
      Type = "VECTOR"
      VectorKnowledgeBaseConfiguration = {
        EmbeddingModelArn = var.embedding_model_arn
      }
    }

    StorageConfiguration = {
      Type = "S3_VECTORS"
      S3VectorsConfiguration = {
        VectorBucketArn = jsondecode(aws_cloudcontrolapi_resource.vector_bucket.properties).VectorBucketArn
        IndexName       = jsondecode(aws_cloudcontrolapi_resource.vector_index.properties).IndexName
        #  IndexArn        = jsondecode(aws_cloudcontrolapi_resource.vector_index.properties).IndexArn
      }
    }
  })

  depends_on = [time_sleep.wait_30_seconds]
}





# Bedrock Data Source (your existing docs in S3)
resource "aws_bedrockagent_data_source" "s3_docs" {
  name              = "docs-${random_id.suffix.hex}"
  knowledge_base_id = jsondecode(aws_cloudcontrolapi_resource.kb.properties).KnowledgeBaseId

  data_source_configuration {
    type = "S3"
    s3_configuration {
      bucket_arn = "arn:aws:s3:::${aws_s3_bucket.Retrieval-Augmented-Generation.bucket}"
      #inclusion_prefixes = length(var.docs_prefix) > 0 ? [var.docs_prefix] : null
    }
  }

}

# Sync Vector database to Knowledge base
resource "terraform_data" "bedrock_sync" {
  # Triggers ensure the sync runs when these IDs change
  triggers_replace = [
    aws_cloudcontrolapi_resource.kb.id,
    aws_bedrockagent_data_source.s3_docs.data_source_id
  ]
  # This block runs a local command that goes into aws and executes the command that syncs my vertor database with the 
  provisioner "local-exec" {
    command = <<EOT
      aws bedrock-agent start-ingestion-job --knowledge-base-id ${aws_cloudcontrolapi_resource.kb.id} --data-source-id ${aws_bedrockagent_data_source.s3_docs.data_source_id} --region ${var.region}
    EOT
  }

  depends_on = [
    aws_cloudcontrolapi_resource.kb,
    aws_bedrockagent_data_source.s3_docs
  ]
}




# Just a simple zip function to zip the python code for the lambda function, so that it can be uploaded to AWS Lambda
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda_function.py"
  output_path = "${path.module}/lambda.zip"
}

resource "aws_iam_role" "lambda_role" {
  name = "kb-chat-lambda-role-${random_id.suffix.hex}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

#This is a policy to talk to bedrock
resource "aws_iam_policy" "lambda_bedrock" {
  name = "lambda-bedrock-kb-${random_id.suffix.hex}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow",
        Action = ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream"],
      Resource = "*" },


      { Effect = "Allow",
        Action = ["bedrock-agent-runtime:Retrieve"],
      Resource = "*" }
    ]
  })
}
# This is so it can invoke lambda functions
resource "aws_iam_role_policy" "lambda_bedrock_full" {
  name = "lambda-bedrock-full-access"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:Retrieve",
          "bedrock:InvokeModel"
        ]
        Resource = "*"
      }
    ]
  })
}
# This is for lambda basic execution role, which allows the Lambda function to write logs to CloudWatch, and also allows it to talk to bedrock with the above policy
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
# Iam policy attachment for the basic Lambda execution role, which allows the Lambda function to speak to bedrock and no writing logs yet
resource "aws_iam_role_policy_attachment" "lambda_bedrock_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_bedrock.arn
}
# This is the lambda function resource, which is the part that handles talking to the bedrock model and then passess the response back to the API Gatewayl and database
resource "aws_lambda_function" "chat" {
  function_name = "kb-chat"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.12"

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  #  reserved_concurrent_executions = 10   # I only have 10 concurrencies in this account, so I cannot reserve some to use my ddos protection strategy, too bad

  environment {
    variables = {
      KB_ID           = jsondecode(aws_cloudcontrolapi_resource.kb.properties).KnowledgeBaseId
      CLAUDE_MODEL_ID = var.claude_model_arn
      #AWS_REGION      = var.region
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
    aws_iam_role_policy_attachment.lambda_bedrock_attach
  ]
}




# This is the RestAPI creation using API Gateway, which will be the public endpoint for the system
resource "aws_api_gateway_rest_api" "api" {
  name = "kb-chat-api"
}
# This creates a path to in the rest API that will allow for specific path routing which is /chat in this case
resource "aws_api_gateway_resource" "chat" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "chat"
}
# This creates a POST method for the /chat path in the API Gateway, which will be used to send messages to the Lambda function
resource "aws_api_gateway_method" "post" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.chat.id
  http_method   = "POST"
  authorization = "NONE"
}
# This creates a Lambda integration with the API Gateway, which allows the API Gateway to invoke the Lambda function when a request is made to the /chat endpoint
resource "aws_api_gateway_integration" "lambda" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.chat.id
  http_method = aws_api_gateway_method.post.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.chat.invoke_arn
}
# This is for giving permission to the API Gateway to invoke the Lambda function, which is necessary for the integration to work
resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.chat.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*"
}

resource "aws_api_gateway_deployment" "deploy" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  depends_on  = [aws_api_gateway_integration.lambda]
}

resource "aws_api_gateway_stage" "prod" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  deployment_id = aws_api_gateway_deployment.deploy.id
  stage_name    = "prod"
}

# Throttle (best-effort targets) at stage level :contentReference[oaicite:9]{index=9}
resource "aws_api_gateway_method_settings" "throttle" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name  = aws_api_gateway_stage.prod.stage_name
  method_path = "*/*"

  settings {
    throttling_rate_limit  = 5
    throttling_burst_limit = 10
  }
}


# Fix the API GATEWAY to allow Website communication
resource "aws_api_gateway_method" "options" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.chat.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.chat.id
  http_method = aws_api_gateway_method.options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}


resource "aws_api_gateway_method_response" "options_200" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.chat.id
  http_method = aws_api_gateway_method.options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Headers" = true
  }
}


resource "aws_api_gateway_integration_response" "options_200" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.chat.id
  http_method = aws_api_gateway_method.options.http_method
  status_code = aws_api_gateway_method_response.options_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
    "method.response.header.Access-Control-Allow-Methods" = "'OPTIONS,POST'"
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization,X-Amz-Date,X-Api-Key,X-Amz-Security-Token'"
  }

  depends_on = [aws_api_gateway_integration.options]
}


resource "aws_api_gateway_method_response" "post_200" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.chat.id
  http_method = aws_api_gateway_method.post.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

resource "aws_api_gateway_integration_response" "post_200" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.chat.id
  http_method = aws_api_gateway_method.post.http_method
  status_code = aws_api_gateway_method_response.post_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }

  depends_on = [aws_api_gateway_integration.lambda]
}

resource "aws_api_gateway_deployment" "deploy2" {
  rest_api_id = aws_api_gateway_rest_api.api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.chat.id,
      aws_api_gateway_method.post.id,
      aws_api_gateway_integration.lambda.id,
      aws_api_gateway_method.options.id,
      aws_api_gateway_integration.options.id,
      aws_api_gateway_integration_response.options_200.id
    ]))
  }

  depends_on = [
    aws_api_gateway_integration.lambda,
    aws_api_gateway_integration_response.options_200
  ]
}

#################################################################################################################
##############################################     Hosting      #################################################
##############################################   EC2 Instance   #################################################
#################################################################################################################
#################################################################################################################


# This is to host the websiite on ec2

variable "first_option" {
  description = "To enable Ec2 hosting turn the default to true below"
  type = bool
  default = false
}


resource "aws_security_group" "EC2_SG" {
  count = var.first_option ? 1 : 0
  name        = "EC2_SG"
  description = "Allow TLS inbound traffic on HTTP and RDP and all outbound traffic"
  vpc_id      = module.vpc1.vpc_id

  tags = {
    Name = "EC2_SG"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_http_ipv4" {
  count = var.first_option ? 1 : 0
  security_group_id = aws_security_group.EC2_SG[0].id
  cidr_ipv4         = var.public_cidr
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "allow_all_egress_ipv4" {
  count = var.first_option ? 1 : 0
  security_group_id = aws_security_group.EC2_SG[0].id
  cidr_ipv4         = var.public_cidr
  ip_protocol       = "-1" # semantically equivalent to all ports
}

#This is the Ec2 Instance that is used to speak to the API Gateway which calls the lambda function that allows me to test the system.

resource "aws_instance" "web" {
  count = var.first_option ? 1 : 0
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.micro"
  subnet_id                   = module.subnet1.subnet_id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.EC2_SG[0].id]

  user_data = <<-EOF
#!/bin/bash
set -euxo pipefail

# Enable nginx repo
amazon-linux-extras enable nginx1

# Refresh yum metadata
yum clean metadata

# Install nginx
yum install -y nginx

# Enable and start nginx
systemctl enable nginx
systemctl start nginx

# Write your HTML file
cat > /usr/share/nginx/html/index.html <<'HTML'
${file("${path.module}/index.html")}
HTML

# Restart nginx to load new file
systemctl restart nginx

# Debug logs (optional but useful)
echo "Nginx status:"
systemctl status nginx --no-pager

echo "Listening ports:"
ss -tulpn | grep :80

EOF

  tags = {
    Name = "chatbot-static-web"
  }
}
#################################################################################################################
##############################################    Hosting       #################################################
############################################## S3 + Cloudfront  #################################################
#################################################################################################################
#################################################################################################################

# s3 + Cloudfront Hosting HTTP Website
variable "second_option" {
  description = "To enable Ec2 hosting turn the default to true below"
  type = bool
  default = true
}



resource "aws_s3_bucket" "website-bucket" {
  count = var.second_option ? 1 : 0
  bucket = "website-bucket-${random_id.suffix.hex}"

  tags = {
    Name        = "My bucket"
    Environment = "Dev"
  }
}
# Upload the html document to the s3 bucket
resource "aws_s3_object" "uploads1" {
  count = var.second_option ? 1 : 0
  bucket = aws_s3_bucket.website-bucket[0].id
  key    = "index.html"
  source = "${path.module}/index.html"

  # Helps Terraform detect changes in file contents
  etag = filemd5("${path.module}/index.html")
  content_type = "text/html"
}

# S3 Bucket Configuration for static website hosting
resource "aws_s3_bucket_website_configuration" "static_site" {
  count = var.second_option ? 1 : 0
  bucket = aws_s3_bucket.website-bucket[0].id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}


############################################                               #########################################################
############################################      Route 53                 #########################################################
############################################                               #########################################################

import {
  to = aws_route53domains_registered_domain.unshieldedhollow[0]
  id = var.registered_domain # Your domain here
}

resource "aws_route53_zone" "primary" {
  count = var.second_option ? 1 : 0
  name = var.registered_domain
}

# The registered domain for the domain you choose
resource "aws_route53domains_registered_domain" "unshieldedhollow" {
  count = var.second_option ? 1 : 0
  domain_name = var.root_domain_name

  dynamic "name_server" {
    for_each = aws_route53_zone.primary[0].name_servers
    content {
      name = name_server.value
    }
  }
  tags = {
    Environment = var.Environment
  }
}
# The acm cert for Cloudfront
module "acm_cert_1" {
  count = var.second_option ? 1 : 0
  source      = "./modules/acm_certificate"
  domain_name = var.registered_domain
  tags        = "Cloudfront"
  zone        = aws_route53_zone.primary[0].zone_id

}


# Cloudfront


############################################                               #########################################################
############################################      Cloudfront               #########################################################
############################################                               #########################################################



resource "aws_cloudfront_origin_access_control" "oac" {
  count = var.second_option ? 1 : 0
  name                              = "default-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

locals {
  s3_origin_id = length(aws_s3_bucket.website-bucket) > 0 ? "s3-origin-${aws_s3_bucket.website-bucket[0].id}" : null
}



# Cloudfront Distribution
resource "aws_cloudfront_distribution" "s3_distribution" {
  count = var.second_option ? 1 : 0
  origin {
    domain_name              = aws_s3_bucket.website-bucket[0].bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.oac[0].id
    origin_id                = local.s3_origin_id
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Some comment"
  default_root_object = "index.html"
  aliases = [var.registered_domain]
  #aliases = ["${var.root_domain_name}", "www.${var.root_domain_name}"]

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  # Cache behavior with precedence 0
  ordered_cache_behavior {
    path_pattern     = "/content/immutable/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false
      headers      = ["Origin"]

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  # Cache behavior with precedence 1
  ordered_cache_behavior {
    path_pattern     = "/content/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Environment = "production"
  }
  viewer_certificate {
  acm_certificate_arn      = module.acm_cert_1[0].certificate_arn
  ssl_support_method       = "sni-only"
  minimum_protocol_version = "TLSv1.2_2021"
 }

 depends_on = [ module.acm_cert_1 ]
}



# Create Route53 records for the CloudFront distribution aliases


resource "aws_route53_record" "cloudfront" {
  count = var.second_option ? 1 : 0
  zone_id  = aws_route53_zone.primary[0].zone_id
  name     = ""
  type     = "A"

  alias {
    name                   = aws_cloudfront_distribution.s3_distribution[0].domain_name
    zone_id                = aws_cloudfront_distribution.s3_distribution[0].hosted_zone_id
    evaluate_target_health = false
  }
}
resource "aws_route53_record" "cloudfront1" {
  count = var.second_option ? 1 : 0
  zone_id  = aws_route53_zone.primary[0].zone_id
  name     = "www"
  type     = "A"

  alias {
    name                   = aws_cloudfront_distribution.s3_distribution[0].domain_name
    zone_id                = aws_cloudfront_distribution.s3_distribution[0].hosted_zone_id
    evaluate_target_health = false
  }
}


# Iam bucket policy for cloudfront access
data "aws_iam_policy_document" "origin_bucket_policy" {
  count = var.second_option ? 1 : 0
  statement {
    sid    = "AllowCloudFrontServicePrincipalReadWrite"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions = [
      "s3:GetObject"
    ]

    resources = [
      "${aws_s3_bucket.website-bucket[0].arn}/*",
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.s3_distribution[0].arn]
    }
  }
}

# Extracts the json policy from the policy above and connects it to the s3 bucket
resource "aws_s3_bucket_policy" "b" {
  count = var.second_option ? 1 : 0
  bucket = aws_s3_bucket.website-bucket[0].bucket
  policy = data.aws_iam_policy_document.origin_bucket_policy[0].json
}