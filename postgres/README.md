# A set of scripts to simplify some routine tasks in PostgreSQL

[По-русски / In Russian](README.ru.md)

- <install_pg_profile.sh> Download, build and install pg_profile extension for PostgreSQL (the script will download and install the pg_stat_kcache and pg_profile extensions from the official git repos)

- <yc_psql.sh> A wrapper script for quick connection to Yandec.Cloud Managed PostgreSQL clusters (script get a list of clusters, databases and users interactively, passwords are taken from Vault along a specific path, then you connect to the cluster via psql/usql with the received data)

Author: Mikhail Grigoryev <sleuthhound@gmail.com>
