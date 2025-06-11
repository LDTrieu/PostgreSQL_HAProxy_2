#!/bin/bash

# Automatic Failover Daemon cho PostgreSQL HA
# Tự động promote replica khi detect master failure

DAEMON_NAME="PostgreSQL Auto-Failover Daemon"
CHECK_INTERVAL=5  # Check every 5 seconds
LOG_FILE="failover-daemon.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

check_master_status() {
    # Check postgres-master container and connection
    if timeout 3 docker ps --format "table {{.Names}}" | grep -q "^postgres-master$" 2>/dev/null; then
        if timeout 5 docker exec postgres-master psql -U postgres -t -c "SELECT 1" >/dev/null 2>&1; then
            local role=$(timeout 5 docker exec postgres-master psql -U postgres -t -c "SELECT CASE WHEN pg_is_in_recovery() THEN 'REPLICA' ELSE 'MASTER' END;" 2>/dev/null | tr -d ' \t\n\r')
            if [ "$role" = "MASTER" ]; then
                return 0  # Master is healthy
            fi
        fi
    fi
    return 1  # Master is down/failed
}

find_best_replica() {
    local best_replica=""
    local max_orders=0
    local best_lag=999999
    
    for replica in postgres-replica1 postgres-replica2 postgres-replica3; do
        # Check if replica is running and connected
        if timeout 3 docker ps --format "table {{.Names}}" | grep -q "^${replica}$" 2>/dev/null; then
            if timeout 5 docker exec ${replica} psql -U postgres -t -c "SELECT 1" >/dev/null 2>&1; then
                # Check if it's still a replica (not already promoted)
                local role=$(timeout 5 docker exec ${replica} psql -U postgres -t -c "SELECT CASE WHEN pg_is_in_recovery() THEN 'REPLICA' ELSE 'MASTER' END;" 2>/dev/null | tr -d ' \t\n\r')
                
                if [ "$role" = "REPLICA" ]; then
                    # Check data count (orders)
                    local orders=$(timeout 5 docker exec ${replica} psql -U postgres -d pos_db -t -c "SELECT COUNT(*) FROM pos_order;" 2>/dev/null | tr -d ' \t\n\r')
                    
                    if [ -n "$orders" ] && [ "$orders" -ge "$max_orders" ]; then
                        max_orders=$orders
                        best_replica=$replica
                    fi
                fi
            fi
        fi
    done
    
    echo $best_replica
}

perform_automatic_failover() {
    log "🚨 MASTER FAILURE DETECTED - Initiating automatic failover..."
    
    # Find best replica candidate
    local best_replica=$(find_best_replica)
    
    if [ -n "$best_replica" ]; then
        log "🗳️ ELECTION RESULT: $best_replica selected as new master"
        log "⚡ Promoting $best_replica to master..."
        
        # Promote the selected replica
        if timeout 15 docker exec $best_replica psql -U postgres -c "SELECT pg_promote();" >/dev/null 2>&1; then
            log "✅ AUTOMATIC FAILOVER SUCCESSFUL: $best_replica is now MASTER"
            
            # Wait a bit for promotion to complete
            sleep 5
            
            # Verify promotion
            local new_role=$(timeout 5 docker exec $best_replica psql -U postgres -t -c "SELECT CASE WHEN pg_is_in_recovery() THEN 'REPLICA' ELSE 'MASTER' END;" 2>/dev/null | tr -d ' \t\n\r')
            if [ "$new_role" = "MASTER" ]; then
                log "🎉 VERIFICATION: $best_replica confirmed as new MASTER"
                return 0
            else
                log "❌ VERIFICATION FAILED: $best_replica promotion unsuccessful"
                return 1
            fi
        else
            log "❌ PROMOTION FAILED: Could not promote $best_replica"
            return 1
        fi
    else
        log "❌ NO SUITABLE REPLICA FOUND for promotion"
        return 1
    fi
}

start_daemon() {
    log "🚀 Starting $DAEMON_NAME..."
    log "📊 Check interval: ${CHECK_INTERVAL}s"
    log "📋 Monitoring: postgres-master"
    log "🎯 Candidates: postgres-replica1, postgres-replica2, postgres-replica3"
    
    local consecutive_failures=0
    local max_failures=3  # Require 3 consecutive failures before failover
    
    while true; do
        if check_master_status; then
            # Master is healthy
            consecutive_failures=0
            echo -n "."  # Show activity
        else
            # Master failed
            ((consecutive_failures++))
            log "⚠️ Master check failed ($consecutive_failures/$max_failures)"
            
            if [ $consecutive_failures -ge $max_failures ]; then
                # Perform automatic failover
                if perform_automatic_failover; then
                    consecutive_failures=0
                    log "🔄 Resuming monitoring with new master..."
                else
                    log "💀 Failover failed - continuing monitoring..."
                    consecutive_failures=0
                fi
            fi
        fi
        
        sleep $CHECK_INTERVAL
    done
}

stop_daemon() {
    log "🛑 Stopping $DAEMON_NAME..."
    exit 0
}

status_check() {
    echo "🔍 $DAEMON_NAME Status Check"
    echo "================================"
    
    echo "📊 Current cluster status:"
    if check_master_status; then
        echo "  🔥 Master: HEALTHY"
    else
        echo "  ❌ Master: FAILED/DOWN"
        
        local best_replica=$(find_best_replica)
        if [ -n "$best_replica" ]; then
            echo "  🏆 Best replica candidate: $best_replica"
        else
            echo "  ⚠️ No suitable replica found"
        fi
    fi
    
    echo ""
    echo "📋 Available replicas:"
    for replica in postgres-replica1 postgres-replica2 postgres-replica3; do
        echo -n "  $replica: "
        if timeout 3 docker ps --format "table {{.Names}}" | grep -q "^${replica}$" 2>/dev/null; then
            if timeout 5 docker exec ${replica} psql -U postgres -t -c "SELECT 1" >/dev/null 2>&1; then
                local role=$(timeout 5 docker exec ${replica} psql -U postgres -t -c "SELECT CASE WHEN pg_is_in_recovery() THEN 'REPLICA' ELSE 'MASTER' END;" 2>/dev/null | tr -d ' \t\n\r')
                local orders=$(timeout 5 docker exec ${replica} psql -U postgres -d pos_db -t -c "SELECT COUNT(*) FROM pos_order;" 2>/dev/null | tr -d ' \t\n\r')
                echo "$role ($orders orders)"
            else
                echo "CONNECTION FAILED"
            fi
        else
            echo "CONTAINER DOWN"
        fi
    done
}

# Handle signals
trap stop_daemon SIGINT SIGTERM

case "${1:-}" in
    "start"|"")
        start_daemon
        ;;
    "status"|"s")
        status_check
        ;;
    "test"|"t")
        log "🧪 Testing failover mechanism..."
        perform_automatic_failover
        ;;
    "stop")
        echo "Use Ctrl+C to stop the daemon"
        ;;
    "help"|"h")
        echo "$DAEMON_NAME"
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  start         - Start automatic failover daemon (default)"
        echo "  status, s     - Check current cluster status"
        echo "  test, t       - Test failover mechanism once"
        echo "  help, h       - Show this help"
        echo ""
        echo "Features:"
        echo "  ✅ Automatic master failure detection"
        echo "  ✅ Smart replica selection (by data count)"
        echo "  ✅ Automatic promotion to master"
        echo "  ✅ Verification after promotion"
        echo "  ✅ Continuous monitoring"
        echo ""
        echo "Example:"
        echo "  $0 start      # Start daemon in foreground"
        echo "  $0 status     # Check cluster status"
        ;;
    *)
        echo "Unknown command: $1"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac 