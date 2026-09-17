# GPT_EA

Standalone MetaTrader 5 GPT-assisted Expert Advisor with multi-timeframe market analysis, OpenAI secondary validation, risk-based lot sizing, timed APPROVE/DENY trade authorization, and execution-time revalidation.

Repository: https://github.com/bonaventuresimeon/GPT_EA.git

## Clone

```bash
git clone https://github.com/bonaventuresimeon/GPT_EA.git
cd GPT_EA
```

## Main EA

Compile `GPT_EA.mq5` in MetaEditor. It includes the local `GPT_EA_Part01.mqh` through `GPT_EA_Part07.mqh` source files contained in this repository.

## Trade approval flow

Signal card → OpenAI review → timed APPROVE / DENY prompt → fresh market revalidation → execution only when approved and still valid.

- **APPROVE:** re-checks the entry zone, M5 trigger, spread, economic-event block, Treasury-yield shock, position limit, and risk-based lot size before sending the order.
- **DENY:** deletes the pending trade setup immediately.
- **No response before timeout:** automatically deletes the pending trade setup.
- **Expired/stale setup:** approval cannot force execution after the setup becomes invalid.

## OpenAI configuration

The OpenAI API key is entered locally in the MT5 EA inputs and must never be committed to GitHub.

In MetaTrader 5, allow WebRequest access to:

```text
https://api.openai.com
```

Then configure the OpenAI inputs inside the EA settings.

## Project separation

`GPT_EA` is an independent project. It has no runtime dependency on CelestialNexus or any other repository.
