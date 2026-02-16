# 1. 定义 AWS Provider
provider "aws" {
  region = "us-east-1"
}

resource "random_id" "id" {
  byte_length = 4
}

# 2. 简历存储桶
resource "aws_s3_bucket" "resume_storage" {
  bucket = "campus-recruitment-resumes-${random_id.id.hex}"
}

resource "aws_s3_bucket_cors_configuration" "cors" {
  bucket = aws_s3_bucket.resume_storage.id
  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "POST", "GET"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# 3. 招聘门户用户池
resource "aws_cognito_user_pool" "recruitment_pool" {
  name = "campus-recruitment-user-pool"
  password_policy {
    minimum_length = 8
  }
}

# 4. 用户池域名 (Google 回调的基础)
resource "aws_cognito_user_pool_domain" "main" {
  domain       = "campus-recruitment-auth-${random_id.id.hex}"
  user_pool_id = aws_cognito_user_pool.recruitment_pool.id
}

# 5. Google 身份提供商配置
resource "aws_cognito_identity_provider" "google" {
  user_pool_id  = aws_cognito_user_pool.recruitment_pool.id
  provider_name = "Google"
  provider_type = "Google"

  provider_details = {
    authorize_scopes = "email openid profile"
    client_id        = "614270326946-vf4eriv6dp9q078gge557bb977v7h3h4.apps.googleusercontent.com"     # 这里填 Google 给你的 ID
    client_secret    = "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" # 这里填 Google 给你的 Secret
    attributes_url                = "https://people.googleapis.com/v1/people/me?personFields="
    attributes_url_add_attributes = "true"
    authorize_url                 = "https://accounts.google.com/o/oauth2/v2/auth"
    token_request_method          = "POST"
    token_url                     = "https://oauth2.googleapis.com/token"
    oidc_issuer                   = "https://accounts.google.com"
  }

  attribute_mapping = {
    email    = "email"
    username = "sub"
  }
}

# 6. 合并后的 App Client (只保留这一个)
resource "aws_cognito_user_pool_client" "portal_client" {
  name         = "recruitment-portal-client"
  user_pool_id = aws_cognito_user_pool.recruitment_pool.id

  supported_identity_providers = ["COGNITO", "Google"]

  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["email", "openid", "profile"]

  callback_urls = ["http://localhost:3000/auth/callback"]
  logout_urls   = ["http://localhost:3000/"]

  # 必须先创建 Provider 才能创建有关联的 Client
  depends_on = [aws_cognito_identity_provider.google]

  explicit_auth_flows = [
      "ALLOW_USER_SRP_AUTH",
      "ALLOW_REFRESH_TOKEN_AUTH"
    ]

  access_token_validity  = 1 # 小时
  id_token_validity      = 1 # 小时
  refresh_token_validity = 30 # 天
}

# 角色组
resource "aws_cognito_user_group" "candidate_group" {
  name         = "candidate"
  user_pool_id = aws_cognito_user_pool.recruitment_pool.id
}

resource "aws_cognito_user_group" "recruiter_group" {
  name         = "recruiter"
  user_pool_id = aws_cognito_user_pool.recruitment_pool.id
}

# 7. 招聘系统 API 网关 & 授权器
resource "aws_apigatewayv2_api" "recruitment_gw" {
  name          = "recruitment-service-gateway"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_authorizer" "recruitment_auth" {
  api_id           = aws_apigatewayv2_api.recruitment_gw.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "recruitment-cognito-auth"

  jwt_configuration {
    audience = [aws_cognito_user_pool_client.portal_client.id]
    issuer   = "https://${aws_cognito_user_pool.recruitment_pool.endpoint}"
  }
}

output "cognito_user_pool_id" {
  value = aws_cognito_user_pool.recruitment_pool.id
}

output "cognito_app_client_id" {
  value = aws_cognito_user_pool_client.portal_client.id
}

output "cognito_domain_url" {
  value = "${aws_cognito_user_pool_domain.main.domain}.auth.us-east-1.amazoncognito.com"
}
