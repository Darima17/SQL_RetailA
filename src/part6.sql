DROP FUNCTION IF EXISTS fnc_personal_offers_cross_selling;

------------------------- Part 6 function: fnc_personal_offers_cross_selling --------------
CREATE OR REPLACE FUNCTION fnc_personal_offers_cross_selling(
        groups_count int, 
        max_churn_rate numeric, 
        max_stability_index numeric,
        max_part_sku numeric, 
        margin_part numeric)
RETURNS table(
    Customer_ID bigint,
    SKU_Name varchar,
    Offer_Discount_Depth int)
LANGUAGE plpgsql
AS $$
BEGIN
RETURN QUERY
WITH groups_selection  as (
    SELECT
        VG.customer_id,
        VG.group_id,
        (VG.group_minimum_discount * 100)::int / 5 * 5 + 5 as group_minimum_discount,
        row_number() OVER w as rank_affinity
    FROM  groups_view AS VG
    WHERE VG.group_churn_rate <= max_churn_rate
        AND VG.group_stability_index < max_stability_index
    WINDOW w as (PARTITION BY VG.customer_id ORDER BY VG.group_affinity_index DESC)
    ),
margin_sku_determ as (
    SELECT
        GC.customer_id,
        GC.group_id,
        GC.group_minimum_discount,
        ST.sku_retail_price - ST.sku_purchase_price as margin,
        row_number() OVER w1 as rank_margin,
        ST.sku_id,
        CV.Customer_Primary_Store as customer_primary_store
    FROM groups_selection  GC
    JOIN customers_view CV ON GC.rank_affinity <= groups_count
        AND GC.customer_id = CV.Customer_ID
    JOIN sales_stores ST ON CV.Customer_Primary_Store = ST.transaction_store_id
    JOIN product_matrix PM ON GC.group_id = PM.group_id
        AND ST.sku_id = PM.sku_id 
    WINDOW w1 as (PARTITION BY GC.customer_id, GC.group_id
        ORDER BY ST.sku_retail_price - ST.sku_purchase_price DESC)
        ),
sku_share_in_groups as (
    SELECT
        B.customer_id,
        B.group_id,
        B.sku_id,
        (SELECT count(DISTINCT CH.transaction_id) FROM purchase_history_view PHV
        JOIN checks CH ON PHV.customer_id = B.customer_id
            AND PHV.group_id = B.group_id
            AND PHV.transaction_id = CH.transaction_id
            AND CH.sku_id = B.sku_id)::numeric
        / (SELECT PV.group_purchase FROM period_view PV
            WHERE PV.customer_id = B.customer_id
              AND PV.group_id = B.group_id) as part_sku_in_groups,
        B.group_minimum_discount,
        B.customer_primary_store
    FROM margin_sku_determ B
    WHERE rank_margin = 1
    ),
calc_discount as (
    SELECT
        C.customer_id,
        C.group_id,
        C.sku_id,
        C.group_minimum_discount,
        (SELECT sum(ST.sku_retail_price - ST.sku_purchase_price) / sum(ST.sku_retail_price) * margin_part
         FROM sales_stores ST WHERE ST.transaction_store_id = C.customer_primary_store) as allowable_discount
    FROM sku_share_in_groups C
    WHERE C.part_sku_in_groups * 100 <= max_part_sku)

SELECT
    F.customer_id::bigint,
    PM.sku_name::varchar,
    F.group_minimum_discount::int
FROM calc_discount F
JOIN product_matrix PM ON F.sku_id = PM.sku_id
WHERE F.group_minimum_discount <= F.allowable_discount;
END;
$$;

-------------------------------tests ---------------------------------------------

SELECT * FROM fnc_personal_offers_cross_selling (5, 3, 0.5, 100, 30);

SELECT * FROM fnc_personal_offers_cross_selling (5, 3, 0.5, 100, 50);