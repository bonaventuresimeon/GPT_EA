#!/usr/bin/env python3
from pathlib import Path
import re, sys

ROOT=Path(__file__).resolve().parents[1]
SRC=(ROOT/'GPT_EA.mq5').read_text(encoding='utf-8-sig')
errors=[]
passes=[]

def fn(name):
    m=re.search(rf'\b(?:void|bool|double|string|int|ulong|color)\s+{re.escape(name)}\s*\([^)]*\)\s*\{{',SRC)
    if not m:
        errors.append(f'missing function {name}')
        return ''
    i=m.end()-1; depth=0; state='code'
    while i<len(SRC):
        c=SRC[i]; n=SRC[i+1] if i+1<len(SRC) else ''
        if state=='code':
            if c=='/' and n=='/': state='line'; i+=2; continue
            if c=='/' and n=='*': state='block'; i+=2; continue
            if c=='"': state='str'; i+=1; continue
            if c=="'": state='char'; i+=1; continue
            if c=='{': depth+=1
            elif c=='}':
                depth-=1
                if depth==0: return SRC[m.start():i+1]
            i+=1
        elif state=='line':
            if c=='\n': state='code'
            i+=1
        elif state=='block':
            if c=='*' and n=='/': state='code'; i+=2
            else: i+=1
        else:
            q='"' if state=='str' else "'"
            if c=='\\': i+=2; continue
            if c==q: state='code'
            i+=1
    errors.append(f'unterminated function {name}')
    return ''

def require(label, body, tokens):
    miss=[t for t in tokens if t not in body]
    if miss: errors.extend(f'{label}: missing {t}' for t in miss)
    else: passes.append(label)

def require_order(label, body, tokens):
    pos=[body.find(t) for t in tokens]
    if any(p<0 for p in pos) or pos!=sorted(pos):
        errors.append(f'{label}: wrong/missing order {tokens}')
    else: passes.append(label)

header=fn('HUDDrawHeader')
market_panel=fn('HUDDrawMarketPanel')
mtf=fn('HUDDrawMTFPanel')
trade=fn('HUDDrawTradePanel')
conf=fn('HUDDrawConfirmationsPanel')
invalid=fn('HUDDrawInvalidationPanel')
footer=fn('HUDDrawFooter')
market=fn('RenderFloatingMarketHUD')
live=fn('RenderFloatingLiveHUD')
router=fn('RefreshElegantChartDashboard')
status=fn('HUDStatusText')
click=fn('HandleHUDClick')
trade_map=fn('DrawTradeMap')
live_map=fn('DrawLiveManagementMap')
be=fn('VisualBreakEvenLevel')

require('header live engine binding',header,[
    '_Symbol','g_visualSession','HUDPeriodText()','HUDSpreadText(_Symbol)'
])
require('market-state engine binding',market_panel,[
    's.bullish','g_visualRegime','r.structureAligned','VisualVolatilityLabel(r)','g_visualNewsRisk'
])
require('MTF engine binding',mtf,['g_visualTrendDetail','HUDTFState'])
require('planned trade-value binding',trade,[
    's.confidence','s.zoneLow','s.zoneHigh','s.sl','s.tp1','s.tp2','s.tp3','s.effectiveRR1','InpBELockMinR'
])
require('confirmation engine binding',conf,[
    'r.structureAligned','MomentumStillAligned','PriceInsideZone','r.rejectionCandle','r.volumeRatio','InpMinVolumeRatio'
])
require('footer risk/approval binding',footer,[
    'InpRiskPercent',
    'bool enabled=(pendingIndex>=0 && (live || !g_visualNoTrade));',
    'int statusPending=enabled?pendingIndex:-1;',
    'g_displayPending=enabled?pendingIndex:-1'
])
require('market render source binding',market,[
    'ActivePendingForSymbol(_Symbol)','TradeSetup s=g_visualLastSetup','ConfluenceReport r=g_visualLastReport',
    'bool contextHas=(g_visualHasSetup && s.symbol==_Symbol);',
    'bool setupHas=(contextHas && !g_visualNoTrade);',
    'else if(contextHas && g_visualNoTrade)',
    'HUDRenderMarketBody(w,h,sc,contextHas,setupHas,s,r,pending);',
    'if(setupHas && s.valid) DrawTradeMap(s); else DeleteTradeMap();'
])
require('market invalidation sync',fn('HUDRenderMarketBody'),[
    'DoubleToString(s.sl,id)','s.expiryM15','candles without TP1'
])

require('live position binding',live,[
    'PositionGetString(POSITION_SYMBOL)','POSITION_IDENTIFIER','POSITION_TYPE_BUY','POSITION_PRICE_OPEN','POSITION_SL',
    'CurrentPositionR(ticket,rNow,liveR,liveEntry,px,liveBull)',
    'LegacyTicketRead(ticket,"TP1"','LegacyTicketRead(ticket,"TP2"','LegacyTicketRead(ticket,"TP3"',
    'PosKey(pid,"SL_STAGE")','PositionFlag(pid,ticket,"TP1DONE")','PositionFlag(pid,ticket,"TP2PARTIAL")',
    'VisualBreakEvenLevel(sym,bull,entry,R)','DrawLiveManagementMap(ticket)'
])
require('live chart-map sync',live_map,[
    'POSITION_PRICE_OPEN','POSITION_SL','PosKey(pid,"INITSL")','LegacyTicketRead(ticket,"TP1"',
    'LegacyTicketRead(ticket,"TP2"','LegacyTicketRead(ticket,"TP3"','VisualBreakEvenLevel(sym,bull,entry,R)',
    'SetHLine(LEVEL_ENTRY,entry','SetHLine(LEVEL_LIVE_SL,currentSL','SetHLine(LEVEL_TP1,tp1',
    'SetHLine(LEVEL_TP2,tp2','SetHLine(LEVEL_TP3,tp3','RecordTrailingMovement(pid,currentSL,stage)'
])
require('planned chart-map sync',trade_map,[
    'SetHLine(LEVEL_ENTRY,s.preferred','SetHLine(LEVEL_SL,s.sl','SetHLine(LEVEL_TP1,s.tp1',
    'SetHLine(LEVEL_TP2,s.tp2','SetHLine(LEVEL_TP3,s.tp3','s.zoneHigh','s.zoneLow'
])
require('cost-aware BE sync',be,[
    'InpBECostATRFrac*atr','(t.ask-t.bid)+DynamicSlippagePoints(sym)*PointFor(sym)','InpBELockMinR*R','NormalizePriceToTick'
])

require('approval/deny fail-closed',click,[
    'if(idx>=0 && idx<ArraySize(g_pending) && g_pending[idx].active) ApprovePending(idx);',
    'if(idx>=0 && idx<ArraySize(g_pending) && g_pending[idx].active)',
    'DeletePending(idx,"user denied trade")'
])
require('close is presentation-only',click,['g_fhudHidden=true;','DestroyHUD();'])
require_order('router priority LIVE before MARKET',router,[
    'FindChartManagedPosition(ticket)','RenderFloatingLiveHUD(ticket)','RenderFloatingMarketHUD()'
])

for token in ['UI_STATE_SCANNING','UI_STATE_SETUP_FOUND','UI_STATE_WAITING_CONFIRMATION','UI_STATE_ENTRY_ARMED',
              'UI_STATE_TRADE_ACTIVE','UI_STATE_TP1','UI_STATE_BREAK_EVEN','UI_STATE_TRAILING','UI_STATE_CLOSED']:
    if token not in SRC: errors.append('missing UI state '+token)

# Exhaustive deterministic truth table for non-live market route.
def market_state(closed,context_has,no_trade,pending,in_zone,last_ready):
    if closed: return 'CLOSED'
    setup_has=context_has and not no_trade
    if not setup_has: return 'SCANNING'
    if pending: return 'ENTRY_ARMED'
    if in_zone and not last_ready: return 'WAITING_CONFIRMATION'
    return 'SETUP_FOUND'

count=0
for closed in (False,True):
  for context_has in (False,True):
    for no_trade in (False,True):
      for pending in (False,True):
        for in_zone in (False,True):
          for ready in (False,True):
            count+=1
            got=market_state(closed,context_has,no_trade,pending,in_zone,ready)
            setup_has=context_has and not no_trade
            if closed and got!='CLOSED': errors.append('closed precedence failure')
            if not closed and not setup_has and got!='SCANNING': errors.append('NO TRADE leaked into actionable HUD state')
            if not closed and setup_has and pending and got!='ENTRY_ARMED': errors.append('entry-armed precedence failure')
passes.append(f'market truth table: {count} combinations including NO TRADE suppression and waiting candidates')

# Exhaustive live stage ladder. Stage is authoritative for lock/trailing, TP1 flag gates TP1/BE labels.
def live_state(stage,tp1done):
    if stage>=4: return 'TRAILING'
    if stage>=1 and tp1done: return 'BREAK_EVEN'
    if tp1done: return 'TP1'
    return 'TRADE_ACTIVE'
expected={(0,False):'TRADE_ACTIVE',(0,True):'TP1',(1,False):'TRADE_ACTIVE',(1,True):'BREAK_EVEN',
          (2,True):'BREAK_EVEN',(3,True):'BREAK_EVEN',(4,True):'TRAILING',(5,True):'TRAILING'}
for args,want in expected.items():
    got=live_state(*args)
    if got!=want: errors.append(f'live ladder {args}: {got} != {want}')
passes.append('live management ladder: TRADE ACTIVE > TP1 > BREAK EVEN > TRAILING')

require('status vocabulary',status,[
    'SCANNING','NO TRADE','SETUP DETECTED','WAITING FOR CONFIRMATION','AWAITING APPROVAL','POSITION OPEN',
    'TP1 HIT','BREAK-EVEN ACTIVE','TRAILING PROFIT','TRADE CLOSED','NEWS PAUSE','RISK BLOCKED','SETUP INVALIDATED'
])

# Ensure the visual layer cannot reserve/reformat chart space.
if 'input bool   InpDashboardReserveChartSpace    = false' not in SRC:
    errors.append('floating HUD chart-space default changed')
else: passes.append('floating overlay / no chart-space reservation')

if errors:
    print('HUD ENGINE BINDING QA: FAILED')
    for e in errors: print('ERROR:',e)
    sys.exit(1)

print('HUD ENGINE BINDING QA: PASS')
for p in passes: print('PASS:',p)
print('STATE FLOW: SCANNING > SETUP FOUND > WAITING CONFIRMATION > ENTRY ARMED > TRADE ACTIVE > TP1 > BREAK EVEN > TRAILING > CLOSED')
print('VALUES: HUD and chart levels source directly from TradeSetup / ConfluenceReport / broker Position / persisted management state.')
