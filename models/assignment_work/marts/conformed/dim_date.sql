-- Date dimension shared by DOT 311 service requests and DOB NOW job filings

WITH stg_311 AS (
    SELECT * FROM {{ ref('stg_nyc_311_dot') }}
),

stg_dob AS (
    SELECT * FROM {{ ref('stg_nyc_dob_job_filings') }}
),

all_dates AS (
    SELECT DISTINCT CAST(created_date AS DATE) AS full_date FROM stg_311 WHERE created_date IS NOT NULL
    UNION DISTINCT
    SELECT DISTINCT CAST(closed_date AS DATE) FROM stg_311 WHERE closed_date IS NOT NULL
    UNION DISTINCT
    SELECT DISTINCT CAST(filing_date AS DATE) FROM stg_dob WHERE filing_date IS NOT NULL
    UNION DISTINCT
    SELECT DISTINCT CAST(current_status_date AS DATE) FROM stg_dob WHERE current_status_date IS NOT NULL
    UNION DISTINCT
    SELECT DISTINCT CAST(first_permit_date AS DATE) FROM stg_dob WHERE first_permit_date IS NOT NULL
    UNION DISTINCT
    SELECT DISTINCT CAST(approved_date AS DATE) FROM stg_dob WHERE approved_date IS NOT NULL
    UNION DISTINCT
    SELECT DISTINCT CAST(signoff_date AS DATE) FROM stg_dob WHERE signoff_date IS NOT NULL
),

date_dimension AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['full_date']) }} AS date_key,
        full_date,
        EXTRACT(YEAR FROM full_date) AS year,
        EXTRACT(QUARTER FROM full_date) AS quarter,
        EXTRACT(MONTH FROM full_date) AS month,
        FORMAT_DATE('%B', full_date) AS month_name,
        EXTRACT(DAY FROM full_date) AS day_of_month,
        EXTRACT(DAYOFWEEK FROM full_date) AS day_of_week,
        FORMAT_DATE('%A', full_date) AS weekday_name,
        EXTRACT(DAYOFWEEK FROM full_date) IN (1, 7) AS is_weekend,
        CASE
            WHEN EXTRACT(MONTH FROM full_date) >= 7 THEN EXTRACT(YEAR FROM full_date) + 1
            ELSE EXTRACT(YEAR FROM full_date)
        END AS fiscal_year
    FROM all_dates
),

null_placeholder AS (
    SELECT
        '-1' AS date_key,
        CAST(NULL AS DATE) AS full_date,
        CAST(NULL AS INT64) AS year,
        CAST(NULL AS INT64) AS quarter,
        CAST(NULL AS INT64) AS month,
        CAST(NULL AS STRING) AS month_name,
        CAST(NULL AS INT64) AS day_of_month,
        CAST(NULL AS INT64) AS day_of_week,
        CAST(NULL AS STRING) AS weekday_name,
        CAST(NULL AS BOOLEAN) AS is_weekend,
        CAST(NULL AS INT64) AS fiscal_year
)

SELECT * FROM date_dimension
UNION ALL
SELECT * FROM null_placeholder