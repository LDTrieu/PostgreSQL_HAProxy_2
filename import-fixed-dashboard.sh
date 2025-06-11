#!/bin/bash

echo "🔧 IMPORTING FIXED DASHBOARD VỚI LOGIC XỬ LÝ ĐÚNG"
echo "================================================="

# Import dashboard using Grafana API
curl -X POST \
  http://admin:admin@localhost:3000/api/dashboards/db \
  -H "Content-Type: application/json" \
  -d @grafana/dashboards/postgresql-ha-pos-order-fixed.json

echo ""
echo "✅ Dashboard đã được import thành công!"
echo "🌐 Mở Grafana: http://localhost:3000"
echo "📊 Dashboard: PostgreSQL HA Cluster - POS Order (Fixed)"
echo ""
echo "🔍 KHÁC BIỆT CHÍNH:"
echo "   ✅ Query trực tiếp PostgreSQL để check role THỰC TẾ"
echo "   ✅ Hiển thị 'CONNECTION FAILED' khi master down"
echo "   ✅ Panel Docker Status riêng biệt"
echo "   ✅ Detect NEW-MASTER sau failover" 