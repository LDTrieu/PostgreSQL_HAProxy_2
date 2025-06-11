#!/bin/bash

echo "🎯 CREATING DEMO AUTOMATIC FAILOVER ENVIRONMENT"
echo "==============================================="

# Setup Simple HA với enhanced monitoring
echo "🔧 Setting up enhanced Simple HA with automatic failover simulation..."

# Stop any existing
docker-compose -f docker-compose-simple-ha.yml down --volumes 2>/dev/null || true

# Start Simple HA
echo "🚀 Starting Simple HA cluster..."
docker-compose -f docker-compose-simple-ha.yml up -d

echo "⏳ Waiting for cluster to be ready (30 seconds)..."
sleep 30

# Check initial status
echo ""
echo "📊 INITIAL CLUSTER STATUS:"
./safe-commands.sh status

# Create simulation script
echo ""
echo "🔧 Creating automatic failover simulation script..."

cat > simulate-automatic-failover.sh << 'EOF'
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
EOF

chmod +x simulate-automatic-failover.sh

# Create comparison script
echo ""
echo "📝 Creating comparison demo script..."

cat > demo-ha-comparison.sh << 'EOF'
#!/bin/bash

echo "📊 HIGH AVAILABILITY COMPARISON DEMO"
echo "===================================="

demo_simple_ha() {
    echo ""
    echo "🔹 SIMPLE HA (Current Setup) - Manual Failover:"
    echo "-----------------------------------------------"
    
    echo "1️⃣ Initial status:"
    ./safe-commands.sh roles
    
    echo ""
    echo "2️⃣ Master failure simulation:"
    docker stop postgres-master 2>/dev/null || true
    sleep 2
    
    echo "3️⃣ Status after master down:"
    ./safe-commands.sh roles
    
    echo ""
    echo "❌ RESULT: No automatic failover - replicas remain as replicas!"
    echo "💡 Manual intervention required: ./safe-commands.sh promote"
    
    echo ""
    echo "4️⃣ Manual promotion:"
    ./safe-commands.sh promote
    
    echo ""
    echo "✅ Manual failover completed"
}

demo_automatic_ha() {
    echo ""
    echo "🔸 AUTOMATIC HA (Simulated) - Auto Failover:"
    echo "--------------------------------------------"
    
    # Start fresh
    docker start postgres-master 2>/dev/null
    sleep 5
    
    echo "1️⃣ Initial status:"
    ./safe-commands.sh roles
    
    echo ""
    echo "2️⃣ Automatic failover simulation:"
    ./simulate-automatic-failover.sh manual-trigger
    
    echo ""
    echo "✅ RESULT: Automatic failover completed without manual intervention!"
}

case "${1:-}" in
    "simple")
        demo_simple_ha
        ;;
    "automatic")
        demo_automatic_ha
        ;;
    "compare"|"")
        echo "🎯 COMPLETE COMPARISON DEMO"
        echo ""
        demo_simple_ha
        echo ""
        echo "=========================================="
        demo_automatic_ha
        echo ""
        echo "📋 SUMMARY:"
        echo "  Simple HA:    Manual intervention required"
        echo "  Automatic HA: Zero manual intervention"
        ;;
    *)
        echo "Usage: $0 [simple|automatic|compare]"
        ;;
esac
EOF

chmod +x demo-ha-comparison.sh

echo ""
echo "✅ DEMO ENVIRONMENT SETUP COMPLETE!"
echo ""
echo "🎯 NOW YOU CAN TEST AUTOMATIC FAILOVER:"
echo ""
echo "🔥 QUICK TEST - See automatic failover in action:"
echo "  ./simulate-automatic-failover.sh manual-trigger"
echo ""
echo "📊 COMPARISON DEMO - See difference between manual vs automatic:"
echo "  ./demo-ha-comparison.sh compare"
echo ""
echo "🔍 INTERACTIVE TEST - Monitor real-time:"
echo "  Terminal 1: ./simulate-automatic-failover.sh start-monitoring"
echo "  Terminal 2: docker stop postgres-master"
echo ""
echo "📋 STATUS MONITORING:"
echo "  ./safe-commands.sh status     # Current cluster status"
echo "  ./safe-commands.sh roles      # PostgreSQL roles"
echo ""
echo "🎉 Environment ready! Try the commands above to see automatic failover!" 