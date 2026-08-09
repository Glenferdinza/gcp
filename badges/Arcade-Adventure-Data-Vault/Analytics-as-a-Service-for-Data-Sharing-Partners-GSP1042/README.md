# Analytics as a Service for Data Sharing Partners || GSP1042 ||

## Solution Overview
This script automates all the tasks required for completing the **Analytics as a Service for Data Sharing Partners (GSP1042)** lab in Google Cloud Skills Boost.

---

## Run the following Commands in CloudShell

```bash
curl -LO https://raw.githubusercontent.com/Glenferdinza/gcp/main/badges/Arcade-Adventure-Data-Vault/Analytics-as-a-Service-for-Data-Sharing-Partners-GSP1042/gsp1042.sh
chmod +x gsp1042.sh
./gsp1042.sh
```

---

## Alternative Execution (Export Environment Variables First)

If you prefer to export variables beforehand, run:

```bash
export CUSTOMER_A_USER="CUSTOMER_A_USERNAME"
export CUSTOMER_B_USER="CUSTOMER_B_USERNAME"
export CUSTOMER_A_PROJECT="CUSTOMER_A_PROJECT_ID"
export CUSTOMER_B_PROJECT="CUSTOMER_B_PROJECT_ID"

curl -LO https://raw.githubusercontent.com/Glenferdinza/gcp/main/badges/Arcade-Adventure-Data-Vault/Analytics-as-a-Service-for-Data-Sharing-Partners-GSP1042/gsp1042.sh
chmod +x gsp1042.sh
./gsp1042.sh
```

---

## Congratulations for completing the Lab!

You have successfully completed the tasks:
1. Created Authorized Views A and B in Data Sharing Partner project.
2. Authorized Views A and B in dataset `demo_dataset`.
3. Granted `roles/bigquery.dataViewer` IAM permissions to Customer A & B users.
4. Created `customer_a_table` view in Customer A Project.
5. Created `customer_b_table` view in Customer B Project.
