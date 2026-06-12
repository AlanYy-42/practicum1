USE sql_engage_db;

-- ============================================================
-- Task 2: SQL-Based Error Pattern Analysis
-- Team A | SQL-Engage Dataset | Syntax & Schema Errors
-- ============================================================

-- ============================================================
-- REQUIRED QUERY 1:
-- Frequency of each error subtype by SQL concept
-- ============================================================
SELECT
    c.concept_name                          AS sql_concept,
    es.subtype_name                         AS error_subtype,
    et.type_name                            AS error_type,
    COUNT(*)                                AS frequency
FROM Submission s
JOIN ErrorSubtype es ON s.subtype_id = es.subtype_id
JOIN ErrorType   et ON es.error_type_id = et.error_type_id
JOIN SQLConcept  c  ON s.concept_id = c.concept_id
GROUP BY c.concept_name, es.subtype_name, et.type_name
ORDER BY c.concept_name, frequency DESC;


-- ============================================================
-- NOTE ON REQUIRED QUERIES 2 & 3 (attempts / persistence)
-- ============================================================
-- The SQL-Engage dataset is a synthetic corpus without student
-- identifiers or attempt sequences. Unlike Team B (SQLRepair),
-- each row is an independent annotated query instance, not a
-- student submission in a session. Therefore:
--   - "average attempts before success/give up" cannot be
--     computed directly; we use error frequency per concept as
--     a proxy for learner difficulty.
--   - "error persistence rate" is approximated by measuring
--     the diversity of error subtypes per concept: concepts
--     with many distinct subtypes indicate broader, recurring
--     difficulty patterns.
-- This limitation is documented in Section 3 of the report.
-- ============================================================


-- ============================================================
-- REQUIRED QUERY 2 (adapted):
-- Proxy for attempt difficulty — average errors per concept
-- (total errors / distinct subtypes seen in that concept)
-- Higher ratio = fewer error types dominate = more persistent
-- ============================================================
SELECT
    c.concept_name                                      AS sql_concept,
    COUNT(*)                                            AS total_errors,
    COUNT(DISTINCT s.subtype_id)                        AS distinct_subtypes,
    ROUND(COUNT(*) / COUNT(DISTINCT s.subtype_id), 2)  AS avg_errors_per_subtype
FROM Submission s
JOIN SQLConcept c ON s.concept_id = c.concept_id
GROUP BY c.concept_name
ORDER BY avg_errors_per_subtype DESC;


-- ============================================================
-- REQUIRED QUERY 3 (adapted):
-- Error persistence proxy — for each concept, which subtype
-- is most dominant (persistence = top subtype share > 40%)
-- ============================================================
SELECT
    c.concept_name,
    es.subtype_name                                         AS dominant_subtype,
    COUNT(*)                                                AS dominant_count,
    total.total_errors,
    ROUND(COUNT(*) * 100.0 / total.total_errors, 1)        AS dominance_pct,
    CASE
        WHEN COUNT(*) * 100.0 / total.total_errors > 40
        THEN 'High persistence'
        ELSE 'Distributed'
    END                                                     AS persistence_label
FROM Submission s
JOIN SQLConcept  c  ON s.concept_id  = c.concept_id
JOIN ErrorSubtype es ON s.subtype_id = es.subtype_id
JOIN (
    SELECT concept_id, COUNT(*) AS total_errors
    FROM Submission
    GROUP BY concept_id
) total ON total.concept_id = s.concept_id
GROUP BY c.concept_name, es.subtype_name, total.total_errors
HAVING dominant_count = (
    SELECT MAX(cnt) FROM (
        SELECT COUNT(*) AS cnt
        FROM Submission s2
        WHERE s2.concept_id = s.concept_id
        GROUP BY s2.subtype_id
    ) sub
)
ORDER BY dominance_pct DESC;


-- ============================================================
-- REQUIRED QUERY 4:
-- Concept difficulty ranking
-- Ranked by: total errors DESC, then subtype diversity ASC
-- (more errors + fewer subtype variety = harder/more confusing)
-- ============================================================
CREATE OR REPLACE VIEW v_concept_difficulty AS
SELECT
    c.concept_name,
    COUNT(*)                            AS total_errors,
    COUNT(DISTINCT s.subtype_id)        AS subtype_diversity,
    SUM(CASE WHEN et.type_name = 'syntax' THEN 1 ELSE 0 END)  AS syntax_errors,
    SUM(CASE WHEN et.type_name = 'schema' THEN 1 ELSE 0 END)  AS schema_errors,
    RANK() OVER (
        ORDER BY COUNT(*) DESC, COUNT(DISTINCT s.subtype_id) ASC
    )                                   AS difficulty_rank
FROM Submission s
JOIN SQLConcept  c  ON s.concept_id = c.concept_id
JOIN ErrorSubtype es ON s.subtype_id = es.subtype_id
JOIN ErrorType   et ON es.error_type_id = et.error_type_id
GROUP BY c.concept_name;

SELECT * FROM v_concept_difficulty ORDER BY difficulty_rank;


-- ============================================================
-- ADDITIONAL QUERY 1:
-- Emotion distribution across error subtypes
-- Reveals which errors cause the most frustration (anger/sadness)
-- ============================================================
SELECT
    es.subtype_name,
    em.emotion_name,
    COUNT(*)                                            AS count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER
        (PARTITION BY es.subtype_name), 1)             AS pct_within_subtype
FROM Submission s
JOIN ErrorSubtype es ON s.subtype_id = es.subtype_id
JOIN Emotion     em ON s.emotion_id  = em.emotion_id
GROUP BY es.subtype_name, em.emotion_name
ORDER BY es.subtype_name, count DESC;


-- ============================================================
-- ADDITIONAL QUERY 2:
-- Schema vs Syntax error distribution per SQL concept
-- Reveals which concepts generate structural confusion (schema)
-- vs syntactic slip-ups (syntax)
-- ============================================================
SELECT
    c.concept_name,
    SUM(CASE WHEN et.type_name = 'syntax' THEN 1 ELSE 0 END) AS syntax_count,
    SUM(CASE WHEN et.type_name = 'schema' THEN 1 ELSE 0 END) AS schema_count,
    COUNT(*)                                                   AS total,
    ROUND(SUM(CASE WHEN et.type_name = 'schema' THEN 1 ELSE 0 END)
          * 100.0 / COUNT(*), 1)                              AS schema_pct
FROM Submission s
JOIN SQLConcept  c  ON s.concept_id = c.concept_id
JOIN ErrorSubtype es ON s.subtype_id = es.subtype_id
JOIN ErrorType   et ON es.error_type_id = et.error_type_id
GROUP BY c.concept_name
ORDER BY schema_pct DESC;


-- ============================================================
-- STORED PROCEDURE:
-- Get top N most frequent error subtypes overall
-- Usage: CALL GetTopErrorSubtypes(5);
-- ============================================================
DROP PROCEDURE IF EXISTS GetTopErrorSubtypes;

DELIMITER $$
CREATE PROCEDURE GetTopErrorSubtypes(IN top_n INT)
BEGIN
    SELECT
        es.subtype_name,
        et.type_name        AS error_type,
        COUNT(*)            AS frequency,
        RANK() OVER (ORDER BY COUNT(*) DESC) AS rnk
    FROM Submission s
    JOIN ErrorSubtype es ON s.subtype_id = es.subtype_id
    JOIN ErrorType   et ON es.error_type_id = et.error_type_id
    GROUP BY es.subtype_name, et.type_name
    ORDER BY frequency DESC
    LIMIT top_n;
END$$
DELIMITER ;

CALL GetTopErrorSubtypes(10);
