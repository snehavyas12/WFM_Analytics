CREATE TABLE wfm_master_calls (
    call_id NUMERIC,
    queue_id NUMERIC,
    caller_id NUMERIC,
    started_at TIMESTAMP,
    status TEXT,
    base_wait_seconds NUMERIC,
    wait_seconds NUMERIC,
    abandon_after_seconds NUMERIC,
    agent_id NUMERIC,
    base_handle_seconds NUMERIC,
    queue_handle_seconds NUMERIC,
    handle_seconds NUMERIC,
    resolved_first_contact BOOLEAN,
    queue_key NUMERIC,
    queue_set NUMERIC,
    queue TEXT,
    sla_seconds NUMERIC,
    wait_factor NUMERIC,
    handle_factor NUMERIC,
    agent_key NUMERIC,
    agent_first_name TEXT,
    agent_last_name TEXT,
    team TEXT,
    agent_tenure_months NUMERIC,
    agent_speed_factor NUMERIC,
    caller_key NUMERIC,
    caller_ref TEXT,
    account_type TEXT,
    region TEXT,
    call_date DATE,
    call_hour NUMERIC,
    day_of_week TEXT,
    day_of_week_num NUMERIC,
    answered_flag NUMERIC,
    abandoned_flag NUMERIC,
    sla_met NUMERIC
);

SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT call_id) AS unique_call_ids
FROM wfm_master_calls;

-- 1. Overall WFM KPIs
SELECT COUNT(*) AS total_calls,
 COUNT(*) FILTER (WHERE status='answered') AS answered_calls,
 COUNT(*) FILTER (WHERE status='abandoned') AS abandoned_calls,
 ROUND(100.0*COUNT(*) FILTER (WHERE status='abandoned')/NULLIF(COUNT(*),0),2) AS abandonment_rate_pct,
 ROUND(AVG(handle_seconds) FILTER (WHERE status='answered')::numeric,2) AS avg_handling_seconds,
 ROUND(AVG(wait_seconds) FILTER (WHERE status='answered')::numeric,2) AS avg_waiting_seconds,
 ROUND(100.0*COUNT(*) FILTER (WHERE status='answered' AND wait_seconds<=sla_seconds)
       /NULLIF(COUNT(*) FILTER (WHERE status='answered'),0),2) AS answered_call_sla_pct,
 ROUND(100.0*AVG(resolved_first_contact::int) FILTER (WHERE status='answered'),2) AS fcr_pct
FROM wfm_master_calls;

-- 2. Queue performance
SELECT queue, COUNT(*) AS total_calls,
 COUNT(*) FILTER (WHERE status='answered') AS answered_calls,
 COUNT(*) FILTER (WHERE status='abandoned') AS abandoned_calls,
 ROUND(AVG(wait_seconds) FILTER (WHERE status='answered')::numeric,2) AS avg_wait_seconds,
 ROUND(AVG(handle_seconds) FILTER (WHERE status='answered')::numeric,2) AS avg_handle_seconds,
 ROUND(100.0*COUNT(*) FILTER (WHERE status='abandoned')/NULLIF(COUNT(*),0),2) AS abandonment_rate_pct,
 ROUND(100.0*COUNT(*) FILTER (WHERE status='answered' AND wait_seconds<=sla_seconds)
       /NULLIF(COUNT(*) FILTER (WHERE status='answered'),0),2) AS sla_attainment_pct
FROM wfm_master_calls GROUP BY queue ORDER BY total_calls DESC;

-- 3. Hourly demand and workload
SELECT call_hour, COUNT(*) AS total_calls,
 COUNT(*) FILTER (WHERE status='answered') AS answered_calls,
 COUNT(*) FILTER (WHERE status='abandoned') AS abandoned_calls,
 ROUND(AVG(wait_seconds) FILTER (WHERE status='answered')::numeric,2) AS avg_wait_seconds,
 ROUND((SUM(handle_seconds) FILTER (WHERE status='answered')/3600.0)::numeric,2) AS workload_hours
FROM wfm_master_calls GROUP BY call_hour ORDER BY call_hour;

-- 4. Day-of-week demand
SELECT day_of_week, day_of_week_num, COUNT(*) AS total_calls,
 COUNT(*) FILTER (WHERE status='answered') AS answered_calls,
 COUNT(*) FILTER (WHERE status='abandoned') AS abandoned_calls
FROM wfm_master_calls
GROUP BY day_of_week, day_of_week_num ORDER BY day_of_week_num;

-- 5. Agent performance (answered calls only)
SELECT agent_id, agent_first_name || ' ' || agent_last_name AS agent_name,
 team, agent_tenure_months, COUNT(*) AS answered_calls,
 ROUND(AVG(handle_seconds)::numeric,2) AS avg_handle_seconds,
 ROUND(AVG(wait_seconds)::numeric,2) AS avg_wait_seconds,
 ROUND(100.0*AVG(resolved_first_contact::int),2) AS fcr_pct,
 ROUND(100.0*AVG((wait_seconds<=sla_seconds)::int),2) AS sla_attainment_pct
FROM wfm_master_calls 
WHERE status='answered'
GROUP BY agent_id, agent_first_name, agent_last_name, team, agent_tenure_months
ORDER BY answered_calls DESC;

-- 6. Team performance (answered calls only)
SELECT team, COUNT(*) AS answered_calls, COUNT(DISTINCT agent_id) AS agents_handling_calls,
 ROUND(AVG(handle_seconds)::numeric,2) AS avg_handle_seconds,
 ROUND(AVG(wait_seconds)::numeric,2) AS avg_wait_seconds,
 ROUND(100.0*AVG(resolved_first_contact::int),2) AS fcr_pct,
 ROUND(100.0*AVG((wait_seconds<=sla_seconds)::int),2) AS sla_attainment_pct
FROM wfm_master_calls 
WHERE status='answered'
GROUP BY team ORDER BY answered_calls DESC;

-- 7. Abandonment by queue
SELECT queue, COUNT(*) AS total_calls,
 COUNT(*) FILTER (WHERE status='abandoned') AS abandoned_calls,
 ROUND(100.0*COUNT(*) FILTER (WHERE status='abandoned')/NULLIF(COUNT(*),0),2) AS abandonment_rate_pct,
 ROUND(AVG(abandon_after_seconds) FILTER (WHERE status='abandoned')::numeric,2) AS avg_abandon_seconds
FROM wfm_master_calls 
GROUP BY queue 
ORDER BY abandonment_rate_pct DESC;

-- 8. SLA misses by queue
SELECT queue,
 COUNT(*) FILTER (WHERE status='answered') AS answered_calls,
 COUNT(*) FILTER (WHERE status='answered' AND wait_seconds>sla_seconds) AS sla_missed_calls,
 ROUND(100.0*COUNT(*) FILTER (WHERE status='answered' AND wait_seconds>sla_seconds)
       /NULLIF(COUNT(*) FILTER (WHERE status='answered'),0),2) AS sla_miss_rate_pct
FROM wfm_master_calls 
GROUP BY queue 
ORDER BY sla_miss_rate_pct DESC;


-- 9. 30-Minute Interval Demand Analysis

SELECT
    call_date,
    DATE_TRUNC('hour', started_at)
        + (EXTRACT(MINUTE FROM started_at)::INTEGER / 30)
        * INTERVAL '30 minutes' AS interval_start,

    COUNT(*) AS total_calls,

    COUNT(*) FILTER (
        WHERE status = 'answered'
    ) AS answered_calls,

    COUNT(*) FILTER (
        WHERE status = 'abandoned'
    ) AS abandoned_calls,

    ROUND(
        AVG(wait_seconds) FILTER (
            WHERE status = 'answered'
        )::NUMERIC, 2
    ) AS avg_wait_seconds,

    ROUND(
        SUM(handle_seconds) FILTER (
            WHERE status = 'answered'
        )::NUMERIC / 60, 2
    ) AS workload_minutes

FROM public.master_calls

GROUP BY
    call_date,
    interval_start

ORDER BY
    call_date,
    interval_start;
