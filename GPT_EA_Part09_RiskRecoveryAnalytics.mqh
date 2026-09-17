// ============================================================================
// GPT_EA Part 09 - Portfolio risk, recovery, analytics, DOM, regime and ONNX
// ============================================================================

// --------------------------- Risk controls ---------------------------
input bool   InpUsePortfolioRisk          = true;
input double InpMaxPortfolioRiskPercent   = 3.00;
input double InpMaxCorrelatedRiskPercent  = 2.00;
input double InpMaxSymbolRiskPercent      = 1.50;
input bool   InpUseDailyKillSwitch        = true;
input double InpDailyLossLimitPercent     = 3.00;
input double InpMaxEquityDrawdownPercent = 8.00;
input int    InpMaxConsecutiveLosses      = 3;
input int    InpCooldownM15Candles        = 4;

// ------------------------- Execution quality -------------------------
input bool   InpUseDynamicSlippage        = true;
input int    InpMinDynamicSlippagePoints  = 10;
input int    InpMaxDynamicSlippagePoints  = 80;
input double InpSlippageSpreadMultiplier  = 1.50;
input double InpSlippageATRFraction       = 0.03;
input bool   InpWriteExecutionJournal     = true;
input string InpExecutionJournalFile      = "GPT_EA_Execution.csv";

// ---------------------- Institutional confluence ---------------------
input bool   InpUseDOMConfirmation        = false;
input bool   InpRequireDOMConfirmation    = false;
input double InpMinDOMImbalance           = 1.10;
input int    InpLevelLookbackBars         = 80;
input int    InpMaxLevelTouches           = 4;
input bool   InpUseRegimeFilter           = true;
input bool   InpRequireSDRForBreakout     = true;
input double InpDisplacementATR           = 0.80;

// ------------------------- Restart recovery --------------------------
input bool   InpPersistPendingApprovals   = true;
input bool   InpRecoverOpenPositions      = true;

// --------------------------- Local ML/ONNX ---------------------------
// Optional model contract: float input [1,12], float output [1,1] probability.
input bool   InpUseONNXConfirmation       = false;
input bool   InpRequireONNXConfirmation   = false;
input string InpONNXModelFile             = "GPT_EA_Model.onnx";
input double InpONNXMinProbability        = 0.60;

bool   g_manualPaused=false;
double g_dayStartEquity=0;
double g_equityPeak=0;
int    g_dayKey=0;
long   g_onnxHandle=INVALID_HANDLE;
bool   g_domSubscribed[];

string RISK_PANEL="GPT_EA_RISK_PANEL";
string RISK_TEXT="GPT_EA_RISK_TEXT";
string BTN_PAUSE="GPT_EA_PAUSE_BTN";

// -------------------------- Persistent keys --------------------------
string SafeSymbolKey(string s)
{
   StringReplace(s,".","_"); StringReplace(s,"#","_"); StringReplace(s,"/","_");
   StringReplace(s,"-","_"); StringReplace(s," ","_");
   return s;
}
string SysKey(string suffix){ return StringFormat("GPT%I64d_%s",InpMagic,suffix); }
string SymKey(const string sym,string suffix){ return SysKey(SafeSymbolKey(sym)+"_"+suffix); }
string PosKey(ulong id,string suffix){ return StringFormat("GPT%I64d_P%I64u_%s",InpMagic,id,suffix); }

double GVRead(const string key,double def=0)
{
   return GlobalVariableCheck(key)?GlobalVariableGet(key):def;
}
void GVWrite(const string key,double v){ GlobalVariableSet(key,v); }

int TodayKey()
{
   MqlDateTime t={}; TimeToStruct(TimeTradeServer(),t);
   return t.year*10000+t.mon*100+t.day;
}

void RefreshRiskSession()
{
   double eq=AccountInfoDouble(ACCOUNT_EQUITY);
   int today=TodayKey();
   int saved=(int)GVRead(SysKey("DAYKEY"),0);
   if(saved!=today)
   {
      GVWrite(SysKey("DAYKEY"),today);
      GVWrite(SysKey("DAYSTART_EQ"),eq);
   }
   g_dayKey=today;
   g_dayStartEquity=GVRead(SysKey("DAYSTART_EQ"),eq);

   double peak=GVRead(SysKey("EQUITY_PEAK"),eq);
   if(eq>peak){ peak=eq; GVWrite(SysKey("EQUITY_PEAK"),peak); }
   g_equityPeak=peak;
   g_manualPaused=(GVRead(SysKey("PAUSED"),0)>0.5);
}

double DailyLossPercent()
{
   RefreshRiskSession();
   if(g_dayStartEquity<=0) return 0;
   return MathMax(0.0,(g_dayStartEquity-AccountInfoDouble(ACCOUNT_EQUITY))/g_dayStartEquity*100.0);
}

double EquityDrawdownPercent()
{
   RefreshRiskSession();
   if(g_equityPeak<=0) return 0;
   return MathMax(0.0,(g_equityPeak-AccountInfoDouble(ACCOUNT_EQUITY))/g_equityPeak*100.0);
}

int ConsecutiveLosses(){ return (int)GVRead(SysKey("CONSEC_LOSS"),0); }

bool RiskKillSwitchActive(string &why)
{
   RefreshRiskSession();
   if(g_manualPaused){ why="Manual PAUSE is active."; return true; }
   if(!InpUseDailyKillSwitch){ why="Kill switch disabled."; return false; }

   double daily=DailyLossPercent();
   double dd=EquityDrawdownPercent();
   int losses=ConsecutiveLosses();
   if(InpDailyLossLimitPercent>0 && daily>=InpDailyLossLimitPercent)
   { why=StringFormat("Daily equity loss %.2f%% >= %.2f%% limit.",daily,InpDailyLossLimitPercent); return true; }
   if(InpMaxEquityDrawdownPercent>0 && dd>=InpMaxEquityDrawdownPercent)
   { why=StringFormat("Equity drawdown %.2f%% >= %.2f%% limit.",dd,InpMaxEquityDrawdownPercent); return true; }
   if(InpMaxConsecutiveLosses>0 && losses>=InpMaxConsecutiveLosses)
   { why=StringFormat("%d consecutive losses >= %d limit.",losses,InpMaxConsecutiveLosses); return true; }
   why="Risk kill switch clear.";
   return false;
}

void ToggleTradingPause()
{
   RefreshRiskSession();
   g_manualPaused=!g_manualPaused;
   GVWrite(SysKey("PAUSED"),g_manualPaused?1:0);
   Print("GPT_EA manual trading state: ",g_manualPaused?"PAUSED":"ACTIVE");
}

// ----------------------------- Cooldown ------------------------------
void MarkSignalCooldown(const string sym)
{
   GVWrite(SymKey(sym,"COOLDOWN"),(double)TimeTradeServer());
}

bool CooldownActive(const string sym,string &why)
{
   if(InpCooldownM15Candles<=0){ why="Cooldown disabled."; return false; }
   datetime t=(datetime)GVRead(SymKey(sym,"COOLDOWN"),0);
   if(t<=0){ why="No duplicate-signal cooldown."; return false; }
   int shift=iBarShift(sym,PERIOD_M15,t,false);
   if(shift<0) shift=(int)((TimeTradeServer()-t)/900);
   if(shift<InpCooldownM15Candles)
   {
      why=StringFormat("Cooldown active: %d/%d M15 candles elapsed.",shift,InpCooldownM15Candles);
      return true;
   }
   why="Cooldown complete.";
   return false;
}

// -------------------------- Dynamic slippage -------------------------
int DynamicSlippagePoints(const string sym)
{
   if(!InpUseDynamicSlippage) return InpMaxSlippagePoints;
   MqlTick t; if(!GetTickSafe(sym,t)) return InpMaxSlippagePoints;
   double pt=PointFor(sym); if(pt<=0) return InpMaxSlippagePoints;
   double spreadPts=MathMax(0.0,(t.ask-t.bid)/pt);
   double atr=0; ATRValue(sym,PERIOD_M5,InpATRPeriod,1,atr);
   double atrPts=(atr>0?atr/pt:0);
   double raw=MathMax((double)InpMinDynamicSlippagePoints,
                      MathMax(spreadPts*InpSlippageSpreadMultiplier,atrPts*InpSlippageATRFraction));
   int out=(int)MathCeil(raw);
   out=MathMax(InpMinDynamicSlippagePoints,MathMin(InpMaxDynamicSlippagePoints,out));
   return out;
}

double EffectiveRRDynamic(const TradeSetup &s)
{
   MqlTick t; if(!GetTickSafe(s.symbol,t)) return 0;
   double cost=MathMax(0.0,t.ask-t.bid)+DynamicSlippagePoints(s.symbol)*PointFor(s.symbol);
   double risk=MathAbs(s.preferred-s.sl)+cost;
   double reward=MathAbs(s.tp2-s.preferred)-cost;
   if(risk<=0 || reward<=0) return 0;
   return reward/risk;
}

// ------------------------- Portfolio exposure ------------------------
int ExposureGroup(const string sym)
{
   string u=sym; StringToUpper(u);
   if(StringFind(u,"US100")>=0 || StringFind(u,"NAS")>=0 || StringFind(u,"USTEC")>=0 ||
      StringFind(u,"GER40")>=0 || StringFind(u,"DE40")>=0 || StringFind(u,"DAX")>=0 ||
      StringFind(u,"US30")>=0 || StringFind(u,"SPX")>=0) return 1; // equity indices
   if(StringFind(u,"XAU")>=0 || StringFind(u,"XAG")>=0) return 2; // metals
   if(StringFind(u,"BTC")>=0 || StringFind(u,"ETH")>=0) return 3; // crypto
   return 4; // FX/other
}

double PositionRiskMoney(const ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return 0;
   double sl=PositionGetDouble(POSITION_SL);
   if(sl<=0) return 1.0e100; // unprotected position => block additional risk
   string sym=PositionGetString(POSITION_SYMBOL);
   double entry=PositionGetDouble(POSITION_PRICE_OPEN);
   double vol=PositionGetDouble(POSITION_VOLUME);
   long type=PositionGetInteger(POSITION_TYPE);
   double p=0;
   ENUM_ORDER_TYPE ot=(type==POSITION_TYPE_BUY?ORDER_TYPE_BUY:ORDER_TYPE_SELL);
   if(!OrderCalcProfit(ot,sym,vol,entry,sl,p)) return 0;
   return MathMax(0.0,-p);
}

double CurrentPortfolioRiskMoney()
{
   double sum=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      double r=PositionRiskMoney(tk);
      if(r>1.0e90) return r;
      sum+=r;
   }
   return sum;
}

double CurrentPortfolioRiskPercent()
{
   double eq=AccountInfoDouble(ACCOUNT_EQUITY); if(eq<=0) return 0;
   double r=CurrentPortfolioRiskMoney(); if(r>1.0e90) return 999;
   return r/eq*100.0;
}

double ProposedRiskMoney(const TradeSetup &s,double lots)
{
   double p=0;
   ENUM_ORDER_TYPE ot=(s.bullish?ORDER_TYPE_BUY:ORDER_TYPE_SELL);
   if(!OrderCalcProfit(ot,s.symbol,lots,s.preferred,s.sl,p)) return 0;
   return MathAbs(p);
}

double CorrelatedOpenRiskMoney(const TradeSetup &s)
{
   int group=ExposureGroup(s.symbol);
   double sum=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      string ps=PositionGetString(POSITION_SYMBOL);
      if(ExposureGroup(ps)!=group) continue;
      bool sameDir=(s.bullish?PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY:PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL);
      if(!sameDir) continue;
      double r=PositionRiskMoney(tk); if(r>1.0e90) return r;
      sum+=r;
   }
   return sum;
}

bool PortfolioRiskAllows(const TradeSetup &s,double lots,string &why)
{
   if(!InpUsePortfolioRisk){ why="Portfolio risk control disabled."; return true; }
   double eq=AccountInfoDouble(ACCOUNT_EQUITY); if(eq<=0){ why="Equity unavailable."; return false; }
   double proposed=ProposedRiskMoney(s,lots);
   double open=CurrentPortfolioRiskMoney();
   if(open>1.0e90){ why="Existing GPT_EA position has no protective stop."; return false; }
   double corr=CorrelatedOpenRiskMoney(s);
   if(corr>1.0e90){ why="Correlated position has no protective stop."; return false; }

   double proposedPct=proposed/eq*100.0;
   double portfolioPct=(open+proposed)/eq*100.0;
   double corrPct=(corr+proposed)/eq*100.0;
   if(InpMaxSymbolRiskPercent>0 && proposedPct>InpMaxSymbolRiskPercent+1e-8)
   { why=StringFormat("Proposed symbol risk %.2f%% > %.2f%% cap.",proposedPct,InpMaxSymbolRiskPercent); return false; }
   if(InpMaxPortfolioRiskPercent>0 && portfolioPct>InpMaxPortfolioRiskPercent+1e-8)
   { why=StringFormat("Portfolio risk %.2f%% > %.2f%% cap.",portfolioPct,InpMaxPortfolioRiskPercent); return false; }
   if(InpMaxCorrelatedRiskPercent>0 && corrPct>InpMaxCorrelatedRiskPercent+1e-8)
   { why=StringFormat("Correlated directional risk %.2f%% > %.2f%% cap.",corrPct,InpMaxCorrelatedRiskPercent); return false; }
   why=StringFormat("Portfolio %.2f%% | correlated %.2f%% | proposed %.2f%%.",portfolioPct,corrPct,proposedPct);
   return true;
}

bool PreAuthorizationRiskAllows(const TradeSetup &s,string &why)
{
   string kill=""; if(RiskKillSwitchActive(kill)){ why=kill; return false; }
   string cd=""; if(CooldownActive(s.symbol,cd)){ why=cd; return false; }
   double rm=0,ol=0; double lots=LotSizeForRisk(s,rm,ol);
   if(lots<=0){ why="Risk lot-size calculation returned zero."; return false; }
   return PortfolioRiskAllows(s,lots,why);
}

// ----------------------- Depth of Market (DOM) -----------------------
void InitDOMSubscriptions()
{
   ArrayResize(g_domSubscribed,ArraySize(g_symbols));
   for(int i=0;i<ArraySize(g_symbols);i++)
   {
      g_domSubscribed[i]=false;
      if(!InpUseDOMConfirmation || g_symbols[i]=="") continue;
      if(EnsureSymbol(g_symbols[i])) g_domSubscribed[i]=MarketBookAdd(g_symbols[i]);
   }
}

void ShutdownDOMSubscriptions()
{
   for(int i=0;i<ArraySize(g_symbols) && i<ArraySize(g_domSubscribed);i++)
      if(g_domSubscribed[i]) MarketBookRelease(g_symbols[i]);
}

bool DOMAligned(const string sym,bool bull,double &ratio,bool &available)
{
   ratio=1.0; available=false;
   if(!InpUseDOMConfirmation) return true;
   MqlBookInfo book[];
   if(!MarketBookGet(sym,book) || ArraySize(book)<=0) return !InpRequireDOMConfirmation;
   available=true;
   double buy=0,sell=0;
   for(int i=0;i<ArraySize(book);i++)
   {
      double v=(book[i].volume_real>0?book[i].volume_real:(double)book[i].volume);
      if(book[i].type==BOOK_TYPE_BUY || book[i].type==BOOK_TYPE_BUY_MARKET) buy+=v;
      else if(book[i].type==BOOK_TYPE_SELL || book[i].type==BOOK_TYPE_SELL_MARKET) sell+=v;
   }
   if(buy<=0 || sell<=0) return !InpRequireDOMConfirmation;
   ratio=(bull?buy/sell:sell/buy);
   return ratio>=InpMinDOMImbalance;
}

// ---------------------- Level quality and regime ---------------------
int LevelQualityScore(const TradeSetup &s,int &touches,int &rejections)
{
   touches=0; rejections=0;
   double atr=0; if(!ATRValue(s.symbol,PERIOD_M15,InpATRPeriod,1,atr) || atr<=0) return 0;
   MqlRates r[]; ArraySetAsSeries(r,true);
   int n=CopyRates(s.symbol,PERIOD_M15,1,MathMax(20,InpLevelLookbackBars),r);
   if(n<=0) return 0;
   double band=0.15*atr;
   for(int i=0;i<n;i++)
   {
      bool touched=(r[i].low<=s.preferred+band && r[i].high>=s.preferred-band);
      if(!touched) continue;
      touches++;
      if(s.bullish && r[i].close>s.preferred && r[i].close>r[i].open) rejections++;
      if(!s.bullish && r[i].close<s.preferred && r[i].close<r[i].open) rejections++;
   }
   int score=10;
   if(touches==0) score=5;
   else if(touches<=2) score=10;
   else if(touches<=InpMaxLevelTouches) score=7;
   else score=2;
   score+=(int)MathMin(3,rejections);
   return MathMin(10,score);
}

bool SweepDisplacementRetest(const TradeSetup &s)
{
   MqlRates r[]; ArraySetAsSeries(r,true);
   if(CopyRates(s.symbol,PERIOD_M15,1,20,r)<14) return false;
   double atr=0; if(!ATRValue(s.symbol,PERIOD_M15,InpATRPeriod,1,atr) || atr<=0) return false;

   // Search recent closed bars for sweep -> displacement -> retest sequence.
   for(int i=0;i<=4;i++)
   {
      MqlRates retest=r[i], disp=r[i+1], sweep=r[i+2];
      double priorHi=-1.0e100,priorLo=1.0e100;
      for(int j=i+3;j<=i+10;j++)
      { priorHi=MathMax(priorHi,r[j].high); priorLo=MathMin(priorLo,r[j].low); }
      double body=MathAbs(disp.close-disp.open);
      bool displaced=(body>=InpDisplacementATR*atr);
      if(s.bullish)
      {
         bool swept=(sweep.low<priorLo && sweep.close>priorLo);
         bool impulse=(displaced && disp.close>sweep.high && disp.close>disp.open);
         double mid=(disp.open+disp.close)*0.5;
         bool held=(retest.low<=disp.close && retest.low>=sweep.low && retest.close>=mid);
         if(swept && impulse && held) return true;
      }
      else
      {
         bool swept=(sweep.high>priorHi && sweep.close<priorHi);
         bool impulse=(displaced && disp.close<sweep.low && disp.close<disp.open);
         double mid=(disp.open+disp.close)*0.5;
         bool held=(retest.high>=disp.close && retest.high<=sweep.high && retest.close<=mid);
         if(swept && impulse && held) return true;
      }
   }
   return false;
}

string DetectMarketRegime(const string sym)
{
   double adx=0,pdi=0,mdi=0,cur=0,avg=0;
   ADXSnapshot(sym,PERIOD_M15,InpADXPeriod,adx,pdi,mdi);
   ATRValue(sym,PERIOD_M15,InpATRPeriod,1,cur);
   avg=AverageATR(sym,PERIOD_M15,InpATRPeriod,50);
   double ar=(avg>0?cur/avg:1.0);
   double orr=OpeningRangeRatio(sym);
   if(ar>=1.45 || orr>=1.80) return "HIGH_VOL_EXPANSION";
   if(adx>=25.0 && ar>=0.85) return "TRENDING";
   if(ar<=0.70 && adx<18.0) return "COMPRESSION";
   return "RANGING";
}

int RegimeAdjustment(const TradeSetup &s,const string regime)
{
   if(!InpUseRegimeFilter) return 0;
   if(regime=="HIGH_VOL_EXPANSION") return (s.kind==SETUP_BREAKOUT_RETEST?8:2);
   if(regime=="TRENDING") return (s.kind==SETUP_PULLBACK?7:6);
   if(regime=="COMPRESSION") return (s.kind==SETUP_BREAKOUT_RETEST?2:-2);
   if(regime=="RANGING") return (s.kind==SETUP_PULLBACK?2:-7);
   return 0;
}

// ----------------------------- ONNX ----------------------------------
bool InitONNX()
{
   if(!InpUseONNXConfirmation) return true;
   g_onnxHandle=OnnxCreate(InpONNXModelFile,ONNX_USE_CPU_ONLY);
   if(g_onnxHandle==INVALID_HANDLE)
   {
      Print("GPT_EA ONNX load failed for ",InpONNXModelFile," error=",GetLastError());
      return !InpRequireONNXConfirmation;
   }
   long inShape[2]={1,12};
   long outShape[2]={1,1};
   if(!OnnxSetInputShape(g_onnxHandle,0,inShape) || !OnnxSetOutputShape(g_onnxHandle,0,outShape))
   {
      Print("GPT_EA ONNX shape setup failed error=",GetLastError());
      OnnxRelease(g_onnxHandle); g_onnxHandle=INVALID_HANDLE;
      return !InpRequireONNXConfirmation;
   }
   return true;
}

void ShutdownONNX()
{
   if(g_onnxHandle!=INVALID_HANDLE){ OnnxRelease(g_onnxHandle); g_onnxHandle=INVALID_HANDLE; }
}

double ONNXProbability(const TradeSetup &s,const ConfluenceReport &r,const string regime)
{
   if(!InpUseONNXConfirmation || g_onnxHandle==INVALID_HANDLE) return -1.0;
   matrixf x(1,12);
   vectorf y(1);
   x[0][0]=(float)(s.confidence/100.0);
   x[0][1]=(float)(r.score/100.0);
   x[0][2]=(float)MathMin(1.5,r.adx/40.0);
   x[0][3]=(float)MathMin(2.0,r.volumeRatio)/2.0f;
   x[0][4]=(float)MathMin(2.5,r.openingRangeRatio)/2.5f;
   x[0][5]=(float)(r.structureAligned?1.0:0.0);
   x[0][6]=(float)(r.liquiditySweep?1.0:0.0);
   x[0][7]=(float)(r.fairValueGap?1.0:0.0);
   x[0][8]=(float)(r.rejectionCandle?1.0:0.0);
   x[0][9]=(float)(r.htfVotes/3.0);
   x[0][10]=(float)MathMin(1.0,EffectiveRRDynamic(s)/3.0);
   double reg=(regime=="TRENDING"?1.0:regime=="HIGH_VOL_EXPANSION"?0.8:regime=="RANGING"?0.4:0.2);
   x[0][11]=(float)reg;
   if(!OnnxRun(g_onnxHandle,ONNX_NO_CONVERSION,x,y))
   {
      Print("GPT_EA ONNX inference failed error=",GetLastError());
      return -1.0;
   }
   return MathMax(0.0,MathMin(1.0,(double)y[0]));
}

// Combine level freshness, SDR, regime, DOM and optional ML with existing confluence.
bool EnhanceSetupWithInstitutionalFilters(TradeSetup &s,const ConfluenceReport &r,string &detail)
{
   detail="";
   if(s.preferred<=0){ s.valid=false; return false; }
   int touches=0,rejections=0;
   int level=LevelQualityScore(s,touches,rejections);
   bool sdr=SweepDisplacementRetest(s);
   string regime=DetectMarketRegime(s.symbol);
   int regAdj=RegimeAdjustment(s,regime);
   double domRatio=1.0; bool domAvailable=false;
   bool domOK=DOMAligned(s.symbol,s.bullish,domRatio,domAvailable);

   s.effectiveRR1=EffectiveRRDynamic(s);
   int adj=(level>=8?4:level<=3?-5:0)+regAdj;
   if(sdr) adj+=6;
   if(InpUseDOMConfirmation && domAvailable) adj+=(domOK?4:-6);
   s.confidence=MathMax(0,MathMin(99,s.confidence+adj));

   double ml=ONNXProbability(s,r,regime);
   bool mlOK=(ml<0?(!InpRequireONNXConfirmation):ml>=InpONNXMinProbability);
   if(ml>=0) s.confidence=MathMax(0,MathMin(99,s.confidence+(ml>=InpONNXMinProbability?4:-7)));

   bool sdrOK=(!InpRequireSDRForBreakout || s.kind!=SETUP_BREAKOUT_RETEST || sdr);
   bool domGate=(!InpRequireDOMConfirmation || domOK);
   if(!sdrOK || !domGate || !mlOK || s.effectiveRR1<InpMinEffectiveRR || s.confidence<InpMinConfidence)
      s.valid=false;

   detail=StringFormat("Regime %s | level %d/10 (%d touches/%d rejects) | SDR %s | DOM %s %.2fx | dynamic R:R %.2f | ONNX %s",
      regime,level,touches,rejections,sdr?"YES":"NO",domAvailable?(domOK?"OK":"WEAK"):"N/A",domRatio,s.effectiveRR1,
      ml<0?"N/A":DoubleToString(ml,2));
   s.reason+=" | "+detail;
   return s.valid;
}

// ------------------------- Execution planning ------------------------
void RegisterPlannedExecution(const TradeSetup &s,double lots,double riskMoney)
{
   MqlTick t; GetTickSafe(s.symbol,t);
   double ref=(s.bullish?t.ask:t.bid);
   double spreadPts=(PointFor(s.symbol)>0?(t.ask-t.bid)/PointFor(s.symbol):0);
   GVWrite(SymKey(s.symbol,"PLAN_TIME"),(double)TimeTradeServer());
   GVWrite(SymKey(s.symbol,"PLAN_REF"),ref);
   GVWrite(SymKey(s.symbol,"PLAN_RISK"),riskMoney);
   GVWrite(SymKey(s.symbol,"PLAN_KIND"),(double)s.kind);
   GVWrite(SymKey(s.symbol,"PLAN_CONF"),(double)s.confidence);
   GVWrite(SymKey(s.symbol,"PLAN_RR"),s.effectiveRR1);
   GVWrite(SymKey(s.symbol,"PLAN_SPREAD"),spreadPts);
   GVWrite(SymKey(s.symbol,"PLAN_SL"),s.sl);
   GVWrite(SymKey(s.symbol,"PLAN_LOTS"),lots);
}

// ------------------------ Restart persistence ------------------------
void PersistPendingApprovals()
{
   if(!InpPersistPendingApprovals) return;
   for(int s=0;s<ArraySize(g_symbols);s++)
   {
      string sym=g_symbols[s]; if(sym=="") continue;
      int idx=ActivePendingForSymbol(sym);
      if(idx<0 || !g_pending[idx].active)
      { GVWrite(SymKey(sym,"P_ACTIVE"),0); continue; }
      TradeSetup p=g_pending[idx].setup;
      GVWrite(SymKey(sym,"P_ACTIVE"),1);
      GVWrite(SymKey(sym,"P_EXPIRES"),(double)g_pending[idx].expiresAt);
      GVWrite(SymKey(sym,"P_BULL"),p.bullish?1:0);
      GVWrite(SymKey(sym,"P_KIND"),(double)p.kind);
      GVWrite(SymKey(sym,"P_ZL"),p.zoneLow); GVWrite(SymKey(sym,"P_ZH"),p.zoneHigh);
      GVWrite(SymKey(sym,"P_PREF"),p.preferred); GVWrite(SymKey(sym,"P_SL"),p.sl);
      GVWrite(SymKey(sym,"P_TP1"),p.tp1); GVWrite(SymKey(sym,"P_TP2"),p.tp2); GVWrite(SymKey(sym,"P_TP3"),p.tp3);
      GVWrite(SymKey(sym,"P_CONF"),p.confidence); GVWrite(SymKey(sym,"P_EXP"),p.expiryM15);
   }
}

void RecoverPendingApprovals()
{
   if(!InpPersistPendingApprovals) return;
   datetime now=TimeTradeServer();
   for(int si=0;si<ArraySize(g_symbols);si++)
   {
      string sym=g_symbols[si];
      if(GVRead(SymKey(sym,"P_ACTIVE"),0)<0.5) continue;
      datetime expires=(datetime)GVRead(SymKey(sym,"P_EXPIRES"),0);
      if(expires<=now){ GVWrite(SymKey(sym,"P_ACTIVE"),0); MarkSignalCooldown(sym); continue; }
      TradeSetup p;
      p.valid=true; p.symbol=sym; p.bullish=(GVRead(SymKey(sym,"P_BULL"),1)>0.5);
      p.kind=(SetupKind)(int)GVRead(SymKey(sym,"P_KIND"),SETUP_PULLBACK);
      p.name=(p.kind==SETUP_BREAKOUT_RETEST?"BREAKOUT-RETEST":"PULLBACK");
      p.zoneLow=GVRead(SymKey(sym,"P_ZL"),0); p.zoneHigh=GVRead(SymKey(sym,"P_ZH"),0);
      p.preferred=GVRead(SymKey(sym,"P_PREF"),0); p.sl=GVRead(SymKey(sym,"P_SL"),0);
      p.tp1=GVRead(SymKey(sym,"P_TP1"),0); p.tp2=GVRead(SymKey(sym,"P_TP2"),0); p.tp3=GVRead(SymKey(sym,"P_TP3"),0);
      p.confidence=(int)GVRead(SymKey(sym,"P_CONF"),0); p.expiryM15=(int)GVRead(SymKey(sym,"P_EXP"),4);
      p.nominalRR1=1; p.effectiveRR1=EffectiveRRDynamic(p);
      p.reason="Recovered pending authorization after MT5 restart.";
      p.invalidation="Fresh validation is mandatory before execution.";
      p.failurePattern="Recovered setup is discarded if current structure no longer confirms.";
      p.eventRisk=p.yieldRisk=""; p.executionRule="Approval requires fresh price/trigger/risk validation.";
      int n=ArraySize(g_pending); ArrayResize(g_pending,n+1);
      g_pending[n].active=true; g_pending[n].setup=p; g_pending[n].card="Recovered after restart";
      g_pending[n].scanReason="Restart recovery"; g_pending[n].createdAt=now; g_pending[n].expiresAt=expires;
   }
}

void RecoverOpenPositionState()
{
   if(!InpRecoverOpenPositions) return;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      string sym=PositionGetString(POSITION_SYMBOL);
      long type=PositionGetInteger(POSITION_TYPE); bool bull=(type==POSITION_TYPE_BUY);
      double entry=PositionGetDouble(POSITION_PRICE_OPEN);
      double sl=PositionGetDouble(POSITION_SL);
      double tp=PositionGetDouble(POSITION_TP);
      if(!GlobalVariableCheck(GVKey(tk,"INITSL"))) GVSet(tk,"INITSL",sl);
      double initSL=GVGet(tk,"INITSL",sl);
      double R=MathAbs(entry-initSL);
      if(R<=0 && tp>0) R=MathAbs(tp-entry)/3.0;
      if(!GlobalVariableCheck(GVKey(tk,"TP1"))) GVSet(tk,"TP1",bull?entry+R:entry-R);
      if(!GlobalVariableCheck(GVKey(tk,"TP2"))) GVSet(tk,"TP2",bull?entry+2*R:entry-2*R);
      if(!GlobalVariableCheck(GVKey(tk,"TP3"))) GVSet(tk,"TP3",tp>0?tp:(bull?entry+3*R:entry-3*R));
      if(!GlobalVariableCheck(GVKey(tk,"EXP"))) GVSet(tk,"EXP",AdaptiveExpiry(sym,InpPullbackExpiryM15));
      if(!GlobalVariableCheck(GVKey(tk,"TP1DONE")))
      {
         bool beMoved=(bull?sl>=entry:sl<=entry) && sl>0;
         GVSet(tk,"TP1DONE",beMoved?1:0);
      }
      ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
      if(GVRead(PosKey(pid,"INITSL"),0)<=0) GVWrite(PosKey(pid,"INITSL"),initSL);
      if(GVRead(PosKey(pid,"ENTRY"),0)<=0) GVWrite(PosKey(pid,"ENTRY"),entry);
      if(GVRead(PosKey(pid,"OPEN_TIME"),0)<=0) GVWrite(PosKey(pid,"OPEN_TIME"),(double)PositionGetInteger(POSITION_TIME));
      if(GVRead(PosKey(pid,"KIND"),0)<=0)
      {
         string c=PositionGetString(POSITION_COMMENT);
         GVWrite(PosKey(pid,"KIND"),(StringFind(c,"BR")>=0?SETUP_BREAKOUT_RETEST:SETUP_PULLBACK));
      }
      if(GVRead(PosKey(pid,"RISK"),0)<=0 && R>0)
      {
         double rm=0; ENUM_ORDER_TYPE ot=(bull?ORDER_TYPE_BUY:ORDER_TYPE_SELL);
         if(OrderCalcProfit(ot,sym,PositionGetDouble(POSITION_VOLUME),entry,initSL,rm)) GVWrite(PosKey(pid,"RISK"),MathAbs(rm));
      }
   }
}

// ---------------------- Analytics and journal ------------------------
string StatKey(int kind,string suffix){ return SysKey(StringFormat("STAT_%d_%s",kind,suffix)); }

void AppendJournal(const string event,const string sym,int kind,ulong deal,ulong pid,double requested,double actual,double slipPts,double r,double mae,double mfe,const string note)
{
   if(!InpWriteExecutionJournal) return;
   int h=FileOpen(InpExecutionJournalFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,',');
   if(h==INVALID_HANDLE){ Print("Journal open failed error=",GetLastError()); return; }
   if(FileSize(h)==0)
      FileWrite(h,"time","event","symbol","setup","deal","position_id","requested","actual","slippage_pts","R","MAE_R","MFE_R","note");
   FileSeek(h,0,SEEK_END);
   FileWrite(h,TimeToString(TimeTradeServer(),TIME_DATE|TIME_SECONDS),event,sym,
             kind==SETUP_BREAKOUT_RETEST?"BREAKOUT_RETEST":"PULLBACK",
             (string)deal,(string)pid,DoubleToString(requested,DigitsFor(sym)),DoubleToString(actual,DigitsFor(sym)),
             DoubleToString(slipPts,2),DoubleToString(r,3),DoubleToString(mae,3),DoubleToString(mfe,3),note);
   FileClose(h);
}

void UpdateSetupStats(int kind,double r,double slip,double mae,double mfe)
{
   double trades=GVRead(StatKey(kind,"TRADES"),0)+1;
   double wins=GVRead(StatKey(kind,"WINS"),0)+(r>0?1:0);
   double losses=GVRead(StatKey(kind,"LOSSES"),0)+(r<=0?1:0);
   GVWrite(StatKey(kind,"TRADES"),trades); GVWrite(StatKey(kind,"WINS"),wins); GVWrite(StatKey(kind,"LOSSES"),losses);
   GVWrite(StatKey(kind,"SUMR"),GVRead(StatKey(kind,"SUMR"),0)+r);
   GVWrite(StatKey(kind,"GW"),GVRead(StatKey(kind,"GW"),0)+MathMax(0.0,r));
   GVWrite(StatKey(kind,"GL"),GVRead(StatKey(kind,"GL"),0)+MathMax(0.0,-r));
   GVWrite(StatKey(kind,"SLIP"),GVRead(StatKey(kind,"SLIP"),0)+slip);
   GVWrite(StatKey(kind,"MAE"),GVRead(StatKey(kind,"MAE"),0)+mae);
   GVWrite(StatKey(kind,"MFE"),GVRead(StatKey(kind,"MFE"),0)+mfe);
   int cons=ConsecutiveLosses();
   if(r>0) cons=0; else cons++;
   GVWrite(SysKey("CONSEC_LOSS"),cons);
}

string SetupStatsText(int kind)
{
   double n=GVRead(StatKey(kind,"TRADES"),0);
   if(n<=0) return "No completed trades";
   double wins=GVRead(StatKey(kind,"WINS"),0);
   double sumr=GVRead(StatKey(kind,"SUMR"),0);
   double gw=GVRead(StatKey(kind,"GW"),0),gl=GVRead(StatKey(kind,"GL"),0);
   double pf=(gl>0?gw/gl:(gw>0?99.0:0));
   return StringFormat("N %.0f | Win %.1f%% | AvgR %.2f | PF %.2f | Slip %.1f | MAE %.2fR | MFE %.2fR",
      n,wins/n*100.0,sumr/n,pf,GVRead(StatKey(kind,"SLIP"),0)/n,
      GVRead(StatKey(kind,"MAE"),0)/n,GVRead(StatKey(kind,"MFE"),0)/n);
}

bool PositionIdentifierOpen(ulong pid)
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0 || !PositionSelectByTicket(tk)) continue;
      if((ulong)PositionGetInteger(POSITION_IDENTIFIER)==pid) return true;
   }
   return false;
}

void UpdateOpenTradeExcursions()
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
      string sym=PositionGetString(POSITION_SYMBOL); bool bull=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
      double entry=PositionGetDouble(POSITION_PRICE_OPEN);
      double initSL=GVRead(PosKey(pid,"INITSL"),GVGet(tk,"INITSL",PositionGetDouble(POSITION_SL)));
      double unit=MathAbs(entry-initSL); if(unit<=0) continue;
      MqlTick t; if(!GetTickSafe(sym,t)) continue;
      double px=(bull?t.bid:t.ask);
      double move=(bull?px-entry:entry-px)/unit;
      double mfe=MathMax(0.0,move),mae=MathMax(0.0,-move);
      if(mfe>GVRead(PosKey(pid,"MFE"),0)) GVWrite(PosKey(pid,"MFE"),mfe);
      if(mae>GVRead(PosKey(pid,"MAE"),0)) GVWrite(PosKey(pid,"MAE"),mae);
   }
}

void HandleEntryDeal(ulong deal)
{
   if(!HistoryDealSelect(deal)) return;
   string sym=HistoryDealGetString(deal,DEAL_SYMBOL);
   ulong pid=(ulong)HistoryDealGetInteger(deal,DEAL_POSITION_ID);
   double actual=HistoryDealGetDouble(deal,DEAL_PRICE);
   double requested=GVRead(SymKey(sym,"PLAN_REF"),actual);
   double slip=(PointFor(sym)>0?MathAbs(actual-requested)/PointFor(sym):0);
   int kind=(int)GVRead(SymKey(sym,"PLAN_KIND"),SETUP_PULLBACK);
   GVWrite(PosKey(pid,"RISK"),GVRead(SymKey(sym,"PLAN_RISK"),0));
   GVWrite(PosKey(pid,"KIND"),kind); GVWrite(PosKey(pid,"ENTRY"),actual);
   GVWrite(PosKey(pid,"INITSL"),GVRead(SymKey(sym,"PLAN_SL"),0));
   GVWrite(PosKey(pid,"REQUESTED"),requested); GVWrite(PosKey(pid,"SLIP"),slip);
   GVWrite(PosKey(pid,"OPEN_TIME"),(double)TimeTradeServer());
   AppendJournal("ENTRY",sym,kind,deal,pid,requested,actual,slip,0,0,0,"execution recorded");
}

void HandleExitDeal(ulong deal)
{
   if(!HistoryDealSelect(deal)) return;
   ulong pid=(ulong)HistoryDealGetInteger(deal,DEAL_POSITION_ID);
   string sym=HistoryDealGetString(deal,DEAL_SYMBOL);
   double pnl=HistoryDealGetDouble(deal,DEAL_PROFIT)+HistoryDealGetDouble(deal,DEAL_COMMISSION)+HistoryDealGetDouble(deal,DEAL_SWAP);
   GVWrite(PosKey(pid,"REALIZED"),GVRead(PosKey(pid,"REALIZED"),0)+pnl);
   AppendJournal("EXIT_PART",sym,(int)GVRead(PosKey(pid,"KIND"),SETUP_PULLBACK),deal,pid,
                 GVRead(PosKey(pid,"REQUESTED"),0),HistoryDealGetDouble(deal,DEAL_PRICE),GVRead(PosKey(pid,"SLIP"),0),0,
                 GVRead(PosKey(pid,"MAE"),0),GVRead(PosKey(pid,"MFE"),0),"partial/final exit deal");
   if(PositionIdentifierOpen(pid)) return;
   if(GVRead(PosKey(pid,"FINAL"),0)>0.5) return;

   double risk=GVRead(PosKey(pid,"RISK"),0);
   double realized=GVRead(PosKey(pid,"REALIZED"),0);
   double R=(risk>0?realized/risk:0);
   int kind=(int)GVRead(PosKey(pid,"KIND"),SETUP_PULLBACK);
   double slip=GVRead(PosKey(pid,"SLIP"),0),mae=GVRead(PosKey(pid,"MAE"),0),mfe=GVRead(PosKey(pid,"MFE"),0);
   UpdateSetupStats(kind,R,slip,mae,mfe);
   MarkSignalCooldown(sym);
   GVWrite(PosKey(pid,"FINAL"),1);
   AppendJournal("CLOSED",sym,kind,deal,pid,GVRead(PosKey(pid,"REQUESTED"),0),HistoryDealGetDouble(deal,DEAL_PRICE),slip,R,mae,mfe,"position finalized");
}

void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result)
{
   if(trans.type!=TRADE_TRANSACTION_DEAL_ADD || trans.deal==0) return;
   if(!HistoryDealSelect(trans.deal)) return;
   if((long)HistoryDealGetInteger(trans.deal,DEAL_MAGIC)!=InpMagic) return;
   ENUM_DEAL_ENTRY e=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal,DEAL_ENTRY);
   if(e==DEAL_ENTRY_IN || e==DEAL_ENTRY_INOUT) HandleEntryDeal(trans.deal);
   if(e==DEAL_ENTRY_OUT || e==DEAL_ENTRY_OUT_BY || e==DEAL_ENTRY_INOUT) HandleExitDeal(trans.deal);
}

// ------------------------- Risk/statistics UI ------------------------
void DeleteRiskAnalyticsPanel()
{
   ObjectDelete(0,RISK_PANEL); ObjectDelete(0,RISK_TEXT); ObjectDelete(0,BTN_PAUSE);
}

void UpdateRiskAnalyticsPanel()
{
   if(!InpDrawDashboard) return;
   RefreshRiskSession();
   string kill=""; bool blocked=RiskKillSwitchActive(kill);
   string txt=StringFormat("RISK & PERFORMANCE\nPortfolio risk: %.2f%% / %.2f%%\nDaily loss: %.2f%% / %.2f%%\nDrawdown: %.2f%% / %.2f%%\nConsecutive losses: %d / %d\nState: %s\n\nPullback: %s\nBreakout: %s",
      CurrentPortfolioRiskPercent(),InpMaxPortfolioRiskPercent,DailyLossPercent(),InpDailyLossLimitPercent,
      EquityDrawdownPercent(),InpMaxEquityDrawdownPercent,ConsecutiveLosses(),InpMaxConsecutiveLosses,
      blocked?("BLOCKED - "+kill):"ACTIVE",SetupStatsText(SETUP_PULLBACK),SetupStatsText(SETUP_BREAKOUT_RETEST));

   if(ObjectFind(0,RISK_PANEL)<0) ObjectCreate(0,RISK_PANEL,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,RISK_PANEL,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,RISK_PANEL,OBJPROP_XDISTANCE,InpDashboardX);
   ObjectSetInteger(0,RISK_PANEL,OBJPROP_YDISTANCE,InpDashboardY+245);
   ObjectSetInteger(0,RISK_PANEL,OBJPROP_XSIZE,470); ObjectSetInteger(0,RISK_PANEL,OBJPROP_YSIZE,175);
   ObjectSetInteger(0,RISK_PANEL,OBJPROP_BGCOLOR,C'14,18,28'); ObjectSetInteger(0,RISK_PANEL,OBJPROP_COLOR,C'55,65,82');
   ObjectSetInteger(0,RISK_PANEL,OBJPROP_BACK,false);

   if(ObjectFind(0,RISK_TEXT)<0) ObjectCreate(0,RISK_TEXT,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,RISK_TEXT,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,RISK_TEXT,OBJPROP_XDISTANCE,InpDashboardX+12);
   ObjectSetInteger(0,RISK_TEXT,OBJPROP_YDISTANCE,InpDashboardY+255);
   ObjectSetInteger(0,RISK_TEXT,OBJPROP_FONTSIZE,9); ObjectSetInteger(0,RISK_TEXT,OBJPROP_COLOR,C'220,225,235');
   ObjectSetString(0,RISK_TEXT,OBJPROP_FONT,"Consolas"); ObjectSetString(0,RISK_TEXT,OBJPROP_TEXT,txt);

   if(ObjectFind(0,BTN_PAUSE)<0) ObjectCreate(0,BTN_PAUSE,OBJ_BUTTON,0,0,0);
   ObjectSetInteger(0,BTN_PAUSE,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,BTN_PAUSE,OBJPROP_XDISTANCE,InpDashboardX+330);
   ObjectSetInteger(0,BTN_PAUSE,OBJPROP_YDISTANCE,InpDashboardY+380);
   ObjectSetInteger(0,BTN_PAUSE,OBJPROP_XSIZE,125); ObjectSetInteger(0,BTN_PAUSE,OBJPROP_YSIZE,26);
   ObjectSetString(0,BTN_PAUSE,OBJPROP_TEXT,g_manualPaused?"RESUME TRADING":"PAUSE TRADING");
   ObjectSetInteger(0,BTN_PAUSE,OBJPROP_BGCOLOR,g_manualPaused?C'35,120,70':C'145,55,55');
   ObjectSetInteger(0,BTN_PAUSE,OBJPROP_COLOR,clrWhite);
   ChartRedraw();
}

// -------------------------- Lifecycle hooks --------------------------
void RiskRecoveryInit()
{
   RefreshRiskSession();
   InitDOMSubscriptions();
   InitONNX();
   RecoverOpenPositionState();
   RecoverPendingApprovals();
   UpdateRiskAnalyticsPanel();
}

void RiskRecoveryTimer()
{
   RefreshRiskSession();
   UpdateOpenTradeExcursions();
   PersistPendingApprovals();
   UpdateRiskAnalyticsPanel();
}

void RiskRecoveryShutdown()
{
   PersistPendingApprovals();
   ShutdownDOMSubscriptions();
   ShutdownONNX();
   DeleteRiskAnalyticsPanel();
}
