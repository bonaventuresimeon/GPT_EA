// ============================================================================
// GPT_EA Part 40 - Clock integrity, model degradation and deterministic fallback
// ============================================================================

input bool   InpUseClockDriftProtection          = true;
input int    InpClockOffsetDriftToleranceSeconds = 120;
input bool   InpAllowOneHourDSTOffsetShift       = true;
input bool   InpUseModelDegradationMonitor       = true;
input int    InpModelHealthMinSamples            = 10;
input double InpModelReducedTrustFailureRate     = 0.20;
input double InpModelDeterministicFailureRate    = 0.45;
input double InpModelReducedTrustRiskMultiplier  = 0.60;
input double InpModelDeterministicRiskMultiplier = 0.35;
input bool   InpAllowDeterministicEmergencyMode  = true;
input string InpModelHealthFile                  = "GPT_EA_ModelHealth.csv";

enum ModelTrustMode
{
   MODEL_TRUST_NORMAL=0,
   MODEL_TRUST_REDUCED=1,
   MODEL_TRUST_DETERMINISTIC_ONLY=2
};

string ModelTrustModeName(int mode)
{
   if(mode==MODEL_TRUST_REDUCED) return "REDUCED_TRUST";
   if(mode==MODEL_TRUST_DETERMINISTIC_ONLY) return "DETERMINISTIC_ONLY";
   return "NORMAL";
}

void EnsureModelHealthHeader()
{
   bool exists=FileIsExist(InpModelHealthFile,FILE_COMMON);
   int h=FileOpen(InpModelHealthFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(h==INVALID_HANDLE) return;
   if(!exists || FileSize(h)==0)
      FileWrite(h,"schema_version","time","mode","requests","failures","schema_failures","stale","provenance_failures",
         "contradictions","clock_offset_seconds","clock_drift_seconds","note");
   FileClose(h);
}

long CurrentServerGMTOffsetSeconds()
{
   datetime gmt=TimeGMT();
   datetime srv=TimeTradeServer();
   if(gmt<=0 || srv<=0) return 0;
   return (long)srv-(long)gmt;
}

bool ClockDriftAllows(string &why)
{
   why="";
   if(!InpUseClockDriftProtection){ why="clock-drift protection disabled"; return true; }
   long nowOffset=CurrentServerGMTOffsetSeconds();
   if(nowOffset==0){ why="clock offset unavailable"; return false; }
   string key=SysKey("CLOCK_OFFSET_BASE");
   long base=(long)GVRead(key,0);
   if(base==0)
   {
      GVWrite(key,(double)nowOffset);
      GVWrite(SysKey("CLOCK_OFFSET_UPDATED"),(double)TimeTradeServer());
      why=StringFormat("clock baseline established at %+d seconds",(int)nowOffset);
      return true;
   }
   long delta=nowOffset-base;
   long absDelta=(long)MathAbs((double)delta);
   if(absDelta<=MathMax(5,InpClockOffsetDriftToleranceSeconds))
   {
      why=StringFormat("clock offset %+d sec; drift %d sec",(int)nowOffset,(int)delta);
      return true;
   }
   bool dst=(InpAllowOneHourDSTOffsetShift && MathAbs((double)absDelta-3600.0)<=MathMax(30,InpClockOffsetDriftToleranceSeconds));
   if(dst)
   {
      GVWrite(key,(double)nowOffset);
      GVWrite(SysKey("CLOCK_OFFSET_UPDATED"),(double)TimeTradeServer());
      why=StringFormat("one-hour broker/DST offset shift accepted and baseline refreshed (%+d sec)",(int)nowOffset);
      return true;
   }
   why=StringFormat("CLOCK DRIFT BLOCK: broker-server/GMT offset changed by %d sec from baseline %+d to %+d",
                    (int)delta,(int)base,(int)nowOffset);
   return false;
}

int CurrentModelTrustMode(string &detail)
{
   double req=GVRead(SysKey("MODEL_REQ"),0);
   double fail=GVRead(SysKey("MODEL_FAIL"),0);
   double schema=GVRead(SysKey("MODEL_SCHEMA_FAIL"),0);
   double stale=GVRead(SysKey("MODEL_STALE"),0);
   double prov=GVRead(SysKey("MODEL_PROV_FAIL"),0);
   double contradictions=GVRead(SysKey("MODEL_CONTRADICTION"),0);
   double bad=fail+schema+stale+prov+contradictions;
   double rate=(req>0?bad/req:0);
   int mode=MODEL_TRUST_NORMAL;
   if(InpUseModelDegradationMonitor && req>=MathMax(1,InpModelHealthMinSamples))
   {
      if(rate>=InpModelDeterministicFailureRate) mode=MODEL_TRUST_DETERMINISTIC_ONLY;
      else if(rate>=InpModelReducedTrustFailureRate) mode=MODEL_TRUST_REDUCED;
   }
   detail=StringFormat("model health %s | requests %.0f bad %.0f rate %.1f%% | fail %.0f schema %.0f stale %.0f provenance %.0f disagreement %.0f",
      ModelTrustModeName(mode),req,bad,rate*100.0,fail,schema,stale,prov,contradictions);
   return mode;
}

bool DeterministicEmergencyStrategyAllowed(const string sym,StrategyClass c,string &why)
{
   why="";
   if(!InpAllowDeterministicEmergencyMode)
   { why="deterministic-only emergency mode disabled"; return false; }

   bool allowed=(c==STRATEGY_TREND_CONTINUATION ||
                 c==STRATEGY_RETRACEMENT_ENTRY ||
                 c==STRATEGY_RANGE_TRADE ||
                 c==STRATEGY_MEAN_REVERSION);
   if(!allowed)
   {
      why="strategy requires live model/news trust in deterministic-only mode";
      return false;
   }
   if(HighImpactEventWithin(sym,MathMax(60,InpStrategyNewsContextMinutes)))
   {
      why="high-impact event proximity blocks deterministic-only execution";
      return false;
   }
   why="strategy permitted by deterministic-only emergency policy away from high-impact events";
   return true;
}

bool ModelClockExecutionAllows(const TradeSetup &s,StrategyClass c,string &why)
{
   string clock="";
   if(!ClockDriftAllows(clock)){ why=clock; return false; }

   string health="";
   int mode=CurrentModelTrustMode(health);
   if(mode==MODEL_TRUST_DETERMINISTIC_ONLY)
   {
      string det="";
      if(!DeterministicEmergencyStrategyAllowed(s.symbol,c,det))
      { why=clock+" | "+health+" | "+det; return false; }
      why=clock+" | "+health+" | "+det;
      return true;
   }
   why=clock+" | "+health;
   return true;
}

double ModelTrustRiskMultiplier()
{
   string d="";
   int mode=CurrentModelTrustMode(d);
   if(mode==MODEL_TRUST_REDUCED) return MathMax(0.10,MathMin(1.0,InpModelReducedTrustRiskMultiplier));
   if(mode==MODEL_TRUST_DETERMINISTIC_ONLY) return MathMax(0.0,MathMin(1.0,InpModelDeterministicRiskMultiplier));
   return 1.0;
}

void WriteModelHealthSnapshot(const string note)
{
   EnsureModelHealthHeader();
   int h=FileOpen(InpModelHealthFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(h==INVALID_HANDLE) return;
   string detail=""; int mode=CurrentModelTrustMode(detail);
   long offset=CurrentServerGMTOffsetSeconds();
   long base=(long)GVRead(SysKey("CLOCK_OFFSET_BASE"),offset);
   FileSeek(h,0,SEEK_END);
   FileWrite(h,"model_health_v1",TimeToString(TimeTradeServer(),TIME_DATE|TIME_SECONDS),ModelTrustModeName(mode),
      DoubleToString(GVRead(SysKey("MODEL_REQ"),0),0),DoubleToString(GVRead(SysKey("MODEL_FAIL"),0),0),
      DoubleToString(GVRead(SysKey("MODEL_SCHEMA_FAIL"),0),0),DoubleToString(GVRead(SysKey("MODEL_STALE"),0),0),
      DoubleToString(GVRead(SysKey("MODEL_PROV_FAIL"),0),0),DoubleToString(GVRead(SysKey("MODEL_CONTRADICTION"),0),0),
      (string)offset,(string)(offset-base),note+" | "+detail);
   FileFlush(h); FileClose(h);
}

void ModelClockTrustInit()
{
   string q=""; ClockDriftAllows(q);
   WriteModelHealthSnapshot("initialization");
}

void ModelClockTrustTimer()
{
   static datetime last=0;
   datetime now=TimeTradeServer();
   if(last==0 || now-last>=300)
   {
      string q=""; ClockDriftAllows(q);
      WriteModelHealthSnapshot("periodic");
      last=now;
   }
}
