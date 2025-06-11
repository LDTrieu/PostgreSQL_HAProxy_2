#!/bin/bash

# Safe Quick Commands - Tránh hanging commands

ACTION="$1"

case "$ACTION" in
    "status"|"s")
        echo "=== QUICK STATUS CHECK ==="
        ./safe-monitor.sh
        ;;
        
    "roles"|"r")
        echo "=== ROLES CHECK ==="
        echo "Master:"
        timeout 10 docker exec postgres-master psql -U postgres -t -c "SELECT CASE WHEN pg_is_in_recovery() THEN 'REPLICA' ELSE 'MASTER' END;" 2>/dev/null || echo "FAILED"
        
        echo "Replicas:"
        for r in postgres-replica1 postgres-replica2 postgres-replica3; do
            echo -n "$r: "
            timeout 10 docker exec $r psql -U postgres -t -c "SELECT CASE WHEN pg_is_in_recovery() THEN 'REPLICA' ELSE 'NEW-MASTER' END;" 2>/dev/null | tr -d ' \t\n\r' || echo "FAILED"
        done
        ;;
        
    "kill-master"|"km")
        echo "=== STOPPING MASTER ==="
        timeout 10 docker stop postgres-master
        echo "Master stopped. Check status:"
        sleep 2
        ./safe-commands.sh roles
        ;;
        
    "start-master"|"sm")
        echo "=== STARTING MASTER ==="
        timeout 10 docker start postgres-master
        echo "Master started. Check status:"
        sleep 3
        ./safe-commands.sh roles
        ;;
        
    "promote"|"p")
        echo "=== PROMOTING REPLICA1 ==="
        timeout 15 docker exec postgres-replica1 psql -U postgres -c "SELECT pg_promote();" 2>/dev/null || echo "Promotion failed"
        echo "Promotion completed. Check status:"
        sleep 3
        ./safe-commands.sh roles
        ;;
        
    "containers"|"c")
        echo "=== CONTAINER STATUS ==="
        timeout 10 docker ps --filter "name=postgres" --format "table {{.Names}}\t{{.Status}}"
        ;;
        
    "orders"|"o")
        echo "=== ORDERS COUNT ==="
        for node in postgres-master postgres-replica1 postgres-replica2 postgres-replica3; do
            echo -n "$node: "
            timeout 10 docker exec $node psql -U postgres -d pos_db -t -c "SELECT COUNT(*) FROM pos_order;" 2>/dev/null | tr -d ' \t\n\r' || echo "FAILED"
        done
        ;;
        
    "test-failover"|"tf")
        echo "=== TESTING FAILOVER ==="
        echo "1. Initial status:"
        ./safe-commands.sh roles
        
        echo ""
        echo "2. Stopping master..."
        timeout 10 docker stop postgres-master
        
        echo ""
        echo "3. Status after master down:"
        ./safe-commands.sh roles
        
        echo ""
        echo "4. Promoting replica1..."
        timeout 15 docker exec postgres-replica1 psql -U postgres -c "SELECT pg_promote();" 2>/dev/null || echo "Promotion failed"
        sleep 3
        
        echo ""
        echo "5. Final status:"
        ./safe-commands.sh roles
        ;;
        
    "help"|"h"|"")
        echo "=== SAFE COMMANDS ==="
        echo "Usage: ./safe-commands.sh [command]"
        echo ""
        echo "Commands:"
        echo "  status, s         - Full status check"  
        echo "  roles, r          - Check PostgreSQL roles"
        echo "  containers, c     - Check container status"
        echo "  orders, o         - Check orders count"
        echo "  kill-master, km   - Stop master"
        echo "  start-master, sm  - Start master"
        echo "  promote, p        - Promote replica1"
        echo "  test-failover, tf - Test complete failover"
        echo "  help, h           - Show this help"
        echo ""
        echo "Features:"
        echo "  ✅ Timeout protection (no hanging)"
        echo "  ✅ Simple output (no color codes)"
        echo "  ✅ Error handling"
        ;;
        
    *)
        echo "Unknown command: $ACTION"
        echo "Use './safe-commands.sh help' for available commands"
        exit 1
        ;;
esac 