select bookings.now() as now;


--select airport_name::json->>'en'as airport
select airport_name ->> lang() AS city
from airports_data
where airport_code = 'YKS'
;
-----------------------------------------------------------------------
-- 1. � ����� ������� ������ ������ ���������?
-- �����: ������, ���������
select city::json->>'en'city, count(airport_code) 
from airports_data
group by city
having count(airport_code) > 1
--info -> city ->> 'en'
;
select airport_name ->> lang() AS city

-- 2. � ����� ���������� ���� �����, ������� ������������� ���������� � ������������ ���������� ���������?
-- �����: AER, DME, OVB, PEE, SVO, SVX, VKO (�� departure_airport, ������ arrival_airport ���������, ����� �� ��������?)

--������� 1 (limit)
with cte1_aircraft as (
select aircraft_code
from aircrafts_data
order by range desc
limit 1
)
select distinct arrival_airport as airport, airport_name::json->>'en'as name
from flights a
inner join airports_data b on a.departure_airport = b.airport_code
inner join aircrafts_data using(aircraft_code)
where aircraft_code = (select aircraft_code
from cte1_aircraft)
order by arrival_airport
;

-- ������� 2 (��������� � max)
with cte2_aircraft as (
select aircraft_code
from aircrafts_data
where range = (select max(range) from aircrafts_data)
)
select distinct arrival_airport as airport, airport_name::json->>'en'as name
from flights a
inner join airports_data b on a.departure_airport = b.airport_code
inner join aircrafts_data using(aircraft_code)
where aircraft_code = (select aircraft_code
from cte2_aircraft)
order by arrival_airport
;

/*
select distinct arrival_airport, aircraft_code
from flights a
inner join airports_data b on a.departure_airport = b.airport_code
inner join aircrafts_data using(aircraft_code)
where aircraft_code = '773'
order by arrival_airport
-- departure_airport, flight_no, arrival_airport
*/

-- 3.���� �� �����, �� ������� �� ����������� ��������?
-- �����: ��, ���� (366 298 ����)
--? ����� �� ���������� ���������? COUNT(DISTINCT column) ���������� ���������� ��������� �����, �������� ������� ������� �� ����� NULL)

--select count(*)
select distinct book_ref
from ticket_flights
left join boarding_passes using(ticket_no)
join tickets using(ticket_no)
where boarding_no is null
;

------------------------
--� ��������� ���������� �� �������� (�� ����������? ��� ������� ���������� ������ null) 
select status, count(book_ref)
from bookings
join tickets using(book_ref)
join ticket_flights using(ticket_no)
-- ��� ��������� �������
join flights using(flight_id)
left join boarding_passes using(ticket_no)
--join flights using(ticket_flights.flight_id)
where boarding_no is null
group by status
order by status
;

-- �� ������� � ��� �� �����������
--select book_ref, ticket_no, ticket_flights.flight_id, status
select status, count(book_ref)
from ticket_flights
join flights using(flight_id)
left join boarding_passes using(ticket_no)
join tickets using(ticket_no)
--where ticket_no = '0005432293273'
--join flights using(flight_id)
where boarding_no is null
group by status
order by status
;

-- ������� ������------------------------------------------------------------
--- ���-�� ������� �� �������� ���������, ��� ������� ��� ���������� �������
select status, count(ticket_no)
from ticket_flights
join flights using(flight_id)
left join boarding_passes using(ticket_no)
--where ticket_no = '0005432293273'
--join flights using(flight_id)
where boarding_no is null
group by status
;

select *
from bookings 
join tickets using(book_ref)
join ticket_flights using(ticket_no)
--join boarding_passes using(ticket_no)
--order by book_ref
join flights using(flight_id)
where ticket_no = '0005432081600'
--where book_ref = '5B06E8'
;

select *
from flights
where flight_id = 12926 or flight_id = 33134 or flight_id = 44913 or flight_id = 45432
;

select *
from bookings 
where book_ref = '383816'
;

select *
from tickets 
where ticket_no = '0005434504712'
;

select *
from bookings 
join tickets using(book_ref)
join ticket_flights using(ticket_no)
join flights using(flight_id)
where status = 'Scheduled' or status = 'Cancelled'
order by book_ref
;

-- 4. �������� ����� ������� ��������� ���������� % ���������?
-- �����: ����� ��������� 100, 
create or replace view model_flights as 
select model::json->>'en' as model, round(cf/(sum(cf) over())*100,0) as percent
from (
select aircraft_code, model, count(flight_id) as cf
from aircrafts_data
join flights using(aircraft_code)
join ticket_flights using(flight_id)
group by aircraft_code
order by cf desc
)
as CC
limit 1
;

select *
from model_flights
;

drop view model_flights
;

---------------------------------------------------
select aircraft_code, model, count(flight_id) as cf
from aircrafts_data
join flights using(aircraft_code)
join ticket_flights using(flight_id)
group by aircraft_code
order by cf DESC
;

--���������� �� ��������� � ������� �������� ������
select status, count(flight_id)
from aircrafts_data
join flights using(aircraft_code)
join ticket_flights using(flight_id)
group by status
;

select status, count(flight_id)
from flights
group by status
;

-- 5. ���� �� ������, � ������� ����� ��������� ������-������� �������, ��� ������-�������?
-- �����: ���
------ https://issue.life/questions/50027658
------ https://postgrespro.ru/docs/postgrespro/9.5/functions-conditional

--refresh materialized view flights_v

create view amount_fc as
select departure_city, arrival_city, sum(
case when rank=1 then min_am
		else - min_am
		end) as diff
from (
with cte_arrival_city as
(
(select distinct departure_city, arrival_city, fare_conditions, min(amount) over (partition by departure_city, arrival_city, fare_conditions)  as min_am
from 
ticket_flights
join flights_v using(flight_id)
where fare_conditions in ('Economy'))
union all
(select distinct departure_city, arrival_city, fare_conditions, min(amount) over (partition by departure_city, arrival_city, fare_conditions)  as min_am
from 
ticket_flights
join flights_v using(flight_id)
where fare_conditions in ('Business'))
order by departure_city, arrival_city, fare_conditions)
select departure_city, arrival_city, fare_conditions, min_am, row_number() over (partition by departure_city, arrival_city) as rank
from cte_arrival_city
)
cc
where rank in (1,2)
group by departure_city, arrival_city
having count(*)>1
;

select arrival_city
from amount_fc
where diff < 0
;
-- ��� ��������� 2 ������� � ����?
drop view amount_fc;

-----------------------------------------------------------------------------------------------
-- ������������� ������� (������� 2 ������ �� �����������, �� � ���������� rank; ��� ��������� �������? ����� - ��� �������� � ����� �� ����������� min ��������� �� economy?)
create view amount_fc as
select *
from (
with cte_arrival_city as (
select distinct departure_city, arrival_city, flight_no, fare_conditions, amount
from 
ticket_flights
join flights_v using(flight_id)
where fare_conditions in ('Economy','Business')
order by departure_city, arrival_city, fare_conditions, amount
) 
--select departure_city, arrival_city, flight_no, fare_conditions, amount, row_number() over (partition by flight_no, fare_conditions order by fare_conditions, amount) as rank
select departure_city, arrival_city, flight_no, fare_conditions, amount, 
row_number() over (partition by departure_city, arrival_city, fare_conditions order by amount) as rank
--min(amount) over (partition by departure_city, arrival_city, fare_conditions) as min_amount
--row_number() over (partition by fare_conditions order by fare_conditions, amount) as rank, 
--min(amount) over (partition by fare_conditions order by fare_conditions, amount) as min_amount
from cte_arrival_city
order by departure_city, arrival_city, fare_conditions
)
--order by flight_no)
CC
where rank = 1
;

-- ������ ����� sum �� ������� � ����� rank ���� ������ �����:
create view amount_fc as
select departure_city, arrival_city, sum(
case when rank=1 then amount
		else - amount
		end) as diff
from (
with cte_arrival_city as (
select distinct departure_city, arrival_city, flight_no, fare_conditions, amount
from 
ticket_flights
join flights_v using(flight_id)
where fare_conditions in ('Economy','Business')
order by departure_city, arrival_city, fare_conditions, amount
) 
--select departure_city, arrival_city, flight_no, fare_conditions, amount, row_number() over (partition by flight_no, fare_conditions order by fare_conditions, amount) as rank
select departure_city, arrival_city, fare_conditions, flight_no, amount, 
row_number() over (partition by departure_city, arrival_city, fare_conditions order by amount) as rank 
--min(amount) over (partition by departure_city, arrival_city, fare_conditions) as min_amount
from cte_arrival_city
order by departure_city, arrival_city, rank
)
CC
where rank = 1
group by departure_city, arrival_city
having count(*)>1
;
/*�� ������ ����������� 1 ��� 2 ������ � ��� ����������. ����� ��������� �������, ��������� ������ � 1 ���������*/ ��� ��������� �������, ����� ��������� �������

----
create view amount_fc as
select *
from (
with cte_arrival_city as (
select distinct departure_city, arrival_city, flight_no, fare_conditions, amount
from 
ticket_flights
join flights_v using(flight_id)
where fare_conditions in ('Economy','Business')
order by departure_city, arrival_city, fare_conditions, amount
) 
--select departure_city, arrival_city, flight_no, fare_conditions, amount, row_number() over (partition by flight_no, fare_conditions order by fare_conditions, amount) as rank
select departure_city, arrival_city, fare_conditions, flight_no, amount, 
row_number() over (partition by departure_city, arrival_city, fare_conditions order by amount) as rank, 
min(amount) over (partition by departure_city, arrival_city, fare_conditions) as min_amount
from cte_arrival_city
order by departure_city, arrival_city, fare_conditions
--order by flight_no)
)
CC
where rank = 1
;
----

-- 6. ������ ������������ ����� �������� ������� ���������
-- �����: ����������� ����� �������� ������� ��������� 16860 ������ (4 ���� 41 ������ ��� 4,68 ����)
-- ��������� ����� � ����� �� ��������� round (diff - double preccision)
-- SELECT pg_typeof(diff) - ������� ��� ������ ���� ����������
-- http://www.sql-tutorial.ru/ru/book_datediff_function/page2.html
-- � ��������:
with cte_delay as (
select *
from
(
select flight_id, flight_no, scheduled_departure_local, actual_departure_local,
extract(epoch from age(actual_departure_local, scheduled_departure_local)) as diff
from flights_v
where status in ('Departed', 'Arrived')
)
CC
order by diff desc)
select '������������ ����� �������� �������: ' || max(diff) ||' ������' as delay
from cte_delay
;

-- � �����:
with cte_delay as (
select *
from
(
select flight_id, flight_no, scheduled_departure_local, actual_departure_local,
round((extract(epoch from age(actual_departure_local, scheduled_departure_local))/3600)::numeric,2) as diff
from flights_v
where status in ('Departed', 'Arrived')
)
CC
order by diff desc)
select '������������ ����� �������� �������: ' || max(diff) ||' ���.' as delay
from cte_delay
;

-----------------------------------------------------------------------------
/* ��� ��������� � ���� (� �������� �� ���), �� ��������������� � ������� (86400 ��� - ��� 1 ����)
select flight_id, flight_no, scheduled_departure, departure_airport, departure_airport_name, departure_city, actual_departure, 
extract(epoch from (date(actual_departure)::timestamp-date(scheduled_departure)::timestamp)) as diff
from flights_v
where status in ('Departed', 'Arrived')
order by diff DESC
;
-- ������� ���������: extract(epoch from age(clock_timestamp(), scheduled_departure_local)) / 3660
-----
select status, count(status)
--select *
from flights_v
where actual_departure is null
group by status
;
*/

-- 7. ����� ������ �������� ��� ������ ������?
-- �����: ��. ���������� ���������� �������
-- ��� ��������� ������� ���������� right outher join - only rows from the right table
-- ����� - �����������, ������ - ���������
-- ������  

create or replace view dir_po 
as
select distinct (da.city::json->>'en')::text || ' - ' || (aa.city::json->>'en')::text AS direction 
--da.city::json->>'en'as dep_city, aa.city::json->>'en'as ar_city
--da.city::json->>'en' aa.city::json->>'en'as direction --da.airport_code, aa.airport_code, da.airport_name::json->>'en'as dep_name, aa.airport_name::json->>'en'as ar_name
from airports_data da
cross join airports_data aa
where da.airport_code<>aa.airport_code and da.city <> aa.city
order by direction
;
create or replace view dir_ac 
as
select distinct (da.city::json->>'en')::text || ' - ' || (aa.city::json->>'en')::text AS direction 
--da.city::json->>'en'as dep_city, aa.city::json->>'en'as ar_city
from flights f
join airports_data da on f.departure_airport = da.airport_code
join airports_data aa on f.arrival_airport = aa.airport_code
-- order by dep_city, ar_city
order by direction
;

select distinct po.direction --ac.direction,
from dir_ac ac
right join dir_po po on ac.direction = po.direction
where ac.direction is null


----------------------------------------------------
create or replace view dir_pos 
as
select distinct (da.city::json->>'en')::text || ' - ' || (aa.city::json->>'en')::text AS direction 
--da.city::json->>'en'as dep_city, aa.city::json->>'en'as ar_city
--da.city::json->>'en' aa.city::json->>'en'as direction --da.airport_code, aa.airport_code, da.airport_name::json->>'en'as dep_name, aa.airport_name::json->>'en'as ar_name
from airports_data da
cross join airports_data aa
where da.airport_code<>aa.airport_code and da.city <> aa.city
order by direction
--order by dep_city, ar_city
-- �������� ������ ��������� ����������� �������� (10704 ������)
;

select *
from dir_po
;

drop view dir_po
;

-- ��� ������������ ����� �������� � fligths (65664 ������, ���. ��������� ��������� - ���� ������� (����� �����), �� � ������ �����)
create or replace view dir_act 
as
select distinct (da.city::json->>'en')::text || ' - ' || (aa.city::json->>'en')::text AS direction 
--da.city::json->>'en'as dep_city, aa.city::json->>'en'as ar_city
from flights f
join airports_data da on f.departure_airport = da.airport_code
join airports_data aa on f.arrival_airport = aa.airport_code
-- order by dep_city, ar_city
order by direction
;

select *
from dir_ac
;

drop view dir_ac
;
----------------------------------------------------

-- 8. ����� ������ �������� ��������� ������ ���������*? (*/���������: ��������� � ��������� ������������� ����� 1 �����)

--https://habr.com/ru/post/269497/ ����������� ������� � PostgreSQL (WITH RECURSIVE)
--https://habr.com/ru/post/340460/ ������� array_agg(MyColumn)
--https://postgrespro.ru/docs/postgrespro/11/functions-json
--https://qa-help.ru/questions/postgres-obedinenie-dvukh-stolbczov-v-odin-element

create or replace view flights_transfers 
as
select * 
from (
select flight_id, ticket_no, scheduled_departure::timestamp, scheduled_arrival::timestamp, departure_city, arrival_city,
--select flight_id, ticket_no, scheduled_departure::date, scheduled_arrival::date, departure_city, arrival_city,
row_number() over (partition by ticket_no) as rownum,
count(flight_id) over (partition by ticket_no) as c_transfers
from ticket_flights
join flights_v using(flight_id)
order by ticket_no, scheduled_departure, scheduled_arrival
)
CC
where c_transfers > 1
-- �������� ������ ������� � ����������� ����������
;

select *
from flights_transfers
;

drop view flights_transfers;

select ticket_no, json_agg(jsonb_build_array(scheduled_departure, scheduled_arrival)) as time_transfers, flights_transfers.c_transfers  ---- ����� ������ � ������� � ���� ������
--, pg_typeof(json_agg(jsonb_build_array(scheduled_departure, scheduled_arrival)))
--select ticket_no, json_agg(scheduled_departure) as dep ---- ����� ������ � ������� � ���� ������
from flights_transfers
where ticket_no = '0005432001918'
group by ticket_no
;


select *
from ticket_flights
left join boarding_passes using(ticket_no)
join tickets using(ticket_no)
where book_ref='5B06E8'
--where boarding_no is not null
--order by book_ref, ticket_no
;



SELECT any_flights.ticket_no,
    any_flights.flight_id,
    any_flights.flight_no,
    any_flights.scheduled_departure,
    any_flights.scheduled_arrival,
    any_flights.departure_city,
    any_flights.arrival_city,
    any_flights.numberrow,
    any_flights.count_flight
select *
   FROM ( SELECT ticket_flights.ticket_no,
            ticket_flights.flight_id,
            flights_v.flight_no,
            flights_v.scheduled_departure,
            flights_v.scheduled_arrival,
            flights_v.departure_city,
            flights_v.arrival_city,
            row_number() OVER (PARTITION BY ticket_flights.ticket_no ORDER BY flights_v.scheduled_departure) AS numberrow,
            count(ticket_flights.flight_id) OVER (PARTITION BY ticket_flights.ticket_no) AS count_flight
           FROM ticket_flights
             JOIN flights_v USING (flight_id)) any_flights
  WHERE any_flights.count_flight > 2
  ORDER BY any_flights.ticket_no, any_flights.numberrow


-- 9. ��������� ���������� ����� �����������, ���������� ������� �������, �������� � ���������� ������������ ���������� ��������� � ���������, ������������� ��� �����** 
-- �����: ��. ���������� ������ ������� (��� ���� ����������� ������� ���������� ����� ����������� ������ ���������� ������������ ��������� ��������� ��������� �� ���� ���������)
/* ** - ���������� ���������� ����� ����� ������� A � B �� ������ ����������� (���� ������� �� �� �����) ������������ ������������:
d = arccos {sin(latitude_a)�sin(latitude_b) + cos(latitude_a)�cos(latitude_b)�cos(longitude_a - longitude_b)}, ��� latitude_a � latitude_b � ������, longitude_a, longitude_b � ������� ������ �������, d � ���������� ����� ��������, ���������� � �������� ������ ���� �������� ����� ������� ����.
���������� ����� ��������, ���������� � ����������, ������������ �� �������:
L = d�R, ��� R = 6371 �� � ������� ������ ������� ����.
��� ������� ���������� ����� ��������, �������������� � ������ ���������� (��������-�����, ���������-��������) , ����� (�) � ��������������� ���������� (������ ��� �������) ������ ���� �������.
*/

with cte_check as (
select distinct f.departure_airport, f.arrival_airport, 
round(6371*acos(
sin(da.coordinates[1]*pi()/180)*sin(aa.coordinates[1]*pi()/180) + 
cos(da.coordinates[1]*pi()/180)*cos(aa.coordinates[1]*pi()/180)*cos(da.coordinates[0]*pi()/180-aa.coordinates[0]*pi()/180)
)::numeric,0) as dist,
ac.range as range -- ac.aircraft_code, model::json->>'en'as model
from flights f
join airports_data da on f.departure_airport = da.airport_code
join airports_data aa on f.arrival_airport = aa.airport_code
join aircrafts_data ac using (aircraft_code)
)
select departure_airport, arrival_airport, dist, range, range-dist as diff
from cte_check
order by diff
;

---
/*select city, coordinates[0], coordinates[1], coordinates[0] * pi()/180 as long 
from airports
;

select city, coordinates[0], coordinates[1], coordinates[0] * pi()/180 as long 
from airports_data
;

select  f.departure_airport, f.arrival_airport, da.coordinates, aa.coordinates
from flights f
join airports_data da on f.departure_airport = da.airport_code
join airports_data aa on f.arrival_airport = aa.airport_code
where departure_airport = 'AAQ'
;
*/

-----------------------------------------
select s.aircraft_code, s.fare_conditions, count(*) as num
from seats s
group by s.aircraft_code, s.fare_conditions
order by s.aircraft_code, s.fare_conditions
;
