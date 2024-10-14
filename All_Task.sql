#1) Select distinct markets for "Atliq Exclusive" in the APAC region:
   SELECT DISTINCT market 
   FROM dim_customer 
   WHERE customer = 'Atliq Exclusive' 
   AND region = 'APAC';

#2) Calculate the percentage change in unique products between fiscal years 2020 and 2021:
   WITH unique_product_count AS (
       SELECT COUNT(DISTINCT CASE WHEN fiscal_year = 2020 THEN product_code END) AS unique_products_2020,
              COUNT(DISTINCT CASE WHEN fiscal_year = 2021 THEN product_code END) AS unique_products_2021
       FROM fact_sales_monthly
   )
   SELECT unique_products_2020,
          unique_products_2021,
          ROUND(((unique_products_2021 - unique_products_2020) / unique_products_2020) * 100, 2) AS percentage_change
   FROM unique_product_count;

#3) Retrieve segment-wise product count:
   SELECT segment, COUNT(DISTINCT product_code) AS product_count 
   FROM dim_product
   GROUP BY segment
   ORDER BY product_count DESC;

4) Retrieve segment-wise product count difference between 2020 and 2021:
   WITH p_count AS (
       SELECT p.segment,
              COUNT(DISTINCT CASE WHEN s.fiscal_year = 2020 THEN s.product_code END) AS product_count_2020,
              COUNT(DISTINCT CASE WHEN s.fiscal_year = 2021 THEN s.product_code END) AS product_count_2021
       FROM fact_sales_monthly s
       INNER JOIN dim_product p ON p.product_code = s.product_code
       GROUP BY segment
   )
   SELECT segment, product_count_2020, product_count_2021, 
          (product_count_2021 - product_count_2020) AS difference 
   FROM p_count
   ORDER BY difference DESC;

5) Retrieve products with the highest and lowest manufacturing cost:
   SELECT p.product_code, p.product, m.manufacturing_cost
   FROM dim_product p
   JOIN fact_manufacturing_cost m ON p.product_code = m.product_code
   WHERE m.manufacturing_cost = (SELECT MAX(manufacturing_cost) FROM fact_manufacturing_cost)
      OR m.manufacturing_cost = (SELECT MIN(manufacturing_cost) FROM fact_manufacturing_cost)
   ORDER BY m.manufacturing_cost DESC;

6) Retrieve the top 5 customers in India based on average pre-invoice discount percentage for 2021:
   WITH tbl1 AS (
       SELECT customer_code AS a, AVG(pre_invoice_discount_pct) AS b 
       FROM fact_pre_invoice_deductions
       WHERE fiscal_year = '2021'
       GROUP BY customer_code
   ),
   tbl2 AS (
       SELECT customer_code AS c, customer AS d 
       FROM dim_customer 
       WHERE market = 'India'
   )
   SELECT tbl2.c AS customer_code, tbl2.d AS customer, ROUND(tbl1.b, 4) AS average_discount_percentage
   FROM tbl1 
   JOIN tbl2 ON tbl1.a = tbl2.c
   ORDER BY average_discount_percentage
   LIMIT 5;

7) Retrieve monthly gross sales amount for "Atliq Exclusive" in each fiscal year:
   SELECT CONCAT(MONTHNAME(s.date), '(', YEAR(s.date), ')') AS 'month', s.fiscal_year,
          ROUND(SUM(s.sold_quantity * g.gross_price), 2) AS gross_sales_amount
   FROM fact_sales_monthly s
   JOIN fact_gross_price g ON s.product_code = g.product_code
   JOIN dim_customer c ON c.customer_code = s.customer_code
   WHERE c.customer = 'Atliq Exclusive'
   GROUP BY month, s.fiscal_year
   ORDER BY s.fiscal_year;

8) Retrieve quarterly total sold quantity for fiscal year 2020:
   SELECT CASE 
              WHEN MONTH(date) IN (9, 10, 11) THEN 'Q1'
              WHEN MONTH(date) IN (12, 1, 2) THEN 'Q2'
              WHEN MONTH(date) IN (3, 4, 5) THEN 'Q3'
              ELSE 'Q4'
          END AS quarter, 
          ROUND(SUM(sold_quantity) / 1000000, 2) AS total_sold_quantity_in_millions
   FROM fact_sales_monthly
   WHERE fiscal_year = '2020'
   GROUP BY quarter
   ORDER BY total_sold_quantity_in_millions DESC;

9) Retrieve sales by channel and calculate its percentage contribution to total sales in 2021:
   WITH tbl1 AS (
       SELECT c.channel, SUM(s.sold_quantity * g.gross_price) AS total_sales
       FROM fact_sales_monthly s
       JOIN fact_gross_price g ON s.product_code = g.product_code
       JOIN dim_customer c ON c.customer_code = s.customer_code
       WHERE s.fiscal_year = '2021'
       GROUP BY channel
   )
   SELECT channel, ROUND(total_sales / 1000000, 2) AS gross_sales_in_millions,
          ROUND(total_sales / SUM(total_sales) OVER () * 100, 2) AS percentage
   FROM tbl1;

10) Retrieve top 3 products in each division with the highest total sold quantity in 2021:
    WITH ranked_products AS (
        SELECT p.division, p.product, s.product_code,
               SUM(s.sold_quantity) AS total_sold_qty,
               RANK() OVER (PARTITION BY p.division ORDER BY SUM(s.sold_quantity) DESC) AS rank_order
        FROM fact_sales_monthly s
        JOIN dim_product p ON p.product_code = s.product_code
        WHERE s.fiscal_year = '2021'
        GROUP BY p.division, s.product_code, p.product
    )
    SELECT *
    FROM ranked_products
    WHERE rank_order IN (1, 2, 3)
    ORDER BY division, rank_order;
