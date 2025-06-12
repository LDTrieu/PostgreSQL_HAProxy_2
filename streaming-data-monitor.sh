#!/bin/bash

# PostgreSQL HA Streaming Data Monitor - High Speed Version
# Monitors real-time streaming data with full screen refresh

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Configuration
MASTER_PORT=5432
REPLICA1_PORT=5433
REPLICA2_PORT=5434
REPLICA3_PORT=5435
REPLICA4_PORT=5436
DB_NAME="postgres"
DB_USER="postgres"
DB_PASS="postgres"
TABLE_NAME="pos_order"  # Tên bảng chính xác

# Refresh interval (default 0.5 seconds for high speed)
REFRESH_INTERVAL=${1:-0.5}

# Clear screen and hide cursor
clear_screen() {
    printf '\033[2J\033[H\033[?25l'
}

# Show cursor on exit
show_cursor() {
    printf '\033[?25h'
}

# Trap to show cursor on exit
trap show_cursor EXIT

# Get container start time
get_container_start_time() {
    local container=$1
    docker inspect --format='{{.State.StartedAt}}' "$container" 2>/dev/null | cut -d'T' -f2 | cut -d'.' -f1
}

# Calculate uptime
calculate_uptime() {
    local container=$1
    local start_time=$(docker inspect --format='{{.State.StartedAt}}' "$container" 2>/dev/null)
    if [[ -n "$start_time" ]]; then
        local start_epoch=$(date -d "$start_time" +%s 2>/dev/null)
        local current_epoch=$(date +%s)
        local uptime_seconds=$((current_epoch - start_epoch))
        
        if [[ $uptime_seconds -lt 60 ]]; then
            echo "${uptime_seconds}s"
        elif [[ $uptime_seconds -lt 3600 ]]; then
            echo "$((uptime_seconds / 60))m $((uptime_seconds % 60))s"
        else
            echo "$((uptime_seconds / 3600))h $((uptime_seconds % 3600 / 60))m $((uptime_seconds % 60))s"
        fi
    else
        echo "N/A"
    fi
}

# Check if PostgreSQL is ready
check_pg_ready() {
    local container=$1
    # Connect directly to container using internal port 5432
    docker exec "$container" pg_isready -h localhost -p 5432 -U "$DB_USER" >/dev/null 2>&1
}

# Execute SQL query
execute_sql() {
    local container=$1
    local query=$2
    # Connect directly to container using internal port 5432
    docker exec "$container" psql -h localhost -p 5432 -U "$DB_USER" -d "$DB_NAME" -t -c "$query" 2>/dev/null | xargs
}

# Get node role and order count
get_node_info() {
    local container=$1
    
    if ! docker ps --format "table {{.Names}}" | grep -q "^${container}$" 2>/dev/null; then
        echo "DOWN|N/A|N/A"
        return 1
    fi
    
    if ! check_pg_ready "$container"; then
        echo "STARTING|N/A|N/A"
        return 1
    fi
    
    # Multiple checks to determine role accurately
    local is_in_recovery=$(execute_sql "$container" "SELECT pg_is_in_recovery();" 2>/dev/null)
    local can_write=$(execute_sql "$container" "SELECT CASE WHEN current_setting('transaction_read_only')::boolean THEN 'f' ELSE 't' END;" 2>/dev/null)
    local wal_level=$(execute_sql "$container" "SELECT current_setting('wal_level');" 2>/dev/null)
    local order_count=$(execute_sql "$container" "SELECT COUNT(*) FROM $TABLE_NAME;" 2>/dev/null || echo "0")
    
    # Determine role based on multiple factors
    local role="UNKNOWN"
    if [[ "$is_in_recovery" == "f" ]] && [[ "$can_write" == "t" ]]; then
        role="MASTER"
    elif [[ "$is_in_recovery" == "t" ]] || [[ "$can_write" == "f" ]]; then
        role="REPLICA"
    else
        # Additional check: try to write to a test table
        local write_test=$(execute_sql "$container" "SELECT 1;" 2>/dev/null)
        if [[ "$write_test" == "1" ]]; then
            # Try a more definitive test
            local master_check=$(execute_sql "$container" "SELECT CASE WHEN pg_is_in_recovery() THEN 'REPLICA' ELSE 'MASTER' END;" 2>/dev/null)
            role="$master_check"
        else
            role="REPLICA"
        fi
    fi
    
    if [[ "$role" == "MASTER" ]]; then
        echo "MASTER|$order_count|ACTIVE"
    else
        echo "REPLICA|$order_count|SYNCED"
    fi
}

# Get last 5 order IDs
get_last_orders() {
    local container=$1
    
    if ! docker ps --format "table {{.Names}}" | grep -q "^${container}$" 2>/dev/null; then
        echo "N/A"
        return 1
    fi
    
    if ! check_pg_ready "$container"; then
        echo "N/A"
        return 1
    fi
    
    local orders=$(execute_sql "$container" "SELECT string_agg(id::text, ',' ORDER BY id DESC) FROM (SELECT id FROM $TABLE_NAME ORDER BY id DESC LIMIT 5) t;" 2>/dev/null)
    echo "${orders:-N/A}"
}

# Get replication lag for replica
get_replication_lag() {
    local container=$1
    
    if ! docker ps --format "table {{.Names}}" | grep -q "^${container}$" 2>/dev/null; then
        echo "N/A"
        return 1
    fi
    
    if ! check_pg_ready "$container"; then
        echo "N/A"
        return 1
    fi
    
    local lag=$(execute_sql "$container" "SELECT COALESCE(EXTRACT(EPOCH FROM (now() - pg_last_xact_replay_timestamp()))::int, 0);" 2>/dev/null)
    
    if [[ "$lag" =~ ^[0-9]+$ ]]; then
        if [[ $lag -eq 0 ]]; then
            echo "0s (Excellent)"
        elif [[ $lag -lt 5 ]]; then
            echo "${lag}s (Good)"
        elif [[ $lag -lt 30 ]]; then
            echo "${lag}s (Warning)"
        else
            echo "${lag}s (High)"
        fi
    else
        echo "N/A"
    fi
}

# Monitor single node - optimized for speed
monitor_node() {
    local name=$1
    local container=$2
    local external_port=$3
    local color=$4
    
    # Get all info in parallel for speed - using container name directly
    local node_info=$(get_node_info "$container")
    local start_time=$(get_container_start_time "$container")
    local uptime=$(calculate_uptime "$container")
    local last_orders=$(get_last_orders "$container")
    
    IFS='|' read -r role order_count status <<< "$node_info"
    
    # Build output buffer
    local output=""
    output+="┌─ ${name} (${container}:${external_port}) $(printf '%*s' $((75 - ${#name} - ${#container} - ${#external_port})) '')┐\n"
    
    if [[ "$role" == "DOWN" ]]; then
        output+="│ Status: ❌ CONTAINER DOWN$(printf '%*s' 55 '')│\n"
        output+="│ Start Time: N/A$(printf '%*s' 60 '')│\n"
        output+="│ Uptime: N/A$(printf '%*s' 64 '')│\n"
        output+="│ Role: N/A$(printf '%*s' 66 '')│\n"
        output+="│ Order Count: N/A$(printf '%*s' 59 '')│\n"
        output+="│ Last 5 Orders: N/A$(printf '%*s' 57 '')│\n"
        output+="│ Replication Lag: N/A$(printf '%*s' 56 '')│\n"
    elif [[ "$role" == "STARTING" ]]; then
        output+="│ Status: 🔄 STARTING UP$(printf '%*s' 57 '')│\n"
        output+="│ Start Time: ${start_time}$(printf '%*s' $((64 - ${#start_time})) '')│\n"
        output+="│ Uptime: ${uptime}$(printf '%*s' $((68 - ${#uptime})) '')│\n"
        output+="│ Role: STARTING$(printf '%*s' 59 '')│\n"
        output+="│ Order Count: N/A$(printf '%*s' 59 '')│\n"
        output+="│ Last 5 Orders: N/A$(printf '%*s' 57 '')│\n"
        output+="│ Replication Lag: N/A$(printf '%*s' 56 '')│\n"
    else
        if [[ "$role" == "MASTER" ]]; then
            output+="│ Status: 🔥 MASTER - ACTIVE$(printf '%*s' 53 '')│\n"
            local lag_info="N/A (Master)"
        else
            local lag=$(get_replication_lag "$container")
            if [[ "$lag" == *"Excellent"* ]]; then
                output+="│ Status: 📘 REPLICA - SYNCED$(printf '%*s' 52 '')│\n"
            elif [[ "$lag" == *"High"* ]]; then
                output+="│ Status: 📘 REPLICA - LAG ${lag%% *}$(printf '%*s' $((48 - ${#lag})) '')│\n"
            else
                output+="│ Status: 📘 REPLICA - SYNCED$(printf '%*s' 52 '')│\n"
            fi
            local lag_info="$lag"
        fi
        
        output+="│ Start Time: ${start_time}$(printf '%*s' $((64 - ${#start_time})) '')│\n"
        output+="│ Uptime: ${uptime}$(printf '%*s' $((68 - ${#uptime})) '')│\n"
        output+="│ Role: ${role}$(printf '%*s' $((70 - ${#role})) '')│\n"
        output+="│ Order Count: ${order_count}$(printf '%*s' $((65 - ${#order_count})) '')│\n"
        output+="│ Last 5 Orders: ${last_orders}$(printf '%*s' $((63 - ${#last_orders})) '')│\n"
        output+="│ Replication Lag: ${lag_info}$(printf '%*s' $((60 - ${#lag_info})) '')│\n"
    fi
    
    output+="└$(printf '%*s' 77 '' | tr ' ' '─')┘\n"
    
    echo -e "${color}${output}${NC}"
}

# Get cluster summary - optimized
get_cluster_summary() {
    local total_nodes=5
    local active_nodes=0
    local master_count=0
    local replica_count=0
    local total_orders=0
    
    # Quick parallel check - connect directly to containers
    for container in postgres-master postgres-replica1 postgres-replica2 postgres-replica3 postgres-replica4; do
        if docker ps --format "table {{.Names}}" | grep -q "^${container}$" 2>/dev/null; then
            ((active_nodes++))
            local info=$(get_node_info "$container")
            IFS='|' read -r role order_count status <<< "$info"
            if [[ "$role" == "MASTER" ]]; then
                ((master_count++))
                total_orders=$order_count
            elif [[ "$role" == "REPLICA" ]]; then
                ((replica_count++))
            fi
        fi
    done
    
    echo "📊 CLUSTER SUMMARY:"
    echo "═══════════════════"
    echo "🖥️  Total Nodes: $total_nodes | 🟢 Active: $active_nodes | 🔴 Down: $((total_nodes - active_nodes))"
    echo "👑 Masters: $master_count | 📚 Replicas: $replica_count"
    echo "📦 Total Orders: $total_orders"
    echo ""
    echo "⚡ Refresh Rate: ${REFRESH_INTERVAL}s | 🕐 $(date '+%H:%M:%S')"
    echo "💡 Press Ctrl+C to exit"
}

# Main monitoring loop - high speed
main_monitor() {
    clear_screen
    
    while true; do
        # Move cursor to top
        printf '\033[H'
        
        # Header
        echo -e "${BOLD}${CYAN}"
        echo "╔════════════════════════════════════════════════════════════════════════════════════════╗"
        echo "║                    🔄 PostgreSQL HA Streaming Data Monitor                            ║"
        echo "║                              $(date '+%Y-%m-%d %H:%M:%S')                                   ║"
        echo "╚════════════════════════════════════════════════════════════════════════════════════════╝"
        echo -e "${NC}"
        
        # Monitor all nodes
        monitor_node "Master" "postgres-master" "$MASTER_PORT" "$GREEN"
        monitor_node "Replica-1" "postgres-replica1" "$REPLICA1_PORT" "$BLUE"
        monitor_node "Replica-2" "postgres-replica2" "$REPLICA2_PORT" "$BLUE"
        monitor_node "Replica-3" "postgres-replica3" "$REPLICA3_PORT" "$BLUE"
        monitor_node "Replica-4" "postgres-replica4" "$REPLICA4_PORT" "$BLUE"
        
        # Summary
        echo -e "${YELLOW}"
        get_cluster_summary
        echo -e "${NC}"
        
        # High speed refresh
        sleep "$REFRESH_INTERVAL"
    done
}

# Start monitoring
echo -e "${GREEN}🚀 Starting High-Speed PostgreSQL HA Streaming Monitor...${NC}"
echo -e "${YELLOW}⚡ Refresh Rate: ${REFRESH_INTERVAL}s${NC}"
sleep 1

main_monitor 