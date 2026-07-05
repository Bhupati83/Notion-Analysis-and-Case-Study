-- ============================================================
--  NOTION — DATA ANALYSIS (PHASE 2 OF 5)
--  Portfolio Project: Product / Business Analyst
--  Analyst: [Your Name]
--  Date: June 2026
--  Database: notion_analytics (PostgreSQL)
--  Description: End-to-end SQL analysis of user behaviour,
--               churn, feature adoption, and revenue breakdown
-- ============================================================


-- ============================================================
-- SECTION 0: DATABASE SCHEMA REFERENCE
-- ============================================================
/*
  TABLES USED IN THIS ANALYSIS:
  ┌─────────────────────┬──────────────────────────────────────────────────────┐
  │ Table               │ Description                                          │
  ├─────────────────────┼──────────────────────────────────────────────────────┤
  │ users               │ All registered users (free + paid)                   │
  │ subscriptions       │ Subscription records per user (plan, dates, status)  │
  │ events              │ User activity events (page view, AI use, etc.)       │
  │ feature_usage       │ Feature-level usage per user per month               │
  │ payments            │ Payment transactions (charges, refunds)              │
  │ churn_events        │ Records of subscription cancellations                │
  │ workspace_members   │ Team workspace membership                            │
  │ geo_data            │ User geography (country, region)                     │
  └─────────────────────┴──────────────────────────────────────────────────────┘

  KEY COLUMNS:
  - users: user_id, signup_date, country, plan_type, is_active
  - subscriptions: sub_id, user_id, plan, status, start_date, end_date, mrr
  - events: event_id, user_id, event_type, feature_name, created_at
  - payments: payment_id, user_id, amount, currency, payment_date, status
  - churn_events: churn_id, user_id, plan, churn_date, churn_reason
  - feature_usage: user_id, feature_name, month, usage_count, is_active_user
  - geo_data: user_id, country, region, city
*/


-- ============================================================
-- SECTION 1: KEY METRICS SNAPSHOT
-- ============================================================

-- ── 1.1 Total Users by Plan ───────────────────────────────────────────────
-- Goal: understand the user distribution across all plan tiers

SELECT
    plan_type,
    COUNT(user_id)                                      AS total_users,
    ROUND(COUNT(user_id) * 100.0 / SUM(COUNT(user_id)) OVER (), 1) AS pct_of_total
FROM users
WHERE is_active = TRUE
GROUP BY plan_type
ORDER BY total_users DESC;

/*
  EXPECTED OUTPUT:
  plan_type   | total_users | pct_of_total
  ------------|-------------|-------------
  free        | 87,000,000  | 87.0%
  plus        |  7,000,000  |  7.0%
  business    |  4,000,000  |  4.0%
  enterprise  |  2,000,000  |  2.0%

  INSIGHT: 87% of users are on the free plan — classic freemium distribution.
           The top 6% (Business + Enterprise) drive the majority of revenue.
*/


-- ── 1.2 Monthly Recurring Revenue (MRR) by Plan ──────────────────────────
-- Goal: understand revenue distribution vs user distribution

SELECT
    s.plan,
    COUNT(DISTINCT s.user_id)                                   AS paying_users,
    ROUND(SUM(s.mrr), 0)                                        AS total_mrr,
    ROUND(AVG(s.mrr), 2)                                        AS avg_mrr_per_user,
    ROUND(SUM(s.mrr) * 100.0 / SUM(SUM(s.mrr)) OVER (), 1)     AS pct_of_total_mrr
FROM subscriptions s
WHERE s.status = 'active'
  AND s.plan   != 'free'
GROUP BY s.plan
ORDER BY total_mrr DESC;

/*
  EXPECTED OUTPUT:
  plan       | paying_users | total_mrr  | avg_mrr/user | pct_mrr
  -----------|--------------|------------|--------------|--------
  enterprise |   2,000,000  | $21,000,000|     $10.50   |  42.0%
  business   |   4,000,000  | $16,500,000|      $4.13   |  33.0%
  plus       |   7,000,000  | $10,000,000|      $1.43   |  20.0%
  (free)     |  87,000,000  |  $2,500,000|       $0.03  |   5.0%

  INSIGHT: Enterprise = 2% of users → 42% of MRR.
           This is the 2%/42% rule — the core business insight of this project.
*/


-- ── 1.3 Annual Revenue Growth (2019–2025) ─────────────────────────────────
-- Goal: visualise revenue trajectory to understand growth rate

SELECT
    EXTRACT(YEAR FROM payment_date)             AS revenue_year,
    ROUND(SUM(amount) / 1000000.0, 1)          AS revenue_millions_usd,
    LAG(ROUND(SUM(amount) / 1000000.0, 1))
        OVER (ORDER BY EXTRACT(YEAR FROM payment_date))
                                                AS prev_year_revenue,
    ROUND(
        (SUM(amount) - LAG(SUM(amount)) OVER (ORDER BY EXTRACT(YEAR FROM payment_date)))
        * 100.0
        / NULLIF(LAG(SUM(amount)) OVER (ORDER BY EXTRACT(YEAR FROM payment_date)), 0),
        1
    )                                           AS yoy_growth_pct
FROM payments
WHERE status = 'completed'
  AND EXTRACT(YEAR FROM payment_date) BETWEEN 2019 AND 2025
GROUP BY revenue_year
ORDER BY revenue_year;

/*
  EXPECTED OUTPUT:
  year | revenue_M | prev_year_M | yoy_growth
  -----|-----------|-------------|----------
  2019 |     $3M   |      -      |     -
  2020 |    $10M   |      $3M    |  +233%
  2021 |    $31M   |     $10M    |  +210%
  2022 |    $67M   |     $31M    |  +116%
  2023 |   $250M   |     $67M    |  +273%
  2024 |   $400M   |    $250M    |   +60%
  2025 |   $600M   |    $400M    |   +50%

  INSIGHT: 19x revenue growth in 4 years. 2023 was the breakout year — 
           likely driven by Notion AI launch + enterprise push.
*/


-- ============================================================
-- SECTION 2: CHURN ANALYSIS (CORE BUSINESS PROBLEM)
-- ============================================================

-- ── 2.1 Monthly Churn Rate by Plan ────────────────────────────────────────
-- Goal: quantify churn per plan tier to identify the problem segment

WITH monthly_subs AS (
    SELECT
        plan,
        DATE_TRUNC('month', start_date)         AS month,
        COUNT(DISTINCT user_id)                 AS active_users_start
    FROM subscriptions
    WHERE status IN ('active', 'churned')
    GROUP BY plan, DATE_TRUNC('month', start_date)
),
monthly_churns AS (
    SELECT
        plan,
        DATE_TRUNC('month', churn_date)         AS month,
        COUNT(DISTINCT user_id)                 AS churned_users
    FROM churn_events
    GROUP BY plan, DATE_TRUNC('month', churn_date)
)
SELECT
    ms.plan,
    TO_CHAR(ms.month, 'YYYY-MM')                AS month,
    ms.active_users_start,
    COALESCE(mc.churned_users, 0)               AS churned_users,
    ROUND(
        COALESCE(mc.churned_users, 0) * 100.0
        / NULLIF(ms.active_users_start, 0),
        2
    )                                           AS monthly_churn_pct
FROM monthly_subs ms
LEFT JOIN monthly_churns mc
    ON ms.plan = mc.plan AND ms.month = mc.month
WHERE ms.month >= DATE_TRUNC('month', NOW()) - INTERVAL '12 months'
ORDER BY ms.plan, ms.month;

/*
  EXPECTED OUTPUT (sample rows):
  plan       | month   | active_start | churned | churn_pct
  -----------|---------|--------------|---------|----------
  plus       | 2025-07 |   7,000,000  | 294,000 |   4.20%
  plus       | 2025-08 |   6,706,000  | 281,652 |   4.20%
  business   | 2025-07 |   4,000,000 |  72,000 |   1.80%
  enterprise | 2025-07 |   2,000,000 |  10,000 |   0.50%

  INSIGHT: Plus plan churn at 4.2%/month = ~40% annual churn.
           Enterprise churn at 0.5%/month = ~6% annual churn.
           The gap is driven by value perception, not product quality.
*/


-- ── 2.2 Top Reasons for Plus Plan Churn ───────────────────────────────────
-- Goal: identify the primary drivers behind Plus churn

SELECT
    churn_reason,
    COUNT(*)                                            AS churn_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct_of_plus_churn
FROM churn_events
WHERE plan       = 'plus'
  AND churn_date >= NOW() - INTERVAL '6 months'
GROUP BY churn_reason
ORDER BY churn_count DESC
LIMIT 8;

/*
  EXPECTED OUTPUT:
  churn_reason                              | count   | pct
  ------------------------------------------|---------|-----
  AI features locked in Business tier       | 487,200 | 34.2%
  Price too high for value received         | 312,800 | 22.0%
  Switching to competitor (Coda/ClickUp)    | 198,400 | 13.9%
  Poor mobile experience                    | 163,200 | 11.5%
  Not using Notion enough to justify cost   | 142,600 | 10.0%
  Missing collaboration features            |  71,400 |  5.0%
  Found free plan sufficient                |  44,200 |  3.1%
  Other                                     |   2,200 |  0.3%

  INSIGHT: 34% of Plus churn is directly caused by AI being locked in Business.
           Combined with 'price too high' (22%), 56% of churn is a VALUE GAP issue.
           This is directly addressable through product changes — no engineering overhaul needed.
*/


-- ── 2.3 Churn Cohort Analysis — When Do Plus Users Leave? ────────────────
-- Goal: identify the critical churn window for Plus users

WITH cohorts AS (
    SELECT
        u.user_id,
        DATE_TRUNC('month', u.signup_date)              AS cohort_month,
        DATE_TRUNC('month', ce.churn_date)              AS churn_month
    FROM users u
    LEFT JOIN churn_events ce ON u.user_id = ce.user_id AND ce.plan = 'plus'
    WHERE u.plan_type = 'plus'
),
cohort_size AS (
    SELECT
        cohort_month,
        COUNT(DISTINCT user_id)     AS cohort_users
    FROM cohorts
    GROUP BY cohort_month
),
churn_by_month AS (
    SELECT
        cohort_month,
        EXTRACT(MONTH FROM AGE(churn_month, cohort_month))  AS months_since_signup,
        COUNT(DISTINCT user_id)                              AS churned
    FROM cohorts
    WHERE churn_month IS NOT NULL
    GROUP BY cohort_month, months_since_signup
)
SELECT
    cbm.months_since_signup,
    SUM(cbm.churned)                        AS total_churned,
    SUM(cs.cohort_users)                    AS total_cohort,
    ROUND(
        SUM(cbm.churned) * 100.0
        / NULLIF(SUM(cs.cohort_users), 0),
        2
    )                                       AS churn_rate_at_month
FROM churn_by_month cbm
JOIN cohort_size cs ON cbm.cohort_month = cs.cohort_month
WHERE cbm.months_since_signup BETWEEN 0 AND 12
GROUP BY cbm.months_since_signup
ORDER BY cbm.months_since_signup;

/*
  EXPECTED OUTPUT:
  months_since_signup | total_churned | churn_rate
  --------------------|---------------|----------
  0                   |    84,000     |  1.2%
  1                   |   126,000     |  1.8%
  2                   |   182,000     |  2.6%
  3                   |   280,000     |  4.0%   ← CHURN SPIKE BEGINS
  4                   |   308,000     |  4.4%   ← PEAK CHURN MONTH
  5                   |   294,000     |  4.2%
  6                   |   266,000     |  3.8%
  ...
  12                  |   154,000     |  2.2%

  INSIGHT: Churn spikes at months 3–4. This is when users hit feature limits
           and seriously evaluate whether to upgrade to Business or leave.
           This is the CRITICAL intervention window for the AI inclusion feature.
*/


-- ── 2.4 Revenue Leakage Calculation ───────────────────────────────────────
-- Goal: quantify the exact financial impact of Plus churn

WITH plus_metrics AS (
    SELECT
        COUNT(DISTINCT user_id)     AS total_plus_users,
        AVG(mrr)                    AS avg_monthly_mrr,
        AVG(mrr) * 12               AS avg_annual_arpu
    FROM subscriptions
    WHERE plan   = 'plus'
      AND status = 'active'
),
churn_calc AS (
    SELECT
        pm.total_plus_users,
        pm.avg_annual_arpu,
        0.042                                                   AS monthly_churn_rate,
        ROUND(pm.total_plus_users * 0.042)                      AS monthly_churned_users,
        ROUND(pm.total_plus_users * 0.042 * 12)                 AS annual_churned_users,
        ROUND(pm.total_plus_users * 0.042 * 12 * pm.avg_annual_arpu)
                                                                AS annual_revenue_leakage
    FROM plus_metrics pm
)
SELECT
    total_plus_users,
    ROUND(avg_annual_arpu, 0)           AS arpu_per_year,
    monthly_churn_rate * 100            AS monthly_churn_pct,
    monthly_churned_users,
    annual_churned_users,
    '$' || TO_CHAR(annual_revenue_leakage, 'FM999,999,999')
                                        AS annual_revenue_leakage_usd,
    -- Conservative scenario: reduce churn by 1pp
    '$' || TO_CHAR(
        ROUND(total_plus_users * 0.01 * 12 * avg_annual_arpu),
        'FM999,999,999'
    )                                   AS saved_if_churn_minus_1pp,
    -- Target scenario: reduce churn to 2.5%
    '$' || TO_CHAR(
        ROUND(total_plus_users * (0.042 - 0.025) * 12 * avg_annual_arpu),
        'FM999,999,999'
    )                                   AS saved_if_churn_at_target
FROM churn_calc;

/*
  EXPECTED OUTPUT:
  total_plus_users | arpu/yr | churn% | monthly_lost | annual_lost | leakage     | save_1pp  | save_target
  -----------------|---------|--------|--------------|-------------|-------------|-----------|------------
  7,000,000        |  $120   |  4.2%  |  294,000     | 3,528,000   | $168,000,000| $40,320,000| $71,400,000

  INSIGHT: $168M annual revenue leakage. Even a 1pp churn reduction = $40M saved.
           Reducing to our 2.5% target saves ~$71M. This is the business case for the PRD.
*/


-- ============================================================
-- SECTION 3: FEATURE ADOPTION ANALYSIS
-- ============================================================

-- ── 3.1 Feature Adoption Rate Among Paid Users ────────────────────────────
-- Goal: understand which features drive engagement (and retention)

SELECT
    fu.feature_name,
    COUNT(DISTINCT CASE WHEN fu.is_active_user = TRUE THEN fu.user_id END)
                                                        AS active_users,
    COUNT(DISTINCT fu.user_id)                          AS total_paid_users,
    ROUND(
        COUNT(DISTINCT CASE WHEN fu.is_active_user = TRUE THEN fu.user_id END) * 100.0
        / NULLIF(COUNT(DISTINCT fu.user_id), 0),
        1
    )                                                   AS adoption_rate_pct,
    ROUND(AVG(fu.usage_count), 1)                       AS avg_monthly_uses
FROM feature_usage fu
JOIN subscriptions s ON fu.user_id = s.user_id
WHERE s.plan   != 'free'
  AND s.status  = 'active'
  AND fu.month  = DATE_TRUNC('month', NOW() - INTERVAL '1 month')
GROUP BY fu.feature_name
ORDER BY adoption_rate_pct DESC;

/*
  EXPECTED OUTPUT:
  feature_name         | active_users | total_users | adoption% | avg_uses/mo
  ---------------------|--------------|-------------|-----------|------------
  pages_and_docs       | 12,540,000   | 13,000,000  |   96.5%   |    47.2
  databases            | 10,140,000   | 13,000,000  |   78.0%   |    23.6
  notion_ai            |  7,020,000   | 13,000,000  |   54.0%   |    18.4
  integrations         |  5,330,000   | 13,000,000  |   41.0%   |     8.1
  mobile_app           |  4,940,000   | 13,000,000  |   38.0%   |    12.3
  notion_calendar      |  4,030,000   | 13,000,000  |   31.0%   |     9.7
  automations          |  3,770,000   | 13,000,000  |   29.0%   |     4.2
  notion_mail          |  2,340,000   | 13,000,000  |   18.0%   |     6.8

  INSIGHT: Pages (96.5%) and Databases (78%) are universal — table stakes.
           Notion AI (54%) has high adoption but is only available to Business+.
           Low mobile adoption (38%) is a red flag given 80%+ non-US user base.
*/


-- ── 3.2 AI Usage vs Churn Correlation ─────────────────────────────────────
-- Goal: prove that AI access drives retention (the core hypothesis)

WITH ai_users AS (
    SELECT DISTINCT user_id
    FROM feature_usage
    WHERE feature_name  = 'notion_ai'
      AND is_active_user = TRUE
      AND month >= NOW() - INTERVAL '6 months'
),
churn_by_ai AS (
    SELECT
        CASE WHEN au.user_id IS NOT NULL THEN 'AI User' ELSE 'Non-AI User' END
                                                        AS user_segment,
        COUNT(DISTINCT s.user_id)                       AS total_users,
        COUNT(DISTINCT ce.user_id)                      AS churned_users,
        ROUND(
            COUNT(DISTINCT ce.user_id) * 100.0
            / NULLIF(COUNT(DISTINCT s.user_id), 0),
            2
        )                                               AS churn_rate_pct
    FROM subscriptions s
    LEFT JOIN ai_users au   ON s.user_id = au.user_id
    LEFT JOIN churn_events ce ON s.user_id = ce.user_id
        AND ce.churn_date >= NOW() - INTERVAL '6 months'
    WHERE s.plan   = 'business'
      AND s.status IN ('active', 'churned')
    GROUP BY user_segment
)
SELECT
    user_segment,
    total_users,
    churned_users,
    churn_rate_pct,
    ROUND(
        (MAX(churn_rate_pct) OVER () - churn_rate_pct)
        * 100.0 / NULLIF(MAX(churn_rate_pct) OVER (), 0),
        1
    )                                                   AS churn_reduction_vs_non_ai_pct
FROM churn_by_ai
ORDER BY churn_rate_pct;

/*
  EXPECTED OUTPUT:
  user_segment | total_users | churned | churn_rate | churn_reduction
  -------------|-------------|---------|------------|----------------
  AI User      | 3,780,000   | 68,040  |    1.8%    |     38.0%
  Non-AI User  | 1,220,000   |  48,800 |    4.0%    |      0.0%

  INSIGHT: AI users churn at 1.8% vs 4.0% for non-AI users — a 38% reduction.
           This is the single strongest data point supporting the PRD recommendation.
           Giving Plus users AI access should replicate this retention effect.
*/


-- ── 3.3 Feature Stickiness Score ──────────────────────────────────────────
-- Goal: rank features by their impact on 90-day retention

WITH user_retention AS (
    SELECT
        u.user_id,
        u.plan_type,
        CASE
            WHEN MAX(e.created_at) >= u.signup_date + INTERVAL '90 days'
            THEN 1 ELSE 0
        END                                             AS retained_90d
    FROM users u
    LEFT JOIN events e ON u.user_id = e.user_id
    WHERE u.signup_date <= NOW() - INTERVAL '90 days'
      AND u.plan_type   != 'free'
    GROUP BY u.user_id, u.plan_type
),
feature_retention AS (
    SELECT
        fu.feature_name,
        COUNT(DISTINCT ur.user_id)                      AS total_users,
        SUM(ur.retained_90d)                            AS retained_users,
        ROUND(SUM(ur.retained_90d) * 100.0
              / NULLIF(COUNT(DISTINCT ur.user_id), 0), 1)
                                                        AS retention_rate_pct
    FROM feature_usage fu
    JOIN user_retention ur ON fu.user_id = ur.user_id
    WHERE fu.is_active_user = TRUE
    GROUP BY fu.feature_name
)
SELECT
    feature_name,
    total_users,
    retained_users,
    retention_rate_pct,
    RANK() OVER (ORDER BY retention_rate_pct DESC)      AS stickiness_rank
FROM feature_retention
ORDER BY stickiness_rank;

/*
  EXPECTED OUTPUT:
  feature_name    | total_users | retained | retention% | rank
  ----------------|-------------|----------|------------|-----
  notion_ai       | 7,020,000   | 6,388,200|    91.0%   |  1
  databases       |10,140,000   | 8,822,580|    87.0%   |  2
  integrations    | 5,330,000   | 4,476,200|    84.0%   |  3
  automations     | 3,770,000   | 3,054,700|    81.0%   |  4
  notion_calendar | 4,030,000   | 3,142,400|    78.0%   |  5
  pages_and_docs  |12,540,000   | 9,279,600|    74.0%   |  6
  mobile_app      | 4,940,000   | 3,506,400|    71.0%   |  7
  notion_mail     | 2,340,000   | 1,521,000|    65.0%   |  8

  INSIGHT: Notion AI has the HIGHEST 90-day retention rate (91%).
           Users who engage with AI stay. This reinforces the PRD hypothesis.
           Pages/Docs — despite universal adoption — have lower retention than AI.
*/


-- ============================================================
-- SECTION 4: GEOGRAPHIC ANALYSIS
-- ============================================================

-- ── 4.1 Users and Revenue by Region ───────────────────────────────────────
-- Goal: identify geographic revenue gaps and opportunity markets

SELECT
    gd.region,
    COUNT(DISTINCT u.user_id)                           AS total_users,
    ROUND(COUNT(DISTINCT u.user_id) * 100.0
          / SUM(COUNT(DISTINCT u.user_id)) OVER (), 1)  AS pct_users,
    ROUND(SUM(p.amount) / 1000000.0, 1)                 AS revenue_millions,
    ROUND(SUM(p.amount) * 100.0
          / SUM(SUM(p.amount)) OVER (), 1)              AS pct_revenue,
    ROUND(SUM(p.amount)
          / NULLIF(COUNT(DISTINCT u.user_id), 0), 0)    AS arpu_usd,
    -- ARPU gap vs North America (benchmark)
    ROUND(
        (SUM(p.amount) / NULLIF(COUNT(DISTINCT u.user_id), 0))
        - FIRST_VALUE(SUM(p.amount) / NULLIF(COUNT(DISTINCT u.user_id), 0))
            OVER (ORDER BY SUM(p.amount) / NULLIF(COUNT(DISTINCT u.user_id), 0) DESC),
        0
    )                                                   AS arpu_gap_vs_leader
FROM users u
JOIN geo_data gd ON u.user_id = gd.user_id
LEFT JOIN payments p ON u.user_id = p.user_id AND p.status = 'completed'
WHERE u.is_active = TRUE
GROUP BY gd.region
ORDER BY revenue_millions DESC;

/*
  EXPECTED OUTPUT:
  region         | users(M) | %users | rev($M) | %rev | arpu  | arpu_gap
  ---------------|----------|--------|---------|------|-------|----------
  North America  |    20M   |  20%   |  $228M  |  38% | $11.40|     $0
  APAC           |    35M   |  35%   |  $168M  |  28% |  $4.80| -$6.60
  Europe         |    25M   |  25%   |  $132M  |  22% |  $5.28| -$6.12
  Latin America  |    12M   |  12%   |   $48M  |   8% |  $4.00| -$7.40
  Others         |     8M   |   8%   |   $24M  |   4% |  $3.00| -$8.40

  INSIGHT: APAC has 35% of users but only 28% of revenue.
           ARPU gap of -$6.60 vs North America.
           Mobile-first markets + lower plan uptake = monetisation opportunity.
*/


-- ── 4.2 Top 10 Countries by User Volume ───────────────────────────────────
-- Goal: identify where Notion's user base lives (not where money comes from)

SELECT
    gd.country,
    gd.region,
    COUNT(DISTINCT u.user_id)                           AS total_users,
    COUNT(DISTINCT CASE WHEN u.plan_type != 'free' THEN u.user_id END)
                                                        AS paid_users,
    ROUND(
        COUNT(DISTINCT CASE WHEN u.plan_type != 'free' THEN u.user_id END) * 100.0
        / NULLIF(COUNT(DISTINCT u.user_id), 0),
        1
    )                                                   AS paid_conversion_pct,
    ROUND(AVG(p.amount), 2)                             AS avg_payment_usd
FROM users u
JOIN geo_data gd ON u.user_id = gd.user_id
LEFT JOIN payments p ON u.user_id = p.user_id AND p.status = 'completed'
WHERE u.is_active = TRUE
GROUP BY gd.country, gd.region
ORDER BY total_users DESC
LIMIT 10;

/*
  EXPECTED OUTPUT:
  country       | region    | users(M) | paid(M) | paid_conv% | avg_pay
  --------------|-----------|----------|---------|------------|--------
  United States |N. America |   20.0M  |   5.4M  |   27.0%    | $14.80
  South Korea   |APAC       |    9.0M  |   1.4M  |   15.6%    |  $9.20
  Japan         |APAC       |    7.5M  |   1.0M  |   13.3%    | $10.40
  Brazil        |Lat America|    6.0M  |   0.5M  |    8.3%    |  $7.60
  India         |APAC       |    5.5M  |   0.4M  |    7.3%    |  $6.20
  Germany       |Europe     |    4.8M  |   0.9M  |   18.8%    | $12.10
  France        |Europe     |    4.2M  |   0.7M  |   16.7%    | $11.80
  United Kingdom|Europe     |    4.0M  |   0.8M  |   20.0%    | $13.20
  Canada        |N. America |    3.5M  |   0.8M  |   22.9%    | $13.80
  Australia     |APAC       |    3.2M  |   0.6M  |   18.8%    | $12.20

  INSIGHT: India has 5.5M users but only 7.3% paid conversion (lowest in top 10).
           Brazil at 8.3%. Both are mobile-first markets — mobile UX gap directly
           suppresses conversion in these high-potential markets.
*/


-- ── 4.3 Mobile vs Desktop Usage by Region ─────────────────────────────────
-- Goal: confirm mobile-first behaviour in APAC/LatAm to justify mobile investment

SELECT
    gd.region,
    COUNT(DISTINCT CASE WHEN e.platform = 'mobile' THEN e.user_id END)
                                                        AS mobile_users,
    COUNT(DISTINCT CASE WHEN e.platform = 'desktop' THEN e.user_id END)
                                                        AS desktop_users,
    COUNT(DISTINCT e.user_id)                           AS total_users,
    ROUND(
        COUNT(DISTINCT CASE WHEN e.platform = 'mobile' THEN e.user_id END) * 100.0
        / NULLIF(COUNT(DISTINCT e.user_id), 0),
        1
    )                                                   AS mobile_pct,
    ROUND(
        COUNT(DISTINCT CASE WHEN e.platform = 'desktop' THEN e.user_id END) * 100.0
        / NULLIF(COUNT(DISTINCT e.user_id), 0),
        1
    )                                                   AS desktop_pct
FROM events e
JOIN geo_data gd ON e.user_id = gd.user_id
WHERE e.created_at >= NOW() - INTERVAL '30 days'
GROUP BY gd.region
ORDER BY mobile_pct DESC;

/*
  EXPECTED OUTPUT:
  region        | mobile% | desktop%
  --------------|---------|----------
  Latin America |  72.4%  |   27.6%
  APAC          |  68.1%  |   31.9%
  Others        |  61.0%  |   39.0%
  Europe        |  44.8%  |   55.2%
  North America |  38.2%  |   61.8%

  INSIGHT: APAC (68%) and LatAm (72%) are overwhelmingly mobile-first.
           Yet these are the regions with the lowest ARPU and paid conversion.
           A mobile experience overhaul (PRD Recommendation R3) is justified.
*/


-- ============================================================
-- SECTION 5: UPGRADE PATH ANALYSIS
-- ============================================================

-- ── 5.1 Plus → Business Upgrade Rate ─────────────────────────────────────
-- Goal: measure how effectively Plus users convert to Business

WITH plus_cohort AS (
    SELECT
        user_id,
        MIN(start_date)                             AS plus_start_date
    FROM subscriptions
    WHERE plan = 'plus'
    GROUP BY user_id
),
upgraded AS (
    SELECT
        pc.user_id,
        pc.plus_start_date,
        MIN(s.start_date)                           AS upgrade_date,
        EXTRACT(DAY FROM MIN(s.start_date) - pc.plus_start_date)
                                                    AS days_to_upgrade
    FROM plus_cohort pc
    JOIN subscriptions s
        ON pc.user_id = s.user_id
        AND s.plan IN ('business', 'enterprise')
        AND s.start_date > pc.plus_start_date
    GROUP BY pc.user_id, pc.plus_start_date
)
SELECT
    COUNT(DISTINCT pc.user_id)                      AS total_plus_users,
    COUNT(DISTINCT u.user_id)                       AS total_upgraded,
    ROUND(
        COUNT(DISTINCT u.user_id) * 100.0
        / NULLIF(COUNT(DISTINCT pc.user_id), 0),
        1
    )                                               AS upgrade_rate_pct,
    ROUND(AVG(u.days_to_upgrade), 0)                AS avg_days_to_upgrade,
    -- Benchmark: SaaS industry average
    25.0                                            AS industry_benchmark_pct,
    ROUND(25.0 - COUNT(DISTINCT u.user_id) * 100.0
          / NULLIF(COUNT(DISTINCT pc.user_id), 0), 1)
                                                    AS gap_vs_benchmark_pp
FROM plus_cohort pc
LEFT JOIN upgraded u ON pc.user_id = u.user_id;

/*
  EXPECTED OUTPUT:
  total_plus | upgraded | upgrade_rate | avg_days | benchmark | gap_vs_bmark
  -----------|----------|--------------|----------|-----------|-------------
  7,000,000  | 840,000  |    12.0%     |   127    |   25.0%   |   -13.0pp

  INSIGHT: Only 12% of Plus users upgrade to Business — vs 25% SaaS benchmark.
           That is a 13pp gap. The average Plus user takes 127 days to upgrade
           (at which point many have already churned). The $10→$18 price jump
           with no intermediate step is the structural cause.
*/


-- ── 5.2 Upgrade Trigger Analysis ──────────────────────────────────────────
-- Goal: what action do users take right before upgrading?

SELECT
    e.event_type                                        AS last_action_before_upgrade,
    e.feature_name,
    COUNT(DISTINCT e.user_id)                           AS user_count,
    ROUND(COUNT(DISTINCT e.user_id) * 100.0
          / SUM(COUNT(DISTINCT e.user_id)) OVER (), 1)  AS pct_of_upgrades
FROM events e
JOIN (
    -- users who upgraded, within 7 days before upgrade
    SELECT s.user_id, MIN(s.start_date) AS upgrade_date
    FROM subscriptions s
    WHERE s.plan IN ('business', 'enterprise')
    GROUP BY s.user_id
) upg ON e.user_id = upg.user_id
    AND e.created_at BETWEEN upg.upgrade_date - INTERVAL '7 days'
                         AND upg.upgrade_date
WHERE e.event_type IN ('feature_limit_hit', 'ai_paywall_shown',
                        'upgrade_cta_clicked', 'team_invite_blocked',
                        'page_limit_hit', 'ai_trial_expired')
GROUP BY e.event_type, e.feature_name
ORDER BY user_count DESC
LIMIT 8;

/*
  EXPECTED OUTPUT:
  last_action_before_upgrade | feature          | users   | pct
  ---------------------------|------------------|---------|-----
  ai_paywall_shown           | notion_ai        | 302,400 | 36.0%
  feature_limit_hit          | automations      | 159,600 | 19.0%
  upgrade_cta_clicked        | upgrade_modal    | 126,000 | 15.0%
  team_invite_blocked        | workspace        |  84,000 | 10.0%
  page_limit_hit             | pages            |  67,200 |  8.0%
  ai_trial_expired           | notion_ai        |  58,800 |  7.0%
  feature_limit_hit          | databases        |  33,600 |  4.0%
  other                      | -                |   8,400 |  1.0%

  INSIGHT: 43% of upgrades are triggered by AI-related friction (paywall shown + trial expired).
           AI is both the #1 churn cause AND the #1 upgrade trigger — it is the
           single most commercially important feature for Notion's Plus segment.
*/


-- ============================================================
-- SECTION 6: EXECUTIVE SUMMARY QUERY
-- ============================================================

-- ── 6.1 Single-Query Business Health Dashboard ────────────────────────────
-- Goal: produce one output that summarises all key metrics for a stakeholder

WITH
total_users     AS (SELECT COUNT(*) AS n FROM users WHERE is_active = TRUE),
paid_users      AS (SELECT COUNT(*) AS n FROM users WHERE is_active = TRUE AND plan_type != 'free'),
plus_churn      AS (SELECT ROUND(AVG(monthly_churn_rate) * 100, 2) AS rate
                    FROM (
                        SELECT
                            DATE_TRUNC('month', churn_date) AS m,
                            COUNT(*) * 1.0 / 7000000 AS monthly_churn_rate
                        FROM churn_events WHERE plan = 'plus'
                        GROUP BY m
                    ) x),
annual_rev      AS (SELECT ROUND(SUM(amount) / 1000000.0, 0) AS rev_m
                    FROM payments
                    WHERE status = 'completed'
                      AND EXTRACT(YEAR FROM payment_date) = 2025),
ai_adoption     AS (SELECT ROUND(COUNT(DISTINCT user_id) * 100.0 / (SELECT n FROM paid_users), 1) AS pct
                    FROM feature_usage
                    WHERE feature_name = 'notion_ai' AND is_active_user = TRUE
                      AND month = DATE_TRUNC('month', NOW() - INTERVAL '1 month'))
SELECT
    (SELECT n FROM total_users)                         AS total_users,
    (SELECT n FROM paid_users)                          AS paid_users,
    (SELECT rev_m FROM annual_rev)                      AS revenue_2025_millions,
    (SELECT rate FROM plus_churn)                       AS plus_monthly_churn_pct,
    ROUND((SELECT rate FROM plus_churn) * 12, 1)        AS plus_annual_churn_pct,
    ROUND(
        7000000 * (SELECT rate/100 FROM plus_churn) * 12 * 120,
        0
    )                                                   AS annual_revenue_leakage_usd,
    (SELECT pct FROM ai_adoption)                       AS ai_adoption_pct_paid_users,
    12.0                                                AS plus_to_biz_upgrade_rate_pct,
    38.0                                                AS churn_reduction_if_ai_enabled_pct;

/*
  EXPECTED OUTPUT (single row):
  total_users | paid_users | rev_2025_M | plus_churn% | annual_churn% | leakage_USD  | ai_adopt% | upgrade% | ai_churn_reduction%
  ------------|------------|------------|-------------|---------------|--------------|-----------|----------|--------------------
  100,000,000 |  4,000,000 |     $600M  |       4.2%  |         40.0% |$168,000,000  |    54.0%  |   12.0%  |               38.0%

  FINAL INSIGHT: This single row tells the complete story.
  → $168M leakage from 4.2% churn
  → AI has 54% adoption but is locked in Business
  → AI users churn 38% less
  → Only 12% of Plus users upgrade (vs 25% benchmark)
  
  RECOMMENDATION: Include Notion AI in Plus plan (20 req/day cap).
  Expected outcome: churn 4.2% → 2.5%, upgrade rate 12% → 18%, +$116M ARR potential.
*/


-- ============================================================
-- END OF ANALYSIS
-- Phase 2 complete | Next: Phase 3 Case Study
-- ============================================================
