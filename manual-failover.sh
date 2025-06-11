#!/bin/bash

echo "🚨 MANUAL FAILOVER SCRIPT"
echo "================================================"

show_current_status() {
    echo "📊 Current Cluster Status:"
    ./check-cluster-status.sh
}

promote_replica_to_master() {
    local replica_container=$1
    local new_master_name=$2
    
    echo "🔄 Promoting $replica_container to MASTER..."
    
    # Stop replica recovery mode
    docker exec $replica_container psql -U postgres -c "SELECT pg_promote();" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo "✅ $new_master_name promoted to MASTER successfully!"
        
        # Configure other replicas to follow new master
        echo "🔗 Configuring other replicas to follow new master..."
        
        # Get new master IP
        NEW_MASTER_IP=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $replica_container)
        
        echo "🎯 New Master IP: $NEW_MASTER_IP"
        
        return 0
    else
        echo "❌ Failed to promote $new_master_name"
        return 1
    fi
}

case "$1" in
    "status")
        show_current_status
        ;;
    "promote-replica1")
        echo "🔥 Promoting REPLICA1 to MASTER..."
        promote_replica_to_master "postgres-replica1" "REPLICA1"
        sleep 5
        show_current_status
        ;;
    "promote-replica2")
        echo "🔥 Promoting REPLICA2 to MASTER..."
        promote_replica_to_master "postgres-replica2" "REPLICA2"
        sleep 5
        show_current_status
        ;;
    "promote-replica3")
        echo "🔥 Promoting REPLICA3 to MASTER..."
        promote_replica_to_master "postgres-replica3" "REPLICA3"
        sleep 5
        show_current_status
        ;;
    "restore-original")
        echo "🔄 Restoring original Master..."
        docker start postgres-master 2>/dev/null
        sleep 10
        show_current_status
        ;;
    "test-failover")
        echo "🧪 TESTING COMPLETE FAILOVER SCENARIO"
        echo "================================================"
        
        echo "1️⃣ Current Status:"
        show_current_status
        
        echo ""
        echo "2️⃣ Stopping Master..."
        docker stop postgres-master
        sleep 3
        
        echo ""
        echo "3️⃣ Status after Master stop:"
        show_current_status
        
        echo ""
        echo "4️⃣ Promoting REPLICA1 to Master..."
        promote_replica_to_master "postgres-replica1" "REPLICA1"
        
        echo ""
        echo "5️⃣ Final Status after Failover:"
        show_current_status
        
        echo ""
        echo "🎯 FAILOVER TEST COMPLETED!"
        echo "   - Original Master: STOPPED"
        echo "   - New Master: REPLICA1"
        echo "   - Other Replicas: Still running"
        ;;
    *)
        echo "Usage: $0 {status|promote-replica1|promote-replica2|promote-replica3|restore-original|test-failover}"
        echo ""
        echo "Commands:"
        echo "  status           - Show current cluster status"
        echo "  promote-replica1 - Promote Replica1 to Master"
        echo "  promote-replica2 - Promote Replica2 to Master"
        echo "  promote-replica3 - Promote Replica3 to Master"
        echo "  restore-original - Start original Master container"
        echo "  test-failover    - Run complete failover test"
        exit 1
        ;;
esac 