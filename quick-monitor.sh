#!/bin/bash

# ============================================================================
# 🚀 Quick Monitor Commands - PostgreSQL HA
# Các lệnh nhanh để test và monitor cluster
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

case "${1:-}" in
    "kill-master"|"km")
        echo -e "${RED}🛑 STOPPING MASTER...${NC}"
        docker stop postgres-master
        echo ""
        echo -e "${YELLOW}📊 CLUSTER STATUS AFTER MASTER DOWN:${NC}"
        ./monitor-cluster-cli.sh roles
        ;;
        
    "revive-master"|"rm")
        echo -e "${GREEN}🚀 STARTING MASTER...${NC}"
        docker start postgres-master
        sleep 3
        echo ""
        echo -e "${YELLOW}📊 CLUSTER STATUS AFTER MASTER UP:${NC}"
        ./monitor-cluster-cli.sh roles
        ;;
        
    "promote-replica1"|"p1")
        echo -e "${RED}🔥 PROMOTING REPLICA1 TO MASTER...${NC}"
        docker exec postgres-replica1 psql -U postgres -c "SELECT pg_promote();"
        sleep 2
        echo ""
        echo -e "${YELLOW}📊 CLUSTER STATUS AFTER PROMOTION:${NC}"
        ./monitor-cluster-cli.sh roles
        ;;
        
    "status"|"s")
        ./monitor-cluster-cli.sh all
        ;;
        
    "roles"|"r")
        ./monitor-cluster-cli.sh roles
        ;;
        
    "watch"|"w")
        ./monitor-cluster-cli.sh watch
        ;;
        
    "test-failover"|"tf")
        echo -e "${YELLOW}🎯 TESTING COMPLETE FAILOVER SCENARIO...${NC}"
        echo "=================================================="
        
        echo ""
        echo -e "${BLUE}1️⃣ Initial cluster status:${NC}"
        ./monitor-cluster-cli.sh roles
        
        echo ""
        echo -e "${RED}2️⃣ Killing master...${NC}"
        docker stop postgres-master
        sleep 2
        
        echo ""
        echo -e "${YELLOW}3️⃣ Status after master down:${NC}"
        ./monitor-cluster-cli.sh roles
        
        echo ""
        echo -e "${GREEN}4️⃣ Promoting replica1 to master...${NC}"
        docker exec postgres-replica1 psql -U postgres -c "SELECT pg_promote();" 2>/dev/null || echo "Promotion may have failed"
        sleep 3
        
        echo ""
        echo -e "${YELLOW}5️⃣ Final cluster status:${NC}"
        ./monitor-cluster-cli.sh roles
        
        echo ""
        echo -e "${BLUE}6️⃣ Orders count check:${NC}"
        ./monitor-cluster-cli.sh orders
        ;;
        
    "insert-test"|"it")
        echo -e "${YELLOW}💾 INSERTING TEST ORDER...${NC}"
        # Try to insert to any available master
        if docker exec postgres-replica1 psql -U postgres -d pos_db -c "INSERT INTO pos_order (customer_name, total_amount) VALUES ('CLI Test Customer', 99.99);" 2>/dev/null; then
            echo -e "${GREEN}✅ Insert successful to replica1 (likely new master)${NC}"
        elif docker exec postgres-master psql -U postgres -d pos_db -c "INSERT INTO pos_order (customer_name, total_amount) VALUES ('CLI Test Customer', 99.99);" 2>/dev/null; then
            echo -e "${GREEN}✅ Insert successful to original master${NC}"
        else
            echo -e "${RED}❌ Insert failed to all nodes${NC}"
        fi
        echo ""
        ./monitor-cluster-cli.sh orders
        ;;
        
    "reset"|"reset-cluster")
        echo -e "${YELLOW}🔄 RESETTING CLUSTER TO ORIGINAL STATE...${NC}"
        echo "================================================="
        
        echo "🛑 Stopping all containers..."
        docker-compose -f docker-compose-simple-ha.yml down
        
        echo "🗑️ Cleaning up data..."
        sudo rm -rf data/postgres-*
        
        echo "🚀 Starting fresh cluster..."
        docker-compose -f docker-compose-simple-ha.yml up -d
        
        echo "⏳ Waiting for cluster to be ready..."
        sleep 10
        
        echo ""
        echo -e "${GREEN}✅ Cluster reset complete!${NC}"
        ./monitor-cluster-cli.sh roles
        ;;
        
    "help"|"h"|"")
        echo ""
        echo -e "${GREEN}🚀 Quick Monitor Commands${NC}"
        echo "=========================="
        echo ""
        echo -e "${YELLOW}FAILOVER TESTING:${NC}"
        echo "  kill-master, km     - Stop master container"
        echo "  revive-master, rm   - Start master container" 
        echo "  promote-replica1, p1 - Promote replica1 to master"
        echo "  test-failover, tf   - Complete failover test scenario"
        echo ""
        echo -e "${YELLOW}MONITORING:${NC}"
        echo "  status, s           - Full cluster status"
        echo "  roles, r            - Check PostgreSQL roles only"
        echo "  watch, w            - Continuous monitoring"
        echo ""
        echo -e "${YELLOW}TESTING:${NC}"
        echo "  insert-test, it     - Insert test order to check write capability"
        echo ""
        echo -e "${YELLOW}MAINTENANCE:${NC}"
        echo "  reset               - Reset cluster to original state"
        echo ""
        echo -e "${BLUE}EXAMPLES:${NC}"
        echo "  ./quick-monitor.sh tf           # Test complete failover"
        echo "  ./quick-monitor.sh km && sleep 5 && ./quick-monitor.sh p1"
        echo "  ./quick-monitor.sh w            # Watch cluster in real-time"
        echo ""
        ;;
        
    *)
        echo -e "${RED}❌ Unknown command: $1${NC}"
        echo "Use './quick-monitor.sh help' for available commands."
        exit 1
        ;;
esac 