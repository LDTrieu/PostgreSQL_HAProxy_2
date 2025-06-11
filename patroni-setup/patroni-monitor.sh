#!/bin/bash

# Patroni HA Cluster Monitor - với Automatic Failover Testing

echo "🔍 PATRONI HA CLUSTER MONITOR"
echo "============================="
echo "Time: $(date)"
echo ""

check_patroni_status() {
    echo "🔥 PATRONI NODES STATUS:"
    echo "----------------------"
    
    for i in 1 2 3; do
        local port=$((8007 + i))
        local node="postgres-node$i"
        echo -n "$node: "
        
        # Check if master
        if timeout 5 curl -s "http://localhost:$port/master" > /dev/null 2>&1; then
            echo "🔥 MASTER"
        # Check if replica
        elif timeout 5 curl -s "http://localhost:$port/replica" > /dev/null 2>&1; then
            echo "📘 REPLICA"
        # Check if running but not master/replica
        elif timeout 5 curl -s "http://localhost:$port/health" > /dev/null 2>&1; then
            echo "⚠️ UNHEALTHY"
        else
            echo "❌ DOWN/UNREACHABLE"
        fi
    done
}

check_containers() {
    echo ""
    echo "📦 CONTAINER STATUS:"
    echo "------------------"
    timeout 10 docker ps --filter "name=postgres-node\|etcd" --format "table {{.Names}}\t{{.Status}}" 2>/dev/null || echo "Failed to check containers"
}

check_etcd_cluster() {
    echo ""
    echo "🗂️ ETCD CLUSTER STATUS:"
    echo "---------------------"
    if timeout 10 docker exec etcd etcdctl --endpoints=http://localhost:2379 cluster-health 2>/dev/null; then
        echo "✅ ETCD healthy"
    else
        echo "❌ ETCD issues"
    fi
}

test_automatic_failover() {
    echo ""
    echo "🎯 TESTING AUTOMATIC FAILOVER"
    echo "=============================="
    
    # Step 1: Find current master
    echo "1️⃣ Finding current master..."
    local current_master=""
    for i in 1 2 3; do
        local port=$((8007 + i))
        if timeout 5 curl -s "http://localhost:$port/master" > /dev/null 2>&1; then
            current_master="postgres-node$i"
            break
        fi
    done
    
    if [ -z "$current_master" ]; then
        echo "❌ No master found! Cannot test failover."
        return 1
    fi
    
    echo "📍 Current master: $current_master"
    
    # Step 2: Show initial status
    echo ""
    echo "2️⃣ Initial cluster status:"
    check_patroni_status
    
    # Step 3: Stop current master
    echo ""
    echo "3️⃣ Stopping current master ($current_master)..."
    timeout 10 docker stop $current_master
    
    # Step 4: Wait for failover
    echo ""
    echo "4️⃣ Waiting for automatic failover..."
    echo "⏳ Patroni should detect master failure and elect new master..."
    
    local failover_detected=false
    for attempt in {1..30}; do  # Wait up to 30 seconds
        sleep 1
        echo -n "."
        
        # Check if any other node became master
        for i in 1 2 3; do
            local port=$((8007 + i))
            local node="postgres-node$i"
            
            if [ "$node" != "$current_master" ]; then
                if timeout 3 curl -s "http://localhost:$port/master" > /dev/null 2>&1; then
                    echo ""
                    echo "🎉 AUTOMATIC FAILOVER DETECTED!"
                    echo "🔥 New master: $node"
                    failover_detected=true
                    break 2
                fi
            fi
        done
    done
    
    echo ""
    
    if [ "$failover_detected" = true ]; then
        echo "✅ AUTOMATIC FAILOVER SUCCESSFUL!"
    else
        echo "❌ AUTOMATIC FAILOVER FAILED OR TIMEOUT!"
    fi
    
    # Step 5: Show final status
    echo ""
    echo "5️⃣ Final cluster status after failover:"
    check_patroni_status
    
    # Step 6: Restart old master
    echo ""
    echo "6️⃣ Restarting old master as replica..."
    timeout 10 docker start $current_master
    sleep 5
    
    echo ""
    echo "7️⃣ Final status after restart:"
    check_patroni_status
}

insert_test_data() {
    echo ""
    echo "💾 TESTING DATA INSERT TO CURRENT MASTER"
    echo "========================================"
    
    # Find current master
    local master_port=""
    for i in 1 2 3; do
        local api_port=$((8007 + i))
        local db_port=$((5431 + i))
        if timeout 5 curl -s "http://localhost:$api_port/master" > /dev/null 2>&1; then
            master_port=$db_port
            echo "📍 Found master on port $master_port"
            break
        fi
    done
    
    if [ -z "$master_port" ]; then
        echo "❌ No master found for data insert"
        return 1
    fi
    
    # Try to insert data
    echo "💾 Inserting test data..."
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    
    if timeout 10 docker exec postgres-node1 psql -h localhost -p 5432 -U postgres -d postgres -c "
        CREATE TABLE IF NOT EXISTS failover_test (
            id SERIAL PRIMARY KEY,
            test_time TIMESTAMP,
            message TEXT
        );
        INSERT INTO failover_test (test_time, message) VALUES ('$timestamp', 'Patroni automatic failover test');
        SELECT COUNT(*) as total_records FROM failover_test;
    " 2>/dev/null; then
        echo "✅ Data insert successful"
    else
        echo "❌ Data insert failed"
    fi
}

# Main menu
case "${1:-}" in
    "status"|"s")
        check_patroni_status
        check_containers
        ;;
        
    "etcd"|"e")
        check_etcd_cluster
        ;;
        
    "failover"|"f")
        test_automatic_failover
        ;;
        
    "insert"|"i")
        insert_test_data
        ;;
        
    "full"|"")
        check_containers
        check_etcd_cluster
        check_patroni_status
        ;;
        
    "test"|"t")
        echo "🎯 COMPLETE PATRONI HA TEST"
        echo "==========================="
        check_containers
        check_etcd_cluster  
        check_patroni_status
        insert_test_data
        test_automatic_failover
        ;;
        
    "help"|"h")
        echo ""
        echo "🔍 PATRONI MONITOR COMMANDS:"
        echo "============================"
        echo ""
        echo "  status, s     - Check Patroni nodes status"
        echo "  etcd, e       - Check ETCD cluster health"
        echo "  failover, f   - Test automatic failover"
        echo "  insert, i     - Test data insert to master"
        echo "  full          - Full status check (default)"
        echo "  test, t       - Complete HA test scenario"
        echo "  help, h       - Show this help"
        echo ""
        echo "🎯 TESTING AUTOMATIC FAILOVER:"
        echo "  ./patroni-monitor.sh failover"
        echo ""
        echo "🔧 PATRONI REST API:"
        echo "  curl http://localhost:8008/master   # Node1 master check"
        echo "  curl http://localhost:8009/replica  # Node2 replica check"
        echo "  curl http://localhost:8010/health   # Node3 health check"
        ;;
        
    *)
        echo "❌ Unknown option: $1"
        echo "Use './patroni-monitor.sh help' for available commands"
        exit 1
        ;;
esac 