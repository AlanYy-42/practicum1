# Data Cleaning and Preprocessing

## Dataset: SQL-Engage v1.0
**Source:** Adaptive Learning and Gamification Lab (ALGL), Northeastern University Vancouver  
**Original size:** 1,500 records  
**Team A subset (syntax + schema errors):** 1,041 records

---

## 1. Filtering

The full dataset contains four error categories: syntax, schema, logic, and construction. As Team A, only syntax and schema error records were retained for analysis.

| Error Type   | Original Count | Retained |
|--------------|---------------|----------|
| syntax       | 846           | Yes   |
| schema       | 195           | Yes   |
| logic        | 394           | No    |
| construction | 65            | No    |
| **Total**    | **1,500**     | **1,041**|

---

## 2. Missing Values

All six columns in the dataset were checked for null values. No missing values were found in any column.

| Column                    | Null Count |
|---------------------------|-----------|
| query                     | 0         |
| error_type                | 0         |
| error_subtype             | 0         |
| emotion                   | 0         |
| feedback_target           | 0         |
| intended_learning_outcome | 0         |

No imputation or row removal was required.

---

## 3. Derived Column: sql_concept

The original dataset does not include a SQL concept column. To support concept-level analysis (required by Task 2), a `sql_concept` column was derived from the `query` field by detecting SQL keywords in the following priority order:

| Priority | Keyword detected | Assigned concept |
|----------|-----------------|-----------------|
| 1        | GROUP BY        | GROUP BY        |
| 2        | HAVING          | HAVING          |
| 3        | JOIN            | JOIN            |
| 4        | ORDER BY        | ORDER BY        |
| 5        | WHERE           | WHERE           |
| 6        | DISTINCT        | DISTINCT        |
| 7        | SELECT (×2)     | SUBQUERY        |
| 8        | INSERT          | INSERT          |
| 9        | UPDATE          | UPDATE          |
| 10       | DELETE          | DELETE          |
| default  | (none above)    | SELECT          |

This extraction was performed in Python prior to loading into MySQL. The resulting distribution across the 1,041 Team A records is:

| sql_concept | Count |
|-------------|-------|
| WHERE       | 469   |
| GROUP BY    | 153   |
| JOIN        | 152   |
| SELECT      | 131   |
| ORDER BY    | 73    |
| DISTINCT    | 33    |
| INSERT      | 22    |
| SUBQUERY    | 5     |
| UPDATE      | 2     |
| HAVING      | 1     |

---

## 4. Normalization into Lookup Tables

To satisfy 3NF requirements, the following columns were extracted into separate lookup tables before loading:

| Column                    | Lookup Table    | Unique Values |
|---------------------------|-----------------|--------------|
| error_type                | ErrorType       | 2            |
| error_subtype             | ErrorSubtype    | 16           |
| emotion                   | Emotion         | 5            |
| sql_concept (derived)     | SQLConcept      | 10           |
| intended_learning_outcome | LearningOutcome | 130          |

The `feedback_target` column was retained directly in the `Submission` table as it is unique per record and not normalizable.

---

## 5. Text Escaping

SQL query strings and feedback messages contain single quotes (e.g., `WHERE Status = 'Active'`). All single quotes were escaped as `''` and backslashes as `\\` prior to insertion into MySQL to prevent syntax errors during data loading.

---

## 6. Summary

No records were dropped for data quality reasons. The only transformations applied were:
- Filtering to syntax and schema records
- Derivation of the `sql_concept` column from query text
- Normalization of categorical columns into lookup tables
- Text escaping for safe MySQL insertion
