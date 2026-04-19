import pymysql
import re
import hashlib

connection = pymysql.connect(
    host="localhost",
    user="user",
    password="password27",
    database="Jenny_Morgan_CRM",
    cursorclass=pymysql.cursors.DictCursor
)

pattern = r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'


def clear_results(cur):
    while cur.nextset():
        pass


def fetch_function_value(cur, query, params=None):
    cur.execute(query, params or ())
    row = cur.fetchone()
    return list(row.values())[0] if row else None


def standardize_item_name(item_name):
    return " ".join(word.capitalize() for word in item_name.strip().split())


def hash_password(password):
    return hashlib.sha256(password.encode()).hexdigest()


def prompt_account_type():
    account_type = input("Enter account type (customer/business): ").strip().lower()

    if account_type == "customer":
        return True
    elif account_type == "business":
        return False
    else:
        print("\nINVALID ACCOUNT TYPE, please try again.")
        return None


def print_catalog(rows):
    if not rows:
        print("No items found.\n")
        return

    print("\n********************************************* STORE CATALOG ***********************************************\n")
    print(f"{'Item Name':35} {'Price':10} {'Type':15} {'Material':20} {'Description':20}")
    print("***********************************************************************************************************")

    for row in rows:
        print(f"{row['item_name']:35} ${row['price']:<9} {row['furniture_type']:15} {row['material']:20} {row['description']:20}")

    print()


def print_order_history(rows):
    if not rows:
        print("No order history found.\n")
        return

    print("\n*********************************** ORDER HISTORY ***********************************\n")

    current_order_id = None
    previous_row = None

    for row in rows:
        if row['order_id'] != current_order_id:
            if previous_row is not None:
                print(f"Order Total: ${previous_row['order_total']}")
                print("***************************************************************************************\n")

            current_order_id = row['order_id']
            print(f"Order ID: {row['order_id']}")
            print(f"Order Status: {row['order_status']}")
            print(f"Order Date: {row['order_date']}")
            print(f"Delivery Date: {row['delivery_date']}")
            print("***************************************************************************************")

        print(f"Item: {row['item_name']}")
        print(f"Brand: {row['brand']}")
        print(f"Type: {row['furniture_type']}")
        print(f"Quantity: {row['quantity']}")
        print(f"Price: ${row['price']}")
        print(f"Item Total: ${row['line_total']}")
        print("***************************************************************************************")

        previous_row = row

    if previous_row is not None:
        print(f"Order Total: ${previous_row['order_total']}")
        print("***************************************************************************************")

    print()


def print_cart(rows):
    if not rows:
        print("Your cart is empty.\n")
        return

    print("\n*********************************** YOUR CART ****************************************\n")

    for row in rows:
        print(f"Item: {row['item_name']}")
        print(f"Quantity: {row['quantity']}")
        print(f"Price: ${row['price']}")
        print(f"Item Total: ${row['line_total']}")
        print("***************************************************************************************")

    print(f"Order Total: ${rows[-1]['order_total']}")
    print()


def print_self_reviews(rows):
    if not rows:
        print("No reviews found.\n")
        return

    print("\n************************************ REVIEWS ************************************\n")
    for row in rows:
        print(f"Review ID: {row['review_id']}")
        print(f"Item: {row['item_name']}")
        print(f"Star Rating: {row['star_rating']}")
        print(f"Review: {row['review']}")
        print("***************************************************************************************")
    print()


def print_all_item_reviews(rows):
    if not rows:
        print("No reviews found.\n")
        return

    print("\n*********************************** ITEM REVIEWS ***********************************\n")
    print(f"Item Name: {rows[0]['item_name']}\n")
    print("*****************************************************************************************")
    for row in rows:
        print(f"Customer: {row['first_name']}")
        print(f"Order Date: {row['order_date']}")
        print(f"Review: {row['review']}")
        print("*****************************************************************************************")
    print()


def print_eligible_reviews(rows):
    if not rows:
        print("No eligible items for review.\n")
        return

    print("\n******************************** ELIGIBLE REVIEW ITEMS ********************************\n")

    for row in rows:
        print(f"Item: {row['item_name']}")
        print(f"Brand: {row['brand']}")
        print(f"Type: {row['furniture_type']}")
        print(f"Delivery Date: {row['delivery_date']}")
        print("***************************************************************************************")

    print()


def print_customer_info(rows):
    if not rows:
        print("No customer info found.\n")
        return

    row = rows[0]

    print("\n************************ CUSTOMER INFORMATION ************************\n")
    print(f"Email: {row['email']}")
    print(f"Name: {row['first_name'].strip()} {row['last_name'].strip()}")
    print(f"Address: {row['street1'].strip()}{', ' + row['street2'].strip() if row['street2'] else ''}, {row['city'].strip()}, {row['state'].strip()} {row['zip_code']}, {row['country'].strip()}")
    print(f"Total Orders: {row['total_orders']}")
    print(f"Total Reviews: {row['total_reviews']}\n")


def signup_or_login(cur):
    while True:
        customer_email = input("Input your email: ").strip().lower()

        if not re.match(pattern, customer_email) or not customer_email:
            print("\nINVALID EMAIL, please try again.")
            continue

        account_flag = prompt_account_type()
        if account_flag is None:
            continue

        email_exists = fetch_function_value(
            cur,
            "SELECT check_customer_email(%s) AS email_exists",
            (customer_email,)
        )

        if email_exists:
            password = input("Enter your password: ").strip()

            login_valid = fetch_function_value(
                cur,
                "SELECT check_user_login(%s, %s, %s) AS login_valid",
                (customer_email, password, account_flag)
            )

            if not login_valid:
                print("\nINVALID EMAIL, PASSWORD, OR ACCOUNT TYPE.")
                continue

            customer_id = fetch_function_value(
                cur,
                "SELECT get_customer_id_by_login(%s, %s, %s) AS customer_id",
                (customer_email, password, account_flag)
            )

            return customer_id, account_flag

        else:
            create_new = input("No account found. Create one? (y/n): ").strip().lower()
            if create_new != "y":
                continue

            password = input("Create a password: ").strip()
            if len(password) <= 12:
                print("\nPASSWORD MUST BE AT LEAST 13 CHARACTERS.")
                continue


            try:
                cur.callproc('create_customer', [customer_email, password, account_flag])
                clear_results(cur)
                connection.commit()

                customer_id = fetch_function_value(
                    cur,
                    "SELECT get_customer_id_by_login(%s, %s, %s) AS customer_id",
                    (customer_email, password, account_flag)
                )

                print("\nNew account created successfully!")
                return customer_id, account_flag

            except Exception as e:
                clear_results(cur)
                print("Error:", e)
                continue


def customer_portal(cur, customer_id):
    exit_var = False
    order_id = None

    while not exit_var:
        menu_1_option = input(
            "\nPlease choose a menu item to continue:"
            "\n1: Check Account Details"
            "\n2: Browse Store"
            "\n3: Exit\n"
        ).strip()

        if menu_1_option not in ("1", "2", "3"):
            print("\nINVALID MENU OPTION, please try again.")
            continue

        if menu_1_option == "1":
            while not exit_var:
                menu_2_option = input(
                    "\nPlease choose a menu item to continue:"
                    "\n1: View Customer Information"
                    "\n2: View Eligible Review Items"
                    "\n3: View Order History"
                    "\n4: Return to previous menu"
                    "\n5: Exit\n"
                ).strip()

                if menu_2_option not in ("1", "2", "3", "4", "5"):
                    print("\nINVALID MENU OPTION, please try again.")
                    continue

                if menu_2_option == "1":
                    try:
                        cur.callproc('show_customer_info', [customer_id])
                        customer_info = cur.fetchall()
                        print_customer_info(customer_info)
                        clear_results(cur)
                    except Exception as e:
                        clear_results(cur)
                        print("Error:", e)
                        continue

                    menu_3_option = input(
                        "\nPlease choose a menu item to continue:"
                        "\n1: Return to previous menu"
                        "\n2: Exit\n"
                    ).strip()

                    if menu_3_option not in ("1", "2"):
                        print("\nINVALID MENU OPTION, please try again.")
                        continue

                    if menu_3_option == "2":
                        exit_var = True

                    continue

                if menu_2_option == "2":
                    while not exit_var:
                        try:
                            cur.callproc('get_customer_products_eligible_for_review', [customer_id])
                            eligible_products = cur.fetchall()
                            print_eligible_reviews(eligible_products)
                            clear_results(cur)
                        except Exception as e:
                            clear_results(cur)
                            print("Error:", e)
                            break

                        menu_4_option = input(
                            "\nPlease choose a menu item to continue:"
                            "\n1: Review item"
                            "\n2: View Written Reviews"
                            "\n3: Return to previous menu"
                            "\n4: Exit\n"
                        ).strip()

                        if menu_4_option not in ("1", "2", "3", "4"):
                            print("\nINVALID MENU OPTION, please try again.")
                            continue

                        if menu_4_option == "1":
                            item_name_for_review = standardize_item_name(input("\nPlease enter item name to review: "))
                            input_item_valid_review = fetch_function_value(
                                cur,
                                "SELECT is_item_eligible_for_review(%s, %s) AS valid_review",
                                (customer_id, item_name_for_review)
                            )

                            if not input_item_valid_review:
                                print("This item is not eligible for review.")
                                input("Press enter to continue: ")
                                continue

                            star_rating_input = input("Please enter a rating from 1 to 5: ").strip()
                            if not star_rating_input.replace(".", "", 1).isdigit():
                                print("\nINVALID STAR RATING, please try again.")
                                input("Press enter to continue: ")
                                continue

                            star_rating = float(star_rating_input)
                            if star_rating <= 0 or star_rating > 5:
                                print("\nINVALID STAR RATING, please try again.")
                                input("Press enter to continue: ")
                                continue

                            review = input("Please enter a review. Min. 100 characters & Max. 999 characters: ").strip()
                            if len(review) > 999 or len(review) < 100:
                                print("\nINVALID CHARACTER COUNT, please try again.")
                                input("Press enter to continue: ")
                                continue

                            try:
                                cur.callproc('create_review', [customer_id, item_name_for_review, review, star_rating])
                                clear_results(cur)
                                connection.commit()
                                print("Review successfully posted!")
                                input("Press enter to continue: ")
                            except Exception as e:
                                clear_results(cur)
                                print("Error:", e)

                            continue

                        if menu_4_option == "2":
                            while not exit_var:
                                try:
                                    cur.callproc('get_customer_written_reviews', [customer_id])
                                    customer_written_reviews = cur.fetchall()
                                    print_self_reviews(customer_written_reviews)
                                    clear_results(cur)
                                    valid_review_ids = [row['review_id'] for row in customer_written_reviews]
                                except Exception as e:
                                    clear_results(cur)
                                    print("Error:", e)
                                    break

                                menu_5_option = input(
                                    "\nPlease choose a menu option:"
                                    "\n1: Update a Written Review"
                                    "\n2: Delete a Written Review"
                                    "\n3: Return to Previous Menu"
                                    "\n4: Exit\n"
                                ).strip()

                                if menu_5_option not in ("1", "2", "3", "4"):
                                    print("\nINVALID MENU OPTION, please try again.")
                                    continue

                                if menu_5_option == "1":
                                    review_id = input("Please enter the review_id you want to update: ").strip()

                                    if not review_id.isdigit() or int(review_id) not in valid_review_ids:
                                        print("\nINVALID REVIEW ID, please try again.")
                                        input("Press enter to continue: ")
                                        continue

                                    menu_review = input(
                                        "\nWhat would you like to update?\n"
                                        "1. Review text\n"
                                        "2. Star rating\n"
                                        "Please enter a menu_option: "
                                    ).strip()

                                    if menu_review == "1":
                                        new_review_text = input(
                                            "Please enter the new review text. Min. 100 characters & Max. 999 characters: "
                                        ).strip()

                                        if len(new_review_text) > 999 or len(new_review_text) < 100:
                                            print("\nINVALID CHARACTER COUNT, please try again.")
                                            input("Press enter to continue: ")
                                            continue

                                        try:
                                            cur.callproc('update_review', [int(review_id), customer_id, new_review_text])
                                            clear_results(cur)
                                            connection.commit()
                                            print("\nReview successfully updated!")
                                            input("Press enter to continue: ")
                                        except Exception as e:
                                            clear_results(cur)
                                            print("Error:", e)
                                            input("Press enter to continue: ")

                                    elif menu_review == "2":
                                        new_star_rating_input = input(
                                            "Please enter the new star rating from 1 to 5: "
                                        ).strip()

                                        if not new_star_rating_input.replace(".", "", 1).isdigit():
                                            print("\nINVALID STAR RATING, please try again.")
                                            input("Press enter to continue: ")
                                            continue

                                        new_star_rating = float(new_star_rating_input)
                                        if new_star_rating <= 0 or new_star_rating > 5:
                                            print("\nINVALID STAR RATING, please try again.")
                                            input("Press enter to continue: ")
                                            continue

                                        try:
                                            cur.callproc('update_star_rating', [int(review_id), customer_id, new_star_rating])
                                            clear_results(cur)
                                            connection.commit()
                                            print("\nStar rating successfully updated!")
                                            input("Press enter to continue: ")
                                        except Exception as e:
                                            clear_results(cur)
                                            print("Error:", e)
                                            input("Press enter to continue: ")

                                    else:
                                        print("\nINVALID MENU OPTION, please try again.")
                                        input("Press enter to continue: ")
                                        continue

                                if menu_5_option == "2":
                                    review_id = input("Please enter the review_id you want to delete: ").strip()

                                    if not review_id.isdigit() or int(review_id) not in valid_review_ids:
                                        print("\nINVALID REVIEW ID, please try again.")
                                        input("Press enter to continue: ")
                                        continue

                                    try:
                                        cur.callproc('delete_review', [int(review_id), customer_id])
                                        clear_results(cur)
                                        connection.commit()
                                        print("\nReview successfully deleted!")
                                        input("Press enter to continue: ")

                                    except Exception as e:
                                        clear_results(cur)
                                        print("Error:", e)

                                    continue

                                if menu_5_option == "3":
                                    break

                                if menu_5_option == "4":
                                    exit_var = True
                                    break

                            continue

                        if menu_4_option == "3":
                            break

                        if menu_4_option == "4":
                            exit_var = True
                            break

                    continue

                if menu_2_option == "3":
                    try:
                        cur.callproc('get_customer_order_history', [customer_id])
                        order_history_rows = cur.fetchall()
                        print_order_history(order_history_rows)
                        clear_results(cur)
                    except Exception as e:
                        clear_results(cur)
                        print("Error:", e)

                    menu_order_history = input(
                        "\nPlease choose a menu item to continue:"
                        "\n1: Return to previous menu"
                        "\n2: Exit\n"
                    ).strip()

                    if menu_order_history not in ("1", "2"):
                        print("\nINVALID MENU OPTION, please try again.")
                        continue

                    if menu_order_history == "2":
                        exit_var = True

                    continue

                if menu_2_option == "4":
                    break

                if menu_2_option == "5":
                    exit_var = True
                    break

            continue

        if menu_1_option == "2":
            while not exit_var:
                cur.execute("SELECT * FROM catalog_summary ORDER BY item_name")
                catalog_rows = cur.fetchall()
                print_catalog(catalog_rows)

                browse_option = input(
                    "\nPlease choose a menu item to continue:"
                    "\n1: Add to cart"
                    "\n2: View reviews"
                    "\n3: View current order cart"
                    "\n4: Return to previous menu"
                    "\n5: Exit\n"
                ).strip()

                if browse_option not in ("1", "2", "3", "4", "5"):
                    print("\nINVALID MENU ITEM, please try again.")
                    continue

                if browse_option == "1":
                    quantity = 1
                    item_name = standardize_item_name(input("Please enter the item name: "))

                    try:
                        if order_id is None:
                            cur.callproc('create_order_cart', [customer_id])
                            result = cur.fetchall()
                            clear_results(cur)

                            if result:
                                order_id = result[0]['new_order_id']
                            else:
                                order_id = fetch_function_value(
                                    cur,
                                    "SELECT get_open_order_id(%s) AS order_id",
                                    (customer_id,)
                                )

                        cur.callproc('upsert_cart_item', [order_id, item_name, quantity])
                        clear_results(cur)
                        connection.commit()
                        print("\nItem successfully added in cart!")
                        input("Press enter to continue: ")

                    except Exception as e:
                        clear_results(cur)
                        print("Error:", e)

                    continue

                if browse_option == "2":
                    item_name = standardize_item_name(input("Please enter the item name to view reviews: "))

                    try:
                        cur.callproc('read_item_reviews', [item_name])
                        item_reviews = cur.fetchall()
                        print_all_item_reviews(item_reviews)
                        clear_results(cur)
                    except Exception as e:
                        clear_results(cur)
                        print("Error:", e)

                    input("Press enter to continue: ")
                    continue

                if browse_option == "3":
                    order_id = fetch_function_value(
                        cur,
                        "SELECT get_open_order_id(%s) AS order_id",
                        (customer_id,)
                    )

                    if order_id is None:
                        print("\nYou do not currently have an open cart. Add an item to create one.")
                        input("Press enter to continue: ")
                        continue

                    try:
                        cur.callproc('view_order_cart', [order_id])
                        order_rows = cur.fetchall()
                        clear_results(cur)

                        if not order_rows:
                            order_id = None
                            continue

                        print_cart(order_rows)
                    except Exception as e:
                        clear_results(cur)
                        print("Error:", e)
                        continue

                    cart_option = input(
                        "\nPlease choose a menu item to continue:"
                        "\n1: Update quantity"
                        "\n2: Delete item"
                        "\n3: Checkout"
                        "\n4: Return to browse menu"
                        "\n5: Exit\n"
                    ).strip()

                    if cart_option == "1":
                        item_name = standardize_item_name(input("Please enter the item name to update: "))
                        quantity_input = input("Please enter how many more items you'd like to add: ").strip()

                        if not quantity_input.isdigit() or int(quantity_input) <= 0:
                            print("\nINVALID QUANTITY, please try again.")
                            continue

                        try:
                            cur.callproc('upsert_cart_item', [order_id, item_name, int(quantity_input)])
                            clear_results(cur)
                            connection.commit()
                            print("\nCart updated successfully!")
                            input("Press enter to continue: ")

                        except Exception as e:
                            clear_results(cur)
                            print("Error:", e)

                        continue

                    if cart_option == "2":
                        item_name = standardize_item_name(input("Please enter the item name to delete: "))

                        try:
                            cur.callproc('delete_cart_item', [order_id, item_name])
                            clear_results(cur)
                            connection.commit()
                            print("Item deleted from cart successfully!")
                            input("Press enter to continue: ")

                        except Exception as e:
                            clear_results(cur)
                            print("Error:", e)

                        continue

                    if cart_option == "3":
                        first_name = input("First name: ").strip()
                        last_name = input("Last name: ").strip()
                        street1 = input("Street address line 1: ").strip()
                        street2 = input("Street address line 2 (optional): ").strip() or None
                        city = input("City: ").strip()
                        state = input("State: ").strip()
                        zip_code = input("Zip code: ").strip()
                        country = input("Country: ").strip()

                        if not first_name or not last_name or not street1 or not city or not state or not country or not zip_code.isdigit():
                            print("\nALL REQUIRED FIELDS MUST BE FILLED IN WITH VALID INPUT. Try again.")
                            input("Press enter to continue: ")
                            continue

                        try:
                            cur.callproc('create_customer_info', [
                                customer_id, first_name, last_name, street1, street2,
                                city, state, int(zip_code), country
                            ])
                            clear_results(cur)

                            cur.callproc('checkout_order', [order_id])
                            clear_results(cur)
                            connection.commit()

                            delivery_date = fetch_function_value(
                                cur,
                                "SELECT delivery_date FROM order_cart WHERE order_id = %s",
                                (order_id,)
                            )

                            if delivery_date:
                                formatted_date = delivery_date.strftime('%B %d, %Y')
                            else:
                                formatted_date = "an estimated delivery date. Check your email for details."

                            print(f"\nOrder checked out successfully! Your order will be here by {formatted_date}")
                            input("Press enter to continue: ")

                        except Exception as e:
                            clear_results(cur)
                            print("Error:", e)

                        continue

                    if cart_option == "4":
                        continue

                    if cart_option == "5":
                        exit_var = True
                        break

                    print("\nINVALID MENU OPTION, please try again.")
                    continue

                if browse_option == "4":
                    break

                if browse_option == "5":
                    open_order_id = fetch_function_value(
                        cur,
                        "SELECT get_open_order_id(%s) AS order_id",
                        (customer_id,)
                    )

                    if open_order_id is not None:
                        try:
                            cur.callproc('cancel_open_cart_on_exit', [open_order_id])
                            clear_results(cur)
                            connection.commit()
                        except Exception:
                            clear_results(cur)

                    exit_var = True
                    break

            continue

        if menu_1_option == "3":
            open_order_id = fetch_function_value(
                cur,
                "SELECT get_open_order_id(%s) AS order_id",
                (customer_id,)
            )

            if open_order_id is not None:
                try:
                    cur.callproc('cancel_open_cart_on_exit', [open_order_id])
                    clear_results(cur)
                    connection.commit()
                except Exception:
                    clear_results(cur)

            exit_var = True
            break


def main():
    cursor = connection.cursor()
    print("\nConnected successfully!\n")

    try:
        customer_id, is_customer_account = signup_or_login(cursor)

        if not is_customer_account:
            print("\nBusiness account login successful.")
            print("Business menu is not implemented yet in this terminal version.")
            return

        customer_portal(cursor, customer_id)

    except Exception as e:
        clear_results(cursor)
        print("Error:", e)

    finally:
        try:
            cursor.close()
        except Exception:
            pass
        connection.close()
        print("\nSee you next time!\n")


if __name__ == "__main__":
    main()