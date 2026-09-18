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
    "InpShowStopMovementRules","InpShowCompactTradeTimeline",
    "InpTrailMovementSegments","InpDashboardRefreshMs","InpDashboardTitleFont","Segoe Script",
    "InpDashboardTransparent","InpDashboardReserveChartSpace","InpDashboardMinWidth","InpDashboardMaxWidth",
    "InpDashboardChartGap","InpDashboardClosedHoldSeconds","VisualDashboardState",
    "UI_STATE_SCANNING","UI_STATE_SETUP_FOUND","UI_STATE_WAITING_CONFIRMATION","UI_STATE_ENTRY_ARMED",
    "UI_STATE_TRADE_ACTIVE","UI_STATE_TP1","UI_STATE_BREAK_EVEN","UI_STATE_TRAILING","UI_STATE_CLOSED",
    "ApplyDashboardChartReserve","DashboardLayout","VisualMTFMatrix","VisualConfidenceBar",
    "RenderPremiumHUDFrame","DASH_HEADER_BG","DASH_FOOTER_BG","DASH_TOP_RAIL","DASH_INNER_FRAME",
    "R10-AUTO-MODEL-HUD-20260918","HUD123",
    "PurgeLegacyVisualObjects","g_visualDataState","DATA LOADING / INSUFFICIENT HISTORY",
    "RenderScanningDashboard","RenderClosedDashboard","RenderDashboardControls",
    "DASH_SUBTITLE","DASH_STATUS","DASH_RULES_CARD","DASH_TIMELINE_CARD",
    "LEVEL_BE","LEVEL_LIVE_SL","TAG_ENTRY","TAG_BE","TAG_TRAIL",
    "RenderCandidateOperationalDashboard","RenderLiveManagementDashboard","DrawLiveManagementMap",
    "RecordTrailingMovement","RefreshElegantChartDashboard","VisualBreakEvenLevel",
    "VisualStopRulesText","VisualTradeTimeline","VisualTimelineNode",
    "EXACT STOP-MOVEMENT RULES","COMPACT TRADE TIMELINE","SL never regresses","last ratchet",
    "BE_TIME","PROFIT_LOCK_TIME","STRONG_LOCK_TIME","TRAIL_TIME","TRAIL_LAST_TIME",
    "InpBECostATRFrac","InpProfitLockTriggerR","InpStrongLockTriggerR","InpTrailStructureBarsM5","InpTrailMinStepR",
    "StopStageName(stage)","CurrentPortfolioRiskPercent()","CurrentModelTrustMode",
    "BrokerHealthScore","LifecycleStateName","CHART_SHIFT_SIZE","CHART_SHOW_OBJECT_DESCR",
    'RefreshElegantChartDashboard(true);','RefreshElegantChartDashboard(false);',
]
for token in required:
    if token not in text:
        errors.append(f"GPT_EA.mq5 missing dashboard token: {token}")

if 'if(!InpDrawDashboard || s.symbol!=_Symbol) return;' not in text:
    errors.append("scan dashboard must be restricted to the attached chart symbol")


for token in (
    'GVWrite(PosKey(pid,"BE_TIME")',
    'GVWrite(PosKey(pid,"PROFIT_LOCK_TIME")',
    'GVWrite(PosKey(pid,"STRONG_LOCK_TIME")',
    'GVWrite(PosKey(pid,"TRAIL_TIME")',
    'GVWrite(PosKey(pid,"TRAIL_LAST_TIME")',
    'GVWrite(PosKey(pid,"EXEC_ANALYSIS_TIME")',
    'GVWrite(PosKey(pid,"EXEC_APPROVAL_TIME")',
    'GVWrite(PosKey(pid,"EXEC_SENT_TIME")',
    'GVWrite(PosKey(pid,"EXEC_FILL_TIME")',
):
    if token not in text:
        errors.append(f"dashboard timeline/stage persistence missing: {token}")

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
    "SetVisualPriceTag","SetVisualBand","RecordTrailingMovement","DrawLiveManagementMap","SetPlanPriceTag",
    "VisualStopRulesText","VisualTradeTimeline",
    "RenderPremiumHUDFrame","RenderLiveManagementDashboard","RenderCandidateOperationalDashboard",
    "RenderScanningDashboard","RenderClosedDashboard","RefreshElegantChartDashboard",
]
for name in visual_functions:
    body=function_body(name)
    if not body:
        errors.append(f"visual function missing: {name}")
        continue
    for forbidden in ("trade.","OrderSend(","PositionModify(","PositionClose(","PositionClosePartial("):
        if forbidden in body:
            errors.append(f"{name} must remain read-only; found {forbidden}")

# Premium rendering contract: boxed chart-matched HUD, optional glass inner cards, reserved chart gutter, no legacy debug layers.
risk_panel=function_body("UpdateRiskAnalyticsPanel")
if "InpElegantChartDashboard && InpPremiumDashboard" not in risk_panel or "ObjectDelete(0,RISK_PANEL)" not in risk_panel:
    errors.append("premium dashboard must suppress the legacy risk/performance overlay")

health_panel=function_body("RenderStrategyHealthDashboard")
if "InpElegantChartDashboard && InpPremiumDashboard" not in health_panel:
    errors.append("premium dashboard must suppress the strategy-health text overlay")

notify=function_body("NotifyCard")
if 'Comment("")' not in notify or "else Comment(card);" not in notify:
    errors.append("premium dashboard must suppress raw signal-card Comment() text while retaining legacy fallback")

rect=function_body("SetPremiumRect")
if "InpDashboardTransparent" not in rect or "clrNONE" not in rect:
    errors.append("premium dashboard must support optional glass inner-card fill")
if "bool glassCard=" not in rect or "name==DASH_PANEL" in rect:
    errors.append("dashboard transparency must be limited to inner information cards; the outer HUD shell must stay opaque")
hud=function_body("RenderPremiumHUDFrame")
for token in ("DASH_PANEL","DASH_INNER_FRAME","DASH_HEADER_BG","DASH_TOP_RAIL","DASH_FOOTER_BG","C'11,15,22'"):
    if token not in hud:
        errors.append("boxed HUD frame missing token: "+token)
if "InpDashboardHeight" not in function_body("DashboardLayout"):
    errors.append("responsive dashboard layout must honor InpDashboardHeight")
for state_renderer in (
    "RenderLiveManagementDashboard",
    "RenderCandidateOperationalDashboard",
    "RenderScanningDashboard",
    "RenderClosedDashboard",
):
    body=function_body(state_renderer)
    if "RenderPremiumHUDFrame(" not in body:
        errors.append(f"{state_renderer} must render inside the boxed premium HUD frame")
    if "SetPremiumRect(DASH_PANEL" in body:
        errors.append(f"{state_renderer} must not bypass the shared boxed HUD renderer")
if 'v1.23 • R10 HUD' not in text or 'EX5 marker HUD123' not in text:
    errors.append("v1.23 R10 HUD / HUD123 runtime identity is missing")
if 'RenderAdvancedDashboard(primary,primaryReport,filterState,approvalReady);' not in text:
    errors.append("ENTRY ARMED dashboard state must be driven by final approvalReady, not the pre-gate trigger")
for premature in (
    '?"HIGH-CONFIDENCE TRADE SETUP":d.action==STRATEGY_ACTION_WAIT',
    'tradable?"✅ HIGH-CONFIDENCE SETUP VALID"',
    'strategyActionOK?"HIGH-CONFIDENCE":"WAIT/NO TRADE"',
):
    if premature in text:
        errors.append("premature HIGH-CONFIDENCE wording remains before all authorization gates: "+premature)

trade_map=function_body("DrawTradeMap")
live_band=function_body("SetVisualBand")
if "OBJPROP_FILL,false" not in trade_map or "OBJPROP_FILL,false" not in live_band:
    errors.append("premium trade/risk/reward regions must be outline-only")

chart_event=function_body("OnChartEvent")
if "CHARTEVENT_CHART_CHANGE" not in chart_event or "RefreshElegantChartDashboard(true);" not in chart_event:
    errors.append("dashboard must rerender after chart geometry changes")

approval=function_body("RenderApprovalPrompt")
if "InpElegantChartDashboard && InpPremiumDashboard" not in approval:
    errors.append("premium dashboard must integrate approval controls instead of drawing an overlapping hero")

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
