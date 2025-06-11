#!/bin/bash

echo "🧪 TEST SỰ KHÁC BIỆT REALTIME GIỮA CÁC NODES"
echo "================================================"
echo "📱 Mở dashboard: http://localhost:3000/d/2ef8ea41-c03c-4629-b1b7-19f288e70796/postgresql-ha-cluster-monitoring-all-nodes"
echo "⏱️  Script này sẽ thêm product mới mỗi 10 giây để bạn thấy số liệu thay đổi realtime"
echo ""

COUNTER=24
while true; do
    echo "⏰ $(date '+%H:%M:%S') - Thêm product #$COUNTER..."
    
    docker exec postgres-master psql -U postgres -d pos_db -c "
    INSERT INTO pos_product (name, description, price, category_id, sku, is_available, created_at) 
    VALUES ('Product-$COUNTER', 'Auto generated product', $(echo $COUNTER*1.1 | bc), 1, 'SKU-$COUNTER', true, NOW());
    " > /dev/null
    
    sleep 2
    
    echo "📊 Số lượng hiện tại:"
    echo "   🔥 MASTER:   $(docker exec postgres-master psql -U postgres -d pos_db -t -c "SELECT COUNT(*) FROM pos_product;" | xargs)"
    echo "   📘 REPLICA1: $(docker exec postgres-replica1 psql -U postgres -d pos_db -t -c "SELECT COUNT(*) FROM pos_product;" | xargs)"
    echo "   📗 REPLICA2: $(docker exec postgres-replica2 psql -U postgres -d pos_db -t -c "SELECT COUNT(*) FROM pos_product;" | xargs)"
    echo "   📙 REPLICA3: $(docker exec postgres-replica3 psql -U postgres -d pos_db -t -c "SELECT COUNT(*) FROM pos_product;" | xargs)"
    
    echo "⏳ Đợi 8 giây trước khi thêm tiếp..."
    sleep 8
    
    COUNTER=$((COUNTER + 1))
    
    if [ $COUNTER -gt 30 ]; then
        echo "🛑 Dừng test tại 30 products"
        break
    fi
done

echo ""
echo "✅ HOÀN THÀNH! Refresh dashboard để thấy số liệu mới nhất." 