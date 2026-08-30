-- 1. Account Level Churn rate
SELECT 
    COUNT(DISTINCT account_id) AS total_accounts,
    SUM(CASE WHEN churn_flag = 1 THEN 1 ELSE 0 END) AS churned_accounts,
    ROUND(
        1.0 * SUM(CASE WHEN churn_flag = 1 THEN 1 ELSE 0 END) / COUNT(DISTINCT account_id), 4
    ) AS churn_rate
FROM accounts;


-- 2. Active MRR amd ARR 

SELECT
    ROUND(SUM(CASE WHEN churn_flag = 0 THEN mrr_amount ELSE 0 END), 2) AS active_mrr,
    ROUND(SUM(CASE WHEN churn_flag = 0 THEN arr_amount ELSE 0 END), 2) AS active_arr
FROM subscriptions;

-- 3. Churn events by reason

SELECT 
    reason_code,
    COUNT(churn_event_id) AS churn_events,
    ROUND(SUM(refund_amount_usd), 2) AS total_refund,
    ROUND(AVG(refund_amount_usd), 2) AS avg_refund
FROM churn_events
GROUP BY reason_code
ORDER BY churn_events DESC;

-- 4. Churn rate by referral source

SELECT
    referral_source,
    COUNT(DISTINCT account_id) AS total_accounts,
    SUM(CASE WHEN churn_flag = 1 THEN 1 ELSE 0 END) AS churned_accounts,
    ROUND(
        100.0 * SUM(CASE WHEN churn_flag = 1 THEN 1 ELSE 0 END) / COUNT(DISTINCT account_id), 2
    ) AS churn_rate_percentage
FROM accounts
GROUP BY referral_source
ORDER BY churn_rate_percentage DESC;


-- 5. Subscription churn rate by plan tier

SELECT
    plan_tier,
    COUNT(DISTINCT subscription_id) AS total_subscriptions,
    SUM(CASE WHEN churn_flag = 1 THEN 1 ELSE 0 END) AS churned_subscriptions,
    ROUND(
        100.0 * SUM(CASE WHEN churn_flag = 1 THEN 1 ELSE 0 END) / COUNT(DISTINCT subscription_id), 2
    ) AS subscription_churn_rate_percentage
FROM subscriptions
GROUP BY plan_tier
ORDER BY subscription_churn_rate_percentage DESC;

-- 6. Monthly churn events

SELECT
    strftime('%Y-%m', churn_date) AS churn_month,
    COUNT(churn_event_id) AS churn_events,
    ROUND(SUM(refund_amount_usd), 2) AS total_refund
FROM churn_events
GROUP BY strftime('%Y-%m', churn_date)
ORDER BY churn_month;

-- 7. Active MRR by plan tier

SELECT
    plan_tier,
    ROUND(SUM(mrr_amount), 2) AS total_mrr,
    ROUND(SUM(CASE WHEN churn_flag = 0 THEN mrr_amount ELSE 0 END), 2) AS active_mrr,
    ROUND(SUM(arr_amount), 2) AS total_arr,
    ROUND(SUM(CASE WHEN churn_flag = 0 THEN arr_amount ELSE 0 END), 2) AS active_arr,
    COUNT(DISTINCT subscription_id) AS total_subscriptions
FROM subscriptions
GROUP BY plan_tier
ORDER BY active_mrr DESC;

-- 8. Active MRR

WITH plan_revenue AS (
    SELECT
        plan_tier,
        SUM(CASE WHEN churn_flag = 0 THEN mrr_amount ELSE 0 END) AS active_mrr
    FROM subscriptions
    GROUP BY plan_tier
)

SELECT
    plan_tier,
    ROUND(active_mrr, 2) AS active_mrr,
    ROUND(
        100.0 * active_mrr / SUM(active_mrr) OVER (),
        2
    ) AS active_mrr_share_percentage
FROM plan_revenue
ORDER BY active_mrr DESC;

-- 9. Top 10 features by usage

SELECT 
    feature_name,
    SUM(usage_count) AS total_usage,
    SUM(error_count) AS total_errors,
    ROUND(AVG(usage_duration_secs), 2) AS usage_duration_secs,
    COUNT(usage_id) AS usage_events,
    ROUND(100.0 * SUM(error_count) / SUM(usage_count), 2) AS error_rate_percentage
FROM feature_usage
GROUP BY feature_name
ORDER BY total_usage DESC
LIMIT 10;

-- 10. Top 10 features by error count

SELECT
    feature_name,
    SUM(error_count) AS total_errors,
    SUM(usage_count) AS total_usage,
    ROUND(
        100.0 * SUM(error_count) / SUM(usage_count),
        2
    ) AS error_rate_percentage
FROM feature_usage
GROUP BY feature_name
ORDER BY total_errors DESC
LIMIT 10;

-- 11. Error rate by beta feature status

SELECT
    is_beta_feature,
    SUM(usage_count) AS total_usage,
    SUM(error_count) AS total_errors,
    ROUND(100.0 * SUM(error_count) / SUM(usage_count), 2) AS error_rate_percentage
FROM feature_usage
GROUP BY is_beta_feature
order by error_rate_percentage DESC;

-- 12. Support health by priority

SELECT 
    priority,
    COUNT(ticket_id) AS ticket_count,
    ROUND(AVG(satisfaction_score), 2) AS avg_satisfaction_score,
    ROUND(AVG(resolution_time_hours), 2) AS avg_resolution_time_hours,
    ROUND(AVG(first_response_time_minutes), 2) AS avg_first_response_time_minutes,
    SUM(CASE WHEN escalation_flag = 1 THEN 1 ELSE 0 END) AS escalated_tickets,
    ROUND(100.0 * SUM(CASE WHEN escalation_flag = 1 THEN 1 ELSE 0 END) / COUNT(ticket_id), 2) AS escalation_rate_percentage
FROM support_tickets
GROUP BY priority
ORDER BY ticket_count DESC;


-- 13. Account-level customer health view

WITH account_usage AS (
    SELECT
        s.account_id,
        SUM(fu.usage_count) AS total_usage,
        SUM(fu.error_count) AS total_errors,
        COUNT(fu.usage_id) AS usage_events,
        ROUND(AVG(fu.usage_duration_secs), 2) AS avg_usage_duration_secs,
        ROUND(
            100.0 * SUM(fu.error_count) / SUM(fu.usage_count),
            2
        ) AS error_rate_percentage
    FROM feature_usage fu
    LEFT JOIN subscriptions s
        ON fu.subscription_id = s.subscription_id
    GROUP BY s.account_id
),

account_support AS (
    SELECT
        account_id,
        COUNT(ticket_id) AS ticket_count,
        ROUND(AVG(satisfaction_score), 2) AS avg_satisfaction,
        ROUND(AVG(resolution_time_hours), 2) AS avg_resolution_hours,
        SUM(CASE WHEN escalation_flag = 1 THEN 1 ELSE 0 END) AS escalated_tickets,
        ROUND(
            100.0 * SUM(CASE WHEN escalation_flag = 1 THEN 1 ELSE 0 END)
            / COUNT(ticket_id),
            2
        ) AS escalation_rate_percentage
    FROM support_tickets
    GROUP BY account_id
),

account_revenue AS (
    SELECT
        account_id,
        ROUND(SUM(mrr_amount), 2) AS total_mrr,
        ROUND(SUM(CASE WHEN churn_flag = 0 THEN mrr_amount ELSE 0 END), 2) AS active_mrr,
        COUNT(DISTINCT subscription_id) AS subscription_count,
        SUM(CASE WHEN churn_flag = 1 THEN 1 ELSE 0 END) AS churned_subscriptions
    FROM subscriptions
    GROUP BY account_id
)

SELECT
    a.account_id,
    a.account_name,
    a.industry,
    a.country,
    a.plan_tier,
    a.churn_flag,
    COALESCE(au.total_usage, 0) AS total_usage,
    COALESCE(au.total_errors, 0) AS total_errors,
    COALESCE(au.error_rate_percentage, 0) AS error_rate_percentage,
    COALESCE(ast.ticket_count, 0) AS ticket_count,
    ast.avg_satisfaction,
    COALESCE(ast.escalated_tickets, 0) AS escalated_tickets,
    COALESCE(ast.escalation_rate_percentage, 0) AS escalation_rate_percentage,
    ar.total_mrr,
    ar.active_mrr,
    ar.subscription_count,
    ar.churned_subscriptions
FROM accounts a
LEFT JOIN account_usage au
    ON a.account_id = au.account_id
LEFT JOIN account_support ast
    ON a.account_id = ast.account_id
LEFT JOIN account_revenue ar
    ON a.account_id = ar.account_id
ORDER BY ar.active_mrr DESC
LIMIT 20;