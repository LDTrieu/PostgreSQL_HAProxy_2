-- PostgreSQL HA Cluster Initialization Script
-- Database: pos_db

-- Create database if not exists (already done by environment variable)
-- CREATE DATABASE pos_db;

-- Connect to pos_db
\c pos_db;

-- Create replication user if not exists
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_user WHERE usename = 'replicator') THEN
        CREATE USER replicator WITH REPLICATION PASSWORD 'replicator123';
    END IF;
END
$$;

-- Grant necessary permissions
GRANT CONNECT ON DATABASE pos_db TO replicator;

-- Create pos_product table (converted from MySQL to PostgreSQL)
CREATE TABLE IF NOT EXISTS pos_product (
    product_id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    price DECIMAL(10,2) NOT NULL,
    category_id INTEGER NOT NULL,
    image TEXT,
    sku VARCHAR(255) NOT NULL,
    is_available BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP,
    created_by INTEGER,
    updated_by INTEGER
);

-- Create pos_order table
CREATE TABLE IF NOT EXISTS pos_order (
    order_id SERIAL PRIMARY KEY,
    order_number VARCHAR(255) NOT NULL,
    order_type VARCHAR(255) NOT NULL,
    status_id INTEGER NOT NULL,
    pos_id INTEGER NOT NULL,
    address VARCHAR(255),
    description TEXT,
    total_amount DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    created_by INTEGER NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP
);

-- Create pos_order_item table
CREATE TABLE IF NOT EXISTS pos_order_item (
    order_item_id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL,
    sku VARCHAR(255) NOT NULL,
    product_id INTEGER NOT NULL,
    qty INTEGER NOT NULL,
    status_id INTEGER NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    created_by INTEGER NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Create pos_user table
CREATE TABLE IF NOT EXISTS pos_user (
    user_id SERIAL PRIMARY KEY,
    user_name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    position_id INTEGER NOT NULL,
    status_id INTEGER NOT NULL,
    config INTEGER NOT NULL,
    shop_config INTEGER NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP,
    deleted BOOLEAN DEFAULT false,
    auth_user_id INTEGER,
    password VARCHAR(255) NOT NULL,
    created_by INTEGER NOT NULL,
    updated_by INTEGER,
    last_login_at TIMESTAMP
);

-- Insert sample data into pos_product for testing
INSERT INTO pos_product (name, description, price, category_id, sku, is_available, created_by) VALUES
('Café Americano', 'Classic black coffee made with espresso and hot water', 45000, 1, 'CAFE-001', true, 1),
('Café Latte', 'Espresso with steamed milk and light foam', 55000, 1, 'CAFE-002', true, 1),
('Cappuccino', 'Espresso with steamed milk and thick foam', 50000, 1, 'CAFE-003', true, 1),
('Mocha', 'Espresso with chocolate and steamed milk', 60000, 1, 'CAFE-004', true, 1),
('Frappé', 'Iced coffee drink with whipped cream', 65000, 1, 'CAFE-005', true, 1),
('Green Tea Latte', 'Matcha green tea with steamed milk', 58000, 2, 'TEA-001', true, 1),
('Chai Tea Latte', 'Spiced tea with steamed milk', 52000, 2, 'TEA-002', true, 1),
('Earl Grey', 'Classic Earl Grey black tea', 35000, 2, 'TEA-003', true, 1),
('Croissant', 'Buttery French pastry', 25000, 3, 'PASTRY-001', true, 1),
('Chocolate Muffin', 'Rich chocolate chip muffin', 30000, 3, 'PASTRY-002', true, 1),
('Cheesecake Slice', 'New York style cheesecake', 75000, 4, 'DESSERT-001', true, 1),
('Tiramisu', 'Italian coffee-flavored dessert', 80000, 4, 'DESSERT-002', true, 1),
('Caesar Salad', 'Fresh romaine lettuce with Caesar dressing', 85000, 5, 'SALAD-001', true, 1),
('Club Sandwich', 'Triple layer sandwich with chicken and bacon', 95000, 6, 'SANDWICH-001', true, 1),
('Margherita Pizza', 'Classic pizza with tomato, mozzarella, and basil', 120000, 7, 'PIZZA-001', true, 1);

-- Insert sample users
INSERT INTO pos_user (user_name, email, position_id, status_id, config, shop_config, password, created_by) VALUES
('Admin User', 'admin@pos.com', 1, 1, 1, 1, 'admin123', 1),
('Manager User', 'manager@pos.com', 2, 1, 1, 1, 'manager123', 1),
('Cashier User', 'cashier@pos.com', 3, 1, 1, 1, 'cashier123', 1);

-- Insert sample orders
INSERT INTO pos_order (order_number, order_type, status_id, pos_id, total_amount, created_by) VALUES
('ORD-001', 'DINE_IN', 1, 1, 100000, 1),
('ORD-002', 'TAKEAWAY', 1, 1, 75000, 2),
('ORD-003', 'DELIVERY', 2, 1, 150000, 1);

-- Insert sample order items
INSERT INTO pos_order_item (order_id, sku, product_id, qty, status_id, price, amount, created_by) VALUES
(1, 'CAFE-001', 1, 2, 1, 45000, 90000, 1),
(1, 'PASTRY-001', 9, 1, 1, 25000, 25000, 1),
(2, 'CAFE-002', 2, 1, 1, 55000, 55000, 2),
(2, 'PASTRY-002', 10, 1, 1, 30000, 30000, 2),
(3, 'PIZZA-001', 15, 1, 1, 120000, 120000, 1),
(3, 'CAFE-003', 3, 1, 1, 50000, 50000, 1);

-- Create monitoring functions for Grafana
CREATE OR REPLACE FUNCTION get_cluster_status()
RETURNS TABLE (
    database_name TEXT,
    pod_id TEXT,
    product_count BIGINT,
    last_5_product_ids TEXT,
    last_5_product_names TEXT,
    role TEXT,
    ip_address INET,
    start_time TIMESTAMP,
    uptime_seconds BIGINT,
    status TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        current_database()::TEXT as database_name,
        inet_server_addr()::TEXT as pod_id,
        (SELECT COUNT(*) FROM pos_product) as product_count,
        (SELECT STRING_AGG(product_id::TEXT, ',' ORDER BY product_id DESC) 
         FROM (SELECT product_id FROM pos_product ORDER BY product_id DESC LIMIT 5) sub) as last_5_product_ids,
        (SELECT STRING_AGG(name, ',' ORDER BY product_id DESC) 
         FROM (SELECT name, product_id FROM pos_product ORDER BY product_id DESC LIMIT 5) sub) as last_5_product_names,
        CASE 
            WHEN pg_is_in_recovery() THEN 'REPLICA'
            ELSE 'MASTER'
        END as role,
        inet_server_addr() as ip_address,
        pg_postmaster_start_time() as start_time,
        EXTRACT(EPOCH FROM (NOW() - pg_postmaster_start_time()))::BIGINT as uptime_seconds,
        CASE 
            WHEN EXTRACT(EPOCH FROM (NOW() - pg_postmaster_start_time())) < 300 THEN 'RECENT_RESTART'
            ELSE 'STABLE'
        END as status;
END;
$$ LANGUAGE plpgsql;

-- Create replication status function
CREATE OR REPLACE FUNCTION get_replication_status()
RETURNS TABLE (
    application_name TEXT,
    client_addr INET,
    backend_start TIMESTAMP,
    state TEXT,
    sent_lsn PG_LSN,
    write_lsn PG_LSN,
    flush_lsn PG_LSN,
    replay_lsn PG_LSN,
    write_lag INTERVAL,
    flush_lag INTERVAL,
    replay_lag INTERVAL
) AS $$
BEGIN
    IF NOT pg_is_in_recovery() THEN
        RETURN QUERY
        SELECT * FROM pg_stat_replication;
    ELSE
        RETURN;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Create master election tracking function
CREATE OR REPLACE FUNCTION get_master_election_status()
RETURNS TABLE (
    election_status TEXT,
    pod_ip INET,
    elected_time TIMESTAMP,
    replica_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        CASE 
            WHEN pg_is_in_recovery() THEN 'REPLICA'
            ELSE 'ELECTED_MASTER'
        END as election_status,
        inet_server_addr() as pod_ip,
        pg_postmaster_start_time() as elected_time,
        CASE 
            WHEN pg_is_in_recovery() THEN 0::BIGINT
            ELSE (SELECT COUNT(*) FROM pg_stat_replication)::BIGINT
        END as replica_count;
END;
$$ LANGUAGE plpgsql;

-- Create product count comparison function
CREATE OR REPLACE FUNCTION get_product_count_realtime()
RETURNS TABLE (
    node_name TEXT,
    product_count BIGINT,
    node_role TEXT,
    last_updated TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        inet_server_addr()::TEXT as node_name,
        (SELECT COUNT(*) FROM pos_product) as product_count,
        CASE 
            WHEN pg_is_in_recovery() THEN 'REPLICA'
            ELSE 'MASTER'
        END as node_role,
        NOW() as last_updated;
END;
$$ LANGUAGE plpgsql;

-- Grant permissions for monitoring functions
GRANT EXECUTE ON FUNCTION get_cluster_status() TO postgres;
GRANT EXECUTE ON FUNCTION get_replication_status() TO postgres;
GRANT EXECUTE ON FUNCTION get_master_election_status() TO postgres;
GRANT EXECUTE ON FUNCTION get_product_count_realtime() TO postgres;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_pos_product_created_at ON pos_product(created_at);
CREATE INDEX IF NOT EXISTS idx_pos_product_category_id ON pos_product(category_id);
CREATE INDEX IF NOT EXISTS idx_pos_product_sku ON pos_product(sku);
CREATE INDEX IF NOT EXISTS idx_pos_order_created_at ON pos_order(created_at);
CREATE INDEX IF NOT EXISTS idx_pos_order_item_order_id ON pos_order_item(order_id);
CREATE INDEX IF NOT EXISTS idx_pos_order_item_product_id ON pos_order_item(product_id);

-- Show completion message
SELECT 'PostgreSQL HA Cluster initialized successfully!' as message; 