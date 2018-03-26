use GatherDD
go

--Create list of distinct IDs
drop table if exists #distinct_Ids

select distinct q2.id as plot_id
				,q2.latitude
				,q2.longitude
				,q2.altitude 
into #distinct_Ids
from tidy.q2 as q2

select d.*
from #distinct_Ids as d
order by d.plot_id

--Calc toilets per user by plot
drop table if exists #total_num_toilets
					,#total_toilet_users
					,#toilets_by_plot_final;

select q2.id
		,sum(cast(q2.no_of_toilets as int)) as total_num_toilets
into #total_num_toilets
from tidy.q2 as q2
group by q2.id

select q3.id as plot_id
		,sum(cast(q3.no_of_toilet_user as int)) as total_toilet_users
into #total_toilet_users
from tidy.q3 as q3
group by q3.id

select tt.id
		,tu.total_toilet_users
		,tt.total_num_toilets
		,(tu.total_toilet_users/tt.total_num_toilets) as users_per_toilet

into #toilets_by_plot_final
from #total_num_toilets as tt
join #total_toilet_users as tu
on tt.id = tu.plot_id
order by tt.id

select sum(tf.total_toilet_users)/sum(tf.total_num_toilets) as avg_number_users_per_toilet
from #toilets_by_plot_final as tf

--Create Toilet Risk Dataset
select distinct tf.*
		,q2.type_of_toilet
		,q2.type_of_property
		,q2.latitude
		,q2.longitude 
into #powerbi_1
from #toilets_by_plot_final as tf

join tidy.q2 as q2
on tf.id = q2.id

select p.*
		,Case	
			When (p.type_of_toilet = 'pit_latrine_lined' or p.type_of_toilet = 'pit_latrine_unlined' or p.type_of_toilet = 'UDDT' or p.type_of_toilet = 'VIP') then 3
			When (p.type_of_toilet = 'pour_flush_inside' or p.type_of_toilet = 'pour_flush_outside') then 2
			When (p.type_of_toilet = 'flush_inside' or p.type_of_toilet = 'flush_outside') then 1
			When (p.type_of_toilet = 'disused_buried') then 0
		 End as type_of_toilet_risk
		,Case	
			When p.users_per_toilet >= 20 then 3
			When (p.users_per_toilet > =10 and p.users_per_toilet <20) then 2
			When p.users_per_toilet < 10 then 1
		End as user_per_toilet_risk
into #powerbi_2
from #powerbi_1 as p

select p.*
		,(p.type_of_toilet_risk*p.user_per_toilet_risk) as compound_risk
into #powerbi_3
from #powerbi_2 as p

select p.id
		,max(p.compound_risk) as compound_risk
		,p.latitude
		,p.longitude
into #powerbi_4
from #powerbi_3 as p
group by p.id
		,p.latitude
		,p.longitude

select p.*
		,Case
			When p.compound_risk = 0 then 'Only has disused toilet'
			When p.compound_risk > 0 and p.compound_risk <= 3 then 'Green'
			When p.compound_risk > 3 and p.compound_risk <=6 then 'Amber'
			When p.compound_risk > 6 then 'Red'
		End as RAG_Status
from #powerbi_4 as p


--Number of type of toilet used
drop table if exists #distinct_id_toilet

select distinct q2.id 
				,q2.type_of_toilet
into #distinct_id_toilet
from tidy.q2 as q2

select q2.type_of_toilet
		,count(*) as number
from tidy.q2 as  q2
group by q2.type_of_toilet

--Average number of people per plot
drop table if exists #avg_num_ppl_plot;

select distinct q2.id as plot_id
				,cast(q2.no_of_ppl as float) as number_of_people
into #avg_num_ppl_plot
from tidy.q2 as q2
order by q2.id

select avg(number_of_people) as avg_num_ppl_plot
from #avg_num_ppl_plot


--% of household and non-household plots
drop table if exists #distinct_id_property;

select distinct q2.id 
				,q2.type_of_property
into #distinct_id_property
from tidy.q2 as q2

select count(*) as number_of_toilets
				,q2.type_of_property
from #distinct_id_property as q2
group by q2.type_of_property

--What is the average age of toilets?
drop table if exists #avg_age_stage;

select sum(cast(q4.age_toilet_1 as float)) + sum(cast(q4.age_toilet_2 as float)) + sum(cast(q4.age_toilet_3 as float)) as summed_ages
		,count(q4.age_toilet_1) + count(q4.age_toilet_2) + count(q4.age_toilet_3) as count_occurrence
into #avg_age_stage
from tidy.q4 as q4

select a.summed_ages/a.count_occurrence as avg_age_toilet
from #avg_age_stage as a

