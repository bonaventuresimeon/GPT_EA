# GPT_EA MetaEditor Compile Gate

This gate is **release blocking**. `GPT_EA.mq5` is not eligible for Strategy Tester, demo-soak certification or real-account release certification until this gate passes on the MetaTrader 5 installation/build intended for validation.

## 1. Required compile target

Compile exactly:

`GPT_EA.mq5`

Do not certify an isolated `.mqh` module or an older copied entry file. The compiled `.ex5` must be produced from the exact Git commit being released.

## 2. Hard PASS criteria

A compile PASS requires all of the following:

- **0 compile errors**.
- **0 unresolved warnings** for the candidate release. The engineering target is 0 warnings; any warning that remains must block release until it is understood, documented and explicitly accepted by the release owner. For real-account R3/R4-style certification, the preferred rule is simply 0 warnings.
- All local includes referenced by `GPT_EA.mq5` resolve from the expected repository copy.
- Exactly one implementation of each MT5 lifecycle callback is present in the compiled program: `OnInit`, `OnDeinit`, `OnTick`, `OnTimer`, `OnChartEvent`, `OnTradeTransaction`.
- No duplicate input/enum/function definitions created by macro/include ordering.
- No implicit-conversion warning that can change price, ticket, identifier, timestamp, retcode, volume or monetary-risk semantics.
- No array-bound, uninitialized-variable, unreachable-code or type-truncation warning affecting execution/risk/recovery logic.
- The compiler creates/updates the intended `GPT_EA.ex5` successfully.
- The `.ex5` timestamp corresponds to the compile run being certified.

## 3. Build identity that must be recorded

Archive with the compile result:

- Git commit SHA;
- repository/branch;
- MetaTrader terminal build;
- MetaEditor build;
- Windows architecture/version used for compilation;
- compile timestamp;
- complete compile log;
- source entry file path;
- generated `.ex5` path;
- SHA-256 hash of the generated `.ex5`;
- SHA-256 hash of the release `.set` preset, if one is used;
- release validation ID;
- compiler error count;
- compiler warning count.

The source commit, `.ex5` hash and `.set` hash together form the release artifact identity.

## 4. Explicit release blockers

Release fails immediately if any of the following occurs:

- any compile error;
- missing include;
- duplicate callback/function definition;
- incompatible function signature;
- undeclared identifier;
- invalid enum/property constant for the installed MT5 build;
- unsafe numeric conversion involving ticket, `POSITION_IDENTIFIER`, volume, price, money or time;
- invalid array access warning;
- compiler cannot create the `.ex5`;
- `.ex5` hash is not archived;
- source is modified after the certified compile without recompiling and generating a new hash;
- compile was performed from a working tree that cannot be tied to the recorded Git commit.

## 5. Post-compile load smoke test

Immediately after a clean compile, attach the new `.ex5` to a **demo** chart with real-account arming disabled and verify:

- EA loads without `INIT_FAILED` or `INIT_PARAMETERS_INCORRECT` for the intended preset;
- all configured symbols resolve or fail with an explicit safe message;
- no missing indicator/library/resource error appears;
- timer starts;
- chart buttons/dashboard render where enabled;
- release certification remains BLOCKED until its evidence inputs are deliberately completed;
- no order is sent merely because the EA was attached;
- Experts/Journal contain no repeated initialization exception/error loop.

This smoke test does not replace Strategy Tester or demo soak.

## 6. Recompile triggers

The compile gate must be repeated after any executable change, including changes to:

- `.mq5` or `.mqh` logic;
- input definitions/defaults;
- strategy or news logic;
- order placement/margin/filling code;
- SL/BE/trailing/partial-exit logic;
- recovery/checkpoint logic;
- observability code that participates in release gates;
- release-certification code;
- include order or macro aliases.

Documentation-only changes may reuse the previous compile only when the release owner explicitly records that no executable source changed.

## 7. Compile evidence record

Minimum record:

| Field | Required value |
|---|---|
| Git SHA | exact candidate commit |
| MetaEditor build | recorded |
| MT5 build | recorded |
| Errors | `0` |
| Warnings | `0` preferred/required for production certification |
| EX5 SHA-256 | non-empty |
| SET SHA-256 | non-empty when preset used |
| Compile log | archived |
| Load smoke test | PASS |
| Release owner | identified in local release evidence |

`InpReleaseMetaEditorCompilePassed=true` may be set only after this contract has actually passed and its evidence is archived.

## 8. Binding into MT5 validation evidence

The compile gate is now one component of `mt5_validation_evidence_v1`. After compilation and the load smoke test:

1. archive the compile log used by this gate;
2. record its SHA-256 in `compile.compile_log_sha256`;
3. ensure the MT5 evidence candidate Git/EX5/SET identity exactly matches the release build;
4. record the same MetaEditor and MT5 builds;
5. complete the remaining Strategy Tester, broker-runtime, recovery, protection and live-demo API/news evidence under `MT5_VALIDATION_EVIDENCE.md`.

A compile PASS alone does not set `InpReleaseMT5ValidationPassed=true`. That input is eligible only after the full MT5 evidence validator returns PASS.
