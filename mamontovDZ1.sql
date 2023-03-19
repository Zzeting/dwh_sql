-- расширяем диапозон значений varchar в аттрибуте "name"
update pg_catalog.pg_attribute set atttypmod = 254
where attrelid = 'dim.product'::regclass and attname = 'name'

-- расширяем диапозон значений varchar в аттрибуте "artist"
update pg_catalog.pg_attribute set atttypmod = 254
where attrelid = 'dim.product'::regclass and attname = 'artist'



-- Задание № 1
insert into dim.product (code, name, artist, product_type, product_category, unit_price, unit_cost, status, effective_ts, expire_ts, is_current)
with author as (
	select distinct ftsa.film_id, array_to_string(array_agg(fsa."name"), ', ') as author
	from nds.films_to_script_author ftsa
	join nds.films_script_author fsa on fsa.id = ftsa.script_author_id
	group by 1
)
select f.id::varchar as code,
	f.title as name,
	coalesce(au.author, 'Неизвестно') as artist,
	'Фильмы' as product_type,
	coalesce(fc."name", 'Неизвестно') as product_category,
	f.price as unit_price,
	f."cost" as unit_cost,
	CASE
      when f.status = 'p' then 'Ожидается'
      when f.status = 'o' then 'Доступен'
      when f.status = 'e' then 'Не продаётся'
  END AS status,
	f.start_ts as effective_ts,
	f.end_ts as expire_ts,
	f.is_current as is_current
from nds.films f 
left join author au on au.film_id = f.id 
left join nds.films_category fc on fc.id = f.category_id 

select * from dim.product p 


-- Задание № 2

--добавляем новый атрибут
alter table dim.customer
add column subscriber_class varchar(25);


update dim.customer as dc
set subscriber_class = subq.subscriber_class
from
(select t.id as id, 
	case 
		when t.perc < 25 then 'R1'
		when t.perc < 50 then 'R2'
		when t.perc < 75 then 'R3'
		when t.perc >= 75 then 'R4'
	end as subscriber_class
from (
	with cte1 as(
		select distinct(si.customer_id) as id, coalesce(
			coalesce(sum(f.price), 0) + coalesce(sum(m.price), 0) + coalesce(sum(b.price),0) , 0) as item_sum 
		from nds.sale_item si 
		left join nds.films f on si.film_id = f.id 
		left join nds.music m on si.music_id = m.id 
		left join nds.book b on si.book_id = b.id 
		where si.dt between	
			(select max(si.dt) - interval '3 months'from nds.sale_item si) and
			(select max(si.dt) as date_end from nds.sale_item si)
		group by si.customer_id
		order by si.customer_id),
	cte2 as(
		select distinct(cs.customer_id) as id, coalesce(sum(s.price), 0) as sub_sum
		from nds.customers_subscriptions cs 
		join nds.subscriptions s on cs.subscription_id = s.id  
		where cs."date" between 
			(select max(cs."date") - interval '3 months' from nds.customers_subscriptions cs)  and 
			(select max(cs."date") from nds.customers_subscriptions cs)
		group by cs.customer_id 
		order by cs.customer_id)
	select c.id as id, ((coalesce(item_sum, 0) + coalesce(sub_sum, 0)) * 4) * 100. / 
			(max((coalesce(item_sum, 0) + coalesce(sub_sum, 0)) * 4) over ()) as perc
	from dim.customer c
	full outer join cte2 on c.id = cte2.id
	full outer join cte1 on c.id = cte1.id) as t) as subq
where dc.id = subq.id

select * from dim.customer c 
