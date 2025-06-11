#!/bin/bash

# ============================================================================
# 🔍 PostgreSQL HA Cluster CLI Monitor
# Thay thế cho Grafana khi cần check nhanh cluster status
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_header() {
    echo ""
    echo "============================================================================"
    echo -e "${GREEN}🔍 PostgreSQL HA Cluster Monitor${NC}"
    echo -e "${BLUE}$(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo "============================================================================"
}

check_container_status() {
    echo ""
    echo -e "${YELLOW}📦 CONTAINER STATUS:${NC}"
    echo "--------------------------------------------"
    
    containers=("postgres-master" "postgres-replica1" "postgres-replica2" "postgres-replica3" "haproxy")
    
    for container in "${containers[@]}"; do
        if docker ps --format "table {{.Names}}" | grep -q "^${container}$"; then
            status=$(docker ps --format "table {{.Names}}\t{{.Status}}" | grep "^${container}" | awk '{print $2}')
            echo -e "✅ ${GREEN}${container}${NC}: ${status}"
        else
            echo -e "❌ ${RED}${container}${NC}: DOWN/NOT FOUND"
        fi
    done
}

check_postgres_roles() {
    echo ""
    echo -e "${YELLOW}🔥 POSTGRESQL ROLES & MASTER DETECTION:${NC}"
    echo "------------------------------------------------------------"
    
    # Master check
    echo -n "🔥 Master (postgres-master): "
    # First check if container is running
    if ! docker ps --format "table {{.Names}}" | grep -q "^postgres-master$"; then
        echo -e "${RED}❌ CONTAINER DOWN${NC}"
    elif master_role=$(docker exec postgres-master psql -U postgres -t -c "SELECT CASE WHEN pg_is_in_recovery() THEN 'REPLICA' ELSE 'MASTER' END;" 2>/dev/null | tr -d ' \t\n\r'); then
        if [ "$master_role" = "MASTER" ]; then
            echo -e "${RED}✅ MASTER${NC}"
        else
            echo -e "${BLUE}📘 REPLICA (Should be MASTER!)${NC}"
        fi
    else
        echo -e "${RED}❌ CONNECTION FAILED${NC}"
    fi
    
    # Replicas check
    replicas=("postgres-replica1" "postgres-replica2" "postgres-replica3")
    
    for replica in "${replicas[@]}"; do
        echo -n "📘 ${replica}: "
        # Check if container is running first
        if ! docker ps --format "table {{.Names}}" | grep -q "^${replica}$"; then
            echo -e "${RED}❌ CONTAINER DOWN${NC}"
        elif role=$(docker exec ${replica} psql -U postgres -t -c "SELECT CASE WHEN pg_is_in_recovery() THEN 'REPLICA' ELSE 'NEW-MASTER' END;" 2>/dev/null | tr -d ' \t\n\r'); then
            if [ "$role" = "REPLICA" ]; then
                echo -e "${BLUE}📘 REPLICA${NC}"
            else
                echo -e "${RED}🔥 NEW-MASTER (Promoted!)${NC}"
            fi
        else
            echo -e "${RED}❌ CONNECTION FAILED${NC}"
        fi
    done
}

check_orders_count() {
    echo ""
    echo -e "${YELLOW}📊 ORDERS COUNT (POS_ORDER table):${NC}"
    echo "--------------------------------------------"
    
    nodes=("postgres-master" "postgres-replica1" "postgres-replica2" "postgres-replica3")
    
    for node in "${nodes[@]}"; do
        echo -n "${node}: "
        if count=$(docker exec ${node} psql -U postgres -d pos_db -t -c "SELECT COUNT(*) FROM pos_order;" 2>/dev/null | tr -d ' \t\n\r'); then
            echo -e "${GREEN}${count} orders${NC}"
        else
            echo -e "${RED}❌ FAILED${NC}"
        fi
    done
}

check_replication_status() {
    echo ""
    echo -e "${YELLOW}🔄 REPLICATION STATUS:${NC}"
    echo "-------------------------------------"
    
    echo "🔥 Master replication status:"
    if docker exec postgres-master psql -U postgres -c "SELECT client_addr, state, sent_lsn, write_lsn, flush_lsn, replay_lsn FROM pg_stat_replication;" 2>/dev/null; then
        echo ""
    else
        echo -e "${RED}❌ Master connection failed${NC}"
    fi
    
    echo "📘 Replica lag status:"
    replicas=("postgres-replica1" "postgres-replica2" "postgres-replica3")
    
    for replica in "${replicas[@]}"; do
        echo -n "${replica}: "
        if lag=$(docker exec ${replica} psql -U postgres -t -c "SELECT CASE WHEN pg_is_in_recovery() THEN pg_last_wal_receive_lsn() - pg_last_wal_replay_lsn() ELSE 'Not in recovery' END;" 2>/dev/null | tr -d ' \t\n\r'); then
            echo -e "${GREEN}${lag}${NC}"
        else
            echo -e "${RED}❌ FAILED${NC}"
        fi
    done
}

check_haproxy_status() {
    echo ""
    echo -e "${YELLOW}🔀 HAPROXY STATUS:${NC}"
    echo "----------------------------"
    
    if curl -s "http://localhost:8080/stats" > /dev/null 2>&1; then
        echo -e "✅ ${GREEN}HAProxy Stats available at: http://localhost:8080/stats${NC}"
        
        # Simple status check
        if docker exec haproxy curl -s "http://localhost:8080/stats/;csv" | grep -q "postgres-master.*UP"; then
            echo -e "🔥 ${GREEN}Master backend: UP${NC}"
        else
            echo -e "🔥 ${RED}Master backend: DOWN${NC}"
        fi
        
        replica_up=$(docker exec haproxy curl -s "http://localhost:8080/stats/;csv" | grep "postgres-replica.*UP" | wc -l)
        echo -e "📘 ${GREEN}Replica backends UP: ${replica_up}/3${NC}"
    else
        echo -e "❌ ${RED}HAProxy not accessible${NC}"
    fi
}

run_continuous_monitor() {
    echo ""
    echo -e "${YELLOW}🔄 CONTINUOUS MONITORING MODE (Press Ctrl+C to stop)${NC}"
    echo "=================================================="
    
    while true; do
        clear
        print_header
        check_container_status
        check_postgres_roles
        check_orders_count
        echo ""
        echo -e "${BLUE}⏰ Next refresh in 5 seconds...${NC}"
        sleep 5
    done
}

# Main menu
case "${1:-}" in
    "containers"|"c")
        print_header
        check_container_status
        ;;
    "roles"|"r")
        print_header
        check_postgres_roles
        ;;
    "orders"|"o")
        print_header
        check_orders_count
        ;;
    "replication"|"rep")
        print_header
        check_replication_status
        ;;
    "haproxy"|"h")
        print_header
        check_haproxy_status
        ;;
    "all"|"a"|"")
        print_header
        check_container_status
        check_postgres_roles
        check_orders_count
        check_replication_status
        check_haproxy_status
        ;;
    "watch"|"w")
        run_continuous_monitor
        ;;
    "help"|"--help"|"-h")
        echo ""
        echo "🔍 PostgreSQL HA Cluster Monitor - USAGE:"
        echo "=========================================="
        echo ""
        echo "  ./monitor-cluster-cli.sh [command]"
        echo ""
        echo "COMMANDS:"
        echo "  containers, c     - Check container status"
        echo "  roles, r          - Check PostgreSQL roles & master detection"
        echo "  orders, o         - Check orders count in each node"
        echo "  replication, rep  - Check replication status & lag"
        echo "  haproxy, h        - Check HAProxy status"
        echo "  all, a            - Run all checks (default)"
        echo "  watch, w          - Continuous monitoring mode"
        echo "  help, -h          - Show this help"
        echo ""
        echo "EXAMPLES:"
        echo "  ./monitor-cluster-cli.sh              # Full check"
        echo "  ./monitor-cluster-cli.sh roles        # Only check roles"
        echo "  ./monitor-cluster-cli.sh watch        # Continuous monitoring"
        echo ""
        ;;
    *)
        echo "❌ Unknown option: $1"
        echo "Use './monitor-cluster-cli.sh help' for usage information."
        exit 1
        ;;
esac 