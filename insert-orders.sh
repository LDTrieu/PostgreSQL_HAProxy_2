#!/bin/bash

# Script để insert 50 đơn hàng vào PostgreSQL HA cluster
# Sử dụng write endpoint để đảm bảo ghi vào master

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Configuration
WRITE_PORT=5439  # HAProxy write endpoint
DB_NAME="postgres"
DB_USER="postgres"
DB_PASS="postgres"
TABLE_NAME="pos_order"  # Tên bảng chính xác

# Danh sách sản phẩm mẫu
PRODUCTS=(
    "Laptop Dell XPS 13|1|25000000"
    "iPhone 15 Pro Max|2|35000000"
    "Samsung Galaxy S24|1|22000000"
    "MacBook Pro M3|1|45000000"
    "iPad Air|3|18000000"
    "AirPods Pro|2|6000000"
    "Apple Watch Series 9|1|12000000"
    "Sony WH-1000XM5|1|8000000"
    "Nintendo Switch OLED|2|9000000"
    "PlayStation 5|1|15000000"
    "Xbox Series X|1|14000000"
    "Monitor LG 27inch 4K|1|12000000"
    "Keyboard Logitech MX Keys|3|2500000"
    "Mouse Logitech MX Master|2|2000000"
    "Webcam Logitech C920|1|2500000"
    "SSD Samsung 1TB|2|3000000"
    "RAM Corsair 32GB|1|4000000"
    "GPU RTX 4070|1|18000000"
    "CPU Intel i7-13700K|1|12000000"
    "Motherboard ASUS ROG|1|8000000"
    "Tai nghe Gaming HyperX|1|3000000"
    "Bàn phím cơ Keychron|1|3500000"
    "Chuột gaming Razer|1|2500000"
    "Màn hình cong Samsung|1|15000000"
    "Loa Bluetooth JBL|2|1500000"
    "Ổ cứng WD 2TB|1|2000000"
    "USB-C Hub Anker|3|800000"
    "Sạc nhanh Anker 65W|2|1200000"
    "Cáp USB-C to Lightning|5|300000"
    "Case iPhone 15|4|500000"
    "Miếng dán màn hình|10|100000"
    "Giá đỡ laptop|1|800000"
    "Đèn LED gaming|1|1500000"
    "Ghế gaming DXRacer|1|8000000"
    "Bàn gaming|1|5000000"
    "Router WiFi 6 ASUS|1|3500000"
    "Switch mạng 8 port|1|1200000"
    "Camera IP Xiaomi|2|800000"
    "Smart TV Samsung 55inch|1|18000000"
    "Soundbar Sony|1|6000000"
    "Máy lọc không khí|1|4000000"
    "Robot hút bụi Xiaomi|1|8000000"
    "Máy pha cà phê Delonghi|1|12000000"
    "Nồi cơm điện Panasonic|1|2500000"
    "Máy xay sinh tố|1|1500000"
    "Bình giữ nhiệt Stanley|2|800000"
    "Túi laptop Targus|1|1200000"
    "Balo du lịch Samsonite|1|3500000"
    "Ví da nam|2|800000"
    "Đồng hồ thông minh Garmin|1|8000000"
)

echo -e "${BOLD}${GREEN}🚀 Bắt đầu insert 50 đơn hàng vào PostgreSQL HA Cluster${NC}"
echo -e "${YELLOW}📡 Kết nối tới Write Endpoint: localhost:${WRITE_PORT}${NC}"
echo ""

# Kiểm tra kết nối
echo -e "${BLUE}🔍 Kiểm tra kết nối database...${NC}"
if ! PGPASSWORD="$DB_PASS" psql -h localhost -p "$WRITE_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" >/dev/null 2>&1; then
    echo -e "${RED}❌ Không thể kết nối tới database!${NC}"
    echo -e "${YELLOW}💡 Hãy đảm bảo HAProxy và PostgreSQL đang chạy${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Kết nối database thành công!${NC}"
echo ""

# Đếm số đơn hàng hiện tại
CURRENT_COUNT=$(PGPASSWORD="$DB_PASS" psql -h localhost -p "$WRITE_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM ${TABLE_NAME};" 2>/dev/null | xargs)
echo -e "${BLUE}📊 Số đơn hàng hiện tại: ${CURRENT_COUNT}${NC}"
echo ""

# Bắt đầu insert
echo -e "${BOLD}${YELLOW}⚡ Bắt đầu insert 50 đơn hàng...${NC}"
echo ""

SUCCESS_COUNT=0
FAILED_COUNT=0

for i in {1..50}; do
    # Chọn ngẫu nhiên một sản phẩm
    RANDOM_INDEX=$((RANDOM % ${#PRODUCTS[@]}))
    PRODUCT_INFO="${PRODUCTS[$RANDOM_INDEX]}"
    
    IFS='|' read -r PRODUCT_NAME QUANTITY PRICE <<< "$PRODUCT_INFO"
    
    # Thêm một chút biến đổi cho quantity và price
    QUANTITY=$((QUANTITY + RANDOM % 3))
    PRICE_VARIATION=$((RANDOM % 1000000))
    FINAL_PRICE=$((PRICE + PRICE_VARIATION))
    
    # Insert đơn hàng
    SQL="INSERT INTO ${TABLE_NAME} (product_name, quantity, price) VALUES ('${PRODUCT_NAME}', ${QUANTITY}, ${FINAL_PRICE});"
    
    if PGPASSWORD="$DB_PASS" psql -h localhost -p "$WRITE_PORT" -U "$DB_USER" -d "$DB_NAME" -c "$SQL" >/dev/null 2>&1; then
        ((SUCCESS_COUNT++))
        echo -e "${GREEN}✅ [$i/50] ${PRODUCT_NAME} - ${QUANTITY} cái - ${FINAL_PRICE}đ${NC}"
    else
        ((FAILED_COUNT++))
        echo -e "${RED}❌ [$i/50] Lỗi insert: ${PRODUCT_NAME}${NC}"
    fi
    
    # Thêm delay nhỏ để tránh quá tải
    sleep 0.1
done

echo ""
echo -e "${BOLD}${GREEN}🎉 Hoàn thành insert đơn hàng!${NC}"
echo -e "${GREEN}✅ Thành công: ${SUCCESS_COUNT}/50${NC}"
if [[ $FAILED_COUNT -gt 0 ]]; then
    echo -e "${RED}❌ Thất bại: ${FAILED_COUNT}/50${NC}"
fi

# Đếm lại số đơn hàng sau khi insert
NEW_COUNT=$(PGPASSWORD="$DB_PASS" psql -h localhost -p "$WRITE_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM ${TABLE_NAME};" 2>/dev/null | xargs)
ADDED_COUNT=$((NEW_COUNT - CURRENT_COUNT))

echo ""
echo -e "${BLUE}📊 Tổng kết:${NC}"
echo -e "${BLUE}   • Đơn hàng trước: ${CURRENT_COUNT}${NC}"
echo -e "${BLUE}   • Đơn hàng sau: ${NEW_COUNT}${NC}"
echo -e "${BLUE}   • Đã thêm: ${ADDED_COUNT} đơn hàng${NC}"
echo ""

# Hiển thị 5 đơn hàng mới nhất
echo -e "${YELLOW}🔍 5 đơn hàng mới nhất:${NC}"
PGPASSWORD="$DB_PASS" psql -h localhost -p "$WRITE_PORT" -U "$DB_USER" -d "$DB_NAME" -c "
SELECT 
    id,
    product_name,
    quantity,
    to_char(price, 'FM999,999,999') || 'đ' as price,
    to_char(created_at, 'HH24:MI:SS') as time
FROM ${TABLE_NAME} 
ORDER BY id DESC 
LIMIT 5;
"

echo ""
echo -e "${GREEN}💡 Bây giờ bạn có thể chạy streaming monitor để xem data replication!${NC}"
echo -e "${YELLOW}   ./streaming-data-monitor.sh 1${NC}" 