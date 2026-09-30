-- ============================================================
-- RFM 用户价值分层（修正版）：NTILE 分位打分 + 经典 8 分类
-- 数据表：user_behavior_clean（已清洗）
-- 仅对有购买行为的用户分层
--
-- 局限说明（面试必讲）：
--   1. 本数据集没有“金额”字段，M 用“购买不同商品数”代理，非真实消费金额；
--   2. NTILE 按分位切分，同分时按行顺序分配，可能造成边界用户落点略有差异；
--   3. F（购买次数）与 M（购买商品数）近似共线，8 分类实际退化为 4~5 个有效类别。
-- ============================================================

WITH user_rfm AS (
    -- 计算每个购买用户的 R、F、M
    SELECT
        user_id,
        DATEDIFF('2014-12-19', MAX(CASE WHEN behavior_type = 4 THEN time END)) AS R,
        COUNT(CASE WHEN behavior_type = 4 THEN 1 END)                          AS F,
        COUNT(DISTINCT CASE WHEN behavior_type = 4 THEN item_id END)           AS M
    FROM user_behavior_clean
    GROUP BY user_id
    HAVING COUNT(CASE WHEN behavior_type = 4 THEN 1 END) > 0
),
scored AS (
    -- 分位打分：R 越小越好（反向），F、M 越大越好
    SELECT
        user_id, R, F, M,
        6 - NTILE(5) OVER (ORDER BY R ASC) AS R_score,
        NTILE(5) OVER (ORDER BY F ASC)     AS F_score,
        NTILE(5) OVER (ORDER BY M ASC)     AS M_score
    FROM user_rfm
),
labeled AS (
    -- 经典 8 分类：R/F/M 各以 4 分为界（高=前 40%，低=后 60%）
    SELECT
        R, F, M,
        CASE
            WHEN R_score >= 4 AND F_score >= 4 AND M_score >= 4 THEN '重要价值客户'
            WHEN R_score <  4 AND F_score >= 4 AND M_score >= 4 THEN '重要保持客户'
            WHEN R_score >= 4 AND F_score <  4 AND M_score >= 4 THEN '重要发展客户'
            WHEN R_score <  4 AND F_score <  4 AND M_score >= 4 THEN '重要挽留客户'
            WHEN R_score >= 4 AND F_score >= 4 AND M_score <  4 THEN '一般价值客户'
            WHEN R_score <  4 AND F_score >= 4 AND M_score <  4 THEN '一般保持客户'
            WHEN R_score >= 4 AND F_score <  4 AND M_score <  4 THEN '一般发展客户'
            ELSE '一般挽留客户'
        END AS 客户类型
    FROM scored
)
SELECT
    客户类型,
    COUNT(*)                                                       AS 用户数,
    ROUND(COUNT(*) / SUM(COUNT(*)) OVER () * 100, 2)               AS 占比_百分比,
    ROUND(AVG(R), 1)                                               AS 平均R_最近购买间隔天,
    ROUND(AVG(F), 1)                                               AS 平均F_购买次数,
    ROUND(AVG(M), 1)                                               AS 平均M_购买商品数
FROM labeled
GROUP BY 客户类型
ORDER BY 用户数 DESC;

-- 可选：查看“重要四格 / 一般四格”的整体占比（结构上必然约 40% / 60%）
-- 重要四格要求 M 高（前 40%），一般四格要求 M 低（后 60%），与阈值松紧无关。
