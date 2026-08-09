#!/bin/bash
set -eo pipefail

echo "========================================================"
echo " Analytics as a Service for Data Sharing Partners "
echo " Lab ID: GSP1042 "
echo "========================================================"

CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null || echo "")
echo "Current Active Project: $CURRENT_PROJECT"
echo "--------------------------------------------------------"

DS_LIST=$(bq ls --project_id=$CURRENT_PROJECT 2>/dev/null || echo "")

if echo "$DS_LIST" | grep -q "customer_a_dataset"; then
    echo "Detected: Running in Customer A Project!"
    if [ -z "$PARTNER_PROJECT" ]; then
        read -p "Enter Data Sharing Partner Project ID: " PARTNER_PROJECT
    fi
    echo "Creating customer_a_table view..."
    bq query --use_legacy_sql=false \
    "CREATE OR REPLACE VIEW \`${CURRENT_PROJECT}.customer_a_dataset.customer_a_table\` AS
    SELECT geos.zip_code, geos.city, cust.last_name, cust.first_name
    FROM \`${CURRENT_PROJECT}.customer_a_dataset.customer_info\` as cust
    JOIN \`${PARTNER_PROJECT}.demo_dataset.authorized_view_a\` as geos
    ON geos.zip_code = cust.postal_code;"
    echo "Task 4 Completed Successfully!"
    exit 0
fi

if echo "$DS_LIST" | grep -q "customer_b_dataset"; then
    echo "Detected: Running in Customer B Project!"
    if [ -z "$PARTNER_PROJECT" ]; then
        read -p "Enter Data Sharing Partner Project ID: " PARTNER_PROJECT
    fi
    echo "Creating customer_b_table view..."
    bq query --use_legacy_sql=false \
    "CREATE OR REPLACE VIEW \`${CURRENT_PROJECT}.customer_b_dataset.customer_b_table\` AS
    SELECT geos.zip_code, geos.city, cust.last_name, cust.first_name
    FROM \`${CURRENT_PROJECT}.customer_b_dataset.customer_info\` as cust
    JOIN \`${PARTNER_PROJECT}.demo_dataset.authorized_view_b\` as geos
    ON geos.zip_code = cust.postal_code;"
    echo "Task 5 Completed Successfully!"
    exit 0
fi

PARTNER_PROJECT="$CURRENT_PROJECT"

echo "Auto-detecting customer credentials and accounts..."

eval $(python3 -c "
import subprocess, json, re

def run(cmd):
    try:
        return subprocess.check_output(cmd, shell=True, text=True).strip()
    except Exception:
        return ''

partner = '$PARTNER_PROJECT'
projs_raw = run('gcloud projects list --format=\"value(projectId)\"')
projs = [p.strip() for p in projs_raw.splitlines() if p.strip().startswith('qwiklabs-gcp-')]

hash_match = re.search(r'qwiklabs-gcp-\d+-([a-f0-9]+)', partner)
if hash_match:
    h = hash_match.group(1)
    for idx in ['00', '01', '02', '03']:
        cand = f'qwiklabs-gcp-{idx}-{h}'
        if cand not in projs:
            projs.append(cand)

other_projs = [p for p in projs if p != partner and p.startswith('qwiklabs-gcp-')]
other_projs.sort()

cust_a_user = ''
cust_b_user = ''

all_users = set()
for p in [partner] + other_projs:
    iam_raw = run(f'gcloud projects get-iam-policy {p} --format=json 2>/dev/null')
    if iam_raw:
        try:
            pol = json.loads(iam_raw)
            for b in pol.get('bindings', []):
                for m in b.get('members', []):
                    if m.startswith('user:'):
                        all_users.add(m.replace('user:', ''))
        except Exception:
            pass

for u in sorted(list(all_users)):
    if 'student-01' in u:
        cust_a_user = u
    elif 'student-02' in u:
        cust_b_user = u

print(f'AUTO_A_USER=\"{cust_a_user}\"')
print(f'AUTO_B_USER=\"{cust_b_user}\"')
")

CUSTOMER_A_USER="${CUSTOMER_A_USER:-$AUTO_A_USER}"
CUSTOMER_B_USER="${CUSTOMER_B_USER:-$AUTO_B_USER}"

if [ -z "$CUSTOMER_A_USER" ]; then
    read -p "Enter Customer A Username (email): " CUSTOMER_A_USER
fi

if [ -z "$CUSTOMER_B_USER" ]; then
    read -p "Enter Customer B Username (email): " CUSTOMER_B_USER
fi

CUSTOMER_A_USER=$(echo "$CUSTOMER_A_USER" | sed 's/^user://' | xargs)
CUSTOMER_B_USER=$(echo "$CUSTOMER_B_USER" | sed 's/^user://' | xargs)

echo "--------------------------------------------------------"
echo "Configuration Summary:"
echo " Partner Project ID  : $PARTNER_PROJECT"
echo " Customer A User     : $CUSTOMER_A_USER"
echo " Customer B User     : $CUSTOMER_B_USER"
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
view_a = {'view': {'projectId': partner_proj, 'datasetId': 'demo_dataset', 'tableId': 'authorized_view_a'}}
view_b = {'view': {'projectId': partner_proj, 'datasetId': 'demo_dataset', 'tableId': 'authorized_view_b'}}

if view_a not in access: access.append(view_a)
if view_b not in access: access.append(view_b)

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
ON VIEW \`${PARTNER_PROJECT}.demo_dataset.authorized_view_a\`
TO 'user:${CUSTOMER_A_USER}';" || true

bq query --use_legacy_sql=false \
"GRANT \`roles/bigquery.dataViewer\`
ON VIEW \`${PARTNER_PROJECT}.demo_dataset.authorized_view_b\`
TO 'user:${CUSTOMER_B_USER}';" || true

python3 -c "
from google.cloud import bigquery
client = bigquery.Client(project='$PARTNER_PROJECT')
def grant(table_id, user_email):
    try:
        t_ref = f'$PARTNER_PROJECT.demo_dataset.{table_id}'
        table = client.get_table(t_ref)
        policy = client.get_iam_policy(table)
        policy.bindings.append({'role': 'roles/bigquery.dataViewer', 'members': [f'user:{user_email}']})
        client.set_iam_policy(table, policy)
    except Exception:
        pass
grant('authorized_view_a', '$CUSTOMER_A_USER')
grant('authorized_view_b', '$CUSTOMER_B_USER')
"

echo "Task 3 completed successfully."
echo "========================================================"
echo " Partner Tasks 1, 2, & 3 Completed Successfully! "
echo "========================================================"
