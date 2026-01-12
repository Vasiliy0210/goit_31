WITH main AS (
    SELECT *,
    'Google' AS media_source
    FROM google_ads_basic_daily gabd
    
    UNION ALL
    
    SELECT ad_date,
           campaign_name,
           adset_name,
           spend,
           impressions,
           reach,
           clicks,
           leads,
           value,
           url_parameters,
           'Facebook' AS media_source
    FROM facebook_ads_basic_daily fba
    LEFT JOIN facebook_adset fa ON fa.adset_id = fba.adset_id
    LEFT JOIN facebook_campaign fc ON fc.campaign_id = fba.campaign_id
),
source_data AS (
    SELECT 
        ad_date,
        media_source,
        campaign_name,
        url_parameters,
        spend,
        impressions,
        clicks,
        value
    FROM main
    WHERE url_parameters LIKE '%utm_%'
),
utm_source_extracted AS (
    SELECT 
        fd.*,
        url_decode(m.matches[1]) AS utm_source
    FROM source_data fd
    LEFT JOIN LATERAL (
        SELECT regexp_matches(url_parameters, 'utm_source=([^&]*)') AS matches
        WHERE url_parameters LIKE '%utm_source=%'
    ) m ON true
),
utm_medium_extracted AS (
    SELECT 
        use.*,
        url_decode(m.matches[1]) AS utm_medium
    FROM utm_source_extracted use
    LEFT JOIN LATERAL (
        SELECT regexp_matches(url_parameters, 'utm_medium=([^&]*)') AS matches
        WHERE url_parameters LIKE '%utm_medium=%'
    ) m ON true
),
utm_campaign_extracted AS (
    SELECT 
        ume.*,
        url_decode(m.matches[1]) AS utm_campaign
    FROM utm_medium_extracted ume
    LEFT JOIN LATERAL (
        SELECT regexp_matches(url_parameters, 'utm_campaign=([^&]*)') AS matches
        WHERE url_parameters LIKE '%utm_campaign=%'
    ) m ON true
)
SELECT
    ad_date,
    media_source,
    campaign_name,
    utm_source,
    utm_medium,
    utm_campaign,
    SUM(spend) AS spend,
    SUM(impressions) AS impressions,
    SUM(clicks) AS clicks,
    SUM(value) AS value,
    CASE
        WHEN SUM(impressions) > 0
        THEN ROUND((SUM(clicks)::NUMERIC / SUM(impressions)) * 100, 2)
        ELSE 0
    END AS ctr,
    CASE
        WHEN SUM(spend) > 0
        THEN ROUND(SUM(value)::NUMERIC / SUM(spend), 2)
        ELSE 0
    END AS roas
FROM utm_campaign_extracted
GROUP BY 1, 2, 3, 4, 5, 6
ORDER BY 1 DESC, 8 DESC;


select  url_parameters,
    (REGEXP_MATCHES(url_parameters, 'utm_medium=([^&]*)'))[1] AS utm_medium,
    (REGEXP_MATCHES(url_parameters, 'utm_campaign=([^&]*)'))[1] as utm_campaign
from facebook_ads_basic_daily