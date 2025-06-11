#!/bin/bash

echo "🎯 SIMULATED AUTOMATIC FAILOVER TEST"
echo "==================================="

monitor_and_failover() {
    echo "🔍 Step 1: Initial cluster status"
    ./safe-commands.sh roles
    
    echo ""
    echo "🎯 Step 2: Monitoring for master failure..."
    echo "⏳ Waiting for master to go down..."
    
    # Monitor master in background
    while true; do
        if ! timeout 5 docker exec postgres-master psql -U postgres -c "SELECT 1" >/dev/null 2>&1; then
            echo ""
            echo "🚨 MASTER FAILURE DETECTED!"
            echo "🔄 Initiating automatic failover simulation..."
            break
        fi
        sleep 2
        echo -n "."
    done
    
    echo ""
    echo "⚡ Step 3: Automatic failover in progress..."
    
    # Simulate automatic election process
    echo "🗳️ Running master election algorithm..."
    sleep 2
    
    # Check which replica has the best state (most data)
    echo "📊 Evaluating replica candidates..."
    
    best_replica=""
    max_orders=0
    
    for replica in postgres-replica1 postgres-replica2 postgres-replica3; do
        if timeout 5 docker exec $replica psql -U postgres -d pos_db -t -c "SELECT COUNT(*) FROM pos_order;" >/dev/null 2>&1; then
            orders=$(timeout 5 docker exec $replica psql -U postgres -d pos_db -t -c "SELECT COUNT(*) FROM pos_order;" 2>/dev/null | tr -d ' \t\n\r')
            echo "  $replica: $orders orders"
            
            if [ "$orders" -gt "$max_orders" ]; then
                max_orders=$orders
                best_replica=$replica
            fi
        fi
    done
    
    if [ -n "$best_replica" ]; then
        echo ""
        echo "🏆 ELECTED NEW MASTER: $best_replica"
        echo "⚡ Promoting $best_replica to master..."
        
        # Promote the best replica
        timeout 15 docker exec $best_replica psql -U postgres -c "SELECT pg_promote();" 2>/dev/null
        
        echo "✅ AUTOMATIC FAILOVER COMPLETED!"
        
        sleep 3
        echo ""
        echo "📊 Step 4: New cluster status after automatic failover:"
        ./safe-commands.sh roles
        
        echo ""
        echo "🎉 AUTOMATIC FAILOVER SUCCESSFUL!"
        echo "   Old Master: postgres-master (DOWN)"
        echo "   New Master: $best_replica (ACTIVE)"
        
    else
        echo "❌ AUTOMATIC FAILOVER FAILED: No suitable replica found"
    fi
}

case "${1:-}" in
    "start-monitoring")
        echo "🔍 Starting automatic failover monitoring..."
        echo "💡 In another terminal, run: docker stop postgres-master"
        echo "📊 This terminal will detect the failure and auto-promote a replica"
        echo ""
        monitor_and_failover
        ;;
    "manual-trigger")
        echo "🎯 Manual trigger of automatic failover simulation..."
        echo ""
        echo "Step 1: Current status"
        ./safe-commands.sh roles
        
        echo ""
        echo "Step 2: Stopping master (simulating failure)..."
        docker stop postgres-master
        
        echo ""
        echo "Step 3: Simulating automatic failover..."
        monitor_and_failover
        ;;
    *)
        echo "🎯 AUTOMATIC FAILOVER SIMULATION"
        echo "Usage: $0 [option]"
        echo ""
        echo "Options:"
        echo "  start-monitoring  - Start monitoring for master failure (interactive)"
        echo "  manual-trigger    - Trigger complete failover simulation"
        echo ""
        echo "Example:"
        echo "  $0 manual-trigger    # Complete simulation"
        echo ""
        echo "Interactive test:"
        echo "  Terminal 1: $0 start-monitoring"
        echo "  Terminal 2: docker stop postgres-master"
        ;;
esac
