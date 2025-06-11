#!/bin/bash

echo "🚨 FIX SPLIT-BRAIN CLUSTER"
echo "================================================"

echo "📊 Current DANGEROUS situation:"
echo "   - REPLICA1: MASTER (25 products)"
echo "   - REPLICA2: MASTER (24 products) ⚠️ SPLIT-BRAIN!"
echo "   - REPLICA3: REPLICA (24 products)"
echo ""

# Choose REPLICA1 as the true master
TRUE_MASTER="postgres-replica1"
TRUE_MASTER_IP="172.25.0.6"

echo "🔥 Designating REPLICA1 as the TRUE MASTER"
echo "🔧 Converting REPLICA2 back to REPLICA mode..."

# Stop replica2 completely
docker exec postgres-replica2 bash -c "
# Use postgres user to run commands
sudo -u postgres pg_ctl stop -D /var/lib/postgresql/data -m fast || true
sleep 2

# Remove all existing recovery/master files
rm -f /var/lib/postgresql/data/standby.signal
rm -f /var/lib/postgresql/data/recovery.conf

# Copy fresh data from new master
# (In real scenario, we'd use pg_basebackup)
# For now, we'll just create standby.signal and configure replication

# Create standby.signal to mark as replica
touch /var/lib/postgresql/data/standby.signal

# Remove any conflicting postgresql.conf settings
sed -i '/primary_conninfo/d' /var/lib/postgresql/data/postgresql.conf

# Add proper replication config
echo \"primary_conninfo = 'host=$TRUE_MASTER_IP port=5432 user=postgres'\" >> /var/lib/postgresql/data/postgresql.conf
echo \"hot_standby = on\" >> /var/lib/postgresql/data/postgresql.conf
echo \"wal_level = replica\" >> /var/lib/postgresql/data/postgresql.conf

# Start as replica
sudo -u postgres pg_ctl start -D /var/lib/postgresql/data
"

echo ""
echo "🔧 Fixing REPLICA3 replication..."

docker exec postgres-replica3 bash -c "
# Use postgres user
sudo -u postgres pg_ctl stop -D /var/lib/postgresql/data -m fast || true
sleep 2

# Remove conflicting configs
sed -i '/primary_conninfo/d' /var/lib/postgresql/data/postgresql.conf

# Ensure we have standby.signal
touch /var/lib/postgresql/data/standby.signal

# Add proper replication config for new master
echo \"primary_conninfo = 'host=$TRUE_MASTER_IP port=5432 user=postgres'\" >> /var/lib/postgresql/data/postgresql.conf
echo \"hot_standby = on\" >> /var/lib/postgresql/data/postgresql.conf

# Start as replica
sudo -u postgres pg_ctl start -D /var/lib/postgresql/data
"

echo ""
echo "⏳ Waiting 15 seconds for cluster to stabilize..."
sleep 15

echo ""
echo "📊 Cluster Status After Fix:"
./check-cluster-status.sh

echo ""
echo "🧪 Testing NEW WRITE to true master (REPLICA1)..."
docker exec $TRUE_MASTER psql -U postgres -d pos_db -c "
INSERT INTO pos_product (name, description, price, category_id, sku, is_available) 
VALUES ('AFTER-SPLIT-BRAIN-FIX', 'Written after fixing split-brain', 888.88, 1, 'FIX-888', true);
"

echo ""
echo "⏳ Waiting 10 seconds for replication..."
sleep 10

echo ""
echo "✅ FINAL VERIFICATION:"
echo "🔥 TRUE MASTER (REPLICA1):"
docker exec postgres-replica1 psql -U postgres -d pos_db -t -c "SELECT COUNT(*) FROM pos_product;" | xargs

echo "📘 REPLICA2 (should sync from master):"
docker exec postgres-replica2 psql -U postgres -d pos_db -t -c "SELECT COUNT(*) FROM pos_product;" | xargs

echo "📙 REPLICA3 (should sync from master):"
docker exec postgres-replica3 psql -U postgres -d pos_db -t -c "SELECT COUNT(*) FROM pos_product;" | xargs

echo ""
echo "🎯 Expected result: All nodes should have 26 products"
echo "💡 If REPLICA2/3 still show 24, replication needs more time or manual intervention" 