Script to automate the installation of PostgreSQL 15 on Rocky Linux for Veeam Backup and Replication v12+
=========================================================================================================

Overview
========
This script automates the installation and basic configuration of PostgreSQL 15 on Rocky Linux 9 systems.

It is designed to simplify the process of preparing a PostgreSQL environment, including tuning and service configuration, in deployments where PostgreSQL will be used by Veeam Backup & Replication as the configuration database.

Features
========
Adds the official PostgreSQL 15 repository

Installs PostgreSQL 15 and its contrib package

Initializes the PostgreSQL database

Starts and enables the PostgreSQL service

Sets the PostgreSQL superuser password (postgres)

Initializes the second disk /dev/sdb that will be used to store PostgreSQL data

Include the "pg_stat_statements" library to the PostgreSQL configuration

Suggest the subsequent steps to be performed on Veeam Backup and Replication to ensure that the PostgreSQL target instance is configured according to the recommended hardware resources values (Source: https://helpcenter.veeam.com/docs/backup/powershell/set-vbrpsqldatabaseserverlimits.html?ver=120) 

Requirements
============
Operating System: Rocky Linux 9

Resources: At least 4 CPUs and 8GB RAM and a second disk still to be partitioned

Privileges: Must be run as root or with sudo

Network Access: Required to reach the PostgreSQL Yum repository

Usage
=====
Download the Script:

  curl -O https://raw.githubusercontent.com/RaffaeleV/installPSQL16/main/installPSQLv15.sh 

Make it executable:

  chmod +x installPSQLv15.sh

Run the Script:

  sudo ./installPSQLv15.sh

Customization
=============
Edit the line

  PG_PASSWORD="P455w0rd"

to set a secure password for the default postgres user.

Edit the line

  echo "host    all             all             192.168.0.0/16            md5" >> $HBA_CONF

to change the subnet to match the IP range of your clients.



Disclaimer
==========
The script is intended for test/dev or initial setup use cases. For production deployments, further hardening and tuning is recommended.

License
=======
This script is provided as-is under the MIT license. Use at your own risk.
