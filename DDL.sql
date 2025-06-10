


-- pos_db.pos_product definition

CREATE TABLE `pos_product` (
  `product_id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `description` text,
  `price` decimal(10,2) NOT NULL,
  `category_id` int NOT NULL,
  `image` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci,
  `sku` varchar(255) NOT NULL,
  `is_available` tinyint(1) NOT NULL DEFAULT '1',
  `created_at` datetime NOT NULL,
  `updated_at` datetime DEFAULT NULL,
  `created_by` int DEFAULT NULL,
  `updated_by` int DEFAULT NULL,
  PRIMARY KEY (`product_id`)
) ENGINE=InnoDB AUTO_INCREMENT=69 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- pos_db.pos_order definition

CREATE TABLE `pos_order` (
  `order_id` int NOT NULL AUTO_INCREMENT,
  `order_number` varchar(255) NOT NULL,
  `order_type` varchar(255) NOT NULL,
  `status_id` int NOT NULL,
  `pos_id` int NOT NULL,
  `address` varchar(255) DEFAULT NULL,
  `description` text,
  `total_amount` decimal(10,2) NOT NULL DEFAULT '0.00',
  `created_by` int NOT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`order_id`)
) ENGINE=InnoDB AUTO_INCREMENT=51 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- pos_db.pos_order_item definition

CREATE TABLE `pos_order_item` (
  `order_item_id` int NOT NULL AUTO_INCREMENT,
  `order_id` int NOT NULL,
  `sku` varchar(255) NOT NULL,
  `product_id` int NOT NULL,
  `qty` int NOT NULL,
  `status_id` int NOT NULL,
  `price` decimal(10,2) NOT NULL,
  `amount` decimal(10,2) NOT NULL,
  `created_by` int NOT NULL,
  `created_at` datetime NOT NULL,
  PRIMARY KEY (`order_item_id`)
) ENGINE=InnoDB AUTO_INCREMENT=79 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;



-- pos_db.pos_user definition

CREATE TABLE `pos_user` (
  `user_id` int NOT NULL AUTO_INCREMENT,
  `user_name` varchar(255) NOT NULL,
  `email` varchar(255) NOT NULL,
  `position_id` int NOT NULL,
  `status_id` int NOT NULL,
  `config` int NOT NULL,
  `shop_config` int NOT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime DEFAULT NULL,
  `__deleted` tinyint DEFAULT '0',
  `auth_user_id` int DEFAULT NULL,
  `password` varchar(255) NOT NULL,
  `created_by` int NOT NULL,
  `updated_by` int DEFAULT NULL,
  `last_login_at` datetime DEFAULT NULL,
  PRIMARY KEY (`user_id`),
  UNIQUE KEY `email` (`email`)
) ENGINE=InnoDB AUTO_INCREMENT=49 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;