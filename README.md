# GPT_EA-

MetaTrader 5 GPT-assisted Expert Advisor with multi-timeframe market analysis, OpenAI secondary validation, risk-based lot sizing, timed APPROVE/DENY trade authorization, and execution-time revalidation.

## Trade approval flow

Signal card → OpenAI review → timed APPROVE / DENY prompt → fresh market revalidation → execution only when approved and still valid.

- **APPROVE:** re-checks entry zone, M5 trigger, spread, economic-event block, Treasury-yield shock, position limit, and lot size before sending the order.
- **DENY:** deletes the pending setup.
- **No response before timeout:** automatically deletes the pending setup.
- OpenAI API keys are entered locally in MT5 inputs and must never be committed to this repository.
