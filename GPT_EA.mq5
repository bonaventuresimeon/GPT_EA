// GPT_EA standalone MetaTrader 5 entry file
// ===== BEGIN INLINED GPT_EA_Part01.mqh =====
#property strict
#property version   "1.20"
#property description "Standalone GPT EA: multi-symbol scanner, OpenAI review, timed approve/deny prompts and approval-only execution."

#include <Trade/Trade.mqh>
CTrade trade;

// ----------------------------- Inputs -----------------------------
input string InpSymbols                 = "XAUUSD,US100.cash,GER40.cash";
input double InpRiskPercent             = 1.00;       // % of equity/balance risked per trade
input bool   InpUseEquity               = true;
input bool   InpRequireApproval         = true;       // signal must be approved before execution
input bool   InpEnableApprovedExecution = true;       // master execution switch
input int    InpApprovalTimeoutSeconds  = 60;         // no response => delete pending setup
input bool   InpApprovalAlert           = true;
input bool   InpEnableAlerts            = true;
input bool   InpEnablePush              = false;
input long   InpMagic                   = 5600917;
input int    InpTimerSeconds            = 30;
input int    InpMaxPositionsPerSymbol   = 1;

input int    InpFastEMA                 = 20;
input int    InpSlowEMA                 = 50;
input int    InpRSIPeriod               = 14;
input int    InpATRPeriod               = 14;
input int    InpSwingBars               = 20;
input int    InpMinConfidence           = 72;
input double InpMinEffectiveRR          = 1.50;       // measured to TP2 after spread/slippage

input double InpMaxSpreadATRFrac        = 0.12;       // spread must be <= fraction of M5 ATR
input int    InpMaxSlippagePoints       = 30;
input double InpBreakoutBufferATR       = 0.10;
input double InpRetestHalfWidthATR      = 0.15;
input double InpPullbackLowATR          = 0.20;
input double InpPullbackHighATR         = 0.10;
input double InpStopATR                 = 1.00;

input int    InpPullbackExpiryM15       = 6;          // time invalidation if TP1 not reached
input int    InpBreakoutExpiryM15       = 4;
input int    InpPostTP1StallM5          = 3;
input double InpPartialAtTP1Percent     = 50.0;
input bool   InpMoveSLToBEAfterTP1      = true;
input double InpBECostATRFrac           = 0.05;

input bool   InpUseEconomicCalendar     = true;
input int    InpNewsBlockBeforeMinutes  = 30;
input int    InpNewsBlockAfterMinutes   = 15;
input bool   InpBlockModerateNews       = false;

input bool   InpUseYieldShockFilter     = true;
input string InpYieldSymbol             = "US10Y";    // change to broker's 10Y-yield symbol
input int    InpYieldLookbackMinutes    = 15;
input double InpYieldShockAbsolute      = 0.05;       // 0.05 yield points = 5 bp if quoted as %

input int    InpPreLondonScanMinute     = 55;         // 08:55 Europe/London
input int    InpLondonHourlyStart       = 9;
input int    InpLondonHourlyEnd         = 17;
input int    InpPreUSOpenMinute         = 25;         // 09:25 America/New_York
input int    InpUSOpenHourNY            = 9;
input int    InpUSOpenMinuteNY          = 30;

// -------------------------- OpenAI API ---------------------------
input bool   InpUseOpenAI               = true;
input string InpOpenAIAPIKey            = "";         // ENTER LOCALLY. Never commit a real key to GitHub.
input string InpOpenAIModel             = "gpt-5.6-luna";
input string InpOpenAIEndpoint          = "https://api.openai.com/v1/responses";
input int    InpOpenAITimeoutMs         = 15000;
input bool   InpAIReviewHighConfidenceOnly = true;
input int    InpAIMaxOutputChars         = 1800;

// ----------------------------- Types ------------------------------
enum SetupKind { SETUP_NONE=0, SETUP_PULLBACK=1, SETUP_BREAKOUT_RETEST=2, SETUP_BREAKOUT=3 };

struct TradeSetup
{
   bool      valid;
   bool      bullish;
   SetupKind kind;
   string    symbol;
   string    name;
   double    zoneLow;
   double    zoneHigh;
   double    preferred;
   double    sl;
   double    tp1;
   double    tp2;
   double    tp3;
   double    nominalRR1;
   double    effectiveRR1;
   int       confidence;
   int       expiryM15;
   string    reason;
   string    invalidation;
   string    failurePattern;
   string    eventRisk;
   string    yieldRisk;
   string    executionRule;
};

string g_symbols[];
string g_lastScheduleKey = "";
string g_lastCard = "";

struct PendingApproval
{
   bool       active;
   TradeSetup setup;
   string     card;
   string     scanReason;
   datetime   createdAt;
   datetime   expiresAt;
};

PendingApproval g_pending[];
int g_displayPending=-1;
string BTN_APPROVE="GPT_EA_APPROVE_BTN";
string BTN_DENY="GPT_EA_DENY_BTN";
string LBL_PROMPT="GPT_EA_APPROVAL_LABEL";

// --------------------------- OpenAI client -------------------------
string JsonEscape(string s)
{
   StringReplace(s,"\\","\\\\");
   StringReplace(s,"\"","\\\"");
   StringReplace(s,"\r","\\r");
   StringReplace(s,"\n","\\n");
   StringReplace(s,"\t","\\t");
   return s;
}

string JsonUnescape(string s)
{
   StringReplace(s,"\\n","\n");
   StringReplace(s,"\\r","\r");
   StringReplace(s,"\\t","\t");
   StringReplace(s,"\\\"","\"");
   StringReplace(s,"\\\\","\\");
   return s;
}

string ExtractOpenAIText(const string json)
{
   // Responses API text commonly appears as: "type":"output_text", ... "text":"..."
   int typePos=StringFind(json,"\"type\":\"output_text\"");
   int start=(typePos>=0 ? typePos : 0);
   string key="\"text\":\"";
   int p=StringFind(json,key,start);
   if(p<0)
   {
      key="\"output_text\":\"";
      p=StringFind(json,key,start);
   }
   if(p<0) return "OpenAI response received, but text could not be parsed.";
   p+=StringLen(key);

   string out="";
   bool esc=false;
   for(int i=p;i<StringLen(json);i++)
   {
      ushort ch=StringGetCharacter(json,i);
      if(ch=='\\' && !esc){ esc=true; out+="\\"; continue; }
      if(ch=='\"' && !esc) break;
      esc=false;
      out+=ShortToString(ch);
      if(StringLen(out)>=InpAIMaxOutputChars) break;
   }
   return JsonUnescape(out);
}

bool CallOpenAI(const string prompt,string &answer,string &errorText)
{
   answer=""; errorText="";
   if(!InpUseOpenAI){ errorText="OpenAI disabled."; return false; }
   if((bool)MQLInfoInteger(MQL_TESTER)){ errorText="WebRequest unavailable in Strategy Tester."; return false; }
   if(StringLen(Trim(InpOpenAIAPIKey))<20){ errorText="OpenAI API key not configured in EA inputs."; return false; }

   string body="{\"model\":\""+JsonEscape(InpOpenAIModel)+"\",\"input\":\""+JsonEscape(prompt)+"\"}";
   string headers="Content-Type: application/json\r\nAuthorization: Bearer "+InpOpenAIAPIKey+"\r\n";
   char data[],result[];
   string resultHeaders="";
   int n=StringToCharArray(body,data,0,WHOLE_ARRAY,CP_UTF8);
   if(n>0) ArrayResize(data,n-1); // remove terminal NUL from HTTP body

   ResetLastError();
   int code=WebRequest("POST",InpOpenAIEndpoint,headers,InpOpenAITimeoutMs,data,result,resultHeaders);
   if(code==-1)
   {
// ===== END INLINED GPT_EA_Part01.mqh =====
// ===== BEGIN INLINED GPT_EA_Part02.mqh =====
      errorText=StringFormat("OpenAI WebRequest failed. MT5 error=%d. Add https://api.openai.com under Tools > Options > Expert Advisors > Allow WebRequest.",GetLastError());
      return false;
   }
   string raw=CharArrayToString(result,0,-1,CP_UTF8);
   if(code<200 || code>=300)
   {
      errorText=StringFormat("OpenAI HTTP %d: %s",code,StringSubstr(raw,0,600));
      return false;
   }
   answer=ExtractOpenAIText(raw);
   if(StringLen(answer)==0){ errorText="OpenAI returned an empty answer."; return false; }
   return true;
}

string BuildOpenAIPrompt(const string sym,const string card)
{
   return "You are the secondary validation layer for a MetaTrader 5 market scanner. "
          "Use ONLY the supplied broker-derived chart analysis and risk filters. Do not invent prices, news, yields, or events. "
          "Review whether the proposed setup is internally consistent. Compare pullback versus breakout-retest failure risk, "
          "spread/slippage sensitivity, time-based invalidation, and post-TP1 management. "
          "Return at most 8 short lines: VERDICT (VALID/WAIT/INVALID), preferred setup, entry condition, invalidation, "
          "RR quality, event/yield risk, time-expiry note, and one execution warning. Symbol: "+sym+"\n\n"+card;
}

// ------------------------- Utility helpers ------------------------
string Trim(string s)
{
   StringTrimLeft(s); StringTrimRight(s); return s;
}

int SplitSymbols()
{
   string tmp[];
   int n=StringSplit(InpSymbols,',',tmp);
   if(n<=0) return 0;
   ArrayResize(g_symbols,n);
   for(int i=0;i<n;i++) g_symbols[i]=Trim(tmp[i]);
   return n;
}

int DigitsFor(const string sym){ return (int)SymbolInfoInteger(sym,SYMBOL_DIGITS); }
double PointFor(const string sym){ return SymbolInfoDouble(sym,SYMBOL_POINT); }
double NormPrice(const string sym,double p){ return NormalizeDouble(p,DigitsFor(sym)); }

bool EnsureSymbol(const string sym)
{
   if(SymbolInfoInteger(sym,SYMBOL_SELECT)) return true;
   return SymbolSelect(sym,true);
}

bool GetTickSafe(const string sym,MqlTick &tick)
{
   if(!EnsureSymbol(sym)) return false;
   return SymbolInfoTick(sym,tick);
}

bool BufferValue(const int handle,const int shift,double &v)
{
   if(handle==INVALID_HANDLE) return false;
   double a[]; ArraySetAsSeries(a,true);
   bool ok=(CopyBuffer(handle,0,shift,1,a)==1);
   if(ok) v=a[0];
   IndicatorRelease(handle);
   return ok;
}

bool EMAValue(const string sym,ENUM_TIMEFRAMES tf,int period,int shift,double &v)
{
   return BufferValue(iMA(sym,tf,period,0,MODE_EMA,PRICE_CLOSE),shift,v);
}

bool RSIValue(const string sym,ENUM_TIMEFRAMES tf,int period,int shift,double &v)
{
   return BufferValue(iRSI(sym,tf,period,PRICE_CLOSE),shift,v);
}

bool ATRValue(const string sym,ENUM_TIMEFRAMES tf,int period,int shift,double &v)
{
   return BufferValue(iATR(sym,tf,period),shift,v);
}

bool CloseValue(const string sym,ENUM_TIMEFRAMES tf,int shift,double &v)
{
   double a[]; ArraySetAsSeries(a,true);
   if(CopyClose(sym,tf,shift,1,a)!=1) return false;
   v=a[0]; return true;
}

bool RecentHighLow(const string sym,ENUM_TIMEFRAMES tf,int startShift,int count,double &hi,double &lo)
{
   MqlRates r[]; ArraySetAsSeries(r,true);
   int got=CopyRates(sym,tf,startShift,count,r);
   if(got<=0) return false;
   hi=-1.0e100; lo=1.0e100;
   for(int i=0;i<got;i++){ if(r[i].high>hi) hi=r[i].high; if(r[i].low<lo) lo=r[i].low; }
   return (hi>-1.0e99 && lo<1.0e99);
}

string TFName(ENUM_TIMEFRAMES tf)
{
   if(tf==PERIOD_D1) return "D1";
   if(tf==PERIOD_H4) return "H4";
   if(tf==PERIOD_H1) return "H1";
   if(tf==PERIOD_M30) return "M30";
   if(tf==PERIOD_M15) return "M15";
   if(tf==PERIOD_M5) return "M5";
   return EnumToString(tf);
}

int DirectionScoreTF(const string sym,ENUM_TIMEFRAMES tf,int weight,string &detail)
{
   double ef,es,rsi,c;
   if(!EMAValue(sym,tf,InpFastEMA,1,ef) || !EMAValue(sym,tf,InpSlowEMA,1,es) ||
      !RSIValue(sym,tf,InpRSIPeriod,1,rsi) || !CloseValue(sym,tf,1,c)) return 0;

   int raw=0;
   raw += (ef>es ? 1 : -1);
   raw += (c>ef ? 1 : -1);
   if(rsi>52.0) raw++;
   else if(rsi<48.0) raw--;

   detail += StringFormat("%s:%s RSI %.1f  ",TFName(tf),(raw>0?"BULL":raw<0?"BEAR":"FLAT"),rsi);
   return raw*weight;
}

int MultiTFScore(const string sym,string &detail,bool &majorAlignedBull,bool &majorAlignedBear)
{
   ENUM_TIMEFRAMES tfs[6]={PERIOD_D1,PERIOD_H4,PERIOD_H1,PERIOD_M30,PERIOD_M15,PERIOD_M5};
   int w[6]={3,3,3,2,2,1};
   int score=0;
   int majorDir[3]={0,0,0};
   detail="";
   for(int i=0;i<6;i++)
   {
      string d="";
      int s=DirectionScoreTF(sym,tfs[i],w[i],d);
      score+=s; detail+=d;
      if(i<3) majorDir[i]=(s>0?1:s<0?-1:0);
   }
   majorAlignedBull=(majorDir[0]>0 && majorDir[1]>0 && majorDir[2]>0);
   majorAlignedBear=(majorDir[0]<0 && majorDir[1]<0 && majorDir[2]<0);
   return score;
}

// ----------------------- Session / DST logic ----------------------
int DayOfWeekForDate(int y,int m,int d)
{
   MqlDateTime s={}; s.year=y; s.mon=m; s.day=d; s.hour=12;
   datetime t=StructToTime(s); MqlDateTime o={}; TimeToStruct(t,o); return o.day_of_week;
}

int DaysInMonth(int y,int m)
{
   if(m==2) return ((y%400==0 || (y%4==0 && y%100!=0))?29:28);
   if(m==4||m==6||m==9||m==11) return 30;
   return 31;
}

int LastSunday(int y,int m)
{
   int d=DaysInMonth(y,m);
   while(d>0 && DayOfWeekForDate(y,m,d)!=0) d--;
   return d;
}

int NthSunday(int y,int m,int nth)
{
   int d=1;
   while(DayOfWeekForDate(y,m,d)!=0) d++;
   return d+7*(nth-1);
}

datetime MakeDateTime(int y,int m,int d,int hh,int mm,int ss=0)
{
   MqlDateTime s={}; s.year=y; s.mon=m; s.day=d; s.hour=hh; s.min=mm; s.sec=ss; return StructToTime(s);
}

bool IsUKDST(datetime utc)
{
   MqlDateTime u={}; TimeToStruct(utc,u);
   datetime a=MakeDateTime(u.year,3,LastSunday(u.year,3),1,0);
   datetime b=MakeDateTime(u.year,10,LastSunday(u.year,10),1,0);
   return (utc>=a && utc<b);
}

bool IsUSDST(datetime utc)
{
   MqlDateTime u={}; TimeToStruct(utc,u);
   datetime a=MakeDateTime(u.year,3,NthSunday(u.year,3,2),7,0); // 02:00 EST = 07:00 UTC
   datetime b=MakeDateTime(u.year,11,NthSunday(u.year,11,1),6,0); // 02:00 EDT = 06:00 UTC
   return (utc>=a && utc<b);
}

datetime LondonLocal(datetime utc){ return utc+(IsUKDST(utc)?3600:0); }
datetime NewYorkLocal(datetime utc){ return utc+(IsUSDST(utc)?-4*3600:-5*3600); }

datetime ServerToUTC(datetime serverTime)
{
   // Calendar and bars use server time. For same-day session checks this live offset is adequate.
   long off=(long)(TimeTradeServer()-TimeGMT());
   return serverTime-off;
}

bool ScheduledScanDue(string &why)
{
   datetime utc=TimeGMT();
   MqlDateTime l={}; TimeToStruct(LondonLocal(utc),l);
   MqlDateTime n={}; TimeToStruct(NewYorkLocal(utc),n);
   bool due=false; why="";

   if(l.hour==8 && l.min==InpPreLondonScanMinute){ due=true; why="Pre-London 08:"+IntegerToString(InpPreLondonScanMinute); }
   if(l.hour>=InpLondonHourlyStart && l.hour<=InpLondonHourlyEnd && l.min==0){ due=true; why="London hourly scan"; }
// ===== END INLINED GPT_EA_Part02.mqh =====
// ===== BEGIN INLINED GPT_EA_Part03.mqh =====
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
// ===== END INLINED GPT_EA_Part03.mqh =====
// ===== BEGIN INLINED GPT_EA_Part04.mqh =====
   if(risk<=0 || reward<=0) return 0;
   return reward/risk;
}

bool SpreadOK(const string sym,string &detail)
{
   MqlTick t; if(!GetTickSafe(sym,t)) { detail="No live tick."; return false; }
   double atr=0; if(!ATRValue(sym,PERIOD_M5,InpATRPeriod,1,atr) || atr<=0){ detail="No M5 ATR."; return false; }
   double spread=t.ask-t.bid;
   double ratio=spread/atr;
   detail=StringFormat("Spread %.1f pts = %.2f%% of M5 ATR",spread/PointFor(sym),ratio*100.0);
   return ratio<=InpMaxSpreadATRFrac;
}

// -------------------------- Setup building ------------------------
void InitSetup(TradeSetup &s,const string sym,SetupKind k,bool bull)
{
   s.valid=false; s.bullish=bull; s.kind=k; s.symbol=sym;
   s.name=(k==SETUP_PULLBACK?"PULLBACK":(k==SETUP_BREAKOUT?"BREAKOUT":"BREAKOUT-RETEST"));
   s.zoneLow=s.zoneHigh=s.preferred=s.sl=s.tp1=s.tp2=s.tp3=0;
   s.nominalRR1=s.effectiveRR1=0; s.confidence=0; s.expiryM15=0;
   s.reason=s.invalidation=s.failurePattern=s.eventRisk=s.yieldRisk=s.executionRule="";
}

void TargetsFromRisk(TradeSetup &s)
{
   double r=MathAbs(s.preferred-s.sl);
   if(r<=0) return;
   if(s.bullish){ s.tp1=s.preferred+r; s.tp2=s.preferred+2*r; s.tp3=s.preferred+3*r; }
   else { s.tp1=s.preferred-r; s.tp2=s.preferred-2*r; s.tp3=s.preferred-3*r; }
   s.tp1=NormPrice(s.symbol,s.tp1); s.tp2=NormPrice(s.symbol,s.tp2); s.tp3=NormPrice(s.symbol,s.tp3);
   s.nominalRR1=1.0;
   s.effectiveRR1=EffectiveRR(s.symbol,s.bullish,s.preferred,s.sl,s.tp2);
}

TradeSetup BuildPullback(const string sym,bool bull,int baseConfidence,const string trendDetail)
{
   TradeSetup s; InitSetup(s,sym,SETUP_PULLBACK,bull);
   double atr=0,ema=0,hi=0,lo=0;
   if(!ATRValue(sym,PERIOD_M15,InpATRPeriod,1,atr) || !EMAValue(sym,PERIOD_M15,InpFastEMA,1,ema) ||
      !RecentHighLow(sym,PERIOD_M15,1,InpSwingBars,hi,lo) || atr<=0) return s;

   s.zoneLow = NormPrice(sym,ema-InpPullbackLowATR*atr);
   s.zoneHigh= NormPrice(sym,ema+InpPullbackHighATR*atr);
   s.preferred=NormPrice(sym,ema);
   if(bull) s.sl=NormPrice(sym,MathMin(lo,ema-InpStopATR*atr));
   else     s.sl=NormPrice(sym,MathMax(hi,ema+InpStopATR*atr));
   TargetsFromRisk(s);

   MqlTick t; if(!GetTickSafe(sym,t)) return s;
   double mid=(t.ask+t.bid)*0.5;
   bool notBroken=(bull ? mid>s.sl : mid<s.sl);
   bool notTooFar=(MathAbs(mid-s.preferred)<=2.25*atr);
   s.confidence=MathMin(95,baseConfidence+(notTooFar?5:-10));
   s.expiryM15=AdaptiveExpiry(sym,InpPullbackExpiryM15);
   s.valid=(notBroken && s.confidence>=InpMinConfidence && s.effectiveRR1>=InpMinEffectiveRR);
   s.reason=trendDetail+StringFormat(" | Pullback to M15 EMA%d; ATR %.5f.",InpFastEMA,atr);
   s.invalidation=(bull?"M15 close below pullback swing/SL or multi-TF bullish alignment breaks.":"M15 close above pullback swing/SL or multi-TF bearish alignment breaks.");
   s.failurePattern=(bull?"Failure: entry zone is accepted below, lower-high/lower-low sequence forms, or support fails before expansion.":"Failure: entry zone is accepted above, higher-low/higher-high sequence forms, or resistance fails before expansion.");
   s.executionRule="Enter only inside the zone after an M5 rejection/higher-low (long) or rejection/lower-high (short). Do not chase.";
   return s;
}

TradeSetup BuildBreakoutRetest(const string sym,bool bull,int baseConfidence,const string trendDetail)
{
   TradeSetup s; InitSetup(s,sym,SETUP_BREAKOUT_RETEST,bull);
   double atr=0,priorHi=0,priorLo=0,lastClose=0;
   if(!ATRValue(sym,PERIOD_M15,InpATRPeriod,1,atr) || atr<=0 ||
      !RecentHighLow(sym,PERIOD_M15,2,InpSwingBars,priorHi,priorLo) || !CloseValue(sym,PERIOD_M15,1,lastClose)) return s;

   double level=(bull?priorHi:priorLo);
   bool broke=(bull ? lastClose>level+InpBreakoutBufferATR*atr : lastClose<level-InpBreakoutBufferATR*atr);
   s.zoneLow=NormPrice(sym,level-InpRetestHalfWidthATR*atr);
   s.zoneHigh=NormPrice(sym,level+InpRetestHalfWidthATR*atr);
   s.preferred=NormPrice(sym,bull?level+0.03*atr:level-0.03*atr);
   if(bull) s.sl=NormPrice(sym,MathMin(priorLo,s.zoneLow-InpStopATR*atr));
   else     s.sl=NormPrice(sym,MathMax(priorHi,s.zoneHigh+InpStopATR*atr));
   TargetsFromRisk(s);

   MqlTick t; if(!GetTickSafe(sym,t)) return s;
   double mid=(t.ask+t.bid)*0.5;
   bool retestReasonable=(MathAbs(mid-level)<=1.50*atr);
   s.confidence=MathMin(97,baseConfidence+(broke?10:-18)+(retestReasonable?3:-8));
   s.expiryM15=AdaptiveExpiry(sym,InpBreakoutExpiryM15);
   s.valid=(broke && retestReasonable && s.confidence>=InpMinConfidence && s.effectiveRR1>=InpMinEffectiveRR);
   s.reason=trendDetail+StringFormat(" | Prior M15 level %.5f; breakout %s.",level,(broke?"CONFIRMED":"NOT confirmed"));
   s.invalidation=(bull?"M15 closes back below the broken resistance and cannot reclaim it on retest.":"M15 closes back above the broken support and cannot reject it on retest.");
   s.failurePattern=(bull?"Failure: false breakout—price closes back inside the old range, retest loses the level, then downside structure expands.":"Failure: false breakdown—price closes back inside the old range, retest loses the level, then upside structure expands.");
   s.executionRule="Require a completed M15 breakout first, then an M5/M15 retest that holds the broken level. No first-candle chasing.";
   return s;
}

int BaseConfidenceFromScore(int score,bool alignedBull,bool alignedBear,bool bull)
{
   double norm=MathMin(1.0,MathAbs(score)/42.0);
   int c=(int)MathRound(55+35*norm);
   bool aligned=(bull?alignedBull:alignedBear);
   if(aligned) c+=5; else c-=12;
   if(c<0)c=0; if(c>95)c=95; return c;
}

TradeSetup ChoosePrimary(TradeSetup &a,TradeSetup &b)
{
   if(a.valid && b.valid) return (b.confidence>a.confidence?b:a);
   if(a.valid) return a;
   if(b.valid) return b;
   return (a.confidence>=b.confidence?a:b);
}

// --------------------------- Lot sizing ---------------------------
double NormalizeVolumeDown(const string sym,double vol)
{
   double mn=SymbolInfoDouble(sym,SYMBOL_VOLUME_MIN);
   double mx=SymbolInfoDouble(sym,SYMBOL_VOLUME_MAX);
   double st=SymbolInfoDouble(sym,SYMBOL_VOLUME_STEP);
   if(st<=0) st=mn;
   vol=MathMin(vol,mx);
   vol=MathFloor(vol/st+1e-9)*st;
   if(vol<mn) return 0.0;
   int vd=2;
   if(st>=1.0) vd=0; else if(st>=0.1) vd=1; else if(st>=0.01) vd=2; else vd=3;
   return NormalizeDouble(vol,vd);
}

double LotSizeForRisk(const TradeSetup &s,double &riskMoney,double &oneLotLoss)
{
   double capital=(InpUseEquity?AccountInfoDouble(ACCOUNT_EQUITY):AccountInfoDouble(ACCOUNT_BALANCE));
   riskMoney=capital*InpRiskPercent/100.0;
   oneLotLoss=0;
   ENUM_ORDER_TYPE ot=(s.bullish?ORDER_TYPE_BUY:ORDER_TYPE_SELL);
   double loss=0;
   if(!OrderCalcProfit(ot,s.symbol,1.0,s.preferred,s.sl,loss)) return 0;
   oneLotLoss=MathAbs(loss);
   if(oneLotLoss<=0) return 0;
   return NormalizeVolumeDown(s.symbol,riskMoney/oneLotLoss);
}

// --------------------------- Signal card --------------------------
string DirText(bool bull){ return bull?"🟢 BULLISH — BUY":"🔴 BEARISH — SELL"; }
string Arrow(bool bull){ return bull?"LONG":"SHORT"; }
// ===== END INLINED GPT_EA_Part04.mqh =====
// ===== BEGIN INLINED GPT_EA_Part08_Advanced.mqh =====
// ============================================================================
// GPT_EA Part 08 - Advanced confluence, event horizon, dashboard and chart map
// ============================================================================

input bool   InpUseAdvancedConfluence      = true;
input int    InpMinAdvancedConfluence      = 76;
input bool   InpRequireHTFMajority          = true;
input int    InpADXPeriod                   = 14;
input double InpMinADX                      = 18.0;
input bool   InpUseLiquiditySweep           = true;
input bool   InpUseFairValueGap             = true;
input bool   InpUseVolumeImpulse            = true;
input double InpMinVolumeRatio              = 0.90;
input double InpMaxEntryDistanceATR         = 1.35;
input int    InpUpcomingEventHorizonMinutes = 480;
input bool   InpAICanVetoTrade              = true;
input bool   InpBlockIfAIUnavailable        = false;
input bool   InpDrawDashboard               = true;
input bool   InpDrawTradeLevels             = true;
input bool   InpPolishChart                 = true;
input int    InpDashboardX                  = 18;
input int    InpDashboardY                  = 20;

struct ConfluenceReport
{
   int    score;
   bool   valid;
   bool   htfAligned;
   int    htfVotes;
   double adx;
   double plusDI;
   double minusDI;
   double volumeRatio;
   double vwap;
   double atr;
   double openingRangeRatio;
   bool   structureAligned;
   bool   liquiditySweep;
   bool   fairValueGap;
   bool   rejectionCandle;
   bool   spreadOK;
   string summary;
};

string DASH_PANEL="GPT_EA_DASH_PANEL";
string DASH_TITLE="GPT_EA_DASH_TITLE";
string DASH_TEXT="GPT_EA_DASH_TEXT";
string BTN_SCAN_NOW="GPT_EA_SCAN_NOW";
string LEVEL_ENTRY="GPT_EA_LEVEL_ENTRY";
string LEVEL_SL="GPT_EA_LEVEL_SL";
string LEVEL_TP1="GPT_EA_LEVEL_TP1";
string LEVEL_TP2="GPT_EA_LEVEL_TP2";
string LEVEL_TP3="GPT_EA_LEVEL_TP3";
string ZONE_BOX="GPT_EA_ENTRY_ZONE";

bool ADXSnapshot(const string sym,ENUM_TIMEFRAMES tf,int period,double &adx,double &pdi,double &mdi)
{
   adx=pdi=mdi=0;
   int h=iADX(sym,tf,period);
   if(h==INVALID_HANDLE) return false;
   double a[],p[],m[];
   ArraySetAsSeries(a,true); ArraySetAsSeries(p,true); ArraySetAsSeries(m,true);
   bool ok=(CopyBuffer(h,0,1,1,a)==1 && CopyBuffer(h,1,1,1,p)==1 && CopyBuffer(h,2,1,1,m)==1);
   IndicatorRelease(h);
   if(!ok) return false;
   adx=a[0]; pdi=p[0]; mdi=m[0];
   return true;
}

int TrendVote(const string sym,ENUM_TIMEFRAMES tf,bool bull)
{
   double fast=0,slow=0,c=0;
   if(!EMAValue(sym,tf,InpFastEMA,1,fast) || !EMAValue(sym,tf,InpSlowEMA,1,slow) || !CloseValue(sym,tf,1,c)) return 0;
   if(bull && fast>slow && c>fast) return 1;
   if(!bull && fast<slow && c<fast) return 1;
   if(bull && fast<slow && c<fast) return -1;
   if(!bull && fast>slow && c>fast) return -1;
   return 0;
}

bool StructureAligned(const string sym,bool bull)
{
   double hi1=0,lo1=0,hi2=0,lo2=0;
   if(!RecentHighLow(sym,PERIOD_M15,1,6,hi1,lo1) || !RecentHighLow(sym,PERIOD_M15,7,6,hi2,lo2)) return false;
   if(bull) return (hi1>hi2 && lo1>lo2);
   return (hi1<hi2 && lo1<lo2);
}

bool LiquiditySweepAligned(const string sym,bool bull)
{
   MqlRates r[]; ArraySetAsSeries(r,true);
   if(CopyRates(sym,PERIOD_M15,1,14,r)<12) return false;
   double priorHi=-1.0e100,priorLo=1.0e100;
   for(int i=1;i<=10;i++)
   {
      if(r[i].high>priorHi) priorHi=r[i].high;
      if(r[i].low<priorLo) priorLo=r[i].low;
   }
   if(bull) return (r[0].low<priorLo && r[0].close>priorLo && r[0].close>r[0].open);
   return (r[0].high>priorHi && r[0].close<priorHi && r[0].close<r[0].open);
}

bool FVGAligned(const string sym,bool bull)
{
   MqlRates r[]; ArraySetAsSeries(r,true);
   if(CopyRates(sym,PERIOD_M15,1,8,r)<6) return false;
   for(int i=0;i<=3;i++)
   {
      if(bull && r[i].low>r[i+2].high) return true;
      if(!bull && r[i].high<r[i+2].low) return true;
   }
   return false;
}

bool M5RejectionAligned(const string sym,bool bull)
{
   MqlRates r[]; ArraySetAsSeries(r,true);
   if(CopyRates(sym,PERIOD_M5,1,2,r)<2) return false;
   double body=MathAbs(r[0].close-r[0].open);
   if(body<PointFor(sym)*2.0) body=PointFor(sym)*2.0;
   double lower=MathMin(r[0].open,r[0].close)-r[0].low;
   double upper=r[0].high-MathMax(r[0].open,r[0].close);
   if(bull) return (r[0].close>r[0].open && lower>=1.20*body);
   return (r[0].close<r[0].open && upper>=1.20*body);
}

double M5VolumeRatio(const string sym)
{
   MqlRates r[]; ArraySetAsSeries(r,true);
   int n=CopyRates(sym,PERIOD_M5,1,22,r);
   if(n<12) return 1.0;
   double avg=0;
   int cnt=0;
   for(int i=1;i<n;i++){ avg+=(double)r[i].tick_volume; cnt++; }
   if(cnt<=0 || avg<=0) return 1.0;
   avg/=cnt;
   return (double)r[0].tick_volume/avg;
}

double IntradayVWAP(const string sym)
{
   MqlRates r[]; ArraySetAsSeries(r,true);
   int n=CopyRates(sym,PERIOD_M5,1,72,r); // rolling six-hour institutional window
   if(n<=0) return 0;
   double pv=0,v=0;
   for(int i=0;i<n;i++)
   {
      double vol=(double)MathMax((long)1,r[i].tick_volume);
      double typical=(r[i].high+r[i].low+r[i].close)/3.0;
      pv+=typical*vol; v+=vol;
   }
   return (v>0?pv/v:0);
}

bool EMAImpulseAligned(const string sym,bool bull)
{
   double e1=0,e3=0,atr=0;
   if(!EMAValue(sym,PERIOD_M15,InpFastEMA,1,e1) || !EMAValue(sym,PERIOD_M15,InpFastEMA,3,e3) || !ATRValue(sym,PERIOD_M15,InpATRPeriod,1,atr) || atr<=0) return false;
   double slope=(e1-e3)/atr;
   return bull ? slope>0.06 : slope<-0.06;
}

string UpcomingEventSummary(const string sym)
{
   if(!InpUseEconomicCalendar) return "Upcoming events: calendar filter disabled.";
   if((bool)MQLInfoInteger(MQL_TESTER)) return "Upcoming events: native calendar unavailable in Strategy Tester.";
   string ccy=RelatedCurrencies(sym);
   if(ccy=="") return "Upcoming events: no mapped macro currency.";
   string curr[]; int nc=StringSplit(ccy,',',curr);
   datetime now=TimeTradeServer();
   datetime to=now+MathMax(60,InpUpcomingEventHorizonMinutes)*60;
   string out="Upcoming macro: ";
   int added=0;
   for(int c=0;c<nc && added<4;c++)
   {
      MqlCalendarValue vals[];
      int n=CalendarValueHistory(vals,now,to,NULL,curr[c]);
      if(n<=0) continue;
      for(int i=0;i<n && added<4;i++)
      {
         MqlCalendarEvent ev={};
         if(!CalendarEventById(vals[i].event_id,ev)) continue;
         if(ev.importance!=CALENDAR_IMPORTANCE_HIGH && ev.importance!=CALENDAR_IMPORTANCE_MODERATE) continue;
         int mins=(int)MathRound((vals[i].time-now)/60.0);
         if(added>0) out+=" | ";
         out+=StringFormat("%s %s %s %+dmin",curr[c],(ev.importance==CALENDAR_IMPORTANCE_HIGH?"HIGH":"MED"),ev.name,mins);
         added++;
      }
   }
   if(added==0) return "Upcoming macro: no high/moderate mapped events in horizon.";
   return out;
}

ConfluenceReport EvaluateConfluence(const TradeSetup &s)
{
   ConfluenceReport r;
   r.score=0; r.valid=true; r.htfAligned=false; r.htfVotes=0;
   r.adx=r.plusDI=r.minusDI=r.volumeRatio=r.vwap=r.atr=r.openingRangeRatio=0;
   r.structureAligned=r.liquiditySweep=r.fairValueGap=r.rejectionCandle=r.spreadOK=false;
   r.summary="";
   if(!s.valid && s.preferred<=0){ r.valid=false; return r; }

   int v1=TrendVote(s.symbol,PERIOD_D1,s.bullish);
   int v2=TrendVote(s.symbol,PERIOD_H4,s.bullish);
   int v3=TrendVote(s.symbol,PERIOD_H1,s.bullish);
   r.htfVotes=(v1>0?1:0)+(v2>0?1:0)+(v3>0?1:0);
   int opposing=(v1<0?1:0)+(v2<0?1:0)+(v3<0?1:0);
   r.htfAligned=(r.htfVotes>=2 && opposing==0);
   if(r.htfVotes==3) r.score+=20;
   else if(r.htfVotes==2) r.score+=14;
   else if(r.htfVotes==1) r.score+=6;

   r.structureAligned=StructureAligned(s.symbol,s.bullish);
   if(r.structureAligned) r.score+=15;
   else
   {
      double h1,l1,h2,l2;
      if(RecentHighLow(s.symbol,PERIOD_M5,1,6,h1,l1) && RecentHighLow(s.symbol,PERIOD_M5,7,6,h2,l2))
      {
         bool m5=(s.bullish?(h1>h2 && l1>l2):(h1<h2 && l1<l2));
         if(m5) r.score+=8;
      }
   }

   if(ADXSnapshot(s.symbol,PERIOD_M15,InpADXPeriod,r.adx,r.plusDI,r.minusDI))
   {
      bool diAligned=(s.bullish?r.plusDI>r.minusDI:r.minusDI>r.plusDI);
      if(r.adx>=InpMinADX && diAligned) r.score+=15;
      else if(diAligned) r.score+=8;
      else if(r.adx>=InpMinADX) r.score+=4;
   }

   double r15=50,r5=50;
   RSIValue(s.symbol,PERIOD_M15,InpRSIPeriod,1,r15);
   RSIValue(s.symbol,PERIOD_M5,InpRSIPeriod,1,r5);
   if(s.bullish)
   {
      if(r15>=52 && r5>=50) r.score+=12;
      else if(r15>=50) r.score+=6;
   }
   else
   {
      if(r15<=48 && r5<=50) r.score+=12;
      else if(r15<=50) r.score+=6;
   }

   r.liquiditySweep=LiquiditySweepAligned(s.symbol,s.bullish);
   if(!InpUseLiquiditySweep) r.score+=4;
   else if(r.liquiditySweep) r.score+=8;

   r.fairValueGap=FVGAligned(s.symbol,s.bullish);
   if(!InpUseFairValueGap) r.score+=2;
   else if(r.fairValueGap) r.score+=5;

   r.volumeRatio=M5VolumeRatio(s.symbol);
   if(!InpUseVolumeImpulse) r.score+=3;
   else if(r.volumeRatio>=InpMinVolumeRatio) r.score+=5;

   r.vwap=IntradayVWAP(s.symbol);
   MqlTick t; GetTickSafe(s.symbol,t);
   double mid=(t.ask+t.bid)*0.5;
   if(r.vwap>0 && (s.bullish?mid>=r.vwap:mid<=r.vwap)) r.score+=5;

   ATRValue(s.symbol,PERIOD_M15,InpATRPeriod,1,r.atr);
   double dist=(r.atr>0?MathAbs(mid-s.preferred)/r.atr:99.0);
   if(dist<=0.60) r.score+=5;
   else if(dist<=InpMaxEntryDistanceATR) r.score+=3;

   string spreadText="";
   r.spreadOK=SpreadOK(s.symbol,spreadText);
   if(r.spreadOK) r.score+=5;

   r.openingRangeRatio=OpeningRangeRatio(s.symbol);
   if(r.openingRangeRatio>=0.55 && r.openingRangeRatio<=1.80) r.score+=5;
   else if(r.openingRangeRatio<2.20) r.score+=2;

   if(EMAImpulseAligned(s.symbol,s.bullish)) r.score=MathMin(100,r.score+5);
   r.rejectionCandle=M5RejectionAligned(s.symbol,s.bullish);
   if(r.rejectionCandle) r.score=MathMin(100,r.score+3);
   if(r.score>100) r.score=100;

   bool hardHTF=(!InpRequireHTFMajority || r.htfAligned);
   bool proximity=(dist<=InpMaxEntryDistanceATR);
   r.valid=(hardHTF && proximity && r.spreadOK && r.score>=InpMinAdvancedConfluence);
   r.summary=StringFormat("Confluence %d/100 | HTF %d/3 | ADX %.1f (+DI %.1f / -DI %.1f) | Struct %s | Sweep %s | FVG %s | Vol %.2fx | OR %.2fx | M5 reject %s",
      r.score,r.htfVotes,r.adx,r.plusDI,r.minusDI,(r.structureAligned?"YES":"NO"),(r.liquiditySweep?"YES":"NO"),(r.fairValueGap?"YES":"NO"),r.volumeRatio,r.openingRangeRatio,(r.rejectionCandle?"YES":"NO"));
   return r;
}

void ApplyAdvancedConfluence(TradeSetup &s,const ConfluenceReport &r)
{
   if(!InpUseAdvancedConfluence) return;
   s.confidence=(int)MathRound(0.55*s.confidence+0.45*r.score);
   if(s.confidence>99) s.confidence=99;
   if(!r.valid || s.confidence<InpMinConfidence) s.valid=false;
   s.reason+=" | "+r.summary;
}

string ConfluenceCardBlock(const ConfluenceReport &r,const string upcoming,bool readyNow)
{
   string s="\n━━━━━━━━━━━━━━━━━━━━\n🎯 ADVANCED CONFLUENCE\n━━━━━━━━━━━━━━━━━━━━\n";
   s+=r.summary+"\n";
   s+=StringFormat("Entry trigger: %s\n",readyNow?"✅ PRICE IN ZONE + M5 TRIGGER READY":"⏳ WAITING FOR PRICE-ZONE + M5 TRIGGER");
   s+=upcoming+"\n";
   s+="Pinpoint rule: structure + HTF direction + momentum + execution-cost regime must agree; no single indicator can authorize a trade.\n";
   return s;
}

bool AIReviewAllowsExecution(const string aiText,bool aiAvailable,string &why)
{
   why="AI gate not required.";
   if(!InpAICanVetoTrade) return true;
   if(!aiAvailable)
   {
      why="AI review unavailable.";
      return !InpBlockIfAIUnavailable;
   }
   string u=aiText; StringToUpper(u);
   if(StringFind(u,"INVALID")>=0 || StringFind(u,"VERDICT: WAIT")>=0 || StringFind(u,"VERDICT (WAIT")>=0)
   {
      why="AI secondary review returned WAIT/INVALID.";
      return false;
   }
   why="AI review did not veto setup.";
   return true;
}

void DeleteTradeMap()
{
   ObjectDelete(0,LEVEL_ENTRY); ObjectDelete(0,LEVEL_SL); ObjectDelete(0,LEVEL_TP1);
   ObjectDelete(0,LEVEL_TP2); ObjectDelete(0,LEVEL_TP3); ObjectDelete(0,ZONE_BOX);
}

void SetHLine(const string name,double price,color c,ENUM_LINE_STYLE style,int width)
{
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_HLINE,0,0,price);
   ObjectSetDouble(0,name,OBJPROP_PRICE,price);
   ObjectSetInteger(0,name,OBJPROP_COLOR,c);
   ObjectSetInteger(0,name,OBJPROP_STYLE,style);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,width);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
}

void DrawTradeMap(const TradeSetup &s)
{
   if(!InpDrawTradeLevels || s.symbol!=_Symbol || s.preferred<=0){ if(s.symbol==_Symbol) DeleteTradeMap(); return; }
   SetHLine(LEVEL_ENTRY,s.preferred,clrGold,STYLE_SOLID,2);
   SetHLine(LEVEL_SL,s.sl,clrTomato,STYLE_SOLID,2);
   SetHLine(LEVEL_TP1,s.tp1,clrLimeGreen,STYLE_DASH,1);
   SetHLine(LEVEL_TP2,s.tp2,clrLimeGreen,STYLE_DASH,1);
   SetHLine(LEVEL_TP3,s.tp3,clrLimeGreen,STYLE_DOT,1);

   datetime left=TimeCurrent()-6*3600;
   datetime right=TimeCurrent()+6*3600;
   if(ObjectFind(0,ZONE_BOX)<0) ObjectCreate(0,ZONE_BOX,OBJ_RECTANGLE,0,left,s.zoneHigh,right,s.zoneLow);
   ObjectMove(0,ZONE_BOX,0,left,s.zoneHigh); ObjectMove(0,ZONE_BOX,1,right,s.zoneLow);
   ObjectSetInteger(0,ZONE_BOX,OBJPROP_COLOR,s.bullish?clrDarkGreen:clrMaroon);
   ObjectSetInteger(0,ZONE_BOX,OBJPROP_FILL,true);
   ObjectSetInteger(0,ZONE_BOX,OBJPROP_BACK,true);
   ObjectSetInteger(0,ZONE_BOX,OBJPROP_SELECTABLE,false);
}

void ApplyChartPolish()
{
   if(!InpPolishChart) return;
   ChartSetInteger(0,CHART_MODE,CHART_CANDLES);
   ChartSetInteger(0,CHART_SHOW_GRID,false);
   ChartSetInteger(0,CHART_COLOR_BACKGROUND,C'11,15,22');
   ChartSetInteger(0,CHART_COLOR_FOREGROUND,clrSilver);
   ChartSetInteger(0,CHART_COLOR_CHART_UP,C'35,196,131');
   ChartSetInteger(0,CHART_COLOR_CHART_DOWN,C'244,82,82');
   ChartSetInteger(0,CHART_COLOR_CANDLE_BULL,C'35,196,131');
   ChartSetInteger(0,CHART_COLOR_CANDLE_BEAR,C'244,82,82');
   ChartSetInteger(0,CHART_COLOR_VOLUME,C'83,100,130');
   ChartRedraw();
}

void StyleApprovalUI()
{
   if(ObjectFind(0,BTN_APPROVE)>=0)
   {
      ObjectSetInteger(0,BTN_APPROVE,OBJPROP_BGCOLOR,C'20,150,95');
      ObjectSetInteger(0,BTN_APPROVE,OBJPROP_COLOR,clrWhite);
      ObjectSetInteger(0,BTN_APPROVE,OBJPROP_BORDER_COLOR,C'45,210,140');
      ObjectSetInteger(0,BTN_APPROVE,OBJPROP_FONTSIZE,10);
   }
   if(ObjectFind(0,BTN_DENY)>=0)
   {
      ObjectSetInteger(0,BTN_DENY,OBJPROP_BGCOLOR,C'190,55,65');
      ObjectSetInteger(0,BTN_DENY,OBJPROP_COLOR,clrWhite);
      ObjectSetInteger(0,BTN_DENY,OBJPROP_BORDER_COLOR,C'245,95,105');
      ObjectSetInteger(0,BTN_DENY,OBJPROP_FONTSIZE,10);
   }
   if(ObjectFind(0,LBL_PROMPT)>=0)
   {
      ObjectSetInteger(0,LBL_PROMPT,OBJPROP_COLOR,clrWhiteSmoke);
      ObjectSetString(0,LBL_PROMPT,OBJPROP_FONT,"Arial");
   }
}

void DeleteAdvancedDashboard()
{
   ObjectDelete(0,DASH_PANEL); ObjectDelete(0,DASH_TITLE); ObjectDelete(0,DASH_TEXT); ObjectDelete(0,BTN_SCAN_NOW);
   DeleteTradeMap();
}

void RenderAdvancedDashboard(const TradeSetup &s,const ConfluenceReport &r,const string filterState,bool readyNow)
{
   if(!InpDrawDashboard) return;
   if(ObjectFind(0,DASH_PANEL)<0) ObjectCreate(0,DASH_PANEL,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,DASH_PANEL,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger(0,DASH_PANEL,OBJPROP_XDISTANCE,InpDashboardX);
   ObjectSetInteger(0,DASH_PANEL,OBJPROP_YDISTANCE,InpDashboardY);
   ObjectSetInteger(0,DASH_PANEL,OBJPROP_XSIZE,430);
   ObjectSetInteger(0,DASH_PANEL,OBJPROP_YSIZE,240);
   ObjectSetInteger(0,DASH_PANEL,OBJPROP_BGCOLOR,C'16,22,32');
   ObjectSetInteger(0,DASH_PANEL,OBJPROP_BORDER_COLOR,C'55,72,96');
   ObjectSetInteger(0,DASH_PANEL,OBJPROP_BACK,false);
   ObjectSetInteger(0,DASH_PANEL,OBJPROP_SELECTABLE,false);

   if(ObjectFind(0,DASH_TITLE)<0) ObjectCreate(0,DASH_TITLE,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,DASH_TITLE,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger(0,DASH_TITLE,OBJPROP_XDISTANCE,InpDashboardX+18);
   ObjectSetInteger(0,DASH_TITLE,OBJPROP_YDISTANCE,InpDashboardY+14);
   ObjectSetInteger(0,DASH_TITLE,OBJPROP_COLOR,C'88,200,255');
   ObjectSetInteger(0,DASH_TITLE,OBJPROP_FONTSIZE,12);
   ObjectSetString(0,DASH_TITLE,OBJPROP_FONT,"Arial Bold");
   ObjectSetString(0,DASH_TITLE,OBJPROP_TEXT,"GPT_EA  •  ADVANCED CONFLUENCE");

   if(ObjectFind(0,DASH_TEXT)<0) ObjectCreate(0,DASH_TEXT,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,DASH_TEXT,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger(0,DASH_TEXT,OBJPROP_XDISTANCE,InpDashboardX+18);
   ObjectSetInteger(0,DASH_TEXT,OBJPROP_YDISTANCE,InpDashboardY+48);
   ObjectSetInteger(0,DASH_TEXT,OBJPROP_COLOR,clrWhiteSmoke);
   ObjectSetInteger(0,DASH_TEXT,OBJPROP_FONTSIZE,9);
   ObjectSetString(0,DASH_TEXT,OBJPROP_FONT,"Arial");
   string dir=s.bullish?"LONG":"SHORT";
   string status=(s.valid && r.valid?"HIGH CONFLUENCE":"WAIT / FILTERED");
   string text=StringFormat("%s  |  %s  |  %s\nSetup: %s  |  Confidence: %d%%  |  Confluence: %d/100\nEntry zone: %.*f - %.*f  |  Preferred: %.*f\nSL: %.*f  |  TP1: %.*f  |  TP2: %.*f  |  TP3: %.*f\nADX: %.1f  |  Volume: %.2fx  |  Opening range: %.2fx\nEntry trigger: %s\n%s",
      s.symbol,dir,status,s.name,s.confidence,r.score,
      DigitsFor(s.symbol),s.zoneLow,DigitsFor(s.symbol),s.zoneHigh,DigitsFor(s.symbol),s.preferred,
      DigitsFor(s.symbol),s.sl,DigitsFor(s.symbol),s.tp1,DigitsFor(s.symbol),s.tp2,DigitsFor(s.symbol),s.tp3,
      r.adx,r.volumeRatio,r.openingRangeRatio,(readyNow?"READY":"WAITING"),filterState);
   ObjectSetString(0,DASH_TEXT,OBJPROP_TEXT,text);

   if(ObjectFind(0,BTN_SCAN_NOW)<0) ObjectCreate(0,BTN_SCAN_NOW,OBJ_BUTTON,0,0,0);
   ObjectSetInteger(0,BTN_SCAN_NOW,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger(0,BTN_SCAN_NOW,OBJPROP_XDISTANCE,InpDashboardX+18);
   ObjectSetInteger(0,BTN_SCAN_NOW,OBJPROP_YDISTANCE,InpDashboardY+198);
   ObjectSetInteger(0,BTN_SCAN_NOW,OBJPROP_XSIZE,120);
   ObjectSetInteger(0,BTN_SCAN_NOW,OBJPROP_YSIZE,26);
   ObjectSetInteger(0,BTN_SCAN_NOW,OBJPROP_BGCOLOR,C'36,92,160');
   ObjectSetInteger(0,BTN_SCAN_NOW,OBJPROP_COLOR,clrWhite);
   ObjectSetInteger(0,BTN_SCAN_NOW,OBJPROP_BORDER_COLOR,C'88,160,230');
   ObjectSetString(0,BTN_SCAN_NOW,OBJPROP_TEXT,"SCAN NOW");
   DrawTradeMap(s);
   StyleApprovalUI();
   ChartRedraw();
}
// ===== END INLINED GPT_EA_Part08_Advanced.mqh =====
// ===== BEGIN INLINED GPT_EA_Part09_RiskRecoveryAnalytics.mqh =====
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
// ===== END INLINED GPT_EA_Part09_RiskRecoveryAnalytics.mqh =====
// ===== BEGIN INLINED GPT_EA_Part44_ChaosFaultInjection.mqh =====
// ============================================================================
// GPT_EA Part 44 - Non-production chaos / fault-injection hooks
// ============================================================================
// Test-only. Fault injection is categorically disabled on REAL accounts.

input bool InpEnableChaosFaultInjection = false;
input int  InpChaosFaultScenario        = 0;
input bool InpChaosOneShot              = true;

enum ChaosFaultScenario
{
   CHAOS_NONE=0,
   CHAOS_API_TIMEOUT=1,
   CHAOS_STALE_QUOTE=2,
   CHAOS_STORAGE_WRITE_FAIL=3,
   CHAOS_BEFORE_ORDER_SEND_AMBIGUOUS=4,
   CHAOS_POST_FILL_PRE_BIND=5,
   CHAOS_DROP_TRADE_TRANSACTION=6,
   CHAOS_DUPLICATE_TRADE_TRANSACTION=7,
   CHAOS_STOP_MODIFY_FAIL=8,
   CHAOS_CORRUPT_CHECKPOINT=9,
   CHAOS_CONNECTION_LOSS=10
};

bool g_chaosConsumed=false;

string ChaosFaultName(int s)
{
   switch(s)
   {
      case CHAOS_API_TIMEOUT: return "API_TIMEOUT";
      case CHAOS_STALE_QUOTE: return "STALE_QUOTE";
      case CHAOS_STORAGE_WRITE_FAIL: return "STORAGE_WRITE_FAIL";
      case CHAOS_BEFORE_ORDER_SEND_AMBIGUOUS: return "BEFORE_ORDER_SEND_AMBIGUOUS";
      case CHAOS_POST_FILL_PRE_BIND: return "POST_FILL_PRE_BIND";
      case CHAOS_DROP_TRADE_TRANSACTION: return "DROP_TRADE_TRANSACTION";
      case CHAOS_DUPLICATE_TRADE_TRANSACTION: return "DUPLICATE_TRADE_TRANSACTION";
      case CHAOS_STOP_MODIFY_FAIL: return "STOP_MODIFY_FAIL";
      case CHAOS_CORRUPT_CHECKPOINT: return "CORRUPT_CHECKPOINT";
      case CHAOS_CONNECTION_LOSS: return "CONNECTION_LOSS";
      default: return "NONE";
   }
}

bool ChaosEnvironmentAllows()
{
   if(!InpEnableChaosFaultInjection) return false;
   if(AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_REAL) return false;
   return ((bool)MQLInfoInteger(MQL_TESTER) || AccountInfoInteger(ACCOUNT_TRADE_MODE)!=ACCOUNT_TRADE_MODE_REAL);
}

bool ChaosFaultHit(int scenario)
{
   if(!ChaosEnvironmentAllows() || InpChaosFaultScenario!=scenario) return false;
   if(InpChaosOneShot && g_chaosConsumed) return false;
   g_chaosConsumed=true;
   GVWrite(SysKey("CHAOS_ACTIVE_SAMPLE"),1);
   GVWrite(SysKey("CHAOS_LAST_SCENARIO"),scenario);
   GVWrite(SysKey("CHAOS_LAST_TIME"),(double)TimeTradeServer());
   Print("GPT_EA CHAOS INJECTION: ",ChaosFaultName(scenario));
   return true;
}

bool ChaosInjectAPITimeout(){ return ChaosFaultHit(CHAOS_API_TIMEOUT); }
bool ChaosInjectStaleQuote(){ return ChaosFaultHit(CHAOS_STALE_QUOTE); }
bool ChaosInjectStorageFailure(){ return ChaosFaultHit(CHAOS_STORAGE_WRITE_FAIL); }
bool ChaosInjectBeforeOrderSend(){ return ChaosFaultHit(CHAOS_BEFORE_ORDER_SEND_AMBIGUOUS); }
bool ChaosInjectPostFillPreBind(){ return ChaosFaultHit(CHAOS_POST_FILL_PRE_BIND); }
bool ChaosDropTradeTransaction(){ return ChaosFaultHit(CHAOS_DROP_TRADE_TRANSACTION); }
bool ChaosDuplicateTradeTransaction(){ return ChaosFaultHit(CHAOS_DUPLICATE_TRADE_TRANSACTION); }
bool ChaosInjectStopModifyFailure(){ return ChaosFaultHit(CHAOS_STOP_MODIFY_FAIL); }
bool ChaosInjectCorruptCheckpoint(){ return ChaosFaultHit(CHAOS_CORRUPT_CHECKPOINT); }
bool ChaosInjectConnectionLoss(){ return ChaosFaultHit(CHAOS_CONNECTION_LOSS); }

void ChaosResetForTest()
{
   if(AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_REAL) return;
   g_chaosConsumed=false;
   GVWrite(SysKey("CHAOS_ACTIVE_SAMPLE"),0);
}

void ChaosInit()
{
   if(InpEnableChaosFaultInjection && AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_REAL)
   {
      Print("GPT_EA CHAOS REFUSED: fault injection is disabled on REAL accounts.");
      g_chaosConsumed=true;
      return;
   }
   if(InpEnableChaosFaultInjection)
      Print("GPT_EA chaos test enabled: ",ChaosFaultName(InpChaosFaultScenario)," | one-shot=",InpChaosOneShot?"YES":"NO");
}
// ===== END INLINED GPT_EA_Part44_ChaosFaultInjection.mqh =====
// ===== BEGIN INLINED GPT_EA_Part10_BrokerUniversalRecovery.mqh =====
// ============================================================================
// GPT_EA Part 10 - Universal broker/symbol compatibility and hardened recovery
// ============================================================================

// --------------------------- Compatibility ---------------------------
input bool   InpAutoResolveBrokerSymbols      = true;
input bool   InpUseMarketWatchUniverse        = false;
input int    InpMaxMarketWatchSymbols         = 40;
input string InpAutoMajorUniverse             = "XAUUSD,XAGUSD,US100,US30,US500,GER40,UK100,JP225,EURUSD,GBPUSD,USDJPY,AUDUSD,USDCAD,USDCHF,NZDUSD,WTI,BRENT,BTCUSD,ETHUSD";
input bool   InpPrintBrokerSymbolProfiles     = true;
input bool   InpCheckBrokerExecutionRules     = true;
input double InpMaxNewTradeMarginPctFree      = 35.0;

// -------------------------- Recovery hardening ------------------------
input bool   InpUseRecoveryFileCheckpoint     = true;
input int    InpRecoveryCheckpointSeconds     = 60;
input string InpRecoveryCheckpointBase        = "GPT_EA_RecoveryState";
input bool   InpRejectRecoveryServerMismatch  = true;

// ----------------------------- Types ---------------------------------
enum GPTAssetClass
{
   GPT_ASSET_UNKNOWN=0,
   GPT_ASSET_FX=1,
   GPT_ASSET_METAL=2,
   GPT_ASSET_INDEX=3,
   GPT_ASSET_ENERGY=4,
   GPT_ASSET_CRYPTO=5,
   GPT_ASSET_STOCK=6,
   GPT_ASSET_OTHER=7
};

struct GPTSymbolProfile
{
   string symbol;
   string canonical;
   string assetClass;
   string description;
   string path;
   string baseCurrency;
   string profitCurrency;
   string marginCurrency;
   long   tradeMode;
   long   calcMode;
   long   fillingMode;
   long   accountLeverage;
   bool   spreadFloat;
   int    digits;
   int    stopsLevelPts;
   int    freezeLevelPts;
   double point;
   double tickSize;
   double tickValueProfit;
   double tickValueLoss;
   double contractSize;
   double volumeMin;
   double volumeMax;
   double volumeStep;
   double volumeLimit;
   double spreadPoints;
   double marginBuy1Lot;
   double marginSell1Lot;
   double initialMarginRateBuy;
   double maintenanceMarginRateBuy;
};

datetime g_lastUniversalCheckpoint=0;

// ----------------------- Symbol normalization -------------------------
string UpperCopy(string s){ StringToUpper(s); return s; }

string CleanSymbolToken(string s)
{
   StringToUpper(s);
   string chars[16]={".","_","-","#","/","\\"," ",":",";","@","!","+","*","(",")",","};
   for(int i=0;i<16;i++) StringReplace(s,chars[i],"");
   return s;
}

string CanonicalInstrumentKey(const string name,const string description="",const string path="")
{
   string u=UpperCopy(name+" "+description+" "+path);
   string c=CleanSymbolToken(name);

   // Metals
   if(StringFind(u,"XAU")>=0 || StringFind(u,"GOLD")>=0) return "METAL:XAU";
   if(StringFind(u,"XAG")>=0 || StringFind(u,"SILVER")>=0) return "METAL:XAG";
   if(StringFind(u,"XPT")>=0 || StringFind(u,"PLATINUM")>=0) return "METAL:XPT";
   if(StringFind(u,"XPD")>=0 || StringFind(u,"PALLADIUM")>=0) return "METAL:XPD";

   // Major global indices and common CFD aliases
   if(StringFind(u,"US100")>=0 || StringFind(u,"NAS100")>=0 || StringFind(u,"NASDAQ100")>=0 || StringFind(u,"USTEC")>=0 || StringFind(u,"NQ100")>=0) return "INDEX:US100";
   if(StringFind(u,"US30")>=0 || StringFind(u,"DJ30")>=0 || StringFind(u,"DOW30")>=0 || StringFind(u,"DOW JONES")>=0) return "INDEX:US30";
   if(StringFind(u,"US500")>=0 || StringFind(u,"SPX500")>=0 || StringFind(u,"SP500")>=0 || StringFind(u,"S&P 500")>=0) return "INDEX:US500";
   if(StringFind(u,"GER40")>=0 || StringFind(u,"DE40")>=0 || StringFind(u,"DAX40")>=0 || StringFind(u,"GERMANY 40")>=0) return "INDEX:GER40";
   if(StringFind(u,"UK100")>=0 || StringFind(u,"FTSE100")>=0) return "INDEX:UK100";
   if(StringFind(u,"JP225")>=0 || StringFind(u,"JPN225")>=0 || StringFind(u,"NIKKEI")>=0) return "INDEX:JP225";
   if(StringFind(u,"HK50")>=0 || StringFind(u,"HKG50")>=0 || StringFind(u,"HANG SENG")>=0) return "INDEX:HK50";
   if(StringFind(u,"AUS200")>=0 || StringFind(u,"AU200")>=0 || StringFind(u,"ASX200")>=0) return "INDEX:AUS200";
   if(StringFind(u,"FRA40")>=0 || StringFind(u,"FR40")>=0 || StringFind(u,"CAC40")>=0) return "INDEX:FRA40";
   if(StringFind(u,"EU50")>=0 || StringFind(u,"STOXX50")>=0 || StringFind(u,"EURO STOXX")>=0) return "INDEX:EU50";

   // Energy
   if(StringFind(u,"WTI")>=0 || StringFind(u,"USOIL")>=0 || StringFind(u,"WTICOIL")>=0 || StringFind(u,"WEST TEXAS")>=0) return "ENERGY:WTI";
   if(StringFind(u,"BRENT")>=0 || StringFind(u,"UKOIL")>=0) return "ENERGY:BRENT";
   if(StringFind(u,"NATGAS")>=0 || StringFind(u,"NATURAL GAS")>=0 || StringFind(u,"NGAS")>=0) return "ENERGY:NATGAS";

   // Crypto
   string crypto[10]={"BTC","ETH","SOL","XRP","ADA","DOGE","LTC","BNB","DOT","AVAX"};
   for(int k=0;k<10;k++) if(StringFind(u,crypto[k])>=0) return "CRYPTO:"+crypto[k];

   // FX - match any recognized currency pair in broker symbol, description or path.
   string cc[12]={"USD","EUR","GBP","JPY","CHF","CAD","AUD","NZD","NOK","SEK","SGD","CNH"};
   string compact=CleanSymbolToken(u);
   for(int i=0;i<12;i++)
      for(int j=0;j<12;j++)
         if(i!=j)
         {
            string pair=cc[i]+cc[j];
            if(StringFind(c,pair)>=0 || StringFind(compact,pair)>=0) return "FX:"+pair;
         }

   // Broker-specific stock/ETF/future names can still be suffix/prefix resolved by cleaned token.
   return "GEN:"+c;
}

string AssetClassFromCanonical(const string key)
{
   if(StringFind(key,"FX:")==0) return "FX";
   if(StringFind(key,"METAL:")==0) return "METAL";
   if(StringFind(key,"INDEX:")==0) return "INDEX";
   if(StringFind(key,"ENERGY:")==0) return "ENERGY";
   if(StringFind(key,"CRYPTO:")==0) return "CRYPTO";
   return "OTHER";
}

int BrokerSymbolCandidateScore(const string requested,const string candidate)
{
   if(requested==candidate) return 1000;
   string rq=CleanSymbolToken(requested);
   string ca=CleanSymbolToken(candidate);
   if(rq==ca) return 950;

   string rd="",rp="",cd="",cp="";
   SymbolInfoString(candidate,SYMBOL_DESCRIPTION,cd);
   SymbolInfoString(candidate,SYMBOL_PATH,cp);
   string rk=CanonicalInstrumentKey(requested,rd,rp);
   string ck=CanonicalInstrumentKey(candidate,cd,cp);
   if(rk==ck && StringFind(rk,"GEN:")!=0) return 900;

   if(StringLen(rq)>=3)
   {
      if(StringFind(ca,rq)==0 || StringFind(rq,ca)==0) return 820;
      if(StringFind(ca,rq)>=0) return 760;
      string dc=CleanSymbolToken(cd+cp);
      if(StringFind(dc,rq)>=0) return 620;
   }
   return 0;
}

string ResolveBrokerSymbol(const string requested)
{
   string r=Trim(requested);
   if(r=="") return "";
   if(EnsureSymbol(r)) return r;
   if(!InpAutoResolveBrokerSymbols) return "";

   int total=SymbolsTotal(false);
   int bestScore=0;
   string best="";
   for(int i=0;i<total;i++)
   {
      string cand=SymbolName(i,false);
      if(cand=="") continue;
      int sc=BrokerSymbolCandidateScore(r,cand);
      if(sc>bestScore){ bestScore=sc; best=cand; }
   }
   if(best!="" && bestScore>=620 && SymbolSelect(best,true))
   {
      PrintFormat("GPT_EA symbol resolver: '%s' -> '%s' (score %d)",r,best,bestScore);
      return best;
   }
   Print("GPT_EA symbol resolver could not resolve: ",r);
   return "";
}

bool ArrayContainsString(string &arr[],const string value)
{
   for(int i=0;i<ArraySize(arr);i++) if(arr[i]==value) return true;
   return false;
}

void AddResolvedSymbol(string &arr[],const string requested)
{
   string s=ResolveBrokerSymbol(requested);
   if(s=="" || ArrayContainsString(arr,s)) return;
   int n=ArraySize(arr); ArrayResize(arr,n+1); arr[n]=s;
}

bool ResolveConfiguredSymbolsUniversal()
{
   string resolved[];
   bool autoRequested=false;
   for(int i=0;i<ArraySize(g_symbols);i++)
   {
      string u=UpperCopy(Trim(g_symbols[i]));
      if(u=="AUTO" || u=="ALL") { autoRequested=true; continue; }
      AddResolvedSymbol(resolved,g_symbols[i]);
   }

   if(autoRequested)
   {
      string majors[]; int n=StringSplit(InpAutoMajorUniverse,',',majors);
      for(int i=0;i<n;i++) AddResolvedSymbol(resolved,Trim(majors[i]));
   }

   if(InpUseMarketWatchUniverse)
   {
      int total=SymbolsTotal(true);
      int cap=MathMax(1,InpMaxMarketWatchSymbols);
      for(int i=0;i<total && ArraySize(resolved)<cap;i++)
      {
         string s=SymbolName(i,true);
         if(s=="") continue;
         long tm=SymbolInfoInteger(s,SYMBOL_TRADE_MODE);
         if(tm==SYMBOL_TRADE_MODE_DISABLED) continue;
         if(!ArrayContainsString(resolved,s))
         { int z=ArraySize(resolved); ArrayResize(resolved,z+1); resolved[z]=s; }
      }
   }

   if(ArraySize(resolved)<=0) return false;
   ArrayResize(g_symbols,ArraySize(resolved));
   for(int i=0;i<ArraySize(resolved);i++) g_symbols[i]=resolved[i];
   return true;
}

// ----------------------- Broker/symbol profile ------------------------
double NormalizePriceToTick(const string sym,double price)
{
   double ts=SymbolInfoDouble(sym,SYMBOL_TRADE_TICK_SIZE);
   if(ts<=0) ts=PointFor(sym);
   if(ts<=0) return NormPrice(sym,price);
   double p=MathRound(price/ts)*ts;
   return NormalizeDouble(p,DigitsFor(sym));
}

bool LoadSymbolProfile(const string sym,GPTSymbolProfile &p)
{
   if(!EnsureSymbol(sym)) return false;
   p.symbol=sym;
   p.description=SymbolInfoString(sym,SYMBOL_DESCRIPTION);
   p.path=SymbolInfoString(sym,SYMBOL_PATH);
   p.canonical=CanonicalInstrumentKey(sym,p.description,p.path);
   p.assetClass=AssetClassFromCanonical(p.canonical);
   p.baseCurrency=SymbolInfoString(sym,SYMBOL_CURRENCY_BASE);
   p.profitCurrency=SymbolInfoString(sym,SYMBOL_CURRENCY_PROFIT);
   p.marginCurrency=SymbolInfoString(sym,SYMBOL_CURRENCY_MARGIN);
   p.tradeMode=SymbolInfoInteger(sym,SYMBOL_TRADE_MODE);
   p.calcMode=SymbolInfoInteger(sym,SYMBOL_TRADE_CALC_MODE);
   p.fillingMode=SymbolInfoInteger(sym,SYMBOL_FILLING_MODE);
   p.accountLeverage=AccountInfoInteger(ACCOUNT_LEVERAGE);
   p.spreadFloat=(bool)SymbolInfoInteger(sym,SYMBOL_SPREAD_FLOAT);
   p.digits=(int)SymbolInfoInteger(sym,SYMBOL_DIGITS);
   p.stopsLevelPts=(int)SymbolInfoInteger(sym,SYMBOL_TRADE_STOPS_LEVEL);
   p.freezeLevelPts=(int)SymbolInfoInteger(sym,SYMBOL_TRADE_FREEZE_LEVEL);
   p.point=SymbolInfoDouble(sym,SYMBOL_POINT);
   p.tickSize=SymbolInfoDouble(sym,SYMBOL_TRADE_TICK_SIZE);
   p.tickValueProfit=SymbolInfoDouble(sym,SYMBOL_TRADE_TICK_VALUE_PROFIT);
   p.tickValueLoss=SymbolInfoDouble(sym,SYMBOL_TRADE_TICK_VALUE_LOSS);
   p.contractSize=SymbolInfoDouble(sym,SYMBOL_TRADE_CONTRACT_SIZE);
   p.volumeMin=SymbolInfoDouble(sym,SYMBOL_VOLUME_MIN);
   p.volumeMax=SymbolInfoDouble(sym,SYMBOL_VOLUME_MAX);
   p.volumeStep=SymbolInfoDouble(sym,SYMBOL_VOLUME_STEP);
   p.volumeLimit=SymbolInfoDouble(sym,SYMBOL_VOLUME_LIMIT);
   p.marginBuy1Lot=0; p.marginSell1Lot=0;
   p.initialMarginRateBuy=0; p.maintenanceMarginRateBuy=0;

   MqlTick t;
   if(SymbolInfoTick(sym,t) && p.point>0)
   {
      p.spreadPoints=MathMax(0.0,(t.ask-t.bid)/p.point);
      OrderCalcMargin(ORDER_TYPE_BUY,sym,1.0,t.ask,p.marginBuy1Lot);
      OrderCalcMargin(ORDER_TYPE_SELL,sym,1.0,t.bid,p.marginSell1Lot);
   }
   else p.spreadPoints=0;
   SymbolInfoMarginRate(sym,ORDER_TYPE_BUY,p.initialMarginRateBuy,p.maintenanceMarginRateBuy);
   return true;
}

string BrokerEnvironmentSummary()
{
   return StringFormat("Broker %s | Server %s | Account currency %s | Account leverage 1:%I64d | Margin mode %d",
      AccountInfoString(ACCOUNT_COMPANY),AccountInfoString(ACCOUNT_SERVER),AccountInfoString(ACCOUNT_CURRENCY),
      AccountInfoInteger(ACCOUNT_LEVERAGE),(int)AccountInfoInteger(ACCOUNT_MARGIN_MODE));
}

string SymbolProfileSummary(const string sym)
{
   GPTSymbolProfile p;
   if(!LoadSymbolProfile(sym,p)) return "Symbol profile unavailable.";
   return StringFormat("%s [%s/%s] | spread %.1f pts (%s) | tick %.8f | contract %.2f | vol %.3f/%.3f/%.3f | stop %d pts | margin 1L buy %.2f sell %.2f %s",
      p.symbol,p.assetClass,p.canonical,p.spreadPoints,p.spreadFloat?"floating":"fixed",
      p.tickSize,p.contractSize,p.volumeMin,p.volumeStep,p.volumeMax,p.stopsLevelPts,
      p.marginBuy1Lot,p.marginSell1Lot,AccountInfoString(ACCOUNT_CURRENCY));
}

void PrintResolvedBrokerProfiles()
{
   Print("GPT_EA broker environment: ",BrokerEnvironmentSummary());
   if(!InpPrintBrokerSymbolProfiles) return;
   for(int i=0;i<ArraySize(g_symbols);i++) Print("GPT_EA profile: ",SymbolProfileSummary(g_symbols[i]));
}

double DirectionalVolume(const string sym,bool bull)
{
   double vol=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=sym) continue;
      long pt=PositionGetInteger(POSITION_TYPE);
      if((bull && pt==POSITION_TYPE_BUY) || (!bull && pt==POSITION_TYPE_SELL)) vol+=PositionGetDouble(POSITION_VOLUME);
   }
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong ot=OrderGetTicket(i); if(ot==0) continue;
      if(OrderGetString(ORDER_SYMBOL)!=sym) continue;
      ENUM_ORDER_TYPE type=(ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      bool longSide=(type==ORDER_TYPE_BUY || type==ORDER_TYPE_BUY_LIMIT || type==ORDER_TYPE_BUY_STOP || type==ORDER_TYPE_BUY_STOP_LIMIT);
      bool shortSide=(type==ORDER_TYPE_SELL || type==ORDER_TYPE_SELL_LIMIT || type==ORDER_TYPE_SELL_STOP || type==ORDER_TYPE_SELL_STOP_LIMIT);
      if((bull && longSide) || (!bull && shortSide)) vol+=OrderGetDouble(ORDER_VOLUME_CURRENT);
   }
   return vol;
}

bool BrokerExecutionAllows(const TradeSetup &s,double lots,string &why)
{
   why="";
   if(!InpCheckBrokerExecutionRules){ why="Broker execution-rule gate disabled."; return true; }
   if(!EnsureSymbol(s.symbol)){ why="Symbol unavailable at broker."; return false; }
   if(!(bool)AccountInfoInteger(ACCOUNT_TRADE_ALLOWED)){ why="Account trading is disabled."; return false; }
   if(!(bool)AccountInfoInteger(ACCOUNT_TRADE_EXPERT)){ why="Expert Advisor trading is disabled for account."; return false; }

   ENUM_SYMBOL_TRADE_MODE mode=(ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(s.symbol,SYMBOL_TRADE_MODE);
   if(mode==SYMBOL_TRADE_MODE_DISABLED){ why="Symbol trading is disabled."; return false; }
   if(mode==SYMBOL_TRADE_MODE_CLOSEONLY){ why="Symbol is close-only."; return false; }
   if(s.bullish && mode==SYMBOL_TRADE_MODE_SHORTONLY){ why="Broker symbol is short-only."; return false; }
   if(!s.bullish && mode==SYMBOL_TRADE_MODE_LONGONLY){ why="Broker symbol is long-only."; return false; }

   double mn=SymbolInfoDouble(s.symbol,SYMBOL_VOLUME_MIN);
   double mx=SymbolInfoDouble(s.symbol,SYMBOL_VOLUME_MAX);
   double st=SymbolInfoDouble(s.symbol,SYMBOL_VOLUME_STEP);
   double lim=SymbolInfoDouble(s.symbol,SYMBOL_VOLUME_LIMIT);
   if(lots<mn-1e-9 || lots>mx+1e-9){ why=StringFormat("Lot %.3f outside broker range %.3f..%.3f.",lots,mn,mx); return false; }
   if(st>0)
   {
      double snapped=MathFloor(lots/st+1e-8)*st;
      if(MathAbs(snapped-lots)>st*0.01){ why="Lot size does not match broker volume step."; return false; }
   }
   if(lim>0 && DirectionalVolume(s.symbol,s.bullish)+lots>lim+1e-9)
   { why=StringFormat("Directional volume limit %.3f lots would be exceeded.",lim); return false; }

   MqlTick t; if(!GetTickSafe(s.symbol,t)){ why="No current broker tick."; return false; }
   double px=(s.bullish?t.ask:t.bid);
   double pt=PointFor(s.symbol);
   int stops=(int)SymbolInfoInteger(s.symbol,SYMBOL_TRADE_STOPS_LEVEL);
   double minStop=stops*pt;
   if(minStop>0)
   {
      if(MathAbs(px-s.sl)+1e-12<minStop){ why=StringFormat("SL inside broker minimum stop distance (%d pts).",stops); return false; }
      if(MathAbs(s.tp3-px)+1e-12<minStop){ why=StringFormat("TP inside broker minimum stop distance (%d pts).",stops); return false; }
   }

   ENUM_ORDER_TYPE ot=(s.bullish?ORDER_TYPE_BUY:ORDER_TYPE_SELL);
   double margin=0;
   if(!OrderCalcMargin(ot,s.symbol,lots,px,margin))
   { why=StringFormat("OrderCalcMargin failed (%d).",GetLastError()); return false; }
   double free=AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   if(margin>free+1e-8){ why=StringFormat("Required margin %.2f exceeds free margin %.2f.",margin,free); return false; }
   if(InpMaxNewTradeMarginPctFree>0 && free>0 && margin/free*100.0>InpMaxNewTradeMarginPctFree)
   { why=StringFormat("New-trade margin %.2f%% of free margin exceeds %.2f%% cap.",margin/free*100.0,InpMaxNewTradeMarginPctFree); return false; }

   why=StringFormat("Broker gate OK | margin %.2f %s | spread %.1f pts | account leverage 1:%I64d",
      margin,AccountInfoString(ACCOUNT_CURRENCY),(t.ask-t.bid)/MathMax(pt,1e-12),AccountInfoInteger(ACCOUNT_LEVERAGE));
   return true;
}

// ------------------------- Recovery helpers ---------------------------
string RecoveryStateFileName()
{
   return StringFormat("%s_%I64d_%I64d.csv",InpRecoveryCheckpointBase,AccountInfoInteger(ACCOUNT_LOGIN),InpMagic);
}

string LegacyTicketKey(ulong ticket,const string suffix){ return StringFormat("CGPT_%I64u_%s",ticket,suffix); }
double LegacyTicketRead(ulong ticket,const string suffix,double def=0)
{
   string k=LegacyTicketKey(ticket,suffix); return GlobalVariableCheck(k)?GlobalVariableGet(k):def;
}
void LegacyTicketWrite(ulong ticket,const string suffix,double v){ GlobalVariableSet(LegacyTicketKey(ticket,suffix),v); }

ulong FindOpenTicketByIdentifier(ulong pid)
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0 || !PositionSelectByTicket(tk)) continue;
      if((ulong)PositionGetInteger(POSITION_IDENTIFIER)==pid) return tk;
   }
   return 0;
}

bool PositionHistoryHadExit(ulong pid)
{
   if(!HistorySelectByPosition(pid)) return false;
   int total=HistoryDealsTotal();
   for(int i=0;i<total;i++)
   {
      ulong d=HistoryDealGetTicket(i); if(d==0) continue;
      ENUM_DEAL_ENTRY e=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(d,DEAL_ENTRY);
      if(e==DEAL_ENTRY_OUT || e==DEAL_ENTRY_OUT_BY) return true;
   }
   return false;
}

double HistoricalInitialSL(ulong pid)
{
   if(!HistorySelectByPosition(pid)) return 0;
   datetime first=0; double sl=0;
   int n=HistoryOrdersTotal();
   for(int i=0;i<n;i++)
   {
      ulong o=HistoryOrderGetTicket(i); if(o==0) continue;
      ENUM_ORDER_TYPE t=(ENUM_ORDER_TYPE)HistoryOrderGetInteger(o,ORDER_TYPE);
      if(t!=ORDER_TYPE_BUY && t!=ORDER_TYPE_SELL) continue;
      datetime tm=(datetime)HistoryOrderGetInteger(o,ORDER_TIME_SETUP);
      double candidate=HistoryOrderGetDouble(o,ORDER_SL);
      if(candidate<=0) continue;
      if(first==0 || tm<first){ first=tm; sl=candidate; }
   }
   return sl;
}

double HistoricalInitialVolume(ulong pid)
{
   if(!HistorySelectByPosition(pid)) return 0;
   double v=0;
   int n=HistoryDealsTotal();
   for(int i=0;i<n;i++)
   {
      ulong d=HistoryDealGetTicket(i); if(d==0) continue;
      ENUM_DEAL_ENTRY e=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(d,DEAL_ENTRY);
      ENUM_DEAL_TYPE t=(ENUM_DEAL_TYPE)HistoryDealGetInteger(d,DEAL_TYPE);
      if((e==DEAL_ENTRY_IN || e==DEAL_ENTRY_INOUT) && (t==DEAL_TYPE_BUY || t==DEAL_TYPE_SELL))
         v+=HistoryDealGetDouble(d,DEAL_VOLUME);
   }
   return v;
}

void ReconcileOpenPositionRecovery()
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
      string sym=PositionGetString(POSITION_SYMBOL);
      bool bull=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
      double entry=PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSL=PositionGetDouble(POSITION_SL);

      int kind=(int)GVRead(PosKey(pid,"KIND"),0);
      if(kind<=0)
      {
         string c=PositionGetString(POSITION_COMMENT);
         kind=(StringFind(c,"BR")>=0?SETUP_BREAKOUT_RETEST:SETUP_PULLBACK);
         GVWrite(PosKey(pid,"KIND"),kind);
      }

      double initSL=GVRead(PosKey(pid,"INITSL"),LegacyTicketRead(tk,"INITSL",0));
      if(initSL<=0) initSL=HistoricalInitialSL(pid);
      if(initSL<=0) initSL=currentSL;
      if(initSL>0)
      {
         GVWrite(PosKey(pid,"INITSL"),initSL);
         LegacyTicketWrite(tk,"INITSL",initSL);
      }

      double unit=MathAbs(entry-initSL);
      if(unit>0)
      {
         double tp1=LegacyTicketRead(tk,"TP1",bull?entry+unit:entry-unit);
         double tp2=LegacyTicketRead(tk,"TP2",bull?entry+2*unit:entry-2*unit);
         double tp3=LegacyTicketRead(tk,"TP3",bull?entry+3*unit:entry-3*unit);
         LegacyTicketWrite(tk,"TP1",NormalizePriceToTick(sym,tp1));
         LegacyTicketWrite(tk,"TP2",NormalizePriceToTick(sym,tp2));
         LegacyTicketWrite(tk,"TP3",NormalizePriceToTick(sym,tp3));
      }

      int exp=(int)LegacyTicketRead(tk,"EXP",0);
      if(exp<=0) LegacyTicketWrite(tk,"EXP",AdaptiveExpiry(sym,kind==SETUP_BREAKOUT_RETEST?InpBreakoutExpiryM15:InpPullbackExpiryM15));

      bool tp1done=(LegacyTicketRead(tk,"TP1DONE",0)>0.5);
      if(!tp1done)
      {
         bool beMoved=(currentSL>0 && (bull?currentSL>=entry:currentSL<=entry));
         bool hadExit=PositionHistoryHadExit(pid);
         if(beMoved || hadExit) LegacyTicketWrite(tk,"TP1DONE",1);
      }

      if(GVRead(PosKey(pid,"ENTRY"),0)<=0) GVWrite(PosKey(pid,"ENTRY"),entry);
      if(GVRead(PosKey(pid,"OPEN_TIME"),0)<=0) GVWrite(PosKey(pid,"OPEN_TIME"),(double)PositionGetInteger(POSITION_TIME));
      if(GVRead(PosKey(pid,"REQUESTED"),0)<=0) GVWrite(PosKey(pid,"REQUESTED"),entry);
      if(GVRead(PosKey(pid,"RISK"),0)<=0 && initSL>0)
      {
         double iv=HistoricalInitialVolume(pid); if(iv<=0) iv=PositionGetDouble(POSITION_VOLUME);
         double loss=0; ENUM_ORDER_TYPE ot=(bull?ORDER_TYPE_BUY:ORDER_TYPE_SELL);
         if(OrderCalcProfit(ot,sym,iv,entry,initSL,loss)) GVWrite(PosKey(pid,"RISK"),MathAbs(loss));
      }
   }
}

void WriteUniversalRecoveryCheckpoint()
{
   if(!InpUseRecoveryFileCheckpoint) return;
   GlobalVariablesFlush();
   int h=FileOpen(RecoveryStateFileName(),FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(h==INVALID_HANDLE){ Print("GPT_EA recovery checkpoint open failed: ",GetLastError()); return; }

   FileWrite(h,"META","2",(string)AccountInfoInteger(ACCOUNT_LOGIN),AccountInfoString(ACCOUNT_SERVER),(string)InpMagic,TimeToString(TimeTradeServer(),TIME_DATE|TIME_SECONDS));
   FileWrite(h,"RISK",(string)g_dayKey,DoubleToString(g_dayStartEquity,8),DoubleToString(g_equityPeak,8),g_manualPaused?"1":"0",(string)ConsecutiveLosses());

   for(int i=0;i<ArraySize(g_pending);i++)
   {
      if(!g_pending[i].active) continue;
      TradeSetup s=g_pending[i].setup;
      FileWrite(h,"PENDING",s.symbol,s.bullish?"1":"0",(string)s.kind,
         DoubleToString(s.zoneLow,DigitsFor(s.symbol)),DoubleToString(s.zoneHigh,DigitsFor(s.symbol)),DoubleToString(s.preferred,DigitsFor(s.symbol)),
         DoubleToString(s.sl,DigitsFor(s.symbol)),DoubleToString(s.tp1,DigitsFor(s.symbol)),DoubleToString(s.tp2,DigitsFor(s.symbol)),DoubleToString(s.tp3,DigitsFor(s.symbol)),
         (string)s.confidence,(string)s.expiryM15,(string)g_pending[i].createdAt,(string)g_pending[i].expiresAt);
   }

   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
      string sym=PositionGetString(POSITION_SYMBOL);
      FileWrite(h,"POSITION",(string)pid,(string)tk,sym,(string)PositionGetInteger(POSITION_TYPE),
         DoubleToString(PositionGetDouble(POSITION_VOLUME),4),DoubleToString(PositionGetDouble(POSITION_PRICE_OPEN),DigitsFor(sym)),
         DoubleToString(PositionGetDouble(POSITION_SL),DigitsFor(sym)),DoubleToString(PositionGetDouble(POSITION_TP),DigitsFor(sym)),
         (string)(int)GVRead(PosKey(pid,"KIND"),SETUP_PULLBACK),DoubleToString(GVRead(PosKey(pid,"INITSL"),LegacyTicketRead(tk,"INITSL",0)),DigitsFor(sym)),
         DoubleToString(LegacyTicketRead(tk,"TP1",0),DigitsFor(sym)),DoubleToString(LegacyTicketRead(tk,"TP2",0),DigitsFor(sym)),DoubleToString(LegacyTicketRead(tk,"TP3",0),DigitsFor(sym)),
         (string)(int)LegacyTicketRead(tk,"EXP",0),(string)(int)LegacyTicketRead(tk,"TP1DONE",0),
         DoubleToString(GVRead(PosKey(pid,"RISK"),0),8),DoubleToString(GVRead(PosKey(pid,"REQUESTED"),0),DigitsFor(sym)),
         DoubleToString(GVRead(PosKey(pid,"SLIP"),0),4),DoubleToString(GVRead(PosKey(pid,"MAE"),0),4),DoubleToString(GVRead(PosKey(pid,"MFE"),0),4),
         (string)(int)GVRead(PosKey(pid,"FINAL"),0));
   }
   FileClose(h);
   g_lastUniversalCheckpoint=TimeTradeServer();
}

void RestoreUniversalRecoveryCheckpoint()
{
   if(!InpUseRecoveryFileCheckpoint) return;
   if(ChaosInjectCorruptCheckpoint())
   {
      GVWrite(SysKey("RECOVERY_CHECKPOINT_ANOMALY"),1);
      GVWrite(SysKey("RECOVERY_CHECKPOINT_ANOMALY_TIME"),(double)TimeTradeServer());
      Print("GPT_EA CHAOS: simulated corrupted recovery checkpoint; disk restore refused and broker/GV reconciliation remains authoritative.");
      return;
   }
   int h=FileOpen(RecoveryStateFileName(),FILE_READ|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(h==INVALID_HANDLE) return;

   if(FileIsEnding(h)){ FileClose(h); return; }
   string row=FileReadString(h);
   if(row!="META"){ FileClose(h); return; }
   int version=(int)StringToInteger(FileReadString(h));
   long login=(long)StringToInteger(FileReadString(h));
   string server=FileReadString(h);
   long magic=(long)StringToInteger(FileReadString(h));
   string snapshotTime=FileReadString(h);
   if(version<2 || login!=AccountInfoInteger(ACCOUNT_LOGIN) || magic!=InpMagic ||
      (InpRejectRecoveryServerMismatch && server!=AccountInfoString(ACCOUNT_SERVER)))
   {
      Print("GPT_EA ignored recovery file due to account/server/magic mismatch. Snapshot=",snapshotTime);
      FileClose(h); return;
   }

   while(!FileIsEnding(h))
   {
      string type=FileReadString(h);
      if(type=="") continue;
      if(type=="RISK")
      {
         int day=(int)StringToInteger(FileReadString(h));
         double de=StringToDouble(FileReadString(h));
         double peak=StringToDouble(FileReadString(h));
         bool paused=(StringToInteger(FileReadString(h))!=0);
         int losses=(int)StringToInteger(FileReadString(h));
         if(!GlobalVariableCheck(SysKey("DAYKEY"))) GVWrite(SysKey("DAYKEY"),day);
         if(!GlobalVariableCheck(SysKey("DAYSTART_EQ"))) GVWrite(SysKey("DAYSTART_EQ"),de);
         if(!GlobalVariableCheck(SysKey("EQUITY_PEAK"))) GVWrite(SysKey("EQUITY_PEAK"),peak);
         if(!GlobalVariableCheck(SysKey("PAUSED"))) GVWrite(SysKey("PAUSED"),paused?1:0);
         if(!GlobalVariableCheck(SysKey("CONSEC_LOSS"))) GVWrite(SysKey("CONSEC_LOSS"),losses);
      }
      else if(type=="PENDING")
      {
         string oldSym=FileReadString(h);
         bool bull=(StringToInteger(FileReadString(h))!=0);
         int kind=(int)StringToInteger(FileReadString(h));
         double zl=StringToDouble(FileReadString(h)),zh=StringToDouble(FileReadString(h)),pref=StringToDouble(FileReadString(h));
         double sl=StringToDouble(FileReadString(h)),tp1=StringToDouble(FileReadString(h)),tp2=StringToDouble(FileReadString(h)),tp3=StringToDouble(FileReadString(h));
         int conf=(int)StringToInteger(FileReadString(h)),exp=(int)StringToInteger(FileReadString(h));
         datetime created=(datetime)StringToInteger(FileReadString(h)),expires=(datetime)StringToInteger(FileReadString(h));
         string sym=ResolveBrokerSymbol(oldSym);
         if(sym=="") continue;
         if(expires<=TimeTradeServer()){ MarkSignalCooldown(sym); continue; }
         bool exists=false;
         for(int p=0;p<ArraySize(g_pending);p++) if(g_pending[p].active && g_pending[p].setup.symbol==sym){ exists=true; break; }
         if(exists) continue;
         TradeSetup s; InitSetup(s,sym,(SetupKind)kind,bull);
         s.valid=true; s.zoneLow=zl; s.zoneHigh=zh; s.preferred=pref; s.sl=sl; s.tp1=tp1; s.tp2=tp2; s.tp3=tp3; s.confidence=conf; s.expiryM15=exp;
         int n=ArraySize(g_pending); ArrayResize(g_pending,n+1);
         g_pending[n].active=true; g_pending[n].setup=s; g_pending[n].card="Recovered from disk checkpoint";
         g_pending[n].scanReason="Disk recovery"; g_pending[n].createdAt=created; g_pending[n].expiresAt=expires;
      }
      else if(type=="POSITION")
      {
         ulong pid=(ulong)StringToInteger(FileReadString(h));
         ulong oldTicket=(ulong)StringToInteger(FileReadString(h));
         string oldSym=FileReadString(h);
         long ptype=(long)StringToInteger(FileReadString(h));
         double volume=StringToDouble(FileReadString(h));
         double entry=StringToDouble(FileReadString(h));
         double csl=StringToDouble(FileReadString(h));
         double ctp=StringToDouble(FileReadString(h));
         int kind=(int)StringToInteger(FileReadString(h));
         double initSL=StringToDouble(FileReadString(h));
         double tp1=StringToDouble(FileReadString(h)),tp2=StringToDouble(FileReadString(h)),tp3=StringToDouble(FileReadString(h));
         int exp=(int)StringToInteger(FileReadString(h)),tp1done=(int)StringToInteger(FileReadString(h));
         double risk=StringToDouble(FileReadString(h)),requested=StringToDouble(FileReadString(h)),slip=StringToDouble(FileReadString(h));
         double mae=StringToDouble(FileReadString(h)),mfe=StringToDouble(FileReadString(h));
         int finalFlag=(int)StringToInteger(FileReadString(h));
         ulong tk=FindOpenTicketByIdentifier(pid);
         if(tk==0 || !PositionSelectByTicket(tk)) continue;
         if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
         if(GVRead(PosKey(pid,"KIND"),0)<=0) GVWrite(PosKey(pid,"KIND"),kind);
         if(GVRead(PosKey(pid,"INITSL"),0)<=0) GVWrite(PosKey(pid,"INITSL"),initSL);
         if(GVRead(PosKey(pid,"ENTRY"),0)<=0) GVWrite(PosKey(pid,"ENTRY"),entry);
         if(GVRead(PosKey(pid,"RISK"),0)<=0) GVWrite(PosKey(pid,"RISK"),risk);
         if(GVRead(PosKey(pid,"REQUESTED"),0)<=0) GVWrite(PosKey(pid,"REQUESTED"),requested);
         if(GVRead(PosKey(pid,"SLIP"),0)<=0) GVWrite(PosKey(pid,"SLIP"),slip);
         if(GVRead(PosKey(pid,"MAE"),0)<=0) GVWrite(PosKey(pid,"MAE"),mae);
         if(GVRead(PosKey(pid,"MFE"),0)<=0) GVWrite(PosKey(pid,"MFE"),mfe);
         if(finalFlag>0) GVWrite(PosKey(pid,"FINAL"),finalFlag);
         if(LegacyTicketRead(tk,"INITSL",0)<=0) LegacyTicketWrite(tk,"INITSL",initSL);
         if(LegacyTicketRead(tk,"TP1",0)<=0) LegacyTicketWrite(tk,"TP1",tp1);
         if(LegacyTicketRead(tk,"TP2",0)<=0) LegacyTicketWrite(tk,"TP2",tp2);
         if(LegacyTicketRead(tk,"TP3",0)<=0) LegacyTicketWrite(tk,"TP3",tp3);
         if(LegacyTicketRead(tk,"EXP",0)<=0) LegacyTicketWrite(tk,"EXP",exp);
         if(LegacyTicketRead(tk,"TP1DONE",0)<=0) LegacyTicketWrite(tk,"TP1DONE",tp1done);
         // Silence unused checkpoint-only values while preserving schema compatibility.
         oldTicket=oldTicket; oldSym=oldSym; ptype=ptype; volume=volume; csl=csl; ctp=ctp;
      }
      else
      {
         while(!FileIsLineEnding(h) && !FileIsEnding(h)) FileReadString(h);
      }
   }
   FileClose(h);
   RefreshRiskSession();
   ReconcileOpenPositionRecovery();
   GlobalVariablesFlush();
}

void UniversalCompatibilityInit()
{
   if(!ResolveConfiguredSymbolsUniversal()) Print("GPT_EA universal resolver found no tradable configured symbols.");
   PrintResolvedBrokerProfiles();
}

void UniversalRecoveryInit()
{
   RestoreUniversalRecoveryCheckpoint();
   ReconcileOpenPositionRecovery();
   WriteUniversalRecoveryCheckpoint();
}

void UniversalRecoveryTimer()
{
   if(!InpUseRecoveryFileCheckpoint) return;
   datetime now=TimeTradeServer();
   if(g_lastUniversalCheckpoint==0 || now-g_lastUniversalCheckpoint>=MathMax(10,InpRecoveryCheckpointSeconds))
      WriteUniversalRecoveryCheckpoint();
}

void UniversalCheckpointNow(){ WriteUniversalRecoveryCheckpoint(); }

void UniversalRecoveryShutdown()
{
   WriteUniversalRecoveryCheckpoint();
   GlobalVariablesFlush();
}
// ===== END INLINED GPT_EA_Part10_BrokerUniversalRecovery.mqh =====
// ===== BEGIN INLINED GPT_EA_Part11_PreflightRecoveryGuard.mqh =====
// ============================================================================
// GPT_EA Part 11 - Server preflight and hardened recovery safety guard
// ============================================================================

input bool   InpUseOrderCheckPreflight       = true;
input double InpMinPostTradeMarginLevelPct   = 150.0;
input bool   InpPauseOnNettingReversal       = true;
input bool   InpPauseOnRecoveryInconsistency = true;
input bool   InpKeepRecoveryBackup           = true;

// ------------------------- MT5 server preflight -----------------------
bool BrokerFillingMode(const string sym,ENUM_ORDER_TYPE_FILLING &out,string &why)
{
   long exec=SymbolInfoInteger(sym,SYMBOL_TRADE_EXEMODE);
   long flags=SymbolInfoInteger(sym,SYMBOL_FILLING_MODE);

   if(exec!=SYMBOL_TRADE_EXECUTION_MARKET)
   {
      out=ORDER_FILLING_RETURN;
      why="RETURN";
      return true;
   }
   if((flags & SYMBOL_FILLING_FOK)==SYMBOL_FILLING_FOK)
   {
      out=ORDER_FILLING_FOK;
      why="FOK";
      return true;
   }
   if((flags & SYMBOL_FILLING_IOC)==SYMBOL_FILLING_IOC)
   {
      out=ORDER_FILLING_IOC;
      why="IOC";
      return true;
   }
   why="No broker-supported filling policy found for Market Execution.";
   return false;
}

bool ServerOrderCheckAllows(const TradeSetup &s,double lots,int deviationPts,string &why)
{
   if(!InpUseOrderCheckPreflight){ why="OrderCheck preflight disabled."; return true; }
   MqlTick tick;
   if(!GetTickSafe(s.symbol,tick)){ why="No live tick for OrderCheck."; return false; }

   ENUM_ORDER_TYPE_FILLING fill;
   string fillText="";
   if(!BrokerFillingMode(s.symbol,fill,fillText)){ why=fillText; return false; }

   MqlTradeRequest req={};
   MqlTradeCheckResult chk={};
   req.action=TRADE_ACTION_DEAL;
   req.magic=(ulong)InpMagic;
   req.symbol=s.symbol;
   req.volume=lots;
   req.type=(s.bullish?ORDER_TYPE_BUY:ORDER_TYPE_SELL);
   req.price=(s.bullish?tick.ask:tick.bid);
   req.sl=NormalizePriceToTick(s.symbol,s.sl);
   req.tp=NormalizePriceToTick(s.symbol,s.tp3);
   req.deviation=(ulong)MathMax(0,deviationPts);
   req.type_filling=fill;
   req.type_time=ORDER_TIME_GTC;
   req.comment=(s.kind==SETUP_BREAKOUT_RETEST?"GPT-BR-CHECK":"GPT-PB-CHECK");

   ResetLastError();
   bool ok=OrderCheck(req,chk);
   if(!ok)
   {
      why=StringFormat("OrderCheck failed: terminal error %d, retcode %u, %s",GetLastError(),chk.retcode,chk.comment);
      return false;
   }
   if(chk.retcode!=0)
   {
      why=StringFormat("OrderCheck rejected request: retcode %u, %s",chk.retcode,chk.comment);
      return false;
   }
   if(chk.margin_free<0)
   {
      why=StringFormat("OrderCheck projects negative free margin %.2f.",chk.margin_free);
      return false;
   }
   if(InpMinPostTradeMarginLevelPct>0 && chk.margin>0 && chk.margin_level>0 && chk.margin_level<InpMinPostTradeMarginLevelPct)
   {
      why=StringFormat("Projected margin level %.1f%% below %.1f%% floor.",chk.margin_level,InpMinPostTradeMarginLevelPct);
      return false;
   }

   why=StringFormat("OrderCheck OK | fill %s | projected free margin %.2f | margin level %.1f%% | %s",
      fillText,chk.margin_free,chk.margin_level,chk.comment);
   return true;
}

// ------------------------ Netting recovery guard ----------------------
bool FirstPositionDirectionFromHistory(ulong pid,bool &firstBull)
{
   firstBull=true;
   if(!HistorySelectByPosition(pid)) return false;
   int n=HistoryDealsTotal();
   long earliest=LONG_MAX;
   bool found=false;
   for(int i=0;i<n;i++)
   {
      ulong d=HistoryDealGetTicket(i); if(d==0) continue;
      ENUM_DEAL_ENTRY e=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(d,DEAL_ENTRY);
      ENUM_DEAL_TYPE t=(ENUM_DEAL_TYPE)HistoryDealGetInteger(d,DEAL_TYPE);
      if(e!=DEAL_ENTRY_IN && e!=DEAL_ENTRY_INOUT) continue;
      if(t!=DEAL_TYPE_BUY && t!=DEAL_TYPE_SELL) continue;
      long tm=HistoryDealGetInteger(d,DEAL_TIME_MSC);
      if(!found || tm<earliest)
      {
         earliest=tm;
         firstBull=(t==DEAL_TYPE_BUY);
         found=true;
      }
   }
   return found;
}

bool RecoveryNettingReversalDetected(string &detail)
{
   detail="No netting reversal inconsistency detected.";
   long mm=AccountInfoInteger(ACCOUNT_MARGIN_MODE);
   if(mm==ACCOUNT_MARGIN_MODE_RETAIL_HEDGING) return false;

   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
      bool firstBull=true;
      if(!FirstPositionDirectionFromHistory(pid,firstBull)) continue;
      bool currentBull=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
      if(firstBull!=currentBull)
      {
         detail=StringFormat("Netting reversal detected on %s position_id=%I64u: original %s, current %s. POSITION_IDENTIFIER was preserved by MT5.",
            PositionGetString(POSITION_SYMBOL),pid,firstBull?"BUY":"SELL",currentBull?"BUY":"SELL");
         return true;
      }
   }
   return false;
}

bool RecoveryStateConsistencyCheck(string &detail)
{
   detail="Recovery state consistent.";
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
      string sym=PositionGetString(POSITION_SYMBOL);
      double entry=PositionGetDouble(POSITION_PRICE_OPEN);
      double initSL=GVRead(PosKey(pid,"INITSL"),LegacyTicketRead(tk,"INITSL",0));
      int kind=(int)GVRead(PosKey(pid,"KIND"),0);
      if(entry<=0)
      {
         detail="Recovered GPT_EA position has no valid entry price: "+sym;
         return false;
      }
      if(initSL<=0)
      {
         detail="Recovered GPT_EA position has no recoverable original stop: "+sym;
         return false;
      }
      if(kind!=SETUP_PULLBACK && kind!=SETUP_BREAKOUT_RETEST)
      {
         detail="Recovered GPT_EA position has unknown setup type: "+sym;
         return false;
      }
   }
   return true;
}

void RecoverySafetyAudit()
{
   string rev="";
   if(InpPauseOnNettingReversal && RecoveryNettingReversalDetected(rev))
   {
      GVWrite(SysKey("PAUSED"),1);
      g_manualPaused=true;
      Print("GPT_EA RECOVERY SAFETY PAUSE: ",rev);
      if(InpEnableAlerts) Alert("GPT_EA paused: "+rev);
   }

   string consistency="";
   if(InpPauseOnRecoveryInconsistency && !RecoveryStateConsistencyCheck(consistency))
   {
      GVWrite(SysKey("PAUSED"),1);
      g_manualPaused=true;
      Print("GPT_EA RECOVERY SAFETY PAUSE: ",consistency);
      if(InpEnableAlerts) Alert("GPT_EA paused: "+consistency);
   }
   GlobalVariablesFlush();
}

// ------------------- Validated checkpoint backup layer ----------------
string RecoveryBackupFileName(){ return RecoveryStateFileName()+".bak"; }

bool AppendRecoveryEndMarker()
{
   if(!InpUseRecoveryFileCheckpoint) return true;
   string main=RecoveryStateFileName();
   int h=FileOpen(main,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(h==INVALID_HANDLE) return false;
   if(!FileSeek(h,0,SEEK_END)){ FileClose(h); return false; }
   uint written=FileWrite(h,"END","2",TimeToString(TimeTradeServer(),TIME_DATE|TIME_SECONDS));
   FileFlush(h);
   FileClose(h);
   return (written>0);
}

bool RecoveryCheckpointHeaderValid(const string fileName)
{
   if(!FileIsExist(fileName,FILE_COMMON)) return false;
   int h=FileOpen(fileName,FILE_READ|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(h==INVALID_HANDLE) return false;
   if(FileIsEnding(h)){ FileClose(h); return false; }

   string tag=FileReadString(h);
   int version=(int)StringToInteger(FileReadString(h));
   long login=(long)StringToInteger(FileReadString(h));
   string server=FileReadString(h);
   long magic=(long)StringToInteger(FileReadString(h));
   FileReadString(h);

   bool completed=false;
   while(!FileIsEnding(h))
   {
      string row=FileReadString(h);
      if(row=="END") completed=true;
      while(!FileIsLineEnding(h) && !FileIsEnding(h)) FileReadString(h);
   }
   FileClose(h);

   bool ok=(tag=="META" && version>=2 && login==AccountInfoInteger(ACCOUNT_LOGIN) && magic==InpMagic && completed);
   if(InpRejectRecoveryServerMismatch && server!=AccountInfoString(ACCOUNT_SERVER)) ok=false;
   return ok;
}

void BackupRecoveryCheckpointIfValid()
{
   if(!InpUseRecoveryFileCheckpoint || !InpKeepRecoveryBackup) return;
   string main=RecoveryStateFileName();
   if(!RecoveryCheckpointHeaderValid(main))
   {
      if(!AppendRecoveryEndMarker()) return;
   }
   if(!RecoveryCheckpointHeaderValid(main)) return;
   ResetLastError();
   if(!FileCopy(main,FILE_COMMON,RecoveryBackupFileName(),FILE_COMMON|FILE_REWRITE))
      Print("GPT_EA recovery backup copy failed: ",GetLastError());
}

void PrepareRecoveryCheckpointFallback()
{
   if(!InpUseRecoveryFileCheckpoint || !InpKeepRecoveryBackup) return;
   string main=RecoveryStateFileName();
   if(RecoveryCheckpointHeaderValid(main)) return;
   string backup=RecoveryBackupFileName();
   if(!RecoveryCheckpointHeaderValid(backup))
   {
      if(FileIsExist(main,FILE_COMMON)) Print("GPT_EA recovery main checkpoint is incomplete/invalid and no completed backup is available.");
      return;
   }
   ResetLastError();
   if(FileCopy(backup,FILE_COMMON,main,FILE_COMMON|FILE_REWRITE))
      Print("GPT_EA restored recovery checkpoint from completed validated backup.");
   else
      Print("GPT_EA could not restore recovery backup: ",GetLastError());
}

void SafeUniversalCheckpointNow()
{
   UniversalCheckpointNow();
   if(!AppendRecoveryEndMarker())
   {
      Print("GPT_EA could not append recovery END marker; snapshot will not be promoted to backup.");
      return;
   }
   BackupRecoveryCheckpointIfValid();
}

void SafeUniversalRecoveryTimer()
{
   if(!InpUseRecoveryFileCheckpoint) return;
   datetime now=TimeTradeServer();
   if(g_lastUniversalCheckpoint==0 || now-g_lastUniversalCheckpoint>=MathMax(10,InpRecoveryCheckpointSeconds))
      SafeUniversalCheckpointNow();
}
// ===== END INLINED GPT_EA_Part11_PreflightRecoveryGuard.mqh =====
#include "GPT_EA_Part00_ForwardDeclarations.mqh"
#include "GPT_EA_Part12_SafetyStopManagement.mqh"
#include "GPT_EA_Part14_StopFailurePolicy.mqh"
#include "GPT_EA_Part18_StopBrokerObservability.mqh"
#include "GPT_EA_Part28_ReleaseCertification.mqh"
#include "GPT_EA_Part29_DeploymentDriftGuard.mqh"
#include "GPT_EA_Part28B_CIReleaseEvidence.mqh"
#include "GPT_EA_Part37A_APICompat.mqh"
#define Trim APITrim
#include "GPT_EA_Part37_APITransport.mqh"
#undef Trim
#include "GPT_EA_Part38_LegalLicenseGate.mqh"
#include "GPT_EA_Part39_CustomerRiskAcknowledgement.mqh"
#include "GPT_EA_Part40_PrivacyReleaseGate.mqh"
#define ReleaseSafetyAllows ReleaseSafetyAllowsR10Privacy
#define ReleaseGateSummary ReleaseGateSummaryR10Privacy
#define StopFailureObservabilityInit StopFailureObservabilityInitR10Privacy
#define AdvancedSafetyInit AdvancedSafetyInitR10Privacy
#define AdvancedSafetyTimer AdvancedSafetyTimerR10Privacy
#include "GPT_EA_Part15_StrategyIntelligence.mqh"
#include "GPT_EA_Part15B_StrategyFrameworks.mqh"
#include "GPT_EA_Part15C_StrategyContextAnalytics.mqh"
#include "GPT_EA_Part20_RealisticCostModel.mqh"
#include "GPT_EA_Part15D_StructureTargets.mqh"
#include "GPT_EA_Part21_ResearchValidation.mqh"
#include "GPT_EA_Part24_SessionStrategyHardening.mqh"
#include "GPT_EA_Part27_StrategyCompletion.mqh"
#include "GPT_EA_Part19_ContinuousIntelligence.mqh"
#define SelectDynamicStrategy SelectDynamicStrategyUltimate
#define PersistStrategyPlanForExecution PersistStrategyPlanForExecutionAccurate
#define StrategyIntelligenceInit StrategyIntelligenceInitFull
#define StrategyIntelligenceTimer StrategyIntelligenceTimerFull
#define EffectiveRRDynamic EffectiveRRFullRatio
#define ScheduledScanDue ScheduledOrContinuousScanDue

// Route all active OpenAI/news WebRequest calls through the R7 transport layer.
// In PROXY mode the legacy key check receives only a harmless local marker; the
// generated bearer header is then discarded before the proxy network request.
#define InpOpenAIAPIKey APITransportLegacyCredential()
#define WebRequest GPTAPIWebRequest
#include "GPT_EA_Part16_NewsIntermarket.mqh"
#include "GPT_EA_Part22A_IntermarketForward.mqh"
#include "GPT_EA_Part22P_ResponseParser.mqh"
#define AssessIntermarket AssessIntermarketHardened
#define ExtractOpenAIText ExtractOpenAITextWide
#include "GPT_EA_Part22_IntelligenceFreshness.mqh"
#undef ExtractOpenAIText
#define GetLiveWebIntel GetLiveWebIntelHardened
#include "GPT_EA_Part16A_StrictRevalidation.mqh"
#define PreEntryIntelligenceRevalidation PreEntryIntelligenceRevalidationStrict
#include "GPT_EA_Part17_ThesisEngine.mqh"
#include "GPT_EA_Part25_ThesisHardening.mqh"
#define ExtractOpenAIText ExtractOpenAITextWide
#include "GPT_EA_Part26_DeepGPTPolicy.mqh"
#undef ExtractOpenAIText
#undef WebRequest
#undef InpOpenAIAPIKey

#include "GPT_EA_Part40_ModelClockTrust.mqh"
#include "GPT_EA_Part41_PortfolioStressLatency.mqh"

// Adaptive execution, portfolio risk, integrity/quarantine, shadow validation, lifecycle,
// exactly-once reconciliation, causal analytics, demo-soak evidence and dashboard stack.
#include "GPT_EA_Part30_AdaptiveRiskPortfolio.mqh"
#include "GPT_EA_Part39_DataIntegrityQuarantine.mqh"
#include "GPT_EA_Part31_ExecutionLearning.mqh"
#include "GPT_EA_Part31A_RegimeSizing.mqh"
#include "GPT_EA_Part31B_ExecutionFinalizer.mqh"
#include "GPT_EA_Part32_ChampionChallenger.mqh"
#include "GPT_EA_Part33_LifecycleIntegrityReplay.mqh"
#include "GPT_EA_Part42_ExecutionReliability.mqh"
#include "GPT_EA_Part43_CausalAttribution.mqh"
#include "GPT_EA_Part34_StrategyHealthDashboard.mqh"
#include "GPT_EA_Part36_DemoSoakEvidence.mqh"
#include "GPT_EA_Part35_AdaptiveIntegration.mqh"

// Part05 order execution consumes final adaptive sizing and learned slippage.
#define LotSizeForRisk AdaptiveLotSizeForRiskFinal
#define AdaptiveLotSizeForRisk AdaptiveLotSizeForRiskFinal
#define DynamicSlippagePoints AdaptiveExecutionSlippagePointsR5
#include "GPT_EA_Part05.mqh"
#undef DynamicSlippagePoints
#undef AdaptiveLotSizeForRisk
#undef LotSizeForRisk

#include "GPT_EA_Part23_IntelligenceObservability.mqh"
#include "GPT_EA_Part06.mqh"
#include "GPT_EA_Part13_AdvancedPositionManager.mqh"

// Scanner/approval path uses the adaptive execution wrappers while older modules retain
// their original deterministic functions.
#undef SelectDynamicStrategy
#define SelectDynamicStrategy SelectDynamicStrategyR5
#define CallOpenAI CallOpenAIDeep
#define NotifyCard NotifyCardR5
#define BuildMandatory25PointThesis BuildMandatory25PointThesisFinal
#define PreAuthorizationRiskAllows AdaptivePreAuthorizationRiskAllowsR5
#define LotSizeForRisk AdaptiveLotSizeForRiskFinal
#define DynamicSlippagePoints AdaptiveExecutionSlippagePointsR5
#define AIReviewAllowsExecution AIReviewAllowsExecutionR5
#define MarkSignalCooldown MarkSignalCooldownR5
#define NewsIntermarketInit NewsIntermarketInitR5
#define NewsIntermarketTimer NewsIntermarketTimerR5
#define DeleteAdvancedDashboard DeleteAdvancedDashboardR5
#include "GPT_EA_Part07.mqh"
#undef DeleteAdvancedDashboard
#undef NewsIntermarketTimer
#undef NewsIntermarketInit
#undef MarkSignalCooldown
#undef AIReviewAllowsExecution
#undef DynamicSlippagePoints
#undef LotSizeForRisk
#undef PreAuthorizationRiskAllows
#undef BuildMandatory25PointThesis
#undef NotifyCard
#undef CallOpenAI
#undef PreEntryIntelligenceRevalidation
#undef GetLiveWebIntel
#undef AssessIntermarket
#undef ScheduledScanDue
#undef EffectiveRRDynamic
#undef StrategyIntelligenceTimer
#undef StrategyIntelligenceInit
#undef PersistStrategyPlanForExecution
#undef SelectDynamicStrategy
#undef AdvancedSafetyTimer
#undef AdvancedSafetyInit
#undef StopFailureObservabilityInit
#undef ReleaseGateSummary
#undef ReleaseSafetyAllows
