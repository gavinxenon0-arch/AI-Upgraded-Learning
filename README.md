<div align="center">

# ⚔️ Hallucination-Resistant RAG System on AWS

**Production-minded RAG pipeline:** S3 docs → S3 Vectors → Bedrock Knowledge Base → Lambda Chat API → (Optional) Website Hosting

<!-- Replace with your own banner image/gif -->


<br/>

![AWS](https://img.shields.io/badge/AWS-232F3E?style=for-the-badge&logo=amazonaws&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)
![CloudFront](https://img.shields.io/badge/CloudFront-FF9900?style=for-the-badge&logo=amazonaws&logoColor=black)
![CDN](https://img.shields.io/badge/Edge%20Security-0B1220?style=for-the-badge)
![Bedrock](https://img.shields.io/badge/Bedrock-00A1C9?style=for-the-badge&logo=amazonaws&logoColor=white)
![AI](https://img.shields.io/badge/Observability-22C55E?style=for-the-badge)
![AWS](https://img.shields.io/badge/AWS-Cloud-orange?style=for-the-badge&logo=amazonaws)
![Terraform](https://img.shields.io/badge/Terraform-1.14+-purple?style=for-the-badge&logo=terraform)
![CloudFront](https://img.shields.io/badge/CloudFront-Edge%20CDN-blue?style=for-the-badge)
![Bedrock](https://img.shields.io/badge/Amazon-Bedrock-green?style=for-the-badge)
![Database](https://img.shields.io/badge/Observability-CloudWatch-yellow?style=for-the-badge)
![Status](https://img.shields.io/badge/Status-Production%20Style-success?style=for-the-badge)
</div>

---

## What this builds (fast)

✅ Uploads local docs from `RAG_Documents/` to S3  
✅ Creates **S3 Vectors** (VectorBucket + Index)  
✅ Creates **Bedrock Knowledge Base** + **Data Source**  
✅ Triggers **ingestion job** (AWS CLI) to sync vectors  
✅ Deploys **Lambda** + **API Gateway** (`POST /chat`) with CORS  
✅ Optional website hosting:
- **Option A:** EC2 + Nginx  
- **Option B (default):** S3 + CloudFront + Route 53 + ACM

---

## Architecture (visual)

# 🚀 What This Project Builds

This project deploys a complete Retrieval Augmented Generation (RAG) system using Infrastructure as Code.

It automatically provisions:

Component	Description
📄 S3 Document Storage	Upload knowledge base documents

🧠 Bedrock Knowledge Base	AI retrieval system

🧬 S3 Vector Database	Vector embeddings storage

⚡ Lambda Chat Engine	Handles prompts + model responses

🌐 API Gateway	Public /chat endpoint

☁️ CloudFront CDN	Optional global frontend hosting

🔐 IAM Roles	Secure model and storage access

🌎 VPC + Subnets	Isolated infrastructure

---

# 🧠 RAG Architecture

<img width="1802" height="1206" alt="mermaid-diagram (1)" src="https://github.com/user-attachments/assets/d039dd1b-d33b-4735-a3ae-b762477e3f28" />

flowchart LR

Docs[RAG Documents] --> S3[(S3 Document Bucket)]

S3 --> Vectors[S3 Vectors]
Vectors --> Index[Vector Index]

Index --> KB[Bedrock Knowledge Base]

KB --> Lambda[Lambda Chat Handler]

Lambda --> API[API Gateway /chat]

API --> Client[Website or Client App]

🧠 System Architecture

<img width="2470" height="129" alt="mermaid-diagram" src="https://github.com/user-attachments/assets/2068f9fa-592b-4f58-a430-ec34b8177acd" />


Hosting Options

S3 + Cloudfront
<img width="1536" height="1024" alt="ChatGPT Image Mar 5, 2026, 02_46_18 AM" src="https://github.com/user-attachments/assets/f3e9f930-64bd-44f0-b122-f15853d5d8b3" />

    &
Ec2 Website
<img width="1536" height="1024" alt="ec2 sssafaf" src="https://github.com/user-attachments/assets/3dbe8cc0-7822-445b-9f5a-0cbcc5733919" />




📂 Project Structure
.
├── main.tf
├── var.tf
├── output.tf
│
├── modules/
│   ├── vpc
│   ├── subnet
│   └── acm_certificate
│
├── RAG_Documents/
│
├── lambda_function.py
├── lambda.zip
│
└── index.html



🧩 Key Features

✔ Upload local documents automatically
✔ Vectorize documents using Titan embeddings
✔ Query with Claude via Bedrock
✔ Fully automated Terraform deployment
✔ Optional CloudFront production hosting

⚡ Quick Deploy

1️⃣ Initialize Terraform
terraform init

2️⃣ Plan Infrastructure
terraform plan

3️⃣ Deploy
terraform apply

🧪 Test the Chat API
curl -X POST \
https://YOUR_API_URL/chat \
-H "Content-Type: application/json" \
-d '{"message":"Explain my documents"}'

🧩 RAG Pipeline

1️⃣ Upload documents
2️⃣ Terraform uploads them to S3
3️⃣ Documents are embedded using Bedrock Titan embeddings
4️⃣ Stored inside S3 Vectors
5️⃣ Queries retrieve context from vectors
6️⃣ Claude generates final response

<img width="2502" height="1206" alt="22222" src="https://github.com/user-attachments/assets/92f895f1-a6c4-494a-8a45-60eeeaed519d" />


🔐 Security Model

The infrastructure implements several AWS security practices:

✔ IAM least-privilege roles
✔ Private networking using VPC
✔ API Gateway throttling
✔ CloudFront Origin Access Control
✔ No public access to vector storage

Future improvements:

AWS WAF

Cognito authentication

request validation

encrypted secrets rotation



## Quick start

1) Pre-reqs

Terraform ~> 1.14.5  | AWS provider 6.33.0  | AWS CLI installed + authenticated  | Backend bucket already exists: backend-extra-unique-1


🎬 Animated Footer: Working Demo on Topic
     
https://github.com/user-attachments/assets/2a94670d-3471-4304-9750-13332952fb12

🎬 Animated Footer: Not Working Demo On Non Topic

https://github.com/user-attachments/assets/cae5d5fd-cb3e-4cd7-bfd2-d1a15cfc21f0

🎯 Why This Project Matters

This project demonstrates real-world cloud engineering skills:

Infrastructure as Code

AI system architecture

serverless backends

secure cloud networking

vector databases

production deployment patterns

This type of architecture is used by modern AI SaaS platforms.


## ⚠️ Problems Encountered and Solutions

### 1. Limited Documentation for S3 Vectors + Bedrock Knowledge Base
**Problem:** AWS documentation for creating a Bedrock Knowledge Base with **S3 Vectors** through Terraform is very limited and fragmented.  
**Solution:** Used AI-assisted research to quickly gather the required documentation and reconstruct the full deployment flow (Vector Bucket → Index → Knowledge Base → Data Source → Ingestion).

---

### 2. Race Conditions During Terraform Deployment
**Problem:** Some AWS resources were not fully available when Terraform attempted to create dependent resources, causing intermittent failures.  
**Solution:** Added a Terraform `time_sleep` resource to ensure the vector bucket, index, and IAM roles were fully initialized before creating the Knowledge Base.

---

### 3. CloudFront + ACM + Route53 Dependency Conflict
**Problem:** ACM certificate validation created duplicate Route53 records which prevented the domain from resolving correctly.  
**Solution:** Removed the incorrect DNS records and adjusted the Terraform dependency flow so the certificate validates before CloudFront is deployed.

---

### 4. Bedrock Ingestion Job Not Supported by Terraform
**Problem:** Terraform does not currently support triggering Bedrock ingestion jobs as a native resource.  
**Solution:** Used a `local-exec` provisioner to run the AWS CLI command that starts the ingestion process after the Knowledge Base and data source are created.

---

### 5. CORS Errors Between Frontend and API Gateway
**Problem:** Browser requests to the `/chat` endpoint failed because API Gateway did not handle preflight requests.  
**Solution:** Added an `OPTIONS` method and configured `Access-Control-Allow-*` headers so the frontend can communicate with the API.

## 🧠 Architecture Decisions

### Vector Database: S3 Vectors instead of Pinecone or OpenSearch
**Decision:** Use **AWS S3 Vectors** as the vector storage backend.  
**Reason:** It integrates directly with **Bedrock Knowledge Bases**, removes the need to manage external vector databases, and keeps the entire system inside AWS for simpler security and networking.

---

### Serverless Compute: Lambda instead of Containers
**Decision:** Use **AWS Lambda** for the chat backend.  
**Reason:** Lambda removes infrastructure management, scales automatically, and is well suited for request-driven workloads like API-based chat interactions.

---

### API Layer: API Gateway instead of ALB
**Decision:** Use **API Gateway** to expose the `/chat` endpoint.  
**Reason:** API Gateway integrates natively with Lambda, supports throttling, request validation, and authentication features that are useful for AI APIs.

---

### Document Storage: S3 instead of Database Storage
**Decision:** Store knowledge documents in **S3**.  
**Reason:** S3 is durable, inexpensive, and integrates directly with Bedrock Knowledge Bases and ingestion pipelines.

---

### Frontend Hosting: CloudFront + S3 instead of EC2
**Decision:** Host the frontend using **CloudFront with an S3 static site**.  
**Reason:** This provides global CDN performance, better security, and lower cost compared to running a web server on EC2.

---

### Infrastructure Management: Terraform instead of manual deployment
**Decision:** Use **Terraform** to provision all infrastructure.  
**Reason:** Infrastructure as Code allows repeatable deployments, version control, and makes the system easier to maintain and reproduce.

## ▶️ How to Run

1. **Update the Terraform backend**

Replace the S3 backend with a bucket you own.


terraform {
backend "s3" {
bucket = "YOUR_BACKEND_BUCKET"
key = "terraform.tfstate"
region = "us-east-1"
}
}


---

2. **Update domain variables**

In `terraform.tfvars` (or variables):


registered_domain = "yourdomain.com"
root_domain_name = "yourdomain.com"


---

3. **Make resources unique**

Some resources (like S3 buckets) must be globally unique.  
If Terraform fails, update names to something unique for your account.

---

4. **Deploy the infrastructure**


terraform init
terraform apply


---

5. **Copy the API Gateway Invoke URL**

After deployment, copy the **Invoke URL**.

Example:


https://xxxx.execute-api.us-east-1.amazonaws.com/prod


---

6. **Use the AI**

Go to your domain (CloudFront site), paste the **Invoke URL**, and start asking questions.

The AI knowledge base is built from **AWS Security Specialty** material stored in `RAG_Documents/`.

## 🧨 Tear Down

To remove all deployed infrastructure and stop AWS charges:

run terraform destroy



## 🧑‍💻 Author

Built as a **production-inspired cloud architecture project** using Terraform and AWS.

The objective of this repository is to demonstrate how modern AI systems can be deployed using:

- Infrastructure as Code
- Serverless compute
- Vector databases
- API-driven architectures

The focus is on **design decisions, deployment challenges, and real-world infrastructure patterns**, not just getting services to run.

---

⭐ If this project helped you or you found it interesting, feel free to give the repository a star.
