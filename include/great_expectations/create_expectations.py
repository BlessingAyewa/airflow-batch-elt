"""
Creates the orders expectation suite.
Run this once to generate the suite file.
Run with: python include/great_expectations/create_expectations.py
"""

import great_expectations as gx

context = gx.get_context(
    mode="file",
    project_root_dir="include/great_expectations"
)

order_suite = context.suites.add(
    gx.ExpectationSuite(name="orders_suite")
)

order_suite.add_expectation(
    gx.expectations.ExpectColumnValuesToNotBeNull(column="order_id")
)

order_suite.add_expectation(
    gx.expectations.ExpectColumnValuesToNotBeNull(column="customer_id")
)

order_suite.add_expectation(
    gx.expectations.ExpectColumnValuesToNotBeNull(column="order_date")
)

order_suite.add_expectation(
    gx.expectations.ExpectColumnValuesToBeBetween(
        column="amount",
        min_value=0,
    )
)

order_suite.add_expectation(
    gx.expectations.ExpectColumnValuesToBeInSet(
        column="status",
        value_set=["pending", "complete", "cancelled"],
    )
)

order_suite.add_expectation(
    gx.expectations.ExpectTableRowCountToBeBetween(
        min_value=1,
    )
)

context.suites.add_or_update(order_suite)
print("orders_suite created successfully")