// ============================================================================
// GPT_EA Part 39 - Data integrity versioning, strategy registry and quarantine
// ============================================================================
// Prevents analytics from mixing materially different strategy/config/runtime
// generations and keeps operationally corrupted samples out of learning.

input bool   InpUseDataIntegrityVersioning      = true;
input bool   InpUseLearningQuarantine           = true;
input string InpDataIntegrityFile               = "GPT_EA_DataIntegrity.csv";
input string InpLearningQuarantineFile          = "GPT_EA_QuarantinedLearning.csv";
input string InpStrategyConfigRegistryFile       = "GPT_EA_StrategyConfigRegistry.csv";
input string InpStrategyEngineVersion           = "strategy_engine_r6_hardening_1";
input string InpModelPolicyVersion              = "model_policy_r6_hardening_1";
input bool   InpQuarantineManualIntervention    = true;
input bool   InpQuarantineBrokerAnomaly         = true;
input bool   InpQuarantineConnectionAnomaly     = true;
input bool   InpQuarantineChaosSamples          = true;
input bool   InpQuarantineStorageFailure        = true;
input bool   InpResetLearningOnGenerationChange  = true;

int IntegrityTextHash(const string text)
{
   long h=2166136261;
   for(int i=0;i<StringLen(text);i++)
   {
      h=(h ^ StringGetCharacter(text,i))*16777619;
      h%=2147483647;
   }
   if(h<0) h=-h;
   return (int)h;
}

string StrategyConfigVersion(StrategyClass c)
{
   switch(c)
   {
      case STRATEGY_TREND_CONTINUATION: return "trend-v1";
      case STRATEGY_RETRACEMENT_ENTRY: return "retracement-v1";
      case STRATEGY_COUNTER_TREND_SCALP: return "counter-scalp-v1";
      case STRATEGY_COUNTER_TREND_SWING: return "counter-swing-v1";
      case STRATEGY_POTENTIAL_REVERSAL: return "reversal-v1";
      case STRATEGY_BREAKOUT: return "breakout-v2-direct";
      case STRATEGY_BREAKOUT_RETEST: return "breakout-retest-v1";
      case STRATEGY_RANGE_TRADE: return "range-v1";
      case STRATEGY_MEAN_REVERSION: return "mean-reversion-v1";
      default: return "no-strategy";
   }
}

string CurrentSensitiveConfigText()
{
   string cfg=StringFormat(
      "risk=%.4f|eq=%d|approval=%d|exec=%d|maxpos=%d|minconf=%d|minrr=%.4f|spread=%.4f|slip=%d|"
      "fast=%d|slow=%d|rsi=%d|atr=%d|swing=%d|pbexp=%d|brexp=%d|tp1=%.2f|be=%d|"
      "news=%d|nb=%d|na=%d|yield=%d|directbo=%d|bovol=%.3f|boadx=%.3f|bozone=%.3f|"
      "portfolio=%d|corr=%.3f|maxcorr=%.3f|maxmacro=%.3f|quality=%d|minmult=%.3f|maxmult=%.3f|"
      "trail=%.3f|lock1=%.3f:%.3f|lock2=%.3f:%.3f|api_mode=%d|proxy=%s|https=%d|"
      "model=%s|policy=%s|symbols=%s",
      InpRiskPercent,InpUseEquity?1:0,InpRequireApproval?1:0,InpEnableApprovedExecution?1:0,InpMaxPositionsPerSymbol,
      InpMinConfidence,InpMinEffectiveRR,InpMaxSpreadATRFrac,InpMaxSlippagePoints,
      InpFastEMA,InpSlowEMA,InpRSIPeriod,InpATRPeriod,InpSwingBars,InpPullbackExpiryM15,InpBreakoutExpiryM15,
      InpPartialAtTP1Percent,InpMoveSLToBEAfterTP1?1:0,
      InpUseEconomicCalendar?1:0,InpNewsBlockBeforeMinutes,InpNewsBlockAfterMinutes,
      InpUseYieldShockFilter?1:0,InpAllowDirectBreakoutExecution?1:0,InpDirectBreakoutMinVolumeRatio,
      InpDirectBreakoutMinADX,InpDirectBreakoutZoneATR,
      InpUseAdaptivePortfolioEngine?1:0,InpCorrelationRiskThreshold,InpMaxCorrelationWeightedRiskPercent,
      InpMaxMacroFactorRiskPercent,InpUseDynamicQualitySizing?1:0,InpMinAdaptiveRiskMultiplier,InpMaxAdaptiveRiskMultiplier,
      InpTrailStartR,InpProfitLockTriggerR,InpProfitLockR,InpStrongLockTriggerR,InpStrongLockR,
      (int)InpAPITransportMode,InpAPIProxyEndpoint,InpAPIRequireHTTPS?1:0,
      InpOpenAIModel,InpModelPolicyVersion,InpSymbols);

   cfg+=StringFormat(
      "|clock=%d:%d:%d|modelhealth=%d:%d:%.4f:%.4f:%.3f:%.3f:det%d|"
      "stress=%d:%.3f:idx%.3f:fx%.3f:metal%.3f:energy%.3f:crypto%.3f:other%.3f|"
      "macro=%d:usd%.3f:yld%.1f:yidx%.3f:ygold%.3f:ycrypto%.3f:riskoff%.3f:vol%.3f:gap%.3f|"
      "gapgate=%d:%.3f|margingate=%d:%.1f|halflife=%d|latency=%d:%.3f|"
      "webfresh=%d:%d:%d:primary%d:risk%d:%d|"
      "quarantine=%d:%d:%d:%d:%d:reset%d|chaos=%d:%d:%d",
      InpUseClockDriftProtection?1:0,InpClockOffsetDriftToleranceSeconds,InpAllowOneHourDSTOffsetShift?1:0,
      InpUseModelDegradationMonitor?1:0,InpModelHealthMinSamples,InpModelReducedTrustFailureRate,
      InpModelDeterministicFailureRate,InpModelReducedTrustRiskMultiplier,InpModelDeterministicRiskMultiplier,
      InpAllowDeterministicEmergencyMode?1:0,
      InpUsePortfolioScenarioStress?1:0,InpMaxScenarioStressLossPctEquity,InpStressIndexShockPct,InpStressFXShockPct,
      InpStressMetalShockPct,InpStressEnergyShockPct,InpStressCryptoShockPct,InpStressOtherShockPct,
      InpUseMacroScenarioStress?1:0,InpStressUSDStrengthPct,InpStressYieldShockBps,InpStressYieldIndexEffectPct,
      InpStressYieldGoldEffectPct,InpStressYieldCryptoEffectPct,InpStressEquityRiskOffPct,
      InpStressVolatilityIndexDropPct,InpStressCorrelatedGapMultiplier,
      InpUseGapRiskSizingGate?1:0,InpMaxGapLossMultipleOfPlannedRisk,
      InpUseMarginStressGate?1:0,InpMinimumStressedMarginLevelPct,
      InpUseDecisionHalfLife?1:0,InpUseExecutionLatencyBudget?1:0,InpMaxLatencyBudgetFraction,
      InpWebIntelMaxAsOfAgeMinutes,InpWebIntelMaxFutureSkewSeconds,InpWebIntelMinAnnotationURLs,
      InpRequirePrimarySourceForHighRisk?1:0,InpWebIntelRiskWatchScore,InpWebIntelRiskBlockScore,
      InpQuarantineManualIntervention?1:0,InpQuarantineBrokerAnomaly?1:0,InpQuarantineConnectionAnomaly?1:0,
      InpQuarantineChaosSamples?1:0,InpQuarantineStorageFailure?1:0,InpResetLearningOnGenerationChange?1:0,
      InpEnableChaosFaultInjection?1:0,InpChaosFaultScenario,InpChaosOneShot?1:0);

   cfg+=LateResilienceConfigText();
   return cfg;
}

string CurrentConfigFingerprint()
{
   return StringFormat("%08X",IntegrityTextHash(CurrentSensitiveConfigText()));
}

string SymbolContractFingerprint(const string sym)
{
   string raw=StringFormat("%s|%d|%.10f|%.10f|%.4f|%.4f|%.4f|%.4f|%d|%d|%I64d",
      sym,(int)SymbolInfoInteger(sym,SYMBOL_DIGITS),SymbolInfoDouble(sym,SYMBOL_POINT),
      SymbolInfoDouble(sym,SYMBOL_TRADE_TICK_SIZE),SymbolInfoDouble(sym,SYMBOL_TRADE_TICK_VALUE),
      SymbolInfoDouble(sym,SYMBOL_TRADE_CONTRACT_SIZE),SymbolInfoDouble(sym,SYMBOL_VOLUME_MIN),
      SymbolInfoDouble(sym,SYMBOL_VOLUME_STEP),(int)SymbolInfoInteger(sym,SYMBOL_TRADE_STOPS_LEVEL),
      (int)SymbolInfoInteger(sym,SYMBOL_TRADE_FREEZE_LEVEL),SymbolInfoInteger(sym,SYMBOL_TRADE_CALC_MODE));
   return StringFormat("%08X",IntegrityTextHash(raw));
}

void EnsureDataIntegrityHeader()
{
   if(!InpUseDataIntegrityVersioning) return;
   bool exists=FileIsExist(InpDataIntegrityFile,FILE_COMMON);
   int h=FileOpen(InpDataIntegrityFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(h==INVALID_HANDLE) return;
   if(!exists || FileSize(h)==0)
      FileWrite(h,"schema_version","time","event","release_id","strategy_engine","model_policy",
         "config_fingerprint","symbol","symbol_fingerprint","strategy","strategy_config","position_id","note");
   FileClose(h);
}

void WriteDataIntegrityRow(const string eventName,const string sym,StrategyClass c,ulong pid,const string note)
{
   if(!InpUseDataIntegrityVersioning) return;
   EnsureDataIntegrityHeader();
   int h=FileOpen(InpDataIntegrityFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(h==INVALID_HANDLE) return;
   FileSeek(h,0,SEEK_END);
   FileWrite(h,"data_integrity_v1",TimeToString(TimeTradeServer(),TIME_DATE|TIME_SECONDS),eventName,
      GPT_EA_REQUIRED_RELEASE_VALIDATION_ID,InpStrategyEngineVersion,InpModelPolicyVersion,CurrentConfigFingerprint(),
      sym,(sym!=""?SymbolContractFingerprint(sym):""),StrategyClassName(c),StrategyConfigVersion(c),(string)pid,note);
   FileFlush(h); FileClose(h);
}

void EnsureLearningQuarantineHeader()
{
   if(!InpUseLearningQuarantine) return;
   bool exists=FileIsExist(InpLearningQuarantineFile,FILE_COMMON);
   int h=FileOpen(InpLearningQuarantineFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(h==INVALID_HANDLE) return;
   if(!exists || FileSize(h)==0)
      FileWrite(h,"schema_version","time","position_id","symbol","strategy","release_id","config_fingerprint",
         "symbol_fingerprint","reason","manual","broker_anomaly","connection_anomaly","chaos","storage");
   FileClose(h);
}

void MarkLearningQuarantine(ulong pid,const string sym,const string reason)
{
   if(pid==0) return;
   GVWrite(PosKey(pid,"LEARN_QUARANTINE"),1);
   GVWrite(PosKey(pid,"LEARN_QUARANTINE_HASH"),IntegrityTextHash(reason));
   WriteDataIntegrityRow("QUARANTINE",sym,(StrategyClass)(int)GVRead(PosKey(pid,"STRATEGY"),0),pid,reason);
   if(!InpUseLearningQuarantine) return;
   EnsureLearningQuarantineHeader();
   int h=FileOpen(InpLearningQuarantineFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(h==INVALID_HANDLE) return;
   FileSeek(h,0,SEEK_END);
   StrategyClass c=(StrategyClass)(int)GVRead(PosKey(pid,"STRATEGY"),0);
   FileWrite(h,"learning_quarantine_v1",TimeToString(TimeTradeServer(),TIME_DATE|TIME_SECONDS),(string)pid,sym,
      StrategyClassName(c),GPT_EA_REQUIRED_RELEASE_VALIDATION_ID,CurrentConfigFingerprint(),
      (sym!=""?SymbolContractFingerprint(sym):""),reason,
      GVRead(PosKey(pid,"MANUAL_INTERVENTION"),0)>0.5?"1":"0",
      GVRead(PosKey(pid,"BROKER_ANOMALY"),0)>0.5?"1":"0",
      GVRead(PosKey(pid,"CONNECTION_ANOMALY"),0)>0.5?"1":"0",
      GVRead(PosKey(pid,"CHAOS_SAMPLE"),0)>0.5?"1":"0",
      GVRead(PosKey(pid,"STORAGE_ANOMALY"),0)>0.5?"1":"0");
   FileFlush(h); FileClose(h);
}

bool LearningSampleShouldQuarantine(ulong pid,const string sym,string &why)
{
   why="";
   if(!InpUseLearningQuarantine) return false;
   if(GVRead(PosKey(pid,"LEARN_QUARANTINE"),0)>0.5){ why="previously quarantined"; return true; }
   if(InpQuarantineManualIntervention && GVRead(PosKey(pid,"MANUAL_INTERVENTION"),0)>0.5)
   { why="manual/mobile/web intervention"; return true; }
   if(InpQuarantineBrokerAnomaly && GVRead(PosKey(pid,"BROKER_ANOMALY"),0)>0.5)
   { why="broker/execution anomaly"; return true; }
   if(InpQuarantineConnectionAnomaly && GVRead(PosKey(pid,"CONNECTION_ANOMALY"),0)>0.5)
   { why="connection/quote anomaly"; return true; }
   if(InpQuarantineChaosSamples && GVRead(PosKey(pid,"CHAOS_SAMPLE"),0)>0.5)
   { why="fault-injection sample"; return true; }
   if(InpQuarantineStorageFailure && GVRead(PosKey(pid,"STORAGE_ANOMALY"),0)>0.5)
   { why="critical storage anomaly"; return true; }

   double storedCfg=GVRead(PosKey(pid,"CONFIG_HASH"),0);
   if(storedCfg>0 && (int)storedCfg!=IntegrityTextHash(CurrentSensitiveConfigText()))
   { why="configuration generation mismatch"; return true; }

   double storedSym=GVRead(PosKey(pid,"SYMBOL_HASH"),0);
   if(storedSym>0 && sym!="" && (int)storedSym!=IntegrityTextHash(
      StringFormat("%s|%d|%.10f|%.10f|%.4f|%.4f|%.4f|%.4f|%d|%d|%I64d",
      sym,(int)SymbolInfoInteger(sym,SYMBOL_DIGITS),SymbolInfoDouble(sym,SYMBOL_POINT),
      SymbolInfoDouble(sym,SYMBOL_TRADE_TICK_SIZE),SymbolInfoDouble(sym,SYMBOL_TRADE_TICK_VALUE),
      SymbolInfoDouble(sym,SYMBOL_TRADE_CONTRACT_SIZE),SymbolInfoDouble(sym,SYMBOL_VOLUME_MIN),
      SymbolInfoDouble(sym,SYMBOL_VOLUME_STEP),(int)SymbolInfoInteger(sym,SYMBOL_TRADE_STOPS_LEVEL),
      (int)SymbolInfoInteger(sym,SYMBOL_TRADE_FREEZE_LEVEL),SymbolInfoInteger(sym,SYMBOL_TRADE_CALC_MODE))))
   { why="symbol-contract generation mismatch"; return true; }
   return false;
}

void AttachIntegrityMetadataToPosition(ulong ticket)
{
   if(ticket==0 || !PositionSelectByTicket(ticket)) return;
   ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
   string sym=PositionGetString(POSITION_SYMBOL);
   StrategyClass c=(StrategyClass)(int)GVRead(PosKey(pid,"STRATEGY"),CandidateStrategyForSymbol(sym));
   GVWrite(PosKey(pid,"CONFIG_HASH"),IntegrityTextHash(CurrentSensitiveConfigText()));
   string raw=StringFormat("%s|%d|%.10f|%.10f|%.4f|%.4f|%.4f|%.4f|%d|%d|%I64d",
      sym,(int)SymbolInfoInteger(sym,SYMBOL_DIGITS),SymbolInfoDouble(sym,SYMBOL_POINT),
      SymbolInfoDouble(sym,SYMBOL_TRADE_TICK_SIZE),SymbolInfoDouble(sym,SYMBOL_TRADE_TICK_VALUE),
      SymbolInfoDouble(sym,SYMBOL_TRADE_CONTRACT_SIZE),SymbolInfoDouble(sym,SYMBOL_VOLUME_MIN),
      SymbolInfoDouble(sym,SYMBOL_VOLUME_STEP),(int)SymbolInfoInteger(sym,SYMBOL_TRADE_STOPS_LEVEL),
      (int)SymbolInfoInteger(sym,SYMBOL_TRADE_FREEZE_LEVEL),SymbolInfoInteger(sym,SYMBOL_TRADE_CALC_MODE));
   GVWrite(PosKey(pid,"SYMBOL_HASH"),IntegrityTextHash(raw));
   GVWrite(PosKey(pid,"STRATEGY_CFG_HASH"),IntegrityTextHash(StrategyConfigVersion(c)));
   GVWrite(PosKey(pid,"MODEL_POLICY_HASH"),IntegrityTextHash(InpModelPolicyVersion));
   WriteDataIntegrityRow("POSITION_BIND",sym,c,pid,"position bound to current data/config generation");
}

string StrategyConfigDescription(StrategyClass c)
{
   switch(c)
   {
      case STRATEGY_TREND_CONTINUATION:
         return StringFormat("min_score=%d;trend_daily=%.2f;trend_weekly=%.2f",InpMinStrategyScore,InpTrendDailyRiskBudgetPct,InpTrendWeeklyRiskBudgetPct);
      case STRATEGY_RETRACEMENT_ENTRY:
         return StringFormat("min_score=%d;expiry=%d;daily=%.2f;weekly=%.2f",InpMinStrategyScore,InpPullbackExpiryM15,InpRetracementDailyRiskBudgetPct,InpRetracementWeeklyRiskBudgetPct);
      case STRATEGY_COUNTER_TREND_SCALP:
         return StringFormat("min_ct=%d;daily=%.2f;weekly=%.2f",InpMinCounterTrendScore,InpCounterScalpDailyRiskBudgetPct,InpCounterScalpWeeklyRiskBudgetPct);
      case STRATEGY_COUNTER_TREND_SWING:
         return StringFormat("min_ct=%d;daily=%.2f;weekly=%.2f",InpMinCounterTrendScore,InpCounterSwingDailyRiskBudgetPct,InpCounterSwingWeeklyRiskBudgetPct);
      case STRATEGY_POTENTIAL_REVERSAL:
         return StringFormat("min_score=%d;daily=%.2f;weekly=%.2f",InpMinStrategyScore,InpReversalDailyRiskBudgetPct,InpReversalWeeklyRiskBudgetPct);
      case STRATEGY_BREAKOUT:
         return StringFormat("direct=%d;vol=%.2f;adx=%.1f;zone=%.2f;daily=%.2f;weekly=%.2f",
            InpAllowDirectBreakoutExecution?1:0,InpDirectBreakoutMinVolumeRatio,InpDirectBreakoutMinADX,InpDirectBreakoutZoneATR,
            InpBreakoutDailyRiskBudgetPct,InpBreakoutWeeklyRiskBudgetPct);
      case STRATEGY_BREAKOUT_RETEST:
         return StringFormat("buffer=%.2f;retest=%.2f;expiry=%d;daily=%.2f;weekly=%.2f",
            InpBreakoutBufferATR,InpRetestHalfWidthATR,InpBreakoutExpiryM15,InpBreakoutRetestDailyRiskBudgetPct,InpBreakoutRetestWeeklyRiskBudgetPct);
      case STRATEGY_RANGE_TRADE:
         return StringFormat("enabled=%d;daily=%.2f;weekly=%.2f",InpAllowRangeTrades?1:0,InpRangeDailyRiskBudgetPct,InpRangeWeeklyRiskBudgetPct);
      case STRATEGY_MEAN_REVERSION:
         return StringFormat("enabled=%d;daily=%.2f;weekly=%.2f",InpAllowMeanReversion?1:0,InpMeanReversionDailyRiskBudgetPct,InpMeanReversionWeeklyRiskBudgetPct);
      default: return "none";
   }
}

void WriteStrategyConfigRegistry()
{
   bool exists=FileIsExist(InpStrategyConfigRegistryFile,FILE_COMMON);
   int h=FileOpen(InpStrategyConfigRegistryFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(h==INVALID_HANDLE) return;
   if(!exists || FileSize(h)==0)
      FileWrite(h,"schema_version","time","release_id","strategy_engine","model_policy","config_fingerprint",
         "strategy","strategy_config_version","configuration");
   FileSeek(h,0,SEEK_END);
   for(int ci=1;ci<=9;ci++)
   {
      StrategyClass c=(StrategyClass)ci;
      FileWrite(h,"strategy_config_registry_v1",TimeToString(TimeTradeServer(),TIME_DATE|TIME_SECONDS),
         GPT_EA_REQUIRED_RELEASE_VALIDATION_ID,InpStrategyEngineVersion,InpModelPolicyVersion,CurrentConfigFingerprint(),
         StrategyClassName(c),StrategyConfigVersion(c),StrategyConfigDescription(c));
   }
   FileFlush(h); FileClose(h);
}

bool IsLearningAggregateGlobal(const string name)
{
   string prefix=SysKey("");
   if(StringFind(name,prefix)!=0) return false;
   string suffix=StringSubstr(name,StringLen(prefix));
   string families[]={
      "STRAT_","CAL_CONF_","EXEC_STRAT_","EXEC_SESSION_","EXPIRY_",
      "EVENT_","HEALTH_RECENT_","CC_","SHADOW_","REGIME_","MODEL_"
   };
   for(int i=0;i<ArraySize(families);i++)
      if(StringFind(suffix,families[i])==0) return true;
   return false;
}

int ResetLearningAggregateGeneration()
{
   int removed=0;
   for(int i=GlobalVariablesTotal()-1;i>=0;i--)
   {
      string name=GlobalVariableName(i);
      if(!IsLearningAggregateGlobal(name)) continue;
      if(GlobalVariableDel(name)) removed++;
   }
   return removed;
}

void EnsureLearningGeneration()
{
   int current=IntegrityTextHash(CurrentSensitiveConfigText());
   string key=SysKey("DATA_GENERATION_HASH");
   int stored=(int)GVRead(key,0);
   if(stored==0)
   {
      GVWrite(key,current);
      GVWrite(SysKey("LEARNING_GENERATION_EPOCH"),1);
      GlobalVariablesFlush();
      return;
   }
   if(stored==current) return;

   int removed=0;
   if(InpResetLearningOnGenerationChange)
      removed=ResetLearningAggregateGeneration();

   double epoch=GVRead(SysKey("LEARNING_GENERATION_EPOCH"),0)+1;
   GVWrite(SysKey("DATA_GENERATION_HASH"),current);
   GVWrite(SysKey("LEARNING_GENERATION_EPOCH"),epoch);
   GVWrite(SysKey("LEARNING_GENERATION_RESET_TIME"),(double)TimeTradeServer());
   GlobalVariablesFlush();

   WriteDataIntegrityRow("LEARNING_GENERATION_RESET","",STRATEGY_NO_TRADE,0,
      StringFormat("material configuration generation changed %08X -> %08X; cleared %d aggregate learning globals; epoch %.0f",
                   stored,current,removed,epoch));
}

void DataIntegrityInit()
{
   EnsureDataIntegrityHeader();
   EnsureLearningQuarantineHeader();
   EnsureLearningGeneration();
   WriteStrategyConfigRegistry();
   WriteDataIntegrityRow("INIT","",STRATEGY_NO_TRADE,0,"EA data-integrity generation initialized");
}

void DataIntegrityTimer()
{
   // Metadata is bound at entry; quarantine is evaluated when trades close.
}

void DataIntegrityShutdown()
{
   WriteDataIntegrityRow("SHUTDOWN","",STRATEGY_NO_TRADE,0,"EA data-integrity generation shutdown");
}
