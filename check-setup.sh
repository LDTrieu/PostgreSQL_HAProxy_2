#!/bin/bash

# PostgreSQL HA Cluster Setup Verification Script

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 PostgreSQL HA Cluster Setup Verification${NC}"
echo "=============================================="

# Check required files
files_to_check=(
    "docker-compose-simple-ha.yml"
    "config/haproxy-simple.cfg"
    "scripts/master-init.sql"
    "scripts/run-all-tests.sh"
    "scripts/test-ha-features.sh"
    "scripts/manual-ha-demo.sh"
    "scripts/cluster-health-check.sh"
    "prometheus/prometheus.yml"
    "grafana/datasources/datasource.yml"
    "grafana/dashboards/postgresql-ha.json"
    "grafana/dashboards/dashboard.yml"
    "README.md"
)

echo -e "\n${YELLOW}📁 Checking required files...${NC}"
missing_files=0
for file in "${files_to_check[@]}"; do
    if [ -f "$file" ]; then
        echo -e "  ✅ $file"
    else
        echo -e "  ❌ $file ${RED}(MISSING)${NC}"
        ((missing_files++))
    fi
done

# Check directories
directories_to_check=(
    "data"
    "data/master"
    "data/replica1"
    "data/replica2"
    "data/replica3"
    "config"
    "scripts"
    "prometheus"
    "grafana"
    "grafana/datasources"
    "grafana/dashboards"
)

echo -e "\n${YELLOW}📂 Checking directories...${NC}"
missing_dirs=0
for dir in "${directories_to_check[@]}"; do
    if [ -d "$dir" ]; then
        echo -e "  ✅ $dir/"
    else
        echo -e "  ❌ $dir/ ${RED}(MISSING)${NC}"
        ((missing_dirs++))
    fi
done

# Check script permissions
echo -e "\n${YELLOW}🔧 Checking script permissions...${NC}"
script_files=(
    "scripts/run-all-tests.sh"
    "scripts/test-ha-features.sh"
    "scripts/manual-ha-demo.sh"
    "scripts/cluster-health-check.sh"
)

permission_issues=0
for script in "${script_files[@]}"; do
    if [ -x "$script" ]; then
        echo -e "  ✅ $script (executable)"
    elif [ -f "$script" ]; then
        echo -e "  ⚠️  $script ${YELLOW}(not executable - will fix)${NC}"
        chmod +x "$script"
        echo -e "  ✅ $script (fixed)"
    else
        echo -e "  ❌ $script ${RED}(missing)${NC}"
        ((permission_issues++))
    fi
done

# Check prerequisites
echo -e "\n${YELLOW}🔍 Checking prerequisites...${NC}"
prereq_issues=0

# Docker
if command -v docker >/dev/null 2>&1; then
    if docker info >/dev/null 2>&1; then
        echo -e "  ✅ Docker (running)"
    else
        echo -e "  ⚠️  Docker ${YELLOW}(installed but not running)${NC}"
        ((prereq_issues++))
    fi
else
    echo -e "  ❌ Docker ${RED}(not installed)${NC}"
    ((prereq_issues++))
fi

# Docker Compose
if command -v docker-compose >/dev/null 2>&1; then
    echo -e "  ✅ Docker Compose"
else
    echo -e "  ❌ Docker Compose ${RED}(not installed)${NC}"
    ((prereq_issues++))
fi

# PostgreSQL Client
if command -v psql >/dev/null 2>&1; then
    echo -e "  ✅ PostgreSQL Client (psql)"
else
    echo -e "  ❌ PostgreSQL Client ${RED}(not installed)${NC}"
    echo -e "     Install with: ${BLUE}sudo apt-get install postgresql-client${NC}"
    ((prereq_issues++))
fi

# Summary
echo -e "\n${BLUE}📋 SETUP VERIFICATION SUMMARY${NC}"
echo "================================"

total_issues=$((missing_files + missing_dirs + permission_issues + prereq_issues))

if [ $total_issues -eq 0 ]; then
    echo -e "${GREEN}🎉 PERFECT SETUP! All files, directories, and prerequisites are ready.${NC}"
    echo ""
    echo -e "${GREEN}✅ Ready to start PostgreSQL HA Cluster!${NC}"
    echo ""
    echo -e "${YELLOW}🚀 To begin, run:${NC}"
    echo -e "   ${BLUE}./scripts/run-all-tests.sh${NC}"
    echo ""
    echo -e "${YELLOW}📖 Or read the README.md for detailed instructions${NC}"
else
    echo -e "${RED}⚠️  SETUP ISSUES DETECTED:${NC}"
    [ $missing_files -gt 0 ] && echo -e "   • $missing_files missing files"
    [ $missing_dirs -gt 0 ] && echo -e "   • $missing_dirs missing directories"
    [ $permission_issues -gt 0 ] && echo -e "   • $permission_issues permission issues"
    [ $prereq_issues -gt 0 ] && echo -e "   • $prereq_issues prerequisite issues"
    echo ""
    echo -e "${YELLOW}Please fix these issues before proceeding.${NC}"
fi

echo ""
echo -e "${BLUE}For help, check README.md or run: ./scripts/run-all-tests.sh${NC}" 