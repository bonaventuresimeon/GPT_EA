#!/usr/bin/env python3
from pathlib import Path
import re

ROOT=Path(__file__).resolve().parents[1]
SRC=(ROOT/"GPT_EA.mq5").read_text(encoding="utf-8-sig")
errors=[]

def fn(name):
    m=re.search(rf"\b(?:void|bool|double|string|int|ulong|color)\s+{re.escape(name)}\s*\([^)]*\)\s*\{{",SRC)
    if not m: return ""
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

market=fn("RenderFloatingMarketHUD")
live=fn("RenderFloatingLiveHUD")
router=fn("RefreshElegantChartDashboard")
status=fn("HUDStatusText")

for token in (
 'VisualDashboardState uiState=UI_STATE_SCANNING;',
 'if(g_dashboardClosedUntil>TimeTradeServer())',
 'uiState=UI_STATE_CLOSED;',
 'if(pending>=0){ uiState=UI_STATE_ENTRY_ARMED;',
 'else if(inZone && !g_visualLastReady){ uiState=UI_STATE_WAITING_CONFIRMATION;',
 'else { uiState=UI_STATE_SETUP_FOUND;',
 'SetVisualDashboardState(uiState,reason);'
):
    if token not in market: errors.append("market state mapping missing: "+token)

for token in (
 'VisualDashboardState st=UI_STATE_TRADE_ACTIVE;',
 'if(stage>=4) st=UI_STATE_TRAILING;',
 'else if(stage>=1 && tp1done) st=UI_STATE_BREAK_EVEN;',
 'else if(tp1done) st=UI_STATE_TP1;',
 'SetVisualDashboardState(st,"live position management");'
):
    if token not in live: errors.append("live state mapping missing: "+token)

for token in ("TRADE CLOSED","NEWS PAUSE","RISK BLOCKED","SETUP INVALIDATED","AWAITING APPROVAL"):
    if token not in status: errors.append("status text missing: "+token)

pos_live=router.find("FindChartManagedPosition(ticket)")
pos_live_render=router.find("RenderFloatingLiveHUD(ticket)")
pos_market=router.find("RenderFloatingMarketHUD()")
if min(pos_live,pos_live_render,pos_market)<0:
    errors.append("router missing live/market render path")
elif not (pos_live < pos_live_render < pos_market):
    errors.append("router priority must be LIVE > MARKET")

def market_state(closed,has,pending,in_zone,last_ready):
    if closed: return "CLOSED"
    if not has: return "SCANNING"
    if pending: return "ENTRY_ARMED"
    if in_zone and not last_ready: return "WAITING_CONFIRMATION"
    return "SETUP_FOUND"

cases=[
 ((True,False,False,False,False),"CLOSED"),
 ((False,False,False,False,False),"SCANNING"),
 ((False,True,False,False,False),"SETUP_FOUND"),
 ((False,True,False,True,False),"WAITING_CONFIRMATION"),
 ((False,True,True,False,False),"ENTRY_ARMED"),
 ((False,True,True,True,True),"ENTRY_ARMED"),
]
for args,expected in cases:
    got=market_state(*args)
    if got!=expected: errors.append(f"market truth-table {args}: {got} != {expected}")

def live_state(stage,tp1done):
    if stage>=4: return "TRAILING"
    if stage>=1 and tp1done: return "BREAK_EVEN"
    if tp1done: return "TP1"
    return "TRADE_ACTIVE"

for args,expected in [
 ((0,False),"TRADE_ACTIVE"),
 ((0,True),"TP1"),
 ((1,True),"BREAK_EVEN"),
 ((4,True),"TRAILING"),
]:
    got=live_state(*args)
    if got!=expected: errors.append(f"live truth-table {args}: {got} != {expected}")

if errors:
    print("DASHBOARD STATE MACHINE CHECK: FAILED")
    for e in errors: print("ERROR:",e)
    raise SystemExit(1)

print("DASHBOARD STATE MACHINE CHECK: PASS")
print("MARKET: SCANNING > SETUP FOUND > WAITING CONFIRMATION > ENTRY ARMED")
print("LIVE: TRADE ACTIVE > TP1 > BREAK EVEN > TRAILING")
print("ROUTER: LIVE POSITION TAKES PRIORITY; OTHERWISE FLOATING MARKET HUD")
