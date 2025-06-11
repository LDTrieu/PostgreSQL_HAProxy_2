#!/bin/bash

echo "🔄 RESET & RECREATE PROPER HA CLUSTER"
echo "================================================"

echo "🛑 Stopping all PostgreSQL containers..."
docker stop postgres-master postgres-replica1 postgres-replica2 postgres-replica3

echo ""
echo "🗑️ Cleaning up data volumes..."
docker volume rm postgresql_haproxy_2_postgres-master-data postgresql_haproxy_2_postgres-replica1-data postgresql_haproxy_2_postgres-replica2-data postgresql_haproxy_2_postgres-replica3-data 2>/dev/null || true

echo ""
echo "🚀 Starting cluster with proper configuration..."
docker-compose -f docker-compose-simple-ha.yml up -d postgres-master

echo "⏳ Waiting for master to be ready..."
sleep 15

# Wait for master to be ready
until docker exec postgres-master pg_isready -U postgres; do
  echo "⏳ Waiting for master..."
  sleep 2
done

echo ""
echo "📊 Master is ready! Starting replicas..."
docker-compose -f docker-compose-simple-ha.yml up -d postgres-replica1 postgres-replica2 postgres-replica3

echo ""
echo "⏳ Waiting 30 seconds for replicas to sync..."
sleep 30

echo ""
echo "📊 Final Cluster Status:"
./check-cluster-status.sh

echo ""
echo "🧪 Testing write to master..."
docker exec postgres-master psql -U postgres -d pos_db -c "
INSERT INTO pos_product (name, description, price, category_id, sku, is_available) 
VALUES ('CLUSTER-RESET-TEST', 'Written after cluster reset', 999.99, 1, 'RESET-999', true);
"

echo ""
echo "⏳ Waiting for replication..."
sleep 10

echo ""
echo "✅ VERIFICATION - All should have same count:"
echo "🔥 MASTER:"
docker exec postgres-master psql -U postgres -d pos_db -t -c "SELECT COUNT(*) FROM pos_product;" | xargs

echo "📘 REPLICA1:"
docker exec postgres-replica1 psql -U postgres -d pos_db -t -c "SELECT COUNT(*) FROM pos_product;" | xargs

echo "📗 REPLICA2:"
docker exec postgres-replica2 psql -U postgres -d pos_db -t -c "SELECT COUNT(*) FROM pos_product;" | xargs

echo "📙 REPLICA3:"
docker exec postgres-replica3 psql -U postgres -d pos_db -t -c "SELECT COUNT(*) FROM pos_product;" | xargs

echo ""
echo "🎉 CLUSTER RECREATED SUCCESSFULLY!"
echo "📱 Now go to dashboard and see proper monitoring:"
echo "   http://localhost:3000/d/b0641cc1-36bd-4514-b9ad-d962b3b63879/postgresql-ha-cluster-robust-monitoring"

echo ""
echo "🧪 Want to test failover again? Run:"
echo "   ./manual-failover.sh test-failover" 