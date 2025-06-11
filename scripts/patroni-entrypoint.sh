#!/bin/bash
set -e

echo "🚀 PATRONI ENTRYPOINT STARTING..."

# Install patroni and required packages
apt-get update
apt-get install -y python3-pip python3-dev libpq-dev curl
pip3 install patroni[etcd]==2.1.4 psycopg2-binary

# Create patroni configuration
mkdir -p /etc/patroni

# Start patroni
exec patroni /etc/patroni.yml 