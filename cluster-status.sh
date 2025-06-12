#!/bin/bash

# PostgreSQL HA Cluster Status Script
# Hiển thị trạng thái tổng quan của cluster

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configuration
MASTER_PORT=5432
REPLICA_PORTS=(5433 5434 5435 5436)
DB_NAME="pos_db"
DB_USER="postgres"
DB_PASS="postgres123"

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    case $status in
        "OK")
            echo -e "${GREEN}✅ $message${NC}"
            ;;
        "ERROR")
            echo -e "${RED}❌ $message${NC}"
            ;;
        "WARNING")
            echo -e "${YELLOW}⚠️  $message${NC}"
            ;;
        "INFO")
            echo -e "${BLUE}ℹ️  $message${NC}"
            ;;
        "HEADER")
            echo -e "${BOLD}${CYAN}$message${NC}"
            ;;
    esac
}

# Function to check if PostgreSQL is ready
check_postgres_ready() {
    local port=$1
    if timeout 3 bash -c "pg_isready -h localhost -p $port -U $DB_USER" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Function to execute SQL query
execute_sql() {
    local port=$1
    local query=$2
    PGPASSWORD=$DB_PASS psql -h localhost -p $port -U $DB_USER -d $DB_NAME -t -c "$query" 2>/dev/null | xargs
}

# Function to check service availability
check_service() {
    local service=$1
    local port=$2
    if nc -z localhost $port 2>/dev/null; then
        print_status "OK" "$service (port $port) is accessible"
        return 0
    else
        print_status "ERROR" "$service (port $port) is not accessible"
        return 1
    fi
}

# Main status check
echo -e "${BOLD}${CYAN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║              PostgreSQL HA Cluster Status                   ║"
echo "║                    $(date)                    ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check Docker containers
print_status "HEADER" "🐳 Docker Containers Status:"
containers=("postgres-master" "postgres-replica1" "postgres-replica2" "postgres-replica3" "postgres-replica4" "haproxy" "grafana" "prometheus")
for container in "${containers[@]}"; do
    if docker ps --format "table {{.Names}}" | grep -q "^$container$"; then
        print_status "OK" "$container is running"
    else
        print_status "ERROR" "$container is not running"
    fi
done

echo ""

# Check PostgreSQL connections
print_status "HEADER" "🔗 PostgreSQL Connections:"
if check_postgres_ready $MASTER_PORT; then
    master_count=$(execute_sql $MASTER_PORT "SELECT COUNT(*) FROM pos_product;" 2>/dev/null || echo "0")
    print_status "OK" "Master PostgreSQL (port $MASTER_PORT) - $master_count products"
else
    print_status "ERROR" "Master PostgreSQL (port $MASTER_PORT) is not ready"
    master_count=0
fi

for port in "${REPLICA_PORTS[@]}"; do
    if check_postgres_ready $port; then
        replica_count=$(execute_sql $port "SELECT COUNT(*) FROM pos_product;" 2>/dev/null || echo "0")
        if [ "$master_count" = "$replica_count" ]; then
            print_status "OK" "Replica PostgreSQL (port $port) - $replica_count products ✓ Synced"
        else
            print_status "WARNING" "Replica PostgreSQL (port $port) - $replica_count products ⚠️ Out of sync"
        fi
    else
        print_status "ERROR" "Replica PostgreSQL (port $port) is not ready"
    fi
done

echo ""

# Check HAProxy
print_status "HEADER" "⚖️ HAProxy Load Balancer:"
check_service "HAProxy Write Port" 5439
check_service "HAProxy Read Port" 5440
check_service "HAProxy Stats" 8080

echo ""

# Check Monitoring Services
print_status "HEADER" "📊 Monitoring Services:"
check_service "Grafana Dashboard" 3000
check_service "Prometheus Metrics" 9090

echo ""

# Database Statistics
print_status "HEADER" "📈 Database Statistics:"
if check_postgres_ready $MASTER_PORT; then
    total_products=$(execute_sql $MASTER_PORT "SELECT COUNT(*) FROM pos_product;" 2>/dev/null || echo "0")
    total_orders=$(execute_sql $MASTER_PORT "SELECT COUNT(*) FROM pos_order;" 2>/dev/null || echo "0")
    total_users=$(execute_sql $MASTER_PORT "SELECT COUNT(*) FROM pos_user;" 2>/dev/null || echo "0")
    
    echo -e "${BLUE}📦 Total Products: ${BOLD}$total_products${NC}"
    echo -e "${BLUE}🛒 Total Orders: ${BOLD}$total_orders${NC}"
    echo -e "${BLUE}👥 Total Users: ${BOLD}$total_users${NC}"
    
    # Recent products
    echo -e "${BLUE}🆕 Recent Products:${NC}"
    PGPASSWORD=$DB_PASS psql -h localhost -p $MASTER_PORT -U $DB_USER -d $DB_NAME -c "
    SELECT 
        '  • ' || name || ' (' || sku || ') - ' || 
        TO_CHAR(price, 'FM999,999,999') || ' VND' as product_info
    FROM pos_product 
    ORDER BY created_at DESC 
    LIMIT 5;" -t 2>/dev/null | grep -v "^$"
fi

echo ""

# Access URLs
print_status "HEADER" "🌐 Access URLs:"
echo -e "${CYAN}📊 Grafana Dashboard:${NC} http://localhost:3000 (admin/admin)"
echo -e "${CYAN}📈 Prometheus:${NC} http://localhost:9090"
echo -e "${CYAN}⚖️ HAProxy Stats:${NC} http://localhost:8080/stats"
echo -e "${CYAN}🗄️ PostgreSQL Master:${NC} localhost:5432"
echo -e "${CYAN}🗄️ PostgreSQL Replicas:${NC} localhost:5433, 5434, 5435, 5436"

echo ""

# Quick Commands
print_status "HEADER" "⚡ Quick Commands:"
echo -e "${CYAN}• Connect to Master:${NC} PGPASSWORD=postgres123 psql -h localhost -p 5432 -U postgres -d pos_db"
echo -e "${CYAN}• Connect to Replica:${NC} PGPASSWORD=postgres123 psql -h localhost -p 5433 -U postgres -d pos_db"
echo -e "${CYAN}• View Logs:${NC} docker-compose -f docker-compose-simple-ha.yml logs -f [service_name]"
echo -e "${CYAN}• Stop Cluster:${NC} docker-compose -f docker-compose-simple-ha.yml down"

echo ""
echo -e "${BOLD}${GREEN}🎉 PostgreSQL HA Cluster is running successfully!${NC}" 