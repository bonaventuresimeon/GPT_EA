// ============================================================================
// GPT_EA Part 34 - Strategy health dashboard and adaptive telemetry
// ============================================================================
// Strategy health status contract: ACTIVE / REDUCED_RISK / SHADOW / DISABLED.

input bool   InpShowStrategyHealthDashboard       = true;
input bool   InpWriteStrategyHealthJournal        = true;
input string InpStrategyHealthJournalFile         = "GPT_EA_StrategyHealth.csv";
input int    InpStrategyHealthJournalMinutes      = 15;

string STRATEGY_HEALTH_PANEL="GPT_EA_STRATEGY_HEALTH_PANEL";

void EnsureStrategyHealthHeader()
{
   if(!InpWriteStrategyHealthJournal) return;
   bool exists=FileIsExist(InpStrategyHealthJournalFile,FILE_COMMON);
   int h=FileOpen(InpStrategyHealthJournalFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(h==INVALID_HANDLE) return;
   if(!exists || FileSize(h)==0)
      FileWrite(h,"schema_version","time","strategy","status","sample_n","win_rate","avg_r","profit_factor","max_dd_r","max_loss_run",
         "recent_n","recent_avg_r","recent_pf","avg_realized_win_loss_rr","strategy_slippage_pts","current_regime","regime_n","regime_avg_r","regime_pf",
         "champion_challenger","risk_multiplier");
   FileClose(h);
}

string DashboardReferenceSymbol()
{
   for(int i=0;i<ArraySize(g_symbols);i++) if(g_symbols[i]!="") return g_symbols[i];
   return _Symbol;
}

void StrategyRealizedWinLossRR(StrategyClass c,double &ratio,double &avgWin,double &avgLoss)
{
   string k=SysKey(StringFormat("STRAT_%d",(int)c));
   double n=GVRead(k+"_N",0),wins=GVRead(k+"_WIN",0),pos=GVRead(k+"_POSR",0),neg=GVRead(k+"_NEGR",0);
   double losses=MathMax(0.0,n-wins);
   avgWin=(wins>0?pos/wins:0);
   avgLoss=(losses>0?neg/losses:0);
   ratio=(avgLoss>0?avgWin/avgLoss:(avgWin>0?99.0:0));
}

string CurrentRegimeEvidenceText(StrategyClass c,const string sym,double &n,double &avg,double &pf)
{
   StrategySnapshot x; BuildStrategySnapshot(sym,x);
   double wr=0,dd=0,ml=0;
   StrategyBucketMetrics(SysKey(StringFormat("STRAT_%d_STATE_%d",(int)c,(int)x.state)),n,wr,avg,pf,dd,ml);
   return MarketStateName(x.state);
}

string StrategyHealthRow(StrategyClass c,const string refSym)
{
   double n=0,wr=0,avg=0,pf=0,dd=0,ml=0;
   StrategyBucketMetrics(SysKey(StringFormat("STRAT_%d",(int)c)),n,wr,avg,pf,dd,ml);
   double rn=GVRead(SysKey(StringFormat("HEALTH_RECENT_N_%d",(int)c)),0);
   double ravg=GVRead(SysKey(StringFormat("HEALTH_RECENT_AVG_%d",(int)c)),0);
   double rpf=GVRead(SysKey(StringFormat("HEALTH_RECENT_PF_%d",(int)c)),0);
   double realRR=0,aw=0,al=0; StrategyRealizedWinLossRR(c,realRR,aw,al);
   double slip=GVRead(SysKey(StringFormat("EXEC_STRAT_%d_SLIP",(int)c)),0);
   double regN=0,regAvg=0,regPF=0; string regime=CurrentRegimeEvidenceText(c,refSym,regN,regAvg,regPF);
   int mode=StrategyHealthMode(c);
   double mult=StrategyHealthRiskMultiplier(c);
   return StringFormat("%-18s %-12s N%3.0f avg%+.2fR PF%.2f DD%.2f | recent %.0f/%+.2f/%.2f | realRR %.2f | slip %.1f | %s %.0f/%+.2f/%.2f | x%.2f",
      StrategyCode(c),AdaptiveStrategyModeName(mode),n,avg,pf,dd,rn,ravg,rpf,realRR,slip,regime,regN,regAvg,regPF,mult);
}

string BuildStrategyHealthDashboardText()
{
   string ref=DashboardReferenceSymbol();
   string out="STRATEGY HEALTH / ADAPTIVE EXECUTION\n";
   out+="Reference regime: "+ref+" | "+RegimeTransitionText(ref)+"\n";
   for(int ci=1;ci<=9;ci++) out+=StrategyHealthRow((StrategyClass)ci,ref)+"\n";
   StrategyClass current=CandidateStrategyForSymbol(ref);
   if(current!=STRATEGY_NO_TRADE) out+=ChampionChallengerSummary(current)+"\n";
   string bh=""; double health=BrokerHealthScore(ref,bh);
   out+=StringFormat("Broker health %.1f | portfolio risk %.2f%% | daily loss %.2f%% | DD %.2f%%\n",health,CurrentPortfolioRiskPercent(),DailyLossPercent(),EquityDrawdownPercent());
   out+="Release: "+ReleaseGateSummary()+"\n";
   return out;
}

void RenderStrategyHealthDashboard()
{
   if(!InpShowStrategyHealthDashboard){ ObjectDelete(0,STRATEGY_HEALTH_PANEL); return; }
   string txt=BuildStrategyHealthDashboardText();
   if(ObjectFind(0,STRATEGY_HEALTH_PANEL)<0) ObjectCreate(0,STRATEGY_HEALTH_PANEL,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,STRATEGY_HEALTH_PANEL,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger(0,STRATEGY_HEALTH_PANEL,OBJPROP_XDISTANCE,16);
   ObjectSetInteger(0,STRATEGY_HEALTH_PANEL,OBJPROP_YDISTANCE,150);
   ObjectSetInteger(0,STRATEGY_HEALTH_PANEL,OBJPROP_FONTSIZE,8);
   ObjectSetString(0,STRATEGY_HEALTH_PANEL,OBJPROP_FONT,"Consolas");
   ObjectSetString(0,STRATEGY_HEALTH_PANEL,OBJPROP_TEXT,txt);
   ChartRedraw();
}

void WriteStrategyHealthSnapshot()
{
   if(!InpWriteStrategyHealthJournal) return;
   datetime now=TimeTradeServer();
   datetime last=(datetime)GVRead(SysKey("HEALTH_JOURNAL_TIME"),0);
   if(last>0 && now-last<MathMax(1,InpStrategyHealthJournalMinutes)*60) return;
   EnsureStrategyHealthHeader();
   int h=FileOpen(InpStrategyHealthJournalFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(h==INVALID_HANDLE) return;
   FileSeek(h,0,SEEK_END);
   string ref=DashboardReferenceSymbol();
   for(int ci=1;ci<=9;ci++)
   {
      StrategyClass c=(StrategyClass)ci;
      double n=0,wr=0,avg=0,pf=0,dd=0,ml=0;
      StrategyBucketMetrics(SysKey(StringFormat("STRAT_%d",ci)),n,wr,avg,pf,dd,ml);
      double rn=GVRead(SysKey(StringFormat("HEALTH_RECENT_N_%d",ci)),0),ravg=GVRead(SysKey(StringFormat("HEALTH_RECENT_AVG_%d",ci)),0),rpf=GVRead(SysKey(StringFormat("HEALTH_RECENT_PF_%d",ci)),0);
      double realRR=0,aw=0,al=0; StrategyRealizedWinLossRR(c,realRR,aw,al);
      double slip=GVRead(SysKey(StringFormat("EXEC_STRAT_%d_SLIP",ci)),0);
      double regN=0,regAvg=0,regPF=0; string regime=CurrentRegimeEvidenceText(c,ref,regN,regAvg,regPF);
      FileWrite(h,"strategy_health_v1",TimeToString(now,TIME_DATE|TIME_SECONDS),StrategyClassName(c),AdaptiveStrategyModeName(StrategyHealthMode(c)),
         n,DoubleToString(wr,1),DoubleToString(avg,3),DoubleToString(pf,3),DoubleToString(dd,3),ml,
         rn,DoubleToString(ravg,3),DoubleToString(rpf,3),DoubleToString(realRR,3),DoubleToString(slip,1),regime,
         regN,DoubleToString(regAvg,3),DoubleToString(regPF,3),SnapshotText(ChampionChallengerSummary(c)),DoubleToString(StrategyHealthRiskMultiplier(c),2));
   }
   FileFlush(h); FileClose(h);
   GVWrite(SysKey("HEALTH_JOURNAL_TIME"),(double)now);
}

string AdaptiveCardAddendum(const TradeSetup &s,const StrategyDecision &d)
{
   return "\n━━━━━━━━━━━━━━━━━━━━\n⚙️ ADAPTIVE EXECUTION & STRATEGY HEALTH\n━━━━━━━━━━━━━━━━━━━━\n"+
      AdaptiveRiskSummary(s)+"\n"+
      ExecutionLearningSummary(s)+"\n"+
      ChampionChallengerSummary(d.strategy)+"\n"+
      LifecycleIntegritySummary(s.symbol)+"\n";
}

void StrategyHealthDashboardInit()
{
   EnsureStrategyHealthHeader();
   RenderStrategyHealthDashboard();
   WriteStrategyHealthSnapshot();
   Print("GPT_EA strategy health dashboard initialized.");
}

void StrategyHealthDashboardTimer()
{
   RenderStrategyHealthDashboard();
   WriteStrategyHealthSnapshot();
}

void DeleteStrategyHealthDashboard()
{
   ObjectDelete(0,STRATEGY_HEALTH_PANEL);
}
