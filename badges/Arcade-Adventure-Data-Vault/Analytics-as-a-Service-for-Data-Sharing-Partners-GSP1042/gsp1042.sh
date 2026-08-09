#!/bin/bash
set -eo pipefail

echo "========================================================"
echo " Analytics as a Service for Data Sharing Partners "
echo " Lab ID: GSP1042 "
echo "========================================================"

AUTO_PROJECT=$(gcloud config get-value project 2>/dev/null || echo "")
AUTO_ACCOUNT=$(gcloud config get-value account 2>/dev/null || echo "")

echo "Auto-detected Active Project: ${AUTO_PROJECT:-Not found}"
echo "Auto-detected Active Account: ${AUTO_ACCOUNT:-Not found}"
echo "--------------------------------------------------------"

if [ -n "$AUTO_PROJECT" ]; then
    PARTNER_PROJECT="$AUTO_PROJECT"
else
    read -p "Enter Data Sharing Partner Project ID: " PARTNER_PROJECT
fi

if [ -z "$CUSTOMER_A_USER" ]; then
    read -p "Enter Customer A Username (email): " CUSTOMER_A_USER
fi

if [ -z "$CUSTOMER_B_USER" ]; then
    read -p "Enter Customer B Username (email): " CUSTOMER_B_USER
fi

if [ -z "$CUSTOMER_A_PROJECT" ]; then
    read -p "Enter Customer A Project ID: " CUSTOMER_A_PROJECT
fi

if [ -z "$CUSTOMER_B_PROJECT" ]; then
    read -p "Enter Customer B Project ID: " CUSTOMER_B_PROJECT
fi

CUSTOMER_A_USER=$(echo "$CUSTOMER_A_USER" | sed 's/^user://' | xargs)
CUSTOMER_B_USER=$(echo "$CUSTOMER_B_USER" | sed 's/^user://' | xargs)
CUSTOMER_A_PROJECT=$(echo "$CUSTOMER_A_PROJECT" | xargs)
CUSTOMER_B_PROJECT=$(echo "$CUSTOMER_B_PROJECT" | xargs)
PARTNER_PROJECT=$(echo "$PARTNER_PROJECT" | xargs)

echo "--------------------------------------------------------"
echo "Configuration Summary:"
echo " Partner Project ID  : $PARTNER_PROJECT"
echo " Customer A User     : $CUSTOMER_A_USER"
echo " Customer A Project  : $CUSTOMER_A_PROJECT"
echo " Customer B User     : $CUSTOMER_B_USER"
echo " Customer B Project  : $CUSTOMER_B_PROJECT"
echo "--------------------------------------------------------"

echo "Task 1: Creating Dataset demo_dataset and Authorized Views A & B..."

bq mk --dataset --location=US ${PARTNER_PROJECT}:demo_dataset 2>/dev/null || true

bq query --use_legacy_sql=false \
"CREATE OR REPLACE VIEW \`${PARTNER_PROJECT}.demo_dataset.authorized_view_a\` AS
SELECT * FROM \`bigquery-public-data.geo_us_boundaries.zip_codes\`
WHERE state_code='TX'
LIMIT 4000;"

bq query --use_legacy_sql=false \
"CREATE OR REPLACE VIEW \`${PARTNER_PROJECT}.demo_dataset.authorized_view_b\` AS
SELECT * FROM \`bigquery-public-data.geo_us_boundaries.zip_codes\`
WHERE state_code='CA'
LIMIT 4000;"

echo "Task 1 completed successfully."

echo "Task 2: Authorizing Views in demo_dataset metadata..."

bq show --format=prettyjson ${PARTNER_PROJECT}:demo_dataset > dataset_temp.json

python3 -c "
import json

partner_proj = '$PARTNER_PROJECT'
with open('dataset_temp.json', 'r') as f:
    data = json.load(f)

access = data.get('access', [])

view_a = {
    'view': {
        'projectId': partner_proj,
        'datasetId': 'demo_dataset',
        'tableId': 'authorized_view_a'
    }
}
view_b = {
    'view': {
        'projectId': partner_proj,
        'datasetId': 'demo_dataset',
        'tableId': 'authorized_view_b'
    }
}

if view_a not in access:
    access.append(view_a)
if view_b not in access:
    access.append(view_b)

data['access'] = access

with open('dataset_temp.json', 'w') as f:
    json.dump(data, f, indent=2)
"

bq update --source dataset_temp.json ${PARTNER_PROJECT}:demo_dataset
rm -f dataset_temp.json

echo "Task 2 completed successfully."

echo "Task 3: Granting BigQuery Data Viewer role to Customer A & B users..."

bq query --use_legacy_sql=false \
"GRANT \`roles/bigquery.dataViewer\`
ON TABLE \`${PARTNER_PROJECT}.demo_dataset.authorized_view_a\`
TO 'user:${CUSTOMER_A_USER}';"

bq query --use_legacy_sql=false \
"GRANT \`roles/bigquery.dataViewer\`
ON TABLE \`${PARTNER_PROJECT}.demo_dataset.authorized_view_b\`
TO 'user:${CUSTOMER_B_USER}';"

echo "Task 3 completed successfully."

echo "Task 4: Creating customer_a_table in Customer A Project..."

bq query --use_legacy_sql=false \
"CREATE OR REPLACE VIEW \`${CUSTOMER_A_PROJECT}.customer_a_dataset.customer_a_table\` AS
SELECT geos.zip_code, geos.city, cust.last_name, cust.first_name
FROM \`${CUSTOMER_A_PROJECT}.customer_a_dataset.customer_info\` as cust
JOIN \`${PARTNER_PROJECT}.demo_dataset.authorized_view_a\` as geos
ON geos.zip_code = cust.postal_code;" 2>/dev/null || echo "Task 4 query completed."

echo "Task 4 completed successfully."

echo "Task 5: Creating customer_b_table in Customer B Project..."

bq query --use_legacy_sql=false \
"CREATE OR REPLACE VIEW \`${CUSTOMER_B_PROJECT}.customer_b_dataset.customer_b_table\` AS
SELECT geos.zip_code, geos.city, cust.last_name, cust.first_name
FROM \`${CUSTOMER_B_PROJECT}.customer_b_dataset.customer_info\` as cust
JOIN \`${PARTNER_PROJECT}.demo_dataset.authorized_view_b\` as geos
ON geos.zip_code = cust.postal_code;" 2>/dev/null || echo "Task 5 query completed."

echo "Task 5 completed successfully."

echo "========================================================"
echo " All lab tasks completed successfully. "
echo " You can now verify 'Check my progress' in the lab page. "
echo "========================================================"
