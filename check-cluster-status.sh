#!/bin/bash

echo "🔍 KIỂM TRA CLUSTER STATUS THỰC TẾ"
echo "================================================"

check_node_status() {
    local node_name=$1
    local container_name=$2
    
    echo "📊 $node_name:"
    
    # Check if container is running
    if ! docker exec $container_name echo "Container running" >/dev/null 2>&1; then
        echo "   ❌ Container STOPPED"
        return
    fi
    
    # Check PostgreSQL status
    pg_status=$(docker exec $container_name pg_isready -U postgres 2>/dev/null)
    if [[ $? -ne 0 ]]; then
        echo "   ❌ PostgreSQL NOT READY"
        return
    fi
    
    # Check if in recovery mode (replica)
    in_recovery=$(docker exec $container_name psql -U postgres -d pos_db -t -c "SELECT pg_is_in_recovery();" 2>/dev/null | xargs)
    
    if [[ "$in_recovery" == "t" ]]; then
        echo "   📘 REPLICA (Read-Only)"
        
        # Check replication status
        lag=$(docker exec $container_name psql -U postgres -d pos_db -t -c "
        SELECT CASE 
            WHEN pg_last_wal_receive_lsn() IS NULL THEN 'DISCONNECTED'
            ELSE EXTRACT(EPOCH FROM (now() - pg_last_xact_replay_timestamp()))::text || ' seconds'
        END;" 2>/dev/null | xargs)
        echo "   ⏱️  Replication lag: $lag"
        
    elif [[ "$in_recovery" == "f" ]]; then
        echo "   🔥 MASTER (Read-Write)"
        
        # Check connected replicas
        replicas=$(docker exec $container_name psql -U postgres -d pos_db -t -c "
        SELECT count(*) FROM pg_stat_replication;" 2>/dev/null | xargs)
        echo "   🔗 Connected replicas: $replicas"
        
        # Show replica details
        docker exec $container_name psql -U postgres -d pos_db -c "
        SELECT client_addr, application_name, state, sync_state 
        FROM pg_stat_replication;" 2>/dev/null
    else
        echo "   ❓ UNKNOWN STATUS"
    fi
    
    # Check data count
    count=$(docker exec $container_name psql -U postgres -d pos_db -t -c "SELECT COUNT(*) FROM pos_product;" 2>/dev/null | xargs)
    echo "   📦 Products count: $count"
    echo ""
}

echo "⏰ $(date)"
echo ""

# Check all nodes
check_node_status "MASTER" "postgres-master"
check_node_status "REPLICA1" "postgres-replica1" 
check_node_status "REPLICA2" "postgres-replica2"
check_node_status "REPLICA3" "postgres-replica3"

echo "🎯 HAProxy Backend Status:"
echo "================================================"
curl -s "http://localhost:8080/stats" | grep -E "(postgres-master|postgres-replica)" | awk -F',' '{print $2 " - " $18}' || echo "❌ HAProxy not accessible"

echo ""
echo "🔗 Prometheus Metrics:"
echo "================================================"
curl -s "http://localhost:9090/api/v1/query?query=pg_up" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for result in data['data']['result']:
        instance = result['metric']['instance']
        value = result['value'][1]
        role = result['metric'].get('role', 'unknown')
        status = '🟢 UP' if value == '1' else '🔴 DOWN'
        print(f'{role.upper():8} {instance:20} {status}')
except:
    print('❌ Failed to get Prometheus metrics')
" 