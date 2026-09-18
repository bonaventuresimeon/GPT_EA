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
// ===== BEGIN INLINED GPT_EA_Part00_ForwardDeclarations.mqh =====
// ============================================================================
// GPT_EA Part 00 - Forward declarations for cross-module hooks
// ============================================================================

// Defined in Part05.
bool PriceInsideZone(const TradeSetup &s);
bool M5Trigger(const TradeSetup &s);
string SetupSummaryLine(const TradeSetup &s);

// Defined in Part13.
bool PositionFlag(ulong pid,ulong ticket,const string field);

// Defined in Part14.
void RegisterStopUpdateFailure(ulong ticket,const string reason,bool critical,double requestedSL,double rNow);
bool StopUpdateRetryDue(ulong pid);

// Defined in Part18 and called by Part14 / Part13.
void RecordStopFailureObservation(ulong ticket,const string context,const string reason,bool critical,double requestedSL,double rNow);
void RecordStopRecoveryObservation(ulong ticket,const string context,const string note);
void RecordStopObservationEvent(ulong ticket,const string eventName,const string context,const string reason,bool critical,double requestedSL,double rNow);
void RecordPartialProtectionObservation(ulong ticket,const string eventName,const string reason);

// Defined in Part23 and used by adaptive notification integration in Part35.
void NotifyCardObserved(const string card);


// Defined in Part39 and used by pre-Part39 historical finalizers.
int IntegrityTextHash(const string text);
string CurrentSensitiveConfigText();

// Defined in Part40 and used by strict revalidation before Part40 is included.
bool DeterministicEmergencyExecutionActive(const string sym,int strategyValue,string &why);

// Defined in Part42; allows Part39 fingerprinting to include later reliability/champion inputs.
string LateResilienceConfigText();
// ===== END INLINED GPT_EA_Part00_ForwardDeclarations.mqh =====
// ===== BEGIN INLINED GPT_EA_Part12_SafetyStopManagement.mqh =====
// ============================================================================
// GPT_EA Part 12 - Release safety gates, recovery invariants and advanced stops
// ============================================================================

input bool   InpUseReleaseSafetyGate           = true;
input bool   InpBlockRealUnlessExplicitlyArmed = true;
input string InpLiveArmPhrase                  = "";
input bool   InpRequireApprovalOnRealAccount   = true;
input bool   InpRequireTerminalConnected       = true;
input bool   InpRequireSeriesSynchronized      = true;
input int    InpMinBarsPerRequiredTF           = 120;
input int    InpMaxQuoteAgeSeconds             = 30;
input bool   InpBlockOnRecoveryInvariantFail   = true;
input bool   InpRequireMarketAndSLOrderModes   = true;

input bool   InpUseAdvancedStopManagement = true;
input double InpBETriggerR                = 1.00;
input double InpBELockMinR                = 0.00;
input double InpProfitLockTriggerR        = 1.50;
input double InpProfitLockR               = 0.50;
input double InpStrongLockTriggerR        = 2.00;
input double InpStrongLockR               = 1.00;
input bool   InpUseATRTrailing            = true;
input double InpTrailStartR               = 2.00;
input double InpTrailATRMultiplier        = 1.25;
input int    InpTrailStructureBarsM5      = 8;
input double InpTrailStructureBufferATR   = 0.15;
input double InpTrailMinStepR             = 0.15;
input double InpPartialAtTP2Percent       = 50.0;
input bool   InpKeepTP3WhileTrailing      = true;

bool g_releaseBlocked=false;
string g_releaseBlockReason="Not evaluated";

bool AdvancedManagementConfigSafe(string &why)
{
   why="";
   if(!InpUseAdvancedStopManagement) return true;
   if(InpBETriggerR<=0){ why="InpBETriggerR must be > 0."; return false; }
   if(InpBELockMinR<0){ why="InpBELockMinR cannot be negative."; return false; }
   if(InpProfitLockTriggerR<InpBETriggerR){ why="Profit-lock trigger must be >= BE trigger."; return false; }
   if(InpProfitLockR<0 || InpProfitLockR>=InpProfitLockTriggerR){ why="Profit-lock R must be >=0 and below its trigger R."; return false; }
   if(InpStrongLockTriggerR<InpProfitLockTriggerR){ why="Strong-lock trigger must be >= profit-lock trigger."; return false; }
   if(InpStrongLockR<InpProfitLockR || InpStrongLockR>=InpStrongLockTriggerR){ why="Strong-lock R must be >= profit-lock R and below strong-lock trigger R."; return false; }
   if(InpTrailStartR<InpStrongLockTriggerR){ why="Trail start must be >= strong-lock trigger."; return false; }
   if(InpTrailATRMultiplier<=0){ why="Trail ATR multiplier must be > 0."; return false; }
   if(InpTrailStructureBarsM5<3){ why="Trail structure lookback must be >= 3 bars."; return false; }
   if(InpTrailStructureBufferATR<0 || InpTrailMinStepR<0){ why="Trail buffers/steps cannot be negative."; return false; }
   if(InpPartialAtTP1Percent<0 || InpPartialAtTP1Percent>100){ why="TP1 partial percent must be 0..100."; return false; }
   if(InpPartialAtTP2Percent<0 || InpPartialAtTP2Percent>100){ why="TP2 partial percent must be 0..100."; return false; }
   return true;
}

bool RequiredSeriesReady(const string sym,string &why)
{
   why="";
   if(!InpRequireSeriesSynchronized) return true;
   ENUM_TIMEFRAMES tfs[6]={PERIOD_D1,PERIOD_H4,PERIOD_H1,PERIOD_M30,PERIOD_M15,PERIOD_M5};
   string names[6]={"D1","H4","H1","M30","M15","M5"};
   for(int i=0;i<6;i++)
   {
      if(!(bool)SeriesInfoInteger(sym,tfs[i],SERIES_SYNCHRONIZED))
      {
         why=sym+" "+names[i]+" series is not synchronized.";
         return false;
      }
      long bars=SeriesInfoInteger(sym,tfs[i],SERIES_BARS_COUNT);
      if(InpMinBarsPerRequiredTF>0 && bars<InpMinBarsPerRequiredTF)
      {
         why=StringFormat("%s %s has only %I64d bars; minimum is %d.",sym,names[i],bars,InpMinBarsPerRequiredTF);
         return false;
      }
   }
   return true;
}

bool QuoteFreshEnough(const string sym,string &why)
{
   why="";
   if(InpMaxQuoteAgeSeconds<=0) return true;
   MqlTick t;
   if(!GetTickSafe(sym,t)){ why=sym+" has no current tick."; return false; }
   datetime now=TimeTradeServer();
   if(now<=0 || t.time<=0){ why=sym+" quote/server timestamp unavailable."; return false; }
   long age=(long)(now-t.time);
   if(age>InpMaxQuoteAgeSeconds)
   {
      why=StringFormat("%s quote age %I64d sec exceeds %d sec limit.",sym,age,InpMaxQuoteAgeSeconds);
      return false;
   }
   return true;
}

bool SymbolOrderModesSafe(const string sym,string &why)
{
   why="";
   if(!InpRequireMarketAndSLOrderModes) return true;
   long mode=SymbolInfoInteger(sym,SYMBOL_ORDER_MODE);
   if((mode & SYMBOL_ORDER_MARKET)!=(long)SYMBOL_ORDER_MARKET){ why=sym+" does not permit market orders."; return false; }
   if((mode & SYMBOL_ORDER_SL)!=(long)SYMBOL_ORDER_SL){ why=sym+" does not permit protective Stop Loss orders."; return false; }
   return true;
}

bool PositionRecoveryInvariant(ulong ticket,string &why)
{
   why="";
   if(!PositionSelectByTicket(ticket)){ why="Position selection failed."; return false; }
   if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) return true;
   ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
   string sym=PositionGetString(POSITION_SYMBOL);
   bool bull=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
   double entry=PositionGetDouble(POSITION_PRICE_OPEN);
   double vol=PositionGetDouble(POSITION_VOLUME);
   double currentSL=PositionGetDouble(POSITION_SL);
   if(pid==0){ why=sym+" has zero POSITION_IDENTIFIER."; return false; }
   if(entry<=0 || vol<=0){ why=sym+" has invalid entry/volume."; return false; }
   if(currentSL<=0){ why=sym+" open GPT_EA position is unprotected (SL=0)."; return false; }
   if(GVRead(PosKey(pid,"FINAL"),0)>0.5){ why=sym+" is open but analytics FINAL flag is already set."; return false; }
   double initSL=GVRead(PosKey(pid,"INITSL"),LegacyTicketRead(ticket,"INITSL",0));
   if(initSL<=0) initSL=HistoricalInitialSL(pid);
   if(initSL<=0){ why=sym+" original stop cannot be recovered."; return false; }
   if(bull && initSL>=entry){ why=sym+" BUY original SL is not below entry."; return false; }
   if(!bull && initSL<=entry){ why=sym+" SELL original SL is not above entry."; return false; }
   double R=MathAbs(entry-initSL);
   if(R<=PointFor(sym)){ why=sym+" recovered initial risk distance is invalid."; return false; }
   double tp1=LegacyTicketRead(ticket,"TP1",bull?entry+R:entry-R);
   double tp2=LegacyTicketRead(ticket,"TP2",bull?entry+2*R:entry-2*R);
   double tp3=LegacyTicketRead(ticket,"TP3",bull?entry+3*R:entry-3*R);
   if(bull && !(tp1>entry && tp2>tp1 && tp3>tp2)){ why=sym+" BUY target geometry is inconsistent."; return false; }
   if(!bull && !(tp1<entry && tp2<tp1 && tp3<tp2)){ why=sym+" SELL target geometry is inconsistent."; return false; }
   return true;
}

bool PendingRecoveryInvariant(string &why)
{
   why="";
   for(int i=0;i<ArraySize(g_pending);i++)
   {
      if(!g_pending[i].active) continue;
      TradeSetup s=g_pending[i].setup;
      if(s.symbol=="" || !EnsureSymbol(s.symbol)){ why="Pending approval has unavailable symbol."; return false; }
      if(g_pending[i].expiresAt<=g_pending[i].createdAt){ why=s.symbol+" pending approval has invalid timestamps."; return false; }
      if(!s.valid){ why=s.symbol+" active pending setup is not marked valid."; return false; }
      if(s.bullish && !(s.sl<s.preferred && s.tp1>s.preferred && s.tp2>s.tp1 && s.tp3>s.tp2)){ why=s.symbol+" pending BUY geometry is inconsistent."; return false; }
      if(!s.bullish && !(s.sl>s.preferred && s.tp1<s.preferred && s.tp2<s.tp1 && s.tp3<s.tp2)){ why=s.symbol+" pending SELL geometry is inconsistent."; return false; }
      for(int j=i+1;j<ArraySize(g_pending);j++)
         if(g_pending[j].active && g_pending[j].setup.symbol==s.symbol){ why=s.symbol+" has duplicate active pending approvals."; return false; }
   }
   return true;
}

bool RecoveryInvariantsPass(string &why)
{
   why="";
   string configWhy="";
   if(!AdvancedManagementConfigSafe(configWhy)){ why="Management configuration invalid: "+configWhy; return false; }
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0) continue;
      if(!PositionSelectByTicket(tk) || PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      string pwhy="";
      if(!PositionRecoveryInvariant(tk,pwhy)){ why=pwhy; return false; }
   }
   string pendingWhy="";
   if(!PendingRecoveryInvariant(pendingWhy)){ why=pendingWhy; return false; }
   if(g_dayStartEquity<=0 || g_equityPeak<=0){ why="Risk-session equity state is invalid."; return false; }
   return true;
}

void RebuildAdvancedProtectionState()
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
      bool bull=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
      double entry=PositionGetDouble(POSITION_PRICE_OPEN);
      double sl=PositionGetDouble(POSITION_SL);
      double initSL=GVRead(PosKey(pid,"INITSL"),LegacyTicketRead(tk,"INITSL",0));
      if(initSL<=0) initSL=HistoricalInitialSL(pid);
      double R=MathAbs(entry-initSL);
      if(R<=0) continue;
      int stage=0;
      if(sl>0)
      {
         double locked=(bull?sl-entry:entry-sl)/R;
         if(locked>=InpStrongLockR-0.05) stage=3;
         else if(locked>=InpProfitLockR-0.05) stage=2;
         else if(locked>=-0.05) stage=1;
      }
      double stored=GVRead(PosKey(pid,"SL_STAGE"),0);
      if(stage>(int)stored) GVWrite(PosKey(pid,"SL_STAGE"),stage);
      GVWrite(PosKey(pid,"LASTSL"),sl);
      if(LegacyTicketRead(tk,"TP1DONE",0)>0.5 || PositionHistoryHadExit(pid))
      {
         LegacyTicketWrite(tk,"TP1PARTIAL",1);
         GVWrite(PosKey(pid,"TP1PARTIAL"),1);
      }
   }
   GlobalVariablesFlush();
}

bool ReleaseSafetyAllows(const string sym,string &why)
{
   why="";
   if(!InpUseReleaseSafetyGate){ why="Release safety gate disabled."; return true; }
   if((bool)MQLInfoInteger(MQL_TESTER)){ why="Strategy Tester environment."; return true; }
   string configWhy="";
   if(!AdvancedManagementConfigSafe(configWhy)){ why="Management configuration invalid: "+configWhy; return false; }
   if(InpRequireTerminalConnected && !(bool)TerminalInfoInteger(TERMINAL_CONNECTED)){ why="Terminal is not connected to trade server."; return false; }
   if(!(bool)TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)){ why="Terminal automated trading is disabled."; return false; }
   if(!(bool)MQLInfoInteger(MQL_TRADE_ALLOWED)){ why="EA-level automated trading permission is disabled."; return false; }
   if(!(bool)AccountInfoInteger(ACCOUNT_TRADE_ALLOWED)){ why="Trading is disabled for this account."; return false; }
   if(!(bool)AccountInfoInteger(ACCOUNT_TRADE_EXPERT)){ why="EA trading is disabled by the trade server/account."; return false; }
   ENUM_ACCOUNT_TRADE_MODE mode=(ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE);
   if(mode==ACCOUNT_TRADE_MODE_REAL)
   {
      if(InpBlockRealUnlessExplicitlyArmed && InpLiveArmPhrase!="GPT_EA_LIVE_ARMED"){ why="REAL account blocked: set local InpLiveArmPhrase to GPT_EA_LIVE_ARMED only after release validation."; return false; }
      if(InpRequireApprovalOnRealAccount && !InpRequireApproval){ why="REAL account blocked: human approval is required by release policy."; return false; }
   }
   if(InpBlockOnRecoveryInvariantFail)
   {
      string inv="";
      if(!RecoveryInvariantsPass(inv)){ why="Recovery invariant failed: "+inv; return false; }
   }
   if(sym!="")
   {
      string swhy="";
      if(!RequiredSeriesReady(sym,swhy)){ why=swhy; return false; }
      if(!QuoteFreshEnough(sym,swhy)){ why=swhy; return false; }
      if(!SymbolOrderModesSafe(sym,swhy)){ why=swhy; return false; }
   }
   return true;
}

void RefreshReleaseSafetyGate()
{
   bool oldBlocked=g_releaseBlocked;
   string oldReason=g_releaseBlockReason;
   string why="";
   bool ok=ReleaseSafetyAllows("",why);
   if(ok)
   {
      for(int i=0;i<ArraySize(g_symbols);i++)
      {
         if(g_symbols[i]=="") continue;
         if(!ReleaseSafetyAllows(g_symbols[i],why)){ ok=false; break; }
      }
   }
   g_releaseBlocked=!ok;
   g_releaseBlockReason=(ok?"All release-blocking safety gates pass.":why);
   if(g_releaseBlocked && (!oldBlocked || oldReason!=g_releaseBlockReason)) Print("GPT_EA RELEASE BLOCK: ",g_releaseBlockReason);
   else if(!g_releaseBlocked && oldBlocked) Print("GPT_EA RELEASE GATE CLEARED: all release-blocking safety gates pass.");
}

string ReleaseGateSummary(){ return (g_releaseBlocked?"BLOCKED - "+g_releaseBlockReason:"PASS"); }

double BrokerModifyDistance(const string sym)
{
   double pt=PointFor(sym);
   int stops=(int)SymbolInfoInteger(sym,SYMBOL_TRADE_STOPS_LEVEL);
   int freeze=(int)SymbolInfoInteger(sym,SYMBOL_TRADE_FREEZE_LEVEL);
   return ((double)MathMax(stops,freeze)+1.0)*pt;
}

bool StopImproves(bool bull,double currentSL,double candidate,double minStep)
{
   if(candidate<=0) return false;
   if(currentSL<=0) return true;
   return bull ? (candidate>currentSL+minStep) : (candidate<currentSL-minStep);
}

bool StopBrokerSafe(const string sym,bool bull,double candidate,string &why)
{
   why="";
   MqlTick t; if(!GetTickSafe(sym,t)){ why="No tick for stop validation."; return false; }
   double px=(bull?t.bid:t.ask);
   double dist=BrokerModifyDistance(sym);
   if(bull && candidate>=px-dist){ why="BUY stop is inside broker stop/freeze distance."; return false; }
   if(!bull && candidate<=px+dist){ why="SELL stop is inside broker stop/freeze distance."; return false; }
   return true;
}

string StopStageName(int stage)
{
   if(stage<=0) return "INITIAL";
   if(stage==1) return "BREAKEVEN";
   if(stage==2) return "PROFIT_LOCK";
   if(stage==3) return "STRONG_LOCK";
   return "TRAIL";
}

bool ApplyAdvancedStop(ulong ticket,double candidate,int stage,double rNow,const string reason)
{
   if(!PositionSelectByTicket(ticket)) return false;
   string sym=PositionGetString(POSITION_SYMBOL);
   bool bull=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
   double currentSL=PositionGetDouble(POSITION_SL);
   double entry=PositionGetDouble(POSITION_PRICE_OPEN);
   ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
   double initSL=GVRead(PosKey(pid,"INITSL"),LegacyTicketRead(ticket,"INITSL",0));
   if(initSL<=0) initSL=HistoricalInitialSL(pid);
   double R=MathAbs(entry-initSL);
   if(R<=0) return false;
   double minStep=MathMax(PointFor(sym),InpTrailMinStepR*MathMax(R,PointFor(sym)));
   candidate=NormalizePriceToTick(sym,candidate);
   if(stage>=4)
   {
      if(!StopImproves(bull,currentSL,candidate,minStep)) return false;
   }
   else if(!StopImproves(bull,currentSL,candidate,PointFor(sym)*0.5)) return false;
   string safeWhy="";
   if(!StopBrokerSafe(sym,bull,candidate,safeWhy)) return false;
   double currentTP=PositionGetDouble(POSITION_TP);
   double tp=((stage>=4 && !InpKeepTP3WhileTrailing)?0:currentTP);
   if(ChaosInjectStopModifyFailure())
   {
      GVWrite(PosKey(pid,"CHAOS_SAMPLE"),1);
      Print(sym,": CHAOS synthetic stop-modification failure.");
      return false;
   }
   GVWrite(PosKey(pid,"EA_EXPECT_SL"),candidate);
   GVWrite(PosKey(pid,"EA_EXPECT_TP"),tp);
   GVWrite(PosKey(pid,"EA_EXPECT_MOD_UNTIL"),(double)(TimeTradeServer()+10));
   if(!trade.PositionModify(ticket,candidate,tp))
   {
      GVWrite(PosKey(pid,"EA_EXPECT_MOD_UNTIL"),0);
      Print(sym,": stop modification failed - ",trade.ResultRetcodeDescription());
      return false;
   }
   GVWrite(PosKey(pid,"SL_STAGE"),stage);
   GVWrite(PosKey(pid,"LASTSL"),candidate);
   LegacyTicketWrite(ticket,"ADV_STAGE",stage);
   SafeUniversalCheckpointNow();
   int kind=(int)GVRead(PosKey(pid,"KIND"),SETUP_PULLBACK);
   AppendJournal("STOP_"+StopStageName(stage),sym,kind,0,pid,entry,candidate,0,rNow,GVRead(PosKey(pid,"MAE"),0),GVRead(PosKey(pid,"MFE"),0),reason);
   PrintFormat("%s: protective SL advanced to %.*f | stage %s | %.2fR | %s",sym,DigitsFor(sym),candidate,StopStageName(stage),rNow,reason);
   return true;
}

bool CurrentPositionR(ulong ticket,double &rNow,double &R,double &entry,double &px,bool &bull)
{
   rNow=0; R=0; entry=0; px=0; bull=true;
   if(!PositionSelectByTicket(ticket)) return false;
   string sym=PositionGetString(POSITION_SYMBOL);
   bull=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
   entry=PositionGetDouble(POSITION_PRICE_OPEN);
   ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
   double initSL=GVRead(PosKey(pid,"INITSL"),LegacyTicketRead(ticket,"INITSL",0));
   if(initSL<=0) initSL=HistoricalInitialSL(pid);
   R=MathAbs(entry-initSL);
   if(R<=0) return false;
   MqlTick t; if(!GetTickSafe(sym,t)) return false;
   px=(bull?t.bid:t.ask);
   rNow=(bull?px-entry:entry-px)/R;
   return true;
}

bool EnsureBreakEvenProtection(ulong ticket,double rNow,double R,double entry,bool bull)
{
   if(!InpUseAdvancedStopManagement || rNow<InpBETriggerR) return false;
   if(!PositionSelectByTicket(ticket)) return false;
   string sym=PositionGetString(POSITION_SYMBOL);
   MqlTick t; if(!GetTickSafe(sym,t)) return false;
   double atr=0; ATRValue(sym,PERIOD_M5,InpATRPeriod,1,atr);
   double cost=MathMax(InpBECostATRFrac*atr,(t.ask-t.bid)+DynamicSlippagePoints(sym)*PointFor(sym));
   double minLock=InpBELockMinR*R;
   double buffer=MathMax(cost,minLock);
   double candidate=(bull?entry+buffer:entry-buffer);
   return ApplyAdvancedStop(ticket,candidate,1,rNow,"cost-aware breakeven");
}

bool AdvanceProfitProtection(ulong ticket,double rNow,double R,double entry,double px,bool bull)
{
   if(!InpUseAdvancedStopManagement) return false;
   if(!PositionSelectByTicket(ticket)) return false;
   string sym=PositionGetString(POSITION_SYMBOL);
   ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
   int stage=(int)GVRead(PosKey(pid,"SL_STAGE"),LegacyTicketRead(ticket,"ADV_STAGE",0));
   bool changed=false;
   if(rNow>=InpBETriggerR && stage<1)
   {
      if(EnsureBreakEvenProtection(ticket,rNow,R,entry,bull)){ stage=1; changed=true; }
   }
   if(rNow>=InpProfitLockTriggerR && stage<2)
   {
      double candidate=(bull?entry+InpProfitLockR*R:entry-InpProfitLockR*R);
      if(ApplyAdvancedStop(ticket,candidate,2,rNow,StringFormat("lock %.2fR after %.2fR",InpProfitLockR,InpProfitLockTriggerR))){ stage=2; changed=true; }
   }
   if(rNow>=InpStrongLockTriggerR && stage<3)
   {
      double candidate=(bull?entry+InpStrongLockR*R:entry-InpStrongLockR*R);
      if(ApplyAdvancedStop(ticket,candidate,3,rNow,StringFormat("lock %.2fR after %.2fR",InpStrongLockR,InpStrongLockTriggerR))){ stage=3; changed=true; }
   }
   if(InpUseATRTrailing && rNow>=InpTrailStartR)
   {
      double atr=0,hi=0,lo=0;
      int lookback=(int)MathMax(3,InpTrailStructureBarsM5);
      if(ATRValue(sym,PERIOD_M5,InpATRPeriod,1,atr) && atr>0 && RecentHighLow(sym,PERIOD_M5,1,lookback,hi,lo))
      {
         double atrStop=(bull?px-InpTrailATRMultiplier*atr:px+InpTrailATRMultiplier*atr);
         double structureStop=(bull?lo-InpTrailStructureBufferATR*atr:hi+InpTrailStructureBufferATR*atr);
         double floorStop=(bull?entry+InpStrongLockR*R:entry-InpStrongLockR*R);
         double candidate=(bull?MathMax(floorStop,MathMin(atrStop,structureStop)):MathMin(floorStop,MathMax(atrStop,structureStop)));
         if(ApplyAdvancedStop(ticket,candidate,4,rNow,"ATR + M5 structure trailing")) changed=true;
      }
   }
   return changed;
}

bool PositionProtectedAtOrBeyondBE(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return false;
   bool bull=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
   double entry=PositionGetDouble(POSITION_PRICE_OPEN);
   double sl=PositionGetDouble(POSITION_SL);
   return sl>0 && (bull?sl>=entry:sl<=entry);
}

void AdvancedSafetyInit()
{
   RebuildAdvancedProtectionState();
   RefreshReleaseSafetyGate();
}

void AdvancedSafetyTimer()
{
   RefreshReleaseSafetyGate();
}
// ===== END INLINED GPT_EA_Part12_SafetyStopManagement.mqh =====
// ===== BEGIN INLINED GPT_EA_Part14_StopFailurePolicy.mqh =====
// ============================================================================
// GPT_EA Part 14 - Stop update failure policy and escalation
// ============================================================================

input int  InpStopUpdateRetrySeconds          = 10;
input int  InpStopFailureWarnAfter            = 3;
input int  InpStopFailurePauseAfter           = 8;
input bool InpPauseNewEntriesOnStopFailure    = true;
input int  InpUnprotectedEmergencySeconds     = 30;
input bool InpEmergencyCloseUnprotected       = true;
input bool InpAlertOnStopFailureEscalation    = true;

bool g_stopPolicyConfigBlocked=false;
string g_stopPolicyConfigReason="Not evaluated";

bool StopFailurePolicyConfigSafe(string &why)
{
   why="";
   if(InpStopUpdateRetrySeconds<1){ why="InpStopUpdateRetrySeconds must be >= 1."; return false; }
   if(InpStopFailureWarnAfter<1){ why="InpStopFailureWarnAfter must be >= 1."; return false; }
   if(InpStopFailurePauseAfter<InpStopFailureWarnAfter)
   { why="InpStopFailurePauseAfter must be >= warning threshold."; return false; }
   if(InpEmergencyCloseUnprotected && InpUnprotectedEmergencySeconds<1)
   { why="InpUnprotectedEmergencySeconds must be >= 1 when emergency close is enabled."; return false; }
   return true;
}

void RefreshStopFailurePolicyConfigGate()
{
   string why="";
   bool ok=StopFailurePolicyConfigSafe(why);
   bool old=g_stopPolicyConfigBlocked;
   string oldWhy=g_stopPolicyConfigReason;
   g_stopPolicyConfigBlocked=!ok;
   g_stopPolicyConfigReason=(ok?"Stop failure policy configuration valid.":why);
   if(!ok)
   {
      StopFailurePauseNewEntries("stop failure policy configuration invalid: "+why);
      if(!old || oldWhy!=why) Print("GPT_EA STOP POLICY CONFIG BLOCK: ",why);
   }
}

int StopFailureCount(ulong pid)
{
   return (int)GVRead(PosKey(pid,"STOP_FAIL_COUNT"),0);
}

datetime StopFailureFirstTime(ulong pid)
{
   return (datetime)GVRead(PosKey(pid,"STOP_FAIL_FIRST"),0);
}

datetime StopFailureLastTime(ulong pid)
{
   return (datetime)GVRead(PosKey(pid,"STOP_FAIL_LAST"),0);
}

bool StopUpdateRetryDue(ulong pid)
{
   datetime now=TimeTradeServer();
   datetime next=(datetime)GVRead(PosKey(pid,"STOP_FAIL_NEXT_RETRY"),0);
   if(next>0) return now>=next;

   datetime last=StopFailureLastTime(pid);
   if(last<=0) return true;
   int adaptive=(int)GVRead(PosKey(pid,"STOP_FAIL_RETRY_SEC"),InpStopUpdateRetrySeconds);
   if(adaptive<1) adaptive=InpStopUpdateRetrySeconds;
   return (now-last>=adaptive);
}

int ActualProtectionStage(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return -1;
   bool bull=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
   double entry=PositionGetDouble(POSITION_PRICE_OPEN);
   double sl=PositionGetDouble(POSITION_SL);
   ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
   double initSL=GVRead(PosKey(pid,"INITSL"),LegacyTicketRead(ticket,"INITSL",0));
   if(initSL<=0) initSL=HistoricalInitialSL(pid);
   double R=MathAbs(entry-initSL);
   if(sl<=0 || R<=0) return -1;
   double locked=(bull?sl-entry:entry-sl)/R;
   if(locked>=InpStrongLockR-0.05) return 3;
   if(locked>=InpProfitLockR-0.05) return 2;
   if(locked>=-0.02) return 1;
   return 0;
}

int ExpectedProtectionStage(double rNow)
{
   if(!InpUseAdvancedStopManagement) return 0;
   if(rNow>=InpStrongLockTriggerR) return 3;
   if(rNow>=InpProfitLockTriggerR) return 2;
   if(rNow>=InpBETriggerR) return 1;
   return 0;
}

void StopFailurePauseNewEntries(const string reason)
{
   if(!InpPauseNewEntriesOnStopFailure) return;
   GVWrite(SysKey("PAUSED"),1);
   g_manualPaused=true;
   GlobalVariablesFlush();
   Print("GPT_EA STOP SAFETY PAUSE: ",reason);
}

void RegisterStopUpdateFailure(ulong ticket,const string reason,bool critical=false,double requestedSL=0,double rNow=0)
{
   if(!PositionSelectByTicket(ticket)) return;
   ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
   string sym=PositionGetString(POSITION_SYMBOL);
   double entry=PositionGetDouble(POSITION_PRICE_OPEN);
   double sl=PositionGetDouble(POSITION_SL);
   datetime now=TimeTradeServer();

   int count=StopFailureCount(pid)+1;
   datetime first=StopFailureFirstTime(pid);
   if(first<=0) first=now;
   GVWrite(PosKey(pid,"STOP_FAIL_COUNT"),count);
   GVWrite(PosKey(pid,"STOP_FAIL_FIRST"),(double)first);
   GVWrite(PosKey(pid,"STOP_FAIL_LAST"),(double)now);
   GVWrite(PosKey(pid,"STOP_FAIL_CRITICAL"),critical?1:0);

   int kind=(int)GVRead(PosKey(pid,"KIND"),SETUP_PULLBACK);
   if(count==1 || count==InpStopFailureWarnAfter || count==InpStopFailurePauseAfter || critical)
   {
      AppendJournal(critical?"STOP_FAIL_CRITICAL":"STOP_UPDATE_FAIL",sym,kind,0,pid,entry,sl,0,0,
                    GVRead(PosKey(pid,"MAE"),0),GVRead(PosKey(pid,"MFE"),0),reason);
   }

   RecordStopFailureObservation(ticket,critical?"CRITICAL_PROTECTION":"STOP_UPDATE",reason,critical,requestedSL,rNow);

   PrintFormat("%s: stop-update failure #%d | critical=%s | %s",sym,count,critical?"YES":"NO",reason);

   bool warn=(critical || (InpStopFailureWarnAfter>0 && count==InpStopFailureWarnAfter));
   if(warn && InpAlertOnStopFailureEscalation)
   {
      string msg=StringFormat("GPT_EA %s stop protection issue: %s",sym,reason);
      if(InpEnableAlerts) Alert(msg);
      if(InpEnablePush && !(bool)MQLInfoInteger(MQL_TESTER)) SendNotification(StringSubstr(msg,0,(int)MathMin(250,StringLen(msg))));
   }

   if(critical || (InpStopFailurePauseAfter>0 && count>=InpStopFailurePauseAfter))
      StopFailurePauseNewEntries(sym+": "+reason);

   SafeUniversalCheckpointNow();
}

void ClearStopFailureState(ulong ticket,const string note="protection recovered")
{
   if(!PositionSelectByTicket(ticket)) return;
   ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
   int oldCount=StopFailureCount(pid);
   if(oldCount<=0) return;
   string sym=PositionGetString(POSITION_SYMBOL);
   double entry=PositionGetDouble(POSITION_PRICE_OPEN);
   double sl=PositionGetDouble(POSITION_SL);
   int kind=(int)GVRead(PosKey(pid,"KIND"),SETUP_PULLBACK);

   RecordStopRecoveryObservation(ticket,"STOP_RECOVERY",note);

   GVWrite(PosKey(pid,"STOP_FAIL_COUNT"),0);
   GVWrite(PosKey(pid,"STOP_FAIL_FIRST"),0);
   GVWrite(PosKey(pid,"STOP_FAIL_LAST"),0);
   GVWrite(PosKey(pid,"STOP_FAIL_CRITICAL"),0);
   GVWrite(PosKey(pid,"STOP_FAIL_RETRY_SEC"),0);
   GVWrite(PosKey(pid,"STOP_FAIL_NEXT_RETRY"),0);
   GVWrite(PosKey(pid,"STOP_FAIL_CLASS_CODE"),0);
   GVWrite(PosKey(pid,"STOP_FAIL_ACTION_CODE"),0);
   GVWrite(PosKey(pid,"STOP_FAIL_CLASS_HASH"),0);

   AppendJournal("STOP_UPDATE_RECOVERED",sym,kind,0,pid,entry,sl,0,0,
                 GVRead(PosKey(pid,"MAE"),0),GVRead(PosKey(pid,"MFE"),0),note);
   PrintFormat("%s: stop protection recovered after %d failed update(s).",sym,oldCount);
   SafeUniversalCheckpointNow();
}

bool TrailingImprovementStillExpected(ulong ticket,double rNow,string &why)
{
   why="";
   if(!InpUseATRTrailing || rNow<InpTrailStartR) return false;
   if(!PositionSelectByTicket(ticket)) return false;
   string sym=PositionGetString(POSITION_SYMBOL);
   bool bull=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
   double entry=PositionGetDouble(POSITION_PRICE_OPEN);
   double currentSL=PositionGetDouble(POSITION_SL);
   ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
   double initSL=GVRead(PosKey(pid,"INITSL"),LegacyTicketRead(ticket,"INITSL",0));
   if(initSL<=0) initSL=HistoricalInitialSL(pid);
   double R=MathAbs(entry-initSL);
   if(R<=0) return false;

   MqlTick t; if(!GetTickSafe(sym,t)) return false;
   double px=(bull?t.bid:t.ask);
   double atr=0,hi=0,lo=0;
   int lookback=(int)MathMax(3,InpTrailStructureBarsM5);
   if(!ATRValue(sym,PERIOD_M5,InpATRPeriod,1,atr) || atr<=0 ||
      !RecentHighLow(sym,PERIOD_M5,1,lookback,hi,lo)) return false;

   double atrStop=(bull?px-InpTrailATRMultiplier*atr:px+InpTrailATRMultiplier*atr);
   double structureStop=(bull?lo-InpTrailStructureBufferATR*atr:hi+InpTrailStructureBufferATR*atr);
   double floorStop=(bull?entry+InpStrongLockR*R:entry-InpStrongLockR*R);
   double candidate=(bull?MathMax(floorStop,MathMin(atrStop,structureStop)):MathMin(floorStop,MathMax(atrStop,structureStop)));
   candidate=NormalizePriceToTick(sym,candidate);
   double minStep=MathMax(PointFor(sym),InpTrailMinStepR*MathMax(R,PointFor(sym)));
   if(!StopImproves(bull,currentSL,candidate,minStep)) return false;

   string safeWhy="";
   if(!StopBrokerSafe(sym,bull,candidate,safeWhy)) return false;
   why=StringFormat("broker-valid trailing improvement to %.*f remained unapplied",DigitsFor(sym),candidate);
   return true;
}

bool ExpectedFixedProtectionCandidate(ulong ticket,int expected,double &candidate,string &geometryWhy)
{
   candidate=0; geometryWhy="";
   if(expected<1 || expected>3 || !PositionSelectByTicket(ticket)) return false;
   string sym=PositionGetString(POSITION_SYMBOL);
   double rNow=0,R=0,entry=0,px=0; bool bull=true;
   if(!CurrentPositionR(ticket,rNow,R,entry,px,bull) || R<=0) return false;

   if(expected==1)
   {
      MqlTick t={}; if(!GetTickSafe(sym,t)) return false;
      double atr=0; ATRValue(sym,PERIOD_M5,InpATRPeriod,1,atr);
      double cost=MathMax(InpBECostATRFrac*atr,(t.ask-t.bid)+DynamicSlippagePoints(sym)*PointFor(sym));
      double buffer=MathMax(cost,InpBELockMinR*R);
      candidate=(bull?entry+buffer:entry-buffer);
   }
   else if(expected==2)
      candidate=(bull?entry+InpProfitLockR*R:entry-InpProfitLockR*R);
   else
      candidate=(bull?entry+InpStrongLockR*R:entry-InpStrongLockR*R);

   candidate=NormalizePriceToTick(sym,candidate);
   string brokerWhy="";
   if(!StopBrokerSafe(sym,bull,candidate,brokerWhy)) geometryWhy=brokerWhy;
   return candidate>0;
}

void AuditStopUpdateAttempt(ulong ticket,double rNow,const string context)
{
   if(!PositionSelectByTicket(ticket)) return;
   ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
   if(!StopUpdateRetryDue(pid)) return; // a direct/previous failure already scheduled the next controlled retry

   int expected=ExpectedProtectionStage(rNow);
   if(expected>0)
   {
      int actual=ActualProtectionStage(ticket);
      if(actual<expected)
      {
         double sl=PositionGetDouble(POSITION_SL);
         bool critical=(sl<=0);
         double requested=0; string geometry="";
         ExpectedFixedProtectionCandidate(ticket,expected,requested,geometry);
         string why=StringFormat("%s expected stage %d but actual stage is %d at %.2fR",context,expected,actual,rNow);
         if(geometry!="") why+=" | "+geometry;
         RegisterStopUpdateFailure(ticket,why,critical,requested,rNow);
         return;
      }
   }

   string trailWhy="";
   if(TrailingImprovementStillExpected(ticket,rNow,trailWhy))
   {
      RegisterStopUpdateFailure(ticket,context+": "+trailWhy,false,0,rNow);
      return;
   }

   ClearStopFailureState(ticket,context+" satisfied");
}

bool HandleUnprotectedStopFailure(ulong ticket,const string reason)
{
   if(!PositionSelectByTicket(ticket)) return true;
   if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) return true;
   double sl=PositionGetDouble(POSITION_SL);
   if(sl>0)
   {
      ClearStopFailureState(ticket,"protective SL restored");
      return true;
   }

   ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
   string sym=PositionGetString(POSITION_SYMBOL);
   double entry=PositionGetDouble(POSITION_PRICE_OPEN);
   if(StopUpdateRetryDue(pid)) RegisterStopUpdateFailure(ticket,reason,true,0,0);

   datetime first=StopFailureFirstTime(pid);
   datetime now=TimeTradeServer();
   int elapsed=(first>0?(int)(now-first):0);
   if(!InpEmergencyCloseUnprotected || elapsed<MathMax(1,InpUnprotectedEmergencySeconds)) return false;

   int kind=(int)GVRead(PosKey(pid,"KIND"),SETUP_PULLBACK);
   double mae=GVRead(PosKey(pid,"MAE"),0);
   double mfe=GVRead(PosKey(pid,"MFE"),0);
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(DynamicSlippagePoints(sym));

   RecordStopObservationEvent(ticket,"EMERGENCY_CLOSE_ATTEMPT","UNPROTECTED_POSITION",reason,true,0,0);
   if(trade.PositionClose(ticket,DynamicSlippagePoints(sym)))
   {
      AppendJournal("EMERGENCY_CLOSE_UNPROTECTED",sym,kind,0,pid,entry,0,0,0,mae,mfe,reason);
      PrintFormat("%s: emergency close sent after %d sec without a protective SL.",sym,elapsed);
      SafeUniversalCheckpointNow();
      return true;
   }

   RecordStopObservationEvent(ticket,"EMERGENCY_CLOSE_FAILED","UNPROTECTED_POSITION",reason,true,0,0);
   Print(sym,": emergency close of unprotected position failed - ",trade.ResultRetcodeDescription());
   return false;
}

string StopFailurePolicySummary()
{
   return StringFormat("default retry %ds | warn %d | pause %d | unprotected emergency %ds | emergency close %s | broker-adaptive retry ON",
      InpStopUpdateRetrySeconds,InpStopFailureWarnAfter,InpStopFailurePauseAfter,
      InpUnprotectedEmergencySeconds,InpEmergencyCloseUnprotected?"ON":"OFF");
}

void StopFailurePolicyInit()
{
   RefreshStopFailurePolicyConfigGate();
   Print("GPT_EA stop failure policy: ",StopFailurePolicySummary());
}

void StopFailurePolicyTimer()
{
   RefreshStopFailurePolicyConfigGate();
}
// ===== END INLINED GPT_EA_Part14_StopFailurePolicy.mqh =====
// ===== BEGIN INLINED GPT_EA_Part18_StopBrokerObservability.mqh =====
// ============================================================================
// GPT_EA Part 18 - Broker-specific stop failure handling and observability
// ============================================================================

input bool   InpWriteStopFailureObservability      = true;
input string InpStopFailureObservabilityFile       = "GPT_EA_StopFailures.csv";
input bool   InpStopObservabilityFlushEachEvent    = true;
input bool   InpBlockNewEntriesOnPartialProtection = true;
input bool   InpBlockOnCriticalStopState           = true;
input bool   InpBlockOnOperatorStopState           = true;
input int    InpPartialProtectionMaxSeconds        = 45;
input int    InpMarketClosedStopRetrySeconds       = 60;
input int    InpConnectionStopRetrySeconds         = 30;
input int    InpFreezeStopRetrySeconds             = 10;
input int    InpRequoteStopRetrySeconds            = 3;
input int    InpRateLimitStopRetrySeconds          = 30;
input int    InpStopRateLimitMaxBackoffSeconds     = 180;

enum StopFailureClassCode
{
   STOP_CLASS_NONE=0,
   STOP_CLASS_INVALID_STOPS=1,
   STOP_CLASS_FROZEN=2,
   STOP_CLASS_MARKET_CLOSED=3,
   STOP_CLASS_REQUOTE_PRICE_CHANGED=4,
   STOP_CLASS_NO_QUOTES=5,
   STOP_CLASS_CONNECTION=6,
   STOP_CLASS_RATE_LIMIT=7,
   STOP_CLASS_TRADING_DISABLED=8,
   STOP_CLASS_INVALID_VOLUME=9,
   STOP_CLASS_INVALID_PRICE=10,
   STOP_CLASS_INVALID_FILL=11,
   STOP_CLASS_STOP_LEVEL_DISTANCE=12,
   STOP_CLASS_NO_CHANGES=13,
   STOP_CLASS_POSITION_CLOSED=14,
   STOP_CLASS_PROTECTION_MISSING=15,
   STOP_CLASS_PARTIAL_PROTECTION=16,
   STOP_CLASS_TRADE_CONTEXT_LOCKED=17,
   STOP_CLASS_OTHER=99
};

enum StopFailureActionCode
{
   STOP_ACTION_NONE=0,
   STOP_ACTION_RETRY_FRESH_PRICE=1,
   STOP_ACTION_WAIT_DISTANCE_CLEAR=2,
   STOP_ACTION_WAIT_MARKET_OPEN=3,
   STOP_ACTION_WAIT_CONNECTION_OR_QUOTE=4,
   STOP_ACTION_BACKOFF=5,
   STOP_ACTION_OPERATOR_OR_BROKER_CHANGE=6,
   STOP_ACTION_CRITICAL_PROTECT_OR_CLOSE=7,
   STOP_ACTION_NOOP=8,
   STOP_ACTION_STOP_POSITION_MANAGEMENT=9
};

string StopFailureClassText(int code)
{
   switch(code)
   {
      case STOP_CLASS_INVALID_STOPS: return "INVALID_STOPS";
      case STOP_CLASS_FROZEN: return "FROZEN";
      case STOP_CLASS_MARKET_CLOSED: return "MARKET_CLOSED";
      case STOP_CLASS_REQUOTE_PRICE_CHANGED: return "REQUOTE_PRICE_CHANGED";
      case STOP_CLASS_NO_QUOTES: return "NO_QUOTES";
      case STOP_CLASS_CONNECTION: return "CONNECTION";
      case STOP_CLASS_RATE_LIMIT: return "RATE_LIMIT";
      case STOP_CLASS_TRADING_DISABLED: return "TRADING_DISABLED";
      case STOP_CLASS_INVALID_VOLUME: return "INVALID_VOLUME";
      case STOP_CLASS_INVALID_PRICE: return "INVALID_PRICE";
      case STOP_CLASS_INVALID_FILL: return "INVALID_FILL";
      case STOP_CLASS_STOP_LEVEL_DISTANCE: return "STOP_LEVEL_DISTANCE";
      case STOP_CLASS_NO_CHANGES: return "NO_CHANGES";
      case STOP_CLASS_POSITION_CLOSED: return "POSITION_CLOSED";
      case STOP_CLASS_PROTECTION_MISSING: return "PROTECTION_MISSING";
      case STOP_CLASS_PARTIAL_PROTECTION: return "PARTIAL_PROTECTION";
      case STOP_CLASS_TRADE_CONTEXT_LOCKED: return "TRADE_CONTEXT_LOCKED";
      case STOP_CLASS_NONE: return "NONE";
      default: return "OTHER_TRANSIENT_OR_BROKER_REJECTION";
   }
}

string StopFailureActionText(int code)
{
   switch(code)
   {
      case STOP_ACTION_RETRY_FRESH_PRICE: return "RETRY_FRESH_PRICE";
      case STOP_ACTION_WAIT_DISTANCE_CLEAR: return "WAIT_DISTANCE_CLEAR";
      case STOP_ACTION_WAIT_MARKET_OPEN: return "WAIT_MARKET_OPEN";
      case STOP_ACTION_WAIT_CONNECTION_OR_QUOTE: return "WAIT_CONNECTION_OR_QUOTE";
      case STOP_ACTION_BACKOFF: return "BACKOFF";
      case STOP_ACTION_OPERATOR_OR_BROKER_CHANGE: return "OPERATOR_OR_BROKER_CHANGE";
      case STOP_ACTION_CRITICAL_PROTECT_OR_CLOSE: return "CRITICAL_PROTECT_OR_CLOSE";
      case STOP_ACTION_NOOP: return "NOOP";
      case STOP_ACTION_STOP_POSITION_MANAGEMENT: return "STOP_POSITION_MANAGEMENT";
      default: return "NONE";
   }
}

int StopFailureClassCodeFrom(uint retcode,const string description,const string reason)
{
   string u=description+" "+reason; StringToUpper(u);
   if(StringFind(u,"TP1 PARTIAL")>=0 || StringFind(u,"PARTIAL PROTECTION")>=0) return STOP_CLASS_PARTIAL_PROTECTION;
   if(StringFind(u,"PROTECTIVE SL MISSING")>=0 || StringFind(u,"NO PROTECTIVE SL")>=0 || StringFind(u,"SL=0")>=0) return STOP_CLASS_PROTECTION_MISSING;
   if(retcode==10025 || StringFind(u,"NO CHANGES")>=0) return STOP_CLASS_NO_CHANGES;
   if(retcode==10036 || StringFind(u,"POSITION CLOSED")>=0) return STOP_CLASS_POSITION_CLOSED;
   if(retcode==10029 || StringFind(u,"FROZEN")>=0 || StringFind(u,"FREEZE")>=0) return STOP_CLASS_FROZEN;
   if(retcode==10016 || StringFind(u,"INVALID STOPS")>=0) return STOP_CLASS_INVALID_STOPS;
   if(StringFind(u,"STOP LEVEL")>=0 || StringFind(u,"MINIMUM STOP")>=0 || StringFind(u,"STOP DISTANCE")>=0) return STOP_CLASS_STOP_LEVEL_DISTANCE;
   if(retcode==10018 || StringFind(u,"MARKET CLOSED")>=0 || StringFind(u,"SESSION CLOSED")>=0) return STOP_CLASS_MARKET_CLOSED;
   if(retcode==10004 || retcode==10020 || StringFind(u,"REQUOTE")>=0 || StringFind(u,"PRICE CHANGED")>=0) return STOP_CLASS_REQUOTE_PRICE_CHANGED;
   if(retcode==10021 || StringFind(u,"PRICE OFF")>=0 || StringFind(u,"NO QUOTE")>=0 || StringFind(u,"NO PRICES")>=0) return STOP_CLASS_NO_QUOTES;
   if(retcode==10031 || StringFind(u,"CONNECTION")>=0 || StringFind(u,"DISCONNECTED")>=0) return STOP_CLASS_CONNECTION;
   if(retcode==10024 || StringFind(u,"TOO MANY")>=0 || StringFind(u,"RATE LIMIT")>=0 || StringFind(u,"FREQUENT REQUEST")>=0) return STOP_CLASS_RATE_LIMIT;
   if(retcode==10028 || StringFind(u,"LOCKED")>=0 || StringFind(u,"TRADE CONTEXT")>=0) return STOP_CLASS_TRADE_CONTEXT_LOCKED;
   if(retcode==10017 || retcode==10026 || retcode==10027 || StringFind(u,"TRADE DISABLED")>=0 || StringFind(u,"AUTOTRADING DISABLED")>=0) return STOP_CLASS_TRADING_DISABLED;
   if(retcode==10014 || StringFind(u,"INVALID VOLUME")>=0) return STOP_CLASS_INVALID_VOLUME;
   if(retcode==10015 || StringFind(u,"INVALID PRICE")>=0) return STOP_CLASS_INVALID_PRICE;
   if(retcode==10030 || StringFind(u,"INVALID FILL")>=0 || StringFind(u,"FILLING")>=0) return STOP_CLASS_INVALID_FILL;
   return STOP_CLASS_OTHER;
}

string StopFailureClassName(uint retcode,const string description,const string reason)
{
   return StopFailureClassText(StopFailureClassCodeFrom(retcode,description,reason));
}

int StopFailureActionForClass(int cls)
{
   if(cls==STOP_CLASS_INVALID_STOPS || cls==STOP_CLASS_FROZEN || cls==STOP_CLASS_STOP_LEVEL_DISTANCE) return STOP_ACTION_WAIT_DISTANCE_CLEAR;
   if(cls==STOP_CLASS_MARKET_CLOSED) return STOP_ACTION_WAIT_MARKET_OPEN;
   if(cls==STOP_CLASS_CONNECTION || cls==STOP_CLASS_NO_QUOTES) return STOP_ACTION_WAIT_CONNECTION_OR_QUOTE;
   if(cls==STOP_CLASS_REQUOTE_PRICE_CHANGED || cls==STOP_CLASS_INVALID_PRICE) return STOP_ACTION_RETRY_FRESH_PRICE;
   if(cls==STOP_CLASS_RATE_LIMIT || cls==STOP_CLASS_TRADE_CONTEXT_LOCKED) return STOP_ACTION_BACKOFF;
   if(cls==STOP_CLASS_TRADING_DISABLED || cls==STOP_CLASS_INVALID_FILL || cls==STOP_CLASS_INVALID_VOLUME) return STOP_ACTION_OPERATOR_OR_BROKER_CHANGE;
   if(cls==STOP_CLASS_PROTECTION_MISSING || cls==STOP_CLASS_PARTIAL_PROTECTION) return STOP_ACTION_CRITICAL_PROTECT_OR_CLOSE;
   if(cls==STOP_CLASS_NO_CHANGES) return STOP_ACTION_NOOP;
   if(cls==STOP_CLASS_POSITION_CLOSED) return STOP_ACTION_STOP_POSITION_MANAGEMENT;
   return STOP_ACTION_RETRY_FRESH_PRICE;
}

int StopFailureRetrySecondsForClassCode(int cls,int failureCount=1)
{
   if(cls==STOP_CLASS_MARKET_CLOSED) return MathMax(10,InpMarketClosedStopRetrySeconds);
   if(cls==STOP_CLASS_CONNECTION || cls==STOP_CLASS_NO_QUOTES) return MathMax(5,InpConnectionStopRetrySeconds);
   if(cls==STOP_CLASS_FROZEN || cls==STOP_CLASS_INVALID_STOPS || cls==STOP_CLASS_STOP_LEVEL_DISTANCE) return MathMax(3,InpFreezeStopRetrySeconds);
   if(cls==STOP_CLASS_REQUOTE_PRICE_CHANGED || cls==STOP_CLASS_INVALID_PRICE) return MathMax(1,InpRequoteStopRetrySeconds);
   if(cls==STOP_CLASS_RATE_LIMIT || cls==STOP_CLASS_TRADE_CONTEXT_LOCKED)
   {
      int multiplier=(int)MathMax(1,MathMin(6,failureCount));
      return MathMin(MathMax(5,InpStopRateLimitMaxBackoffSeconds),MathMax(5,InpRateLimitStopRetrySeconds)*multiplier);
   }
   if(cls==STOP_CLASS_TRADING_DISABLED || cls==STOP_CLASS_INVALID_FILL || cls==STOP_CLASS_INVALID_VOLUME) return MathMax(30,InpMarketClosedStopRetrySeconds);
   if(cls==STOP_CLASS_PROTECTION_MISSING || cls==STOP_CLASS_PARTIAL_PROTECTION) return MathMax(1,InpStopUpdateRetrySeconds);
   if(cls==STOP_CLASS_NO_CHANGES || cls==STOP_CLASS_POSITION_CLOSED) return 0;
   return MathMax(1,InpStopUpdateRetrySeconds);
}

int StopFailureRetrySecondsForClass(const string cls)
{
   int code=STOP_CLASS_OTHER;
   if(cls=="MARKET_CLOSED") code=STOP_CLASS_MARKET_CLOSED;
   else if(cls=="CONNECTION") code=STOP_CLASS_CONNECTION;
   else if(cls=="NO_QUOTES") code=STOP_CLASS_NO_QUOTES;
   else if(cls=="FROZEN") code=STOP_CLASS_FROZEN;
   else if(cls=="INVALID_STOPS") code=STOP_CLASS_INVALID_STOPS;
   else if(cls=="STOP_LEVEL_DISTANCE") code=STOP_CLASS_STOP_LEVEL_DISTANCE;
   else if(cls=="REQUOTE_PRICE_CHANGED") code=STOP_CLASS_REQUOTE_PRICE_CHANGED;
   else if(cls=="INVALID_PRICE") code=STOP_CLASS_INVALID_PRICE;
   else if(cls=="RATE_LIMIT") code=STOP_CLASS_RATE_LIMIT;
   else if(cls=="TRADE_CONTEXT_LOCKED") code=STOP_CLASS_TRADE_CONTEXT_LOCKED;
   else if(cls=="TRADING_DISABLED") code=STOP_CLASS_TRADING_DISABLED;
   else if(cls=="INVALID_FILL") code=STOP_CLASS_INVALID_FILL;
   else if(cls=="INVALID_VOLUME") code=STOP_CLASS_INVALID_VOLUME;
   else if(cls=="PROTECTION_MISSING") code=STOP_CLASS_PROTECTION_MISSING;
   else if(cls=="PARTIAL_PROTECTION") code=STOP_CLASS_PARTIAL_PROTECTION;
   else if(cls=="NO_CHANGES") code=STOP_CLASS_NO_CHANGES;
   else if(cls=="POSITION_CLOSED") code=STOP_CLASS_POSITION_CLOSED;
   return StopFailureRetrySecondsForClassCode(code,1);
}

bool StopFailureClassIsPermanentUntilOperatorOrSessionChange(const string cls)
{
   return (cls=="TRADING_DISABLED" || cls=="INVALID_FILL" || cls=="INVALID_VOLUME");
}

bool StopFailureActionRequiresOperator(int action)
{
   return (action==STOP_ACTION_OPERATOR_OR_BROKER_CHANGE);
}

int StopQuoteAgeSeconds(const string sym)
{
   MqlTick t={}; if(!SymbolInfoTick(sym,t) || t.time<=0) return 999999;
   datetime now=TimeTradeServer();
   return (int)MathMax(0,now-(datetime)t.time);
}

void EnsureStopFailureObservabilityHeader()
{
   if(!InpWriteStopFailureObservability) return;
   bool exists=FileIsExist(InpStopFailureObservabilityFile,FILE_COMMON);
   int h=FileOpen(InpStopFailureObservabilityFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(h==INVALID_HANDLE) return;
   if(!exists || FileSize(h)==0)
      FileWrite(h,"schema_version","time","event","broker","server","login","account_mode","leverage","symbol","canonical","position_id","ticket","side","context","class_code","class","action_code","action","retcode","retcode_text","failure_count","critical","current_sl","requested_or_reference_sl","entry","r_now","spread_pts","quote_age_sec","stops_level_pts","freeze_level_pts","trade_mode","execution_mode","terminal_connected","tp1_partial","tp1_done","tp2_partial","protection_stage","retry_seconds","next_retry_time","reason");
   if(InpStopObservabilityFlushEachEvent) FileFlush(h);
   FileClose(h);
}

void RecordStopObservationEvent(ulong ticket,const string eventName,const string context,const string reason,bool critical,double requestedSL=0,double rNow=0)
{
   if(!InpWriteStopFailureObservability || !PositionSelectByTicket(ticket)) return;
   EnsureStopFailureObservabilityHeader();

   string sym=PositionGetString(POSITION_SYMBOL);
   ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
   bool bull=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
   uint ret=(uint)trade.ResultRetcode();
   string desc=trade.ResultRetcodeDescription();

   bool recoveryEvent=(eventName=="STOP_PROTECTION_RECOVERED");
   int cls=(recoveryEvent?(int)GVRead(PosKey(pid,"STOP_FAIL_CLASS_CODE"),STOP_CLASS_NONE):StopFailureClassCodeFrom(ret,desc,reason));
   int action=(recoveryEvent?(int)GVRead(PosKey(pid,"STOP_FAIL_ACTION_CODE"),STOP_ACTION_NONE):StopFailureActionForClass(cls));
   int count=StopFailureCount(pid);
   int retry=(recoveryEvent?(int)GVRead(PosKey(pid,"STOP_FAIL_RETRY_SEC"),0):StopFailureRetrySecondsForClassCode(cls,MathMax(1,count)));
   datetime next=(recoveryEvent?(datetime)GVRead(PosKey(pid,"STOP_FAIL_NEXT_RETRY"),0):(retry>0?TimeTradeServer()+retry:0));

   if(!recoveryEvent)
   {
      GVWrite(PosKey(pid,"STOP_FAIL_CLASS_CODE"),cls);
      GVWrite(PosKey(pid,"STOP_FAIL_ACTION_CODE"),action);
      GVWrite(PosKey(pid,"STOP_FAIL_RETRY_SEC"),retry);
      GVWrite(PosKey(pid,"STOP_FAIL_NEXT_RETRY"),(double)next);
   }

   double pt=PointFor(sym); MqlTick t={}; GetTickSafe(sym,t);
   double spread=(pt>0?(t.ask-t.bid)/pt:0);
   string canonical=CanonicalInstrumentKey(sym,SymbolInfoString(sym,SYMBOL_DESCRIPTION),SymbolInfoString(sym,SYMBOL_PATH));

   int h=FileOpen(InpStopFailureObservabilityFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(h==INVALID_HANDLE) return;
   FileSeek(h,0,SEEK_END);
   FileWrite(h,"stop_failure_observability_v2",TimeToString(TimeTradeServer(),TIME_DATE|TIME_SECONDS),eventName,
      AccountInfoString(ACCOUNT_COMPANY),AccountInfoString(ACCOUNT_SERVER),(string)AccountInfoInteger(ACCOUNT_LOGIN),
      (string)AccountInfoInteger(ACCOUNT_MARGIN_MODE),(string)AccountInfoInteger(ACCOUNT_LEVERAGE),sym,canonical,
      (string)pid,(string)ticket,bull?"BUY":"SELL",context,(string)cls,StopFailureClassText(cls),(string)action,StopFailureActionText(action),
      (string)ret,desc,(string)count,critical?"1":"0",DoubleToString(PositionGetDouble(POSITION_SL),DigitsFor(sym)),
      DoubleToString(requestedSL,DigitsFor(sym)),DoubleToString(PositionGetDouble(POSITION_PRICE_OPEN),DigitsFor(sym)),DoubleToString(rNow,3),
      DoubleToString(spread,1),(string)StopQuoteAgeSeconds(sym),(string)SymbolInfoInteger(sym,SYMBOL_TRADE_STOPS_LEVEL),
      (string)SymbolInfoInteger(sym,SYMBOL_TRADE_FREEZE_LEVEL),(string)SymbolInfoInteger(sym,SYMBOL_TRADE_MODE),
      (string)SymbolInfoInteger(sym,SYMBOL_TRADE_EXEMODE),TerminalInfoInteger(TERMINAL_CONNECTED)?"1":"0",
      PositionFlag(pid,ticket,"TP1PARTIAL")?"1":"0",PositionFlag(pid,ticket,"TP1DONE")?"1":"0",
      PositionFlag(pid,ticket,"TP2PARTIAL")?"1":"0",(string)ActualProtectionStage(ticket),(string)retry,
      (next>0?TimeToString(next,TIME_DATE|TIME_SECONDS):""),reason);
   if(InpStopObservabilityFlushEachEvent) FileFlush(h);
   FileClose(h);

   if(!recoveryEvent && StopFailureActionRequiresOperator(action) && InpBlockOnOperatorStopState)
      StopFailurePauseNewEntries(sym+": broker stop state "+StopFailureClassText(cls)+" requires operator/broker condition change.");
}

void RecordStopFailureObservation(ulong ticket,const string context,const string reason,bool critical,double requestedSL=0,double rNow=0)
{
   RecordStopObservationEvent(ticket,critical?"CRITICAL_FAILURE":"STOP_UPDATE_FAILURE",context,reason,critical,requestedSL,rNow);
}

void RecordStopRecoveryObservation(ulong ticket,const string context,const string note)
{
   if(!PositionSelectByTicket(ticket)) return;
   RecordStopObservationEvent(ticket,"STOP_PROTECTION_RECOVERED",context,note,false,PositionGetDouble(POSITION_SL),0);
}

void RecordPartialProtectionObservation(ulong ticket,const string eventName,const string reason)
{
   if(!PositionSelectByTicket(ticket)) return;
   ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
   RecordStopObservationEvent(ticket,eventName,"PARTIAL_PROTECTION",reason,eventName=="PARTIAL_PROTECTION_HAZARD",PositionGetDouble(POSITION_SL),0);

   if((eventName=="PARTIAL_PROTECTION_COMPLETED" || eventName=="PARTIAL_PROTECTION_RECOVERED") &&
      StopFailureCount(pid)<=0 && GVRead(PosKey(pid,"STOP_FAIL_CRITICAL"),0)<=0.5)
   {
      GVWrite(PosKey(pid,"STOP_FAIL_CLASS_CODE"),STOP_CLASS_NONE);
      GVWrite(PosKey(pid,"STOP_FAIL_ACTION_CODE"),STOP_ACTION_NONE);
      GVWrite(PosKey(pid,"STOP_FAIL_RETRY_SEC"),0);
      GVWrite(PosKey(pid,"STOP_FAIL_NEXT_RETRY"),0);
   }
}

bool PartialProtectionHazardActive(string &why)
{
   why="No partial-protection hazard.";
   datetime now=TimeTradeServer();
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
      bool partial=PositionFlag(pid,tk,"TP1PARTIAL");
      bool done=PositionFlag(pid,tk,"TP1DONE");
      if(!partial || done) continue;
      datetime tp1=(datetime)GVRead(PosKey(pid,"TP1_TIME"),LegacyTicketRead(tk,"TP1_TIME",0));
      int elapsed=(tp1>0?(int)(now-tp1):0);
      if(elapsed>=MathMax(1,InpPartialProtectionMaxSeconds))
      {
         why=StringFormat("%s has TP1 partial completed but breakeven protection remains incomplete for %d sec.",PositionGetString(POSITION_SYMBOL),elapsed);
         return true;
      }
   }
   return false;
}

bool StopPortfolioProtectionHazardActive(string &why)
{
   why="Stop portfolio protection state clear.";
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
      string sym=PositionGetString(POSITION_SYMBOL);
      double sl=PositionGetDouble(POSITION_SL);
      if(sl<=0)
      {
         why=sym+": open GPT_EA position has no protective SL.";
         return true;
      }
      if(InpBlockOnCriticalStopState && GVRead(PosKey(pid,"STOP_FAIL_CRITICAL"),0)>0.5)
      {
         why=sym+": critical stop failure state remains active.";
         return true;
      }
      int action=(int)GVRead(PosKey(pid,"STOP_FAIL_ACTION_CODE"),STOP_ACTION_NONE);
      if(InpBlockOnOperatorStopState && StopFailureActionRequiresOperator(action))
      {
         why=sym+": stop failure requires operator/broker condition change.";
         return true;
      }
      if(InpStopFailurePauseAfter>0 && StopFailureCount(pid)>=InpStopFailurePauseAfter)
      {
         why=StringFormat("%s: repeated stop failures reached pause threshold (%d).",sym,StopFailureCount(pid));
         return true;
      }
   }
   return false;
}

bool StopObservabilityAllowsNewEntries(string &why)
{
   string portfolioWhy="";
   if(StopPortfolioProtectionHazardActive(portfolioWhy)){ why=portfolioWhy; return false; }
   if(InpBlockNewEntriesOnPartialProtection && PartialProtectionHazardActive(why)) return false;
   why="Stop observability/release gate clear.";
   return true;
}

void ObservePartialProtectionState()
{
   datetime now=TimeTradeServer();
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
      bool partial=PositionFlag(pid,tk,"TP1PARTIAL");
      bool done=PositionFlag(pid,tk,"TP1DONE");
      bool logged=(GVRead(PosKey(pid,"PARTIAL_PROTECT_HAZARD_LOGGED"),0)>0.5);

      if(partial && !done)
      {
         datetime tp1=(datetime)GVRead(PosKey(pid,"TP1_TIME"),LegacyTicketRead(tk,"TP1_TIME",0));
         int elapsed=(tp1>0?(int)(now-tp1):0);
         if(elapsed>=MathMax(1,InpPartialProtectionMaxSeconds))
         {
            string why=StringFormat("TP1 partial completed but required breakeven protection has remained incomplete for %d sec.",elapsed);
            if(!logged)
            {
               GVWrite(PosKey(pid,"PARTIAL_PROTECT_HAZARD_LOGGED"),1);
               RecordPartialProtectionObservation(tk,"PARTIAL_PROTECTION_HAZARD",why);
               Print("GPT_EA PARTIAL PROTECTION HAZARD: ",PositionGetString(POSITION_SYMBOL)," - ",why);
            }
            if(InpBlockNewEntriesOnPartialProtection) StopFailurePauseNewEntries(PositionGetString(POSITION_SYMBOL)+": "+why);
         }
      }
      else if(done && logged)
      {
         RecordPartialProtectionObservation(tk,"PARTIAL_PROTECTION_RECOVERED","TP1 partial and required protection are now complete.");
         GVWrite(PosKey(pid,"PARTIAL_PROTECT_HAZARD_LOGGED"),0);
      }
   }
}

string StopObservabilityHealthSummary()
{
   string why="";
   if(!StopObservabilityAllowsNewEntries(why)) return "BLOCKED: "+why;
   return "CLEAR";
}

void StopFailureObservabilityInit()
{
   EnsureStopFailureObservabilityHeader();
   ObservePartialProtectionState();
   Print("GPT_EA stop observability: ",StopObservabilityHealthSummary());
}

void StopFailureObservabilityTimer()
{
   ObservePartialProtectionState();
}
// ===== END INLINED GPT_EA_Part18_StopBrokerObservability.mqh =====
// ===== BEGIN INLINED GPT_EA_Part28_ReleaseCertification.mqh =====
// ============================================================================
// GPT_EA Part 28 - Live release certification / evidence gate
// ============================================================================
// This gate does not replace testing. It prevents a REAL account from being
// armed unless the operator explicitly attests that the release evidence for
// the current release ID has been completed, validated and archived.

input bool   InpRequireReleaseEvidenceOnReal          = true;
input string InpReleaseValidationId                   = "";
input bool   InpReleaseMetaEditorCompilePassed        = false;
input bool   InpReleaseArtifactIdentityArchived       = false;
input bool   InpReleaseStrategyTesterPassed           = false;
input bool   InpReleaseIntelligenceMatrixPassed       = false;
input bool   InpReleaseAdaptivePortfolioPassed        = false;
input bool   InpReleaseExecutionLearningPassed        = false;
input bool   InpReleaseChampionChallengerPassed       = false;
input bool   InpReleaseLifecycleIntegrityPassed       = false;
input bool   InpReleaseBrokerMatrixPassed             = false;
input bool   InpReleaseDeploymentProfilePassed        = false;
input bool   InpReleaseRecoveryTestsPassed            = false;
input bool   InpReleaseStopMatrixPassed               = false;
input bool   InpReleaseBrokerStopPolicyPassed         = false;
input bool   InpReleasePartialProtectionPassed        = false;
input bool   InpReleaseStopObservabilityPassed        = false;
input bool   InpReleaseLiveNewsIntermarketPassed      = false;
input bool   InpReleaseWebFailureInjectionPassed      = false;
input bool   InpReleaseDemoSoakPassed                 = false;
input bool   InpReleaseOperatorReviewPassed           = false;

// Concrete compile/artifact identity.
input string InpReleaseSourceCommitSha                = "";
input string InpReleaseEx5Sha256                      = "";
input string InpReleaseSetSha256                      = ""; // 64 hex or literal NONE
input string InpReleaseCompileEvidenceId              = "";
input string InpReleaseMetaEditorBuild                = "";
input string InpReleaseMT5Build                       = "";

// Versioned demo-soak evidence.
input string InpReleaseSoakSchemaVersion              = "";
input string InpReleaseSoakEvidenceId                 = "";
input string InpReleaseSoakEvidenceDigest             = "";
input int    InpReleaseSoakTradingDays                = 0;
input int    InpReleaseSoakLondonSessions             = 0;
input int    InpReleaseSoakNYSessions                 = 0;
input bool   InpReleaseSoakOverlapObserved            = false;
input bool   InpReleaseSoakNewsDayObserved            = false;
input bool   InpReleaseSoakRolloverObserved           = false;
input bool   InpReleaseSoakRestartObserved            = false;
input bool   InpReleaseSoakReconnectObserved          = false;
input int    InpReleaseSoakScheduledScans             = 0;
input int    InpReleaseSoakContinuousScans            = 0;
input int    InpReleaseSoakCheckpointUpdates          = 0;
input int    InpReleaseSoakBackupCheckpointUpdates    = 0;
input int    InpReleaseSoakZeroToleranceFailures      = 0;
input int    InpReleaseSoakUnresolvedCriticalStates   = 0;
input int    InpReleaseSoakDuplicateOrders            = 0;
input int    InpReleaseSoakDuplicatePartials          = 0;
input int    InpReleaseSoakSLRegressions              = 0;
input int    InpReleaseSoakUnprotectedAuthorizations  = 0;
input int    InpReleaseSoakReleaseGateBypasses        = 0;
input int    InpReleaseSoakAnalyticsDuplicateFinal    = 0;
input int    InpReleaseSoakStopJoinFailures           = 0;
input int    InpReleaseSoakDashboardMismatches        = 0;
input int    InpReleaseSoakRuntimeCriticalErrors      = 0;
input int    InpReleaseSoakSecretsExposed             = 0;
input bool   InpReleaseSoakExecutionLogPresent        = false;
input bool   InpReleaseSoakStopLogPresent             = false;
input bool   InpReleaseSoakReleaseLogPresent          = false;

// Final GO/NO-GO review identity.
input string InpReleaseFinalReviewEvidenceId          = "";
input string InpReleaseFinalReviewDigest              = "";
input string InpReleaseFinalDecision                  = ""; // must be GO
input string InpReleaseFinalReviewer                  = "";
input string InpReleaseFinalReviewTimestamp           = "";

input bool   InpWriteReleaseEvidenceSnapshot          = true;
input string InpReleaseEvidenceSnapshotFile           = "GPT_EA_ReleaseEvidence.csv";

const string GPT_EA_REQUIRED_RELEASE_VALIDATION_ID = "GPT_EA_FULL_INTELLIGENCE_R6_20260917";
const string GPT_EA_REQUIRED_SOAK_SCHEMA_VERSION   = "demo_soak_evidence_v1";

bool ReleaseHexString(const string value,const int expectedLen)
{
   if(StringLen(value)!=expectedLen) return false;
   const string hex="0123456789abcdefABCDEF";
   for(int i=0;i<expectedLen;i++)
   {
      string ch=StringSubstr(value,i,1);
      if(StringFind(hex,ch)<0) return false;
   }
   return true;
}

bool ReleaseArtifactIdentityAllows(string &why)
{
   why="";
   if(!InpReleaseArtifactIdentityArchived)
   {
      why="Artifact identity has not been archived.";
      return false;
   }
   if(!ReleaseHexString(InpReleaseSourceCommitSha,40))
   {
      why="Source commit SHA must be an exact 40-character hexadecimal Git commit.";
      return false;
   }
   if(!ReleaseHexString(InpReleaseEx5Sha256,64))
   {
      why="EX5 SHA-256 must be an exact 64-character hexadecimal digest.";
      return false;
   }
   if(InpReleaseSetSha256!="NONE" && !ReleaseHexString(InpReleaseSetSha256,64))
   {
      why="SET SHA-256 must be 64 hexadecimal characters or literal NONE.";
      return false;
   }
   if(StringLen(InpReleaseCompileEvidenceId)<4)
   {
      why="Compile evidence ID/reference is missing.";
      return false;
   }
   if(StringLen(InpReleaseMetaEditorBuild)<1 || StringLen(InpReleaseMT5Build)<1)
   {
      why="MetaEditor/MT5 build identity is incomplete.";
      return false;
   }
   why="Artifact identity fields are structurally valid.";
   return true;
}

bool ReleaseDemoSoakEvidenceAllows(string &why)
{
   why="";
   if(!InpReleaseDemoSoakPassed)
   {
      why="Demo-soak acceptance has not been attested.";
      return false;
   }
   if(InpReleaseSoakSchemaVersion!=GPT_EA_REQUIRED_SOAK_SCHEMA_VERSION)
   {
      why="Demo-soak schema version is missing or stale.";
      return false;
   }
   if(StringLen(InpReleaseSoakEvidenceId)<4)
   {
      why="Demo-soak evidence ID/reference is missing.";
      return false;
   }
   if(!ReleaseHexString(InpReleaseSoakEvidenceDigest,64))
   {
      why="Demo-soak evidence digest must be a 64-character SHA-256 value.";
      return false;
   }
   if(InpReleaseSoakTradingDays<5)
   {
      why="Demo soak requires at least 5 consecutive trading days.";
      return false;
   }
   if(InpReleaseSoakLondonSessions<3 || InpReleaseSoakNYSessions<3)
   {
      why="Demo soak requires at least 3 London and 3 New York/U.S. cash sessions.";
      return false;
   }
   if(!InpReleaseSoakOverlapObserved || !InpReleaseSoakNewsDayObserved || !InpReleaseSoakRolloverObserved ||
      !InpReleaseSoakRestartObserved || !InpReleaseSoakReconnectObserved)
   {
      why="Demo soak is missing overlap/news/rollover/restart/reconnect coverage.";
      return false;
   }
   if(InpReleaseSoakScheduledScans<1 || InpReleaseSoakContinuousScans<1)
   {
      why="Demo soak must observe both scheduled and continuous scanning.";
      return false;
   }
   if(InpReleaseSoakCheckpointUpdates<1 || InpReleaseSoakBackupCheckpointUpdates<1)
   {
      why="Demo soak must observe primary and backup recovery checkpoint updates.";
      return false;
   }
   if(InpReleaseSoakZeroToleranceFailures!=0 || InpReleaseSoakUnresolvedCriticalStates!=0 ||
      InpReleaseSoakDuplicateOrders!=0 || InpReleaseSoakDuplicatePartials!=0 || InpReleaseSoakSLRegressions!=0 ||
      InpReleaseSoakUnprotectedAuthorizations!=0 || InpReleaseSoakReleaseGateBypasses!=0 ||
      InpReleaseSoakAnalyticsDuplicateFinal!=0 || InpReleaseSoakStopJoinFailures!=0 ||
      InpReleaseSoakDashboardMismatches!=0 || InpReleaseSoakRuntimeCriticalErrors!=0 || InpReleaseSoakSecretsExposed!=0)
   {
      why="Demo soak contains a non-zero zero-tolerance, critical, duplicate, protection, release, analytics, observability, runtime or secret-exposure count.";
      return false;
   }
   if(!InpReleaseSoakExecutionLogPresent || !InpReleaseSoakStopLogPresent || !InpReleaseSoakReleaseLogPresent)
   {
      why="Demo soak is missing required execution/stop/release evidence logs.";
      return false;
   }
   why="Demo-soak schema and quantitative acceptance fields pass.";
   return true;
}

bool ReleaseFinalReviewAllows(string &why)
{
   why="";
   if(!InpReleaseOperatorReviewPassed)
   {
      why="Final operator release review has not been attested.";
      return false;
   }
   if(StringLen(InpReleaseFinalReviewEvidenceId)<4)
   {
      why="Final GO/NO-GO review evidence ID is missing.";
      return false;
   }
   if(!ReleaseHexString(InpReleaseFinalReviewDigest,64))
   {
      why="Final review digest must be a 64-character SHA-256 value.";
      return false;
   }
   if(InpReleaseFinalDecision!="GO")
   {
      why="Final release decision must be literal GO.";
      return false;
   }
   if(StringLen(InpReleaseFinalReviewer)<2 || StringLen(InpReleaseFinalReviewTimestamp)<8)
   {
      why="Final reviewer identity/timestamp is incomplete.";
      return false;
   }
   why="Final GO/NO-GO review identity is structurally valid.";
   return true;
}

bool ReleaseEvidenceAllows(string &why)
{
   why="";
   if(!InpRequireReleaseEvidenceOnReal)
   {
      why="Release-evidence gate disabled by input.";
      return true;
   }
   if((bool)MQLInfoInteger(MQL_TESTER))
   {
      why="Strategy Tester: release-evidence attestation not required.";
      return true;
   }
   ENUM_ACCOUNT_TRADE_MODE mode=(ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE);
   if(mode!=ACCOUNT_TRADE_MODE_REAL)
   {
      why="Demo/contest account: release-evidence attestation is informational only.";
      return true;
   }

   if(InpReleaseValidationId!=GPT_EA_REQUIRED_RELEASE_VALIDATION_ID)
   {
      why="REAL account blocked: release validation ID is missing or stale.";
      return false;
   }
   if(!InpReleaseMetaEditorCompilePassed){ why="REAL account blocked: MetaEditor compile gate has not been attested."; return false; }

   string artifactWhy="";
   if(!ReleaseArtifactIdentityAllows(artifactWhy))
   {
      why="REAL account blocked: "+artifactWhy;
      return false;
   }

   if(!InpReleaseStrategyTesterPassed){ why="REAL account blocked: Strategy Tester validation has not been attested."; return false; }
   if(!InpReleaseIntelligenceMatrixPassed){ why="REAL account blocked: full-intelligence matrix has not been attested."; return false; }
   if(!InpReleaseAdaptivePortfolioPassed){ why="REAL account blocked: adaptive portfolio/risk-supervisor matrix has not been attested."; return false; }
   if(!InpReleaseExecutionLearningPassed){ why="REAL account blocked: execution-learning matrix has not been attested."; return false; }
   if(!InpReleaseChampionChallengerPassed){ why="REAL account blocked: champion/challenger validation has not been attested."; return false; }
   if(!InpReleaseLifecycleIntegrityPassed){ why="REAL account blocked: lifecycle/integrity/replay validation has not been attested."; return false; }
   if(!InpReleaseBrokerMatrixPassed){ why="REAL account blocked: broker/account/symbol matrix has not been attested."; return false; }
   if(!InpReleaseDeploymentProfilePassed){ why="REAL account blocked: deployment profile/drift validation has not been attested."; return false; }
   if(!InpReleaseRecoveryTestsPassed){ why="REAL account blocked: restart/recovery tests have not been attested."; return false; }
   if(!InpReleaseStopMatrixPassed){ why="REAL account blocked: HIGH-priority stop-management matrix has not been attested."; return false; }
   if(!InpReleaseBrokerStopPolicyPassed){ why="REAL account blocked: broker-specific stop policy tests have not been attested."; return false; }
   if(!InpReleasePartialProtectionPassed){ why="REAL account blocked: partial-protection release test has not been attested."; return false; }
   if(!InpReleaseStopObservabilityPassed){ why="REAL account blocked: stop observability validation has not been attested."; return false; }
   if(!InpReleaseLiveNewsIntermarketPassed){ why="REAL account blocked: live news/intermarket validation has not been attested."; return false; }
   if(!InpReleaseWebFailureInjectionPassed){ why="REAL account blocked: OpenAI/WebRequest failure-injection has not been attested."; return false; }

   string soakWhy="";
   if(!ReleaseDemoSoakEvidenceAllows(soakWhy))
   {
      why="REAL account blocked: "+soakWhy;
      return false;
   }

   string reviewWhy="";
   if(!ReleaseFinalReviewAllows(reviewWhy))
   {
      why="REAL account blocked: "+reviewWhy;
      return false;
   }

   why="Release evidence attested for "+GPT_EA_REQUIRED_RELEASE_VALIDATION_ID+" | "+artifactWhy+" | "+soakWhy+" | "+reviewWhy;
   return true;
}

bool ReleaseSafetyAllowsCertified(const string sym,string &why)
{
   string base="";
   if(!ReleaseSafetyAllows(sym,base))
   {
      why=base;
      return false;
   }

   string stopHealth="";
   if(!StopObservabilityAllowsNewEntries(stopHealth))
   {
      why="Stop-health release gate failed: "+stopHealth;
      return false;
   }

   string evidence="";
   if(!ReleaseEvidenceAllows(evidence))
   {
      why=evidence;
      return false;
   }
   why=base+(base!=""?" | ":"")+stopHealth+(stopHealth!=""?" | ":"")+evidence;
   return true;
}

void RefreshCertifiedReleaseState()
{
   bool oldBlocked=g_releaseBlocked;
   string oldReason=g_releaseBlockReason;
   string why="";
   bool ok=ReleaseSafetyAllowsCertified("",why);
   g_releaseBlocked=!ok;
   g_releaseBlockReason=(ok?"All certified release gates pass.":why);
   if(g_releaseBlocked && (!oldBlocked || oldReason!=g_releaseBlockReason))
      Print("GPT_EA CERTIFIED RELEASE BLOCK: ",g_releaseBlockReason);
   else if(!g_releaseBlocked && oldBlocked)
      Print("GPT_EA CERTIFIED RELEASE GATE CLEARED.");
}

string ReleaseGateSummaryCertified()
{
   string why="";
   if(!ReleaseSafetyAllowsCertified("",why)) return "BLOCKED - "+why;
   return "PASS - "+why;
}

void WriteReleaseEvidenceSnapshot()
{
   if(!InpWriteReleaseEvidenceSnapshot || (bool)MQLInfoInteger(MQL_TESTER)) return;
   int h=FileOpen(InpReleaseEvidenceSnapshotFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(h==INVALID_HANDLE)
   {
      Print("Release evidence snapshot open failed: ",GetLastError());
      return;
   }
   if(FileSize(h)==0)
      FileWrite(h,"time","required_release_id","entered_release_id","account_mode","broker","server",
         "source_commit","ex5_sha256","set_sha256","compile_evidence_id","metaeditor_build","mt5_build",
         "compile","artifact_identity","strategy_tester","intelligence_matrix","adaptive_portfolio","execution_learning","champion_challenger","lifecycle_integrity",
         "broker_matrix","deployment_profile","recovery","stop_matrix","broker_stop_policy","partial_protection","stop_observability","live_news_intermarket",
         "web_failure_injection","demo_soak","soak_schema","soak_evidence_id","soak_digest","soak_trading_days","soak_london_sessions","soak_ny_sessions",
         "soak_overlap","soak_news_day","soak_rollover","soak_restart","soak_reconnect","soak_scheduled_scans","soak_continuous_scans",
         "soak_checkpoint_updates","soak_backup_updates","soak_zero_tolerance_failures","soak_unresolved_critical","soak_duplicate_orders","soak_duplicate_partials",
         "soak_sl_regressions","soak_unprotected_authorizations","soak_gate_bypasses","soak_analytics_duplicate_final","soak_stop_join_failures",
         "soak_dashboard_mismatches","soak_runtime_critical_errors","soak_secrets_exposed","soak_execution_log","soak_stop_log","soak_release_log",
         "operator_review","final_review_id","final_review_digest","final_decision","final_reviewer","final_review_timestamp","gate_result","reason");
   FileSeek(h,0,SEEK_END);
   string why=""; bool ok=ReleaseSafetyAllowsCertified("",why);
   FileWrite(h,TimeToString(TimeTradeServer(),TIME_DATE|TIME_SECONDS),GPT_EA_REQUIRED_RELEASE_VALIDATION_ID,InpReleaseValidationId,
      (string)AccountInfoInteger(ACCOUNT_TRADE_MODE),AccountInfoString(ACCOUNT_COMPANY),AccountInfoString(ACCOUNT_SERVER),
      InpReleaseSourceCommitSha,InpReleaseEx5Sha256,InpReleaseSetSha256,InpReleaseCompileEvidenceId,InpReleaseMetaEditorBuild,InpReleaseMT5Build,
      InpReleaseMetaEditorCompilePassed?"1":"0",InpReleaseArtifactIdentityArchived?"1":"0",InpReleaseStrategyTesterPassed?"1":"0",
      InpReleaseIntelligenceMatrixPassed?"1":"0",InpReleaseAdaptivePortfolioPassed?"1":"0",InpReleaseExecutionLearningPassed?"1":"0",
      InpReleaseChampionChallengerPassed?"1":"0",InpReleaseLifecycleIntegrityPassed?"1":"0",InpReleaseBrokerMatrixPassed?"1":"0",
      InpReleaseDeploymentProfilePassed?"1":"0",InpReleaseRecoveryTestsPassed?"1":"0",InpReleaseStopMatrixPassed?"1":"0",
      InpReleaseBrokerStopPolicyPassed?"1":"0",InpReleasePartialProtectionPassed?"1":"0",InpReleaseStopObservabilityPassed?"1":"0",
      InpReleaseLiveNewsIntermarketPassed?"1":"0",InpReleaseWebFailureInjectionPassed?"1":"0",InpReleaseDemoSoakPassed?"1":"0",
      InpReleaseSoakSchemaVersion,InpReleaseSoakEvidenceId,InpReleaseSoakEvidenceDigest,(string)InpReleaseSoakTradingDays,
      (string)InpReleaseSoakLondonSessions,(string)InpReleaseSoakNYSessions,InpReleaseSoakOverlapObserved?"1":"0",
      InpReleaseSoakNewsDayObserved?"1":"0",InpReleaseSoakRolloverObserved?"1":"0",InpReleaseSoakRestartObserved?"1":"0",
      InpReleaseSoakReconnectObserved?"1":"0",(string)InpReleaseSoakScheduledScans,(string)InpReleaseSoakContinuousScans,
      (string)InpReleaseSoakCheckpointUpdates,(string)InpReleaseSoakBackupCheckpointUpdates,(string)InpReleaseSoakZeroToleranceFailures,
      (string)InpReleaseSoakUnresolvedCriticalStates,(string)InpReleaseSoakDuplicateOrders,(string)InpReleaseSoakDuplicatePartials,
      (string)InpReleaseSoakSLRegressions,(string)InpReleaseSoakUnprotectedAuthorizations,(string)InpReleaseSoakReleaseGateBypasses,
      (string)InpReleaseSoakAnalyticsDuplicateFinal,(string)InpReleaseSoakStopJoinFailures,(string)InpReleaseSoakDashboardMismatches,
      (string)InpReleaseSoakRuntimeCriticalErrors,(string)InpReleaseSoakSecretsExposed,InpReleaseSoakExecutionLogPresent?"1":"0",
      InpReleaseSoakStopLogPresent?"1":"0",InpReleaseSoakReleaseLogPresent?"1":"0",InpReleaseOperatorReviewPassed?"1":"0",
      InpReleaseFinalReviewEvidenceId,InpReleaseFinalReviewDigest,InpReleaseFinalDecision,InpReleaseFinalReviewer,InpReleaseFinalReviewTimestamp,
      ok?"PASS":"BLOCK",why);
   FileFlush(h); FileClose(h);
}

void ReleaseCertificationInit()
{
   RefreshCertifiedReleaseState();
   WriteReleaseEvidenceSnapshot();
   Print("GPT_EA release certification: ",g_releaseBlocked?"BLOCK - ":"PASS - ",g_releaseBlockReason);
}

void AdvancedSafetyInitCertified()
{
   AdvancedSafetyInit();
   RefreshCertifiedReleaseState();
}

void AdvancedSafetyTimerCertified()
{
   AdvancedSafetyTimer();
   RefreshCertifiedReleaseState();
}

void StopFailureObservabilityInitCertified()
{
   StopFailureObservabilityInit();
   ReleaseCertificationInit();
}
// ===== END INLINED GPT_EA_Part28_ReleaseCertification.mqh =====
// ===== BEGIN INLINED GPT_EA_Part29_DeploymentDriftGuard.mqh =====
// ============================================================================
// GPT_EA Part 29 - Deployment identity and broker contract drift guard
// ============================================================================

input bool   InpUseDeploymentDriftGuard          = true;
input bool   InpRequireExpectedIdentityOnReal    = false;
input string InpExpectedBrokerCompany            = "";
input string InpExpectedTradeServer              = "";
input string InpExpectedAccountCurrency          = "";
input int    InpExpectedMarginMode               = -1;
input int    InpExpectedAccountLeverage          = 0;
input bool   InpBlockOnStructuralSymbolDrift     = true;

struct DeploymentSymbolBaseline
{
   string symbol;
   int digits;
   double point;
   double tickSize;
   double contractSize;
   double volumeStep;
   long calcMode;
   long executionMode;
   long fillingMode;
};

DeploymentSymbolBaseline g_deploymentBaseline[];
bool g_deploymentDriftBlocked=false;
string g_deploymentDriftReason="Not evaluated";

bool NearlySame(double a,double b,double rel=1e-9)
{
   double scale=MathMax(1.0,MathMax(MathAbs(a),MathAbs(b)));
   return MathAbs(a-b)<=rel*scale;
}

void CaptureDeploymentBaseline()
{
   ArrayResize(g_deploymentBaseline,0);
   for(int i=0;i<ArraySize(g_symbols);i++)
   {
      string sym=g_symbols[i];
      if(sym=="" || !EnsureSymbol(sym)) continue;
      int n=ArraySize(g_deploymentBaseline);
      ArrayResize(g_deploymentBaseline,n+1);
      g_deploymentBaseline[n].symbol=sym;
      g_deploymentBaseline[n].digits=(int)SymbolInfoInteger(sym,SYMBOL_DIGITS);
      g_deploymentBaseline[n].point=SymbolInfoDouble(sym,SYMBOL_POINT);
      g_deploymentBaseline[n].tickSize=SymbolInfoDouble(sym,SYMBOL_TRADE_TICK_SIZE);
      g_deploymentBaseline[n].contractSize=SymbolInfoDouble(sym,SYMBOL_TRADE_CONTRACT_SIZE);
      g_deploymentBaseline[n].volumeStep=SymbolInfoDouble(sym,SYMBOL_VOLUME_STEP);
      g_deploymentBaseline[n].calcMode=SymbolInfoInteger(sym,SYMBOL_TRADE_CALC_MODE);
      g_deploymentBaseline[n].executionMode=SymbolInfoInteger(sym,SYMBOL_TRADE_EXEMODE);
      g_deploymentBaseline[n].fillingMode=SymbolInfoInteger(sym,SYMBOL_FILLING_MODE);
   }
}

bool ExpectedDeploymentIdentityAllows(string &why)
{
   why="";
   if(!InpUseDeploymentDriftGuard){ why="Deployment drift guard disabled."; return true; }

   ENUM_ACCOUNT_TRADE_MODE mode=(ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE);
   bool real=(mode==ACCOUNT_TRADE_MODE_REAL);
   if(real && InpRequireExpectedIdentityOnReal)
   {
      if(InpExpectedBrokerCompany=="" || InpExpectedTradeServer=="" || InpExpectedAccountCurrency=="")
      {
         why="REAL account deployment identity required but expected broker/server/currency is incomplete.";
         return false;
      }
   }

   if(InpExpectedBrokerCompany!="" && AccountInfoString(ACCOUNT_COMPANY)!=InpExpectedBrokerCompany)
   {
      why="Broker company differs from certified deployment identity.";
      return false;
   }
   if(InpExpectedTradeServer!="" && AccountInfoString(ACCOUNT_SERVER)!=InpExpectedTradeServer)
   {
      why="Trade server differs from certified deployment identity.";
      return false;
   }
   if(InpExpectedAccountCurrency!="" && AccountInfoString(ACCOUNT_CURRENCY)!=InpExpectedAccountCurrency)
   {
      why="Account currency differs from certified deployment identity.";
      return false;
   }
   if(InpExpectedMarginMode>=0 && AccountInfoInteger(ACCOUNT_MARGIN_MODE)!=InpExpectedMarginMode)
   {
      why="Account margin mode differs from certified deployment identity.";
      return false;
   }
   if(InpExpectedAccountLeverage>0 && AccountInfoInteger(ACCOUNT_LEVERAGE)!=InpExpectedAccountLeverage)
   {
      why="Account leverage differs from certified deployment identity.";
      return false;
   }
   return true;
}

bool StructuralSymbolDriftAllows(string &why)
{
   why="";
   if(!InpUseDeploymentDriftGuard || !InpBlockOnStructuralSymbolDrift) return true;
   for(int i=0;i<ArraySize(g_deploymentBaseline);i++)
   {
      string sym=g_deploymentBaseline[i].symbol;
      if(!EnsureSymbol(sym))
      {
         why=sym+" is no longer available after deployment baseline capture.";
         return false;
      }
      int digits=(int)SymbolInfoInteger(sym,SYMBOL_DIGITS);
      double point=SymbolInfoDouble(sym,SYMBOL_POINT);
      double tick=SymbolInfoDouble(sym,SYMBOL_TRADE_TICK_SIZE);
      double contract=SymbolInfoDouble(sym,SYMBOL_TRADE_CONTRACT_SIZE);
      double step=SymbolInfoDouble(sym,SYMBOL_VOLUME_STEP);
      long calc=SymbolInfoInteger(sym,SYMBOL_TRADE_CALC_MODE);
      long exec=SymbolInfoInteger(sym,SYMBOL_TRADE_EXEMODE);
      long fill=SymbolInfoInteger(sym,SYMBOL_FILLING_MODE);

      if(digits!=g_deploymentBaseline[i].digits || !NearlySame(point,g_deploymentBaseline[i].point) ||
         !NearlySame(tick,g_deploymentBaseline[i].tickSize) || !NearlySame(contract,g_deploymentBaseline[i].contractSize) ||
         !NearlySame(step,g_deploymentBaseline[i].volumeStep) || calc!=g_deploymentBaseline[i].calcMode ||
         exec!=g_deploymentBaseline[i].executionMode || fill!=g_deploymentBaseline[i].fillingMode)
      {
         why=StringFormat("%s structural broker contract drift detected: digits/point/tick/contract/volume-step/calc/execution/filling profile changed.",sym);
         return false;
      }
   }
   return true;
}

bool DeploymentDriftAllows(string &why)
{
   string id="";
   if(!ExpectedDeploymentIdentityAllows(id)){ why=id; return false; }
   string structural="";
   if(!StructuralSymbolDriftAllows(structural)){ why=structural; return false; }
   why="Deployment identity and structural symbol profile stable.";
   return true;
}

bool ReleaseSafetyAllowsR6(const string sym,string &why)
{
   string certified="";
   if(!ReleaseSafetyAllowsCertified(sym,certified))
   {
      why=certified;
      return false;
   }
   string drift="";
   if(!DeploymentDriftAllows(drift))
   {
      why="Deployment drift gate failed: "+drift;
      return false;
   }
   why=certified+(certified!=""?" | ":"")+drift;
   return true;
}

void RefreshR6ReleaseState()
{
   bool oldBlocked=g_releaseBlocked;
   string oldReason=g_releaseBlockReason;
   string why="";
   bool ok=ReleaseSafetyAllowsR6("",why);
   g_deploymentDriftBlocked=!ok && StringFind(why,"Deployment drift gate failed")>=0;
   g_deploymentDriftReason=(g_deploymentDriftBlocked?why:"Deployment drift gate clear.");
   g_releaseBlocked=!ok;
   g_releaseBlockReason=(ok?"All R6 release gates pass.":why);
   if(g_releaseBlocked && (!oldBlocked || oldReason!=g_releaseBlockReason))
      Print("GPT_EA R6 RELEASE BLOCK: ",g_releaseBlockReason);
   else if(!g_releaseBlocked && oldBlocked)
      Print("GPT_EA R6 RELEASE GATE CLEARED.");
}

string ReleaseGateSummaryR6()
{
   string why="";
   return ReleaseSafetyAllowsR6("",why)?"PASS - "+why:"BLOCKED - "+why;
}

void AdvancedSafetyInitR6()
{
   AdvancedSafetyInitCertified();
   CaptureDeploymentBaseline();
   RefreshR6ReleaseState();
}

void AdvancedSafetyTimerR6()
{
   AdvancedSafetyTimerCertified();
   RefreshR6ReleaseState();
}

void StopFailureObservabilityInitR6()
{
   StopFailureObservabilityInit();
   ReleaseCertificationInit();
   if(ArraySize(g_deploymentBaseline)==0) CaptureDeploymentBaseline();
   RefreshR6ReleaseState();
}

void DeploymentDriftGuardInit()
{
   if(ArraySize(g_deploymentBaseline)==0) CaptureDeploymentBaseline();
   RefreshR6ReleaseState();
   Print("GPT_EA deployment drift guard: ",g_deploymentDriftBlocked?"BLOCK - ":"PASS - ",g_deploymentDriftReason);
}
// ===== END INLINED GPT_EA_Part29_DeploymentDriftGuard.mqh =====
// ===== BEGIN INLINED GPT_EA_Part28B_CIReleaseEvidence.mqh =====
// ============================================================================
// GPT_EA Part 28B - R6 supplemental CI / runner / MT5 / soak evidence binding
// ============================================================================
// Supplemental fail-closed release evidence layered on top of Part28/Part29.
// REAL arming requires runner recovery + acceptance, executed CI provenance,
// MT5 validation evidence, and the five-day reconciled soak record.

input bool   InpReleaseRunnerRecoveryPassed             = false;
input string InpReleaseRunnerRecoverySchemaVersion      = "";
input string InpReleaseRunnerRecoveryEvidenceId         = "";
input string InpReleaseRunnerRecoveryDigest             = "";

input bool   InpReleaseRunnerRecoveryAcceptancePassed        = false;
input string InpReleaseRunnerRecoveryAcceptanceSchemaVersion = "";
input string InpReleaseRunnerRecoveryAcceptanceId            = "";
input string InpReleaseRunnerRecoveryAcceptanceDigest        = "";

input bool   InpReleaseCIStaticEvidencePassed           = false;
input string InpReleaseCISchemaVersion                  = "";
input long   InpReleaseCIRunId                          = 0;
input int    InpReleaseCIRunAttempt                     = 0;
input long   InpReleaseCIJobId                          = 0;
input long   InpReleaseCIRunnerId                       = 0;
input int    InpReleaseCIStepsExecuted                  = 0;
input string InpReleaseCIHeadSha                        = "";
input string InpReleaseCIEvidenceDigest                 = "";
input string InpReleaseCIConclusion                     = "";
input string InpReleaseCIArtifactName                   = "";
input bool   InpReleaseCIArtifactArchived               = false;
input bool   InpReleaseCIAttestationVerified            = false;
input string InpReleaseCIBundleSchemaVersion            = "";
input string InpReleaseCIBundleDigest                   = "";
input bool   InpReleaseCIBundleValidated                = false;

input bool   InpReleaseMT5ValidationPassed              = false;
input string InpReleaseMT5ValidationSchemaVersion       = "";
input string InpReleaseMT5ValidationEvidenceId          = "";
input string InpReleaseMT5ValidationDigest              = "";

input bool   InpReleaseResilienceHardeningPassed        = false;
input string InpReleaseResilienceSchemaVersion          = "";
input string InpReleaseResilienceEvidenceId             = "";
input string InpReleaseResilienceDigest                 = "";
input string InpReleaseCertifiedConfigFingerprint       = "";

input string InpReleaseSoakAcceptanceSchemaVersion      = "";
input string InpReleaseSoakAcceptanceRecordId           = "";
input string InpReleaseSoakAcceptanceRecordDigest       = "";

input bool   InpWriteR6SupplementalEvidenceSnapshot     = true;
input string InpR6SupplementalEvidenceSnapshotFile      = "GPT_EA_R6SupplementalEvidence.csv";

const string GPT_EA_REQUIRED_RUNNER_RECOVERY_SCHEMA       = "runner_recovery_evidence_v1";
const string GPT_EA_REQUIRED_RUNNER_ACCEPTANCE_SCHEMA     = "runner_recovery_acceptance_v1";
const string GPT_EA_REQUIRED_CI_SCHEMA_VERSION            = "github_actions_static_evidence_v1";
const string GPT_EA_REQUIRED_CI_BUNDLE_SCHEMA             = "ci_evidence_bundle_v1";
const string GPT_EA_REQUIRED_MT5_VALIDATION_SCHEMA        = "mt5_validation_evidence_v2";
const string GPT_EA_REQUIRED_RESILIENCE_SCHEMA             = "resilience_hardening_evidence_v1";
const string GPT_EA_REQUIRED_SOAK_RECORD_SCHEMA           = "five_day_soak_acceptance_v2";

bool ReleaseRunnerRecoveryEvidenceAllows(string &why)
{
   why="";
   if(!InpReleaseRunnerRecoveryPassed)
   {
      why="GitHub hosted-runner recovery evidence has not been attested.";
      return false;
   }
   if(InpReleaseRunnerRecoverySchemaVersion!=GPT_EA_REQUIRED_RUNNER_RECOVERY_SCHEMA)
   {
      why="Runner-recovery evidence schema is missing or stale.";
      return false;
   }
   if(StringLen(InpReleaseRunnerRecoveryEvidenceId)<8)
   {
      why="Runner-recovery evidence ID is missing.";
      return false;
   }
   if(!ReleaseHexString(InpReleaseRunnerRecoveryDigest,64))
   {
      why="Runner-recovery evidence digest must be a 64-character SHA-256 value.";
      return false;
   }
   why="Hosted-runner recovery evidence PASS.";
   return true;
}

bool ReleaseRunnerRecoveryAcceptanceAllows(string &why)
{
   why="";
   if(!InpReleaseRunnerRecoveryAcceptancePassed)
   {
      why="Runner-recovery production acceptance matrix has not been attested.";
      return false;
   }
   if(InpReleaseRunnerRecoveryAcceptanceSchemaVersion!=GPT_EA_REQUIRED_RUNNER_ACCEPTANCE_SCHEMA)
   {
      why="Runner-recovery acceptance schema is missing or stale.";
      return false;
   }
   if(StringLen(InpReleaseRunnerRecoveryAcceptanceId)<8)
   {
      why="Runner-recovery acceptance ID is missing.";
      return false;
   }
   if(!ReleaseHexString(InpReleaseRunnerRecoveryAcceptanceDigest,64))
   {
      why="Runner-recovery acceptance digest must be a 64-character SHA-256 value.";
      return false;
   }
   why="Runner-recovery production acceptance matrix PASS.";
   return true;
}

bool ReleaseCIStaticEvidenceAllows(string &why)
{
   why="";
   if(!InpReleaseCIStaticEvidencePassed)
   {
      why="GitHub Actions static evidence has not been attested.";
      return false;
   }
   if(InpReleaseCISchemaVersion!=GPT_EA_REQUIRED_CI_SCHEMA_VERSION)
   {
      why="GitHub Actions evidence schema is missing or stale.";
      return false;
   }
   if(InpReleaseCIRunId<=0 || InpReleaseCIRunAttempt<=0 || InpReleaseCIJobId<=0 || InpReleaseCIRunnerId<=0)
   {
      why="GitHub Actions evidence must identify an executed run/attempt/job with runner_id > 0.";
      return false;
   }
   if(InpReleaseCIStepsExecuted<7)
   {
      why="GitHub Actions evidence shows too few executed workflow steps.";
      return false;
   }
   if(!ReleaseHexString(InpReleaseCIHeadSha,40) || InpReleaseCIHeadSha!=InpReleaseSourceCommitSha)
   {
      why="GitHub Actions head SHA is invalid or does not match the certified source commit.";
      return false;
   }
   if(!ReleaseHexString(InpReleaseCIEvidenceDigest,64))
   {
      why="GitHub Actions evidence digest must be a 64-character SHA-256 value.";
      return false;
   }
   if(InpReleaseCIConclusion!="success")
   {
      why="GitHub Actions conclusion must be literal success.";
      return false;
   }
   if(StringLen(InpReleaseCIArtifactName)<8 || !InpReleaseCIArtifactArchived)
   {
      why="GitHub Actions evidence artifact is missing or not archived.";
      return false;
   }
   if(!InpReleaseCIAttestationVerified)
   {
      why="GitHub artifact provenance attestation has not been verified.";
      return false;
   }
   if(InpReleaseCIBundleSchemaVersion!=GPT_EA_REQUIRED_CI_BUNDLE_SCHEMA)
   {
      why="GitHub Actions CI bundle schema is missing or stale.";
      return false;
   }
   if(!ReleaseHexString(InpReleaseCIBundleDigest,64) || !InpReleaseCIBundleValidated)
   {
      why="GitHub Actions final CI evidence bundle has not been validated with a valid SHA-256 digest.";
      return false;
   }
   why="Executed GitHub Actions static evidence, completed-job identity, archive, provenance attestation and final bundle PASS.";
   return true;
}

bool ReleaseMT5ValidationEvidenceAllows(string &why)
{
   why="";
   if(!InpReleaseMT5ValidationPassed)
   {
      why="MT5/MetaEditor validation evidence has not been attested.";
      return false;
   }
   if(InpReleaseMT5ValidationSchemaVersion!=GPT_EA_REQUIRED_MT5_VALIDATION_SCHEMA)
   {
      why="MT5 validation evidence schema is missing or stale.";
      return false;
   }
   if(StringLen(InpReleaseMT5ValidationEvidenceId)<8)
   {
      why="MT5 validation evidence ID is missing.";
      return false;
   }
   if(!ReleaseHexString(InpReleaseMT5ValidationDigest,64))
   {
      why="MT5 validation evidence digest must be a 64-character SHA-256 value.";
      return false;
   }
   why="MT5/MetaEditor v2 compile, tester, execution-resilience, broker-runtime, protection and live API evidence PASS.";
   return true;
}

bool ReleaseResilienceHardeningAllows(string &why)
{
   why="";
   if(!InpReleaseResilienceHardeningPassed)
   {
      why="R6 resilience-hardening acceptance matrix has not been attested.";
      return false;
   }
   if(InpReleaseResilienceSchemaVersion!=GPT_EA_REQUIRED_RESILIENCE_SCHEMA)
   {
      why="Resilience-hardening evidence schema is missing or stale.";
      return false;
   }
   if(StringLen(InpReleaseResilienceEvidenceId)<8)
   {
      why="Resilience-hardening evidence ID is missing.";
      return false;
   }
   if(!ReleaseHexString(InpReleaseResilienceDigest,64))
   {
      why="Resilience-hardening evidence digest must be a 64-character SHA-256 value.";
      return false;
   }
   if(StringLen(InpReleaseCertifiedConfigFingerprint)!=8)
   {
      why="Certified runtime configuration fingerprint must be exactly 8 hexadecimal characters.";
      return false;
   }
   for(int i=0;i<8;i++)
   {
      ushort c=StringGetCharacter(InpReleaseCertifiedConfigFingerprint,i);
      bool hex=((c>='0'&&c<='9')||(c>='A'&&c<='F')||(c>='a'&&c<='f'));
      if(!hex){ why="Certified configuration fingerprint contains non-hex characters."; return false; }
   }
   why="R6 resilience hardening and certified configuration fingerprint PASS.";
   return true;
}

bool ReleaseFiveDaySoakRecordAllows(string &why)
{
   why="";
   if(InpReleaseSoakAcceptanceSchemaVersion!=GPT_EA_REQUIRED_SOAK_RECORD_SCHEMA)
   {
      why="Five-day soak acceptance schema is missing or stale.";
      return false;
   }
   if(StringLen(InpReleaseSoakAcceptanceRecordId)<8)
   {
      why="Five-day soak acceptance record ID is missing.";
      return false;
   }
   if(!ReleaseHexString(InpReleaseSoakAcceptanceRecordDigest,64))
   {
      why="Five-day soak acceptance record digest must be a 64-character SHA-256 value.";
      return false;
   }
   why="Five-day soak acceptance v2 identity/digest structurally PASS.";
   return true;
}

bool ReleaseSupplementalR6EvidenceAllows(string &why)
{
   why="";
   if((bool)MQLInfoInteger(MQL_TESTER))
   {
      why="Strategy Tester: supplemental R6 release evidence is informational only.";
      return true;
   }
   ENUM_ACCOUNT_TRADE_MODE mode=(ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE);
   if(mode!=ACCOUNT_TRADE_MODE_REAL)
   {
      why="Demo/contest account: supplemental R6 release evidence is informational only.";
      return true;
   }

   string runner="";
   if(!ReleaseRunnerRecoveryEvidenceAllows(runner))
   {
      why="REAL account blocked: "+runner;
      return false;
   }
   string runnerAcceptance="";
   if(!ReleaseRunnerRecoveryAcceptanceAllows(runnerAcceptance))
   {
      why="REAL account blocked: "+runnerAcceptance;
      return false;
   }
   string ci="";
   if(!ReleaseCIStaticEvidenceAllows(ci))
   {
      why="REAL account blocked: "+ci;
      return false;
   }
   string mt5="";
   if(!ReleaseMT5ValidationEvidenceAllows(mt5))
   {
      why="REAL account blocked: "+mt5;
      return false;
   }
   string resilience="";
   if(!ReleaseResilienceHardeningAllows(resilience))
   {
      why="REAL account blocked: "+resilience;
      return false;
   }
   string soak="";
   if(!ReleaseFiveDaySoakRecordAllows(soak))
   {
      why="REAL account blocked: "+soak;
      return false;
   }
   why=runner+" | "+runnerAcceptance+" | "+ci+" | "+mt5+" | "+resilience+" | "+soak;
   return true;
}

bool ReleaseSafetyAllowsR6Evidence(const string sym,string &why)
{
   string base="";
   if(!ReleaseSafetyAllowsR6(sym,base))
   {
      why=base;
      return false;
   }
   string supplemental="";
   if(!ReleaseSupplementalR6EvidenceAllows(supplemental))
   {
      why=supplemental;
      return false;
   }
   why=base+(base!=""?" | ":"")+supplemental;
   return true;
}

void RefreshR6EvidenceReleaseState()
{
   bool oldBlocked=g_releaseBlocked;
   string oldReason=g_releaseBlockReason;
   string why="";
   bool ok=ReleaseSafetyAllowsR6Evidence("",why);
   g_releaseBlocked=!ok;
   g_releaseBlockReason=(ok?"All R6 release and supplemental evidence gates pass.":why);
   if(g_releaseBlocked && (!oldBlocked || oldReason!=g_releaseBlockReason))
      Print("GPT_EA R6 EVIDENCE RELEASE BLOCK: ",g_releaseBlockReason);
   else if(!g_releaseBlocked && oldBlocked)
      Print("GPT_EA R6 EVIDENCE RELEASE GATE CLEARED.");
}

string ReleaseGateSummaryR6Evidence()
{
   string why="";
   return ReleaseSafetyAllowsR6Evidence("",why)?"PASS - "+why:"BLOCKED - "+why;
}

void WriteR6SupplementalEvidenceSnapshot()
{
   if(!InpWriteR6SupplementalEvidenceSnapshot || (bool)MQLInfoInteger(MQL_TESTER)) return;
   int h=FileOpen(InpR6SupplementalEvidenceSnapshotFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(h==INVALID_HANDLE) return;
   if(FileSize(h)==0)
      FileWrite(h,"time","required_release_id","source_commit",
         "runner_recovery_passed","runner_recovery_schema","runner_recovery_id","runner_recovery_digest",
         "runner_acceptance_passed","runner_acceptance_schema","runner_acceptance_id","runner_acceptance_digest",
         "ci_passed","ci_schema","ci_run_id","ci_run_attempt","ci_job_id","ci_runner_id","ci_steps","ci_head_sha","ci_digest",
         "ci_conclusion","ci_artifact","ci_artifact_archived","ci_attestation_verified","ci_bundle_schema","ci_bundle_digest","ci_bundle_validated",
         "mt5_validation_passed","mt5_validation_schema","mt5_validation_id","mt5_validation_digest",
         "resilience_passed","resilience_schema","resilience_id","resilience_digest","certified_config_fingerprint",
         "soak_acceptance_schema","soak_record_id","soak_record_digest","gate_result","reason");
   FileSeek(h,0,SEEK_END);
   string why=""; bool ok=ReleaseSafetyAllowsR6Evidence("",why);
   FileWrite(h,TimeToString(TimeTradeServer(),TIME_DATE|TIME_SECONDS),GPT_EA_REQUIRED_RELEASE_VALIDATION_ID,InpReleaseSourceCommitSha,
      InpReleaseRunnerRecoveryPassed?"1":"0",InpReleaseRunnerRecoverySchemaVersion,InpReleaseRunnerRecoveryEvidenceId,InpReleaseRunnerRecoveryDigest,
      InpReleaseRunnerRecoveryAcceptancePassed?"1":"0",InpReleaseRunnerRecoveryAcceptanceSchemaVersion,InpReleaseRunnerRecoveryAcceptanceId,InpReleaseRunnerRecoveryAcceptanceDigest,
      InpReleaseCIStaticEvidencePassed?"1":"0",InpReleaseCISchemaVersion,(string)InpReleaseCIRunId,(string)InpReleaseCIRunAttempt,
      (string)InpReleaseCIJobId,(string)InpReleaseCIRunnerId,(string)InpReleaseCIStepsExecuted,InpReleaseCIHeadSha,InpReleaseCIEvidenceDigest,
      InpReleaseCIConclusion,InpReleaseCIArtifactName,InpReleaseCIArtifactArchived?"1":"0",InpReleaseCIAttestationVerified?"1":"0",
      InpReleaseCIBundleSchemaVersion,InpReleaseCIBundleDigest,InpReleaseCIBundleValidated?"1":"0",
      InpReleaseMT5ValidationPassed?"1":"0",InpReleaseMT5ValidationSchemaVersion,InpReleaseMT5ValidationEvidenceId,InpReleaseMT5ValidationDigest,
      InpReleaseResilienceHardeningPassed?"1":"0",InpReleaseResilienceSchemaVersion,InpReleaseResilienceEvidenceId,InpReleaseResilienceDigest,
      InpReleaseCertifiedConfigFingerprint,
      InpReleaseSoakAcceptanceSchemaVersion,InpReleaseSoakAcceptanceRecordId,InpReleaseSoakAcceptanceRecordDigest,
      ok?"PASS":"BLOCK",why);
   FileFlush(h); FileClose(h);
}

void AdvancedSafetyInitR6Evidence()
{
   AdvancedSafetyInitR6();
   RefreshR6EvidenceReleaseState();
}

void AdvancedSafetyTimerR6Evidence()
{
   AdvancedSafetyTimerR6();
   RefreshR6EvidenceReleaseState();
}

void StopFailureObservabilityInitR6Evidence()
{
   StopFailureObservabilityInitR6();
   RefreshR6EvidenceReleaseState();
   WriteR6SupplementalEvidenceSnapshot();
}
// ===== END INLINED GPT_EA_Part28B_CIReleaseEvidence.mqh =====
// ===== BEGIN INLINED GPT_EA_Part37A_APICompat.mqh =====
// ============================================================================
// GPT_EA Part 37A - API transport compatibility helpers
// ============================================================================

string APITrim(const string source)
{
   string value=source;
   StringTrimLeft(value);
   StringTrimRight(value);
   return value;
}
// ===== END INLINED GPT_EA_Part37A_APICompat.mqh =====
#define Trim APITrim
// ===== BEGIN INLINED GPT_EA_Part37_APITransport.mqh =====
// ============================================================================
// GPT_EA Part 37 - OpenAI/WebRequest transport abstraction and release guard
// ============================================================================
// DIRECT mode is intended for private development/single-terminal operation.
// PROXY mode keeps the OpenAI API key server-side for distributed deployments.
// The proxy contract is OpenAI-Responses-compatible: it accepts the same JSON
// request body and returns the upstream status/body while authenticating MT5
// with a separate, revocable proxy token.

enum GPTAPITransportMode
{
   GPT_API_DIRECT_OPENAI = 0,
   GPT_API_SECURE_PROXY  = 1
};

input GPTAPITransportMode InpAPITransportMode              = GPT_API_DIRECT_OPENAI;
input string              InpAPIProxyEndpoint              = "";
input string              InpAPIProxyToken                 = ""; // separate scoped proxy credential; never use the OpenAI key here
input bool                InpAPIRequireHTTPS               = true;
input bool                InpAPIRequireProxyOnReal         = false;
input int                 InpAPITransportMaxTimeoutMs      = 20000;
input int                 InpAPITransportFailureThreshold  = 3;
input int                 InpAPITransportBackoffSeconds    = 60;
input int                 InpAPIAuthBackoffSeconds         = 300;
input bool                InpAPIBlockDuringBackoff         = true;
input bool                InpAPIWriteHealthLog             = true;
input string              InpAPIHealthLogFile              = "GPT_EA_APIHealth.csv";
input bool                InpReleaseAPITransportPassed     = false;

int      g_apiTransportFailures=0;
datetime g_apiTransportNextRetry=0;
long     g_apiTransportSequence=0;
bool     g_apiTransportWasFailing=false;

string APITransportModeText()
{
   return InpAPITransportMode==GPT_API_SECURE_PROXY ? "PROXY" : "DIRECT_OPENAI";
}

bool APIStartsWith(const string value,const string prefix)
{
   return StringLen(value)>=StringLen(prefix) && StringSubstr(value,0,StringLen(prefix))==prefix;
}

bool APITrustedDirectEndpoint(const string endpoint)
{
   // Prevent accidentally sending the OpenAI bearer token to an arbitrary host.
   return endpoint=="https://api.openai.com" || APIStartsWith(endpoint,"https://api.openai.com/");
}

string APITransportAllowListURL()
{
   if(InpAPITransportMode==GPT_API_SECURE_PROXY) return Trim(InpAPIProxyEndpoint);
   return "https://api.openai.com";
}

// Active legacy request builders check InpOpenAIAPIKey before calling WebRequest.
// The entry file macro-rewrites those references to this helper while the files
// are included. DIRECT returns the real local key. PROXY returns only a harmless
// non-secret marker when a proxy credential is configured. The resulting legacy
// Authorization header is discarded by GPTAPIWebRequest before the proxy call.
string APITransportLegacyCredential()
{
   if(InpAPITransportMode==GPT_API_SECURE_PROXY)
      return StringLen(Trim(InpAPIProxyToken))>=12 ? "PROXY_TRANSPORT_ACTIVE" : "";
   return InpOpenAIAPIKey;
}

bool APITransportConfigurationAllows(string &why)
{
   why="";
   if(!InpUseOpenAI)
   {
      why="OpenAI disabled; API transport is idle.";
      return true;
   }
   if((bool)MQLInfoInteger(MQL_TESTER))
   {
      why="Strategy Tester: WebRequest transport is unavailable by platform design.";
      return true;
   }

   bool real=((ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_REAL);
   if(real && InpAPIRequireProxyOnReal && InpAPITransportMode!=GPT_API_SECURE_PROXY)
   {
      why="REAL account requires secure proxy transport by configuration.";
      return false;
   }

   if(InpAPITransportMode==GPT_API_DIRECT_OPENAI)
   {
      string endpoint=Trim(InpOpenAIEndpoint);
      if(endpoint=="")
      {
         why="Direct OpenAI endpoint is empty.";
         return false;
      }
      if(InpAPIRequireHTTPS && !APIStartsWith(endpoint,"https://"))
      {
         why="Direct OpenAI endpoint must use HTTPS.";
         return false;
      }
      if(!APITrustedDirectEndpoint(endpoint))
      {
         why="Direct mode refuses to send the OpenAI bearer key to a non-api.openai.com endpoint.";
         return false;
      }
      if(StringLen(Trim(InpOpenAIAPIKey))<20)
      {
         why="Direct mode requires a locally configured OpenAI API key.";
         return false;
      }
      why="DIRECT_OPENAI configured. MT5 allow-list must contain https://api.openai.com.";
      return true;
   }

   string proxy=Trim(InpAPIProxyEndpoint);
   if(proxy=="")
   {
      why="Proxy mode selected but InpAPIProxyEndpoint is empty.";
      return false;
   }
   if(InpAPIRequireHTTPS && !APIStartsWith(proxy,"https://"))
   {
      why="Proxy endpoint must use HTTPS.";
      return false;
   }
   if(StringLen(Trim(InpAPIProxyToken))<12)
   {
      why="Proxy mode requires a scoped proxy token of at least 12 characters.";
      return false;
   }
   if(Trim(InpOpenAIAPIKey)!="" && Trim(InpAPIProxyToken)==Trim(InpOpenAIAPIKey))
   {
      why="Proxy token must not reuse the OpenAI API key.";
      return false;
   }
   why="SECURE_PROXY configured. Add the proxy HTTPS origin/endpoint to the MT5 WebRequest allow-list.";
   return true;
}

string APIHeaderValueCI(const string headers,const string key)
{
   string low=headers;
   string needle=key;
   StringToLower(low);
   StringToLower(needle);
   needle+=":";
   int p=StringFind(low,needle);
   if(p<0) return "";
   p+=StringLen(needle);
   int e=StringFind(headers,"\r\n",p);
   if(e<0) e=StringLen(headers);
   return Trim(StringSubstr(headers,p,e-p));
}

void APIStringToResult(const string text,char &result[])
{
   int n=StringToCharArray(text,result,0,WHOLE_ARRAY,CP_UTF8);
   if(n>0) ArrayResize(result,n-1);
}

string APINewTraceId()
{
   g_apiTransportSequence++;
   return StringFormat("gpt-ea-%I64d-%I64d",(long)TimeLocal(),g_apiTransportSequence);
}

void APIWriteHealthEvent(const string trace,const int code,const int mqlError,const string requestId,const string outcome)
{
   if(!InpAPIWriteHealthLog || (bool)MQLInfoInteger(MQL_TESTER)) return;
   int h=FileOpen(InpAPIHealthLogFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(h==INVALID_HANDLE) return;
   if(FileSize(h)==0)
      FileWrite(h,"time","transport","trace_id","http_code","mql_error","consecutive_failures","next_retry","request_id","outcome");
   FileSeek(h,0,SEEK_END);
   string retryText=(g_apiTransportNextRetry>0?TimeToString(g_apiTransportNextRetry,TIME_DATE|TIME_SECONDS):"");
   FileWrite(h,TimeToString(TimeLocal(),TIME_DATE|TIME_SECONDS),APITransportModeText(),trace,(string)code,(string)mqlError,
      (string)g_apiTransportFailures,retryText,requestId,outcome);
   FileFlush(h);
   FileClose(h);
}

void APITransportRecordOutcome(const string trace,const int code,const int mqlError,const string responseHeaders)
{
   string requestId=APIHeaderValueCI(responseHeaders,"x-request-id");
   bool success=(code>=200 && code<300);
   if(success)
   {
      bool recovered=g_apiTransportWasFailing || g_apiTransportFailures>0 || g_apiTransportNextRetry>0;
      g_apiTransportFailures=0;
      g_apiTransportNextRetry=0;
      g_apiTransportWasFailing=false;
      if(recovered) APIWriteHealthEvent(trace,code,mqlError,requestId,"RECOVERED");
      return;
   }

   g_apiTransportWasFailing=true;
   g_apiTransportFailures++;
   int threshold=(InpAPITransportFailureThreshold<1?1:InpAPITransportFailureThreshold);
   int retrySeconds=(InpAPITransportBackoffSeconds<5?5:InpAPITransportBackoffSeconds);
   int authBackoff=(InpAPIAuthBackoffSeconds<retrySeconds?retrySeconds:InpAPIAuthBackoffSeconds);
   bool authFailure=(code==401 || code==403);
   bool rateLimited=(code==429);
   bool transportFailure=(code==598 || code==599);
   bool serverFailure=(code>=500 && code<=599);

   if(authFailure)
      g_apiTransportNextRetry=TimeLocal()+authBackoff;
   else if(rateLimited || g_apiTransportFailures>=threshold || transportFailure || serverFailure)
      g_apiTransportNextRetry=TimeLocal()+retrySeconds;

   string outcome=authFailure?"AUTH_BLOCK":(rateLimited?"RATE_LIMIT":(transportFailure?"TRANSPORT_FAIL":(serverFailure?"SERVER_FAIL":"HTTP_FAIL")));
   APIWriteHealthEvent(trace,code,mqlError,requestId,outcome);
}

int GPTAPIWebRequest(const string method,const string url,const string headers,const int timeout,const char &data[],char &result[],string &result_headers)
{
   ArrayResize(result,0);
   result_headers="";
   GVWrite(SysKey("MODEL_REQ"),GVRead(SysKey("MODEL_REQ"),0)+1);

   string config="";
   if(!APITransportConfigurationAllows(config))
   {
      GVWrite(SysKey("MODEL_FAIL"),GVRead(SysKey("MODEL_FAIL"),0)+1);
      APIStringToResult("API transport configuration blocked: "+config,result);
      return 598;
   }

   datetime now=TimeLocal();
   if(InpAPIBlockDuringBackoff && g_apiTransportNextRetry>now)
   {
      GVWrite(SysKey("MODEL_FAIL"),GVRead(SysKey("MODEL_FAIL"),0)+1);
      APIStringToResult(StringFormat("API transport backoff active until %s.",TimeToString(g_apiTransportNextRetry,TIME_DATE|TIME_SECONDS)),result);
      result_headers="X-GPT-EA-Transport: backoff\r\n";
      return 598;
   }

   string trace=APINewTraceId();
   if(ChaosInjectAPITimeout())
   {
      APIStringToResult("CHAOS: synthetic API timeout before network transport.",result);
      result_headers="X-GPT-EA-Transport: chaos-timeout\r\n";
      GVWrite(SysKey("MODEL_FAIL"),GVRead(SysKey("MODEL_FAIL"),0)+1);
      APITransportRecordOutcome(trace,599,0,result_headers);
      return 599;
   }
   string target=url;
   string outgoingHeaders=headers;
   if(InpAPITransportMode==GPT_API_SECURE_PROXY)
   {
      target=Trim(InpAPIProxyEndpoint);
      // Deliberately discard the caller's OpenAI Authorization header. The
      // proxy injects its server-side OpenAI credential instead.
      outgoingHeaders="Content-Type: application/json\r\n";
      outgoingHeaders+="Accept: application/json\r\n";
      outgoingHeaders+="X-GPT-EA-Token: "+InpAPIProxyToken+"\r\n";
      outgoingHeaders+="X-GPT-EA-Request-Id: "+trace+"\r\n";
      outgoingHeaders+="X-GPT-EA-Upstream: openai-responses\r\n";
   }
   else
   {
      int hlen=StringLen(outgoingHeaders);
      if(hlen>=2 && StringSubstr(outgoingHeaders,hlen-2,2)!="\r\n") outgoingHeaders+="\r\n";
      outgoingHeaders+="X-Client-Request-Id: "+trace+"\r\n";
   }

   int maxTimeout=(InpAPITransportMaxTimeoutMs<1000?1000:InpAPITransportMaxTimeoutMs);
   int effectiveTimeout=(timeout<1000?1000:timeout);
   if(effectiveTimeout>maxTimeout) effectiveTimeout=maxTimeout;

   ulong transportStart=GetTickCount64();
   ResetLastError();
   int code=WebRequest(method,target,outgoingHeaders,effectiveTimeout,data,result,result_headers);
   double transportLatency=(double)(GetTickCount64()-transportStart);
   double oldLatency=GVRead(SysKey("MODEL_LATENCY_EWMA_MS"),0);
   GVWrite(SysKey("MODEL_LATENCY_EWMA_MS"),(oldLatency<=0?transportLatency:0.20*transportLatency+0.80*oldLatency));
   GVWrite(SysKey("MODEL_LAST_LATENCY_MS"),transportLatency);
   int mqlError=(code==-1?GetLastError():0);
   if(code==-1)
   {
      APIStringToResult(StringFormat("MT5 WebRequest transport failure %d. Verify internet/TLS and the MT5 WebRequest allow-list for %s.",
                        mqlError,APITransportAllowListURL()),result);
      code=599; // internal synthetic HTTP-like status so downstream code gets deterministic failure text
   }

   if(code<200 || code>=300)
      GVWrite(SysKey("MODEL_FAIL"),GVRead(SysKey("MODEL_FAIL"),0)+1);
   else
      GVWrite(SysKey("MODEL_LAST_TRANSPORT_OK"),(double)TimeTradeServer());
   APITransportRecordOutcome(trace,code,mqlError,result_headers);
   return code;
}

bool APITransportReleaseEvidenceAllows(string &why)
{
   why="";
   if((bool)MQLInfoInteger(MQL_TESTER))
   {
      why="Strategy Tester: API transport evidence is informational only.";
      return true;
   }
   ENUM_ACCOUNT_TRADE_MODE mode=(ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE);
   if(mode!=ACCOUNT_TRADE_MODE_REAL)
   {
      why="Demo/contest account: API transport evidence is informational only.";
      return true;
   }
   if(!InpReleaseAPITransportPassed)
   {
      why="REAL account blocked: API transport/WebRequest test matrix has not been attested.";
      return false;
   }
   string config="";
   if(!APITransportConfigurationAllows(config))
   {
      why="REAL account blocked: "+config;
      return false;
   }
   why="API transport release evidence PASS | "+config;
   return true;
}

bool ReleaseSafetyAllowsR7API(const string sym,string &why)
{
   string base="";
   if(!ReleaseSafetyAllowsR6Evidence(sym,base))
   {
      why=base;
      return false;
   }
   string api="";
   if(!APITransportReleaseEvidenceAllows(api))
   {
      why=api;
      return false;
   }
   why=base+(base!=""?" | ":"")+api;
   return true;
}

void RefreshR7APIReleaseState()
{
   bool oldBlocked=g_releaseBlocked;
   string oldReason=g_releaseBlockReason;
   string why="";
   bool ok=ReleaseSafetyAllowsR7API("",why);
   g_releaseBlocked=!ok;
   g_releaseBlockReason=(ok?"All R7 API/release evidence gates pass.":why);
   if(g_releaseBlocked && (!oldBlocked || oldReason!=g_releaseBlockReason))
      Print("GPT_EA R7 API RELEASE BLOCK: ",g_releaseBlockReason);
   else if(!g_releaseBlocked && oldBlocked)
      Print("GPT_EA R7 API RELEASE GATE CLEARED.");
}

string ReleaseGateSummaryR7API()
{
   string why="";
   return ReleaseSafetyAllowsR7API("",why)?"PASS - "+why:"BLOCKED - "+why;
}

void AdvancedSafetyInitR7API()
{
   AdvancedSafetyInitR6Evidence();
   RefreshR7APIReleaseState();
}

void AdvancedSafetyTimerR7API()
{
   AdvancedSafetyTimerR6Evidence();
   RefreshR7APIReleaseState();
}

void StopFailureObservabilityInitR7API()
{
   StopFailureObservabilityInitR6Evidence();
   RefreshR7APIReleaseState();
}
// ===== END INLINED GPT_EA_Part37_APITransport.mqh =====
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
