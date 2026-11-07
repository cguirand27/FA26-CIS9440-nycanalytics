-- Clean and standardize DOB NOW job filings data
-- One row per job filing

WITH source AS (
    SELECT * FROM {{ source('raw', 'source_nyc_dob_job_apps') }}
),

cleaned AS (
    SELECT
        -- Keep all other columns as-is (incl. filing dates, already TIMESTAMP,
        -- and all filing_representative_* columns needed later)
        * EXCEPT (
            filing_status, job_type, borough, postcode, zip,
            council_district, latitude, longitude, initial_cost, commmunity_board
        ),

        UPPER(TRIM(filing_status)) AS filing_status,
        UPPER(TRIM(job_type)) AS job_type,

        -- Conformed with 311: same borough values
        CASE
            WHEN UPPER(TRIM(borough)) IN ('MANHATTAN', 'NEW YORK COUNTY') THEN 'Manhattan'
            WHEN UPPER(TRIM(borough)) IN ('BRONX', 'THE BRONX') THEN 'Bronx'
            WHEN UPPER(TRIM(borough)) IN ('BROOKLYN', 'KINGS COUNTY') THEN 'Brooklyn'
            WHEN UPPER(TRIM(borough)) IN ('QUEENS', 'QUEEN', 'QUEENS COUNTY') THEN 'Queens'
            WHEN UPPER(TRIM(borough)) IN ('STATEN ISLAND', 'RICHMOND COUNTY') THEN 'Staten Island'
            ELSE 'UNKNOWN or CITYWIDE'
        END AS borough,

        -- Conformed with 311: job SITE zip (postcode) renamed to zip, cleaned to 5 digits
        CASE
            WHEN REGEXP_CONTAINS(TRIM(postcode), r'^\d{5}') THEN LEFT(TRIM(postcode), 5)
            ELSE NULL
        END AS zip,

        -- Raw "zip" is the owner's zip, renamed so it isn't confused with the site zip
        CAST(zip AS STRING) AS owner_zip,

        CAST(council_district AS STRING) AS council_district,
        CAST(latitude AS DECIMAL) AS latitude,
        CAST(longitude AS DECIMAL) AS longitude,

        -- Cost stored as text in raw; strip $ and commas, cast to number
        SAFE_CAST(REGEXP_REPLACE(initial_cost, r'[^0-9.]', '') AS NUMERIC) AS initial_cost,

        -- Fix typo in raw column name
        commmunity_board AS community_board,

        CURRENT_TIMESTAMP() AS _stg_loaded_at

    FROM source
    WHERE job_filing_number IS NOT NULL
      AND filing_date IS NOT NULL

    -- Deduplicate: keep the most recently updated record per filing
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY job_filing_number ORDER BY current_status_date DESC
    ) = 1
)

SELECT * FROM cleaned