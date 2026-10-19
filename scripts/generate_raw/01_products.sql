-- raw_products: product catalog (source emulation), 4 static rows.
-- Re-runnable: table is dropped and recreated on every run.

drop table if exists raw.raw_products;
create table raw.raw_products (
    product_id int,
    product_name varchar,
    product_type varchar,
    term_months int,
    annual_rate numeric(5,4)
);
insert into raw.raw_products (product_id, product_name, product_type, term_months, annual_rate)
values
(1, 'Cash Loan 6M', 'cash', 6, 0.4800),
(2, 'Cash Loan 12M', 'cash', 12, 0.4200),
(3, 'POS Loan 3M', 'pos', 3, 0.2400),
(4, 'POS Loan 6M', 'pos', 6, 0.3000);