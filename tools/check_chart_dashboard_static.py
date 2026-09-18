#!/usr/bin/env python3
from __future__ import annotations
import re
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
SRC=(ROOT/"GPT_EA.mq5").read_text(encoding="utf-8-sig")
errors=[]

def fn(name:str)->str:
    m=re.search(rf"\b(?:void|bool|double|string|int|ulong|color)\s+{re.escape(name)}\s*\([^)]*\)\s*\{{",SRC)
    if not m:
        return ""
    i=m.end()-1; depth=0; state="code"
    while i<len(SRC):
        c=SRC[i]; n=SRC[i+1] if i+1<len(SRC) else ""
        if state=="code":
            if c=="/" and n=="/": state="line"; i+=2; continue
            if c=="/" and n=="*": state="block"; i+=2; continue
            if c=='"': state="str"; i+=1; continue
            if c=="'": state="char"; i+=1; continue
            if c=="{": depth+=1
            elif c=="}":
                depth-=1
                if depth==0: return SRC[m.start():i+1]
            i+=1
        elif state=="line":
            if c=="\n": state="code"
            i+=1
        elif state=="block":
            if c=="*" and n=="/": state="code"; i+=2
            else: i+=1
        else:
            q='"' if state=="str" else "'"
            if c=="\\": i+=2; continue
            if c==q: state="code"
            i+=1
    return ""

required=[
 '#property version   "1.24"',"R12-FLOATING-HUD-20260918","FLOAT124","RenderFloatingMarketHUD","RenderFloatingLiveHUD",
 "FloatingHUDLayout","HUD_DRAG_HANDLE","CHARTEVENT_OBJECT_DRAG","LoadFloatingHUDPosition",
 "SaveFloatingHUDPosition","HUDPositionKey","GPT EA — MARKET INTELLIGENCE","MARKET STATE",
 "MULTI-TIMEFRAME","GPT TRADE INTELLIGENCE","CONFIRMATIONS","INVALIDATION",
 "AWAITING APPROVAL","APPROVED • WAITING FOR ENTRY","DENIED • CONTINUING SCAN",
 "POSITION OPEN","TP1 HIT","BREAK-EVEN ACTIVE","TRAILING PROFIT","TRADE CLOSED",
 "SETUP INVALIDATED","NEWS PAUSE","RISK BLOCKED","BTN_APPROVE","BTN_DENY",
 "g_displayPending","D1","H4","H1","M30","M15","M5",
]
for token in required:
    if token not in SRC: errors.append("missing floating-HUD token: "+token)

layout=fn("FloatingHUDLayout")
for token in ("ChartGetInteger(0,CHART_WIDTH_IN_PIXELS","MathRound((double)cw*0.90)","w=(int)MathMin","g_fhudX","g_fhudY"):
    if token not in layout: errors.append("responsive floating layout missing: "+token)

frame=fn("HUDRenderFrame")
for token in ("HUD_SHADOW","DASH_PANEL","DASH_HEADER_BG","DASH_TOP_RAIL","DASH_FOOTER_BG","HUDSetDragHandle","HUDRenderControls"):
    if token not in frame: errors.append("HUD frame missing: "+token)

market=fn("RenderFloatingMarketHUD")
for token in ("DASH_MARKET_CARD","HUDSetMTFColumn","DASH_TRADE_CARD","DASH_RULES_CARD",
              "HUD_INVALIDATION_CARD","HUDConfidenceBars","HUDTradeField",
              "ActivePendingForSymbol(_Symbol)","DrawTradeMap(s)"):
    if token not in market: errors.append("market HUD contract missing: "+token)

live=fn("RenderFloatingLiveHUD")
for token in ("UI_STATE_TRADE_ACTIVE","UI_STATE_BREAK_EVEN","UI_STATE_TRAILING","DrawLiveManagementMap","HUD_INVALIDATION_CARD"):
    if token not in live: errors.append("live HUD contract missing: "+token)

controls=fn("HUDRenderControls")
for token in ("HUDSetButton(BTN_APPROVE","HUDSetButton(BTN_DENY","g_displayPending=enabled?pendingIndex:-1"):
    if token not in controls: errors.append("approval control contract missing: "+token)

events=fn("OnChartEvent")
for token in ("CHARTEVENT_OBJECT_DRAG","sparam==HUD_DRAG_HANDLE","HandleFloatingHUDDrag()",
              "RefreshFloatingHUDHover","ApprovePending(idx)",'DeletePending(idx,"user denied trade")'):
    if token not in events: errors.append("chart-event contract missing: "+token)
if "sparam==HUD_DRAG_HANDLE || sparam==HUD_DRAG_TEXT || sparam==DASH_PANEL" not in events:
    errors.append("HUD shell/drag clicks are not explicitly excluded from approval")

persist=fn("SaveFloatingHUDPosition")+fn("LoadFloatingHUDPosition")+fn("HUDPositionKey")
for token in ("GlobalVariableSet","GlobalVariableGet","ChartID()"):
    if token not in persist: errors.append("HUD persistence missing: "+token)

router=fn("RefreshElegantChartDashboard")
for token in ("FindChartManagedPosition(ticket)","RenderFloatingLiveHUD(ticket)","RenderFloatingMarketHUD()"):
    if token not in router: errors.append("dashboard router missing: "+token)
for old in ("RenderLiveManagementDashboard(ticket)","RenderCandidateOperationalDashboard()","RenderScanningDashboard()"):
    if old in router: errors.append("legacy full-chart renderer remains active: "+old)
if "ApplyDashboardChartReserve" in router:
    errors.append("floating HUD router must not reserve chart space")

for name in ("RenderFloatingMarketHUD","RenderFloatingLiveHUD","HUDRenderFrame","HUDRenderControls","HandleFloatingHUDDrag"):
    body=fn(name)
    if not body:
        errors.append("missing function: "+name); continue
    for forbidden in ("OrderSend(","ApprovedPlaceTrade(","trade.Buy(","trade.Sell(","PositionClose(","PositionModify("):
        if forbidden in body: errors.append(f"{name} is not read-only: {forbidden}")

if "InpDashboardReserveChartSpace    = false;" not in SRC:
    errors.append("floating overlay must default to no chart-space reservation")

if errors:
    print("FLOATING HUD STATIC CHECK: FAILED")
    for e in errors: print("ERROR:",e)
    raise SystemExit(1)

print("FLOATING HUD STATIC CHECK: PASS")
print("R12: wide floating overlay, five intelligence cards, persistent drag position, chart-local fail-closed approval controls")
