USE sql_engage_db;

DROP TABLE IF EXISTS FeedbackEvaluation;

CREATE TABLE FeedbackEvaluation (
    eval_id        INT          NOT NULL AUTO_INCREMENT,
    feedback_id    INT          NOT NULL,
    rater_name     VARCHAR(50)  NOT NULL,
    dimension      VARCHAR(30)  NOT NULL,
    score          INT          NOT NULL,
    PRIMARY KEY (eval_id),
    CONSTRAINT fk_eval_feedback FOREIGN KEY (feedback_id)
        REFERENCES LLMFeedback(feedback_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT chk_score CHECK (score BETWEEN 1 AND 4)
);
