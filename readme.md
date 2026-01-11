<<<<<<< HEAD
# AI-Powered Receipt Processing System

This project is a hybrid cloud solution that processes market receipts using AWS serverless technologies and stores structured data in an Oracle Autonomous Database.

The system utilizes Amazon Textract for OCR and Amazon Bedrock (Claude 3 Haiku) for intelligent data extraction, ensuring high accuracy in parsing receipt details.

---

## System Architecture

The infrastructure is built on a custom Virtual Private Cloud (VPC) to ensure network isolation. Public and private resources are strictly separated.

![System Architecture Diagram](https://i.hizliresim.com/ex54f2a.png)

### Core Components

- **VPC & Subnets:** The network is divided into Public and Private subnets. Application logic resides in the Private subnet with no direct internet access.
- **AWS NAT Gateway / NAT Instance:** The infrastructure code defaults to **NAT Gateway** for high availability and production standards. However, the architecture diagram depicts a **NAT Instance**, and the Terraform code includes a toggleable module for this cost-effective alternative suitable for development environments.
- **Oracle Database Security:** The database is configured with an Access Control List (ACL) that only accepts connections from the NAT Gateway's static IP.

---

## Data Flow

1. **Upload:** A receipt image is uploaded to an Amazon S3 bucket.
2. **Trigger:** The upload event triggers a Lambda function located in the Private Subnet.
3. **Processing:**
   - **Textract** extracts raw text from the image.
   - **Bedrock (Claude 3)** parses the text into a structured JSON format.
   - Traffic to these services is routed internally via VPC Endpoints.
4. **Storage:** The processed data is sent to the Oracle Autonomous Database.
5. **Security:** The connection uses mTLS (Oracle Wallet) and originates from the whitelisted NAT Gateway IP.
6. **Retrieval:** Users can query the processed data via an API Gateway endpoint.

=======
# AI-Powered Receipt Processing System 

This project is a hybrid cloud system that automatically reads market receipts and stores structured data securely.  
AWS is used for serverless AI processing and API management, while Oracle Cloud (OCI) is used for high-performance and secure data persistence.

---

## System Architecture 

The system is designed with **maximum network isolation**.  
All sensitive processing stays inside private networks, and outbound traffic is strictly controlled through a single point.

### Architecture Diagram

![Security-First Hybrid Cloud Architecture](https://i.hizliresim.com/ex54f2a.png)

**Diagram Explanation:**

- **Custom AWS VPC (172.0.0.0/16):** A dedicated virtual private cloud provides an isolated network environment, ensuring that the project resources are not part of the default shared network.

- **Private Subnet (172.0.1.0/24):** All processing logic and Lambda functions are located here. This subnet has no direct access to the internet, which protects the core application from external threats.

- **Public Subnet (172.0.2.0/24):** This layer acts as a managed entry and exit point. It hosts the components that need to communicate with the outside world, such as the API Gateway and the NAT Instance.

- **NAT Instance & Static IP (3.239.6.232):** Since the Lambdas are in a private subnet, they use this NAT Instance to send data to the Oracle Database. The static Elastic IP allows for a consistent identity when communicating outside of AWS.

- **AWS API Gateway:** This serves as the secure front door for the application. It receives external requests for data retrieval and forwards them to the internal functions.

- **Oracle Autonomous Database (OCI) Connectivity:** To ensure maximum security, the Oracle Database is configured to reject all traffic except for requests coming from the specific static IP of the AWS NAT Instance.

---

## Network and Security Details

The architecture follows a strict *deny-by-default* model.

### Network Segmentation (IP Plan)

| Component | Location | CIDR / IP | Purpose |
| :--- | :--- | :--- | :--- |
| VPC | AWS | 172.0.0.0/16 | Main isolated network |
| Private Subnet | AWS | 172.0.1.0/24 | Lambda, VPC Endpoints |
| Public Subnet | AWS | 172.0.2.0/24 | NAT Instance, API Gateway Path |
| NAT Instance | AWS | 3.239.6.232 | Single authorized egress |
| Oracle DB | OCI | Private Endpoint | Data persistence |

No compute resource has direct internet access.

---

## End-to-End Data Flow

1. **Receipt Upload:** The user uploads a receipt image to Amazon S3.
2. **Event-Driven Processing:** An S3 event triggers an AWS Lambda function inside the Private Subnet.
3. **Private AI & OCR:** - Amazon Textract extracts text.
   - Amazon Bedrock (Claude 3 Haiku) transforms OCR output into structured JSON.
   - All access happens through **VPC Interface Endpoints (PrivateLink)**.
4. **Controlled Egress:** When data must be saved to Oracle Cloud, traffic is routed through the **NAT Instance**.
5. **Data Retrieval (API):** Authorized users or applications can fetch the processed receipt data through **AWS API Gateway**. This triggers a retrieval Lambda that securely queries the Oracle Database.
6. **Oracle Cloud Access:** Oracle Autonomous Database only accepts connections from **3.239.6.232 (whitelisted static IP)**.

7. **Monitoring & Logging:** Every step of the execution, from S3 triggers to Database connection attempts, is logged via Amazon CloudWatch. Custom metrics and alarms are set up to notify in case of Lambda failures or timeout issues.
>>>>>>> 494d6122b4f2102cabba4efd1ca9f422ec725ab3
---

## Technical Stack

<<<<<<< HEAD
- **Infrastructure:** Terraform
- **Runtime:** Python 3.12
- **Compute:** AWS Lambda
- **AI & OCR:** Amazon Bedrock (Claude 3 Haiku), Amazon Textract
- **Database:** Oracle Autonomous Database (OCI)
- **Networking:** AWS VPC, NAT Gateway, VPC Endpoints
- **Logging:** Amazon CloudWatch

---

## Deployment Guide

Follow these steps to deploy the infrastructure.

### 1. Clone the Repository

Clone the project source code to your local environment.

### 2. Configure Environment Variables

Create a `terraform.tfvars` file in the root directory to store your sensitive credentials. This file is excluded from version control.

```hcl
db_user         = "ADMIN"
db_password     = "YourStrongPassword"
db_dsn          = "db2024_high"
wallet_password = "YourWalletPassword"
```

### 3. Setup Oracle Wallet
Download the Client Credentials (Wallet) zip file from the OCI Console. Extract the contents (cwallet.sso, tnsnames.ora, etc.) into the following directories:

- lambda_source/ocr_processor/wallet/

- lambda_source/db_reader/wallet/

Note: Terraform allows these directories to be local-only. It will automatically zip them with the code during deployment.

### 4. Apply Infrastructure
Initialize and apply the Terraform configuration:
```
terraform init
terraform apply
```

### 5. Final Configuration
1. After the deployment finishes, Terraform will output a value named nat_gateway_ip.

2. Copy this IP address.

3. Navigate to your Oracle Autonomous Database settings in OCI.

4. Add the IP to the Network Access Control List (ACL).

5. Save the changes to allow connectivity.



### Database Schema
Execute the following SQL script to create the required table in your Oracle Database:
```
=======
- **API Layer:** AWS API Gateway
- **Compute:** AWS Lambda (Python 3.12)
- **OCR:** Amazon Textract
- **AI Processing:** Amazon Bedrock (Claude 3 Haiku)
- **Storage:** Amazon S3 (private access via Gateway Endpoint)
- **Database:** Oracle Autonomous Database (OCI, mTLS 
Wallet)
- **Monitoring:** Amazon CloudWatch (Logs, Metrics, and Alarms)
---

## Database Schema (Oracle SQL)

```sql
>>>>>>> 494d6122b4f2102cabba4efd1ca9f422ec725ab3
CREATE TABLE market_fisleri (
    id NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    magaza_adi VARCHAR2(255),
    fis_tarihi DATE,
    fis_saati VARCHAR2(10),
    toplam_tutar NUMBER(10, 2),
    kdv_tutari NUMBER(10, 2),
    odeme_tipi VARCHAR2(50),
    urun_listesi CLOB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```


<<<<<<< HEAD
### Developer Notes
- Source Packaging: Python source code and Wallet files are automatically zipped by Terraform during the apply phase.


- **NAT Strategy:** The project is configured to use a **NAT Gateway** by default to ensure maximum stability and zero maintenance. However, since NAT Gateways incur a fixed hourly cost, the `main.tf` file contains a commented-out configuration for a **NAT Instance (t2.micro)**. Developers can switch to the NAT Instance to reduce AWS costs to nearly zero during the testing phase.
=======
## Developer Notes
- A NAT Instance (t2.micro) is used instead of a Managed NAT Gateway to reduce monthly costs.

- The system uses Security Groups and NACLs to control all traffic.

- No backend resource is open to the public internet.

- The design follows the principles of Least-Privilege and Zero-Trust.

- API Gateway acts as the only secure bridge for inbound data requests.
- Observability: All Lambda functions follow a structured logging format sent to CloudWatch Logs, allowing for real-time debugging and performance monitoring of the AI extraction pipeline.
>>>>>>> 494d6122b4f2102cabba4efd1ca9f422ec725ab3
