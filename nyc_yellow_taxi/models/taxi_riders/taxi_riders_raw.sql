with source_data as (
    select * from read_parquet('yellow_tripdata_2026-01.parquet')
)

select * from source_data
