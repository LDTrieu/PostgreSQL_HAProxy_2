#!/bin/bash
set -e

# Create replication user
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE USER replicator REPLICATION PASSWORD 'replicator123';
EOSQL

# Copy custom pg_hba.conf if it exists
if [ -f /etc/postgresql/pg_hba.conf ]; then
    cp /etc/postgresql/pg_hba.conf /var/lib/postgresql/data/pg_hba.conf
    echo "Custom pg_hba.conf copied successfully"
fi

echo "Replication setup completed" 