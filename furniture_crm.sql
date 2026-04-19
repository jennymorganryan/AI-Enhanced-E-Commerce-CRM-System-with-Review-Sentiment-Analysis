CREATE DATABASE IF NOT EXISTS Jenny_Morgan_CRM;
USE `Jenny_Morgan_CRM`;

CREATE USER IF NOT EXISTS 'user'@'localhost' IDENTIFIED BY 'password27';
GRANT SELECT, INSERT, UPDATE, DELETE, EXECUTE ON Jenny_Morgan_CRM.* TO 'user'@'localhost';


CREATE TABLE customer (
customer_id INT AUTO_INCREMENT PRIMARY KEY,
email VARCHAR(255) NOT NULL UNIQUE
);

CREATE TABLE customer_info (
customer_id INT NOT NULL,
first_name VARCHAR(100) NOT NULL,
last_name VARCHAR(100) NOT NULL,
street1 VARCHAR(35) NOT NULL,
street2 VARCHAR(35),
city VARCHAR(35) NOT NULL,
state VARCHAR(50) NOT NULL,
zip_code INT NOT NULL,
country VARCHAR(50) NOT NULL,
PRIMARY KEY (customer_id),
CONSTRAINT fk_customer_info_customer
FOREIGN KEY (customer_id) REFERENCES customer(customer_id)
ON DELETE CASCADE ON UPDATE CASCADE,
CHECK (zip_code < 1000000000 AND zip_code > 9999)
);


CREATE TABLE inventory_item (
sku INT AUTO_INCREMENT PRIMARY KEY,
item_name VARCHAR(50) NOT NULL UNIQUE,
furniture_type VARCHAR(100),
brand VARCHAR(100),
description VARCHAR(400),
color VARCHAR(50),
price DECIMAL(10,2),
length DECIMAL(10,2),
width DECIMAL(10,2),
weight INT,
material VARCHAR(50),
shape VARCHAR(30),
size_name VARCHAR(10),
softness VARCHAR(20),
diameter DECIMAL(10,2),
furniture_style VARCHAR(30),
sku_stock INT NOT NULL DEFAULT 0,
last_restock DATE DEFAULT (CURRENT_DATE),
CHECK(sku_stock >= 0),
CHECK(price >= 0),
CHECK(weight > 0 AND weight < 1000),
CHECK(length IS NULL OR length > 0),
CHECK(width IS NULL OR width > 0),
CHECK(diameter IS NULL OR diameter > 0),
CHECK(furniture_type IN ('bed','mattress','chair','rug','table','desk','nightstand','dining set','couch', 'dresser', 'other')),
CHECK(furniture_style IS NULL OR furniture_style IN
('office','bedroom','living room','bathroom','kids room','teens room', 'gym',
'dining','recliner','accent','rocking','bar','coffee','side','end',
'desk','platform','bunk','canopy','sectional','loveseat','sleeper','futon')),
CHECK(size_name IS NULL OR size_name IN ('twin','full','queen','king')),
CHECK(softness IS NULL OR softness IN ('soft','medium','firm')),
CHECK(shape IS NULL OR shape IN ('round','square','rectangular','oval','L-shape','heart')),
CHECK(material IS NULL OR material IN
('wood','oak','pine','maple','walnut','cherry','mahogany','birch', 'fur', 'faux fur','poplar', 'copper', 'stainless steel',
'teak','cedar','ash','beech','hickory','acacia','alder','bamboo', 'coils', 'latex', 'aluminum','other',
'plywood','memory foam','polyester','polyfoam','cotton','hybrid','bamboo','particleboard','veneer','metal',
'plastic','glass','leather','fabric','foam','velvet','iron', 'natural materials', 'synthetic fibers', 'nylon'))
);

CREATE TABLE furniture_piece (
furniture_id INT AUTO_INCREMENT PRIMARY KEY,
warehouse_location VARCHAR(50),
sku INT NOT NULL,
CONSTRAINT fk_inventory_item_to_furniture
FOREIGN KEY (sku)
REFERENCES inventory_item(sku)
ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE order_cart (
order_id INT AUTO_INCREMENT PRIMARY KEY,
customer_id INT NOT NULL,
order_date TIMESTAMP,
delivery_date DATETIME,
order_status VARCHAR(50) NOT NULL DEFAULT 'open',
CONSTRAINT fk_customer_to_order_cart
FOREIGN KEY (customer_id)
REFERENCES customer(customer_id)
ON DELETE RESTRICT ON UPDATE CASCADE,
CHECK (order_status IN ('open', 'submitted', 'cancelled', 'delivered'))
);

CREATE TABLE review (
review_id INT AUTO_INCREMENT PRIMARY KEY,
customer_id INT NOT NULL,
sku INT NOT NULL,
review VARCHAR(1000) NOT NULL,
CONSTRAINT fk_customer_to_review
FOREIGN KEY (customer_id)
REFERENCES customer(customer_id)
ON DELETE RESTRICT ON UPDATE CASCADE,
CONSTRAINT fk_inventory_item_to_review
FOREIGN KEY (sku)
REFERENCES inventory_item(sku)
ON DELETE RESTRICT ON UPDATE CASCADE,
CONSTRAINT unique_customer_sku_review
UNIQUE (customer_id, sku),
CHECK(LENGTH(review) > 99)
);

CREATE TABLE inventoryitem_adds_ordercart (
sku INT,
order_id INT,
quantity INT NOT NULL DEFAULT 0,
CONSTRAINT fk_inventoryitem_relationship_ordercart
FOREIGN KEY (sku) REFERENCES inventory_item(sku)
ON DELETE RESTRICT ON UPDATE CASCADE,
CONSTRAINT fk_ordercart_relationship_inventoryitem
FOREIGN KEY (order_id) REFERENCES order_cart(order_id)
ON DELETE CASCADE ON UPDATE CASCADE,
PRIMARY KEY(sku, order_id),
CHECK (quantity > 0)
);

-- Views --------------------------------------------------

-- View of store catalog for customer - user interface

CREATE VIEW catalog_summary AS
SELECT
ii.item_name,
ii.furniture_type,
ii.price,
ii.description,
ii.material,
ii.furniture_style
FROM inventory_item AS ii;


-- Functions ---------------------------------------

-- Function to check if input item is eligible for review
DELIMITER **

CREATE FUNCTION is_item_eligible_for_review (
input_customer_id INT,
input_item_name VARCHAR(50)
)
RETURNS BOOLEAN
DETERMINISTIC
READS SQL DATA

BEGIN
DECLARE found_sku INT;
DECLARE eligible_count INT;

SELECT sku
INTO found_sku
FROM inventory_item
WHERE item_name = input_item_name;

IF found_sku IS NULL THEN
    RETURN FALSE;
END IF;

SELECT COUNT(*)
INTO eligible_count
FROM order_cart AS o
JOIN inventoryitem_adds_ordercart AS i
ON o.order_id = i.order_id
LEFT JOIN review AS r
ON r.customer_id = o.customer_id
AND r.sku = i.sku
WHERE o.customer_id = input_customer_id
AND i.sku = found_sku
AND o.order_status = 'delivered'
AND o.delivery_date <= CURRENT_TIMESTAMP
AND r.review_id IS NULL;

IF eligible_count > 0 THEN
RETURN TRUE;
ELSE
RETURN FALSE;
END IF;

END **

DELIMITER ;

-- Function getter for order_id for a customer's open order

DELIMITER **
CREATE FUNCTION get_order_id (
input_customer_id INT
)
RETURNS INT
DETERMINISTIC
READS SQL DATA

BEGIN
DECLARE found_order_id INT;
SELECT order_id
INTO found_order_id
FROM customer_info AS ci
JOIN order_cart AS oc
ON ci.customer_id = oc.customer_id
WHERE ci.customer_id = input_customer_id
AND oc.order_status = "open"
ORDER BY oc.order_id DESC
LIMIT 1;

RETURN found_order_id;

END **
DELIMITER ;


-- Function to get the sku of an item from the item_name

DELIMITER **

CREATE FUNCTION get_sku_by_item_name (
input_item_name VARCHAR(50)
)
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
DECLARE found_sku INT;

SELECT sku
INTO found_sku
FROM inventory_item
WHERE item_name = input_item_name;

RETURN found_sku;
END **

DELIMITER ;

-- Function to return the customer info that an input email belongs to


DELIMITER **

CREATE FUNCTION get_customer_id_by_email (
input_email VARCHAR(255)
)
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
DECLARE found_customer_id INT;

SELECT customer_id
INTO found_customer_id
FROM customer
WHERE email = input_email;

RETURN found_customer_id;
END **

DELIMITER ;

-- Function check to see if the user input email matches the database


DELIMITER **

CREATE FUNCTION check_customer_email(input_email VARCHAR(255))
RETURNS BOOLEAN
DETERMINISTIC
READS SQL DATA
BEGIN
DECLARE email_count INT;

SELECT COUNT(*)
INTO email_count
FROM customer
WHERE email = input_email;

IF email_count > 0 THEN
RETURN TRUE;
ELSE
RETURN FALSE;
END IF;

END **

DELIMITER ;


-- Function to sum up the order total 

DELIMITER **

CREATE FUNCTION function_order_total(input_order_id INT)
RETURNS DECIMAL(10,2)
DETERMINISTIC
READS SQL DATA
BEGIN
DECLARE order_total DECIMAL(10,2);

SELECT IFNULL(SUM(ii.price * i.quantity), 0.00)
INTO order_total
FROM inventoryitem_adds_ordercart AS i
JOIN inventory_item AS ii
ON i.sku = ii.sku
WHERE i.order_id = input_order_id;

RETURN order_total;
END **

DELIMITER ;

-- Function which counts how many orders a customer has

DELIMITER **


CREATE FUNCTION count_customer_orders(input_customer_id INT)
RETURNS INT
DETERMINISTIC
READS SQL DATA

BEGIN
DECLARE customer_order_count INT;
SELECT COUNT(*)
INTO customer_order_count
FROM order_cart
WHERE customer_id = input_customer_id;
RETURN customer_order_count;
END **

DELIMITER ;

--  Function to find open cart

DELIMITER **

CREATE FUNCTION get_open_order_id(input_customer_id INT)
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
DECLARE found_order_id INT;

SELECT MAX(order_id)
INTO found_order_id
FROM order_cart
WHERE customer_id = input_customer_id
AND order_status = 'open';

RETURN found_order_id;
END **

DELIMITER ;


-- Function to count how many reviews a customer has written

DELIMITER **

CREATE FUNCTION count_customer_reviews(input_customer_id INT)
RETURNS INT
DETERMINISTIC
READS SQL DATA

BEGIN
DECLARE customer_review_count INT;
SELECT COUNT(*)
INTO customer_review_count
FROM review
WHERE customer_id = input_customer_id;
RETURN customer_review_count;
END **

DELIMITER ;


-- Procedures ----------------------------------------------

-- Procedure to VIEW own written reviews:

DELIMITER **

CREATE PROCEDURE get_customer_written_reviews (
IN input_customer_id INT
)
BEGIN
SELECT
r.review_id,
r.sku,
ii.item_name,
r.review
FROM review AS r
JOIN inventory_item AS ii
ON r.sku = ii.sku
WHERE r.customer_id = input_customer_id
ORDER BY r.review_id DESC;
END **

DELIMITER ;

-- Procedure to UPDATE written reviews


DELIMITER **

CREATE PROCEDURE update_review (
IN input_review_id INT,
IN input_customer_id INT,
IN input_review_text VARCHAR(1000)
)
BEGIN
UPDATE review
SET review = input_review_text
WHERE review_id = input_review_id
AND customer_id = input_customer_id;

IF ROW_COUNT() = 0 THEN
SIGNAL SQLSTATE '45000'
SET MESSAGE_TEXT = 'Review does not exist for this customer.';
END IF;
END **

DELIMITER ;

-- Procedure to DELETE written review


DELIMITER **

CREATE PROCEDURE delete_review (
IN input_review_id INT,
IN input_customer_id INT
)
BEGIN
DELETE FROM review
WHERE review_id = input_review_id
AND customer_id = input_customer_id;

IF ROW_COUNT() = 0 THEN
SIGNAL SQLSTATE '45000'
SET MESSAGE_TEXT = 'Review does not exist for this customer.';
END IF;
END **

DELIMITER ;
-- Procedure to CREATE a review


DELIMITER **

CREATE PROCEDURE create_review (
IN input_customer_id INT,
IN input_item_name VARCHAR(50),
IN input_review VARCHAR(1000)
)
BEGIN
DECLARE found_sku INT;
DECLARE eligible_count INT;

SELECT sku
INTO found_sku
FROM inventory_item
WHERE item_name = input_item_name;

IF found_sku IS NULL THEN
SIGNAL SQLSTATE '45000'
SET MESSAGE_TEXT = 'Item name does not exist.';
END IF;

SELECT COUNT(*)
INTO eligible_count
FROM order_cart AS o
JOIN inventoryitem_adds_ordercart AS i
ON o.order_id = i.order_id
LEFT JOIN review AS r
ON r.customer_id = o.customer_id
AND r.sku = i.sku
WHERE o.customer_id = input_customer_id
AND i.sku = found_sku
AND o.order_status = 'delivered'
AND o.delivery_date <= CURRENT_TIMESTAMP
AND r.review_id IS NULL;

IF eligible_count = 0 THEN
SIGNAL SQLSTATE '45000'
SET MESSAGE_TEXT = 'Customer is not eligible to review this item.';
END IF;

INSERT INTO review (
customer_id,
sku,
review
)
VALUES (
input_customer_id,
found_sku,
input_review
);
END **

DELIMITER ;

-- Procedure to CREATE customer when user logs in with email and they are new customer

DELIMITER **

CREATE PROCEDURE create_customer(IN email_p VARCHAR(255))
BEGIN

INSERT INTO customer (email)
VALUES (email_p);

END**

DELIMITER ;



-- Procedure to CREATE customer_info when customer is checking out


DELIMITER **

CREATE PROCEDURE create_customer_info (
IN input_customer_id INT,
IN input_first_name VARCHAR(100),
IN input_last_name VARCHAR(100),
IN input_street1 VARCHAR(35),
IN input_street2 VARCHAR(35),
IN input_city VARCHAR(50),
IN input_state VARCHAR(50),
IN input_zip_code INT,
IN input_country VARCHAR(50)
)
BEGIN
DECLARE existing_customer_count INT;

SELECT COUNT(*)
INTO existing_customer_count
FROM customer_info
WHERE customer_id = input_customer_id;

IF existing_customer_count > 0 THEN
UPDATE customer_info
SET first_name = input_first_name,
last_name = input_last_name,
street1 = input_street1,
street2 = input_street2,
city = input_city,
state = input_state,
zip_code = input_zip_code,
country = input_country
WHERE customer_id = input_customer_id;
ELSE
INSERT INTO customer_info (
customer_id,
first_name,
last_name,
street1,
street2,
city,
state,
zip_code,
country
)
VALUES (
input_customer_id,
input_first_name,
input_last_name,
input_street1,
input_street2,
input_city,
input_state,
input_zip_code,
input_country
);
END IF;
END **

DELIMITER ;

-- Procedure to delete an item from a cart

DROP PROCEDURE IF EXISTS delete_cart_item;

DELIMITER **

CREATE PROCEDURE delete_cart_item (
IN input_order_id INT,
IN input_item_name VARCHAR(50)
)
BEGIN
DECLARE database_sku INT;
DECLARE remaining_item_count INT;

SELECT sku
INTO database_sku
FROM inventory_item
WHERE item_name = input_item_name;

IF database_sku IS NULL THEN
SIGNAL SQLSTATE '45000'
SET MESSAGE_TEXT = 'Invalid catalog item name.';
END IF;

DELETE FROM inventoryitem_adds_ordercart
WHERE order_id = input_order_id
AND sku = database_sku;

IF ROW_COUNT() = 0 THEN
SIGNAL SQLSTATE '45000'
SET MESSAGE_TEXT = 'Item is not in the cart.';
END IF;

SELECT COUNT(*)
INTO remaining_item_count
FROM inventoryitem_adds_ordercart
WHERE order_id = input_order_id;

IF remaining_item_count = 0 THEN
UPDATE order_cart
SET order_status = 'cancelled'
WHERE order_id = input_order_id
AND order_status = 'open';
END IF;

END **

DELIMITER ;

-- Procedure to show customer info 

DELIMITER **

CREATE PROCEDURE show_customer_info (
IN input_customer_id INT
)
BEGIN
DECLARE customer_count INT;

SELECT COUNT(*)
INTO customer_count
FROM customer AS c
JOIN customer_info AS ci
ON c.customer_id = ci.customer_id
WHERE c.customer_id = input_customer_id;

IF customer_count = 0 THEN
SIGNAL SQLSTATE '45000'
SET MESSAGE_TEXT = 'Customer does not exist.';
END IF;

SELECT
c.email,
ci.first_name,
ci.last_name,
ci.street1,
ci.street2,
ci.city,
ci.state,
ci.zip_code,
ci.country,
count_customer_orders(c.customer_id) AS total_orders,
count_customer_reviews(c.customer_id) AS total_reviews
FROM customer AS c
JOIN customer_info AS ci
ON c.customer_id = ci.customer_id
WHERE c.customer_id = input_customer_id;
END **

DELIMITER ;

-- Procedure to cancel open cart order on exit

DELIMITER **

CREATE PROCEDURE cancel_open_cart_on_exit (
IN input_order_id INT 
)
BEGIN
DECLARE matching_order_count INT;
DECLARE current_order_status VARCHAR(50);


SELECT COUNT(*)
INTO matching_order_count
FROM order_cart
WHERE order_id = input_order_id;

IF matching_order_count = 0 THEN
SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Order does not exist.';
END IF;

SELECT order_status
INTO current_order_status
FROM order_cart
WHERE order_id = input_order_id;

IF current_order_status = 'open' THEN
UPDATE order_cart
SET order_status = 'cancelled'
WHERE order_id = input_order_id;
END IF;

END **

DELIMITER ;

-- Procedure to get a customer order history  

DELIMITER **

CREATE PROCEDURE get_customer_order_history (
IN input_customer_id INT
)
BEGIN
DECLARE matching_order_count INT;

SELECT COUNT(*)
INTO matching_order_count
FROM order_cart
WHERE customer_id = input_customer_id
AND order_status IN ('submitted', 'delivered');

IF matching_order_count = 0 THEN
SIGNAL SQLSTATE '45000'
SET MESSAGE_TEXT = 'Customer has no order history.';
END IF;

SELECT
o.order_id,
o.order_date,
o.delivery_date,
o.order_status,
ii.item_name,
ii.brand,
ii.furniture_type,
ii.price,
i.quantity,
(ii.price * i.quantity) AS line_total,
function_order_total(o.order_id) AS order_total
FROM order_cart AS o
JOIN inventoryitem_adds_ordercart AS i
ON o.order_id = i.order_id
JOIN inventory_item AS ii
ON i.sku = ii.sku
WHERE o.customer_id = input_customer_id
AND o.order_status IN ('submitted', 'delivered')
ORDER BY o.order_id DESC, ii.item_name;
END **

DELIMITER ;


-- Procedure to check out order

DELIMITER **

CREATE PROCEDURE checkout_order (
IN input_order_id INT
)
BEGIN
DECLARE item_count INT;
DECLARE current_status VARCHAR(50);
DECLARE insufficient_stock_count INT;

SELECT order_status
INTO current_status
FROM order_cart
WHERE order_id = input_order_id;

IF current_status IS NULL THEN
SIGNAL SQLSTATE '45000'
SET MESSAGE_TEXT = 'Order does not exist.';
END IF;

IF current_status <> 'open' THEN
SIGNAL SQLSTATE '45000'
SET MESSAGE_TEXT = 'Only an open order can be checked out.';
END IF;

SELECT COUNT(*)
INTO item_count
FROM inventoryitem_adds_ordercart
WHERE order_id = input_order_id;

IF item_count = 0 THEN
SIGNAL SQLSTATE '45000'
SET MESSAGE_TEXT = 'Cart is empty.';
END IF;

SELECT COUNT(*)
INTO insufficient_stock_count
FROM inventoryitem_adds_ordercart AS i
JOIN inventory_item AS ii
ON i.sku = ii.sku
WHERE i.order_id = input_order_id
AND i.quantity > ii.sku_stock;

IF insufficient_stock_count > 0 THEN
SIGNAL SQLSTATE '45000'
SET MESSAGE_TEXT = 'One or more cart items no longer have enough stock available.';
END IF;

UPDATE inventory_item AS ii
JOIN inventoryitem_adds_ordercart AS i
ON ii.sku = i.sku
SET ii.sku_stock = ii.sku_stock - i.quantity
WHERE i.order_id = input_order_id;

UPDATE order_cart
SET order_status = 'submitted',
order_date = CURRENT_TIMESTAMP,
delivery_date = DATE_ADD(CURRENT_TIMESTAMP, INTERVAL 7 DAY)
WHERE order_id = input_order_id;

END **

DELIMITER ;
-- Procedure to read all customer reviews for a particular item_name / sku. User can see the user's first name, order_date and review.

DELIMITER **

CREATE PROCEDURE read_item_reviews (
IN input_item_name VARCHAR(50)
)
BEGIN
SELECT
ii.item_name,
ci.first_name,
MAX(o.order_date) AS order_date,
r.review
FROM review AS r
JOIN customer_info AS ci
ON r.customer_id = ci.customer_id
JOIN inventory_item AS ii
ON r.sku = ii.sku
JOIN inventoryitem_adds_ordercart AS i
ON i.sku = r.sku
JOIN order_cart AS o
ON o.order_id = i.order_id
AND o.customer_id = r.customer_id
WHERE ii.item_name = input_item_name
AND o.order_status = 'delivered'
GROUP BY r.review_id, ci.first_name, r.review
ORDER BY order_date DESC;
END **

DELIMITER ;



-- Procedure to CREATE order_cart 

DELIMITER **

CREATE PROCEDURE create_order_cart(
IN input_customer_id INT
)
BEGIN
INSERT INTO order_cart (
customer_id,
order_status
)
VALUES (
input_customer_id,
'open'
);

SELECT LAST_INSERT_ID() AS new_order_id;
END **

DELIMITER ;

-- Procedure to view order in cart

DELIMITER **

CREATE PROCEDURE view_order_cart (
IN input_order_id INT
)
BEGIN
SELECT
ii.item_name,
ii.brand,
ii.furniture_type,
ii.color,
ii.price,
i.quantity,
(ii.price * i.quantity) AS line_total,
function_order_total(input_order_id) AS order_total
FROM inventoryitem_adds_ordercart AS i
JOIN inventory_item AS ii
ON i.sku = ii.sku
WHERE i.order_id = input_order_id
ORDER BY ii.item_name;
 
END **

DELIMITER ;

-- Proecedure to add to cart OR change quantity

DELIMITER **

CREATE PROCEDURE upsert_cart_item (
IN input_order_id INT,
IN input_item_name VARCHAR(50),
IN input_quantity INT
)
BEGIN
DECLARE database_sku INT;
DECLARE matching_cart_item_count INT;

IF input_quantity <= 0 THEN
SIGNAL SQLSTATE '45000'
SET MESSAGE_TEXT = 'Quantity must be greater than 0.';
END IF;

SELECT sku
INTO database_sku
FROM inventory_item
WHERE item_name = input_item_name;

IF database_sku IS NULL THEN
SIGNAL SQLSTATE '45000'
SET MESSAGE_TEXT = 'Invalid catalog item name.';
END IF;

SELECT COUNT(*)
INTO matching_cart_item_count
FROM inventoryitem_adds_ordercart
WHERE order_id = input_order_id
AND sku = database_sku;

IF matching_cart_item_count > 0 THEN
UPDATE inventoryitem_adds_ordercart
SET quantity = input_quantity + quantity
WHERE order_id = input_order_id
AND sku = database_sku;
ELSE
INSERT INTO inventoryitem_adds_ordercart (
sku,
order_id,
quantity
)
VALUES (
database_sku,
input_order_id,
input_quantity
);
END IF;
END **

DELIMITER ;
-- Procedure to READ / Check What Skus in Past Orders are available for review using customers email

DELIMITER **

CREATE PROCEDURE get_customer_products_eligible_for_review(
IN input_customer_id INT
)
BEGIN
DECLARE eligible_review_count INT;

SELECT COUNT(DISTINCT i.sku)
INTO eligible_review_count
FROM order_cart AS o
JOIN inventoryitem_adds_ordercart AS i
ON o.order_id = i.order_id
LEFT JOIN review AS r
ON r.customer_id = o.customer_id
AND r.sku = i.sku
WHERE o.customer_id = input_customer_id
AND o.order_status = 'delivered'
AND o.delivery_date <= CURRENT_TIMESTAMP
AND r.review_id IS NULL;

IF eligible_review_count = 0 THEN
SIGNAL SQLSTATE '45000'
SET MESSAGE_TEXT = 'Customer has no eligible delivered items available for review.';
END IF;

SELECT DISTINCT
ii.sku,
ii.item_name,
ii.furniture_type,
ii.brand,
ii.color,
o.order_id,
o.delivery_date
FROM order_cart AS o
JOIN inventoryitem_adds_ordercart AS i
ON o.order_id = i.order_id
JOIN inventory_item AS ii
ON i.sku = ii.sku
LEFT JOIN review AS r
ON r.customer_id = o.customer_id
AND r.sku = i.sku
WHERE o.customer_id = input_customer_id
AND o.order_status = 'delivered'
AND o.delivery_date <= CURRENT_TIMESTAMP
AND r.review_id IS NULL;
END **

DELIMITER ;


-- Procedure to update stock for a sku 

DELIMITER **

CREATE PROCEDURE update_stock_for_order (
IN input_order_id INT
)
BEGIN
DECLARE matching_order_count INT;
DECLARE current_order_status VARCHAR(50);

SELECT COUNT(*)
INTO matching_order_count
FROM order_cart
WHERE order_id = input_order_id;

IF matching_order_count = 0 THEN
SIGNAL SQLSTATE '45000'
SET MESSAGE_TEXT = 'Order does not exist.';
END IF;

SELECT order_status
INTO current_order_status
FROM order_cart
WHERE order_id = input_order_id;

IF current_order_status <> 'submitted' THEN
SIGNAL SQLSTATE '45000'
SET MESSAGE_TEXT = 'Stock can only be updated for a submitted order.';
END IF;

UPDATE inventory_item AS ii
JOIN inventoryitem_adds_ordercart AS i
ON ii.sku = i.sku
SET ii.sku_stock = ii.sku_stock - i.quantity
WHERE i.order_id = input_order_id;
END **

DELIMITER ;

-- Procedure to sync order status of database


DELIMITER **

CREATE PROCEDURE sync_all_delivered_orders ()
BEGIN
UPDATE order_cart
SET order_status = 'delivered'
WHERE order_status = 'submitted'
AND delivery_date IS NOT NULL
AND delivery_date <= CURRENT_TIMESTAMP;
END **

DELIMITER ;


-- Triggers ------------------------------------------------------------------

-- checks if the item is in stock when customer inserts && creates order_cart if not already created.

DELIMITER **

CREATE TRIGGER before_insert_inventoryitem_adds_ordercart_check
BEFORE INSERT ON inventoryitem_adds_ordercart
FOR EACH ROW
BEGIN
DECLARE available_stock_quantity INT;
DECLARE matching_order_count INT;
DECLARE current_order_status VARCHAR(50);

SELECT COUNT(*)
INTO matching_order_count
FROM order_cart
WHERE order_id = NEW.order_id;

IF matching_order_count = 0 THEN
SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Items can only be added to an open cart.';


END IF;

SELECT order_status
INTO current_order_status
FROM order_cart
WHERE order_id = NEW.order_id;

IF current_order_status <> 'open' THEN
SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Items can only be added to an open cart.';
END IF;

SELECT sku_stock
INTO available_stock_quantity
FROM inventory_item
WHERE sku = NEW.sku;

IF available_stock_quantity IS NULL THEN
SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'SKU does not exist in inventory.';
END IF;


IF NEW.quantity > available_stock_quantity THEN
SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Requested quantity exceeds available stock.';
END IF;
END **


-- Trigger to make sure a certain quantity of an item are available in inventory when customer add items to cart
CREATE TRIGGER check_inventory_for_items
BEFORE UPDATE ON inventoryitem_adds_ordercart
FOR EACH ROW
BEGIN

DECLARE available_stock_quantity INT;
DECLARE current_order_status VARCHAR(50);


SELECT order_status
INTO current_order_status
FROM order_cart
WHERE order_id = NEW.order_id;

IF current_order_status <> 'open' THEN
SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only an open cart can be updated.';
END IF;

SELECT sku_stock
INTO available_stock_quantity
FROM inventory_item
WHERE sku = NEW.sku;

IF available_stock_quantity IS NULL THEN
SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'SKU does not exist in inventory.';
END IF;


IF NEW.quantity > available_stock_quantity THEN
SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Requested quantity exceeds available stock.';
END IF;
END **

DELIMITER ;

        

-- TESTING ---------------------------


  INSERT INTO customer (email) VALUES
('jenny@gmail.com'),
('alexis@gmail.com'),
('maria@gmail.com'),
('noah@gmail.com'),
('ava@gmail.com'),
('ethan@gmail.com');

INSERT INTO customer_info
(customer_id, first_name, last_name, street1, street2, city, state, zip_code, country)
VALUES
(1, 'Jenny', 'Morgan', '8795 Worthy St', NULL, 'Boston', 'MA', 21089, 'USA'),
(2, 'Alexis', 'Turner', '5900 Willow Tree St', NULL, 'Savannah', 'GA', 31401, 'USA'),
(3, 'Maria', 'Lopez', '78 Braunfels St', 'Apt 2B', 'Austin', 'TX', 73301, 'USA'),
(4, 'Noah', 'Bennett', '820 Ohio Dr', NULL, 'Columbus', 'OH', 43215, 'USA'),
(5, 'Ava', 'Collins', '9358 Sunny Isle Dr', 'Unit 14', 'Miami', 'FL', 33101, 'USA'),
(6, 'Ethan', 'Reed', '902 Trumpet Sound St', NULL, 'Charlotte', 'NC', 28202, 'USA');

INSERT INTO inventory_item
(item_name, furniture_type, brand, description, color, price, length, width, weight, material, shape, size_name, softness, diameter, furniture_style, sku_stock, last_restock)
VALUES
('Bodo Platform Bed Queen', 'bed', 'Bodo', 'Low profile queen platform bed', 'walnut', 899.99, 85.00, 63.00, 140, 'walnut', 'rectangular', 'queen', NULL, NULL, 'platform', 6, '2026-03-20'),
('Sela Memory Foam Mattress Queen', 'mattress', 'Sela', 'Queen memory foam mattress', 'white', 649.99, 80.00, 60.00, 88, 'memory foam', 'rectangular', 'queen', 'medium', NULL, NULL, 10, '2026-03-21'),
('Vid Accent Chair', 'chair', 'Vid', 'Upholstered accent chair', 'cream', 329.99, 32.00, 30.00, 42, 'fabric', 'square', NULL, NULL, NULL, 'accent', 12, '2026-03-19'),
('Noro Coffee Table Round', 'table', 'Noro', 'Round coffee table with oak top', 'natural', 259.99, NULL, NULL, 38, 'oak', 'round', NULL, NULL, 36.00, 'coffee', 8, '2026-03-18'),
('Luma Writing Desk', 'desk', 'Luma', 'Minimal writing desk for office use', 'black', 419.99, 48.00, 24.00, 55, 'metal', 'rectangular', NULL, NULL, NULL, 'office', 7, '2026-03-22'),
('Kivo Nightstand', 'nightstand', 'Kivo', 'Compact bedroom nightstand', 'brown', 149.99, 20.00, 18.00, 24, 'pine', 'square', NULL, NULL, NULL, 'bedroom', 15, '2026-03-17'),
('Tavi Dining Set Round', 'dining set', 'Tavi', 'Round dining set for four', 'espresso', 999.99, NULL, NULL, 210, 'wood', 'round', NULL, NULL, 48.00, 'dining', 4, '2026-03-15'),
('Mira Rug Soft', 'rug', 'Mira', 'Soft area rug for living room', 'ivory', 189.99, NULL, NULL, 18, 'synthetic fibers', 'oval', NULL, NULL, 72.00, 'living room', 11, '2026-03-23'),
('Oren Bar Chair', 'chair', 'Oren', 'Tall chair for kitchen island', 'gray', 219.99, 19.00, 20.00, 28, 'metal', 'square', NULL, NULL, NULL, 'bar', 9, '2026-03-16'),
('Pavo Desk Chair', 'chair', 'Pavo', 'Simple task chair for office desk', 'navy', 279.99, 24.00, 24.00, 31, 'fabric', 'square', NULL, NULL, NULL, 'office', 10, '2026-03-24'),
('Sori Full Bed Frame', 'bed', 'Sori', 'Full size canopy bed frame', 'black', 1099.99, 82.00, 57.00, 165, 'iron', 'rectangular', 'full', NULL, NULL, 'canopy', 3, '2026-03-14'),
('Vela Side Table', 'table', 'Vela', 'Small side table for living room', 'white', 119.99, 18.00, 18.00, 14, 'glass', 'round', NULL, NULL, 18.00, 'side', 13, '2026-03-20');


INSERT INTO furniture_piece
(warehouse_location, sku)
VALUES
('A1', 1),
('A1', 1),
('A1', 1),
('A2', 2),
('A2', 2),
('A2', 2),
('B1', 3),
('B1', 3),
('B2', 4),
('B2', 4),
('C1', 5),
('C1', 5),
('C2', 6),
('C2', 6),
('D1', 7),
('D1', 7),
('D2', 8),
('D2', 8),
('E1', 9),
('E1', 9),
('E2', 10),
('E2', 10),
('F1', 11),
('F1', 11),
('F2', 12),
('F2', 12);

INSERT INTO order_cart
(customer_id, order_date, delivery_date, order_status)
VALUES
(1, '2026-03-01 10:15:00', '2026-03-08 10:15:00', 'delivered'),
(2, '2026-03-02 13:20:00', '2026-03-09 13:20:00', 'delivered'),
(3, '2026-03-03 09:45:00', '2026-03-10 09:45:00', 'delivered'),
(4, '2026-03-04 16:30:00', '2026-03-11 16:30:00', 'delivered'),
(5, '2026-03-05 11:10:00', '2026-03-12 11:10:00', 'delivered'),
(6, '2026-03-06 14:25:00', '2026-03-13 14:25:00', 'delivered'),
(1, '2026-03-10 12:00:00', '2026-03-17 12:00:00', 'delivered'),
(2, '2026-03-12 15:40:00', '2026-03-19 15:40:00', 'delivered'),
(3, '2026-03-15 08:30:00', '2026-03-22 08:30:00', 'delivered'),
(4, '2026-03-18 17:05:00', '2026-03-25 17:05:00', 'delivered'),
(5, NULL, NULL, 'open'),
(6, '2026-03-20 18:15:00', '2026-03-27 18:15:00', 'cancelled');

INSERT INTO inventoryitem_adds_ordercart
(sku, order_id, quantity)
VALUES
(1, 1, 1),
(2, 1, 1),
(7, 2, 1),
(8, 2, 1),
(5, 3, 1),
(10, 3, 1),
(6, 4, 1),
(11, 4, 1),
(3, 5, 1),
(9, 5, 2),
(4, 6, 1),
(12, 6, 1),
(8, 7, 1),
(12, 7, 1),
(3, 8, 1),
(9, 8, 1),
(1, 9, 1),
(5, 9, 1),
(2, 10, 1),
(4, 10, 1),
(6, 11, 1),
(7, 12, 1);

INSERT INTO review (customer_id, sku, review) VALUES
(1, 1, 'Honestly I was nervous ordering a bed frame online but this one surprised me. It looks high quality, not cheap at all, and once it is set up it does not move or creak. Took a bit of patience to assemble though.'),
(1, 2, 'This mattress is incredibly comfortable overall. I noticed my sleep improved a little after a few nights.'),
(1, 8, 'The rug is nice but the color was a little off compared to the pictures. Not a dealbreaker, just something to be aware of. It still looks good in my space and feels soft.'),
(2, 7, 'Really happy with this dining set!! It fits perfectly in my apartment and does not feel flimsy at all. I have had people over already and everyone commented on how nice it looks. Im a happy customer'),
(2, 8, 'It is a decent rug. Not super thick but not terrible either. It does what I need it to do which is tying the room together, just do not expect anything super plush and comfortable'),
(2, 3, 'The chair looks great but comfort wise it is just okay. Fine for sitting for a bit but I would not use it for long work sessions so if you are looking for an aesthetic piece without caring for comfort this is a good option'),
(2, 9, 'These bar chairs were actually better than I expected. They feel solid and the height is perfect for my counter. Im writing this sentence to reach mininum character for the review'),
(3, 5, 'I like the look of this desk a lot, it is very simple and clean. It works well for studying and my laptop setup, but I did notice it scratches a little easier than I would like so just be careful'),
(3, 10, 'This chair is alright. It rolls smoothly and looks nice but I wish it had more support for my back. After a couple hours I definitely feel it.'),
(3, 1, 'The bed frame actually got delivered broken and not only did the company give me a refund but they also ordered another to my house, once it arrived I was surprised by the high quality of the bed frame. It might last a century or more!'),
(4, 6, 'The nightstand is fine. The drawers feel a little lightweight but it works and the size is exactly what I needed for my space.'),
(4, 11, 'This bed frame is beautiful, like genuinely a statement piece but putting it together was a process. Took me way longer than expected. Once it is up though, it feels very sturdy so I am happy'),
(4, 2, 'This mattress took a few nights to get used to but now I actually like it. It is supportive without being too firm. Not perfect, but definitely comfortable enough.'),
(5, 3, 'MY FAVORITE CHAIR!! I got this chair mostly for how it looks and it delivers. It is comfortable for and just gorgeous, I have gotten many compliments on it'),
(5, 9, 'One of the chairs had a small scuff when it arrived but it was not too noticeable. Overall they feel stable and look good in our vacation home so I am satisfied.'),
(6, 4, 'This table honestly made my living room look more put together. It feels solid and the finish looks splendid in person. Definitely one of my better purchases recently.'),
(6, 12, 'Simple side table but very useful. I use it next to my couch and it works perfectly, the material feels great too. I would buy it again');

