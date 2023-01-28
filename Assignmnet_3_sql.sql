WITH discount_order_count AS 
(
		SELECT product_id, discount, COUNT(DISTINCT order_id) as order_count
		FROM sale.order_item
		GROUP BY product_id, discount
),
	order_count_difference AS
(
		SELECT product_id, discount, order_count,
		LAG(order_count) OVER (PARTITION BY product_id ORDER BY discount) - order_count as order_count_difference
		FROM discount_order_count
)
		SELECT DISTINCT product_id,
			CASE
			WHEN order_count_difference > 0 THEN 'Positive'
			WHEN order_count_difference < 0 THEN 'Negative'
			ELSE 'Neutral'
			END as 'Discount Effect'
		FROM order_count_difference
		ORDER BY product_id;

