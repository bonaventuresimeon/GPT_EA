# GPT_EA R6 Lifecycle & Demo-Soak Release Test Matrix

This matrix is release blocking for the stale-approval lifecycle fix and the R6 machine-observed demo-soak evidence path. Source presence alone is not a PASS.

## A. Stale approval lifecycle

### LS-001 fresh revalidation rejection after human approval
- Produce a HIGH-CONFIDENCE setup with `InpRequireApproval=true`.
- Confirm lifecycle becomes `WAIT_CONFIRMATION` with `LIFECYCLE_WAIT_HUMAN_APPROVAL`.
- Approve the prompt, then cause `FreshApprovalValidation()` to fail before order placement.
- Verify no broker order exists.
- On the next lifecycle/soak timer cycle, verify the symbol transitions to `INVALIDATED` and `LIFECYCLE_WAIT_KIND` clears.
- Verify `GPT_EA_Lifecycle.csv` records the reason.

### LS-002 market-confirmation wait is preserved
- Produce a `WAIT/REANALYZE` setup that is waiting for market structure rather than a human approval.
- Verify wait kind is `LIFECYCLE_WAIT_MARKET_CONFIRMATION`.
- Ensure no pending human approval exists.
- Run repeated timers.
- Verify the stale-human-approval reconciler does **not** invalidate this state solely because no approval object exists.

### LS-003 denial and approval timeout
- Deny one pending setup and let another expire.
- Verify cooldown behavior remains intact.
- Verify lifecycle becomes `INVALIDATED` and human wait-kind is cleared.

### LS-004 approval queue suppressed after scan
- Allow a scan to produce a high-confidence/human-wait state.
- Before `QueueForApproval` completes, activate a release/stop-health block.
- Verify no pending approval remains.
- Verify stale human wait reconciles to `INVALIDATED` with no order.

### LS-005 execution-path block before SENT
- Approve a valid prompt, then trigger an adaptive/broker/risk block before `SENT`.
- Verify no fill occurs and the stale human wait is later invalidated rather than remaining indefinitely.

### LS-006 successful approval path
- Approve a setup that passes all final gates.
- Verify normal state sequence continues to `APPROVED -> SENT -> FILLED`.
- Verify stale reconciliation never invalidates a symbol with an actual open GPT_EA position.

### LS-007 restart with stale human wait
- Persist/reproduce `WAIT_CONFIRMATION + HUMAN_APPROVAL` without an active pending approval or open position.
- Restart the EA.
- Verify initialization/timer reconciliation closes it to `INVALIDATED`.

### LS-008 soak disabled
- Set `InpEnableDemoSoakEvidence=false`.
- Reproduce LS-001.
- Verify stale human approval reconciliation still runs; lifecycle correctness must not depend on soak logging.

## B. Soak collector isolation and identity

### DS-001 demo/contest only
- On demo/contest, enable Part36 with an evidence ID >= 8 characters and verify collection starts.
- On REAL, verify the soak collector refuses collection and does not self-certify any release input.
- In Strategy Tester, verify the live soak collector remains inactive.

### DS-002 evidence-ID continuity
- Run with one evidence ID, accumulate counters, restart using the same ID and verify counters persist.
- Change to a new evidence ID and verify a new run resets its own machine counters.

### DS-003 restart counting
- Initialize the same candidate/evidence ID, then restart/reinitialize.
- Verify `restart_observed`/restart counter increments once per observed reinitialization and the event is journaled.

## C. Trading-day and session coverage

### DS-010 five consecutive trading days
- Run through five valid trading days with fresh configured-symbol quotes.
- Verify `trading_days`/max consecutive count reaches at least 5.
- Verify Friday -> Monday is treated as consecutive for the normal weekday contract.
- Verify a missing weekday resets the current consecutive streak.

### DS-011 fresh-quote requirement
- Remove/stale all configured-symbol quotes for a calendar day.
- Verify that day is not falsely counted as an observed trading day.

### DS-012 London / New York / overlap
- Observe three London days, three New York/U.S. cash days and at least one overlap.
- Verify each day is counted once per category despite repeated timer calls.

### DS-013 high-impact news day
- On a live demo terminal with native calendar availability, observe a mapped high-impact event for a configured symbol.
- Verify the news-day field records the observation once for that day.
- Verify Strategy Tester does not fabricate this evidence.

## D. Rollover and connectivity

### DS-020 rollover spread expansion
- Observe the configured UTC rollover window.
- Verify the window alone does not satisfy R6 rollover evidence.
- Require spread/M5-ATR to reach `InpDemoSoakRolloverSpreadATRFrac` and verify `rollover_observed` becomes true only after expansion.

### DS-021 disconnect/reconnect
- Create a controlled terminal/network disconnect on demo.
- Verify a disconnect is observed.
- Reconnect and verify reconnect count increments only after a previously observed disconnect.

## E. Scan coverage

### DS-030 scheduled scan
- Allow a London/U.S. scheduled scan reason to produce the multi-symbol scan.
- Verify `scheduled_scans` increments once for the scan cycle rather than once per symbol card.

### DS-031 continuous/new-M5 scan
- Trigger a continuous interval or new-M5 scan.
- Verify `continuous_scans` increments and is distinct from scheduled scans.

### DS-032 manual scan
- Click `SCAN NOW`.
- Verify the separate manual scan evidence count increments.
- Manual scan does not substitute for required scheduled and continuous scan counts.

### DS-033 scan deduplication
- With three configured symbols receiving cards from the same scan reason within the dedupe window, verify the run is counted once.

## F. Recovery checkpoint evidence

### DS-040 primary checkpoint update
- Allow `SafeUniversalCheckpointNow`/timer to write a new recovery checkpoint.
- Verify a changed `g_lastUniversalCheckpoint` increments primary checkpoint evidence.

### DS-041 validated backup checkpoint
- Verify the `.bak` file passes `RecoveryCheckpointHeaderValid`.
- Verify backup-checkpoint observation increments only when a valid completed backup exists.

### DS-042 incomplete backup
- Corrupt/remove the backup in a controlled test.
- Verify it does not count as valid backup evidence.

## G. Critical-state and zero-tolerance evidence

### DS-050 unprotected position
- In a controlled demo harness, create/detect a GPT_EA position with no SL.
- Verify unresolved critical state is non-zero and a zero-tolerance incident is recorded.

### DS-051 unprotected new authorization
- While a critical/unprotected state exists, create an active pending authorization in a controlled test.
- Verify `unprotected_new_authorizations` and the aggregate zero-tolerance count increment once per incident episode.

### DS-052 release/dashboard mismatch
- Inject a controlled mismatch between release summary and `g_releaseBlocked`.
- Verify `dashboard_gate_mismatches` increments and blocks machine readiness.

### DS-053 external reconciliation
- Introduce a duplicate order/partial, SL regression, analytics duplicate finalization, stop join failure, runtime critical error or secret-exposure finding in controlled evidence.
- Verify the final human report/release JSON reflects the true non-zero value even if the runtime collector did not directly observe the event.
- Verify the R6 validator rejects the release.

## H. Required logs

### DS-060 execution log presence
- Verify `GPT_EA_Execution.csv` exists in Common Files.

### DS-061 stop log presence
- Verify `GPT_EA_StopFailures.csv` header/file exists even when there were no material stop failures.

### DS-062 release evidence log presence
- Verify `GPT_EA_ReleaseEvidence.csv` exists and records PASS/BLOCK plus reason.

### DS-063 missing log
- Remove one required log in a controlled environment.
- Verify machine coverage is not READY and final schema/release evidence cannot be promoted as complete.

## I. JSON snapshot / digest / import

### DS-070 runtime snapshot structure
- Verify `GPT_EA_DemoSoakSnapshot.json` contains the `demo_soak_evidence_v1` fields expected by `SOAK_EVIDENCE_SCHEMA.json`.
- Verify `evidence_digest` is deliberately blank in the live runtime snapshot.

### DS-071 incomplete snapshot importer block
- Run `tools/import_soak_snapshot.py` before coverage is complete.
- Verify it fails and does not modify the release-evidence JSON.

### DS-072 missing report importer block
- Point `report_path` to a missing file.
- Verify import fails without modifying release evidence.

### DS-073 successful digest finalization
- Complete/reconcile the soak and report.
- Run the importer.
- Verify it calculates the canonical SHA-256 excluding `evidence_digest`, inserts the digest and updates only the `demo_soak` object in the target release evidence.

### DS-074 soak schema validator
- Run `tools/validate_soak_evidence.py`.
- Verify PASS only when required counts/booleans/zero fields/report/digest all satisfy the schema.

### DS-075 full release validator
- Run `tools/validate_release_evidence.py` on the exact candidate release bundle.
- Verify a valid soak is necessary but not sufficient: all other R6 gates and final-review evidence still must pass.

### DS-076 digest tamper
- Modify any finalized soak field without recomputing the digest.
- Verify soak/release validators fail.

## J. Part28 fail-closed promotion

### DS-080 schema mismatch
- Set `InpReleaseDemoSoakPassed=true` but use an incorrect `InpReleaseSoakSchemaVersion`.
- Verify REAL execution remains blocked.

### DS-081 digest missing/malformed
- Use blank or malformed soak digest.
- Verify REAL execution remains blocked.

### DS-082 insufficient coverage
- Keep any required day/session/event/scan/checkpoint count below threshold.
- Verify REAL execution remains blocked.

### DS-083 non-zero failure counter
- Set any R6 zero-tolerance field non-zero.
- Verify REAL execution remains blocked.

### DS-084 required log false
- Set any required log-presence input false.
- Verify REAL execution remains blocked.

### DS-085 complete soak still requires final GO
- Provide complete valid soak evidence while final operator review is incomplete/HOLD.
- Verify REAL execution remains blocked.

## R6 PASS rule

This matrix passes only when stale human approval waits cannot remain orphaned, legitimate market-confirmation waits are preserved, Part36 produces reproducible evidence on the exact demo candidate, the machine snapshot reconciles to the human report, schema/digest validators pass, every zero-tolerance field is reconciled, and Part28 remains fail-closed until all R6 release evidence and final GO review are complete.


## K. Per-day reconciliation acceptance v2

### DS-090 missing day checklist
- Finalize a five-day record with one missing `reconciliation_checklist_path` or missing file.
- Verify `tools/validate_five_day_soak_record.py` fails.

### DS-091 checklist not accepted
- Use an otherwise complete checklist that still says `HOLD DAY / ACCEPT DAY` or `HOLD DAY`.
- Verify validation fails until the completed artifact contains literal `Decision: **ACCEPT DAY**`.

### DS-092 checklist candidate/date mismatch
- Put a different day date or candidate Git SHA in a day checklist.
- Verify validation fails.

### DS-093 unreconciled machine day
- Set `day_reconciled=false`, blank `reconciled_by`, or blank `reconciled_at`.
- Verify validation fails.

### DS-094 duplicate checklist path
- Point two accepted days at the same checklist file.
- Verify validation fails.

### DS-095 complete five-day reconciliation v2
- Provide five unique dated checklists, matching candidate/date, literal `ACCEPT DAY`, reviewer and timestamp.
- Verify the five-day record finalizes and `demo_soak.acceptance_record_schema_version=five_day_soak_acceptance_v2`.

### DS-096 v1 downgrade attempt
- Replace the acceptance record/schema field with `five_day_soak_acceptance_v1`.
- Verify soak/release validators and Part28B supplemental gate reject it.
