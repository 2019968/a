-- 多路径转化漏斗
WITH user_buy AS (
    SELECT DISTINCT user_id FROM user_behavior_clean WHERE behavior_type = 4
)
SELECT
    '浏览→购买' AS 转化路径,
    COUNT(DISTINCT ub.user_id) AS 上游行为用户数,
    COUNT(DISTINCT CASE WHEN ub.user_id IN (SELECT user_id FROM user_buy) THEN ub.user_id END) AS 购买用户数,
    ROUND(COUNT(DISTINCT CASE WHEN ub.user_id IN (SELECT user_id FROM user_buy) THEN ub.user_id END) / COUNT(DISTINCT ub.user_id) * 100, 2) AS 转化率_百分比
FROM user_behavior_clean ub WHERE behavior_type = 1

UNION ALL

SELECT
    '收藏→购买' AS 转化路径,
    COUNT(DISTINCT ub.user_id) AS 上游行为用户数,
    COUNT(DISTINCT CASE WHEN ub.user_id IN (SELECT user_id FROM user_buy) THEN ub.user_id END) AS 购买用户数,
    ROUND(COUNT(DISTINCT CASE WHEN ub.user_id IN (SELECT user_id FROM user_buy) THEN ub.user_id END) / COUNT(DISTINCT ub.user_id) * 100, 2) AS 转化率_百分比
FROM user_behavior_clean ub WHERE behavior_type = 2

UNION ALL

SELECT
    '加购→购买' AS 转化路径,
    COUNT(DISTINCT ub.user_id) AS 上游行为用户数,
    COUNT(DISTINCT CASE WHEN ub.user_id IN (SELECT user_id FROM user_buy) THEN ub.user_id END) AS 购买用户数,
    ROUND(COUNT(DISTINCT CASE WHEN ub.user_id IN (SELECT user_id FROM user_buy) THEN ub.user_id END) / COUNT(DISTINCT ub.user_id) * 100, 2) AS 转化率_百分比
FROM user_behavior_clean ub WHERE behavior_type = 3;
