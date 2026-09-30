-- ============================================================
-- 转化漏斗分析（修正版）：事件级 / 严格有序 / 意向分组 三层口径
-- 数据表：user_behavior_clean（已清洗）
-- ============================================================

-- 【1】事件级级联比率：每 100 次浏览对应多少次加购、购买（流量结构，非漏斗）
SELECT
    ROUND(
        SUM(CASE WHEN behavior_type = 3 THEN 1 ELSE 0 END) * 100.0
        / NULLIF(SUM(CASE WHEN behavior_type = 1 THEN 1 ELSE 0 END), 0), 2
    ) AS 每100次浏览对应加购,
    ROUND(
        SUM(CASE WHEN behavior_type = 4 THEN 1 ELSE 0 END) * 100.0
        / NULLIF(SUM(CASE WHEN behavior_type = 1 THEN 1 ELSE 0 END), 0), 2
    ) AS 每100次浏览对应购买,
    ROUND(
        SUM(CASE WHEN behavior_type = 4 THEN 1 ELSE 0 END) * 100.0
        / NULLIF(SUM(CASE WHEN behavior_type = 3 THEN 1 ELSE 0 END), 0), 2
    ) AS 加购与购买事件比
FROM user_behavior_clean;

-- 【2】严格有序漏斗：用户 × 商品配对，要求 浏览 → 加购 → 购买 时间严格递增
WITH item_seq AS (
    SELECT
        user_id,
        item_id,
        MIN(CASE WHEN behavior_type = 1 THEN time END) AS t_pv,
        MIN(CASE WHEN behavior_type = 3 THEN time END) AS t_cart
    FROM user_behavior_clean
    GROUP BY user_id, item_id
),
pv_cart AS (
    SELECT user_id, item_id, t_cart
    FROM item_seq
    WHERE t_pv IS NOT NULL AND t_cart IS NOT NULL AND t_cart >= t_pv
),
pv_cart_buy AS (
    SELECT p.user_id, p.item_id
    FROM pv_cart p
    JOIN user_behavior_clean b
        ON b.user_id = p.user_id
       AND b.item_id = p.item_id
       AND b.behavior_type = 4
       AND b.time >= p.t_cart
    GROUP BY p.user_id, p.item_id
)
SELECT
    (SELECT COUNT(*) FROM item_seq WHERE t_pv IS NOT NULL)                AS 浏览配对,
    (SELECT COUNT(*) FROM pv_cart)                                       AS 浏览后加购,
    ROUND((SELECT COUNT(*) FROM pv_cart) * 100.0
        / (SELECT COUNT(*) FROM item_seq WHERE t_pv IS NOT NULL), 2)      AS 浏览后加购率,
    (SELECT COUNT(*) FROM pv_cart_buy)                                   AS 加购后购买,
    ROUND((SELECT COUNT(*) FROM pv_cart_buy) * 100.0
        / (SELECT COUNT(*) FROM pv_cart), 2)                             AS 加购后购买率,
    ROUND((SELECT COUNT(*) FROM pv_cart_buy) * 100.0
        / (SELECT COUNT(*) FROM item_seq WHERE t_pv IS NOT NULL), 2)      AS 整体转化率
;

-- 【3】意向分组购买率：有收藏/加购 vs 无收藏/加购（相关关系，非因果）
SELECT
    CASE WHEN 有收藏或加购 = 1 THEN '有收藏或加购' ELSE '无收藏且无加购' END AS 用户类型,
    COUNT(*)                                                              AS 用户数,
    SUM(有购买)                                                            AS 购买用户,
    ROUND(SUM(有购买) * 100.0 / COUNT(*), 2)                               AS 购买率
FROM (
    SELECT
        user_id,
        MAX(CASE WHEN behavior_type IN (2, 3) THEN 1 ELSE 0 END) AS 有收藏或加购,
        MAX(CASE WHEN behavior_type = 4 THEN 1 ELSE 0 END)        AS 有购买
    FROM user_behavior_clean
    GROUP BY user_id
) t
GROUP BY 有收藏或加购
ORDER BY 有收藏或加购 DESC;

-- 性能建议：大数据量下为 (user_id, item_id, behavior_type, time) 建立组合索引
