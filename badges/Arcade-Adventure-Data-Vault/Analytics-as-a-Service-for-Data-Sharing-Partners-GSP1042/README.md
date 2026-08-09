# Analytics as a Service for Data Sharing Partners || GSP1042 ||

## Solution Overview
Script ini dibuat khusus untuk menyelesaikan lab **Analytics as a Service for Data Sharing Partners (GSP1042)** pada Google Cloud Skills Boost secara otomatis dan aman.

---

## Run the following Commands in CloudShell

```bash
curl -LO https://raw.githubusercontent.com/Glenferdinza/gcp/main/badges/Arcade-Adventure-Data-Vault/Analytics-as-a-Service-for-Data-Sharing-Partners-GSP1042/gsp1042.sh
chmod +x gsp1042.sh
./gsp1042.sh
```

---

## Fitur & Keamanan Script

1. **Auto-Detect Credentials & Project ID**: Script secara otomatis mendeteksi project active (`gcloud config get-value project`) dan akun active di Cloud Shell.
2. **Interactive Input Prompts**: Parameter yang memerlukan input manual (Customer A User, Customer B User, Customer A Project, Customer B Project) akan diminta secara otomatis saat script pertama kali dijalankan.
3. **Safe Execution**: Menggunakan tools resmi Google Cloud (`gcloud`, `bq`) dan library standar Python `json` tanpa menyimpan credentials atau token dalam bentuk hardcode.
4. **Input Sanitization**: Membersihkan prefix `user:` jika Anda melakukan copy-paste email akun student dari halaman lab.

---

## Task Verification Summary

Script akan secara otomatis menyelesaikan seluruh task:
1. Membuat Authorized Views A (Texas) dan B (California) di `demo_dataset`.
2. Mendaftarkan Authorized Views di dataset metadata `demo_dataset`.
3. Memberikan IAM Role `roles/bigquery.dataViewer` ke Customer A User & Customer B User.
4. Membuat view `customer_a_table` pada Customer A Project.
5. Membuat view `customer_b_table` pada Customer B Project.
