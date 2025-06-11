#!/bin/bash

# Real-time PostgreSQL HA Monitor
# Continuous monitoring để thấy failover real-time

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Interval between refreshes (seconds)
REFRESH_INTERVAL=2

print_header() {
    echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║                    🔍 PostgreSQL HA Real-Time Monitor                        ║${NC}"
    echo -e "${BOLD}${CYAN}║                         $(date '+%Y-%m-%d %H:%M:%S')                              ║${NC}"
    echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

check_node_status() {
    local node=$1
    local label=$2
    local color=$3
    
    echo -n -e "${color}${BOLD}${label}:${NC} "
    
    # Check container first
    if ! timeout 3 docker ps --format "table {{.Names}}" | grep -q "^${node}$" 2>/dev/null; then
        echo -e "${RED}❌ CONTAINER DOWN${NC}"
        return 1
    fi
    
    # Check PostgreSQL role
    if timeout 5 docker exec ${node} psql -U postgres -t -c "SELECT 'CONNECTED'" >/dev/null 2>&1; then
        local role=$(timeout 5 docker exec ${node} psql -U postgres -t -c "SELECT CASE WHEN pg_is_in_recovery() THEN 'REPLICA' ELSE 'MASTER' END;" 2>/dev/null | tr -d ' \t\n\r')
        
        case $role in
            "MASTER")
                echo -e "${RED}🔥 MASTER${NC} $(get_connection_info $node)"
                ;;
            "REPLICA")
                echo -e "${BLUE}📘 REPLICA${NC} $(get_connection_info $node)"
                ;;
            *)
                echo -e "${YELLOW}⚠️ UNKNOWN ROLE${NC}"
                ;;
        esac
    else
        echo -e "${RED}❌ CONNECTION FAILED${NC}"
        return 1
    fi
}

get_connection_info() {
    local node=$1
    local orders=$(timeout 3 docker exec ${node} psql -U postgres -d pos_db -t -c "SELECT COUNT(*) FROM pos_order;" 2>/dev/null | tr -d ' \t\n\r')
    if [ -n "$orders" ]; then
        echo -e "${GREEN}(${orders} orders)${NC}"
    else
        echo -e "${RED}(no data)${NC}"
    fi
}

check_haproxy_status() {
    echo -n -e "${PURPLE}${BOLD}HAProxy:${NC} "
    
    if timeout 3 docker ps --format "table {{.Names}}" | grep -q "^haproxy$" 2>/dev/null; then
        if timeout 3 curl -s "http://localhost:8080/stats" > /dev/null 2>&1; then
            echo -e "${GREEN}✅ RUNNING${NC} ${CYAN}(Stats: http://localhost:8080/stats)${NC}"
        else
            echo -e "${YELLOW}⚠️ CONTAINER UP BUT STATS UNREACHABLE${NC}"
        fi
    else
        echo -e "${RED}❌ CONTAINER DOWN${NC}"
    fi
}

check_cluster_summary() {
    echo ""
    echo -e "${BOLD}${YELLOW}📊 CLUSTER SUMMARY:${NC}"
    echo -e "${YELLOW}═══════════════════${NC}"
    
    local master_count=0
    local replica_count=0
    local down_count=0
    
    for node in postgres-master postgres-replica1 postgres-replica2 postgres-replica3; do
        if timeout 3 docker ps --format "table {{.Names}}" | grep -q "^${node}$" 2>/dev/null; then
            if timeout 5 docker exec ${node} psql -U postgres -t -c "SELECT 'CONNECTED'" >/dev/null 2>&1; then
                local role=$(timeout 5 docker exec ${node} psql -U postgres -t -c "SELECT CASE WHEN pg_is_in_recovery() THEN 'REPLICA' ELSE 'MASTER' END;" 2>/dev/null | tr -d ' \t\n\r')
                case $role in
                    "MASTER") ((master_count++)) ;;
                    "REPLICA") ((replica_count++)) ;;
                esac
            else
                ((down_count++))
            fi
        else
            ((down_count++))
        fi
    done
    
    echo -e "  🔥 Masters: ${RED}${BOLD}${master_count}${NC}"
    echo -e "  📘 Replicas: ${BLUE}${BOLD}${replica_count}${NC}"
    echo -e "  ❌ Down/Failed: ${RED}${BOLD}${down_count}${NC}"
    
    # Health status
    if [ $master_count -eq 1 ] && [ $down_count -eq 0 ]; then
        echo -e "  🟢 Cluster Health: ${GREEN}${BOLD}HEALTHY${NC}"
    elif [ $master_count -eq 1 ] && [ $down_count -gt 0 ]; then
        echo -e "  🟡 Cluster Health: ${YELLOW}${BOLD}DEGRADED${NC}"
    elif [ $master_count -eq 0 ]; then
        echo -e "  🔴 Cluster Health: ${RED}${BOLD}NO MASTER${NC}"
    elif [ $master_count -gt 1 ]; then
        echo -e "  🟠 Cluster Health: ${RED}${BOLD}SPLIT-BRAIN${NC}"
    fi
}

show_instructions() {
    echo ""
    echo -e "${BOLD}${CYAN}🎯 TEST INSTRUCTIONS:${NC}"
    echo -e "${CYAN}═══════════════════${NC}"
    echo -e "  ${GREEN}• Open another terminal${NC}"
    echo -e "  ${GREEN}• Run: ${YELLOW}docker stop postgres-master${NC}     ${CYAN}# Stop master${NC}"
    echo -e "  ${GREEN}• Run: ${YELLOW}docker stop postgres-replica1${NC}   ${CYAN}# Stop replica${NC}"
    echo -e "  ${GREEN}• Run: ${YELLOW}docker start postgres-master${NC}    ${CYAN}# Restart master${NC}"
    echo -e "  ${GREEN}• Watch this screen for real-time updates!${NC}"
    echo ""
    echo -e "  ${RED}• Press Ctrl+C to exit${NC}"
}

monitor_loop() {
    trap 'echo -e "\n${YELLOW}👋 Monitoring stopped by user${NC}"; exit 0' INT
    
    while true; do
        clear
        print_header
        
        echo -e "${BOLD}${GREEN}📦 NODE STATUS:${NC}"
        echo -e "${GREEN}═══════════════${NC}"
        check_node_status "postgres-master" "Master   " "${RED}"
        check_node_status "postgres-replica1" "Replica-1" "${BLUE}"
        check_node_status "postgres-replica2" "Replica-2" "${BLUE}"
        check_node_status "postgres-replica3" "Replica-3" "${BLUE}"
        
        echo ""
        echo -e "${BOLD}${PURPLE}🔀 LOAD BALANCER:${NC}"
        echo -e "${PURPLE}═════════════════${NC}"
        check_haproxy_status
        
        check_cluster_summary
        show_instructions
        
        echo -e "${CYAN}🔄 Refreshing in ${REFRESH_INTERVAL}s...${NC}"
        sleep $REFRESH_INTERVAL
    done
}

# Support different modes
case "${1:-}" in
    "once"|"o")
        print_header
        echo -e "${BOLD}${GREEN}📦 NODE STATUS:${NC}"
        echo -e "${GREEN}═══════════════${NC}"
        check_node_status "postgres-master" "Master   " "${RED}"
        check_node_status "postgres-replica1" "Replica-1" "${BLUE}"
        check_node_status "postgres-replica2" "Replica-2" "${BLUE}"
        check_node_status "postgres-replica3" "Replica-3" "${BLUE}"
        
        echo ""
        echo -e "${BOLD}${PURPLE}🔀 LOAD BALANCER:${NC}"
        echo -e "${PURPLE}═════════════════${NC}"
        check_haproxy_status
        
        check_cluster_summary
        ;;
        
    "fast"|"f")
        REFRESH_INTERVAL=1
        echo -e "${YELLOW}🚀 Fast mode: 1 second refresh${NC}"
        sleep 2
        monitor_loop
        ;;
        
    "slow"|"s")
        REFRESH_INTERVAL=5
        echo -e "${YELLOW}🐌 Slow mode: 5 second refresh${NC}"
        sleep 2
        monitor_loop
        ;;
        
    "help"|"h")
        echo -e "${BOLD}${CYAN}🔍 Real-Time PostgreSQL HA Monitor${NC}"
        echo ""
        echo "Usage: $0 [mode]"
        echo ""
        echo "Modes:"
        echo "  (default)    - Real-time monitoring (2s refresh)"
        echo "  once, o      - Single check (no loop)"
        echo "  fast, f      - Fast monitoring (1s refresh)"
        echo "  slow, s      - Slow monitoring (5s refresh)"
        echo "  help, h      - Show this help"
        echo ""
        echo "Examples:"
        echo "  $0           # Start real-time monitoring"
        echo "  $0 once      # Single status check"
        echo "  $0 fast      # Fast refresh mode"
        echo ""
        echo "During monitoring:"
        echo "  • Open another terminal"
        echo "  • Run: docker stop postgres-master"
        echo "  • Watch real-time failover detection!"
        ;;
        
    *)
        echo -e "${YELLOW}🔍 Starting Real-Time HA Monitor...${NC}"
        echo -e "${CYAN}Press Ctrl+C to stop${NC}"
        sleep 2
        monitor_loop
        ;;
esac 