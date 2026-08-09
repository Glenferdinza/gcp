# Consuming Customer Specific Datasets from Data Sharing Partners using BigQuery || GSP1043 ||

## Solution Overview
Script ini dibuat khusus untuk menyelesaikan lab **Consuming Customer Specific Datasets from Data Sharing Partners using BigQuery (GSP1043)** pada Google Cloud Skills Boost secara otomatis dan aman.

---

## Run the following Commands in CloudShell

```bash
curl -LO https://raw.githubusercontent.com/Glenferdinza/gcp/main/badges/Arcade-Adventure-Data-Vault/Consuming-Customer-Specific-Datasets-from-Data-Sharing-Partners-using-BigQuery-GSP1043/gsp1043.sh
chmod +x gsp1043.sh
./gsp1043.sh
```

---

## Fitur & Keamanan Script

1. **Auto-Detect Credentials & Projects**: Script secara otomatis mendeteksi Project ID dan Username untuk Data Sharing Partner, Data Publisher, dan Customer (Data Twin) langsung dari sesi Cloud Shell.
2. **Safe Execution**: Menggunakan tools resmi Google Cloud (`gcloud`, `bq`) dan library standar Python `json` tanpa menyimpan credentials atau token hardcoded.
3. **Multi-Console Awareness**: Script dapat dijalankan di Cloud Shell konsol manapun (Partner, Publisher, maupun Customer) dan secara otomatis menyesuaikan eksekusi task yang relevan.

---

## Task Verification Summary

Script akan secara otomatis menyelesaikan seluruh task:
1. Membuat `authorized_table` di `demo_dataset` pada Data Sharing Partner Project dan mengabaikan otorisasi IAM.
2. Membuat `authorized_view` di `data_publisher_dataset` pada Data Publisher Project dan memberikan izin ke Customer User.
3. Menggabungkan data di Customer Project untuk membuat `customer_table` view (Data Twin).
4. Melakukan `INSERT INTO` baris baru pada Data Sharing Partner project untuk konfirmasi fungsionalitas Data Twin.
