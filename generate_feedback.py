#!/usr/bin/env python3
"""
CS5200 Practicum 1 | Team A | SQL-Engage
Task 3: LLM-Based Feedback Generation
"""

import os
import sys
import time

import mysql.connector
import anthropic

MODEL = "claude-sonnet-4-20250514"   # required by the practicum
TOP_N = 5
MAX_TOKENS = 400
TEMPERATURE = 0.0
SLEEP_BETWEEN_CALLS = 2

SYSTEM_PROMPT = (
    "You are a patient SQL tutor for students writing their first SQL queries. "
    "When shown a faulty query, you reply with ONE short feedback message of 2-4 "
    "sentences. The message must: (1) name what is wrong, (2) briefly explain why "
    "it is wrong, and (3) tell the student what to do differently. Use an "
    "encouraging, beginner-appropriate tone. Do NOT rewrite the full corrected "
    "query for them and do NOT add headings, bullet points, or code blocks."
)

USER_PROMPT_TEMPLATE = """A student practicing the SQL concept "{concept}" made an error.

Error category: {error_type}
Error pattern: {subtype}

The student submitted this query:
{query}

Correct expectation (what they should learn): {outcome}

Write the feedback message this student would receive."""


def db_connect():
    return mysql.connector.connect(
        host=os.getenv("DB_HOST", "127.0.0.1"),
        port=int(os.getenv("DB_PORT", "3306")),
        user=os.getenv("DB_USER", "root"),
        password=os.getenv("DB_PASSWORD", ""),
        database=os.getenv("DB_NAME", "sql_engage_db"),
    )


def get_top_patterns(cur, n):
    cur.execute(
        """
        SELECT es.subtype_id, es.subtype_name, et.type_name, COUNT(*) AS frequency
        FROM Submission s
        JOIN ErrorSubtype es ON s.subtype_id = es.subtype_id
        JOIN ErrorType   et ON es.error_type_id = et.error_type_id
        GROUP BY es.subtype_id, es.subtype_name, et.type_name
        ORDER BY frequency DESC
        LIMIT %s
        """,
        (n,),
    )
    return cur.fetchall()


def get_example(cur, subtype_id):
    cur.execute(
        """
        SELECT s.submission_id, s.query_text, c.concept_name, lo.outcome_text
        FROM Submission s
        JOIN SQLConcept       c  ON s.concept_id = c.concept_id
        JOIN LearningOutcome  lo ON s.outcome_id = lo.outcome_id
        WHERE s.subtype_id = %s
        ORDER BY s.submission_id
        LIMIT 1
        """,
        (subtype_id,),
    )
    return cur.fetchone()


def store_feedback(cur, row):
    cur.execute(
        """
        INSERT INTO LLMFeedback
            (subtype_id, example_submission_id, model_name, prompt_text,
             generated_feedback, frequency_rank, error_frequency)
        VALUES (%(subtype_id)s, %(example_id)s, %(model)s, %(prompt)s,
                %(feedback)s, %(rank)s, %(freq)s)
        ON DUPLICATE KEY UPDATE
            example_submission_id = VALUES(example_submission_id),
            model_name            = VALUES(model_name),
            prompt_text           = VALUES(prompt_text),
            generated_feedback    = VALUES(generated_feedback),
            frequency_rank        = VALUES(frequency_rank),
            error_frequency       = VALUES(error_frequency),
            generated_at          = CURRENT_TIMESTAMP
        """,
        row,
    )


def main():
    if not os.getenv("ANTHROPIC_API_KEY"):
        sys.exit("ERROR: set ANTHROPIC_API_KEY before running.")

    claude = anthropic.Anthropic()
    conn = db_connect()
    cur = conn.cursor(dictionary=True)

    patterns = get_top_patterns(cur, TOP_N)
    print(f"Top {TOP_N} error patterns:")
    for i, p in enumerate(patterns, 1):
        print(f"  {i}. {p['subtype_name']} ({p['type_name']}) - {p['frequency']} occurrences")
    print()

    for rank, p in enumerate(patterns, 1):
        ex = get_example(cur, p["subtype_id"])
        if ex is None:
            print(f"[skip] no example for {p['subtype_name']}")
            continue

        prompt = USER_PROMPT_TEMPLATE.format(
            concept=ex["concept_name"],
            error_type=p["type_name"],
            subtype=p["subtype_name"],
            query=ex["query_text"],
            outcome=ex["outcome_text"],
        )

        print(f"[{rank}/{len(patterns)}] generating feedback for '{p['subtype_name']}'...")
        try:
            resp = claude.messages.create(
                model=MODEL,
                max_tokens=MAX_TOKENS,
                temperature=TEMPERATURE,
                system=SYSTEM_PROMPT,
                messages=[{"role": "user", "content": prompt}],
            )
            feedback = "".join(
                block.text for block in resp.content if block.type == "text"
            ).strip()
        except Exception as e:
            print(f"   API error: {e}")
            continue

        store_feedback(
            cur,
            {
                "subtype_id": p["subtype_id"],
                "example_id": ex["submission_id"],
                "model": MODEL,
                "prompt": prompt,
                "feedback": feedback,
                "rank": rank,
                "freq": p["frequency"],
            },
        )
        conn.commit()
        print(f"   stored: {feedback[:80]}{'...' if len(feedback) > 80 else ''}\n")
        time.sleep(SLEEP_BETWEEN_CALLS)

    cur.execute(
        """
        SELECT lf.frequency_rank, es.subtype_name, lf.error_frequency,
               LEFT(lf.generated_feedback, 70) AS preview
        FROM LLMFeedback lf
        JOIN ErrorSubtype es ON lf.subtype_id = es.subtype_id
        ORDER BY lf.frequency_rank
        """
    )
    print("Stored feedback rows:")
    for r in cur.fetchall():
        print(f"  #{r['frequency_rank']} {r['subtype_name']} ({r['error_frequency']}): {r['preview']}...")

    cur.close()
    conn.close()


if __name__ == "__main__":
    main()
