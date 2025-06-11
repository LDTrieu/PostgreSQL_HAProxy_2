#!/bin/bash

echo "🎯 Testing PostgreSQL HA Grafana Dashboard"
echo "==========================================="

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test Panel 1: Products Count Realtime Comparison
echo -e "\n${YELLOW}📊 Panel 1: Products Count Realtime Comparison${NC}"
echo "Getting product count from all nodes..."

MASTER_COUNT=$(docker exec postgres-master psql -U postgres -d pos_db -t -c "SELECT COUNT(*) FROM pos_product;" | tr -d ' ')
REPLICA1_COUNT=$(docker exec postgres-replica1 psql -U postgres -d pos_db -t -c "SELECT COUNT(*) FROM pos_product;" | tr -d ' ')
REPLICA2_COUNT=$(docker exec postgres-replica2 psql -U postgres -d pos_db -t -c "SELECT COUNT(*) FROM pos_product;" | tr -d ' ')
REPLICA3_COUNT=$(docker exec postgres-replica3 psql -U postgres -d pos_db -t -c "SELECT COUNT(*) FROM pos_product;" | tr -d ' ')

echo "MASTER: $MASTER_COUNT"
echo "REPLICA1: $REPLICA1_COUNT"
echo "REPLICA2: $REPLICA2_COUNT"
echo "REPLICA3: $REPLICA3_COUNT"

# Alert check
if [ "$MASTER_COUNT" = "$REPLICA1_COUNT" ] && [ "$MASTER_COUNT" = "$REPLICA2_COUNT" ] && [ "$MASTER_COUNT" = "$REPLICA3_COUNT" ]; then
    echo -e "${GREEN}✅ PASS: All nodes synchronized${NC}"
else
    echo -e "${RED}❌ ALERT: Replication lag detected!${NC}"
fi

# Test Panel 2: Cluster Status Overview
echo -e "\n${YELLOW}📊 Panel 2: Cluster Status Overview${NC}"
echo "Getting cluster status from master..."
docker exec postgres-master psql -U postgres -d pos_db -c "
SELECT 
  'pos_db' as database_name,
  'postgres-master' as pod_id,
  COUNT(*) as product_count,
  ARRAY_TO_STRING(ARRAY(SELECT product_id::text FROM pos_product ORDER BY created_at DESC LIMIT 3), ', ') as last_3_product_ids,
  ARRAY_TO_STRING(ARRAY(SELECT name FROM pos_product ORDER BY created_at DESC LIMIT 3), ', ') as last_3_product_names,
  'MASTER' as role
FROM pos_product;"

# Test Panel 3: Pod Start Time Monitoring
echo -e "\n${YELLOW}📊 Panel 3: Pod Start Time Monitoring${NC}"
echo "Getting uptime from Prometheus..."
UPTIME_DATA=$(curl -s "http://localhost:9090/api/v1/query?query=time()-process_start_time_seconds{job=~\"postgres.*\"}")
echo "$UPTIME_DATA" | jq -r '.data.result[] | "\(.metric.instance): \(.value[1] | tonumber | . / 3600 | floor)h \((.value[1] | tonumber % 3600) / 60 | floor)m uptime"'

# Check for recent restarts (< 5 minutes)
RECENT_RESTARTS=$(echo "$UPTIME_DATA" | jq '.data.result[] | select(.value[1] | tonumber < 300)')
if [ "$RECENT_RESTARTS" = "" ]; then
    echo -e "${GREEN}✅ PASS: No recent restarts detected${NC}"
else
    echo -e "${RED}❌ ALERT: Recent restarts detected!${NC}"
    echo "$RECENT_RESTARTS"
fi

# Test Panel 4: Master Election Tracking
echo -e "\n${YELLOW}📊 Panel 4: Master Election Tracking${NC}"
echo "Getting replication status..."
REPLICATION_DATA=$(curl -s "http://localhost:9090/api/v1/query?query=pg_replication_is_replica")
echo "$REPLICATION_DATA" | jq -r '.data.result[] | "\(.metric.instance): \(if .value[1] == "0" then "MASTER" else "REPLICA" end)"'

# Check master count
MASTER_COUNT=$(echo "$REPLICATION_DATA" | jq '[.data.result[] | select(.value[1] == "0")] | length')
REPLICA_COUNT=$(echo "$REPLICATION_DATA" | jq '[.data.result[] | select(.value[1] == "1")] | length')

echo "Masters: $MASTER_COUNT, Replicas: $REPLICA_COUNT"

if [ "$MASTER_COUNT" = "1" ]; then
    echo -e "${GREEN}✅ PASS: Exactly 1 master detected${NC}"
else
    echo -e "${RED}❌ ALERT: Invalid master count: $MASTER_COUNT${NC}"
fi

# Test real-time monitoring
echo -e "\n${YELLOW}🔄 Testing Real-time Monitoring${NC}"
echo "Inserting test product..."
psql -h localhost -p 5439 -U postgres -d pos_db -c "
INSERT INTO pos_product (name, description, price, category_id, sku, is_available) 
VALUES ('Test-$(date +%s)', 'Dashboard test product', 999.99, 1, 'TEST-$(date +%s)', true);"

echo "Waiting 2 seconds for replication..."
sleep 2

echo "Checking replication..."
NEW_MASTER_COUNT=$(docker exec postgres-master psql -U postgres -d pos_db -t -c "SELECT COUNT(*) FROM pos_product;" | tr -d ' ')
NEW_REPLICA_COUNT=$(docker exec postgres-replica1 psql -U postgres -d pos_db -t -c "SELECT COUNT(*) FROM pos_product;" | tr -d ' ')

echo "Master: $NEW_MASTER_COUNT, Replica1: $NEW_REPLICA_COUNT"

if [ "$NEW_MASTER_COUNT" = "$NEW_REPLICA_COUNT" ]; then
    echo -e "${GREEN}✅ PASS: Real-time replication working${NC}"
else
    echo -e "${RED}❌ ALERT: Real-time replication failed${NC}"
fi

# Dashboard access test
echo -e "\n${YELLOW}🎯 Testing Dashboard Access${NC}"
DASHBOARD_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -u admin:admin123 "http://localhost:3000/d/ff76b7f1-b33b-471c-805e-24ba5795a5bb/postgresql-ha-cluster-monitoring")

if [ "$DASHBOARD_STATUS" = "200" ]; then
    echo -e "${GREEN}✅ PASS: Dashboard accessible at http://localhost:3000/d/ff76b7f1-b33b-471c-805e-24ba5795a5bb/postgresql-ha-cluster-monitoring${NC}"
else
    echo -e "${RED}❌ FAIL: Dashboard not accessible (HTTP $DASHBOARD_STATUS)${NC}"
fi

echo -e "\n${GREEN}🎉 Dashboard Test Complete!${NC}"
echo "Access dashboard: http://localhost:3000/d/ff76b7f1-b33b-471c-805e-24ba5795a5bb/postgresql-ha-cluster-monitoring"
echo "Login: admin / admin123" 