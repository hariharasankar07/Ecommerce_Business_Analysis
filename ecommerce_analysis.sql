create database ecommerce_analysis;
use ecommerce_analysis;
-- 2. Table Creation
-- create customer table
create table customers(
customer_id int primary key,
customer_name varchar(100),
city varchar(50),
state varchar(50),
signup_date date
);
-- create products table;
create table products (
product_id int primary key,	
product_name varchar(100),	
category varchar (50),
price decimal (10,2)
);
-- create orders table 
create table orders (
order_id int primary key,	
customer_id	int,
product_id	int,
order_date	date,
quantity	int,
unit_price	decimal(10,2),
discount_pct decimal (5,2),	
sales	decimal (12,2),
profit decimal (12,2),
foreign key (customer_id)
references customers(customer_id),
foreign key (product_id)
references products(product_id) 
);
-- create returns table
create table returns(
return_id int primary key,
order_id int,	
return_date	date,
return_reason varchar(50),
foreign key (order_id)
references orders(order_id)
); 
-- create payments table
create table payments (
payment_id int primary key,	
order_id int,	
payment_method varchar(30),	
payment_status varchar(20),
foreign key(order_id)
references orders(order_id)
);
show tables;

-- 3. Data Validation 
select count(*) as total_customers from customers;
-- Data Validation
select 'customers' as table_name, count(*) as row_count
from customers
union all
select 'orders', count(*) from orders
union all 
select 'payments', count(*) from payments
union all 
select'products', count(*)  from products
union all
select 'returns', count(*) from returns;
-- null values checking
select count(*) as total_rows,
count(customer_id) as customer_ids, 
count(product_id) as product_ids,
count(order_date) as order_dates,
count(sales) as sales_values,
count(profit) as profit_values
from orders; -- checked no Null values
-- checking duplicates in order_id
select order_id,
count(*) as duplicate_count
from orders
group by order_id
having count(*) > 1;

-- 4. Relationship Checking
select count(*) as invalid_customer_orders 
from orders o left join customers c on
o.customer_id = c.customer_id
where c.customer_id is null; 

select count(*) as invalid_customer_orders 
from orders o left join products p on
o.product_id = p.product_id
where p.product_id is null;

select count(*) as invalid_payment_orders
from orders o left join payments pa on
o.order_id = pa.order_id
where pa.order_id is null;

-- 5. Business Analysis 
-- total sales
select sum(sales) as total_sales from orders;
-- total profit
select sum(profit) as total_profit from orders;
-- Busniess questions
-- Q1 How much total revenue did the business generate, how much profit did it make ?
select sum(sales) as total_revenue,
sum(profit) as total_profit
from orders

-- Q2 Which customers generate the hightest revenue for the business, and how many orders have they placed ?
select
c.customer_id, 
c.customer_name,
sum(o.sales)as highest_revenue,
count(o.order_id) as no_of_orders  
from orders o join customers c on
o.customer_id = c.customer_id
group by c.customer_id, c.customer_name
order by highest_revenue desc limit 10;

-- Q3 Which products generate the hightest sales revenue for the business?
select 
p.product_id, 
p.product_name, 
sum(o.sales) as total_sales_revenue
from orders o inner join products p  on
o.product_id = p.product_id
group by p.product_id, p.product_name
order by total_sales_revenue desc limit 10;

-- Q4 Which product categories generate the highest sales and profit for the buisness?
select 
p.category as product_category, 
sum(o.sales) as total_sales, 
sum(o.profit) as total_profit
from products p inner join orders o on
p.product_id = o.product_id 
group by product_category
order by total_sales desc, total_profit desc;

-- Q5 What percentage of orders were returned, and which product have the highest return rate?
select 
p.product_id as product_id, 
p.product_name as product_name,
count(distinct o.order_id) as total_orders, count(distinct r.order_id) as returned_orders,
round(count(distinct r.order_id) * 100.0 /count(distinct o.order_id),2) as returned_rate
from products p inner join orders o on
p.product_id = o.product_id
left join returns r on 
o.order_id = r.order_id
group by product_id, product_name
having count(distinct o.order_id) >= 10
order by returned_rate desc
limit 10; 

-- Q6 Which payments menthods have the highest payment faliure?
select 
payment_method, 
count(distinct payment_id) as total_payments, 
sum( case when payment_status = 'failed'then 1 else 0 end ) as total_payments_failed,
round(sum(case when payment_status = 'failed'then 1 else 0 end ) * 100.0 / count(*),2) as payment_failed_rate
from payments 
group by payment_method
order by payment_failed_rate desc, total_payments_failed desc;

-- Q7 How do monthly sales and profit change overtime?
select
 monthname(order_date) as month,
sum(sales) as total_sales,
sum(profit) as total_profit
from orders
group by month(order_date), monthname(order_date) 
order by month(order_date);

-- Q8 Compared to the previous month, did sales increase or decrease, and by how much?
with monthly_sales as (
select monthname(order_date) as month,
month(order_date) as month_number,
sum(sales) as total_sales
from orders
group by month(order_date),monthname(order_date)
),
monthly_analysis as (
select 
month, 
total_sales,month_number,
lag(total_sales) over (order by month_number) as previous_month_sales
from monthly_sales)
select
 month, 
 total_sales,
case 
when previous_month_sales is null then 'No previous month'
when total_sales > previous_month_sales then 'Increase'
when total_sales < previous_month_sales then 'Decrease' 
else 'Same' end as sales_status,
abs(total_sales - previous_month_sales) as difference
from monthly_analysis
order by month_number; 

-- Q9 Within each product category, which are the top 3 products by sales?
with product_ranking as (
select 
p.product_name as product_name,
p.category as category,
sum(o.sales) as total_sales,
rank() over (partition by p.category order by sum(o.sales) desc)  as sales_rank
from products p inner join orders o on
p.product_id = o.product_id 
group by product_name, category
)
select 
product_name, 
category, 
total_sales,
sales_rank
from product_ranking
where sales_rank <=3
order by category, sales_rank;

-- Q10 For each month, what is the total sales for the month and the rolling average sales of the current month plus the previous 2 months ?
with monthly_sales as (
select 
monthname(order_date) as month, 
month(order_date) as month_number, 
sum(sales) as total_sales
from orders
group by month, month_number
)
select
month, 
total_sales,
round(avg(total_sales) over (order by month_number rows between 2 preceding and current row),2) as rolling_3_month_avg
from monthly_sales
order by month_number;

-- Q11 Which cities generate the highest sales, and what percentage of total company sales is contributed by each city?
with city_sales as (
select 
c.city as city, 
sum(o.sales) as total_sales
from customers c inner join orders o on 
c.customer_id = o.customer_id
group by city
),
city_sales_pcnt as (
select 
city, 
total_sales, 
sum(total_sales) over() as company_total_sale
from city_sales
)
select 
city, 
total_sales,
round(total_sales / company_total_sales * 100,2) as sale_contribution_pcnt
from city_sales_pcnt
order by total_sales desc;

-- Q12 Based on total sales and profit, how can we divide products into four performance groups and which group contains the best-perfoming products?
with product_sales as (
select
p.product_name,
sum(o.sales) as total_sales,
sum(o.profit) as total_profit
from products p
inner join orders o
on p.product_id = o.product_id
group by
p.product_name
),
product_groups as (
select
product_name,
total_sales,
total_profit,
ntile(4) over (order by total_sales desc) as sales_group,
ntile(4) over (order by total_profit desc) as profit_group
from product_sales
)
select
product_name,
total_sales,
total_profit,
sales_group,
profit_group,
case
when sales_group = 1 and profit_group = 1 then 'top performer'
when sales_group = 1 and profit_group > 1 then 'high sales low profit'
when sales_group > 1 and profit_group = 1 then 'low sales high profit'
else 'low performer' end as performance_category
from product_groups
order by performance_category, total_sales desc;

-- Q13 For each month how many new customers made their first purchases in that month?
select
monthname(first_order) as cohort_month, 
count(*) as new_customers
from
( 
select 
customer_id, 
min(order_date) as first_order
from orders
group by customer_id) as customer_first_order
group by
month(first_order), monthname(first_order)
order by month(first_order);

-- Q14 Which products have high sales but ususllay low profit margins?
with product_metrics as (
select
p.product_id,
p.product_name,
sum(o.sales) as total_sales,
sum(o.profit) as total_profit
from products p
join orders o
on p.product_id = o.product_id
group by p.product_id, p.product_name
),
product_analysis as (
select
product_id,
product_name,
total_sales,
total_profit,
round((total_profit / nullif(total_sales, 0)) * 100,2) as profit_margin_pct
from product_metrics
),
company_average as (
select
avg(total_sales) as avg_sales,
avg(profit_margin_pct) as avg_profit_margin
from product_analysis
)
select
pa.product_id,
pa.product_name,
pa.total_sales,
pa.total_profit,
pa.profit_margin_pct,
round(ca.avg_sales, 2) as avg_sales,
round(ca.avg_profit_margin, 2) as avg_profit_margin
from product_analysis pa
cross join company_average ca
where pa.total_sales > ca.avg_sales
and pa.profit_margin_pct < ca.avg_profit_margin
order by pa.total_sales desc;

-- Q15 Which products lose the most potential profit because of returned orders?
with product_returns as (
select
p.product_id,
p.product_name,
sum(o.profit) as total_profit,
sum(
case
when r.order_id is not null
then o.profit
else 0
end
) as returned_profit
from products p
join orders o
on p.product_id = o.product_id
left join returns r
on o.order_id = r.order_id
group by
p.product_id,
p.product_name
)
select
product_id,
product_name,
total_profit,
returned_profit,
round(( returned_profit / nullif(total_profit, 0)) * 100,2 ) as return_profit_impact_pct
from product_returns
order by returned_profit desc;















