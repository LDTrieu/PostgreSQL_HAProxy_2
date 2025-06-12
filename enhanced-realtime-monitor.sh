#!/bin/bash

# Enhanced Real-Time Monitor với Automatic Failover
# Combination of monitoring và automatic promotion

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

AUTO_FAILOVER_ENABLED=false
LAST_MASTER=""
FAILOVER_LOG="enhanced-monitor.log"

log_event() {
    echo "[$(date '+%H:%M:%S')] $1" >> $FAILOVER_LOG
}

check_and_auto_promote() {
    # Check if we need automatic failover
    local current_masters=0
    local master_node=""
    
    # Count current masters
    for node in postgres-master postgres-replica1 postgres-replica2 postgres-replica3 postgres-replica4; do
        if timeout 5 docker ps --format "table {{.Names}}" | grep -q "^${node}$" 2>/dev/null; then
            # Try with longer timeout for more reliability
            if timeout 10 docker exec ${node} psql -U postgres -t -c "SELECT 1" >/dev/null 2>&1; then
                local role=$(timeout 10 docker exec ${node} psql -U postgres -t -c "SELECT CASE WHEN pg_is_in_recovery() THEN 'REPLICA' ELSE 'MASTER' END;" 2>/dev/null | tr -d ' \t\n\r')
                if [ "$role" = "MASTER" ]; then
                    ((current_masters++))
                    master_node=$node
                fi
            fi
        fi
    done
    
    # If no master and auto-failover enabled, promote best replica
    if [ $current_masters -eq 0 ] && [ "$AUTO_FAILOVER_ENABLED" = true ]; then
        log_event "🚨 NO MASTER DETECTED - AUTO-FAILOVER TRIGGERED"
        
        # Find best replica
        local best_replica=""
        local max_orders=0
        
        for replica in postgres-replica1 postgres-replica2 postgres-replica3 postgres-replica4; do
            if timeout 5 docker ps --format "table {{.Names}}" | grep -q "^${replica}$" 2>/dev/null; then
                # Use longer timeout for better reliability during startup
                if timeout 10 docker exec ${replica} psql -U postgres -t -c "SELECT 1" >/dev/null 2>&1; then
                    local role=$(timeout 10 docker exec ${replica} psql -U postgres -t -c "SELECT CASE WHEN pg_is_in_recovery() THEN 'REPLICA' ELSE 'MASTER' END;" 2>/dev/null | tr -d ' \t\n\r')
                    if [ "$role" = "REPLICA" ]; then
                        local orders=$(timeout 10 docker exec ${replica} psql -U postgres -d pos_db -t -c "SELECT COUNT(*) FROM pos_order;" 2>/dev/null | tr -d ' \t\n\r')
                        if [ -n "$orders" ] && [ "$orders" -ge "$max_orders" ]; then
                            max_orders=$orders
                            best_replica=$replica
                        fi
                    fi
                fi
            fi
        done
        
        if [ -n "$best_replica" ]; then
            log_event "🗳️ PROMOTING $best_replica"
            if timeout 15 docker exec $best_replica psql -U postgres -c "SELECT pg_promote();" >/dev/null 2>&1; then
                log_event "✅ AUTO-FAILOVER SUCCESS: $best_replica → MASTER"
                return 0
            else
                log_event "❌ AUTO-FAILOVER FAILED: $best_replica promotion error"
                return 1
            fi
        fi
    fi
    
    return 0
}

print_enhanced_header() {
    echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║              🔍 Enhanced PostgreSQL HA Monitor + Auto-Failover               ║${NC}"
    echo -e "${BOLD}${CYAN}║                         $(date '+%Y-%m-%d %H:%M:%S')                              ║${NC}"
    if [ "$AUTO_FAILOVER_ENABLED" = true ]; then
        echo -e "${BOLD}${CYAN}║                            ⚡ AUTO-FAILOVER: ON                              ║${NC}"
    else
        echo -e "${BOLD}${CYAN}║                            ⚠️  AUTO-FAILOVER: OFF                             ║${NC}"
    fi
    echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

check_node_status_enhanced() {
    local node=$1
    local label=$2
    local color=$3
    
    echo -n -e "${color}${BOLD}${label}:${NC} "
    
    # Check container first
    if ! timeout 5 docker ps --format "table {{.Names}}" | grep -q "^${node}$" 2>/dev/null; then
        echo -e "${RED}❌ CONTAINER DOWN${NC}"
        return 1
    fi
    
    # Check container health/status
    local container_status=$(docker ps --filter "name=^${node}$" --format "{{.Status}}" 2>/dev/null)
    if [[ $container_status == *"starting"* ]] || [[ $container_status == *"health: starting"* ]]; then
        echo -e "${YELLOW}⏳ STARTING...${NC}"
        return 1
    fi
    
    # Enhanced PostgreSQL connection check with retry
    local connected=false
    local role=""
    local orders=""
    
    # Try multiple times với increasing timeout
    for attempt in 1 2 3; do
        local timeout_duration=$((5 + attempt * 2))  # 7s, 9s, 11s
        
        if timeout $timeout_duration docker exec ${node} psql -U postgres -t -c "SELECT 'CONNECTED'" >/dev/null 2>&1; then
            # Get role
            role=$(timeout $timeout_duration docker exec ${node} psql -U postgres -t -c "SELECT CASE WHEN pg_is_in_recovery() THEN 'REPLICA' ELSE 'MASTER' END;" 2>/dev/null | tr -d ' \t\n\r')
            
            # Get orders count
            orders=$(timeout $timeout_duration docker exec ${node} psql -U postgres -d pos_db -t -c "SELECT COUNT(*) FROM pos_order;" 2>/dev/null | tr -d ' \t\n\r')
            
            if [ -n "$role" ]; then
                connected=true
                break
            fi
        fi
        
        # Brief pause between attempts
        [ $attempt -lt 3 ] && sleep 1
    done
    
    if [ "$connected" = true ]; then
        case $role in
            "MASTER")
                echo -e "${RED}🔥 MASTER${NC} ${GREEN}${NC}"
                if [ "$LAST_MASTER" != "$node" ]; then
                    log_event "👑 NEW MASTER DETECTED: $node"
                    LAST_MASTER=$node
                fi
                ;;
            "REPLICA")
                echo -e "${BLUE}📘 REPLICA${NC} ${GREEN}${NC}"
                ;;
            *)
                echo -e "${YELLOW}⚠️ UNKNOWN ROLE${NC}"
                ;;
        esac
    else
        # Check specific states
        local container_logs=$(timeout 3 docker logs ${node} --tail 3 2>/dev/null | tail -1)
        
        if [[ $container_logs == *"Waiting for master"* ]]; then
            echo -e "${YELLOW}⌛ WAITING FOR MASTER${NC}"
        elif [[ $container_logs == *"starting"* ]] || [[ $container_logs == *"PostgreSQL init"* ]]; then
            echo -e "${YELLOW}⏳ POSTGRES STARTING...${NC}"
        elif timeout 5 docker exec ${node} ps aux 2>/dev/null | grep -q postgres 2>/dev/null; then
            echo -e "${YELLOW}⏳ POSTGRES STARTING...${NC}"
        else
            echo -e "${RED}❌ CONNECTION FAILED${NC}"
        fi
        return 1
    fi
}

fix_split_brain() {
    log_event "🚨 SPLIT-BRAIN DETECTED - Attempting to fix..."
    
    # Strategy: Demote postgres-master (original) if postgres-replica2 is also master
    # This assumes replica2 is the legitimate new master from failover
    
    local masters=()
    local primary_master=""
    local secondary_master=""
    
    # Find all masters
    for node in postgres-master postgres-replica1 postgres-replica2 postgres-replica3 postgres-replica4; do
        if timeout 5 docker ps --format "table {{.Names}}" | grep -q "^${node}$" 2>/dev/null; then
            if timeout 10 docker exec ${node} psql -U postgres -t -c "SELECT 1" >/dev/null 2>&1; then
                local role=$(timeout 10 docker exec ${node} psql -U postgres -t -c "SELECT CASE WHEN pg_is_in_recovery() THEN 'REPLICA' ELSE 'MASTER' END;" 2>/dev/null | tr -d ' \t\n\r')
                if [ "$role" = "MASTER" ]; then
                    masters+=("$node")
                fi
            fi
        fi
    done
    
    if [ ${#masters[@]} -eq 2 ]; then
        # Prioritize replica nodes over original master
        if [[ " ${masters[@]} " =~ " postgres-master " ]] && [[ " ${masters[@]} " =~ " postgres-replica2 " ]]; then
            secondary_master="postgres-master"
            primary_master="postgres-replica2"
        else
            # Default: demote first one found
            primary_master="${masters[0]}"
            secondary_master="${masters[1]}"
        fi
        
        log_event "🔧 FIXING: Keeping $primary_master as MASTER, demoting $secondary_master"
        
        # Method 1: Try to force secondary into standby mode
        log_event "🔄 Attempting to demote $secondary_master to replica..."
        
        # Try to restart in replica mode first
        if docker restart "$secondary_master" >/dev/null 2>&1; then
            sleep 5  # Wait for PostgreSQL to start
            
            # Check if it's still master after restart
            local new_role=$(timeout 10 docker exec "$secondary_master" psql -U postgres -t -c "SELECT CASE WHEN pg_is_in_recovery() THEN 'REPLICA' ELSE 'MASTER' END;" 2>/dev/null | tr -d ' \t\n\r')
            
            if [ "$new_role" = "REPLICA" ]; then
                log_event "✅ SPLIT-BRAIN FIX: $secondary_master successfully demoted to REPLICA"
                return 0
            else
                log_event "⚠️ Restart failed to fix split-brain, trying stronger method..."
                
                # Method 2: Stop the problematic master completely
                log_event "🛑 STOPPING $secondary_master to resolve split-brain"
                
                if docker stop "$secondary_master" >/dev/null 2>&1; then
                    log_event "✅ SPLIT-BRAIN FIX: $secondary_master stopped, $primary_master is now sole MASTER"
                    log_event "💡 Manual restart of $secondary_master will make it a replica"
                    return 0
                else
                    log_event "❌ SPLIT-BRAIN FIX FAILED: Could not stop $secondary_master"
                    return 1
                fi
            fi
        else
            log_event "❌ SPLIT-BRAIN FIX FAILED: Could not restart $secondary_master"
            return 1
        fi
    fi
    
    return 1
}

show_enhanced_cluster_summary() {
    echo ""
    echo -e "${BOLD}${YELLOW}📊 CLUSTER SUMMARY:${NC}"
    echo -e "${YELLOW}═══════════════════${NC}"
    
    local master_count=0
    local replica_count=0
    local down_count=0
    local master_nodes=""
    
    for node in postgres-master postgres-replica1 postgres-replica2 postgres-replica3 postgres-replica4; do
        if timeout 3 docker ps --format "table {{.Names}}" | grep -q "^${node}$" 2>/dev/null; then
            if timeout 5 docker exec ${node} psql -U postgres -t -c "SELECT 'CONNECTED'" >/dev/null 2>&1; then
                local role=$(timeout 5 docker exec ${node} psql -U postgres -t -c "SELECT CASE WHEN pg_is_in_recovery() THEN 'REPLICA' ELSE 'MASTER' END;" 2>/dev/null | tr -d ' \t\n\r')
                case $role in
                    "MASTER") 
                        ((master_count++))
                        master_nodes="$master_nodes $node"
                        ;;
                    "REPLICA") ((replica_count++)) ;;
                esac
            else
                ((down_count++))
            fi
        else
            ((down_count++))
        fi
    done
    
    echo -e "  🔥 Masters: ${RED}${BOLD}${master_count}${NC}${master_nodes}"
    echo -e "  📘 Replicas: ${BLUE}${BOLD}${replica_count}${NC}"
    echo -e "  ❌ Down/Failed: ${RED}${BOLD}${down_count}${NC}"
    
    # Health status with auto-failover consideration  
    local total_nodes=5
    local active_nodes=$((master_count + replica_count))
    local quorum_threshold=3  # 3/5 majority
    
    if [ $master_count -eq 1 ] && [ $down_count -eq 0 ]; then
        echo -e "  🟢 Cluster Health: ${GREEN}${BOLD}HEALTHY${NC} (5/5 nodes, quorum: ${active_nodes}/${total_nodes})"
    elif [ $master_count -eq 1 ] && [ $down_count -gt 0 ]; then
        if [ $active_nodes -ge $quorum_threshold ]; then
            echo -e "  🟡 Cluster Health: ${YELLOW}${BOLD}DEGRADED${NC} (quorum: ${active_nodes}/${total_nodes} ✅)"
        else
            echo -e "  🔴 Cluster Health: ${RED}${BOLD}DEGRADED - NO QUORUM${NC} (${active_nodes}/${total_nodes} < ${quorum_threshold})"
        fi
    elif [ $master_count -eq 0 ]; then
        if [ "$AUTO_FAILOVER_ENABLED" = true ]; then
            echo -e "  🔄 Cluster Health: ${YELLOW}${BOLD}NO MASTER - AUTO-FAILOVER TRIGGERED${NC}"
        else
            echo -e "  🔴 Cluster Health: ${RED}${BOLD}NO MASTER${NC}"
        fi
    elif [ $master_count -gt 1 ]; then
        echo -e "  🟠 Cluster Health: ${RED}${BOLD}SPLIT-BRAIN${NC} (${master_count} masters detected)"
        # Auto-fix split-brain if auto-failover is enabled
        if [ "$AUTO_FAILOVER_ENABLED" = true ]; then
            echo -e "  🔧 ${YELLOW}Auto-fixing split-brain...${NC}"
            fix_split_brain
        fi
    fi
}

show_enhanced_instructions() {
    echo ""
    echo -e "${BOLD}${CYAN}🎯 ENHANCED TEST INSTRUCTIONS:${NC}"
    echo -e "${CYAN}══════════════════════════════${NC}"
    if [ "$AUTO_FAILOVER_ENABLED" = true ]; then
        echo -e "  ${GREEN}• Auto-failover: ${YELLOW}ENABLED${NC} - Replicas will auto-promote when master down"
        echo -e "  ${GREEN}• Test: ${YELLOW}docker stop postgres-master${NC}     ${CYAN}# Watch automatic promotion!${NC}"
        echo -e "  ${GREEN}• Test: ${YELLOW}docker stop <current-master>${NC}   ${CYAN}# Watch failover to new replica${NC}"
    else
        echo -e "  ${RED}• Auto-failover: ${YELLOW}DISABLED${NC} - Manual promotion required"
        echo -e "  ${GREEN}• Enable: ${YELLOW}Press 'A' during monitoring${NC}     ${CYAN}# Enable auto-failover${NC}"
        echo -e "  ${GREEN}• Test: ${YELLOW}docker stop postgres-master${NC}      ${CYAN}# Manual failover needed${NC}"
    fi
    echo -e "  ${GREEN}• Toggle: ${YELLOW}Press 'A'${NC}                       ${CYAN}# Toggle auto-failover on/off${NC}"
    echo -e "  ${GREEN}• Restart: ${YELLOW}docker start <container>${NC}       ${CYAN}# Restart any container${NC}"
    echo -e "  ${RED}• Fix Split-Brain: ${YELLOW}Auto-fixed when detected${NC}   ${CYAN}# Demotes old master${NC}"
    echo ""
    echo -e "  ${RED}• Press Ctrl+C to exit${NC}"
}

monitor_with_auto_failover() {
    local refresh_interval=${1:-2}
    
    # Clear log
    > $FAILOVER_LOG
    
    echo -e "${YELLOW}🔍 Starting Enhanced Real-Time Monitor...${NC}"
    echo -e "${CYAN}Press 'A' anytime to toggle auto-failover${NC}"
    sleep 2
    
    while true; do
        clear
        print_enhanced_header
        
        # Perform auto-failover check if enabled
        if [ "$AUTO_FAILOVER_ENABLED" = true ]; then
            check_and_auto_promote
        fi
        
        echo -e "${BOLD}${GREEN}📦 NODE STATUS:${NC}"
        echo -e "${GREEN}═══════════════${NC}"
        check_node_status_enhanced "postgres-master" "Master   " "${RED}"
        check_node_status_enhanced "postgres-replica1" "Replica-1" "${BLUE}"
        check_node_status_enhanced "postgres-replica2" "Replica-2" "${BLUE}"
        check_node_status_enhanced "postgres-replica3" "Replica-3" "${BLUE}"
        check_node_status_enhanced "postgres-replica4" "Replica-4" "${BLUE}"
        
        show_enhanced_cluster_summary
        show_enhanced_instructions
        
        # Show recent events
        if [ -f "$FAILOVER_LOG" ] && [ -s "$FAILOVER_LOG" ]; then
            echo -e "${BOLD}${PURPLE}📋 RECENT EVENTS:${NC}"
            echo -e "${PURPLE}═════════════════${NC}"
            tail -3 $FAILOVER_LOG | while read line; do
                echo -e "  ${CYAN}$line${NC}"
            done
        fi
        
        echo -e "${CYAN}🔄 Refreshing in ${refresh_interval}s... (Press 'A' for auto-failover toggle)${NC}"
        
        # Non-blocking read for user input
        if read -t $refresh_interval -n 1 key 2>/dev/null; then
            if [[ $key =~ ^[Aa]$ ]]; then
                if [ "$AUTO_FAILOVER_ENABLED" = true ]; then
                    AUTO_FAILOVER_ENABLED=false
                    log_event "⚠️ AUTO-FAILOVER DISABLED by user"
                else
                    AUTO_FAILOVER_ENABLED=true
                    log_event "⚡ AUTO-FAILOVER ENABLED by user"
                fi
            fi
        fi
    done
}

# Main
case "${1:-}" in
    "auto"|"a")
        AUTO_FAILOVER_ENABLED=true
        monitor_with_auto_failover 2
        ;;
    "manual"|"m")
        AUTO_FAILOVER_ENABLED=false
        monitor_with_auto_failover 2
        ;;
    "fast")
        AUTO_FAILOVER_ENABLED=true
        monitor_with_auto_failover 1
        ;;
    "help"|"h")
        echo "Enhanced Real-Time PostgreSQL HA Monitor"
        echo "Usage: $0 [mode]"
        echo ""
        echo "Modes:"
        echo "  auto, a       - Start with auto-failover enabled"
        echo "  manual, m     - Start with auto-failover disabled"
        echo "  fast          - Fast mode with auto-failover (1s refresh)"
        echo "  help, h       - Show this help"
        echo "  (default)     - Auto mode (2s refresh)"
        echo ""
        echo "During monitoring:"
        echo "  Press 'A'     - Toggle auto-failover on/off"
        echo "  Ctrl+C        - Exit"
        ;;
    *)
        AUTO_FAILOVER_ENABLED=true
        monitor_with_auto_failover 2
        ;;
esac 