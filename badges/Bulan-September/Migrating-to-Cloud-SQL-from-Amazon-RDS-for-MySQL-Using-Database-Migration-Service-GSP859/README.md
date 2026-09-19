# Migrating to Cloud SQL from Amazon RDS for MySQL Using Database Migration Service || GSP859 ||

## Solution Overview
Script ini dibuat khusus untuk menyelesaikan lab **Migrating to Cloud SQL from Amazon RDS for MySQL Using Database Migration Service (GSP859)** pada Google Cloud Skills Boost / Arcade Program secara semi-otomatis, cepat, dan aman.

---

## Run the following Commands in CloudShell

```bash
curl -LO https://raw.githubusercontent.com/Glenferdinza/gcp/main/badges/Bulan-September/Migrating-to-Cloud-SQL-from-Amazon-RDS-for-MySQL-Using-Database-Migration-Service-GSP859/gsp859.sh
chmod +x gsp859.sh
./gsp859.sh
```

---

## Fitur & Keamanan Script

1. **Auto-Detect Setup & Resources**:
   - Mendeteksi project GCP aktif (`gcloud config get-value project`).
   - Mendeteksi Region dan Public IP dari instance Cloud SQL (`mysql-cloudsql`).
   - Mengaktifkan API `datamigration.googleapis.com` dan `sqladmin.googleapis.com` secara otomatis.
   - Menginstal utility yang diperlukan (`aws-cli`, `dnsutils`, `default-mysql-client`).

2. **Smart AWS Auto-Detection & Interactive Fallback**:
   - Meminta input **AWS Access Key ID** dan **AWS Secret Access Key** secara interaktif dari panel *Lab details*.
   - Mengonfigurasi AWS CLI pada region `us-east-1`.
   - Menggunakan AWS CLI untuk **mendeteksi otomatis** endpoint hostname Amazon RDS dan Security Group ID (`sg-xxxx`).
   - Melakukan resolusi DNS otomatis dari RDS Hostname ke IPv4 address (tanpa perlu hitung manual).

3. **Database Migration Service (DMS) Automation**:
   - Membuat connection profile source `mysql-rds-source` via CLI (`gcloud database-migration connection-profiles create`).
   - Mengotomatiskan penambahan IP allowlist pada AWS Security Group (`aws ec2 authorize-security-group-ingress`) untuk semua outgoing IP DMS, IP Cloud SQL, dan IP Cloud Shell.
   - Melakukan verifikasi (`verify`) dan memulai job (`start`), lalu memantau status migration job hingga `COMPLETED`.

4. **Data Verification**:
   - Membuka akses jaringan sementara ke Cloud SQL untuk Cloud Shell.
   - Menjalankan query MySQL untuk memastikan database `customers_data` dan tabel `customers` telah termigrasi dengan total 5.030 baris data.

---

## Task Verification Summary

| Task | Deskripsi | Status Otomatisasi |
|---|---|---|
| **Task 1** | Install and configure the AWS CLI tool in Cloud Shell | **Otomatis** (Instalasi & konfigurasi via credential prompt) |
| **Task 2** | Create a one-time migration job | **Semi-Otomatis** (Profile dibuat via CLI, Job draft di wizard console) |
| **Task 3** | Configure the IP allowlist on source instance | **Otomatis** (Whitelisting IP egress DMS ke Security Group AWS) |
| **Task 4** | Test and run a one-time migration job | **Otomatis** (Verifikasi, start, & polling hingga status `COMPLETED`) |
| **Task 5** | Confirm the data in Cloud SQL for MySQL | **Otomatis** (Query validasi tabel `customers` via client MySQL) |
