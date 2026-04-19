# E-commerce Furniture Store CRM 

## Project Overview

This project is a Python host application connected to a MySQL database for a small e-commerce furniture store CRM system. The user is the e-commerce store customer. The system uses CRUD operations and supports features such as allowing a customer to enter an email, view account details, browse store inventory, add items to a cart, check out, and manage product reviews.

## Full CRUD Operations List

### Create
- create_customer: creates a new store customer
- create_customer_info: creates customer information for shipping and account access 
- create_order_cart: creates an order / cart 
- upsert_cart_item: adds a quanity of one of an item to cart
- create_review: creates a review on an eligible item

### Read
- show_customer_info: reads customer information
- catalog_summary (SELECT): store catalog for customer view
- view_order_cart: views a customers open order / cart
- get_customer_written_reviews: reads all of the reviews written by a customer
- read_item_reviews: reads all of the reviews posted to an item
- get_customer_products_eligible_for_review: reads all of the delivered products to a customer which are eligible for review (have not been reviewed yet)
- check_customer_email: reads a customers email to check if it exists in the database
- get_customer_id_by_email: returns a customers id when given an email
- get_open_order_id: returns a customers order id if it is open
- is_item_eligible_for_review: checks to see if an item is eligible for review

### Update
- create_customer_info: updates a customers information when checking out
- upsert_cart_item: updates an item quantity if already in card 
- update_review: updates a customer's written review
- checkout_order: updates order status 
- cancel_open_cart_on_exit: updates an orders status to cancelled if a customer has an open cart when they exit the application

### Delete
- delete_cart_item: deletes an item in a customers open order / cart
- delete_review: deletes a customer's written review

## Quick Start

1. Run `furniture_crm.sql` in MySQL Workbench  
2. Install dependencies: `pip install -r requirements.txt`  
3. Run: `python furniture_crm.py`  

## Project Files

The project folder should contain the following files:

1. `furniture_crm.py`  
   Python host application for running the CRM system.

2. `furniture_crm.sql`  
   SQL file that creates and populates the `Jenny_Morgan_CRM` database, including tables, views, functions, procedures, triggers, sample data, and the restricted database user used by the Python application.

3. `requirements.txt`  
   Python dependency file for installing required libraries.

4. `README.md`  
   Instructions for creating and running the project.

## Software Requirements

The following software must be installed on the computer before running the project:

1. Python 3  
2. MySQL Server  
3. MySQL Workbench or MySQL Command Line Client  

## Python Library Requirements

The Python application requires the following library:

```txt
PyMySQL
```

## Download Pages

Use the following download pages for required technologies:

1. Python 3  
   https://www.python.org/downloads/

2. MySQL Community Server  
   https://dev.mysql.com/downloads/mysql/

3. MySQL Workbench  
   https://dev.mysql.com/downloads/workbench/

4. PyMySQL  
   https://pypi.org/project/PyMySQL/

## Expected Installation Directories

The project may be stored in any directory on the local computer. Example locations:

### Windows
```text
C:\Users\YourName\Documents\Furniture_crm
```

### macOS
```text
/Users/YourName/Documents/Furniture_crm
```

Inside the project folder:

```text
Furniture_CRM_Project/
    furniture_crm.py
    furniture_crm.sql
    requirements.txt
    README.md
```

## Database Setup Instructions

1. Install MySQL Server.  
2. Install MySQL Workbench or use the MySQL Command Line Client.  
3. Open MySQL Workbench.  
4. Open the file `furniture_crm.sql`.  
5. Run the entire SQL script.  

This SQL file will:

- Create the `Jenny_Morgan_CRM` database  
- Create all required tables  
- Create views, functions, procedures, and triggers  
- Insert sample data  
- Create the restricted MySQL user used by the Python application  

## Python Setup Instructions

1. Open a terminal or command prompt.  
2. Navigate to the project folder.  

### Example (Windows)
```text
cd C:\Users\YourName\Documents\Furniture_CRM_Project
```

### Example (macOS)
```text
cd /Users/YourName/Documents/Furniture_CRM_Project
```

3. Install the required Python library:

```bash
pip install -r requirements.txt
```

## Running the Application

After the SQL script has been executed and dependencies are installed, run:

```bash
python3 furniture_crm.py
```

## Database Connection Information

The Python application connects using the following credentials defined in the SQL setup file:

```python
connection = pymysql.connect(
    host="localhost",
    user="user",
    password="password27",
    database="Jenny_Morgan_CRM",
    cursorclass=pymysql.cursors.DictCursor
)
```

The SQL setup file must be run first so that this database and user exist.

## Notes

- The program is a terminal-based application.  
- The SQL file must be run before starting the Python file.  
- The application assumes MySQL is running locally on `localhost`.  
- Sample data is automatically inserted by the SQL script.  
- The project is designed to run on a local machine.  