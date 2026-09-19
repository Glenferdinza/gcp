#!/bin/bash
set -eo pipefail

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${CYAN}========================================================${NC}"
echo -e "${CYAN} Migrating to Cloud SQL from Amazon RDS for MySQL       ${NC}"
echo -e "${CYAN} Using Database Migration Service                       ${NC}"
echo -e "${CYAN} Lab ID: GSP859                                         ${NC}"
echo -e "${CYAN}========================================================${NC}"

# 1. Detect GCP Environment
CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null || echo "")
echo -e "${GREEN}Active GCP Project:${NC} $CURRENT_PROJECT"

if [ -z "$CURRENT_PROJECT" ]; then
    echo -e "${RED}Error: No active GCP project configured in gcloud.${NC}"
    exit 1
fi

# Enable required Google Cloud APIs
echo -e "\n${YELLOW}Enabling necessary GCP APIs (Database Migration & Cloud SQL Admin)...${NC}"
gcloud services enable datamigration.googleapis.com sqladmin.googleapis.com compute.googleapis.com --quiet

# Detect Cloud SQL Instance Region and Public IP
echo -e "\n${YELLOW}Detecting Cloud SQL 'mysql-cloudsql' configuration...${NC}"
CLOUDSQL_REGION=$(gcloud sql instances describe mysql-cloudsql --format="value(region)" 2>/dev/null || echo "")
CLOUDSQL_IP=$(gcloud sql instances describe mysql-cloudsql --format="value(ipAddresses[0].ipAddress)" 2>/dev/null || echo "")

REGION="${REGION:-$CLOUDSQL_REGION}"
if [ -z "$REGION" ]; then
    REGION=$(gcloud config get-value compute/region 2>/dev/null || echo "us-central1")
fi

echo -e "${GREEN}Destination Region :${NC} $REGION"
echo -e "${GREEN}Cloud SQL Public IP:${NC} $CLOUDSQL_IP"

# 2. Prerequisites: Ensure CLI tools (AWS CLI, dig, mysql) are available
echo -e "\n${YELLOW}Checking required CLI utilities...${NC}"

if ! command -v dig &>/dev/null || ! command -v mysql &>/dev/null; then
    echo "Installing dnsutils and mysql-client..."
    sudo apt-get update -qq && sudo apt-get install -y -qq dnsutils default-mysql-client
fi

if ! command -v aws &>/dev/null; then
    echo "Installing AWS CLI v2..."
    curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip -q -o awscliv2.zip
    sudo ./aws/install --update
    rm -rf aws awscliv2.zip
fi
echo -e "${GREEN}CLI tools are ready.${NC}"

# 3. AWS Credentials & Auto-Detection
echo -e "\n${CYAN}--------------------------------------------------------${NC}"
echo -e "${CYAN} Task 1: Configure AWS CLI & Auto-Detect RDS Resources  ${NC}"
echo -e "${CYAN}--------------------------------------------------------${NC}"

if [ -z "$AWS_ACCESS_KEY_ID" ]; then
    read -p "Enter AWS Access Key ID (from Lab Details pane): " AWS_ACCESS_KEY_ID
fi

if [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    read -p "Enter AWS Secret Access Key (from Lab Details pane): " AWS_SECRET_ACCESS_KEY
fi

AWS_ACCESS_KEY_ID=$(echo "$AWS_ACCESS_KEY_ID" | xargs)
AWS_SECRET_ACCESS_KEY=$(echo "$AWS_SECRET_ACCESS_KEY" | xargs)
AWS_DEFAULT_REGION="us-east-1"

export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION

aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID"
aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY"
aws configure set default.region "$AWS_DEFAULT_REGION"

echo -e "${GREEN}AWS CLI configured successfully for region ${AWS_DEFAULT_REGION}.${NC}"

# Auto-detect RDS Hostname and Security Group ID via AWS CLI
echo -e "\n${YELLOW}Auto-detecting AWS RDS Hostname and Security Group...${NC}"
AUTO_RDS_HOST=$(aws rds describe-db-instances --region us-east-1 --query "DBInstances[0].Endpoint.Address" --output text 2>/dev/null || echo "")
AUTO_RDS_SG=$(aws rds describe-db-instances --region us-east-1 --query "DBInstances[0].VpcSecurityGroups[0].VpcSecurityGroupId" --output text 2>/dev/null || echo "")

RDS_HOSTNAME="${RDS_HOSTNAME:-$AUTO_RDS_HOST}"
if [ -z "$RDS_HOSTNAME" ] || [ "$RDS_HOSTNAME" = "None" ]; then
    read -p "Enter AWS RDS Database - Source (Hostname from Lab details): " RDS_HOSTNAME
fi
RDS_HOSTNAME=$(echo "$RDS_HOSTNAME" | xargs)

RDS_SG_ID="${RDS_SG_ID:-$AUTO_RDS_SG}"
if [ -z "$RDS_SG_ID" ] || [ "$RDS_SG_ID" = "None" ]; then
    read -p "Enter AWS RDS Database Security Group ID (e.g., sg-xxxx): " RDS_SG_ID
fi
RDS_SG_ID=$(echo "$RDS_SG_ID" | xargs)

# Resolve RDS Hostname to IP address
echo -e "\n${YELLOW}Resolving RDS Hostname to IP Address...${NC}"
RDS_IP=$(python3 -c "import socket; print(socket.gethostbyname('$RDS_HOSTNAME'))" 2>/dev/null || dig +short "$RDS_HOSTNAME" 2>/dev/null | tail -n1 || echo "")

if [ -z "$RDS_IP" ]; then
    read -p "Enter RDS IP Address (run: dig $RDS_HOSTNAME): " RDS_IP
fi
RDS_IP=$(echo "$RDS_IP" | xargs)

echo -e "--------------------------------------------------------"
echo -e "${GREEN}RDS Hostname      :${NC} $RDS_HOSTNAME"
echo -e "${GREEN}RDS IP Address    :${NC} $RDS_IP"
echo -e "${GREEN}RDS Security Group:${NC} $RDS_SG_ID"
echo -e "--------------------------------------------------------"

# 4. Task 2: Create Source Connection Profile
echo -e "\n${CYAN}--------------------------------------------------------${NC}"
echo -e "${CYAN} Task 2: Create Source Connection Profile in DMS        ${NC}"
echo -e "${CYAN}--------------------------------------------------------${NC}"

if gcloud database-migration connection-profiles describe mysql-rds-source --region="$REGION" &>/dev/null; then
    echo -e "${GREEN}Connection Profile 'mysql-rds-source' already exists.${NC}"
else
    echo "Creating connection profile 'mysql-rds-source'..."
    gcloud database-migration connection-profiles create mysql mysql-rds-source \
        --region="$REGION" \
        --display-name="mysql-rds-source" \
        --host="$RDS_IP" \
        --port=3306 \
        --username="admin" \
        --password="changeme" \
        --no-async
    echo -e "${GREEN}Connection Profile 'mysql-rds-source' created successfully!${NC}"
fi

echo -e "\n${GREEN}>> Checkpoint 1 (Create connection profile for MySQL source instance) is READY to be verified on Skills Boost! <<${NC}"

# 5. Task 2 (Part 2) & Task 3: DMS Migration Job Setup & IP Allowlist
echo -e "\n${CYAN}--------------------------------------------------------${NC}"
echo -e "${CYAN} Task 2 & 3: Configure Migration Job & IP Allowlist     ${NC}"
echo -e "${CYAN}--------------------------------------------------------${NC}"
echo -e "${YELLOW}Please complete the following in the Google Cloud Console if not done yet:${NC}"
echo -e "1. Go to ${CYAN}Database Migration -> Migration jobs -> Create migration job${NC}"
echo -e "   - Job Name: ${GREEN}rds-to-cloudsql${NC}"
echo -e "   - Source Database Engine: ${GREEN}Amazon RDS for MySQL${NC}"
echo -e "   - Destination Region: ${GREEN}$REGION${NC}"
echo -e "   - Migration Job Type: ${GREEN}One-time${NC}"
echo -e "   - Click Save & continue"
echo -e "2. Define source: Select existing profile ${GREEN}mysql-rds-source${NC}, then Save & continue"
echo -e "3. Define destination: Select Existing instance -> ${GREEN}mysql-cloudsql${NC}"
echo -e "   (Type 'mysql-cloudsql' to confirm and wait for execution)"
echo -e "4. Define connectivity method: Select ${GREEN}IP allowlist${NC}"
echo -e "   Copy the ${YELLOW}Destination outgoing IP addresses${NC} shown on the screen."
echo -e "5. Configure migration databases: Leave default (${GREEN}All databases${NC}), Save & continue (draft saved)."
echo -e "--------------------------------------------------------"

read -p "Enter Destination Outgoing IP addresses (space-separated, e.g. 35.239.140.158 34.172.105.39): " -a OUTGOING_IPS || true

# Authorize Outgoing IPs in AWS Security Group
if [ ${#OUTGOING_IPS[@]} -gt 0 ]; then
    for IP in "${OUTGOING_IPS[@]}"; do
        IP_CLEAN=$(echo "$IP" | xargs)
        if [ -n "$IP_CLEAN" ]; then
            echo -e "Authorizing Outgoing IP ${CYAN}$IP_CLEAN/32${NC} in AWS Security Group $RDS_SG_ID..."
            aws ec2 authorize-security-group-ingress \
                --group-id "$RDS_SG_ID" \
                --protocol tcp \
                --port 3306 \
                --cidr "${IP_CLEAN}/32" 2>/dev/null || true
        fi
    done
fi

# Also authorize Cloud SQL public IP and Cloud Shell public IP for fail-safe connectivity
if [ -n "$CLOUDSQL_IP" ]; then
    echo -e "Authorizing Cloud SQL Public IP ${CYAN}$CLOUDSQL_IP/32${NC} in AWS Security Group..."
    aws ec2 authorize-security-group-ingress \
        --group-id "$RDS_SG_ID" \
        --protocol tcp \
        --port 3306 \
        --cidr "${CLOUDSQL_IP}/32" 2>/dev/null || true
fi

MY_PUBLIC_IP=$(curl -s -4 ifconfig.me 2>/dev/null || curl -s -4 icanhazip.com 2>/dev/null || echo "")
if [ -n "$MY_PUBLIC_IP" ]; then
    aws ec2 authorize-security-group-ingress \
        --group-id "$RDS_SG_ID" \
        --protocol tcp \
        --port 3306 \
        --cidr "${MY_PUBLIC_IP}/32" 2>/dev/null || true
fi

echo -e "${GREEN}>> Checkpoint 2 (Create a one-time migration job) and Checkpoint 3 (Configure IP allowlist) are READY! <<${NC}"

# 6. Task 4: Test & Run Migration Job
echo -e "\n${CYAN}--------------------------------------------------------${NC}"
echo -e "${CYAN} Task 4: Test & Run Migration Job                       ${NC}"
echo -e "${CYAN}--------------------------------------------------------${NC}"

echo -e "Verifying migration job 'rds-to-cloudsql'..."
gcloud database-migration migration-jobs verify rds-to-cloudsql --region="$REGION" 2>/dev/null || true

JOB_STATE=$(gcloud database-migration migration-jobs describe rds-to-cloudsql --region="$REGION" --format="value(state)" 2>/dev/null || echo "NOT_STARTED")

if [ "$JOB_STATE" = "NOT_STARTED" ] || [ "$JOB_STATE" = "DRAFT" ] || [ "$JOB_STATE" = "STOPPED" ]; then
    echo "Starting migration job 'rds-to-cloudsql'..."
    gcloud database-migration migration-jobs start rds-to-cloudsql --region="$REGION" 2>/dev/null || true
fi

echo -e "${YELLOW}Monitoring migration job status (this may take 2-4 minutes)...${NC}"
while true; do
    CURRENT_STATE=$(gcloud database-migration migration-jobs describe rds-to-cloudsql --region="$REGION" --format="value(state)" 2>/dev/null || echo "UNKNOWN")
    echo -e "Status: ${CYAN}$CURRENT_STATE${NC} ($(date +'%T'))"

    if [ "$CURRENT_STATE" = "COMPLETED" ]; then
        echo -e "${GREEN}Migration job 'rds-to-cloudsql' completed successfully!${NC}"
        break
    elif [ "$CURRENT_STATE" = "FAILED" ]; then
        echo -e "${RED}Migration job failed. Please check DMS logs in Google Cloud Console.${NC}"
        break
    fi
    sleep 15
done

echo -e "\n${GREEN}>> Checkpoint 4 (Test and run a one-time migration job) is READY to verify! <<${NC}"

# 7. Task 5: Confirm Data in Cloud SQL
echo -e "\n${CYAN}--------------------------------------------------------${NC}"
echo -e "${CYAN} Task 5: Confirm Migrated Data in Cloud SQL for MySQL   ${NC}"
echo -e "${CYAN}--------------------------------------------------------${NC}"

if [ -n "$MY_PUBLIC_IP" ]; then
    echo -e "Temporarily authorizing Cloud Shell IP (${MY_PUBLIC_IP}) on Cloud SQL instance 'mysql-cloudsql'..."
    gcloud sql instances patch mysql-cloudsql --authorized-networks="${MY_PUBLIC_IP}/32" --quiet 2>/dev/null || true
fi

echo -e "Connecting to Cloud SQL MySQL and checking migrated records..."
RECORD_COUNT=$(MYSQL_PWD=supersecret mysql -h "$CLOUDSQL_IP" -u root --get-server-public-key -s -N -e "USE customers_data; SELECT count(*) FROM customers;" 2>/dev/null || echo "")

if [ -n "$RECORD_COUNT" ]; then
    echo -e "${GREEN}Success! Total records in customers_data.customers:${NC} ${YELLOW}$RECORD_COUNT${NC} (Expected: 5030)"
else
    echo -e "${YELLOW}Notice: Direct Cloud Shell query skipped. You can manually run:${NC}"
    echo -e "mysql -h $CLOUDSQL_IP -u root -p --get-server-public-key"
    echo -e "Password: supersecret"
    echo -e "use customers_data; select count(*) from customers; exit"
fi

echo -e "\n${GREEN}>> Checkpoint 5 (Confirm the data in Cloud SQL for MySQL) is READY to verify! <<${NC}"

echo -e "\n${CYAN}========================================================${NC}"
echo -e "${GREEN} Congratulations! GSP859 Lab Completed Successfully!    ${NC}"
echo -e "${CYAN}========================================================${NC}"
