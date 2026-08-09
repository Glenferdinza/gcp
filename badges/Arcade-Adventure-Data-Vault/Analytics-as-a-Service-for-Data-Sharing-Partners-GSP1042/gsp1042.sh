#!/bin/bash
set -eo pipefail

echo "========================================================"
echo " Analytics as a Service for Data Sharing Partners "
echo " Lab ID: GSP1042 "
echo "========================================================"

PARTNER_PROJECT=$(gcloud config get-value project 2>/dev/null)

if [ -z "$PARTNER_PROJECT" ]; then
    read -p "Enter Data Sharing Partner Project ID: " PARTNER_PROJECT
fi

echo "Data Sharing Partner Project: $PARTNER_PROJECT"

if [ -z "$CUSTOMER_A_USER" ]; then
    read -p "Enter Customer A Username (e.g. student-01-xxxx@qwiklabs.net): " CUSTOMER_A_USER
fi

if [ -z "$CUSTOMER_B_USER" ]; then
    read -p "Enter Customer B Username (e.g. student-02-xxxx@qwiklabs.net): " CUSTOMER_B_USER
fi

if [ -z "$CUSTOMER_A_PROJECT" ]; then
    read -p "Enter Customer A Project ID: " CUSTOMER_A_PROJECT
fi

if [ -z "$CUSTOMER_B_PROJECT" ]; then
    read -p "Enter Customer B Project ID: " CUSTOMER_B_PROJECT
fi

echo "--------------------------------------------------------"
echo "Task 1: Creating Dataset and Authorized Views A & B..."

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

echo "--------------------------------------------------------"
echo "Task 2: Assigning Authorized Views permissions in demo_dataset..."

python3 -c "
from google.cloud import bigquery

project_id = '$PARTNER_PROJECT'
client = bigquery.Client(project=project_id)
dataset_ref = f'{project_id}.demo_dataset'

dataset = client.get_dataset(dataset_ref)
entries = dataset.access_entries

views_to_add = [
    {'projectId': project_id, 'datasetId': 'demo_dataset', 'tableId': 'authorized_view_a'},
    {'projectId': project_id, 'datasetId': 'demo_dataset', 'tableId': 'authorized_view_b'}
]

existing_views = [e.entity_id for e in entries if e.entity_type == 'view']
for view in views_to_add:
    if view not in existing_views:
        entries.append(bigquery.AccessEntry(role=None, entity_type='view', entity_id=view))

dataset.access_entries = entries
client.update_dataset(dataset, ['access_entries'])
print('Views authorized in dataset metadata.')
"

echo "Task 2 completed successfully."

echo "--------------------------------------------------------"
echo "Task 3: Granting IAM permissions to Customer A & B..."

bq query --use_legacy_sql=false \
"GRANT \`roles/bigquery.dataViewer\`
ON TABLE \`${PARTNER_PROJECT}.demo_dataset.authorized_view_a\`
TO 'user:${CUSTOMER_A_USER}';"

bq query --use_legacy_sql=false \
"GRANT \`roles/bigquery.dataViewer\`
ON TABLE \`${PARTNER_PROJECT}.demo_dataset.authorized_view_b\`
TO 'user:${CUSTOMER_B_USER}';"

echo "Task 3 completed successfully."

echo "--------------------------------------------------------"
echo "Task 4: Displaying insights for View A..."

bq query --use_legacy_sql=false \
"CREATE OR REPLACE VIEW \`${CUSTOMER_A_PROJECT}.customer_a_dataset.customer_a_table\` AS
SELECT geos.zip_code, geos.city, cust.last_name, cust.first_name
FROM \`${CUSTOMER_A_PROJECT}.customer_a_dataset.customer_info\` as cust
JOIN \`${PARTNER_PROJECT}.demo_dataset.authorized_view_a\` as geos
ON geos.zip_code = cust.postal_code;"

echo "Task 4 completed successfully."

echo "--------------------------------------------------------"
echo "Task 5: Displaying insights for View B..."

bq query --use_legacy_sql=false \
"CREATE OR REPLACE VIEW \`${CUSTOMER_B_PROJECT}.customer_b_dataset.customer_b_table\` AS
SELECT geos.zip_code, geos.city, cust.last_name, cust.first_name
FROM \`${CUSTOMER_B_PROJECT}.customer_b_dataset.customer_info\` as cust
JOIN \`${PARTNER_PROJECT}.demo_dataset.authorized_view_b\` as geos
ON geos.zip_code = cust.postal_code;"

echo "Task 5 completed successfully."

echo "========================================================"
echo " Congratulations! All tasks completed successfully. "
echo " Check your progress in Google Cloud Skills Boost. "
echo "========================================================"
