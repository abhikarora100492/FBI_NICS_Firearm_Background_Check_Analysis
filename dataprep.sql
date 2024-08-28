/* Pivot data from wide to long format */ 
drop table if exists #gun_backgroundchecks
SELECT 
    t.month,
    t.state,
    v.background_check_category,
	case when v.background_check_category in ('issuance', 'redemption', 'rentals', 'private_sale', 'returned') then 'in' else 'out' end possession_type,
    coalesce(case when v.handgun = '' then null else v.handgun end,0) handgun,
    coalesce(case when v.long_gun = '' then null else v.long_gun end,0) long_gun,
    coalesce(case when v.other = '' then null else v.other end,0) other,
    coalesce(CASE WHEN v.background_check_category = 'issuance' THEN t.multiple ELSE NULL END,0) AS multiple
into #gun_backgroundchecks
FROM master.dbo.[nics-firearm-background-checks] t
CROSS APPLY (
    VALUES 
        ('issuance', t.handgun, t.long_gun, t.other),
        ('prepawn', t.prepawn_handgun, t.prepawn_long_gun, t.prepawn_other),
        ('redemption', t.redemption_handgun, t.redemption_long_gun, t.redemption_other),
        ('returned', t.returned_handgun, t.returned_long_gun, t.returned_other),
        ('rentals', t.rentals_handgun, t.rentals_long_gun, NULL),
        ('private_sale', t.private_sale_handgun, t.private_sale_long_gun, t.private_sale_other),
        ('return_to_seller', t.return_to_seller_handgun, t.return_to_seller_long_gun, t.return_to_seller_other)
) v(background_check_category, handgun, long_gun, other)
where cast(left(month,4) as int) >= 2014
ORDER BY t.month, t.state, v.background_check_category;

/* Statistical analysis to deetrmine the days with the highest frequency more than 90% of monthly volume */
drop table if exists #backgroundcheck_stats
SELECT 
	month,
	state,
	total,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total) OVER () AS median_total,
	PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY total) OVER () AS percentile_75
into #backgroundcheck_stats
FROM 
(
select month
,state
,sum(handgun+long_gun+other+multiple) total
from #gun_backgroundchecks
where possession_type != 'out'
group by month
,state
)a
ORDER BY state;

select month
,count(*) Num_States_W_Outlier_BackgroundChecks
from 
(
SELECT 
	month,
	state,
	total,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total) OVER () AS median_total,
	PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY total) OVER () AS percentile_75
FROM 
(
select month
,state
,sum(handgun+long_gun+other+multiple) total
from #gun_backgroundchecks
where possession_type != 'out'
group by month
,state
)a
)b
where total > percentile_75
group by month
