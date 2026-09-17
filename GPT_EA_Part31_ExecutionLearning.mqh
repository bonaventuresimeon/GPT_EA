// ============================================================================
// GPT_EA Part 31 - Execution-quality learning, calibration and strategy health
// ============================================================================

input bool   InpUseExecutionQualityLearning       = true;
input string InpExecutionLearningFile             = "GPT_EA_ExecutionLearningV2.csv";
input double InpExecutionEwmaAlpha                = 0.20;
input int    InpExecutionForecastMinSamples       = 5;
input double InpExecutionForecastRRBuffer         = 0.05;

input bool   InpUseConfidenceCalibration          = true;
input int    InpConfidenceCalibrationMinSamples   = 8;
input double InpConfidenceCalibrationPriorTrades  = 20.0;
input int    InpMinCalibratedConfidence           = 62;

input bool   InpUseStrategyDegradationDetector    = true;
input int    InpDegradationRecentTrades           = 12;
input int    InpDegradationMinTrades              = 8;
input double InpReducedRiskRecentAvgR             = 0.00;
input double InpReducedRiskRecentPF               = 0.90;
input double InpShadowRecentAvgR                  = -0.15;
input double InpShadowRecentPF                    = 0.75;
input double InpDisableRecentAvgR                 = -0.50;
input double InpDisableRecentPF                   = 0.50;

input bool   InpUseEventSpecificBehavior          = true;
input int    InpEventBehaviorWindowMinutes        = 60;
input int    InpEventBehaviorMinSamples           = 6;
input double InpEventBehaviorMinAvgR              = -0.05;
input double InpEventBehaviorMinPF                = 0.85;
input bool   InpBlockNegativeEventBehavior        = true;

input bool   InpUseMAEMFEResearch                 = true;
input bool   InpUseLearnedCandleExpiry            = true;
input int    InpLearnedExpiryMinSamples           = 8;
input double InpLearnedExpiryPercentile           = 0.75;
input int    InpLearnedExpiryMaxM15               = 12;

input bool   InpUseRegimeTransitionRisk           = true;
input int    InpRegimeTransitionCautionM15        = 2;
input double InpRegimeTransitionRiskMultiplier    = 0.60;

// Scheduled event categories used for contextual strategy evidence.
enum AdaptiveEventClass
{
   EVENT_NONE=0,
   EVENT_CPI=1,
   EVENT_PPI=2,
   EVENT_NFP_EMPLOYMENT=3,
   EVENT_FOMC_FED=4,
   EVENT_ECB=5,
   EVENT_BOE=6,
   EVENT_GDP=7,
   EVENT_PMI=8,
   EVENT_RETAIL_SALES=9,
   EVENT_SPEECH=10,
   EVENT_OTHER_HIGH_IMPACT=11
};

string AdaptiveEventName(int c)
{
   switch(c)
   {
      case EVENT_CPI: return "CPI/INFLATION";
      case EVENT_PPI: return "PPI";
      case EVENT_NFP_EMPLOYMENT: return "NFP/EMPLOYMENT";
      case EVENT_FOMC_FED: return "FOMC/FED";
      case EVENT_ECB: return "ECB";
      case EVENT_BOE: return "BOE";
      case EVENT_GDP: return "GDP";
      case EVENT_PMI: return "PMI";
      case EVENT_RETAIL_SALES: return "RETAIL_SALES";
      case EVENT_SPEECH: return "CENTRAL_BANK_SPEECH";
      case EVENT_OTHER_HIGH_IMPACT: return "OTHER_HIGH_IMPACT";
      default: return "NONE";
   }
}

int ClassifyEconomicEventName(string name)
{
   StringToUpper(name);
   if(StringFind(name,"CPI")>=0 || StringFind(name,"CONSUMER PRICE")>=0 || StringFind(name,"INFLATION")>=0) return EVENT_CPI;
   if(StringFind(name,"PPI")>=0 || StringFind(name,"PRODUCER PRICE")>=0) return EVENT_PPI;
   if(StringFind(name,"NONFARM")>=0 || StringFind(name,"NFP")>=0 || StringFind(name,"PAYROLL")>=0 ||
      StringFind(name,"EMPLOYMENT")>=0 || StringFind(name,"UNEMPLOYMENT")>=0 || StringFind(name,"JOBLESS")>=0) return EVENT_NFP_EMPLOYMENT;
   if(StringFind(name,"FOMC")>=0 || StringFind(name,"FEDERAL RESERVE")>=0 || StringFind(name,"FED ")>=0 || StringFind(name,"FED RATE")>=0) return EVENT_FOMC_FED;
   if(StringFind(name,"ECB")>=0 || StringFind(name,"EUROPEAN CENTRAL BANK")>=0) return EVENT_ECB;
   if(StringFind(name,"BOE")>=0 || StringFind(name,"BANK OF ENGLAND")>=0) return EVENT_BOE;
   if(StringFind(name,"GDP")>=0 || StringFind(name,"GROSS DOMESTIC")>=0) return EVENT_GDP;
   if(StringFind(name,"PMI")>=0 || StringFind(name,"PURCHASING MANAGER")>=0) return EVENT_PMI;
   if(StringFind(name,"RETAIL SALES")>=0) return EVENT_RETAIL_SALES;
   if(StringFind(name,"SPEECH")>=0 || StringFind(name,"TESTIMONY")>=0 || StringFind(name,"PRESS CONFERENCE")>=0 || StringFind(name,"REMARKS")>=0) return EVENT_SPEECH;
   return EVENT_OTHER_HIGH_IMPACT;
}

int CurrentAdaptiveEventClass(const string sym,string &eventName)
{
   eventName="";
   if(!InpUseEventSpecificBehavior || !InpUseEconomicCalendar || (bool)MQLInfoInteger(MQL_TESTER)) return EVENT_NONE;
   string ccys=RelatedCurrencies(sym); if(ccys=="") return EVENT_NONE;
   string a[]; int nc=StringSplit(ccys,',',a);
   datetime now=TimeTradeServer();
   int w=MathMax(5,InpEventBehaviorWindowMinutes);
   datetime from=now-w*60,to=now+w*60;
   long best=2147483647; int bestClass=EVENT_NONE;
   for(int c=0;c<nc;c++)
   {
      MqlCalendarValue vals[]; int n=CalendarValueHistory(vals,from,to,NULL,a[c]);
      for(int i=0;i<n;i++)
      {
         MqlCalendarEvent ev={}; if(!CalendarEventById(vals[i].event_id,ev)) continue;
         if(ev.importance!=CALENDAR_IMPORTANCE_HIGH) continue;
         long dist=(long)MathAbs((double)(vals[i].time-now));
         if(dist<best)
         {
            best=dist; eventName=ev.name; bestClass=ClassifyEconomicEventName(ev.name);
         }
      }
   }
   return bestClass;
}

int ConfidenceBucket(int raw)
{
   int c=MathMax(0,MathMin(100,raw));
   return (c/5)*5;
}

string ConfidenceBucketKey(int raw)
{
   return SysKey(StringFormat("CAL_CONF_%d",ConfidenceBucket(raw)));
}

int CalibratedConfidenceValue(int raw,string &detail)
{
   raw=MathMax(0,MathMin(100,raw));
   if(!InpUseConfidenceCalibration){ detail="confidence calibration disabled"; return raw; }
   string k=ConfidenceBucketKey(raw);
   double n=GVRead(k+"_N",0),wins=GVRead(k+"_WIN",0);
   if(n<InpConfidenceCalibrationMinSamples)
   {
      detail=StringFormat("confidence %d%% raw; calibration sample N %.0f developing",raw,n);
      return raw;
   }
   double prior=MathMax(1.0,InpConfidenceCalibrationPriorTrades);
   double p0=raw/100.0;
   double p=(wins+prior*p0)/(n+prior);
   int out=(int)MathRound(MathMax(0.0,MathMin(1.0,p))*100.0);
   detail=StringFormat("confidence raw %d%% -> calibrated %d%% from N %.0f observed win %.1f%%",raw,out,n,(n>0?wins/n*100.0:0));
   return out;
}

void ApplyConfidenceCalibration(TradeSetup &s,string &detail)
{
   int raw=s.confidence;
   int cal=CalibratedConfidenceValue(raw,detail);
   s.confidence=cal;
   if(InpUseConfidenceCalibration && cal<InpMinCalibratedConfidence)
      s.valid=false;
}

double EWMA(double oldValue,double newValue,double alpha)
{
   if(oldValue<=0) return newValue;
   double a=MathMax(0.01,MathMin(1.0,alpha));
   return a*newValue+(1.0-a)*oldValue;
}

int ExecutionSessionCode(const string sym)
{
   string s=AccurateSessionBucket();
   return StrategySessionCode(s);
}

double ExecutionSlippageForecastPoints(const string sym,StrategyClass c,string &detail)
{
   double dynamic=(double)DynamicSlippagePoints(sym);
   double sn=GVRead(SymKey(sym,"EXEC_N"),0);
   double s=GVRead(SymKey(sym,"EXEC_SLIP_EWMA_PTS"),0);
   int ses=ExecutionSessionCode(sym);
   double cs=GVRead(SysKey(StringFormat("EXEC_STRAT_%d_SLIP",(int)c)),0);
   double ss=GVRead(SysKey(StringFormat("EXEC_SESSION_%d_SLIP",ses)),0);
   double learned=0;
   if(sn>=InpExecutionForecastMinSamples) learned=MathMax(s,MathMax(cs,ss));
   double out=MathMax(dynamic,learned);
   detail=StringFormat("slippage forecast %.1f pts | dynamic %.1f | symbol EWMA %.1f N %.0f | strategy %.1f | session %.1f",
                       out,dynamic,s,sn,cs,ss);
   return out;
}

bool ExecutionForecastRRGate(const TradeSetup &s,StrategyClass c,string &why)
{
   string f=""; double slipPts=ExecutionSlippageForecastPoints(s.symbol,c,f);
   MqlTick t={}; if(!GetTickSafe(s.symbol,t)){ why="Execution forecast: no fresh tick."; return false; }
   double pt=PointFor(s.symbol); if(pt<=0){ why="Execution forecast: invalid point size."; return false; }
   double spread=MathMax(0.0,t.ask-t.bid),slip=slipPts*pt;
   double modeled=(s.bullish?s.preferred+spread+slip:s.preferred-spread-slip);
   double grossRisk=MathAbs(OneLotProfitBetween(s.symbol,s.bullish,modeled,s.sl));
   double reward=MathAbs(OneLotProfitBetween(s.symbol,s.bullish,modeled,s.tp2));
   double commission=EstimateCommissionPerLotRoundTurn(s.symbol);
   double rr=(grossRisk+commission>0?MathMax(0.0,reward-commission)/(grossRisk+commission):0);
   double floor=(c==STRATEGY_COUNTER_TREND_SCALP?MathMax(1.10,InpMinEffectiveRR-0.30):InpMinEffectiveRR)+InpExecutionForecastRRBuffer;
   why=StringFormat("execution forecast R:R %.2f vs %.2f floor | %s",rr,floor,f);
   return rr>=floor;
}

void RegisterAdaptiveExecutionRequest(const TradeSetup &s,double lots,double riskMoney)
{
   if(!InpUseExecutionQualityLearning) return;
   MqlTick t={}; GetTickSafe(s.symbol,t);
   double pt=PointFor(s.symbol);
   GVWrite(SymKey(s.symbol,"EXEC_ATTEMPTS"),GVRead(SymKey(s.symbol,"EXEC_ATTEMPTS"),0)+1);
   GVWrite(SymKey(s.symbol,"EXEC_REQ_MS"),(double)GetTickCount64());
   GVWrite(SymKey(s.symbol,"EXEC_REQ_TIME"),(double)TimeTradeServer());
   GVWrite(SymKey(s.symbol,"EXEC_EXPECTED"),s.preferred);
   GVWrite(SymKey(s.symbol,"EXEC_REQ_PX"),s.bullish?t.ask:t.bid);
   GVWrite(SymKey(s.symbol,"EXEC_REQ_SPREAD_PTS"),(pt>0?(t.ask-t.bid)/pt:0));
   GVWrite(SymKey(s.symbol,"EXEC_REQ_LOTS"),lots);
   GVWrite(SymKey(s.symbol,"EXEC_REQ_RISK"),riskMoney);
   GVWrite(SymKey(s.symbol,"EXEC_REQ_CONF"),s.confidence);
}

void RegisterAdaptiveExecutionFailure(const string sym,const string reason)
{
   if(!InpUseExecutionQualityLearning) return;
   GVWrite(SymKey(sym,"EXEC_FAILS"),GVRead(SymKey(sym,"EXEC_FAILS"),0)+1);
   Print(sym,": adaptive execution-learning failure captured - ",reason);
}

void EnsureExecutionLearningHeader()
{
   if(!InpUseExecutionQualityLearning) return;
   bool exists=FileIsExist(InpExecutionLearningFile,FILE_COMMON);
   int h=FileOpen(InpExecutionLearningFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(h==INVALID_HANDLE) return;
   if(!exists || FileSize(h)==0)
      FileWrite(h,"schema_version","time","event","broker","server","symbol","position_id","strategy","market_state","session","event_class",
                   "expected_entry","request_price","fill_price","spread_request_pts","spread_fill_pts","slippage_pts","latency_ms","lots","risk_money",
                   "raw_confidence","calibrated_confidence","realized_r","mae_r","mfe_r","tp1_m15","commission",
                   "release_id","strategy_engine","model_policy","config_fingerprint","symbol_fingerprint","strategy_config","note");
   FileClose(h);
}

void WriteExecutionLearningRow(const string eventName,const string sym,ulong pid,const string note,double realizedR=0)
{
   if(!InpUseExecutionQualityLearning) return;
   EnsureExecutionLearningHeader();
   int h=FileOpen(InpExecutionLearningFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(h==INVALID_HANDLE) return;
   FileSeek(h,0,SEEK_END);
   int cls=(int)GVRead(PosKey(pid,"STRATEGY"),GVRead(SymKey(sym,"PLAN_STRATEGY"),0));
   int state=(int)GVRead(PosKey(pid,"MARKET_STATE"),GVRead(SymKey(sym,"PLAN_STATE"),0));
   int ses=(int)GVRead(PosKey(pid,"EXEC_SESSION"),ExecutionSessionCode(sym));
   int ev=(int)GVRead(PosKey(pid,"EVENT_CLASS"),0);
   double commission=GVRead(PosKey(pid,"ACTUAL_COMMISSION"),0);
   FileWrite(h,"execution_learning_v2",TimeToString(TimeTradeServer(),TIME_DATE|TIME_SECONDS),eventName,
      AccountInfoString(ACCOUNT_COMPANY),AccountInfoString(ACCOUNT_SERVER),sym,(string)pid,
      StrategyClassName((StrategyClass)cls),MarketStateName((MarketStateClass)state),(string)ses,AdaptiveEventName(ev),
      DoubleToString(GVRead(PosKey(pid,"EXEC_EXPECTED"),0),DigitsFor(sym)),DoubleToString(GVRead(PosKey(pid,"EXEC_REQUEST_PX"),0),DigitsFor(sym)),
      DoubleToString(GVRead(PosKey(pid,"EXEC_FILL"),0),DigitsFor(sym)),DoubleToString(GVRead(PosKey(pid,"EXEC_SPREAD_REQ"),0),1),
      DoubleToString(GVRead(PosKey(pid,"EXEC_SPREAD_FILL"),0),1),DoubleToString(GVRead(PosKey(pid,"EXEC_SLIP_PTS"),0),1),
      DoubleToString(GVRead(PosKey(pid,"EXEC_LATENCY_MS"),0),0),DoubleToString(GVRead(PosKey(pid,"EXEC_LOTS"),0),2),
      DoubleToString(GVRead(PosKey(pid,"RISK"),0),2),DoubleToString(GVRead(PosKey(pid,"RAW_CONF"),0),0),
      DoubleToString(GVRead(PosKey(pid,"CAL_CONF"),0),0),DoubleToString(realizedR,3),
      DoubleToString(GVRead(PosKey(pid,"MAE_R"),0),3),DoubleToString(GVRead(PosKey(pid,"MFE_R"),0),3),
      DoubleToString(GVRead(PosKey(pid,"TP1_M15"),0),1),DoubleToString(commission,2),
      GPT_EA_REQUIRED_RELEASE_VALIDATION_ID,InpStrategyEngineVersion,InpModelPolicyVersion,CurrentConfigFingerprint(),
      (sym!=""?SymbolContractFingerprint(sym):""),StrategyConfigVersion((StrategyClass)cls),note);
   FileFlush(h); FileClose(h);
}

void PersistAdaptivePlanMetadata(const TradeSetup &s)
{
   string cal=""; int calibrated=CalibratedConfidenceValue(s.confidence,cal);
   string evName=""; int ev=CurrentAdaptiveEventClass(s.symbol,evName);
   GVWrite(SymKey(s.symbol,"PLAN_RAW_CONF"),s.confidence);
   GVWrite(SymKey(s.symbol,"PLAN_CAL_CONF"),calibrated);
   GVWrite(SymKey(s.symbol,"PLAN_EVENT_CLASS"),ev);
   GVWrite(SymKey(s.symbol,"PLAN_EXEC_SESSION"),ExecutionSessionCode(s.symbol));
   GVWrite(SymKey(s.symbol,"PLAN_EXPECTED_RR"),RealisticRiskReward(s).rr);
}

void RegisterAdaptiveExecutionFill(ulong ticket,const TradeSetup &s,double lots,double riskMoney)
{
   if(!InpUseExecutionQualityLearning || ticket==0 || !PositionSelectByTicket(ticket)) return;
   ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
   string sym=PositionGetString(POSITION_SYMBOL);
   double pt=PointFor(sym),fill=PositionGetDouble(POSITION_PRICE_OPEN);
   MqlTick t={}; GetTickSafe(sym,t);
   double req=GVRead(SymKey(sym,"EXEC_REQ_PX"),s.preferred);
   bool bull=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
   double slipPts=(pt>0?(bull?fill-req:req-fill)/pt:0);
   double latency=MathMax(0.0,(double)GetTickCount64()-GVRead(SymKey(sym,"EXEC_REQ_MS"),(double)GetTickCount64()));
   double spreadFill=(pt>0?(t.ask-t.bid)/pt:0);
   double spreadReq=GVRead(SymKey(sym,"EXEC_REQ_SPREAD_PTS"),spreadFill);
   StrategyClass c=CandidateStrategyForSymbol(sym);
   int ses=ExecutionSessionCode(sym);
   string evName=""; int ev=CurrentAdaptiveEventClass(sym,evName);
   string calText=""; int calibrated=CalibratedConfidenceValue(s.confidence,calText);

   GVWrite(PosKey(pid,"ADAPT_META"),1);
   GVWrite(PosKey(pid,"EXEC_EXPECTED"),s.preferred);
   GVWrite(PosKey(pid,"EXEC_REQUEST_PX"),req);
   GVWrite(PosKey(pid,"EXEC_FILL"),fill);
   GVWrite(PosKey(pid,"EXEC_SPREAD_REQ"),spreadReq);
   GVWrite(PosKey(pid,"EXEC_SPREAD_FILL"),spreadFill);
   GVWrite(PosKey(pid,"EXEC_SLIP_PTS"),slipPts);
   GVWrite(PosKey(pid,"EXEC_LATENCY_MS"),latency);
   GVWrite(PosKey(pid,"EXEC_LOTS"),lots);
   GVWrite(PosKey(pid,"RISK"),riskMoney);
   GVWrite(PosKey(pid,"RAW_CONF"),s.confidence);
   GVWrite(PosKey(pid,"CAL_CONF"),calibrated);
   GVWrite(PosKey(pid,"EVENT_CLASS"),ev);
   GVWrite(PosKey(pid,"EXEC_SESSION"),ses);
   GVWrite(PosKey(pid,"OPEN_TIME"),(double)PositionGetInteger(POSITION_TIME));
   GVWrite(PosKey(pid,"MAE_R"),0); GVWrite(PosKey(pid,"MFE_R"),0);

   double n=GVRead(SymKey(sym,"EXEC_N"),0)+1; GVWrite(SymKey(sym,"EXEC_N"),n);
   GVWrite(SymKey(sym,"EXEC_SLIP_EWMA_PTS"),EWMA(GVRead(SymKey(sym,"EXEC_SLIP_EWMA_PTS"),0),MathMax(0.0,slipPts),InpExecutionEwmaAlpha));
   GVWrite(SymKey(sym,"EXEC_SPREAD_EWMA_PTS"),EWMA(GVRead(SymKey(sym,"EXEC_SPREAD_EWMA_PTS"),0),spreadFill,InpExecutionEwmaAlpha));
   GVWrite(SymKey(sym,"EXEC_LATENCY_EWMA_MS"),EWMA(GVRead(SymKey(sym,"EXEC_LATENCY_EWMA_MS"),0),latency,InpExecutionEwmaAlpha));
   GVWrite(SysKey(StringFormat("EXEC_STRAT_%d_SLIP",(int)c)),EWMA(GVRead(SysKey(StringFormat("EXEC_STRAT_%d_SLIP",(int)c)),0),MathMax(0.0,slipPts),InpExecutionEwmaAlpha));
   GVWrite(SysKey(StringFormat("EXEC_SESSION_%d_SLIP",ses)),EWMA(GVRead(SysKey(StringFormat("EXEC_SESSION_%d_SLIP",ses)),0),MathMax(0.0,slipPts),InpExecutionEwmaAlpha));
   WriteExecutionLearningRow("FILL",sym,pid,calText,0);
}

void UpdateOpenMAEMFE()
{
   if(!InpUseMAEMFEResearch) return;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
      double rNow=0,R=0,entry=0,px=0; bool bull=true;
      if(!CurrentPositionR(tk,rNow,R,entry,px,bull) || R<=0) continue;
      if(rNow>GVRead(PosKey(pid,"MFE_R"),0)) GVWrite(PosKey(pid,"MFE_R"),rNow);
      double mae=MathMax(0.0,-rNow);
      if(mae>GVRead(PosKey(pid,"MAE_R"),0)) GVWrite(PosKey(pid,"MAE_R"),mae);
      datetime open=(datetime)GVRead(PosKey(pid,"OPEN_TIME"),PositionGetInteger(POSITION_TIME));
      if(PositionFlag(pid,tk,"TP1PARTIAL") && GVRead(PosKey(pid,"TP1_M15"),0)<=0)
      {
         datetime tp1=(datetime)GVRead(PosKey(pid,"TP1_TIME"),0);
         if(tp1>0 && open>0) GVWrite(PosKey(pid,"TP1_M15"),MathMax(0.0,(tp1-open)/900.0));
      }
   }
}

void UpdateConfidenceCalibrationBucket(int raw,double R)
{
   string k=ConfidenceBucketKey(raw);
   UpdateStrategyBucket(k,R);
}

void UpdateExpiryHistogram(StrategyClass c,double tp1M15)
{
   if(tp1M15<=0) return;
   int b=(int)MathCeil(tp1M15); b=MathMax(1,MathMin(InpLearnedExpiryMaxM15,b));
   string k=SysKey(StringFormat("EXPIRY_%d_B%d",(int)c,b));
   GVWrite(k,GVRead(k,0)+1);
   GVWrite(SysKey(StringFormat("EXPIRY_%d_N",(int)c)),GVRead(SysKey(StringFormat("EXPIRY_%d_N",(int)c)),0)+1);
}

int LearnedStrategyExpiryM15(StrategyClass c,int fallback,string &detail)
{
   detail="learned expiry unavailable";
   if(!InpUseLearnedCandleExpiry || c==STRATEGY_NO_TRADE) return fallback;
   double n=GVRead(SysKey(StringFormat("EXPIRY_%d_N",(int)c)),0);
   if(n<InpLearnedExpiryMinSamples)
   { detail=StringFormat("learned expiry sample %.0f/%d; fallback %d",n,InpLearnedExpiryMinSamples,fallback); return fallback; }
   double target=n*MathMax(0.50,MathMin(0.95,InpLearnedExpiryPercentile)),cum=0;
   int chosen=fallback;
   for(int b=1;b<=InpLearnedExpiryMaxM15;b++)
   {
      cum+=GVRead(SysKey(StringFormat("EXPIRY_%d_B%d",(int)c,b)),0);
      if(cum>=target){ chosen=b; break; }
   }
   chosen=MathMax(1,MathMin(InpLearnedExpiryMaxM15,chosen));
   detail=StringFormat("learned %.0fth percentile expiry %d M15 from N %.0f",InpLearnedExpiryPercentile*100.0,chosen,n);
   return chosen;
}

bool EventSpecificBehaviorAllows(const string sym,StrategyClass c,string &why)
{
   why="No scheduled event-specific restriction.";
   if(!InpUseEventSpecificBehavior || c==STRATEGY_NO_TRADE) return true;
   string eventName=""; int ev=CurrentAdaptiveEventClass(sym,eventName);
   if(ev==EVENT_NONE) return true;
   string k=SysKey(StringFormat("EVENT_%d_STRAT_%d",ev,(int)c));
   double n=0,wr=0,avg=0,pf=0,dd=0,ml=0; StrategyBucketMetrics(k,n,wr,avg,pf,dd,ml);
   why=StringFormat("%s / %s historical context N %.0f win %.1f%% avg %.2fR PF %.2f",
                    AdaptiveEventName(ev),StrategyClassName(c),n,wr,avg,pf);
   if(n<InpEventBehaviorMinSamples){ why+=" | developing sample"; return true; }
   bool ok=(avg>=InpEventBehaviorMinAvgR && pf>=InpEventBehaviorMinPF);
   if(!ok && InpBlockNegativeEventBehavior){ why+=" | BLOCK"; return false; }
   why+=(ok?" | PASS":" | WATCH");
   return true;
}

void CollectRecentStrategyRs(StrategyClass c,double &arr[])
{
   ArrayResize(arr,0);
   datetime now=TimeTradeServer(),from=now-MathMax(10,InpStrategyHistoryLookbackDays)*86400;
   if(!HistorySelect(from,now)) return;
   ulong pids[]; datetime closes[];
   int total=HistoryDealsTotal();
   for(int i=0;i<total;i++)
   {
      ulong d=HistoryDealGetTicket(i); if(d==0 || (long)HistoryDealGetInteger(d,DEAL_MAGIC)!=InpMagic) continue;
      ENUM_DEAL_ENTRY e=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(d,DEAL_ENTRY);
      if(e!=DEAL_ENTRY_OUT && e!=DEAL_ENTRY_OUT_BY && e!=DEAL_ENTRY_INOUT) continue;
      ulong pid=(ulong)HistoryDealGetInteger(d,DEAL_POSITION_ID);
      if((int)GVRead(PosKey(pid,"STRATEGY"),0)!=(int)c || PositionIdentifierOpen(pid)) continue;
      datetime tm=(datetime)HistoryDealGetInteger(d,DEAL_TIME);
      int at=-1; for(int j=0;j<ArraySize(pids);j++) if(pids[j]==pid){ at=j; break; }
      if(at<0){ int n=ArraySize(pids); ArrayResize(pids,n+1); ArrayResize(closes,n+1); pids[n]=pid; closes[n]=tm; }
      else if(tm>closes[at]) closes[at]=tm;
   }
   for(int i=0;i<ArraySize(pids)-1;i++) for(int j=i+1;j<ArraySize(pids);j++) if(closes[j]<closes[i])
   { datetime tt=closes[i]; closes[i]=closes[j]; closes[j]=tt; ulong pp=pids[i]; pids[i]=pids[j]; pids[j]=pp; }
   int start=MathMax(0,ArraySize(pids)-MathMax(1,InpDegradationRecentTrades));
   for(int i=start;i<ArraySize(pids);i++)
   {
      double risk=GVRead(PosKey(pids[i],"RISK"),0); if(risk<=0) continue;
      int n=ArraySize(arr); ArrayResize(arr,n+1); arr[n]=StrategyPositionRealized(pids[i])/risk;
   }
}

void StrategyRecentMetrics(StrategyClass c,double &n,double &avg,double &pf)
{
   double a[]; CollectRecentStrategyRs(c,a); n=ArraySize(a); avg=0; pf=0;
   double pos=0,neg=0,sum=0;
   for(int i=0;i<ArraySize(a);i++){ sum+=a[i]; if(a[i]>0) pos+=a[i]; else if(a[i]<0) neg+=-a[i]; }
   if(n>0) avg=sum/n;
   pf=(neg>0?pos/neg:(pos>0?99.0:0.0));
}

void RefreshStrategyHealthModes()
{
   if(!InpUseStrategyDegradationDetector) return;
   for(int ci=1;ci<=9;ci++)
   {
      StrategyClass c=(StrategyClass)ci;
      double n=0,avg=0,pf=0; StrategyRecentMetrics(c,n,avg,pf);
      int mode=ADAPTIVE_MODE_ACTIVE; double riskMult=1.0;
      if(n>=InpDegradationMinTrades)
      {
         if(avg<=InpDisableRecentAvgR && pf<InpDisableRecentPF){ mode=ADAPTIVE_MODE_DISABLED; riskMult=0; }
         else if(avg<=InpShadowRecentAvgR || pf<InpShadowRecentPF){ mode=ADAPTIVE_MODE_SHADOW; riskMult=0; }
         else if(avg<InpReducedRiskRecentAvgR || pf<InpReducedRiskRecentPF){ mode=ADAPTIVE_MODE_REDUCED_RISK; riskMult=0.50; }
      }
      GVWrite(SysKey(StringFormat("HEALTH_MODE_%d",ci)),mode);
      GVWrite(SysKey(StringFormat("HEALTH_RISK_MULT_%d",ci)),riskMult);
      GVWrite(SysKey(StringFormat("HEALTH_RECENT_N_%d",ci)),n);
      GVWrite(SysKey(StringFormat("HEALTH_RECENT_AVG_%d",ci)),avg);
      GVWrite(SysKey(StringFormat("HEALTH_RECENT_PF_%d",ci)),pf);
   }
}

void RefreshRegimeTransition(const string sym)
{
   if(!InpUseRegimeTransitionRisk) return;
   StrategySnapshot x; BuildStrategySnapshot(sym,x);
   int prev=(int)GVRead(SymKey(sym,"REGIME_STATE_PREV"),STATE_UNKNOWN);
   datetime changed=(datetime)GVRead(SymKey(sym,"REGIME_CHANGED_TIME"),0);
   if(prev==STATE_UNKNOWN)
   {
      GVWrite(SymKey(sym,"REGIME_STATE_PREV"),(int)x.state);
      GVWrite(SymKey(sym,"REGIME_CHANGED_TIME"),(double)TimeTradeServer());
      GVWrite(SymKey(sym,"REGIME_RISK_MULT"),1.0);
      return;
   }
   if(prev!=(int)x.state)
   {
      GVWrite(SymKey(sym,"REGIME_STATE_PREV"),(int)x.state);
      GVWrite(SymKey(sym,"REGIME_FROM_STATE"),prev);
      GVWrite(SymKey(sym,"REGIME_CHANGED_TIME"),(double)TimeTradeServer());
      GVWrite(SymKey(sym,"REGIME_RISK_MULT"),InpRegimeTransitionRiskMultiplier);
      return;
   }
   int bars=(changed>0?BarsSince(sym,PERIOD_M15,changed):999);
   GVWrite(SymKey(sym,"REGIME_RISK_MULT"),(bars<=InpRegimeTransitionCautionM15?InpRegimeTransitionRiskMultiplier:1.0));
}

string RegimeTransitionText(const string sym)
{
   int from=(int)GVRead(SymKey(sym,"REGIME_FROM_STATE"),STATE_UNKNOWN);
   int to=(int)GVRead(SymKey(sym,"REGIME_STATE_PREV"),STATE_UNKNOWN);
   datetime tm=(datetime)GVRead(SymKey(sym,"REGIME_CHANGED_TIME"),0);
   double m=GVRead(SymKey(sym,"REGIME_RISK_MULT"),1.0);
   if(from==STATE_UNKNOWN || tm<=0) return "Regime transition: no established transition history.";
   return StringFormat("Regime transition: %s -> %s | changed %d M15 bars ago | risk x%.2f",
      MarketStateName((MarketStateClass)from),MarketStateName((MarketStateClass)to),BarsSince(sym,PERIOD_M15,tm),m);
}

void FinalizeAdaptiveLearningHistory()
{
   datetime now=TimeTradeServer(),from=now-MathMax(10,InpStrategyHistoryLookbackDays)*86400;
   if(!HistorySelect(from,now)) return;
   int total=HistoryDealsTotal();
   for(int i=MathMax(0,total-800);i<total;i++)
   {
      ulong d=HistoryDealGetTicket(i); if(d==0 || (long)HistoryDealGetInteger(d,DEAL_MAGIC)!=InpMagic) continue;
      ENUM_DEAL_ENTRY e=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(d,DEAL_ENTRY);
      if(e!=DEAL_ENTRY_OUT && e!=DEAL_ENTRY_OUT_BY && e!=DEAL_ENTRY_INOUT) continue;
      ulong pid=(ulong)HistoryDealGetInteger(d,DEAL_POSITION_ID);
      if(PositionIdentifierOpen(pid) || GVRead(PosKey(pid,"ADAPT_FINAL"),0)>0.5 || GVRead(PosKey(pid,"ADAPT_META"),0)<0.5) continue;
      int cls=(int)GVRead(PosKey(pid,"STRATEGY"),0); if(cls<=0) continue;
      double risk=GVRead(PosKey(pid,"RISK"),0); if(risk<=0) continue;
      double pnl=StrategyPositionRealized(pid),R=pnl/risk;
      int raw=(int)GVRead(PosKey(pid,"RAW_CONF"),0);
      int ev=(int)GVRead(PosKey(pid,"EVENT_CLASS"),0);
      double tp1=GVRead(PosKey(pid,"TP1_M15"),0);
      if(raw>0) UpdateConfidenceCalibrationBucket(raw,R);
      if(ev>0) UpdateStrategyBucket(SysKey(StringFormat("EVENT_%d_STRAT_%d",ev,cls)),R);
      if(tp1>0) UpdateExpiryHistogram((StrategyClass)cls,tp1);
      string maeKey=SysKey(StringFormat("MAE_MFE_%d",cls));
      GVWrite(maeKey+"_N",GVRead(maeKey+"_N",0)+1);
      GVWrite(maeKey+"_MAE",GVRead(maeKey+"_MAE",0)+GVRead(PosKey(pid,"MAE_R"),0));
      GVWrite(maeKey+"_MFE",GVRead(maeKey+"_MFE",0)+GVRead(PosKey(pid,"MFE_R"),0));

      double commission=0;
      if(HistorySelectByPosition(pid))
      {
         int nd=HistoryDealsTotal();
         for(int j=0;j<nd;j++){ ulong dd=HistoryDealGetTicket(j); if(dd>0) commission+=MathAbs(HistoryDealGetDouble(dd,DEAL_COMMISSION)); }
      }
      GVWrite(PosKey(pid,"ACTUAL_COMMISSION"),commission);
      string sym=HistoryDealGetString(d,DEAL_SYMBOL);
      WriteExecutionLearningRow("CLOSED",sym,pid,"post-trade learning finalized",R);
      GVWrite(PosKey(pid,"ADAPT_FINAL"),1);
   }
}

bool AdaptiveExecutionLearningAllows(const TradeSetup &s,string &why)
{
   StrategyClass c=CandidateStrategyForSymbol(s.symbol);
   string event=""; if(!EventSpecificBehaviorAllows(s.symbol,c,event)){ why=event; return false; }
   string rr=""; if(!ExecutionForecastRRGate(s,c,rr)){ why=rr; return false; }
   why=event+" | "+rr;
   return true;
}

string ExecutionLearningSummary(const TradeSetup &s)
{
   StrategyClass c=CandidateStrategyForSymbol(s.symbol);
   string cf="",sl="",ev="",exp="";
   int cal=CalibratedConfidenceValue(s.confidence,cf);
   double forecast=ExecutionSlippageForecastPoints(s.symbol,c,sl);
   bool eventOK=EventSpecificBehaviorAllows(s.symbol,c,ev);
   int learned=LearnedStrategyExpiryM15(c,s.expiryM15,exp);
   string k=SysKey(StringFormat("MAE_MFE_%d",(int)c));
   double n=GVRead(k+"_N",0),mae=(n>0?GVRead(k+"_MAE",0)/n:0),mfe=(n>0?GVRead(k+"_MFE",0)/n:0);
   return StringFormat("Execution learning: calibrated confidence %d%% | slip forecast %.1f pts | learned expiry %d M15 | MAE/MFE avg %.2fR/%.2fR N %.0f | event %s | %s",
      cal,forecast,learned,mae,mfe,n,eventOK?"PASS":"BLOCK",RegimeTransitionText(s.symbol));
}

void ExecutionLearningInit()
{
   EnsureExecutionLearningHeader();
   RefreshStrategyHealthModes();
   for(int i=0;i<ArraySize(g_symbols);i++) if(g_symbols[i]!="") RefreshRegimeTransition(g_symbols[i]);
   FinalizeAdaptiveLearningHistory();
   Print("GPT_EA execution-quality learning initialized.");
}

void ExecutionLearningTimer()
{
   UpdateOpenMAEMFE();
   FinalizeAdaptiveLearningHistory();
   RefreshStrategyHealthModes();
   for(int i=0;i<ArraySize(g_symbols);i++) if(g_symbols[i]!="") RefreshRegimeTransition(g_symbols[i]);
}
