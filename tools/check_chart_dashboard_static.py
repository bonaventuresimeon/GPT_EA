#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
MAIN=ROOT/"GPT_EA.mq5"
DOC=ROOT/"docs"/"CHART_DASHBOARD_OBSERVABILITY.md"
errors:list[str]=[]

if not MAIN.exists():
    print("CHART DASHBOARD STATIC CHECK: FAILED\nERROR: GPT_EA.mq5 missing")
    raise SystemExit(1)

text=MAIN.read_text(encoding="utf-8")

required=[
    "InpElegantChartDashboard","InpDrawLiveManagementLevels","InpDrawTrailingMovement",
    "InpTrailMovementSegments","InpDashboardRefreshMs","InpDashboardTitleFont","Segoe Script",
    "DASH_SUBTITLE","DASH_STATUS","LEVEL_BE","LEVEL_LIVE_SL","TAG_ENTRY","TAG_BE","TAG_TRAIL",
    "RenderCandidateOperationalDashboard","RenderLiveManagementDashboard","DrawLiveManagementMap",
    "RecordTrailingMovement","RefreshElegantChartDashboard","VisualBreakEvenLevel",
    "StopStageName(stage)","CurrentPortfolioRiskPercent()","CurrentModelTrustMode",
    "BrokerHealthScore","LifecycleStateName","CHART_SHIFT_SIZE","CHART_SHOW_OBJECT_DESCR",
    'RefreshElegantChartDashboard(true);','RefreshElegantChartDashboard(false);',
]
for token in required:
    if token not in text:
        errors.append(f"GPT_EA.mq5 missing dashboard token: {token}")

if 'if(!InpDrawDashboard || s.symbol!=_Symbol) return;' not in text:
    errors.append("scan dashboard must be restricted to the attached chart symbol")

# Extract balanced function bodies and ensure visual functions cannot trade.
def function_body(name:str)->str:
    m=re.search(rf"\b(?:void|bool|double|string|int|ulong)\s+{re.escape(name)}\s*\([^)]*\)\s*\{{",text)
    if not m: return ""
    start=m.end()-1
    depth=0
    state="code"
    i=start
    while i<len(text):
        ch=text[i]
        nx=text[i+1] if i+1<len(text) else ""
        if state=="code":
            if ch=="/" and nx=="/": state="line"; i+=2; continue
            if ch=="/" and nx=="*": state="block"; i+=2; continue
            if ch=='"': state="string"; i+=1; continue
            if ch=="'": state="char"; i+=1; continue
            if ch=="{": depth+=1
            elif ch=="}":
                depth-=1
                if depth==0: return text[start:i+1]
            i+=1; continue
        if state=="line":
            if ch=="\n": state="code"
            i+=1; continue
        if state=="block":
            if ch=="*" and nx=="/": state="code"; i+=2
            else: i+=1
            continue
        if state in {"string","char"}:
            quote='"' if state=="string" else "'"
            if ch=="\\" and i+1<len(text): i+=2; continue
            if ch==quote: state="code"
            i+=1
    return ""

visual_functions=[
    "SetVisualPriceTag","SetVisualBand","RecordTrailingMovement","DrawLiveManagementMap",
    "RenderLiveManagementDashboard","RenderCandidateOperationalDashboard","RefreshElegantChartDashboard",
]
for name in visual_functions:
    body=function_body(name)
    if not body:
        errors.append(f"visual function missing: {name}")
        continue
    for forbidden in ("trade.","OrderSend(","PositionModify(","PositionClose(","PositionClosePartial("):
        if forbidden in body:
            errors.append(f"{name} must remain read-only; found {forbidden}")

on_tick=function_body("OnTick")
if "RefreshElegantChartDashboard(false);" not in on_tick:
    errors.append("OnTick must refresh chart observability")
for forbidden in ("ManagePositionsAdvanced(","ApprovedPlaceTrade(","OrderSend("):
    if forbidden in on_tick:
        errors.append(f"OnTick visual path must not execute trading logic: {forbidden}")

if not DOC.exists() or len(DOC.read_text(encoding="utf-8").strip())<500:
    errors.append("dashboard observability documentation missing/too small")

if errors:
    print("CHART DASHBOARD STATIC CHECK: FAILED")
    for e in errors: print("ERROR:",e)
    sys.exit(1)

print("CHART DASHBOARD STATIC CHECK: PASS")
