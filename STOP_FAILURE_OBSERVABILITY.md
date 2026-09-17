# GPT_EA Stop-Failure Observability Contract

Runtime file: `GPT_EA_StopFailures.csv` in the MT5 Common Files area.

Every material stop-management failure or escalation must be traceable by durable `POSITION_IDENTIFIER` and broker/server context.

## Required fields

| Field | Meaning |
|---|---|
| `time` | trade-server timestamp |
| `broker` | account broker/company |
| `server` | connected trade server |
| `account_mode` | netting/exchange/hedging margin mode |
| `symbol` | actual resolved broker symbol |
| `position_id` | durable position lifecycle ID |
| `ticket` | current broker position ticket |
| `side` | BUY/SELL |
| `context` | BE/profit-lock/trail/critical/emergency context |
| `class` | normalized broker failure class |
| `retcode` | MT5 trade result code |
| `retcode_text` | broker/terminal description |
| `failure_count` | durable failure count |
| `critical` | whether protection is missing/critical |
| `current_sl` | server-side SL at observation time |
| `requested_or_reference_sl` | candidate/reference SL where available |
| `entry` | position entry |
| `r_now` | current R multiple when available |
| `spread_pts` | current Bid/Ask spread in symbol points |
| `stops_level_pts` | broker minimum stops level |
| `freeze_level_pts` | broker freeze level |
| `execution_mode` | symbol execution mode |
| `tp1_partial` | TP1 partial already completed |
| `tp1_done` | TP1 + required protection complete |
| `tp2_partial` | TP2 scale-out complete |
| `protection_stage` | actual SL stage (initial/BE/profit/strong lock) |
| `retry_seconds` | broker-class-specific retry delay |
| `reason` | human-readable cause |

## Required event behavior

- First expected stop failure is observable.
- Warning/pause/critical escalation remains in the execution journal and the stop-failure CSV.
- Recovery is visible through the normal `STOP_UPDATE_RECOVERED` execution event.
- Missing-SL emergency close is visible through `EMERGENCY_CLOSE_UNPROTECTED`.
- Requotes and stale prices must be distinguishable from invalid-stops/freeze failures.
- Market-closed and connectivity failures must be distinguishable from permanent configuration failures.
- Partial-protection state must be visible so an operator can tell whether profit was taken before BE became secure.

## Operational metrics

The release/dashboard analytics should be able to derive:

- stop-update failure count by broker/symbol;
- failure rate by BE / profit-lock / trail stage;
- average retries before recovery;
- time from TP1 partial to BE protection;
- count of partial-protection hazards;
- count of missing-SL critical events;
- emergency-close attempts and failures;
- failure distribution by retcode/class;
- failures by spread/stop/freeze regime;
- failures by account mode and execution mode.

## Alerting invariants

- do not alert on normal no-op trail calculations;
- alert at configured warning thresholds;
- critical missing-SL conditions alert immediately;
- avoid an alert storm every timer cycle;
- a safety pause remains operator-controlled even if a later retry succeeds.

The CSV is an observability/audit source, not authorization. Logging failure must never substitute for actually preserving or repairing protection.
