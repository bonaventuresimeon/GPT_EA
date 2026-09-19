#!/usr/bin/env python3
from __future__ import annotations
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = (ROOT / "GPT_EA.mq5").read_text(encoding="utf-8-sig")
errors: list[str] = []

def fn(name: str) -> str:
    m = re.search(rf"\b(?:void|bool|double|string|int|ulong|color|uint)\s+{re.escape(name)}\s*\([^)]*\)\s*\{{", SRC)
    if not m:
        return ""
    i = m.end() - 1
    depth = 0
    state = "code"
    while i < len(SRC):
        c = SRC[i]
        n = SRC[i + 1] if i + 1 < len(SRC) else ""
        if state == "code":
            if c == "/" and n == "/":
                state = "line"; i += 2; continue
            if c == "/" and n == "*":
                state = "block"; i += 2; continue
            if c == '"':
                state = "str"; i += 1; continue
            if c == "'":
                state = "char"; i += 1; continue
            if c == "{":
                depth += 1
            elif c == "}":
                depth -= 1
                if depth == 0:
                    return SRC[m.start():i + 1]
            i += 1
        elif state == "line":
            if c == "\n":
                state = "code"
            i += 1
        elif state == "block":
            if c == "*" and n == "/":
                state = "code"; i += 2
            else:
                i += 1
        else:
            q = '"' if state == "str" else "'"
            if c == "\\":
                i += 2; continue
            if c == q:
                state = "code"
            i += 1
    return ""

required = [
    '#property version   "1.24"',
    '#include <Canvas/Canvas.mqh>',
    "CCanvas g_hudCanvas",
    "R32-REFERENCE-HUD-20260919",
    "PIXEL124",
    "RenderFloatingMarketHUD",
    "RenderFloatingLiveHUD",
    "FloatingHUDLayout",
    "HUD_CANVAS_NAME",
    'HUD_CANVAS_NAME="GPT_HUD_CANVAS"',
    'HUD_DRAG_HANDLE="GPT_HUD_DRAG_HANDLE"',
    'HUD_SETTINGS_HIT="GPT_HUD_SETTINGS"',
    'HUD_CLOSE_HIT="GPT_HUD_CLOSE"',
    'HUD_APPROVE_HIT="GPT_HUD_APPROVE"',
    'HUD_DENY_HIT="GPT_HUD_DENY"',
    "CHARTEVENT_OBJECT_DRAG",
    "LoadFloatingHUDPosition",
    "SaveFloatingHUDPosition",
    "HUDPositionKey",
    "MARKET INTELLIGENCE",
    "MARKET STATE",
    "MULTI-TIMEFRAME",
    "GPT TRADE INTELLIGENCE",
    "CONFIRMATIONS",
    "INVALIDATION",
    "AWAITING APPROVAL",
    "POSITION OPEN",
    "TP1 HIT",
    "BREAK-EVEN ACTIVE",
    "TRAILING PROFIT",
    "TRADE CLOSED",
    "SETUP INVALIDATED",
    "NEWS PAUSE",
    "RISK BLOCKED",
    "D1", "H4", "H1", "M30", "M15", "M5",
]
for token in required:
    if token not in SRC:
        errors.append("missing R32 HUD token: " + token)

# Pixel-derived design geometry from reference image 1.
for token in (
    "#define HUD_DESIGN_W 1138",
    "#define HUD_DESIGN_H 277",
    "#define HUD_DEFAULT_X 18",
    "#define HUD_DEFAULT_Y 36",
    "#define HUD_REFERENCE_RASTER_SCALE 1.00",
    "#define HUD_CHART_GUTTER_ALLOWANCE 0",
    "#define HUD_HEADER_H 44",
    "#define HUD_PANEL_Y 46",
    "#define HUD_PANEL_H 186",
    "#define HUD_FOOTER_Y 235",
    "#define HUD_MARKET_X 9",
    "#define HUD_MARKET_W 232",
    "#define HUD_MTF_X 247",
    "#define HUD_MTF_W 172",
    "#define HUD_TRADE_X 425",
    "#define HUD_TRADE_W 318",
    "#define HUD_CONFIRM_X 749",
    "#define HUD_CONFIRM_W 205",
    "#define HUD_INVALID_X 960",
    "#define HUD_APPROVE_X 835",
    "#define HUD_APPROVE_W 147",
    "#define HUD_DENY_X 988",
    "#define HUD_DENY_W 138",
):
    if token not in SRC:
        errors.append("reference geometry missing/mismatched: " + token)

layout = fn("FloatingHUDLayout")
for token in (
    "ChartGetInteger(0,CHART_WIDTH_IN_PIXELS",
    "ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS",
    "HUD_DESIGN_W",
    "HUD_DESIGN_H",
    "availableW",
    "MathMax(180",
    "g_fhudX",
    "g_fhudY",
):
    if token not in layout:
        errors.append("responsive layout missing: " + token)

canvas = fn("HUDCanvasEnsure")
for token in (
    "CreateBitmapLabel",
    "COLOR_FORMAT_ARGB_NORMALIZE",
    "g_fhudCanvasReady",
    "Resize",
    "OBJPROP_XDISTANCE",
    "OBJPROP_YDISTANCE",
    "OBJPROP_SELECTABLE,false",
):
    if token not in canvas:
        errors.append("canvas lifecycle missing: " + token)

shell = fn("HUDPaintShell") + fn("HUDOutlineShell")
for token in (
    "HUDFillRoundRect",
    "HUDGradientRoundRect",
    "HUDStrokeRoundRect",
    "HUDDrawHeader",
    "C'189,145,40'",
):
    if token not in shell:
        errors.append("premium shell missing: " + token)

header = fn("HUDDrawHeader")
for token in (
    "HUDDrawBrain",
    "MARKET INTELLIGENCE",
    "TERMINAL_CONNECTED",
    "HUDPeriodText",
    "HUDSpreadText",
    "HUDDrawGrip",
    "HUDDrawGear",
    "HUDDrawClose",
    "HUD_DRAG_HANDLE",
    "HUD_SETTINGS_HIT",
    "HUD_CLOSE_HIT",
    "HUDS(391,sc)",
    "HUDS(511,sc)",
):
    if token not in header:
        errors.append("header contract missing: " + token)

market_body = fn("HUDRenderMarketBody")
for token in (
    "HUDDrawMarketPanel",
    "HUDDrawMTFPanel",
    "HUDDrawTradePanel",
    "HUDDrawConfirmationsPanel",
    "HUDDrawInvalidationPanel",
    "HUDDrawFooter",
):
    if token not in market_body:
        errors.append("five-panel/footer contract missing: " + token)

trade = fn("HUDDrawTradePanel")
for token in (
    "Setup:",
    "Confidence:",
    "HUDDrawConfidence",
    "Status:",
    "Entry:",
    "SL:",
    "BE Trigger:",
    "TP1:",
    "TP2:",
    "TP3:",
    "R:R:",
):
    if token not in trade:
        errors.append("trade-intelligence contract missing: " + token)

confirm = fn("HUDDrawConfirmationsPanel")
for token in (
    "H4/H1 structure",
    "M15 momentum",
    "Waiting M5 rejection",
    "Breakout volume",
    "HUDDrawConfirmRow",
):
    if token not in confirm:
        errors.append("confirmation contract missing: " + token)

footer = fn("HUDDrawFooter")
for token in (
    "EA STATUS",
    "APPROVE",
    "DENY",
    "HUD_APPROVE_HIT",
    "HUD_DENY_HIT",
    "g_displayPending=enabled?pendingIndex:-1",
):
    if token not in footer:
        errors.append("footer/control contract missing: " + token)

market = fn("RenderFloatingMarketHUD")
for token in (
    "ActivePendingForSymbol(_Symbol)",
    "SetVisualDashboardState",
    "HUDPrepare",
    "HUDPaintShell",
    "HUDRenderMarketBody",
    "HUDOutlineShell",
    "g_hudCanvas.Update(false)",
    "DrawTradeMap(s)",
):
    if token not in market:
        errors.append("market HUD render contract missing: " + token)

live = fn("RenderFloatingLiveHUD")
for token in (
    "UI_STATE_TRADE_ACTIVE",
    "UI_STATE_BREAK_EVEN",
    "UI_STATE_TRAILING",
    "HUDDrawMarketPanel",
    "HUDDrawTradePanel",
    "HUDDrawConfirmationsPanel",
    "DrawLiveManagementMap",
    "g_hudCanvas.Update(false)",
):
    if token not in live:
        errors.append("live HUD render contract missing: " + token)

events = fn("OnChartEvent")
for token in (
    "CHARTEVENT_OBJECT_DRAG",
    "sparam==HUD_DRAG_HANDLE",
    "HandleFloatingHUDDrag()",
    "RefreshFloatingHUDHover",
    "HUD_SETTINGS_HIT",
    "HUD_CLOSE_HIT",
    "HUD_APPROVE_HIT",
    "HUD_DENY_HIT",
    "HandleHUDClick(sparam)",
):
    if token not in events:
        errors.append("chart-event contract missing: " + token)

clicks = fn("HandleHUDClick")
for token in (
    "ApprovePending(idx)",
    'DeletePending(idx,"user denied trade")',
    "g_fhudHidden=true",
):
    if token not in clicks:
        errors.append("HUD click behavior missing: " + token)

persist = fn("SaveFloatingHUDPosition") + fn("LoadFloatingHUDPosition") + fn("HUDPositionKey")
for token in ("GlobalVariableSet", "GlobalVariableGet", "ChartID()", "GPT_HUD_R32_"):
    if token not in persist:
        errors.append("HUD persistence missing: " + token)

router = fn("RefreshElegantChartDashboard")
for token in ("FindChartManagedPosition(ticket)", "RenderFloatingLiveHUD(ticket)", "RenderFloatingMarketHUD()"):
    if token not in router:
        errors.append("dashboard router missing: " + token)
for old in ("RenderLiveManagementDashboard(ticket)", "RenderCandidateOperationalDashboard()", "RenderScanningDashboard()"):
    if old in router:
        errors.append("legacy full-chart renderer remains active: " + old)
if "ApplyDashboardChartReserve" in router:
    errors.append("floating HUD router must not reserve chart space")

for name in (
    "RenderFloatingMarketHUD",
    "RenderFloatingLiveHUD",
    "HUDPaintShell",
    "HUDRenderMarketBody",
    "HandleFloatingHUDDrag",
):
    body = fn(name)
    if not body:
        errors.append("missing function: " + name)
        continue
    for forbidden in ("OrderSend(", "ApprovedPlaceTrade(", "trade.Buy(", "trade.Sell(", "PositionClose(", "PositionModify("):
        if forbidden in body:
            errors.append(f"{name} is not presentation-only: {forbidden}")

if "InpDashboardReserveChartSpace    = false;" not in SRC:
    errors.append("floating overlay must default to no chart-space reservation")
if "input int    InpDashboardX                  = 18;" not in SRC:
    errors.append("reference X offset must default to 18")
if "input int    InpDashboardY                  = 36;" not in SRC:
    errors.append("reference Y offset must default to 36")

if errors:
    print("PIXEL HUD STATIC CHECK: FAILED")
    for e in errors:
        print("ERROR:", e)
    raise SystemExit(1)

print("PIXEL HUD STATIC CHECK: PASS")
print("R32: 1138x277 reference master at 1:1 canvas scale, reference-tracked typography/icons/buttons, persistent drag, live state binding, chart-local fail-closed controls")
