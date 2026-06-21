USE sql_engage_db;

DROP TABLE IF EXISTS LLMFeedback;

CREATE TABLE LLMFeedback (
    feedback_id           INT          NOT NULL AUTO_INCREMENT,
    subtype_id            INT          NOT NULL,
    example_submission_id INT          NOT NULL,
    model_name            VARCHAR(100) NOT NULL,
    prompt_text           TEXT         NOT NULL,
    generated_feedback    TEXT         NOT NULL,
    frequency_rank        INT          NOT NULL,
    error_frequency       INT          NOT NULL,
    generated_at          DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (feedback_id),
    UNIQUE KEY uq_fb_subtype (subtype_id),
    CONSTRAINT fk_fb_subtype FOREIGN KEY (subtype_id)
        REFERENCES ErrorSubtype(subtype_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_fb_example FOREIGN KEY (example_submission_id)
        REFERENCES Submission(submission_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);
