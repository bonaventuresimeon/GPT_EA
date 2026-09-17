# GPT_EA R6 Runner-Recovery Test Matrix

These cases validate the transition from the known pre-runner failure to acceptable release CI evidence. They do not replace the CI bundle tests.

| ID | Case | Required result |
|---|---|---|
| RR-001 | Historical incident has runner_id=0, empty runner name and zero executed steps | Recorded as PRE_RUNNER_NO_STEPS; never PASS |
| RR-002 | Recovery probe still returns runner_id=0 | HOLD; validator FAIL |
| RR-003 | Recovery probe has runner_id>0 but conclusion failure | HOLD; validator FAIL |
| RR-004 | Recovery probe has runner_id>0 and >=1 executed step, conclusion success | Probe portion PASS |
| RR-005 | Static release job runner_id=0 or <7 executed steps | Validator FAIL |
| RR-006 | Static job conclusion not success | Validator FAIL |
| RR-007 | Static job head SHA differs from frozen candidate | Validator FAIL |
| RR-008 | Static CI bundle digest differs from runner-recovery record | Validator FAIL |
| RR-009 | Runner-recovery static job IDs differ from release ci_static IDs | Final release validator FAIL |
| RR-010 | Private status/billing/budget/payment checks not recorded true | Validator FAIL |
| RR-011 | Operator decision remains HOLD | Validator FAIL |
| RR-012 | Evidence digest missing/tampered | Validator FAIL |
| RR-013 | Complete recovery record + exact candidate CI bundle | Runner-recovery validator PASS |
| RR-014 | Part28B runner-recovery inputs absent/default | REAL remains blocked |
| RR-015 | Runner recovery passes but CI bundle fails | REAL remains blocked |
| RR-016 | CI passes but runner-recovery evidence invalid | REAL remains blocked |
| RR-017 | Recovered environment later regresses to PRE_RUNNER_NO_STEPS | New release state HOLD; investigate before further evidence |
| RR-018 | Final-review basis changes runner-recovery object after GO review | Final review digest mismatch/FAIL |

Archive run/job URLs or API exports for the incident, recovery probe and exact-candidate static run. Never convert a pre-runner failure into PASS by manually entering non-zero IDs.
