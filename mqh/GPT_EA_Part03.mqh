   if(n.hour==InpUSOpenHourNY && n.min==InpPreUSOpenMinute){ due=true; why="Pre-U.S. cash open"; }
   if(n.hour==InpUSOpenHourNY && n.min==InpUSOpenMinuteNY){ due=true; why="U.S. cash open"; }

   string key=StringFormat("%04d%02d%02d-%02d%02d-%s",l.year,l.mon,l.day,l.hour,l.min,why);
   if(due && key!=g_lastScheduleKey){ g_lastScheduleKey=key; return true; }
   return false;
}

// ------------------------- Volatility logic -----------------------
double AverageATR(const string sym,ENUM_TIMEFRAMES tf,int period,int samples)
{
   int h=iATR(sym,tf,period);
   if(h==INVALID_HANDLE) return 0;
   double a[]; ArraySetAsSeries(a,true);
   int n=CopyBuffer(h,0,1,samples,a); IndicatorRelease(h);
   if(n<=0) return 0;
   double s=0; for(int i=0;i<n;i++) s+=a[i]; return s/n;
}

double OpeningRangeRatio(const string sym)
{
   MqlRates r[]; ArraySetAsSeries(r,true);
   int n=CopyRates(sym,PERIOD_M15,0,160,r);
   if(n<=0) return 1.0;
   double atr=0; if(!ATRValue(sym,PERIOD_M15,InpATRPeriod,1,atr) || atr<=0) return 1.0;

   double lHi=-1.0e100,lLo=1.0e100,uHi=-1.0e100,uLo=1.0e100;
   int lCount=0,uCount=0,lDate=-1,uDate=-1;
   datetime lLatest=0,uLatest=0,nowUTC=TimeGMT();

   for(int i=0;i<n;i++)
   {
      datetime utc=ServerToUTC(r[i].time);
      if(nowUTC-utc>36*3600) continue;
      MqlDateTime l={}; TimeToStruct(LondonLocal(utc),l);
      MqlDateTime ny={}; TimeToStruct(NewYorkLocal(utc),ny);
      int ld=l.year*10000+l.mon*100+l.day;
      int ud=ny.year*10000+ny.mon*100+ny.day;
      bool londonOR=(l.hour==9 && (l.min==0 || l.min==15));
      bool usOR=(ny.hour==9 && (ny.min==30 || ny.min==45));

      if(londonOR)
      {
         if(lDate<0) lDate=ld;
         if(ld==lDate){ if(r[i].high>lHi) lHi=r[i].high; if(r[i].low<lLo) lLo=r[i].low; lCount++; if(r[i].time>lLatest) lLatest=r[i].time; }
      }
      if(usOR)
      {
         if(uDate<0) uDate=ud;
         if(ud==uDate){ if(r[i].high>uHi) uHi=r[i].high; if(r[i].low<uLo) uLo=r[i].low; uCount++; if(r[i].time>uLatest) uLatest=r[i].time; }
      }
   }

   double lRatio=(lCount>=2 && lHi>lLo ? (lHi-lLo)/atr : -1.0);
   double uRatio=(uCount>=2 && uHi>uLo ? (uHi-uLo)/atr : -1.0);
   if(lRatio<0 && uRatio<0) return 1.0;
   if(uRatio>=0 && uLatest>=lLatest) return uRatio;
   return lRatio;
}

int AdaptiveExpiry(const string sym,int base)
{
   double cur=0,avg=AverageATR(sym,PERIOD_M15,InpATRPeriod,50);
   if(!ATRValue(sym,PERIOD_M15,InpATRPeriod,1,cur) || cur<=0 || avg<=0) return base;
   double atrRatio=cur/avg;
   double orRatio=OpeningRangeRatio(sym);
   double mult=1.0;
   if(atrRatio>1.50 || orRatio>1.80) mult*=0.70; // fast tape: setup should work quickly
   else if(atrRatio<0.70 || orRatio<0.70) mult*=1.35; // slow tape: allow more candles
   int out=(int)MathRound(base*mult);
   if(out<2) out=2; if(out>12) out=12;
   return out;
}

bool SessionConditionInvalidates(const string sym,double preferred,double atr,string &why)
{
   MqlTick t; if(!GetTickSafe(sym,t)) return true;
   double mid=(t.ask+t.bid)*0.5;
   if(atr>0 && MathAbs(mid-preferred)>1.75*atr)
   {
      why="Price displaced >1.75 ATR from planned entry; stale pre-open level.";
      return true;
   }
   double orr=OpeningRangeRatio(sym);
   if(orr>2.20)
   {
      why=StringFormat("Opening range %.2f x M15 ATR; volatility regime changed.",orr);
      return true;
   }
   why="Session displacement/opening range acceptable.";
   return false;
}

// ------------------------- News / yield filters -------------------
void AddCurrency(string &csv,const string c)
{
   if(StringLen(c)!=3) return;
   if(StringFind(","+csv+",",","+c+",")<0){ if(csv!="") csv+=","; csv+=c; }
}

string RelatedCurrencies(const string sym)
{
   string u=sym; StringToUpper(u);
   string out="";
   if(StringFind(u,"XAU")>=0 || StringFind(u,"XAG")>=0 || StringFind(u,"US100")>=0 || StringFind(u,"USTEC")>=0 ||
      StringFind(u,"NAS")>=0 || StringFind(u,"US30")>=0 || StringFind(u,"SPX")>=0 || StringFind(u,"BTC")>=0) AddCurrency(out,"USD");
   if(StringFind(u,"GER40")>=0 || StringFind(u,"DE40")>=0 || StringFind(u,"DAX")>=0) AddCurrency(out,"EUR");

   // Common FX symbols: pick first two recognized 3-letter currencies present in name.
   string known[8]={"USD","EUR","GBP","JPY","CHF","CAD","AUD","NZD"};
   for(int i=0;i<8;i++) if(StringFind(u,known[i])>=0) AddCurrency(out,known[i]);
   return out;
}

bool CalendarBlock(const string sym,string &detail)
{
   detail="No blocking scheduled event found.";
   if(!InpUseEconomicCalendar) { detail="Economic-calendar filter disabled."; return false; }
   if((bool)MQLInfoInteger(MQL_TESTER)) { detail="Calendar unavailable in Strategy Tester; use live/demo or CSV news data."; return false; }

   string ccy=RelatedCurrencies(sym);
   if(ccy=="") return false;
   string arr[]; int nc=StringSplit(ccy,',',arr);
   datetime now=TimeTradeServer();
   datetime from=now-InpNewsBlockAfterMinutes*60;
   datetime to=now+InpNewsBlockBeforeMinutes*60;

   for(int c=0;c<nc;c++)
   {
      MqlCalendarValue vals[];
      int n=CalendarValueHistory(vals,from,to,NULL,arr[c]);
      if(n<=0) continue;
      for(int i=0;i<n;i++)
      {
         MqlCalendarEvent ev={};
         if(!CalendarEventById(vals[i].event_id,ev)) continue;
         bool high=(ev.importance==CALENDAR_IMPORTANCE_HIGH);
         bool moderate=(ev.importance==CALENDAR_IMPORTANCE_MODERATE);
         if(high || (InpBlockModerateNews && moderate))
         {
            int mins=(int)MathRound((vals[i].time-now)/60.0);
            detail=StringFormat("BLOCK: %s %s at %s (%+d min, server time)",arr[c],ev.name,TimeToString(vals[i].time,TIME_MINUTES),mins);
            return true;
         }
      }
   }
   return false;
}

bool YieldShock(string &detail)
{
   detail="No Treasury-yield shock detected.";
   if(!InpUseYieldShockFilter){ detail="Yield-shock filter disabled."; return false; }
   if(!EnsureSymbol(InpYieldSymbol)){ detail="Yield symbol '"+InpYieldSymbol+"' not found; filter skipped."; return false; }
   MqlTick t; if(!SymbolInfoTick(InpYieldSymbol,t)){ detail="Yield symbol has no tick; filter skipped."; return false; }
   int shift=MathMax(1,InpYieldLookbackMinutes);
   double old=0; if(!CloseValue(InpYieldSymbol,PERIOD_M1,shift,old) || old<=0){ detail="Insufficient yield history; filter skipped."; return false; }
   double now=(t.bid>0?t.bid:t.last);
   double move=now-old;
   detail=StringFormat("%s %d-min move: %+.4f",InpYieldSymbol,InpYieldLookbackMinutes,move);
   if(MathAbs(move)>=InpYieldShockAbsolute){ detail="BLOCK: "+detail+" exceeds shock threshold."; return true; }
   return false;
}

// ---------------------- Spread / slippage / R:R -------------------
double EffectiveRR(const string sym,bool bullish,double entry,double sl,double tp)
{
   MqlTick t; if(!GetTickSafe(sym,t)) return 0;
   double spread=MathMax(0.0,t.ask-t.bid);
   double slip=InpMaxSlippagePoints*PointFor(sym);
   double cost=spread+slip;
   double risk=MathAbs(entry-sl)+cost;
   double reward=MathAbs(tp-entry)-cost;
