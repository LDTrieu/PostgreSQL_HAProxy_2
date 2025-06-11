#!/bin/bash

echo "🔧 FIX REPLICATION AFTER FAILOVER"
echo "================================================"

NEW_MASTER_IP="172.25.0.6"  # IP của postgres-replica1 (new master)
NEW_MASTER_CONTAINER="postgres-replica1"

echo "📊 Current Status:"
./check-cluster-status.sh

echo ""
echo "🔄 Reconfiguring REPLICA2 to follow new master..."

# Stop replica2
docker exec postgres-replica2 psql -U postgres -c "SELECT pg_promote();" 2>/dev/null
sleep 2

# Reset to replica mode and point to new master
docker exec postgres-replica2 bash -c "
# Stop PostgreSQL temporarily
pg_ctl stop -D /var/lib/postgresql/data -m fast

# Remove old recovery config
rm -f /var/lib/postgresql/data/standby.signal
rm -f /var/lib/postgresql/data/recovery.conf

# Create new standby.signal for new master
touch /var/lib/postgresql/data/standby.signal

# Configure primary_conninfo to point to new master
echo \"primary_conninfo = 'host=$NEW_MASTER_IP port=5432 user=postgres'\" >> /var/lib/postgresql/data/postgresql.conf

# Start PostgreSQL in recovery mode
pg_ctl start -D /var/lib/postgresql/data
"

echo ""
echo "🔄 Reconfiguring REPLICA3 to follow new master..."

# Similar for replica3
docker exec postgres-replica3 bash -c "
# Stop PostgreSQL temporarily
pg_ctl stop -D /var/lib/postgresql/data -m fast

# Remove old recovery config
rm -f /var/lib/postgresql/data/standby.signal
rm -f /var/lib/postgresql/data/recovery.conf

# Create new standby.signal for new master
touch /var/lib/postgresql/data/standby.signal

# Configure primary_conninfo to point to new master
echo \"primary_conninfo = 'host=$NEW_MASTER_IP port=5432 user=postgres'\" >> /var/lib/postgresql/data/postgresql.conf

# Start PostgreSQL in recovery mode
pg_ctl start -D /var/lib/postgresql/data
"

echo ""
echo "⏳ Waiting 10 seconds for replication to stabilize..."
sleep 10

echo ""
echo "📊 Final Status After Reconfiguration:"
./check-cluster-status.sh

echo ""
echo "🧪 Testing write to new master..."
docker exec $NEW_MASTER_CONTAINER psql -U postgres -d pos_db -c "
INSERT INTO pos_product (name, description, price, category_id, sku, is_available) 
VALUES ('POST-FAILOVER-TEST', 'Written to new master after failover', 777.77, 1, 'FAILOVER-777', true);
"

echo ""
echo "⏳ Waiting 5 seconds for replication..."
sleep 5

echo ""
echo "✅ Checking if replication works..."
echo "🔥 NEW MASTER (REPLICA1) - Product count:"
docker exec postgres-replica1 psql -U postgres -d pos_db -t -c "SELECT COUNT(*) FROM pos_product;" | xargs

echo "📘 REPLICA2 - Product count:"
docker exec postgres-replica2 psql -U postgres -d pos_db -t -c "SELECT COUNT(*) FROM pos_product;" | xargs

echo "📙 REPLICA3 - Product count:"
docker exec postgres-replica3 psql -U postgres -d pos_db -t -c "SELECT COUNT(*) FROM pos_product;" | xargs 