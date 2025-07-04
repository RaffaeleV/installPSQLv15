#!/bin/bash
set -e

# Variables
DISK="/dev/sdb"
MOUNT_POINT="/var/lib/pgsql/data"
PGSQL_PORT=5432
PGSQL_VERSION=15
PG_PASSWORD="P455w0rd"  # Note: use /$ to reference $

echo "[1/8] Partitioning and formatting $DISK..."
# Create partition (non-interactive)
echo -e "o\nn\np\n1\n\n\nw" | fdisk $DISK
PARTITION="${DISK}1"

# Wait for partition to be recognized
udevadm settle

# Format and mount
mkfs.xfs $PARTITION
mkdir -p $MOUNT_POINT
mount $PARTITION $MOUNT_POINT

# Persist in fstab
UUID=$(blkid -s UUID -o value $PARTITION)
echo "UUID=$UUID $MOUNT_POINT xfs defaults 0 0" >> /etc/fstab

echo "[2/8] Adding PostgreSQL Yum Repository and Installing PostgreSQL..."
dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-9-x86_64/pgdg-redhat-repo-latest.noarch.rpm
dnf -qy module disable postgresql
dnf install -y postgresql${PGSQL_VERSION}-server postgresql${PGSQL_VERSION}-contrib

echo "[3/8] Initializing PostgreSQL database on the new disk..."
/usr/pgsql-${PGSQL_VERSION}/bin/postgresql-${PGSQL_VERSION}-setup initdb

# Change ownership just to be safe
chown -R postgres:postgres $MOUNT_POINT

echo "[4/8] Enabling and starting PostgreSQL service..."
systemctl enable --now postgresql-${PGSQL_VERSION}

echo "[5/8] Setting PostgreSQL user password..."
sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD '${PG_PASSWORD}';"

echo "[6/8] Configuring PostgreSQL to listen on all interfaces and enable pg_stat_statements..."
PG_CONF="/var/lib/pgsql/${PGSQL_VERSION}/data/postgresql.conf"
HBA_CONF="/var/lib/pgsql/${PGSQL_VERSION}/data/pg_hba.conf"

# Listen on all IPs
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" $PG_CONF

# Add pg_stat_statements to preload libraries
if ! grep -q "shared_preload_libraries" $PG_CONF; then
  echo "shared_preload_libraries = 'pg_stat_statements'" >> $PG_CONF
else
  sed -i "s|#*shared_preload_libraries *=.*|shared_preload_libraries = 'pg_stat_statements'|" $PG_CONF
fi

# Recommended additional settings for pg_stat_statements
echo "pg_stat_statements.max = 10000" >> $PG_CONF
echo "pg_stat_statements.track = all" >> $PG_CONF

# Allow connections from LAN (adjust subnet as needed)
echo "host    all             all             192.168.0.0/16            md5" >> $HBA_CONF

echo "[7/8] Configuring firewall..."
firewall-cmd --permanent --add-port=${PGSQL_PORT}/tcp
firewall-cmd --reload

echo "[8/8] Restarting PostgreSQL and creating extension..."
systemctl restart postgresql-${PGSQL_VERSION}

# Enable pg_stat_statements in the default DB
sudo -u postgres psql -d postgres -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;"

echo "PostgreSQL setup complete with pg_stat_statements enabled."

# Manual instructions for Veeam PostgreSQL tuning
cat <<EOF

Manual Configuration Required for Veeam Backup & Replication
------------------------------------------------------------
To adjust the configuration of the PostgreSQL instance for optimal use with Veeam Backup & Replication,
follow these steps:
1. On the backup server, run the following PowerShell cmdlet to generate configuration parameters:
   Set-VBRPSQLDatabaseServerLimits -OSType Linux -CPUCount <CPU cores> -RamGb <RAM in GB> -DumpToFile <file path>
   Example:
   Set-VBRPSQLDatabaseServerLimits -OSType Linux -CPUCount 16 -RamGb 32 -DumpToFile "C:\config.sql"

2. Copy the generated file (e.g., config.sql) to the Linux machine where PostgreSQL is installed.

3. Apply the configuration using the psql CLI tool:
   psql -U <user> -f <file path>
   Example:
   psql -U postgres -f "/tmp/config.sql"

This will update PostgreSQL parameters and write them into:
   postgresql.auto.conf
This file is read automatically at service startup and overrides default settings.

EOF
