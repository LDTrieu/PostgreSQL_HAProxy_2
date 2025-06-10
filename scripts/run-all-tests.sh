#!/bin/bash

# PostgreSQL HA Cluster Menu-Driven Test Runner
# Complete testing suite với interactive menu

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
MAGENTA='\033[0;95m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

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
    clear
    echo -e "${MAGENTA}"
    echo "╔═══════════════════════════════════════════════════════════════════════════════════════╗"
    echo "║                      POSTGRESQL HA CLUSTER - TEST SUITE MENU                         ║"
    echo "╚═══════════════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

show_banner() {
    echo -e "${PURPLE}"
    cat << "EOF"
    ____            __                 _____ ____    __ 
   / __ \____  ____/ /_____ ________  / ___// __ \  / / 
  / /_/ / __ \/ __  / ___/ // ___/ _ \ \__ \/ / / / / /  
 / ____/ /_/ / /_/ / /  / __(__  )  __/___/ / /_/ / / /___
/_/    \____/\__,_/_/   \___/____/\___/____/\___\_\/_____/
                                                         
        HIGH AVAILABILITY CLUSTER TESTING SUITE        
EOF
    echo -e "${NC}"
}

# Check prerequisites
check_prerequisites() {
    log "🔍 Checking prerequisites..."
    
    # Check if Docker is running
    if ! docker info > /dev/null 2>&1; then
        error "Docker is not running or accessible"
        return 1
    fi
    
    # Check if docker-compose is available
    if ! command -v docker-compose > /dev/null 2>&1; then
        error "docker-compose is not installed or not in PATH"
        return 1
    fi
    
    # Check if psql is available
    if ! command -v psql > /dev/null 2>&1; then
        error "PostgreSQL client (psql) is not installed"
        warning "Install with: sudo apt-get install postgresql-client"
        return 1
    fi
    
    # Check if required files exist
    local required_files=(
        "$PROJECT_ROOT/docker-compose-simple-ha.yml"
        "$SCRIPT_DIR/test-ha-features.sh"
        "$SCRIPT_DIR/manual-ha-demo.sh"
        "$SCRIPT_DIR/cluster-health-check.sh"
    )
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            error "Required file not found: $file"
            return 1
        fi
    done
    
    success "All prerequisites met"
    return 0
}

# Show cluster status
show_cluster_status() {
    log "📊 Current cluster status:"
    
    echo -e "\n${CYAN}🐳 Docker Containers:${NC}"
    if docker-compose -f "$PROJECT_ROOT/docker-compose-simple-ha.yml" ps 2>/dev/null; then
        echo ""
    else
        warning "Cluster is not running"
    fi
    
    echo -e "${CYAN}🔗 Service URLs:${NC}"
    echo "  • Grafana Dashboard: http://localhost:3000 (admin/admin123)"
    echo "  • Prometheus: http://localhost:9090"  
    echo "  • HAProxy Stats: http://localhost:8080/stats"
    echo "  • PostgreSQL Master: localhost:5432"
    echo "  • PostgreSQL Replicas: localhost:5433, 5434, 5435"
    echo "  • HAProxy Write: localhost:5439"
    echo "  • HAProxy Read: localhost:5440"
}

# Start cluster
start_cluster() {
    header
    log "🚀 Starting PostgreSQL HA Cluster..."
    
    cd "$PROJECT_ROOT"
    
    log "Pulling latest images..."
    docker-compose -f docker-compose-simple-ha.yml pull
    
    log "Starting all services..."
    docker-compose -f docker-compose-simple-ha.yml up -d
    
    log "Waiting for services to be ready (this may take a few minutes)..."
    sleep 30
    
    success "Cluster started successfully!"
    show_cluster_status
    
    echo -e "\n${YELLOW}Press Enter to return to menu...${NC}"
    read -r
}

# Stop cluster
stop_cluster() {
    header
    log "🛑 Stopping PostgreSQL HA Cluster..."
    
    cd "$PROJECT_ROOT"
    docker-compose -f docker-compose-simple-ha.yml down
    
    success "Cluster stopped successfully!"
    
    echo -e "\n${YELLOW}Press Enter to return to menu...${NC}"
    read -r
}

# Clean cluster (with volumes)
clean_cluster() {
    header
    warning "⚠️  This will remove all data including volumes!"
    echo -e "${RED}Are you sure you want to proceed? (y/N):${NC}"
    read -r confirm
    
    if [[ $confirm =~ ^[Yy]$ ]]; then
        log "🧹 Cleaning PostgreSQL HA Cluster (including volumes)..."
        
        cd "$PROJECT_ROOT"
        docker-compose -f docker-compose-simple-ha.yml down --volumes --remove-orphans
        docker system prune -f
        
        success "Cluster cleaned successfully!"
    else
        info "Operation cancelled"
    fi
    
    echo -e "\n${YELLOW}Press Enter to return to menu...${NC}"
    read -r
}

# Run comprehensive automated tests
run_comprehensive_tests() {
    header
    log "🧪 Running Comprehensive Automated Tests..."
    
    if [ ! -f "$SCRIPT_DIR/test-ha-features.sh" ]; then
        error "test-ha-features.sh not found"
        return 1
    fi
    
    chmod +x "$SCRIPT_DIR/test-ha-features.sh"
    bash "$SCRIPT_DIR/test-ha-features.sh"
    
    echo -e "\n${YELLOW}Press Enter to return to menu...${NC}"
    read -r
}

# Run interactive demo
run_interactive_demo() {
    header
    log "🎯 Starting Interactive Demo..."
    
    if [ ! -f "$SCRIPT_DIR/manual-ha-demo.sh" ]; then
        error "manual-ha-demo.sh not found"
        return 1
    fi
    
    chmod +x "$SCRIPT_DIR/manual-ha-demo.sh"
    bash "$SCRIPT_DIR/manual-ha-demo.sh"
    
    echo -e "\n${YELLOW}Press Enter to return to menu...${NC}"
    read -r
}

# Run health monitor
run_health_monitor() {
    header
    log "🏥 Starting Real-time Health Monitor..."
    
    if [ ! -f "$SCRIPT_DIR/cluster-health-check.sh" ]; then
        error "cluster-health-check.sh not found"
        return 1
    fi
    
    chmod +x "$SCRIPT_DIR/cluster-health-check.sh"
    bash "$SCRIPT_DIR/cluster-health-check.sh"
    
    echo -e "\n${YELLOW}Press Enter to return to menu...${NC}"
    read -r
}

# Run single health check
run_single_health_check() {
    header
    log "🔍 Performing Single Health Check..."
    
    if [ ! -f "$SCRIPT_DIR/cluster-health-check.sh" ]; then
        error "cluster-health-check.sh not found"
        return 1
    fi
    
    chmod +x "$SCRIPT_DIR/cluster-health-check.sh"
    bash "$SCRIPT_DIR/cluster-health-check.sh" --single
    
    echo -e "\n${YELLOW}Press Enter to return to menu...${NC}"
    read -r
}

# Quick database operations
run_quick_db_operations() {
    header
    log "📊 Quick Database Operations..."
    
    echo -e "${CYAN}Choose operation:${NC}"
    echo "1. Insert sample products"
    echo "2. Show product count on all nodes"
    echo "3. Show replication status"
    echo "4. Test HAProxy connections"
    echo "5. Return to main menu"
    
    echo -e "\n${YELLOW}Enter your choice (1-5):${NC}"
    read -r choice
    
    case $choice in
        1)
            log "Inserting sample products..."
            PGPASSWORD=postgres123 psql -h localhost -p 5432 -U postgres -d pos_db -c "
                INSERT INTO pos_product (name, description, price, category_id, sku, is_available, created_by) 
                VALUES 
                ('Quick Test $(date +%s)', 'Quick test product', 99000, 1, 'QUICK-$(date +%s)', true, 1),
                ('Quick Test 2 $(date +%s)', 'Another quick test product', 88000, 1, 'QUICK2-$(date +%s)', true, 1);
            "
            success "Sample products inserted!"
            ;;
        2)
            log "Product count on all nodes:"
            for port in 5432 5433 5434 5435; do
                local count=$(PGPASSWORD=postgres123 psql -h localhost -p $port -U postgres -d pos_db -t -c "SELECT COUNT(*) FROM pos_product;" 2>/dev/null | xargs || echo "N/A")
                echo "  Port $port: $count products"
            done
            ;;
        3)
            log "Replication status:"
            PGPASSWORD=postgres123 psql -h localhost -p 5432 -U postgres -d pos_db -c "SELECT * FROM pg_stat_replication;"
            ;;
        4)
            log "Testing HAProxy connections..."
            echo "Testing write port (5439):"
            if PGPASSWORD=postgres123 psql -h localhost -p 5439 -U postgres -d pos_db -c "SELECT 1;" > /dev/null 2>&1; then
                success "Write port accessible"
            else
                error "Write port not accessible"
            fi
            echo "Testing read port (5440):"
            if PGPASSWORD=postgres123 psql -h localhost -p 5440 -U postgres -d pos_db -c "SELECT 1;" > /dev/null 2>&1; then
                success "Read port accessible"
            else
                error "Read port not accessible"
            fi
            ;;
        5)
            return
            ;;
        *)
            error "Invalid choice"
            ;;
    esac
    
    echo -e "\n${YELLOW}Press Enter to continue...${NC}"
    read -r
    run_quick_db_operations
}

# Show logs
show_logs() {
    header
    log "📋 Cluster Logs..."
    
    echo -e "${CYAN}Choose service:${NC}"
    echo "1. PostgreSQL Master"
    echo "2. PostgreSQL Replica 1"
    echo "3. PostgreSQL Replica 2" 
    echo "4. PostgreSQL Replica 3"
    echo "5. HAProxy"
    echo "6. Grafana"
    echo "7. Prometheus"
    echo "8. All services"
    echo "9. Return to main menu"
    
    echo -e "\n${YELLOW}Enter your choice (1-9):${NC}"
    read -r choice
    
    cd "$PROJECT_ROOT"
    
    case $choice in
        1) docker-compose -f docker-compose-simple-ha.yml logs postgres-master ;;
        2) docker-compose -f docker-compose-simple-ha.yml logs postgres-replica1 ;;
        3) docker-compose -f docker-compose-simple-ha.yml logs postgres-replica2 ;;
        4) docker-compose -f docker-compose-simple-ha.yml logs postgres-replica3 ;;
        5) docker-compose -f docker-compose-simple-ha.yml logs haproxy ;;
        6) docker-compose -f docker-compose-simple-ha.yml logs grafana ;;
        7) docker-compose -f docker-compose-simple-ha.yml logs prometheus ;;
        8) docker-compose -f docker-compose-simple-ha.yml logs ;;
        9) return ;;
        *) error "Invalid choice" ;;
    esac
    
    if [ $choice -ne 9 ]; then
        echo -e "\n${YELLOW}Press Enter to return to menu...${NC}"
        read -r
    fi
}

# Main menu
show_main_menu() {
    header
    show_banner
    
    echo -e "${CYAN}📋 MAIN MENU - Choose an option:${NC}"
    echo ""
    echo -e "${GREEN}🚀 CLUSTER MANAGEMENT:${NC}"
    echo "  1. Start HA Cluster"
    echo "  2. Stop HA Cluster"
    echo "  3. Clean Cluster (remove volumes)"
    echo "  4. Show Cluster Status"
    echo ""
    echo -e "${GREEN}🧪 TESTING SUITE:${NC}"
    echo "  5. Run Comprehensive Automated Tests"
    echo "  6. Run Interactive Step-by-step Demo"
    echo "  7. Start Real-time Health Monitor"
    echo "  8. Single Health Check"
    echo ""
    echo -e "${GREEN}📊 DATABASE OPERATIONS:${NC}"
    echo "  9. Quick Database Operations"
    echo " 10. Show Service Logs"
    echo ""
    echo -e "${GREEN}🔧 UTILITIES:${NC}"
    echo " 11. Check Prerequisites"
    echo " 12. Open Web Interfaces"
    echo ""
    echo -e "${RED}❌ EXIT:${NC}"
    echo " 13. Exit"
    echo ""
    echo -e "${YELLOW}Enter your choice (1-13):${NC}"
}

# Open web interfaces
open_web_interfaces() {
    header
    log "🌐 Opening Web Interfaces..."
    
    echo -e "${CYAN}Available web interfaces:${NC}"
    echo "• Grafana Dashboard: http://localhost:3000 (admin/admin123)"
    echo "• Prometheus: http://localhost:9090"
    echo "• HAProxy Stats: http://localhost:8080/stats"
    
    if command -v xdg-open > /dev/null 2>&1; then
        log "Opening interfaces in browser..."
        xdg-open "http://localhost:3000" > /dev/null 2>&1 &
        sleep 2
        xdg-open "http://localhost:9090" > /dev/null 2>&1 &
        sleep 2
        xdg-open "http://localhost:8080/stats" > /dev/null 2>&1 &
        success "Web interfaces opened!"
    else
        info "Please open the URLs manually in your browser"
    fi
    
    echo -e "\n${YELLOW}Press Enter to return to menu...${NC}"
    read -r
}

# Main execution loop
main() {
    # Check prerequisites once at startup
    if ! check_prerequisites; then
        error "Prerequisites check failed. Please fix the issues and try again."
        exit 1
    fi
    
    while true; do
        show_main_menu
        read -r choice
        
        case $choice in
            1)  start_cluster ;;
            2)  stop_cluster ;;
            3)  clean_cluster ;;
            4)  header; show_cluster_status; echo -e "\n${YELLOW}Press Enter to return to menu...${NC}"; read -r ;;
            5)  run_comprehensive_tests ;;
            6)  run_interactive_demo ;;
            7)  run_health_monitor ;;
            8)  run_single_health_check ;;
            9)  run_quick_db_operations ;;
            10) show_logs ;;
            11) header; check_prerequisites; echo -e "\n${YELLOW}Press Enter to return to menu...${NC}"; read -r ;;
            12) open_web_interfaces ;;
            13) 
                header
                success "🙏 Thank you for using PostgreSQL HA Cluster Test Suite!"
                log "Goodbye!"
                exit 0
                ;;
            *)
                error "Invalid choice. Please enter a number between 1-13."
                sleep 2
                ;;
        esac
    done
}

# Handle script interruption
trap 'echo -e "\n${YELLOW}Script interrupted by user${NC}"; exit 0' INT

# Execute main function
main "$@" 