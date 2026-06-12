-- ============================================================
-- CS5200 Practicum 1 | Team A | SQL-Engage Dataset
-- Schema: sql_engage_db
-- Normal Form: 3NF
-- ============================================================

DROP DATABASE IF EXISTS sql_engage_db;
CREATE DATABASE sql_engage_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE sql_engage_db;

-- ------------------------------------------------------------
-- 1. ErrorType: enumeration of error categories
-- ------------------------------------------------------------
CREATE TABLE ErrorType (
    error_type_id   INT          NOT NULL AUTO_INCREMENT,
    type_name       VARCHAR(50)  NOT NULL,
    PRIMARY KEY (error_type_id),
    UNIQUE KEY uq_type_name (type_name)
);

-- ------------------------------------------------------------
-- 2. ErrorSubtype: 23 subtypes, each belonging to one ErrorType
-- ------------------------------------------------------------
CREATE TABLE ErrorSubtype (
    subtype_id      INT          NOT NULL AUTO_INCREMENT,
    subtype_name    VARCHAR(100) NOT NULL,
    error_type_id   INT          NOT NULL,
    PRIMARY KEY (subtype_id),
    UNIQUE KEY uq_subtype_name (subtype_name),
    CONSTRAINT fk_subtype_type FOREIGN KEY (error_type_id)
        REFERENCES ErrorType(error_type_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

-- ------------------------------------------------------------
-- 3. Emotion: learner affective state
-- ------------------------------------------------------------
CREATE TABLE Emotion (
    emotion_id      INT          NOT NULL AUTO_INCREMENT,
    emotion_name    VARCHAR(50)  NOT NULL,
    PRIMARY KEY (emotion_id),
    UNIQUE KEY uq_emotion_name (emotion_name)
);

-- ------------------------------------------------------------
-- 4. SQLConcept: SQL keyword/clause tested
-- ------------------------------------------------------------
CREATE TABLE SQLConcept (
    concept_id      INT          NOT NULL AUTO_INCREMENT,
    concept_name    VARCHAR(50)  NOT NULL,
    PRIMARY KEY (concept_id),
    UNIQUE KEY uq_concept_name (concept_name)
);

-- ------------------------------------------------------------
-- 5. LearningOutcome: intended learning objective per submission
-- ------------------------------------------------------------
CREATE TABLE LearningOutcome (
    outcome_id      INT          NOT NULL AUTO_INCREMENT,
    outcome_text    TEXT         NOT NULL,
    PRIMARY KEY (outcome_id)
);

-- ------------------------------------------------------------
-- 6. Submission: main fact table (1 row = 1 query instance)
--    feedback_target stays here: unique per row, not normalizable
-- ------------------------------------------------------------
CREATE TABLE Submission (
    submission_id   INT          NOT NULL AUTO_INCREMENT,
    query_text      TEXT         NOT NULL,
    subtype_id      INT          NOT NULL,
    emotion_id      INT          NOT NULL,
    concept_id      INT          NOT NULL,
    outcome_id      INT          NOT NULL,
    feedback_target TEXT         NOT NULL,
    PRIMARY KEY (submission_id),
    CONSTRAINT fk_sub_subtype  FOREIGN KEY (subtype_id)
        REFERENCES ErrorSubtype(subtype_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_sub_emotion  FOREIGN KEY (emotion_id)
        REFERENCES Emotion(emotion_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_sub_concept  FOREIGN KEY (concept_id)
        REFERENCES SQLConcept(concept_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_sub_outcome  FOREIGN KEY (outcome_id)
        REFERENCES LearningOutcome(outcome_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);
