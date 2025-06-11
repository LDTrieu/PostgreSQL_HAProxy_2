-- ======================================================
-- PostgreSQL HA Cluster - Master Initialization Script
-- Using pos_order table for demo
-- ======================================================

-- Create database
CREATE DATABASE pos_db;

-- Connect to the database
\c pos_db;

-- Create pos_order table (converted from MySQL to PostgreSQL)
CREATE TABLE pos_order (
    order_id SERIAL PRIMARY KEY,
    order_number VARCHAR(255) NOT NULL,
    order_type VARCHAR(255) NOT NULL,
    status_id INTEGER NOT NULL,
    pos_id INTEGER NOT NULL,
    address VARCHAR(255) DEFAULT NULL,
    description TEXT,
    total_amount DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    created_by INTEGER NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NULL
);

-- Create index for better performance
CREATE INDEX idx_pos_order_number ON pos_order(order_number);
CREATE INDEX idx_pos_order_status ON pos_order(status_id);
CREATE INDEX idx_pos_order_created_at ON pos_order(created_at);

-- Insert sample orders for HA testing
INSERT INTO pos_order (order_number, order_type, status_id, pos_id, address, description, total_amount, created_by, created_at) VALUES
('ORD-2025-001', 'DINE_IN', 1, 1, NULL, 'Combo burger + fries + drink', 125000.00, 1, NOW() - INTERVAL '5 days'),
('ORD-2025-002', 'TAKEAWAY', 1, 1, NULL, 'Pizza margherita large', 320000.00, 1, NOW() - INTERVAL '4 days'),
('ORD-2025-003', 'DELIVERY', 2, 2, '123 Nguyen Hue St, District 1, HCMC', 'Sushi combo for 2', 450000.00, 2, NOW() - INTERVAL '3 days'),
('ORD-2025-004', 'DINE_IN', 3, 1, NULL, 'Steak dinner with wine', 780000.00, 1, NOW() - INTERVAL '2 days'),
('ORD-2025-005', 'DELIVERY', 1, 3, '456 Le Loi St, District 3, HCMC', 'Pho bo special', 85000.00, 3, NOW() - INTERVAL '1 day'),
('ORD-2025-006', 'TAKEAWAY', 1, 2, NULL, 'Coffee and pastries', 150000.00, 2, NOW() - INTERVAL '12 hours'),
('ORD-2025-007', 'DINE_IN', 2, 1, NULL, 'Seafood hotpot for 4', 1200000.00, 1, NOW() - INTERVAL '6 hours'),
('ORD-2025-008', 'DELIVERY', 1, 3, '789 Tran Hung Dao St, District 5, HCMC', 'Banh mi combo', 65000.00, 3, NOW() - INTERVAL '3 hours'),
('ORD-2025-009', 'TAKEAWAY', 3, 2, NULL, 'Bubble tea and snacks', 95000.00, 2, NOW() - INTERVAL '1 hour'),
('ORD-2025-010', 'DINE_IN', 1, 1, NULL, 'BBQ ribs and beer', 350000.00, 1, NOW() - INTERVAL '30 minutes'),
('ORD-2025-011', 'DELIVERY', 2, 3, '321 Vo Van Tan St, District 3, HCMC', 'Vietnamese feast', 520000.00, 3, NOW() - INTERVAL '15 minutes'),
('ORD-2025-012', 'TAKEAWAY', 1, 2, NULL, 'Fresh spring rolls', 120000.00, 2, NOW() - INTERVAL '5 minutes'),
('ORD-2025-013', 'DINE_IN', 1, 1, NULL, 'Fried chicken family meal', 280000.00, 1, NOW()),
('ORD-2025-014', 'DELIVERY', 3, 3, '654 Hai Ba Trung St, District 1, HCMC', 'Thai curry and rice', 180000.00, 3, NOW()),
('ORD-2025-015', 'TAKEAWAY', 1, 2, NULL, 'Smoothie bowl and juice', 110000.00, 2, NOW());

-- Grant permissions for replication user
GRANT ALL PRIVILEGES ON DATABASE pos_db TO postgres;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO postgres;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO postgres;

-- Display summary
SELECT 
    'PostgreSQL HA Cluster Initialized' as status,
    'pos_order' as main_table,
    COUNT(*) as sample_orders,
    MIN(created_at) as earliest_order,
    MAX(created_at) as latest_order,
    SUM(total_amount) as total_revenue
FROM pos_order;

-- Show order types distribution
SELECT 
    order_type,
    COUNT(*) as orders_count,
    SUM(total_amount) as revenue_by_type
FROM pos_order 
GROUP BY order_type 
ORDER BY revenue_by_type DESC;

-- Show status distribution
SELECT 
    status_id,
    CASE 
        WHEN status_id = 1 THEN 'PENDING'
        WHEN status_id = 2 THEN 'PROCESSING' 
        WHEN status_id = 3 THEN 'COMPLETED'
        ELSE 'UNKNOWN'
    END as status_name,
    COUNT(*) as orders_count
FROM pos_order 
GROUP BY status_id 
ORDER BY status_id;

\echo '✅ PostgreSQL HA Cluster với pos_order đã được khởi tạo thành công!'
\echo '📊 15 sample orders đã được tạo'
\echo '🔄 Sẵn sàng cho failover testing với pos_order count' 