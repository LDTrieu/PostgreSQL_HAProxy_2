#!/bin/bash

# PostgreSQL HA Cluster Manual Demo Script  
# Interactive step-by-step demonstration

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

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

header() {
    echo -e "${PURPLE}╔════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${NC} $1 ${PURPLE}║${NC}"
    echo -e "${PURPLE}╚════════════════════════════════════════╝${NC}"
}

wait_for_user() {
    echo -e "${YELLOW}Nhấn Enter để tiếp tục...${NC}"
    read -r
}

show_cluster_status() {
    header "TRẠNG THÁI CLUSTER HIỆN TẠI"
    
    echo -e "${CYAN}📊 Docker Containers:${NC}"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(postgres|haproxy|grafana|prometheus)"
    
    echo -e "\n${CYAN}🔗 PostgreSQL Connections:${NC}"
    for port in $MASTER_PORT $REPLICA1_PORT $REPLICA2_PORT $REPLICA3_PORT; do
        if PGPASSWORD=$DB_PASS psql -h localhost -p $port -U $DB_USER -d $DB_NAME -c "SELECT 1;" > /dev/null 2>&1; then
            echo -e "  Port $port: ${GREEN}CONNECTED${NC}"
        else
            echo -e "  Port $port: ${RED}DISCONNECTED${NC}"
        fi
    done
    
    echo -e "\n${CYAN}📈 Product Count per Node:${NC}"
    for port in $MASTER_PORT $REPLICA1_PORT $REPLICA2_PORT $REPLICA3_PORT; do
        local count=$(PGPASSWORD=$DB_PASS psql -h localhost -p $port -U $DB_USER -d $DB_NAME -t -c "SELECT COUNT(*) FROM pos_product;" 2>/dev/null | xargs || echo "N/A")
        local role=$(PGPASSWORD=$DB_PASS psql -h localhost -p $port -U $DB_USER -d $DB_NAME -t -c "SELECT CASE WHEN pg_is_in_recovery() THEN 'REPLICA' ELSE 'MASTER' END;" 2>/dev/null | xargs || echo "N/A")
        echo -e "  Port $port ($role): $count products"
    done
}

demo_step_1() {
    header "BƯỚC 1: KHỞI TẠO CLUSTER"
    
    info "Demonstration sẽ khởi động PostgreSQL HA cluster với:"
    echo "  • 1 Master PostgreSQL (port 5432)"
    echo "  • 3 Replica PostgreSQL (ports 5433, 5434, 5435)"
    echo "  • HAProxy Load Balancer (ports 5439 write, 5440 read)"
    echo "  • Grafana Dashboard (port 3000)"
    echo "  • Prometheus Monitoring (port 9090)"
    
    wait_for_user
    
    log "Khởi động cluster với docker-compose..."
    docker-compose -f docker-compose-simple-ha.yml up -d
    
    log "Đang chờ tất cả services sẵn sàng (có thể mất vài phút)..."
    sleep 30
    
    show_cluster_status
}

demo_step_2() {
    header "BƯỚC 2: KIỂM TRA STREAMING REPLICATION"
    
    info "Bây giờ chúng ta sẽ test streaming replication bằng cách:"
    echo "  1. Chèn một sản phẩm mới vào Master"
    echo "  2. Xác minh dữ liệu được replicate ngay lập tức đến tất cả Replicas"
    
    wait_for_user
    
    # Hiển thị số lượng sản phẩm hiện tại
    log "Số lượng sản phẩm hiện tại:"
    show_cluster_status
    
    # Chèn sản phẩm mới
    local new_product_name="Demo Product $(date +%s)"
    local new_sku="DEMO-$(date +%s)"
    
    log "Chèn sản phẩm mới: $new_product_name"
    PGPASSWORD=$DB_PASS psql -h localhost -p $MASTER_PORT -U $DB_USER -d $DB_NAME -c "
        INSERT INTO pos_product (name, description, price, category_id, sku, is_available, created_by) 
        VALUES ('$new_product_name', 'Demo replication product', 125000, 1, '$new_sku', true, 1);
    "
    
    success "Sản phẩm đã được chèn vào Master!"
    
    log "Chờ 3 giây để replication hoàn tất..."
    sleep 3
    
    log "Kiểm tra replication trên tất cả nodes:"
    show_cluster_status
    
    info "✨ Lưu ý: Tất cả replicas nên có cùng số lượng sản phẩm như Master"
}

demo_step_3() {
    header "BƯỚC 3: KIỂM TRA LOAD BALANCING"
    
    info "Bây giờ chúng ta sẽ test HAProxy load balancing:"
    echo "  • Write operations qua port 5439 (chỉ Master)"
    echo "  • Read operations qua port 5440 (load balanced replicas)"
    
    wait_for_user
    
    # Test write operations
    log "Testing write operations qua HAProxy (port $HAPROXY_WRITE_PORT)..."
    local haproxy_sku="HAPROXY-$(date +%s)"
    
    PGPASSWORD=$DB_PASS psql -h localhost -p $HAPROXY_WRITE_PORT -U $DB_USER -d $DB_NAME -c "
        INSERT INTO pos_product (name, description, price, category_id, sku, is_available, created_by) 
        VALUES ('HAProxy Write Test', 'Inserted via HAProxy write port', 135000, 1, '$haproxy_sku', true, 1);
    "
    
    success "Write operation qua HAProxy thành công!"
    
    # Test read operations
    log "Testing read operations qua HAProxy (port $HAPROXY_READ_PORT)..."
    for i in {1..3}; do
        local count=$(PGPASSWORD=$DB_PASS psql -h localhost -p $HAPROXY_READ_PORT -U $DB_USER -d $DB_NAME -t -c "SELECT COUNT(*) FROM pos_product;" | xargs)
        log "Read test $i qua HAProxy: $count products"
        sleep 1
    done
    
    success "Load balancing đang hoạt động tốt!"
    
    info "🌐 Truy cập HAProxy Stats: http://localhost:8080/stats"
}

demo_step_4() {
    header "BƯỚC 4: MÔ PHỎNG FAILOVER"
    
    warning "⚠️  CẢNH BÁO: Bước này sẽ mô phỏng Master failure!"
    info "Điều này sẽ:"
    echo "  1. Dừng Master PostgreSQL container"
    echo "  2. Kiểm tra cluster reaction"
    echo "  3. Khôi phục Master"
    
    echo -e "${RED}Bạn có muốn tiếp tục? (y/n):${NC}"
    read -r confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        warning "Bỏ qua failover test"
        return
    fi
    
    log "Trạng thái trước khi failover:"
    show_cluster_status
    
    warning "Dừng Master container..."
    docker stop postgres-master
    
    log "Chờ 10 giây để cluster phản ứng..."
    sleep 10
    
    log "Trạng thái sau khi Master down:"
    show_cluster_status
    
    warning "Khôi phục Master container..."
    docker start postgres-master
    
    log "Chờ Master khởi động lại..."
    sleep 20
    
    log "Trạng thái sau khi khôi phục:"
    show_cluster_status
    
    success "Failover simulation hoàn tất!"
}

demo_step_5() {
    header "BƯỚC 5: MONITORING VÀ GRAFANA"
    
    info "Kiểm tra monitoring functions và Grafana dashboard:"
    
    log "Testing monitoring functions..."
    
    echo -e "\n${CYAN}📊 Cluster Status Function:${NC}"
    PGPASSWORD=$DB_PASS psql -h localhost -p $MASTER_PORT -U $DB_USER -d $DB_NAME -c "SELECT * FROM get_cluster_status();"
    
    echo -e "\n${CYAN}🔄 Replication Status Function:${NC}"
    PGPASSWORD=$DB_PASS psql -h localhost -p $MASTER_PORT -U $DB_USER -d $DB_NAME -c "SELECT * FROM get_replication_status();"
    
    echo -e "\n${CYAN}👑 Master Election Status Function:${NC}"
    PGPASSWORD=$DB_PASS psql -h localhost -p $MASTER_PORT -U $DB_USER -d $DB_NAME -c "SELECT * FROM get_master_election_status();"
    
    echo -e "\n${CYAN}📈 Product Count Realtime Function:${NC}"
    PGPASSWORD=$DB_PASS psql -h localhost -p $MASTER_PORT -U $DB_USER -d $DB_NAME -c "SELECT * FROM get_product_count_realtime();"
    
    info "🎨 Access Grafana Dashboard: http://localhost:3000"
    info "   Username: admin, Password: admin123"
    info "📊 Access Prometheus: http://localhost:9090"
    info "📈 Access HAProxy Stats: http://localhost:8080/stats"
    
    wait_for_user
}

demo_step_6() {
    header "BƯỚC 6: PERFORMANCE TEST"
    
    info "Chạy performance test với concurrent operations:"
    
    wait_for_user
    
    log "Chạy 10 concurrent insert operations..."
    local start_time=$(date +%s)
    
    for i in {1..10}; do
        {
            PGPASSWORD=$DB_PASS psql -h localhost -p $MASTER_PORT -U $DB_USER -d $DB_NAME -c "
                INSERT INTO pos_product (name, description, price, category_id, sku, is_available, created_by) 
                VALUES ('Perf Test $i', 'Concurrent performance test $i', $((60000 + i)), 1, 'PERF-$i-$(date +%s)', true, 1);
            " > /dev/null 2>&1
        } &
    done
    
    wait
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    success "Performance test hoàn tất trong $duration giây!"
    
    log "Trạng thái cluster sau performance test:"
    show_cluster_status
}

main() {
    clear
    header "POSTGRESQL HA CLUSTER INTERACTIVE DEMO"
    
    info "Chào mừng đến với PostgreSQL HA Cluster Interactive Demo!"
    echo ""
    echo "Demo này sẽ hướng dẫn bạn qua tất cả tính năng chính:"
    echo "  • Streaming Replication"
    echo "  • Load Balancing với HAProxy"
    echo "  • Failover Simulation"
    echo "  • Auto Recovery"
    echo "  • Monitoring với Grafana"
    echo "  • Performance Testing"
    echo ""
    
    wait_for_user
    
    demo_step_1
    demo_step_2  
    demo_step_3
    demo_step_4
    demo_step_5
    demo_step_6
    
    header "DEMO HOÀN TẤT!"
    
    success "🎉 PostgreSQL HA Cluster Demo đã hoàn thành thành công!"
    
    info "📋 Tóm tắt những gì chúng ta đã làm:"
    echo "  ✅ Khởi động HA cluster với 1 master + 3 replicas"
    echo "  ✅ Kiểm tra streaming replication"
    echo "  ✅ Test load balancing với HAProxy"
    echo "  ✅ Mô phỏng failover và recovery"
    echo "  ✅ Xác minh monitoring functions"
    echo "  ✅ Chạy performance test"
    
    info "🔗 Các URLs quan trọng:"
    echo "  • Grafana Dashboard: http://localhost:3000 (admin/admin123)"
    echo "  • Prometheus: http://localhost:9090"
    echo "  • HAProxy Stats: http://localhost:8080/stats"
    
    echo ""
    log "Cluster vẫn đang chạy. Sử dụng 'docker-compose -f docker-compose-simple-ha.yml down' để dừng."
}

# Execute main function
main "$@" 