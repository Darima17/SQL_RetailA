----- Administrator -----
DROP ROLE IF EXISTS Administrator;

CREATE ROLE Administrator;

GRANT pg_read_all_settings TO Administrator;

GRANT pg_signal_backend TO Administrator;

GRANT pg_read_all_data TO Administrator;

GRANT pg_write_all_data TO Administrator;

----- Visitor -----
DROP ROLE IF EXISTS Visitor;

CREATE ROLE Visitor;

GRANT pg_read_all_data TO Visitor;
------Example queries-----
-- SET ROLE Visitor;

-- SELECT * FROM customers;

-- SELECT * FROM transactions;

-- DELETE FROM customers WHERE customer_id = 1;

-- SET ROLE Administrator;