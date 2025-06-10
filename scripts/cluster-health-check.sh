#!/bin/bash

# PostgreSQL HA Cluster Real-time Health Check Script
# Continuous monitoring với health scoring

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
MASTER_PORT=5432
REPLICA1_PORT=5433
REPLICA2_PORT=5434
REPLICA3_PORT=5435
DB_NAME="pos_db"
DB_USER="postgres"
DB_PASS="postgres123"
HAPROXY_WRITE_PORT=5439
HAPROXY_READ_PORT=5440
REFRESH_INTERVAL=5

# Health score thresholds
EXCELLENT_THRESHOLD=95
GOOD_THRESHOLD=80
WARNING_THRESHOLD=60

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

header() {
    echo -e "${PURPLE}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    printf "${PURPLE}║${NC} %-74s ${PURPLE}║${NC}\n" "$1"
    echo -e "${PURPLE}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
}

# Check PostgreSQL connection health
check_postgres_health() {
    local host=$1
    local port=$2
    local name=$3
    local health_score=0
    local status_details=""
    
    # Test connection (30 points)
    if PGPASSWORD=$DB_PASS psql -h $host -p $port -U $DB_USER -d $DB_NAME -c "SELECT 1;" > /dev/null 2>&1; then
        health_score=$((health_score + 30))
        status_details="${status_details}✅ Connection "
    else
        status_details="${status_details}❌ Connection "
    fi
    
    # Test basic query performance (20 points)
    local start_time=$(date +%s%N)
    if PGPASSWORD=$DB_PASS psql -h $host -p $port -U $DB_USER -d $DB_NAME -t -c "SELECT COUNT(*) FROM pos_product;" > /dev/null 2>&1; then
        local end_time=$(date +%s%N)
        local query_time=$(( (end_time - start_time) / 1000000 ))  # Convert to milliseconds
        if [ $query_time -lt 100 ]; then
            health_score=$((health_score + 20))
            status_details="${status_details}✅ Query(${query_time}ms) "
        elif [ $query_time -lt 500 ]; then
            health_score=$((health_score + 15))
            status_details="${status_details}⚠️  Query(${query_time}ms) "
        else
            health_score=$((health_score + 5))
            status_details="${status_details}🐌 Query(${query_time}ms) "
        fi
    else
        status_details="${status_details}❌ Query "
    fi
    
    # Check role consistency (25 points)
    local role=$(PGPASSWORD=$DB_PASS psql -h $host -p $port -U $DB_USER -d $DB_NAME -t -c "SELECT CASE WHEN pg_is_in_recovery() THEN 'REPLICA' ELSE 'MASTER' END;" 2>/dev/null | xargs)
    if [ ! -z "$role" ]; then
        health_score=$((health_score + 20))
        status_details="${status_details}✅ Role($role) "
        
        # Additional check for replication lag (master only) (5 bonus points)
        if [ "$role" = "MASTER" ]; then
            local replica_count=$(PGPASSWORD=$DB_PASS psql -h $host -p $port -U $DB_USER -d $DB_NAME -t -c "SELECT COUNT(*) FROM pg_stat_replication;" 2>/dev/null | xargs || echo "0")
            if [ "$replica_count" -gt "0" ]; then
                health_score=$((health_score + 5))
                status_details="${status_details}✅ Replicas($replica_count) "
            fi
        fi
    else
        status_details="${status_details}❌ Role "
    fi
    
    # Check data consistency (25 points)
    local product_count=$(PGPASSWORD=$DB_PASS psql -h $host -p $port -U $DB_USER -d $DB_NAME -t -c "SELECT COUNT(*) FROM pos_product;" 2>/dev/null | xargs || echo "N/A")
    if [ "$product_count" != "N/A" ] && [ "$product_count" -gt "0" ]; then
        health_score=$((health_score + 25))
        status_details="${status_details}✅ Data($product_count) "
    else
        status_details="${status_details}❌ Data($product_count) "
    fi
    
    # Return results
    echo "$health_score|$status_details|$role|$product_count"
}

# Check HAProxy health
check_haproxy_health() {
    local health_score=0
    local status_details=""
    
    # Check write port
    if PGPASSWORD=$DB_PASS psql -h localhost -p $HAPROXY_WRITE_PORT -U $DB_USER -d $DB_NAME -c "SELECT 1;" > /dev/null 2>&1; then
        health_score=$((health_score + 50))
        status_details="${status_details}✅ Write "
    else
        status_details="${status_details}❌ Write "
    fi
    
    # Check read port
    if PGPASSWORD=$DB_PASS psql -h localhost -p $HAPROXY_READ_PORT -U $DB_USER -d $DB_NAME -c "SELECT 1;" > /dev/null 2>&1; then
        health_score=$((health_score + 50))
        status_details="${status_details}✅ Read "
    else
        status_details="${status_details}❌ Read "
    fi
    
    echo "$health_score|$status_details"
}

# Get Docker container status
check_docker_health() {
    local containers=("postgres-master" "postgres-replica1" "postgres-replica2" "postgres-replica3" "haproxy" "grafana" "prometheus")
    local running_count=0
    local total_count=${#containers[@]}
    
    for container in "${containers[@]}"; do
        if docker ps --format "{{.Names}}" | grep -q "^${container}$"; then
            ((running_count++))
        fi
    done
    
    local health_percentage=$(( (running_count * 100) / total_count ))
    echo "$running_count/$total_count ($health_percentage%)"
}

# Calculate overall cluster health
calculate_cluster_health() {
    local master_score=$1
    local replica1_score=$2
    local replica2_score=$3
    local replica3_score=$4
    local haproxy_score=$5
    
    # Weighted calculation
    local master_weight=40
    local replica_weight=15  # Each replica gets 15%
    local haproxy_weight=15
    
    local total_score=$(( 
        (master_score * master_weight / 100) + 
        (replica1_score * replica_weight / 100) + 
        (replica2_score * replica_weight / 100) + 
        (replica3_score * replica_weight / 100) + 
        (haproxy_score * haproxy_weight / 100)
    ))
    
    echo $total_score
}

# Get health status color
get_health_color() {
    local score=$1
    if [ $score -ge $EXCELLENT_THRESHOLD ]; then
        echo $GREEN
    elif [ $score -ge $GOOD_THRESHOLD ]; then
        echo $CYAN
    elif [ $score -ge $WARNING_THRESHOLD ]; then
        echo $YELLOW
    else
        echo $RED
    fi
}

# Get health status text
get_health_status() {
    local score=$1
    if [ $score -ge $EXCELLENT_THRESHOLD ]; then
        echo "EXCELLENT"
    elif [ $score -ge $GOOD_THRESHOLD ]; then
        echo "GOOD"
    elif [ $score -ge $WARNING_THRESHOLD ]; then
        echo "WARNING"
    else
        echo "CRITICAL"
    fi
}

# Display real-time health dashboard
display_health_dashboard() {
    clear
    header "POSTGRESQL HA CLUSTER - REAL-TIME HEALTH MONITORING"
    
    echo -e "${CYAN}📊 Checking cluster health...${NC}"
    
    # Check all components
    local master_result=$(check_postgres_health localhost $MASTER_PORT "Master")
    local replica1_result=$(check_postgres_health localhost $REPLICA1_PORT "Replica1")
    local replica2_result=$(check_postgres_health localhost $REPLICA2_PORT "Replica2") 
    local replica3_result=$(check_postgres_health localhost $REPLICA3_PORT "Replica3")
    local haproxy_result=$(check_haproxy_health)
    local docker_status=$(check_docker_health)
    
    # Parse results
    IFS='|' read -r master_score master_details master_role master_count <<< "$master_result"
    IFS='|' read -r replica1_score replica1_details replica1_role replica1_count <<< "$replica1_result"
    IFS='|' read -r replica2_score replica2_details replica2_role replica2_count <<< "$replica2_result"
    IFS='|' read -r replica3_score replica3_details replica3_role replica3_count <<< "$replica3_result"
    IFS='|' read -r haproxy_score haproxy_details <<< "$haproxy_result"
    
    # Calculate overall health
    local cluster_health=$(calculate_cluster_health $master_score $replica1_score $replica2_score $replica3_score $haproxy_score)
    local health_color=$(get_health_color $cluster_health)
    local health_status=$(get_health_status $cluster_health)
    
    echo ""
    echo -e "${health_color}🏥 OVERALL CLUSTER HEALTH: ${cluster_health}/100 (${health_status})${NC}"
    echo -e "${CYAN}🐳 Docker Containers: ${docker_status}${NC}"
    echo ""
    
    # Display detailed component health
    printf "%-15s %-10s %-8s %-60s\n" "COMPONENT" "HEALTH" "ROLE" "STATUS DETAILS"
    echo "─────────────────────────────────────────────────────────────────────────────────────────"
    
    # Master
    local master_color=$(get_health_color $master_score)
    printf "%-15s ${master_color}%-10s${NC} %-8s %-60s\n" "Master" "${master_score}/100" "$master_role" "$master_details"
    
    # Replicas
    local replica1_color=$(get_health_color $replica1_score)
    printf "%-15s ${replica1_color}%-10s${NC} %-8s %-60s\n" "Replica1" "${replica1_score}/100" "$replica1_role" "$replica1_details"
    
    local replica2_color=$(get_health_color $replica2_score)
    printf "%-15s ${replica2_color}%-10s${NC} %-8s %-60s\n" "Replica2" "${replica2_score}/100" "$replica2_role" "$replica2_details"
    
    local replica3_color=$(get_health_color $replica3_score)
    printf "%-15s ${replica3_color}%-10s${NC} %-8s %-60s\n" "Replica3" "${replica3_score}/100" "$replica3_role" "$replica3_details"
    
    # HAProxy
    local haproxy_color=$(get_health_color $haproxy_score)
    printf "%-15s ${haproxy_color}%-10s${NC} %-8s %-60s\n" "HAProxy" "${haproxy_score}/100" "LB" "$haproxy_details"
    
    echo ""
    
    # Data consistency check
    echo -e "${CYAN}📊 DATA CONSISTENCY CHECK:${NC}"
    printf "%-15s %-10s\n" "NODE" "PRODUCT COUNT"
    echo "─────────────────────────────"
    printf "%-15s %-10s\n" "Master" "$master_count"
    printf "%-15s %-10s\n" "Replica1" "$replica1_count"
    printf "%-15s %-10s\n" "Replica2" "$replica2_count"
    printf "%-15s %-10s\n" "Replica3" "$replica3_count"
    
    # Check for data inconsistency
    if [ "$master_count" != "$replica1_count" ] || [ "$master_count" != "$replica2_count" ] || [ "$master_count" != "$replica3_count" ]; then
        echo -e "${RED}⚠️  DATA INCONSISTENCY DETECTED!${NC}"
    else
        echo -e "${GREEN}✅ All nodes have consistent data${NC}"
    fi
    
    echo ""
    echo -e "${CYAN}🔗 Quick Access URLs:${NC}"
    echo "  • Grafana Dashboard: http://localhost:3000 (admin/admin123)"
    echo "  • Prometheus: http://localhost:9090"
    echo "  • HAProxy Stats: http://localhost:8080/stats"
    
    echo ""
    echo -e "${BLUE}⏰ Last updated: $(date)${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop monitoring${NC}"
}

# Monitor cluster in real-time
monitor_cluster() {
    log "🚀 Starting PostgreSQL HA Cluster Health Monitoring"
    log "Refresh interval: ${REFRESH_INTERVAL} seconds"
    
    # Trap to handle graceful shutdown
    trap 'echo -e "\n${YELLOW}Monitoring stopped by user${NC}"; exit 0' INT
    
    while true; do
        display_health_dashboard
        sleep $REFRESH_INTERVAL
    done
}

# One-time health check
single_health_check() {
    log "🔍 Performing single health check..."
    display_health_dashboard
}

# Show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -m, --monitor     Continuous monitoring mode (default)"
    echo "  -s, --single      Single health check"
    echo "  -i, --interval N  Set refresh interval (seconds, default: 5)"
    echo "  -h, --help        Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                    # Start continuous monitoring"
    echo "  $0 --single           # Perform single health check"
    echo "  $0 --monitor -i 10    # Monitor with 10-second intervals"
}

# Main function
main() {
    local mode="monitor"
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -m|--monitor)
                mode="monitor"
                shift
                ;;
            -s|--single)
                mode="single"
                shift
                ;;
            -i|--interval)
                REFRESH_INTERVAL="$2"
                shift 2
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Execute based on mode
    case $mode in
        "monitor")
            monitor_cluster
            ;;
        "single")
            single_health_check
            ;;
        *)
            echo "Invalid mode: $mode"
            exit 1
            ;;
    esac
}

# Execute main function
main "$@" 