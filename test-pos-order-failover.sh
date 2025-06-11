#!/bin/bash

echo "🧪 TESTING POS ORDER FAILOVER SCENARIO"
echo "======================================="

echo "📊 Initial cluster status:"
echo "🔥 MASTER: $(docker exec postgres-master psql -U postgres -d pos_db -t -c "SELECT COUNT(*) FROM pos_order;" | xargs) orders"
echo "📘 REPLICA1: $(docker exec postgres-replica1 psql -U postgres -d pos_db -t -c "SELECT COUNT(*) FROM pos_order;" | xargs) orders"
echo "📗 REPLICA2: $(docker exec postgres-replica2 psql -U postgres -d pos_db -t -c "SELECT COUNT(*) FROM pos_order;" | xargs) orders"
echo "📙 REPLICA3: $(docker exec postgres-replica3 psql -U postgres -d pos_db -t -c "SELECT COUNT(*) FROM pos_order;" | xargs) orders"

echo ""
echo "🎯 Open Dashboard: http://localhost:3000/d/5f302b38-1ddf-4d2e-9fcd-4b14728df229/postgresql-ha-cluster-pos-order-monitoring"
echo ""
echo "💡 Current scenario shows:"
echo "   - Panel 1: Orders Count - All nodes show 15 orders"
echo "   - Panel 2: Cluster Status - All nodes show REPLICA role"
echo "   - Panel 3: Pod Start Time - All containers uptime"
echo "   - Panel 4: Master Election - All nodes UP status"
echo ""

echo "🧪 Test 1: Add new order to MASTER"
echo "====================================="
docker exec postgres-master psql -U postgres -d pos_db -c "
INSERT INTO pos_order (order_number, order_type, status_id, pos_id, description, total_amount, created_by) 
VALUES ('ORD-FAILOVER-TEST-001', 'DINE_IN', 1, 1, 'Pre-failover test order', 199000.00, 1);
"

echo "⏳ Waiting for replication..."
sleep 5

echo "📊 After adding 1 order:"
echo "🔥 MASTER: $(docker exec postgres-master psql -U postgres -d pos_db -t -c "SELECT COUNT(*) FROM pos_order;" | xargs) orders"
echo "📘 REPLICA1: $(docker exec postgres-replica1 psql -U postgres -d pos_db -t -c "SELECT COUNT(*) FROM pos_order;" | xargs) orders"
echo "📗 REPLICA2: $(docker exec postgres-replica2 psql -U postgres -d pos_db -t -c "SELECT COUNT(*) FROM pos_order;" | xargs) orders"
echo "📙 REPLICA3: $(docker exec postgres-replica3 psql -U postgres -d pos_db -t -c "SELECT COUNT(*) FROM pos_order;" | xargs) orders"

echo ""
echo "🚨 Test 2: SIMULATE MASTER FAILURE"
echo "===================================="
echo "⚠️ Stopping postgres-master container..."
docker stop postgres-master

echo "⏳ Waiting 10 seconds for failure detection..."
sleep 10

echo "💡 Dashboard should now show:"
echo "   - Panel 1: Master connection failed, replicas still show data"
echo "   - Panel 2: Master row missing/failed, replicas still REPLICA role"
echo "   - Panel 4: Master shows DOWN, replicas still UP"
echo ""

echo "🔥 Test 3: MANUAL FAILOVER - PROMOTE REPLICA1"
echo "==============================================="
echo "🔄 Promoting REPLICA1 to MASTER..."
docker exec postgres-replica1 psql -U postgres -c "SELECT pg_promote();"

echo "⏳ Waiting for promotion..."
sleep 5

echo "📊 After promotion - Order counts:"
echo "❌ MASTER: STOPPED"
echo "🔥 REPLICA1 (NEW MASTER): $(docker exec postgres-replica1 psql -U postgres -d pos_db -t -c "SELECT COUNT(*) FROM pos_order;" | xargs) orders"
echo "📗 REPLICA2: $(docker exec postgres-replica2 psql -U postgres -d pos_db -t -c "SELECT COUNT(*) FROM pos_order;" | xargs) orders"  
echo "📙 REPLICA3: $(docker exec postgres-replica3 psql -U postgres -d pos_db -t -c "SELECT COUNT(*) FROM pos_order;" | xargs) orders"

echo ""
echo "🧪 Test 4: WRITE TO NEW MASTER"
echo "==============================="
echo "📝 Adding order to new master (REPLICA1)..."
docker exec postgres-replica1 psql -U postgres -d pos_db -c "
INSERT INTO pos_order (order_number, order_type, status_id, pos_id, description, total_amount, created_by) 
VALUES ('ORD-POST-FAILOVER-001', 'DELIVERY', 2, 3, 'Order after failover to replica1', 299000.00, 3);
"

echo "⏳ Waiting..."
sleep 3

echo "📊 Final order counts:"
echo "❌ MASTER: STOPPED"
echo "🔥 REPLICA1 (NEW MASTER): $(docker exec postgres-replica1 psql -U postgres -d pos_db -t -c "SELECT COUNT(*) FROM pos_order;" | xargs) orders"
echo "📗 REPLICA2: $(docker exec postgres-replica2 psql -U postgres -d pos_db -t -c "SELECT COUNT(*) FROM pos_order;" | xargs) orders"
echo "📙 REPLICA3: $(docker exec postgres-replica3 psql -U postgres -d pos_db -t -c "SELECT COUNT(*) FROM pos_order;" | xargs) orders"

echo ""
echo "🎯 EXPECTED DASHBOARD RESULTS:"
echo "==============================="
echo "✅ Panel 1 (Orders Count): REPLICA1=17, REPLICA2&3=16, Master=Failed"
echo "✅ Panel 2 (Cluster Status): REPLICA1 shows MASTER role, others REPLICA"  
echo "✅ Panel 3 (Pod Start Time): Shows restart times"
echo "✅ Panel 4 (Master Election): Master DOWN, replicas UP"
echo ""
echo "🎉 FAILOVER TEST COMPLETED!"
echo "Dashboard URL: http://localhost:3000/d/5f302b38-1ddf-4d2e-9fcd-4b14728df229/postgresql-ha-cluster-pos-order-monitoring"

echo ""
echo "🔄 To restore original master:"
echo "   docker start postgres-master"
echo "   ./manual-failover.sh status" 