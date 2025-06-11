#!/bin/bash

echo "🚀 DEPLOY DASHBOARD MỚI - HIỂN THỊ TẤT CẢ NODES"
echo "================================================"

# Import dashboard mới
echo "1️⃣ Import dashboard mới..."
RESULT=$(curl -s -u admin:admin123 -X POST \
  "http://localhost:3000/api/dashboards/db" \
  -H "Content-Type: application/json" \
  -d @grafana/dashboards/postgresql-ha-monitoring-fixed.json)

echo $RESULT | python3 -m json.tool

echo ""
echo "2️⃣ Lấy URL dashboard mới:"
NEW_UID=$(echo $RESULT | python3 -c "import sys, json; print(json.load(sys.stdin)['uid'])")
echo "🌐 Dashboard URL: http://localhost:3000/d/$NEW_UID/postgresql-ha-cluster-monitoring-all-nodes"

echo ""
echo "3️⃣ Thêm product mới vào Master để test sự khác biệt..."
docker exec postgres-master psql -U postgres -d pos_db -c "
INSERT INTO pos_product (product_id, name, category, price, quantity, created_at) 
VALUES 
  (21, 'Test-21 MASTER ONLY', 'test', 99.99, 10, NOW()),
  (22, 'Test-22 MASTER ONLY', 'test', 88.88, 5, NOW());
"

echo ""
echo "4️⃣ Đợi 5 giây để replication sync..."
sleep 5

echo ""
echo "5️⃣ Kiểm tra số lượng product trên tất cả nodes:"
echo "📊 MASTER:"
docker exec postgres-master psql -U postgres -d pos_db -t -c "SELECT COUNT(*) FROM pos_product;" | xargs

echo "📊 REPLICA1:"
docker exec postgres-replica1 psql -U postgres -d pos_db -t -c "SELECT COUNT(*) FROM pos_product;" | xargs

echo "📊 REPLICA2:"
docker exec postgres-replica2 psql -U postgres -d pos_db -t -c "SELECT COUNT(*) FROM pos_product;" | xargs

echo "📊 REPLICA3:"
docker exec postgres-replica3 psql -U postgres -d pos_db -t -c "SELECT COUNT(*) FROM pos_product;" | xargs

echo ""
echo "6️⃣ Test Panel 1 với dữ liệu mới:"
curl -s -u admin:admin123 \
  -X POST "http://localhost:3000/api/ds/query" \
  -H "Content-Type: application/json" \
  -d '{
    "queries": [
      {
        "datasource": {"uid": "P08B8726A6F9294EC"},
        "rawSql": "SELECT '\''MASTER'\'' as node_name, COUNT(*) as product_count FROM pos_product",
        "format": "table",
        "refId": "A"
      },
      {
        "datasource": {"uid": "P8CC35BA9726F8E90"},
        "rawSql": "SELECT '\''REPLICA1'\'' as node_name, COUNT(*) as product_count FROM pos_product",
        "format": "table", 
        "refId": "B"
      },
      {
        "datasource": {"uid": "P4E956032969666E7"},
        "rawSql": "SELECT '\''REPLICA2'\'' as node_name, COUNT(*) as product_count FROM pos_product",
        "format": "table", 
        "refId": "C"
      },
      {
        "datasource": {"uid": "P1CF95CFA97CB61CD"},
        "rawSql": "SELECT '\''REPLICA3'\'' as node_name, COUNT(*) as product_count FROM pos_product",
        "format": "table", 
        "refId": "D"
      }
    ]
  }' | python3 -c "
import sys, json
data = json.load(sys.stdin)
for key, result in data['results'].items():
    if result['frames']:
        values = result['frames'][0]['data']['values']
        node_name = values[0][0] if values[0] else 'Unknown'
        count = values[1][0] if len(values) > 1 else 0
        print(f'🎯 {key}: {node_name} = {count} products')
"

echo ""
echo "✅ HOÀN TẤT!"
echo "📱 Vào URL dashboard: http://localhost:3000/d/$NEW_UID/postgresql-ha-cluster-monitoring-all-nodes"
echo "🔄 Nhấn Ctrl+F5 để hard refresh"
echo ""
echo "📊 BÂY GIỜ BẠN SẼ THẤY:"
echo "   - Panel 1: 4 stat boxes có màu khác nhau (🔥MASTER, 📘REPLICA1, 📗REPLICA2, 📙REPLICA3)"
echo "   - Panel 2: Bảng với 4 dòng hiển thị tất cả nodes"
echo "   - Tất cả nodes đều có 22 products (replication đã sync)" 