# Local MetaEditor Compile Workflow

This repository keeps **GPT_EA.mq5** as the only project-local MetaTrader source file that must be compiled. The remaining executable include is MetaTrader 5's built-in `<Trade/Trade.mqh>`.

## Local compile

From Windows PowerShell at the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\compile_metaeditor.ps1
```

The script:

- locates `metaeditor64.exe` automatically when possible;
- locates an MQL5 root containing `Include\Trade\Trade.mqh`;
- compiles `GPT_EA.mq5` with MetaEditor's real compiler;
- writes `GPT_EA.log`;
- writes the first actionable diagnostics to `metaeditor-first-errors.txt`;
- exits non-zero when MetaEditor reports compile errors.

If auto-detection does not find your installation:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\compile_metaeditor.ps1 `
  -MetaEditorPath "C:\Program Files\Your Broker MT5\metaeditor64.exe" `
  -Mql5Root "$env:APPDATA\MetaQuotes\Terminal\YOUR_TERMINAL_ID\MQL5"
```

For a syntax-only pass:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\compile_metaeditor.ps1 -SyntaxOnly
```

## First-error interpretation

Always fix the earliest compiler errors first because one syntax/type error can cascade into many later diagnostics.

Common patterns:

| MetaEditor diagnostic | Meaning / first action |
| --- | --- |
| `undeclared identifier` | A symbol is used before a valid declaration, was renamed by a macro, or is missing entirely. Inspect the named line and nearby forward declarations. |
| `function already defined` / `variable already defined` | A true name collision remains. Keep one implementation or rename the helper while preserving the single MT5 event hook. |
| `wrong parameters count` | The function call does not match an MQL5 overload. Check argument count/types against the declared signature. |
| `cannot convert enum` / type conversion error | Use the correct enum/type or an explicit safe cast where MQL5 requires it. |
| `cannot open include file` | The MQL5 include root is wrong. Confirm `MQL5\Include\Trade\Trade.mqh` exists and pass `-Mql5Root`. |
| syntax error around `{`, `}`, `(`, `)` | Inspect the first reported line and the function immediately before it; later errors are often cascading. |

## Optional self-hosted GitHub workflow

`.github/workflows/metaeditor-local-compile.yml` runs only when manually dispatched and requires a **Windows X64 self-hosted GitHub Actions runner** on a machine where MetaTrader 5 / MetaEditor is installed.

Optional repository variables:

- `METAEDITOR_PATH` — full path to `metaeditor64.exe`
- `MQL5_ROOT` — path to the terminal's `MQL5` directory

The workflow uploads `GPT_EA.log` and `metaeditor-first-errors.txt` as diagnostics.
