# GPT_EA Deployment Drift Test Matrix

This matrix validates `GPT_EA_Part29_DeploymentDriftGuard.mqh` and is **release blocking** when deployment-profile attestation is required.

## Purpose

A broker/account environment can change after validation. The EA therefore captures structural symbol properties at initialization and blocks new entries if material contract properties drift unexpectedly during the running deployment.

Dynamic spread, stops-level and freeze-level changes are *not* treated as structural drift because they can legitimately vary and are already handled by live execution/stop gates.

## Required cases

| ID | Priority | Scenario | Expected result |
|---|---|---|---|
| DD-001 | HIGH | Baseline capture on startup | All resolved configured symbols receive a structural baseline |
| DD-002 | HIGH | Stable broker session | Drift gate remains PASS |
| DD-003 | HIGH | Expected broker company matches | PASS |
| DD-004 | HIGH | Expected broker company mismatch | New entries BLOCKED |
| DD-005 | HIGH | Expected trade server mismatch | New entries BLOCKED |
| DD-006 | HIGH | Expected account currency mismatch | New entries BLOCKED |
| DD-007 | HIGH | Expected margin mode mismatch | New entries BLOCKED |
| DD-008 | HIGH | Expected account leverage mismatch | New entries BLOCKED |
| DD-009 | HIGH | Symbol disappears/unavailable after baseline | New entries BLOCKED |
| DD-010 | HIGH | Digits change | New entries BLOCKED |
| DD-011 | HIGH | `SYMBOL_POINT` changes | New entries BLOCKED |
| DD-012 | HIGH | tick size changes | New entries BLOCKED |
| DD-013 | HIGH | contract size changes | New entries BLOCKED |
| DD-014 | HIGH | volume step changes | New entries BLOCKED |
| DD-015 | HIGH | calculation mode changes | New entries BLOCKED |
| DD-016 | HIGH | execution mode changes | New entries BLOCKED |
| DD-017 | HIGH | filling mode changes | New entries BLOCKED |
| DD-018 | HIGH | Spread widens only | No structural-drift block; normal spread gate handles it |
| DD-019 | HIGH | stops level changes only | No structural-drift block; live stop gate handles it |
| DD-020 | HIGH | freeze level changes only | No structural-drift block; live stop gate handles it |
| DD-021 | HIGH | Existing position open when drift occurs | Existing position remains managed; no new authorization |
| DD-022 | HIGH | Approval pending when drift becomes active | Fresh validation rejects execution |
| DD-023 | HIGH | Dashboard/timer refresh after drift | Release state shows BLOCKED with reason |
| DD-024 | HIGH | Restart after broker migration/spec change | New baseline is captured only after operator/release review; release evidence must be revalidated |

## Expected identity policy

`InpRequireExpectedIdentityOnReal` may be enabled for stricter deployments. When enabled on a real account, expected broker, server and account currency must be deliberately supplied locally.

Optional exact checks:

- `InpExpectedBrokerCompany`
- `InpExpectedTradeServer`
- `InpExpectedAccountCurrency`
- `InpExpectedMarginMode`
- `InpExpectedAccountLeverage`

These values should come from the intended deployment account, not from assumptions or another broker.

## PASS criteria

- all applicable HIGH cases pass;
- structural drift cannot authorize a new order;
- existing positions continue protective management;
- normal dynamic spread/stops/freeze changes do not create false structural-drift blocks;
- mismatch reason is visible in release/dashboard logging;
- deployment change forces operator review/revalidation rather than silent continuation.

`InpReleaseDeploymentProfilePassed=true` may be set only after this matrix and the intended broker profile have been validated and archived.