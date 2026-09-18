// GPT_EA standalone MetaTrader 5 entry file
// Legacy modular wiring manifest (NON-EXECUTABLE).
// Retained only so repository release checks can verify historical module order/provenance.
// #include "GPT_EA_Part01.mqh"
// #include "GPT_EA_Part02.mqh"
// #include "GPT_EA_Part03.mqh"
// #include "GPT_EA_Part04.mqh"
// #include "GPT_EA_Part08_Advanced.mqh"
// #include "GPT_EA_Part09_RiskRecoveryAnalytics.mqh"
// #include "GPT_EA_Part44_ChaosFaultInjection.mqh"
// #include "GPT_EA_Part10_BrokerUniversalRecovery.mqh"
// #include "GPT_EA_Part11_PreflightRecoveryGuard.mqh"
// #include "GPT_EA_Part00_ForwardDeclarations.mqh"
// #include "GPT_EA_Part12_SafetyStopManagement.mqh"
// #include "GPT_EA_Part14_StopFailurePolicy.mqh"
// #include "GPT_EA_Part18_StopBrokerObservability.mqh"
// #include "GPT_EA_Part28_ReleaseCertification.mqh"
// #include "GPT_EA_Part29_DeploymentDriftGuard.mqh"
// #include "GPT_EA_Part28B_CIReleaseEvidence.mqh"
// #include "GPT_EA_Part37A_APICompat.mqh"
// #include "GPT_EA_Part37_APITransport.mqh"
// #include "GPT_EA_Part38_LegalLicenseGate.mqh"
// #include "GPT_EA_Part39_CustomerRiskAcknowledgement.mqh"
// #include "GPT_EA_Part40_PrivacyReleaseGate.mqh"
// #include "GPT_EA_Part15_StrategyIntelligence.mqh"
// #include "GPT_EA_Part15B_StrategyFrameworks.mqh"
// #include "GPT_EA_Part15C_StrategyContextAnalytics.mqh"
// #include "GPT_EA_Part20_RealisticCostModel.mqh"
// #include "GPT_EA_Part15D_StructureTargets.mqh"
// #include "GPT_EA_Part21_ResearchValidation.mqh"
// #include "GPT_EA_Part24_SessionStrategyHardening.mqh"
// #include "GPT_EA_Part27_StrategyCompletion.mqh"
// #include "GPT_EA_Part19_ContinuousIntelligence.mqh"
// #include "GPT_EA_Part16_NewsIntermarket.mqh"
// #include "GPT_EA_Part22A_IntermarketForward.mqh"
// #include "GPT_EA_Part22P_ResponseParser.mqh"
// #include "GPT_EA_Part22_IntelligenceFreshness.mqh"
// #include "GPT_EA_Part16A_StrictRevalidation.mqh"
// #include "GPT_EA_Part17_ThesisEngine.mqh"
// #include "GPT_EA_Part25_ThesisHardening.mqh"
// #include "GPT_EA_Part26_DeepGPTPolicy.mqh"
// #include "GPT_EA_Part40_ModelClockTrust.mqh"
// #include "GPT_EA_Part41_PortfolioStressLatency.mqh"
// #include "GPT_EA_Part30_AdaptiveRiskPortfolio.mqh"
// #include "GPT_EA_Part39_DataIntegrityQuarantine.mqh"
// #include "GPT_EA_Part31_ExecutionLearning.mqh"
// #include "GPT_EA_Part31A_RegimeSizing.mqh"
// #include "GPT_EA_Part31B_ExecutionFinalizer.mqh"
// #include "GPT_EA_Part32_ChampionChallenger.mqh"
// #include "GPT_EA_Part33_LifecycleIntegrityReplay.mqh"
// #include "GPT_EA_Part42_ExecutionReliability.mqh"
// #include "GPT_EA_Part43_CausalAttribution.mqh"
// #include "GPT_EA_Part34_StrategyHealthDashboard.mqh"
// #include "GPT_EA_Part36_DemoSoakEvidence.mqh"
// #include "GPT_EA_Part35_AdaptiveIntegration.mqh"
// #include "GPT_EA_Part05.mqh"
// #include "GPT_EA_Part23_IntelligenceObservability.mqh"
// #include "GPT_EA_Part06.mqh"
// #include "GPT_EA_Part13_AdvancedPositionManager.mqh"
// #include "GPT_EA_Part07.mqh"
#property strict
#property version   "1.20"
#property description "Standalone GPT EA: multi-symbol scanner, OpenAI review, timed approve/deny prompts and approval-only execution."

#include <Trade/Trade.mqh>
CTrade trade;

// ----------------------------- Inputs -----------------------------
input string InpSymbols                 = "ALL";        // ALL = every tradeable broker symbol; AUTO = curated major universe; or comma-separated manual list
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
input string InpOpenAIAPIKey            = "";         // Optional direct-mode fallback. Never commit a real key to GitHub.
input bool   InpOpenAIKeyPreferFile      = true;       // Prefer a local key file over the EA input field.
input bool   InpOpenAIKeyUseCommonFile   = true;       // true => Terminal\\Common\\Files, false => MQL5\\Files.
input string InpOpenAIKeyFile            = "GPT_EA_OpenAI.key"; // One-line local secret file; never add it to Git.
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

string g_openAIKeyCache="";
bool   g_openAIKeyCacheLoaded=false;
string g_openAIKeySource="MISSING";

string OpenAISecretTrim(string value)
{
   StringTrimLeft(value);
   StringTrimRight(value);
   return value;
}

string ReadOpenAIKeyFile()
{
   if(OpenAISecretTrim(InpOpenAIKeyFile)=="") return "";
   int flags=FILE_READ|FILE_TXT|FILE_ANSI;
   if(InpOpenAIKeyUseCommonFile) flags|=FILE_COMMON;
   ResetLastError();
   int h=FileOpen(InpOpenAIKeyFile,flags,0,CP_UTF8);
   if(h==INVALID_HANDLE) return "";
   string key=OpenAISecretTrim(FileReadString(h));
   FileClose(h);
   return key;
}

string OpenAILocalCredential()
{
   if(!g_openAIKeyCacheLoaded)
   {
      g_openAIKeyCacheLoaded=true;
      string fileKey=ReadOpenAIKeyFile();
      string inlineKey=OpenAISecretTrim(InpOpenAIAPIKey);
      if(InpOpenAIKeyPreferFile && StringLen(fileKey)>=20)
      {
         g_openAIKeyCache=fileKey;
         g_openAIKeySource=InpOpenAIKeyUseCommonFile?"COMMON FILE":"MQL5 FILE";
      }
      else if(StringLen(inlineKey)>=20)
      {
         g_openAIKeyCache=inlineKey;
         g_openAIKeySource="EA INPUT";
      }
      else if(StringLen(fileKey)>=20)
      {
         g_openAIKeyCache=fileKey;
         g_openAIKeySource=InpOpenAIKeyUseCommonFile?"COMMON FILE":"MQL5 FILE";
      }
      else
      {
         g_openAIKeyCache="";
         g_openAIKeySource="MISSING";
      }
   }
   return g_openAIKeyCache;
}

string OpenAIKeySourceText()
{
   OpenAILocalCredential();
   return g_openAIKeySource;
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
   string apiKey=OpenAILocalCredential();
   if(StringLen(apiKey)<20){ errorText="OpenAI API key not configured. Add it to the local key file or EA input."; return false; }

   string body="{\"model\":\""+JsonEscape(InpOpenAIModel)+"\",\"input\":\""+JsonEscape(prompt)+"\"}";
   string headers="Content-Type: application/json\r\nAuthorization: Bearer "+apiKey+"\r\n";
   char data[],result[];
   string resultHeaders="";
   int n=StringToCharArray(body,data,0,WHOLE_ARRAY,CP_UTF8);
   if(n>0) ArrayResize(data,n-1); // remove terminal NUL from HTTP body

   ResetLastError();
   int code=WebRequest("POST",InpOpenAIEndpoint,headers,InpOpenAITimeoutMs,data,result,resultHeaders);
   if(code==-1)
   {
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
   return (datetime)(serverTime-off);
}

bool ScheduledScanDue(string &why)
{
   datetime utc=TimeGMT();
   MqlDateTime l={}; TimeToStruct(LondonLocal(utc),l);
   MqlDateTime n={}; TimeToStruct(NewYorkLocal(utc),n);
   bool due=false; why="";

   if(l.hour==8 && l.min==InpPreLondonScanMinute){ due=true; why="Pre-London 08:"+IntegerToString(InpPreLondonScanMinute); }
   if(l.hour>=InpLondonHourlyStart && l.hour<=InpLondonHourlyEnd && l.min==0){ due=true; why="London hourly scan"; }
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

void AddCalendarCurrencyIfKnown(string &csv,const string raw)
{
   string c=Trim(raw); StringToUpper(c);
   if(c=="CNH") c="CNY"; // MT5 economic-calendar country data normally uses mainland CNY.
   string known[]={"USD","EUR","GBP","JPY","CHF","CAD","AUD","NZD","NOK","SEK","DKK","SGD","CNY","HKD","ZAR","TRY","MXN","PLN","HUF","CZK","THB","INR","BRL","ILS","AED","SAR","RUB","KRW"};
   for(int i=0;i<ArraySize(known);i++)
      if(c==known[i]) { AddCurrency(csv,c); return; }
}

string RelatedCurrencies(const string sym)
{
   string desc=SymbolInfoString(sym,SYMBOL_DESCRIPTION);
   string path=SymbolInfoString(sym,SYMBOL_PATH);
   string u=sym+" "+desc+" "+path; StringToUpper(u);
   string out="";

   // Prefer broker-provided contract currencies; they survive suffixes, prefixes and proprietary tickers.
   AddCalendarCurrencyIfKnown(out,SymbolInfoString(sym,SYMBOL_CURRENCY_BASE));
   AddCalendarCurrencyIfKnown(out,SymbolInfoString(sym,SYMBOL_CURRENCY_PROFIT));
   AddCalendarCurrencyIfKnown(out,SymbolInfoString(sym,SYMBOL_CURRENCY_MARGIN));

   // Explicit currency codes in the broker name/description/path.
   string known[]={"USD","EUR","GBP","JPY","CHF","CAD","AUD","NZD","NOK","SEK","DKK","SGD","CNH","CNY","HKD","ZAR","TRY","MXN","PLN","HUF","CZK","THB","INR","BRL","ILS","AED","SAR","RUB","KRW"};
   for(int i=0;i<ArraySize(known);i++)
      if(StringFind(u,known[i])>=0) AddCalendarCurrencyIfKnown(out,known[i]);

   // Regional index/rate aliases whose broker metadata can omit the macro currency.
   if(StringFind(u,"US100")>=0 || StringFind(u,"USTEC")>=0 || StringFind(u,"NAS100")>=0 ||
      StringFind(u,"NASDAQ")>=0 || StringFind(u,"US30")>=0 || StringFind(u,"DOW")>=0 ||
      StringFind(u,"US500")>=0 || StringFind(u,"SP500")>=0 || StringFind(u,"S&P 500")>=0 ||
      StringFind(u,"US2000")>=0 || StringFind(u,"RUSSELL")>=0 || StringFind(u,"VIX")>=0 ||
      StringFind(u,"TREASURY")>=0 || StringFind(u,"US10Y")>=0 || StringFind(u,"US02Y")>=0 ||
      StringFind(u,"US2Y")>=0 || StringFind(u,"US05Y")>=0 || StringFind(u,"US5Y")>=0 ||
      StringFind(u,"US30Y")>=0) AddCurrency(out,"USD");
   if(StringFind(u,"GER40")>=0 || StringFind(u,"DE40")>=0 || StringFind(u,"DAX")>=0 ||
      StringFind(u,"FRA40")>=0 || StringFind(u,"CAC40")>=0 || StringFind(u,"EU50")>=0 ||
      StringFind(u,"STOXX")>=0 || StringFind(u,"BUND")>=0 || StringFind(u,"BOBL")>=0 ||
      StringFind(u,"SCHATZ")>=0) AddCurrency(out,"EUR");
   if(StringFind(u,"UK100")>=0 || StringFind(u,"FTSE")>=0 || StringFind(u,"GILT")>=0) AddCurrency(out,"GBP");
   if(StringFind(u,"JP225")>=0 || StringFind(u,"NIKKEI")>=0 || StringFind(u,"JGB")>=0) AddCurrency(out,"JPY");
   if(StringFind(u,"HK50")>=0 || StringFind(u,"HANG SENG")>=0) AddCurrency(out,"HKD");
   if(StringFind(u,"AUS200")>=0 || StringFind(u,"ASX200")>=0) AddCurrency(out,"AUD");
   if(StringFind(u,"CH20")>=0 || StringFind(u,"SMI")>=0) AddCurrency(out,"CHF");
   if(StringFind(u,"CA60")>=0 || StringFind(u,"TSX")>=0) AddCurrency(out,"CAD");

   // Global USD-sensitive asset classes remain exposed to U.S. macro even when quoted in another currency.
   if(StringFind(u,"XAU")>=0 || StringFind(u,"GOLD")>=0 || StringFind(u,"XAG")>=0 || StringFind(u,"SILVER")>=0 ||
      StringFind(u,"XPT")>=0 || StringFind(u,"PLATINUM")>=0 || StringFind(u,"XPD")>=0 || StringFind(u,"PALLADIUM")>=0 ||
      StringFind(u,"WTI")>=0 || StringFind(u,"BRENT")>=0 || StringFind(u,"OIL")>=0 || StringFind(u,"NATGAS")>=0 ||
      StringFind(u,"NATURAL GAS")>=0 || StringFind(u,"CRYPTO")>=0 || StringFind(u,"BTC")>=0 || StringFind(u,"ETH")>=0 ||
      StringFind(u,"SOL")>=0 || StringFind(u,"XRP")>=0 || StringFind(u,"COPPER")>=0 || StringFind(u,"COCOA")>=0 ||
      StringFind(u,"COFFEE")>=0 || StringFind(u,"SUGAR")>=0 || StringFind(u,"COTTON")>=0 || StringFind(u,"WHEAT")>=0 ||
      StringFind(u,"CORN")>=0 || StringFind(u,"SOY")>=0) AddCurrency(out,"USD");

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
// GPT_EA Part 08 - Advanced confluence, event horizon, dashboard and chart map

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
input bool   InpElegantChartDashboard       = true;
input bool   InpDrawLiveManagementLevels    = true;
input bool   InpDrawTrailingMovement        = true;
input int    InpTrailMovementSegments       = 12;
input int    InpDashboardWidth              = 620;
input int    InpDashboardHeight             = 520;
input int    InpDashboardRefreshMs           = 750;
input string InpDashboardTitleFont          = "Segoe Script";
input string InpDashboardBodyFont           = "Segoe UI";
input bool   InpPremiumDashboard             = true;
input bool   InpPremiumUIAnimations          = true;
input int    InpApprovalHeroX                = 20;
input int    InpApprovalHeroY                = 20;
input int    InpApprovalHeroWidth            = 510;
input int    InpApprovalHeroHeight           = 246;
input int    InpApprovalAnimationMs          = 250;
input int    InpApprovalDangerSeconds        = 15;
input int    InpApprovalFeedbackSeconds      = 5;
input bool   InpEnableApprovalHover          = true;


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
string DASH_SUBTITLE="GPT_EA_DASH_SUBTITLE";
string DASH_TEXT="GPT_EA_DASH_TEXT";
string DASH_STATUS="GPT_EA_DASH_STATUS";
string BTN_SCAN_NOW="GPT_EA_SCAN_NOW";
string LEVEL_ENTRY="GPT_EA_LEVEL_ENTRY";
string LEVEL_SL="GPT_EA_LEVEL_SL";
string LEVEL_BE="GPT_EA_LEVEL_BE";
string LEVEL_LIVE_SL="GPT_EA_LEVEL_LIVE_SL";
string LEVEL_TP1="GPT_EA_LEVEL_TP1";
string LEVEL_TP2="GPT_EA_LEVEL_TP2";
string LEVEL_TP3="GPT_EA_LEVEL_TP3";
string ZONE_BOX="GPT_EA_ENTRY_ZONE";
string TAG_ENTRY="GPT_EA_TAG_ENTRY";
string TAG_SL="GPT_EA_TAG_SL";
string TAG_BE="GPT_EA_TAG_BE";
string TAG_TP1="GPT_EA_TAG_TP1";
string TAG_TP2="GPT_EA_TAG_TP2";
string TAG_TP3="GPT_EA_TAG_TP3";
string TAG_TRAIL="GPT_EA_TAG_TRAIL";
string LEVEL_TRAIL_START="GPT_EA_LEVEL_TRAIL_START";
string DASH_MARKET_CARD="GPT_EA_DASH_MARKET_CARD";
string DASH_MARKET_LABEL="GPT_EA_DASH_MARKET_LABEL";
string DASH_TRADE_CARD="GPT_EA_DASH_TRADE_CARD";
string DASH_TRADE_LABEL="GPT_EA_DASH_TRADE_LABEL";
string DASH_RISK_CARD="GPT_EA_DASH_RISK_CARD";
string DASH_RISK_LABEL="GPT_EA_DASH_RISK_LABEL";
string DASH_RULES_CARD="GPT_EA_DASH_RULES_CARD";
string DASH_RULES_LABEL="GPT_EA_DASH_RULES_LABEL";
string DASH_TIMELINE_CARD="GPT_EA_DASH_TIMELINE_CARD";
string DASH_TIMELINE_LABEL="GPT_EA_DASH_TIMELINE_LABEL";
string DASH_ACTION_CARD="GPT_EA_DASH_ACTION_CARD";
string DASH_ACTION_LABEL="GPT_EA_DASH_ACTION_LABEL";

string APP_PANEL="GPT_EA_APPROVAL_PANEL";
string APP_ACCENT="GPT_EA_APPROVAL_ACCENT";
string APP_TITLE="GPT_EA_APPROVAL_TITLE";
string APP_STATUS="GPT_EA_APPROVAL_STATUS";
string APP_META="GPT_EA_APPROVAL_META";
string APP_LADDER="GPT_EA_APPROVAL_LADDER";
string APP_TIMER="GPT_EA_APPROVAL_TIMER";
string APP_PROGRESS_BG="GPT_EA_APPROVAL_PROGRESS_BG";
string APP_PROGRESS_FG="GPT_EA_APPROVAL_PROGRESS_FG";
string APP_HINT="GPT_EA_APPROVAL_HINT";

bool g_approvalHoverApprove=false;
bool g_approvalHoverDeny=false;
ulong g_lastApprovalVisualMS=0;
string g_approvalFeedbackText="";
datetime g_approvalFeedbackUntil=0;
int g_approvalFeedbackKind=0;


TradeSetup g_visualLastSetup;
ConfluenceReport g_visualLastReport;
string g_visualLastFilter="";
bool g_visualLastReady=false;
bool g_visualHasSetup=false;
double g_visualTrailLastSL=0.0;
datetime g_visualTrailLastTime=0;
ulong g_visualTrailPid=0;
int g_visualTrailSeq=0;
ulong g_visualLastRefreshMS=0;

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
   ObjectDelete(0,LEVEL_ENTRY); ObjectDelete(0,LEVEL_SL); ObjectDelete(0,LEVEL_BE);
   ObjectDelete(0,LEVEL_TRAIL_START);
   ObjectDelete(0,LEVEL_TP1); ObjectDelete(0,LEVEL_TP2); ObjectDelete(0,LEVEL_TP3);
   ObjectDelete(0,ZONE_BOX);
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
   if(!InpDrawTradeLevels || s.symbol!=_Symbol || s.preferred<=0)
   {
      if(s.symbol==_Symbol) DeleteTradeMap();
      return;
   }

   double R=MathAbs(s.preferred-s.sl);
   if(R<=0) return;
   double beBuffer=MathMax(InpBELockMinR*R,PointFor(s.symbol)*2.0);
   double be=NormalizePriceToTick(s.symbol,s.bullish?s.preferred+beBuffer:s.preferred-beBuffer);
   double trailStart=NormalizePriceToTick(s.symbol,s.bullish?s.preferred+InpTrailStartR*R:s.preferred-InpTrailStartR*R);
   int d=DigitsFor(s.symbol);

   SetHLine(LEVEL_ENTRY,s.preferred,C'75,165,255',STYLE_SOLID,2);
   SetHLine(LEVEL_SL,s.sl,C'235,84,94',STYLE_SOLID,2);
   SetHLine(LEVEL_BE,be,C'229,194,96',STYLE_DASHDOT,1);
   SetHLine(LEVEL_TRAIL_START,trailStart,C'189,119,255',STYLE_DOT,1);
   SetHLine(LEVEL_TP1,s.tp1,C'91,218,151',STYLE_DASH,1);
   SetHLine(LEVEL_TP2,s.tp2,C'67,197,132',STYLE_DASH,1);
   SetHLine(LEVEL_TP3,s.tp3,C'48,174,113',STYLE_DOT,2);

   ObjectSetString(0,LEVEL_ENTRY,OBJPROP_TEXT,StringFormat("ENTRY  %.*f  |  0.00R",d,s.preferred));
   ObjectSetString(0,LEVEL_SL,OBJPROP_TEXT,StringFormat("STOP LOSS  %.*f  |  -1.00R",d,s.sl));
   ObjectSetString(0,LEVEL_BE,OBJPROP_TEXT,StringFormat("B.E. PROJECTION  %.*f  |  activates after TP1/protection rules",d,be));
   ObjectSetString(0,LEVEL_TRAIL_START,OBJPROP_TEXT,StringFormat("TRAIL START  %.*f  |  %.2fR",d,trailStart,InpTrailStartR));
   ObjectSetString(0,LEVEL_TP1,OBJPROP_TEXT,StringFormat("TP1  %.*f  |  +1.00R",d,s.tp1));
   ObjectSetString(0,LEVEL_TP2,OBJPROP_TEXT,StringFormat("TP2  %.*f  |  +2.00R",d,s.tp2));
   ObjectSetString(0,LEVEL_TP3,OBJPROP_TEXT,StringFormat("TP3 / RUNNER  %.*f  |  +3.00R",d,s.tp3));

   datetime left=TimeCurrent()-6*3600;
   datetime right=TimeCurrent()+6*3600;
   if(ObjectFind(0,ZONE_BOX)<0) ObjectCreate(0,ZONE_BOX,OBJ_RECTANGLE,0,left,s.zoneHigh,right,s.zoneLow);
   ObjectMove(0,ZONE_BOX,0,left,s.zoneHigh);
   ObjectMove(0,ZONE_BOX,1,right,s.zoneLow);
   ObjectSetInteger(0,ZONE_BOX,OBJPROP_COLOR,s.bullish?C'18,70,52':C'78,31,41');
   ObjectSetInteger(0,ZONE_BOX,OBJPROP_FILL,true);
   ObjectSetInteger(0,ZONE_BOX,OBJPROP_BACK,true);
   ObjectSetInteger(0,ZONE_BOX,OBJPROP_SELECTABLE,false);
}

void ApplyChartPolish()
{
   if(!InpPolishChart) return;
   ChartSetInteger(0,CHART_MODE,CHART_CANDLES);
   ChartSetInteger(0,CHART_SHOW_GRID,false);
   ChartSetInteger(0,CHART_SHIFT,true);
   ChartSetDouble(0,CHART_SHIFT_SIZE,18.0);
   ChartSetInteger(0,CHART_SHOW_OBJECT_DESCR,true);
   ChartSetInteger(0,CHART_COLOR_BACKGROUND,C'11,15,22');
   ChartSetInteger(0,CHART_COLOR_FOREGROUND,clrSilver);
   ChartSetInteger(0,CHART_COLOR_CHART_UP,C'35,196,131');
   ChartSetInteger(0,CHART_COLOR_CHART_DOWN,C'244,82,82');
   ChartSetInteger(0,CHART_COLOR_CANDLE_BULL,C'35,196,131');
   ChartSetInteger(0,CHART_COLOR_CANDLE_BEAR,C'244,82,82');
   ChartSetInteger(0,CHART_COLOR_VOLUME,C'83,100,130');
   ChartRedraw();
}


color PremiumPulseColor(const color calm,const color bright)
{
   if(!InpPremiumUIAnimations) return calm;
   return (((GetTickCount64()/450)%2)==0 ? calm : bright);
}

void SetPremiumRect(const string name,const ENUM_BASE_CORNER corner,const int x,const int y,const int w,const int h,
                    const color bg,const color border,const long z=0)
{
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_CORNER,corner);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,bg);
   ObjectSetInteger(0,name,OBJPROP_BORDER_COLOR,border);
   ObjectSetInteger(0,name,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,name,OBJPROP_ZORDER,z);
}

void SetPremiumLabel(const string name,const ENUM_BASE_CORNER corner,const int x,const int y,const string text,
                     const color fg,const int fontSize,const string font,const long z=5)
{
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_CORNER,corner);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_COLOR,fg);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,fontSize);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,name,OBJPROP_ZORDER,z);
   ObjectSetString(0,name,OBJPROP_FONT,font);
   ObjectSetString(0,name,OBJPROP_TEXT,text);
}

void SetApprovalFeedback(const string text,const int kind)
{
   g_approvalFeedbackText=text;
   g_approvalFeedbackKind=kind;
   g_approvalFeedbackUntil=TimeTradeServer()+MathMax(1,InpApprovalFeedbackSeconds);
}

bool ApprovalFeedbackActive()
{
   return (g_approvalFeedbackText!="" && TimeTradeServer()<=g_approvalFeedbackUntil);
}

string VisualOpenAIState()
{
   if(!InpUseOpenAI) return "OFF";
   if((bool)MQLInfoInteger(MQL_TESTER)) return "TESTER OFFLINE";
   if(StringLen(OpenAILocalCredential())<20) return "KEY MISSING";
   return "CONFIGURED • "+OpenAIKeySourceText();
}

void SetDashboardSection(const string card,const string label,const int x,const int y,const int w,const int h,
                         const string title,const string body,const color accent)
{
   SetPremiumRect(card,CORNER_RIGHT_UPPER,x,y,w,h,C'13,21,33',accent,2);
   SetPremiumLabel(label,CORNER_RIGHT_UPPER,x+12,y+8,title+"\n"+body,clrWhiteSmoke,8,InpDashboardBodyFont,4);
}

void ClearDashboardSections()
{
   ObjectDelete(0,DASH_MARKET_CARD); ObjectDelete(0,DASH_MARKET_LABEL);
   ObjectDelete(0,DASH_TRADE_CARD); ObjectDelete(0,DASH_TRADE_LABEL);
   ObjectDelete(0,DASH_RISK_CARD); ObjectDelete(0,DASH_RISK_LABEL);
   ObjectDelete(0,DASH_RULES_CARD); ObjectDelete(0,DASH_RULES_LABEL);
   ObjectDelete(0,DASH_TIMELINE_CARD); ObjectDelete(0,DASH_TIMELINE_LABEL);
   ObjectDelete(0,DASH_ACTION_CARD); ObjectDelete(0,DASH_ACTION_LABEL);
}

bool ApprovalMouseInside(const long mx,const double my,const int x,const int y,const int w,const int h)
{
   return (mx>=x && mx<=x+w && my>=y && my<=y+h);
}

void UpdateApprovalHover(const long mx,const double my)
{
   if(!InpEnableApprovalHover)
   {
      g_approvalHoverApprove=false;
      g_approvalHoverDeny=false;
      return;
   }
   int x=InpApprovalHeroX;
   int y=InpApprovalHeroY;
   int w=(int)MathMax(420,InpApprovalHeroWidth);
   int btnY=y+174;
   int btnW=(w-58)/2;
   g_approvalHoverApprove=ApprovalMouseInside(mx,my,x+22,btnY,btnW,40);
   g_approvalHoverDeny=ApprovalMouseInside(mx,my,x+36+btnW,btnY,btnW,40);
}

void StyleApprovalUI()
{
   bool pulse=(((GetTickCount64()/450)%2)==0);
   int x=InpApprovalHeroX;
   int y=InpApprovalHeroY;
   int w=(int)MathMax(420,InpApprovalHeroWidth);
   int btnW=(w-58)/2;
   int baseY=y+174;

   if(ObjectFind(0,BTN_APPROVE)>=0)
   {
      ObjectSetInteger(0,BTN_APPROVE,OBJPROP_XDISTANCE,x+22);
      ObjectSetInteger(0,BTN_APPROVE,OBJPROP_YDISTANCE,baseY-(g_approvalHoverApprove?2:0));
      ObjectSetInteger(0,BTN_APPROVE,OBJPROP_XSIZE,btnW);
      ObjectSetInteger(0,BTN_APPROVE,OBJPROP_YSIZE,g_approvalHoverApprove?42:40);
      ObjectSetInteger(0,BTN_APPROVE,OBJPROP_BGCOLOR,g_approvalHoverApprove?C'24,181,126':C'17,143,98');
      ObjectSetInteger(0,BTN_APPROVE,OBJPROP_COLOR,clrWhite);
      ObjectSetInteger(0,BTN_APPROVE,OBJPROP_BORDER_COLOR,pulse?C'94,244,185':C'49,204,144');
      ObjectSetInteger(0,BTN_APPROVE,OBJPROP_FONTSIZE,10);
      ObjectSetInteger(0,BTN_APPROVE,OBJPROP_ZORDER,20);
      ObjectSetString(0,BTN_APPROVE,OBJPROP_FONT,"Segoe UI Semibold");
      ObjectSetString(0,BTN_APPROVE,OBJPROP_TEXT,"✓  APPROVE TRADE");
   }
   if(ObjectFind(0,BTN_DENY)>=0)
   {
      ObjectSetInteger(0,BTN_DENY,OBJPROP_XDISTANCE,x+36+btnW);
      ObjectSetInteger(0,BTN_DENY,OBJPROP_YDISTANCE,baseY-(g_approvalHoverDeny?2:0));
      ObjectSetInteger(0,BTN_DENY,OBJPROP_XSIZE,btnW);
      ObjectSetInteger(0,BTN_DENY,OBJPROP_YSIZE,g_approvalHoverDeny?42:40);
      ObjectSetInteger(0,BTN_DENY,OBJPROP_BGCOLOR,g_approvalHoverDeny?C'212,62,78':C'173,48,62');
      ObjectSetInteger(0,BTN_DENY,OBJPROP_COLOR,clrWhite);
      ObjectSetInteger(0,BTN_DENY,OBJPROP_BORDER_COLOR,pulse?C'255,128,139':C'232,84,96');
      ObjectSetInteger(0,BTN_DENY,OBJPROP_FONTSIZE,10);
      ObjectSetInteger(0,BTN_DENY,OBJPROP_ZORDER,20);
      ObjectSetString(0,BTN_DENY,OBJPROP_FONT,"Segoe UI Semibold");
      ObjectSetString(0,BTN_DENY,OBJPROP_TEXT,"×  DENY");
   }
   if(ObjectFind(0,LBL_PROMPT)>=0)
   {
      ObjectSetInteger(0,LBL_PROMPT,OBJPROP_COLOR,clrWhiteSmoke);
      ObjectSetString(0,LBL_PROMPT,OBJPROP_FONT,"Segoe UI");
   }
}

void DeleteAdvancedDashboard()
{
   ObjectDelete(0,DASH_PANEL); ObjectDelete(0,DASH_TITLE); ObjectDelete(0,DASH_SUBTITLE);
   ObjectDelete(0,DASH_TEXT); ObjectDelete(0,DASH_STATUS); ObjectDelete(0,BTN_SCAN_NOW);
   ClearDashboardSections();
   ObjectDelete(0,LEVEL_BE); ObjectDelete(0,LEVEL_LIVE_SL); ObjectDelete(0,LEVEL_TRAIL_START);
   ObjectDelete(0,TAG_ENTRY); ObjectDelete(0,TAG_SL); ObjectDelete(0,TAG_BE);
   ObjectDelete(0,TAG_TP1); ObjectDelete(0,TAG_TP2); ObjectDelete(0,TAG_TP3); ObjectDelete(0,TAG_TRAIL);
   ObjectDelete(0,"GPT_EA_RISK_ZONE"); ObjectDelete(0,"GPT_EA_REWARD_ZONE");
   int maxSeg=(int)MathMax(3,InpTrailMovementSegments);
   for(int i=0;i<maxSeg;i++) ObjectDelete(0,StringFormat("GPT_EA_TRAIL_SEG_%02d",i));
   DeleteTradeMap();
}

void RenderAdvancedDashboard(const TradeSetup &s,const ConfluenceReport &r,const string filterState,bool readyNow)
{
   if(!InpDrawDashboard || s.symbol!=_Symbol) return;
   g_visualLastSetup=s;
   g_visualLastReport=r;
   g_visualLastFilter=filterState;
   g_visualLastReady=readyNow;
   g_visualHasSetup=(s.symbol!="");

   int panelW=(int)MathMax(460,InpDashboardWidth);
   int panelH=(int)MathMax(330,InpDashboardHeight);
   if(ObjectFind(0,DASH_PANEL)<0) ObjectCreate(0,DASH_PANEL,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,DASH_PANEL,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger(0,DASH_PANEL,OBJPROP_XDISTANCE,InpDashboardX);
   ObjectSetInteger(0,DASH_PANEL,OBJPROP_YDISTANCE,InpDashboardY);
   ObjectSetInteger(0,DASH_PANEL,OBJPROP_XSIZE,panelW);
   ObjectSetInteger(0,DASH_PANEL,OBJPROP_YSIZE,panelH);
   ObjectSetInteger(0,DASH_PANEL,OBJPROP_BGCOLOR,C'10,16,25');
   ObjectSetInteger(0,DASH_PANEL,OBJPROP_BORDER_COLOR,C'82,126,168');
   ObjectSetInteger(0,DASH_PANEL,OBJPROP_BACK,false);
   ObjectSetInteger(0,DASH_PANEL,OBJPROP_SELECTABLE,false);

   if(ObjectFind(0,DASH_TITLE)<0) ObjectCreate(0,DASH_TITLE,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,DASH_TITLE,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger(0,DASH_TITLE,OBJPROP_XDISTANCE,InpDashboardX+20);
   ObjectSetInteger(0,DASH_TITLE,OBJPROP_YDISTANCE,InpDashboardY+14);
   ObjectSetInteger(0,DASH_TITLE,OBJPROP_COLOR,C'225,198,115');
   ObjectSetInteger(0,DASH_TITLE,OBJPROP_FONTSIZE,15);
   ObjectSetString(0,DASH_TITLE,OBJPROP_FONT,InpDashboardTitleFont);
   ObjectSetString(0,DASH_TITLE,OBJPROP_TEXT,"GPT EA  •  Intelligent Market Desk");

   if(ObjectFind(0,DASH_SUBTITLE)<0) ObjectCreate(0,DASH_SUBTITLE,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,DASH_SUBTITLE,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger(0,DASH_SUBTITLE,OBJPROP_XDISTANCE,InpDashboardX+22);
   ObjectSetInteger(0,DASH_SUBTITLE,OBJPROP_YDISTANCE,InpDashboardY+46);
   ObjectSetInteger(0,DASH_SUBTITLE,OBJPROP_COLOR,C'118,193,235');
   ObjectSetInteger(0,DASH_SUBTITLE,OBJPROP_FONTSIZE,9);
   ObjectSetString(0,DASH_SUBTITLE,OBJPROP_FONT,InpDashboardBodyFont);
   ObjectSetString(0,DASH_SUBTITLE,OBJPROP_TEXT,"SCAN / ANALYSIS MODE  •  D1 H4 H1 M30 M15 M5");

   if(ObjectFind(0,DASH_STATUS)<0) ObjectCreate(0,DASH_STATUS,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,DASH_STATUS,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger(0,DASH_STATUS,OBJPROP_XDISTANCE,InpDashboardX+22);
   ObjectSetInteger(0,DASH_STATUS,OBJPROP_YDISTANCE,InpDashboardY+70);
   ObjectSetInteger(0,DASH_STATUS,OBJPROP_COLOR,readyNow?C'91,220,156':C'245,184,86');
   ObjectSetInteger(0,DASH_STATUS,OBJPROP_FONTSIZE,10);
   ObjectSetString(0,DASH_STATUS,OBJPROP_FONT,"Segoe UI Semibold");
   ObjectSetString(0,DASH_STATUS,OBJPROP_TEXT,readyNow?"● EXECUTION CONDITIONS READY":"● EA IS ANALYZING / WAITING");

   if(ObjectFind(0,DASH_TEXT)<0) ObjectCreate(0,DASH_TEXT,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,DASH_TEXT,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger(0,DASH_TEXT,OBJPROP_XDISTANCE,InpDashboardX+22);
   ObjectSetInteger(0,DASH_TEXT,OBJPROP_YDISTANCE,InpDashboardY+96);
   ObjectSetInteger(0,DASH_TEXT,OBJPROP_COLOR,clrWhiteSmoke);
   ObjectSetInteger(0,DASH_TEXT,OBJPROP_FONTSIZE,9);
   ObjectSetString(0,DASH_TEXT,OBJPROP_FONT,InpDashboardBodyFont);

   string dir=s.bullish?"LONG":"SHORT";
   string status=(s.valid && r.valid?"HIGH CONFLUENCE":"WAIT / FILTERED");
   double rr=(s.effectiveRR1>0?s.effectiveRR1:0);
   string action=readyNow?"Price is inside the execution area; final approval/revalidation path is active.":
      "EA is preserving capital while waiting for price, trigger and all hard gates to align.";
   string text=StringFormat(
      "%s  •  %s  •  %s\n"
      "Setup: %s  |  Confidence %d%%  |  Confluence %d/100  |  Eff R:R %.2f\n"
      "Entry zone  %.*f – %.*f   •   Preferred %.*f\n"
      "Initial SL  %.*f   •   TP1 %.*f   •   TP2 %.*f   •   TP3 %.*f\n"
      "ADX %.1f   •   Volume %.2fx   •   Opening-range %.2fx\n"
      "Structure %s  |  Liquidity sweep %s  |  FVG %s  |  Rejection %s\n"
      "Filters: %s\n"
      "EA action: %s",
      s.symbol,dir,status,s.name,s.confidence,r.score,rr,
      DigitsFor(s.symbol),s.zoneLow,DigitsFor(s.symbol),s.zoneHigh,DigitsFor(s.symbol),s.preferred,
      DigitsFor(s.symbol),s.sl,DigitsFor(s.symbol),s.tp1,DigitsFor(s.symbol),s.tp2,DigitsFor(s.symbol),s.tp3,
      r.adx,r.volumeRatio,r.openingRangeRatio,
      r.structureAligned?"YES":"NO",r.liquiditySweep?"YES":"NO",r.fairValueGap?"YES":"NO",r.rejectionCandle?"YES":"NO",
      filterState,action);
   ObjectSetString(0,DASH_TEXT,OBJPROP_TEXT,text);

   if(ObjectFind(0,BTN_SCAN_NOW)<0) ObjectCreate(0,BTN_SCAN_NOW,OBJ_BUTTON,0,0,0);
   ObjectSetInteger(0,BTN_SCAN_NOW,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger(0,BTN_SCAN_NOW,OBJPROP_XDISTANCE,InpDashboardX+22);
   ObjectSetInteger(0,BTN_SCAN_NOW,OBJPROP_YDISTANCE,InpDashboardY+panelH-42);
   ObjectSetInteger(0,BTN_SCAN_NOW,OBJPROP_XSIZE,132);
   ObjectSetInteger(0,BTN_SCAN_NOW,OBJPROP_YSIZE,27);
   ObjectSetInteger(0,BTN_SCAN_NOW,OBJPROP_BGCOLOR,C'34,87,139');
   ObjectSetInteger(0,BTN_SCAN_NOW,OBJPROP_COLOR,clrWhite);
   ObjectSetInteger(0,BTN_SCAN_NOW,OBJPROP_BORDER_COLOR,C'107,173,221');
   ObjectSetInteger(0,BTN_SCAN_NOW,OBJPROP_FONTSIZE,9);
   ObjectSetString(0,BTN_SCAN_NOW,OBJPROP_FONT,"Segoe UI Semibold");
   ObjectSetString(0,BTN_SCAN_NOW,OBJPROP_TEXT,"↻  SCAN NOW");

   DrawTradeMap(s);
   StyleApprovalUI();
   ChartRedraw();
}
// GPT_EA Part 09 - Portfolio risk, recovery, analytics, DOM, regime and ONNX

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

void HandleRiskAnalyticsTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result)
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
// GPT_EA Part 44 - Non-production chaos / fault-injection hooks
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
// GPT_EA Part 10 - Universal broker/symbol compatibility and hardened recovery

// --------------------------- Compatibility ---------------------------
input bool   InpAutoResolveBrokerSymbols      = true;
input bool   InpUseMarketWatchUniverse        = false;   // optional supplement for AUTO/manual modes; ALL already covers the full broker catalog
input int    InpMaxMarketWatchSymbols         = 0;       // 0 = unlimited when Market Watch supplementation is enabled
input bool   InpIncludeCloseOnlySymbols       = false;   // normally exclude symbols that cannot accept new entries
input int    InpMaxBrokerUniverseSymbols      = 0;       // 0 = unlimited; applies to ALL/full-broker discovery
input int    InpUniversalScanBatchSize        = 40;      // <=0 = scan the whole resolved universe in one cycle
input int    InpUniverseClockProbeSymbols     = 12;      // bounded M5-bar probes for continuous-scan scheduling
input string InpAutoMajorUniverse             = "XAUUSD,XAGUSD,US100,US30,US500,GER40,UK100,JP225,HK50,AUS200,FRA40,EU50,EURUSD,GBPUSD,GBPCAD,USDJPY,AUDUSD,USDCAD,USDCHF,NZDUSD,USOIL,UKOIL,NATGAS,BTCUSD,ETHUSD,SOLUSD,XRPUSD,LTCUSD,UNIUSD,BNBUSD";
input bool   InpPrintBrokerSymbolProfiles     = false;
input int    InpMaxPrintedBrokerProfiles      = 50;      // <=0 = print every resolved profile
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
int      g_universalScanCursor=0;
int      g_universalUniverseTotal=0;
int      g_universalUniverseEligible=0;
bool     g_fullBrokerUniverseMode=false;

// ----------------------- Symbol normalization -------------------------
string UpperCopy(string s){ StringToUpper(s); return s; }

string CleanSymbolToken(string s)
{
   StringToUpper(s);
   string chars[16]={".","_","-","#","/","\\"," ",":",";","@","!","+","*","(",")",","};
   for(int i=0;i<16;i++) StringReplace(s,chars[i],"");
   return s;
}

bool IsKnownFiatCurrencyCode(const string raw)
{
   string c=raw; StringToUpper(c);
   if(c=="CNH") c="CNY";
   string known[]={"USD","EUR","GBP","JPY","CHF","CAD","AUD","NZD","NOK","SEK","DKK","SGD","CNY","HKD","ZAR","TRY","MXN","PLN","HUF","CZK","THB","INR","BRL","ILS","AED","SAR","RUB","KRW"};
   for(int i=0;i<ArraySize(known);i++) if(c==known[i]) return true;
   return false;
}

bool CleanCryptoPairContains(const string cleanSymbol,const string token)
{
   if(cleanSymbol==token) return true;
   string quotes[]={"USD","USDT","USDC","EUR","GBP","JPY","CHF","AUD","CAD","BTC","ETH"};
   for(int i=0;i<ArraySize(quotes);i++)
   {
      if(StringFind(cleanSymbol,token+quotes[i])>=0) return true;
      if(StringFind(cleanSymbol,quotes[i]+token)>=0) return true;
   }
   return false;
}

string CanonicalInstrumentKey(const string name,const string description="",const string path="",
                              const long calcMode=-1,const string baseCurrency="",
                              const string profitCurrency="",const string marginCurrency="")
{
   string u=UpperCopy(name+" "+description+" "+path);
   string meta=UpperCopy(description+" "+path);
   string c=CleanSymbolToken(name);
   string base=UpperCopy(baseCurrency),profit=UpperCopy(profitCurrency),margin=UpperCopy(marginCurrency);
   if(base=="CNH") base="CNY";
   if(profit=="CNH") profit="CNY";
   if(margin=="CNH") margin="CNY";

   // Strong broker-native product identity comes first so a stock named after gold,
   // an ETF tracking an index, or a futures contract is not misclassified by its description.
   if(StringFind(meta,"ETF")>=0 || StringFind(meta,"EXCHANGE TRADED FUND")>=0) return "ETF:"+c;
   if(calcMode==SYMBOL_CALC_MODE_EXCH_BONDS || calcMode==SYMBOL_CALC_MODE_EXCH_BONDS_MOEX ||
      StringFind(meta,"\\BONDS")>=0 || StringFind(meta,"/BONDS")>=0 ||
      StringFind(meta,"TREASURY")>=0 || StringFind(meta,"GILT")>=0 ||
      StringFind(meta,"BUND")>=0 || StringFind(meta,"JGB")>=0) return "BOND_RATE:"+c;
   if(calcMode==SYMBOL_CALC_MODE_EXCH_STOCKS || calcMode==SYMBOL_CALC_MODE_EXCH_STOCKS_MOEX ||
      StringFind(meta,"\\STOCKS")>=0 || StringFind(meta,"/STOCKS")>=0 ||
      StringFind(meta,"\\SHARES")>=0 || StringFind(meta,"/SHARES")>=0) return "STOCK:"+c;
   if(calcMode==SYMBOL_CALC_MODE_FUTURES || calcMode==SYMBOL_CALC_MODE_EXCH_FUTURES ||
      calcMode==SYMBOL_CALC_MODE_EXCH_FUTURES_FORTS ||
      StringFind(meta,"\\FUTURES")>=0 || StringFind(meta,"/FUTURES")>=0) return "FUTURE:"+c;
   if(calcMode==SYMBOL_CALC_MODE_FOREX || calcMode==SYMBOL_CALC_MODE_FOREX_NO_LEVERAGE)
   {
      if(IsKnownFiatCurrencyCode(base) && IsKnownFiatCurrencyCode(profit) && base!=profit) return "FX:"+base+profit;
      if(IsKnownFiatCurrencyCode(base) && IsKnownFiatCurrencyCode(margin) && base!=margin) return "FX:"+base+margin;
      return "FX:"+c;
   }

   // Precious metals
   if(StringFind(u,"XAU")>=0 || StringFind(u,"GOLD")>=0) return "METAL:XAU";
   if(StringFind(u,"XAG")>=0 || StringFind(u,"SILVER")>=0) return "METAL:XAG";
   if(StringFind(u,"XPT")>=0 || StringFind(u,"PLATINUM")>=0) return "METAL:XPT";
   if(StringFind(u,"XPD")>=0 || StringFind(u,"PALLADIUM")>=0) return "METAL:XPD";

   // Major global indices and common CFD aliases.
   if(StringFind(u,"US100")>=0 || StringFind(u,"NAS100")>=0 || StringFind(u,"NASDAQ100")>=0 || StringFind(u,"USTEC")>=0 || StringFind(u,"NQ100")>=0) return "INDEX:US100";
   if(StringFind(u,"US30")>=0 || StringFind(u,"DJ30")>=0 || StringFind(u,"DOW30")>=0 || StringFind(u,"DOW JONES")>=0) return "INDEX:US30";
   if(StringFind(u,"US500")>=0 || StringFind(u,"SPX500")>=0 || StringFind(u,"SP500")>=0 || StringFind(u,"S&P 500")>=0) return "INDEX:US500";
   if(StringFind(u,"US2000")>=0 || StringFind(u,"RUSSELL 2000")>=0 || StringFind(u,"RUSSELL2000")>=0) return "INDEX:US2000";
   if(StringFind(u,"GER40")>=0 || StringFind(u,"DE40")>=0 || StringFind(u,"DAX40")>=0 || StringFind(u,"GERMANY 40")>=0) return "INDEX:GER40";
   if(StringFind(u,"UK100")>=0 || StringFind(u,"FTSE100")>=0) return "INDEX:UK100";
   if(StringFind(u,"JP225")>=0 || StringFind(u,"JPN225")>=0 || StringFind(u,"NIKKEI")>=0) return "INDEX:JP225";
   if(StringFind(u,"HK50")>=0 || StringFind(u,"HKG50")>=0 || StringFind(u,"HANG SENG")>=0) return "INDEX:HK50";
   if(StringFind(u,"AUS200")>=0 || StringFind(u,"AU200")>=0 || StringFind(u,"ASX200")>=0) return "INDEX:AUS200";
   if(StringFind(u,"FRA40")>=0 || StringFind(u,"FR40")>=0 || StringFind(u,"CAC40")>=0) return "INDEX:FRA40";
   if(StringFind(u,"EU50")>=0 || StringFind(u,"STOXX50")>=0 || StringFind(u,"EURO STOXX")>=0) return "INDEX:EU50";
   if(StringFind(u,"ES35")>=0 || StringFind(u,"IBEX35")>=0) return "INDEX:ES35";
   if(StringFind(u,"CH20")>=0 || StringFind(u,"SWISS20")>=0 || StringFind(u,"SWISS MARKET INDEX")>=0 ||
      StringFind(c,"SMI20")==0 || c=="SMI") return "INDEX:CH20";
   if(StringFind(u,"SA40")>=0 || StringFind(u,"JSE40")>=0) return "INDEX:SA40";
   if(StringFind(u,"VIX")>=0 || StringFind(u,"VOLATILITY INDEX")>=0) return "INDEX:VIX";

   // Energy
   if(StringFind(u,"WTI")>=0 || StringFind(u,"USOIL")>=0 || StringFind(u,"WTICOIL")>=0 || StringFind(u,"WEST TEXAS")>=0 || StringFind(u,"XTI")>=0) return "ENERGY:WTI";
   if(StringFind(u,"BRENT")>=0 || StringFind(u,"UKOIL")>=0 || StringFind(u,"XBR")>=0) return "ENERGY:BRENT";
   if(StringFind(u,"NATGAS")>=0 || StringFind(u,"NATURAL GAS")>=0 || StringFind(u,"NGAS")>=0) return "ENERGY:NATGAS";

   // Non-energy commodities / softs / agriculture / industrial metals.
   if(StringFind(u,"COPPER")>=0 || StringFind(u,"XCU")>=0) return "COMMODITY:COPPER";
   if(StringFind(u,"ALUMINUM")>=0 || StringFind(u,"ALUMINIUM")>=0) return "COMMODITY:ALUMINUM";
   if(StringFind(u,"NICKEL")>=0) return "COMMODITY:NICKEL";
   if(StringFind(u,"ZINC")>=0) return "COMMODITY:ZINC";
   if(StringFind(u,"COCOA")>=0) return "COMMODITY:COCOA";
   if(StringFind(u,"COFFEE")>=0) return "COMMODITY:COFFEE";
   if(StringFind(u,"SUGAR")>=0) return "COMMODITY:SUGAR";
   if(StringFind(u,"COTTON")>=0) return "COMMODITY:COTTON";
   if(StringFind(u,"WHEAT")>=0) return "COMMODITY:WHEAT";
   if(StringFind(u,"CORN")>=0 || StringFind(u,"MAIZE")>=0) return "COMMODITY:CORN";
   if(StringFind(u,"SOYBEAN")>=0 || StringFind(u,"SOY")>=0) return "COMMODITY:SOY";
   if(StringFind(u,"LUMBER")>=0) return "COMMODITY:LUMBER";

   // Crypto - require a recognizable token/quote pair unless broker metadata explicitly says crypto.
   string crypto[]={"BTC","ETH","SOL","XRP","ADA","DOGE","LTC","BNB","DOT","AVAX","UNI","LINK","TRX","BCH","ETC","XLM","ATOM","NEAR","AAVE","MATIC","POL","TON","SHIB","SUI","APT","FIL","ICP","ARB","OP","PEPE"};
   for(int k=0;k<ArraySize(crypto);k++) if(CleanCryptoPairContains(c,crypto[k])) return "CRYPTO:"+crypto[k];

   // FX - broad developed/emerging-market recognition.
   string cc[]={"USD","EUR","GBP","JPY","CHF","CAD","AUD","NZD","NOK","SEK","DKK","SGD","CNH","CNY","HKD","ZAR","TRY","MXN","PLN","HUF","CZK","THB","INR","BRL","ILS","AED","SAR","RUB","KRW"};
   string compact=CleanSymbolToken(u);
   for(int i=0;i<ArraySize(cc);i++)
      for(int j=0;j<ArraySize(cc);j++)
         if(i!=j)
         {
            string pair=cc[i]+cc[j];
            if(StringFind(c,pair)>=0 || StringFind(compact,pair)>=0) return "FX:"+pair;
         }

   // Broker folder/description metadata for CFD/OTC products not identified by an exchange calculation mode.
   if(StringFind(u,"CRYPTO")>=0 || StringFind(u,"DIGITAL ASSET")>=0) return "CRYPTO:"+c;
   if(StringFind(u,"ENERG")>=0 || StringFind(u,"OIL")>=0 || StringFind(u,"NATURAL GAS")>=0) return "ENERGY:"+c;
   if(StringFind(u,"COMMODIT")>=0 || StringFind(u,"AGRICULT")>=0 || StringFind(u,"SOFTS")>=0) return "COMMODITY:"+c;
   if(StringFind(u,"INDICES")>=0 || StringFind(u,"EQUITY INDEX")>=0 || StringFind(u,"INDEX CFD")>=0 || StringFind(u,"IDX_")>=0) return "INDEX:"+c;
   if(StringFind(u,"TREASURY")>=0 || StringFind(u,"BOND")>=0 || StringFind(u,"YIELD")>=0 ||
      StringFind(u,"INTEREST RATE")>=0 || StringFind(u,"GILT")>=0 || StringFind(u,"BUND")>=0 ||
      StringFind(u,"BOBL")>=0 || StringFind(u,"SCHATZ")>=0 || StringFind(u,"JGB")>=0) return "BOND_RATE:"+c;
   if(StringFind(u,"FUTURE")>=0) return "FUTURE:"+c;
   if(StringFind(u,"STOCK")>=0 || StringFind(u,"SHARE")>=0 ||
      (StringFind(u,"EQUITY")>=0 && StringFind(u,"EQUITY INDEX")<0)) return "STOCK:"+c;
   if(StringFind(u,"FOREX")>=0 || StringFind(u,"CURRENCY")>=0) return "FX:"+c;

   // Remaining MT5 calculation-mode fallbacks for proprietary CFD names.
   if(calcMode==SYMBOL_CALC_MODE_CFDINDEX) return "INDEX:"+c;
   if(calcMode==SYMBOL_CALC_MODE_SERV_COLLATERAL) return "OTHER:COLLATERAL";

   // Currency metadata remains useful even when a broker reports a generic CFD calculation mode.
   if(IsKnownFiatCurrencyCode(base) && IsKnownFiatCurrencyCode(profit) && base!=profit) return "FX:"+base+profit;
   if(IsKnownFiatCurrencyCode(base) && IsKnownFiatCurrencyCode(margin) && base!=margin) return "FX:"+base+margin;

   // Unknown but tradeable broker instruments remain eligible and are analyzed generically.
   return "GEN:"+c;
}

string CanonicalBrokerInstrumentKey(const string sym)
{
   string description=SymbolInfoString(sym,SYMBOL_DESCRIPTION);
   string path=SymbolInfoString(sym,SYMBOL_PATH);
   string base=SymbolInfoString(sym,SYMBOL_CURRENCY_BASE);
   string profit=SymbolInfoString(sym,SYMBOL_CURRENCY_PROFIT);
   string margin=SymbolInfoString(sym,SYMBOL_CURRENCY_MARGIN);
   long calcMode=(long)SymbolInfoInteger(sym,SYMBOL_TRADE_CALC_MODE);
   return CanonicalInstrumentKey(sym,description,path,calcMode,base,profit,margin);
}

string AssetClassFromCanonical(const string key)
{
   if(StringFind(key,"FX:")==0) return "FX";
   if(StringFind(key,"METAL:")==0) return "METAL";
   if(StringFind(key,"INDEX:")==0) return "INDEX";
   if(StringFind(key,"ENERGY:")==0) return "ENERGY";
   if(StringFind(key,"COMMODITY:")==0) return "COMMODITY";
   if(StringFind(key,"CRYPTO:")==0) return "CRYPTO";
   if(StringFind(key,"STOCK:")==0) return "STOCK";
   if(StringFind(key,"ETF:")==0) return "ETF";
   if(StringFind(key,"FUTURE:")==0) return "FUTURE";
   if(StringFind(key,"BOND_RATE:")==0) return "BOND_RATE";
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

bool BrokerSymbolEligibleForUniverse(const string sym)
{
   if(sym=="") return false;

   // SymbolsTotal(false) includes instruments outside Market Watch. Discovery must not
   // interpret unavailable pre-selection metadata as "disabled"; exact eligibility is
   // rechecked after EnsureSymbol() selects the instrument for analysis.
   if(!(bool)SymbolInfoInteger(sym,SYMBOL_SELECT)) return true;

   ENUM_SYMBOL_TRADE_MODE tm=(ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(sym,SYMBOL_TRADE_MODE);
   if(tm==SYMBOL_TRADE_MODE_DISABLED) return false;
   if(tm==SYMBOL_TRADE_MODE_CLOSEONLY && !InpIncludeCloseOnlySymbols) return false;

   // Service-collateral symbols are account assets, not executable market instruments.
   ENUM_SYMBOL_CALC_MODE cm=(ENUM_SYMBOL_CALC_MODE)SymbolInfoInteger(sym,SYMBOL_TRADE_CALC_MODE);
   if(cm==SYMBOL_CALC_MODE_SERV_COLLATERAL) return false;
   return true;
}

bool UniverseCapacityAvailable(string &arr[])
{
   return (InpMaxBrokerUniverseSymbols<=0 || ArraySize(arr)<InpMaxBrokerUniverseSymbols);
}

void AddDiscoveredBrokerSymbol(string &arr[],const string sym)
{
   if(!UniverseCapacityAvailable(arr) || !BrokerSymbolEligibleForUniverse(sym) || ArrayContainsString(arr,sym)) return;
   int n=ArraySize(arr);
   ArrayResize(arr,n+1);
   arr[n]=sym;
}

void AddResolvedSymbol(string &arr[],const string requested)
{
   if(!UniverseCapacityAvailable(arr)) return;
   string s=ResolveBrokerSymbol(requested);
   if(s=="" || !BrokerSymbolEligibleForUniverse(s) || ArrayContainsString(arr,s)) return;
   int n=ArraySize(arr); ArrayResize(arr,n+1); arr[n]=s;
}

int DiscoverFullBrokerUniverse(string &arr[])
{
   int before=ArraySize(arr);
   int total=SymbolsTotal(false);
   g_universalUniverseTotal=total;
   for(int i=0;i<total && UniverseCapacityAvailable(arr);i++)
   {
      string s=SymbolName(i,false);
      AddDiscoveredBrokerSymbol(arr,s);
   }
   g_universalUniverseEligible=ArraySize(arr);
   return ArraySize(arr)-before;
}

bool ResolveConfiguredSymbolsUniversal()
{
   string resolved[];
   bool autoRequested=false;
   bool allRequested=false;
   g_universalUniverseTotal=SymbolsTotal(false);

   for(int i=0;i<ArraySize(g_symbols);i++)
   {
      string u=UpperCopy(Trim(g_symbols[i]));
      if(u=="ALL" || u=="BROKER" || u=="UNIVERSE" || u=="ALL_MARKETS")
      {
         allRequested=true;
         continue;
      }
      if(u=="AUTO")
      {
         autoRequested=true;
         continue;
      }
      AddResolvedSymbol(resolved,g_symbols[i]);
   }

   if(autoRequested)
   {
      string majors[]; int n=StringSplit(InpAutoMajorUniverse,',',majors);
      for(int i=0;i<n;i++) AddResolvedSymbol(resolved,Trim(majors[i]));
   }

   g_fullBrokerUniverseMode=allRequested;

   if(allRequested)
   {
      int added=DiscoverFullBrokerUniverse(resolved);
      PrintFormat("GPT_EA full broker universe: catalog=%d, eligible/resolved=%d, newly added=%d, cap=%d",
                  g_universalUniverseTotal,ArraySize(resolved),added,InpMaxBrokerUniverseSymbols);
   }

   if(InpUseMarketWatchUniverse)
   {
      int total=SymbolsTotal(true);
      int added=0;
      for(int i=0;i<total && UniverseCapacityAvailable(resolved);i++)
      {
         if(InpMaxMarketWatchSymbols>0 && added>=InpMaxMarketWatchSymbols) break;
         string s=SymbolName(i,true);
         int before=ArraySize(resolved);
         AddDiscoveredBrokerSymbol(resolved,s);
         if(ArraySize(resolved)>before) added++;
      }
      PrintFormat("GPT_EA Market Watch supplement: catalog=%d, newly added=%d, cap=%d",
                  total,added,InpMaxMarketWatchSymbols);
   }

   if(ArraySize(resolved)<=0) return false;
   ArrayResize(g_symbols,ArraySize(resolved));
   for(int i=0;i<ArraySize(resolved);i++) g_symbols[i]=resolved[i];

   g_universalUniverseEligible=ArraySize(g_symbols);
   g_universalScanCursor=0;
   PrintFormat("GPT_EA resolved symbol universe ready: %d tradeable symbols.",ArraySize(g_symbols));
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
   p.baseCurrency=SymbolInfoString(sym,SYMBOL_CURRENCY_BASE);
   p.profitCurrency=SymbolInfoString(sym,SYMBOL_CURRENCY_PROFIT);
   p.marginCurrency=SymbolInfoString(sym,SYMBOL_CURRENCY_MARGIN);
   p.tradeMode=SymbolInfoInteger(sym,SYMBOL_TRADE_MODE);
   p.calcMode=SymbolInfoInteger(sym,SYMBOL_TRADE_CALC_MODE);
   p.canonical=CanonicalInstrumentKey(sym,p.description,p.path,p.calcMode,p.baseCurrency,p.profitCurrency,p.marginCurrency);
   p.assetClass=AssetClassFromCanonical(p.canonical);
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
      if(!OrderCalcMargin(ORDER_TYPE_BUY,sym,1.0,t.ask,p.marginBuy1Lot))
         p.marginBuy1Lot=0.0;
      if(!OrderCalcMargin(ORDER_TYPE_SELL,sym,1.0,t.bid,p.marginSell1Lot))
         p.marginSell1Lot=0.0;
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
   PrintFormat("GPT_EA symbol universe: resolved=%d | broker catalog=%d | scan batch=%d",
               ArraySize(g_symbols),g_universalUniverseTotal,InpUniversalScanBatchSize);
   if(!InpPrintBrokerSymbolProfiles) return;
   int total=ArraySize(g_symbols);
   int cap=total;
   if(InpMaxPrintedBrokerProfiles>0 && InpMaxPrintedBrokerProfiles<cap) cap=InpMaxPrintedBrokerProfiles;
   for(int i=0;i<cap;i++) Print("GPT_EA profile: ",SymbolProfileSummary(g_symbols[i]));
   if(cap<total) PrintFormat("GPT_EA profile logging capped at %d/%d symbols.",cap,total);
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
// GPT_EA Part 11 - Server preflight and hardened recovery safety guard

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
// GPT_EA Part 00 - Forward declarations for cross-module hooks

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
// GPT_EA Part 12 - Release safety gates, recovery invariants and advanced stops

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
   // Global release state checks account/terminal/recovery configuration only.
   // Per-symbol series, quote freshness and broker order-mode checks are enforced
   // immediately before approval/execution, so a closed market cannot block every other market.
   bool ok=ReleaseSafetyAllows("",why);
   g_releaseBlocked=!ok;
   g_releaseBlockReason=(ok?"All global release-blocking safety gates pass.":why);
   if(g_releaseBlocked && (!oldBlocked || oldReason!=g_releaseBlockReason)) Print("GPT_EA RELEASE BLOCK: ",g_releaseBlockReason);
   else if(!g_releaseBlocked && oldBlocked) Print("GPT_EA RELEASE GATE CLEARED: all global release-blocking safety gates pass.");
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
   datetime stageTime=TimeTradeServer();
   GVWrite(PosKey(pid,"SL_STAGE"),stage);
   GVWrite(PosKey(pid,"LASTSL"),candidate);
   GVWrite(PosKey(pid,"SL_STAGE_TIME"),(double)stageTime);
   GVWrite(PosKey(pid,"SL_STAGE_R"),rNow);
   GVWrite(PosKey(pid,"SL_STAGE_PRICE"),candidate);
   if(stage==1 && GVRead(PosKey(pid,"BE_TIME"),0)<=0) GVWrite(PosKey(pid,"BE_TIME"),(double)stageTime);
   if(stage==2 && GVRead(PosKey(pid,"PROFIT_LOCK_TIME"),0)<=0) GVWrite(PosKey(pid,"PROFIT_LOCK_TIME"),(double)stageTime);
   if(stage==3 && GVRead(PosKey(pid,"STRONG_LOCK_TIME"),0)<=0) GVWrite(PosKey(pid,"STRONG_LOCK_TIME"),(double)stageTime);
   if(stage>=4)
   {
      if(GVRead(PosKey(pid,"TRAIL_TIME"),0)<=0) GVWrite(PosKey(pid,"TRAIL_TIME"),(double)stageTime);
      GVWrite(PosKey(pid,"TRAIL_LAST_TIME"),(double)stageTime);
   }
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
// GPT_EA Part 14 - Stop update failure policy and escalation

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
// GPT_EA Part 18 - Broker-specific stop failure handling and observability

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
   string canonical=CanonicalBrokerInstrumentKey(sym);

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
// GPT_EA Part 28 - Live release certification / evidence gate
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

string ReleaseCsvEscape(string value)
{
   bool quote=(StringFind(value,";")>=0 || StringFind(value,"\"")>=0 ||
               StringFind(value,"\\r")>=0 || StringFind(value,"\\n")>=0);
   if(StringFind(value,"\"")>=0)
      StringReplace(value,"\"","\"\"");
   return quote ? "\""+value+"\"" : value;
}

void ReleaseCsvAppend(string &row,const string value)
{
   if(StringLen(row)>0) row+=";";
   row+=ReleaseCsvEscape(value);
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
   {
      string header=
         "time;required_release_id;entered_release_id;account_mode;broker;server;"
         "source_commit;ex5_sha256;set_sha256;compile_evidence_id;metaeditor_build;mt5_build;"
         "compile;artifact_identity;strategy_tester;intelligence_matrix;adaptive_portfolio;execution_learning;champion_challenger;lifecycle_integrity;"
         "broker_matrix;deployment_profile;recovery;stop_matrix;broker_stop_policy;partial_protection;stop_observability;live_news_intermarket;"
         "web_failure_injection;demo_soak;soak_schema;soak_evidence_id;soak_digest;soak_trading_days;soak_london_sessions;soak_ny_sessions;"
         "soak_overlap;soak_news_day;soak_rollover;soak_restart;soak_reconnect;soak_scheduled_scans;soak_continuous_scans;"
         "soak_checkpoint_updates;soak_backup_updates;soak_zero_tolerance_failures;soak_unresolved_critical;soak_duplicate_orders;soak_duplicate_partials;"
         "soak_sl_regressions;soak_unprotected_authorizations;soak_gate_bypasses;soak_analytics_duplicate_final;soak_stop_join_failures;"
         "soak_dashboard_mismatches;soak_runtime_critical_errors;soak_secrets_exposed;soak_execution_log;soak_stop_log;soak_release_log;"
         "operator_review;final_review_id;final_review_digest;final_decision;final_reviewer;final_review_timestamp;gate_result;reason";
      FileWriteString(h,header+"\r\n");
   }

   FileSeek(h,0,SEEK_END);
   string why="";
   bool ok=ReleaseSafetyAllowsCertified("",why);
   string row="";

   ReleaseCsvAppend(row,TimeToString(TimeTradeServer(),TIME_DATE|TIME_SECONDS));
   ReleaseCsvAppend(row,GPT_EA_REQUIRED_RELEASE_VALIDATION_ID);
   ReleaseCsvAppend(row,InpReleaseValidationId);
   ReleaseCsvAppend(row,(string)AccountInfoInteger(ACCOUNT_TRADE_MODE));
   ReleaseCsvAppend(row,AccountInfoString(ACCOUNT_COMPANY));
   ReleaseCsvAppend(row,AccountInfoString(ACCOUNT_SERVER));
   ReleaseCsvAppend(row,InpReleaseSourceCommitSha);
   ReleaseCsvAppend(row,InpReleaseEx5Sha256);
   ReleaseCsvAppend(row,InpReleaseSetSha256);
   ReleaseCsvAppend(row,InpReleaseCompileEvidenceId);
   ReleaseCsvAppend(row,InpReleaseMetaEditorBuild);
   ReleaseCsvAppend(row,InpReleaseMT5Build);
   ReleaseCsvAppend(row,InpReleaseMetaEditorCompilePassed?"1":"0");
   ReleaseCsvAppend(row,InpReleaseArtifactIdentityArchived?"1":"0");
   ReleaseCsvAppend(row,InpReleaseStrategyTesterPassed?"1":"0");
   ReleaseCsvAppend(row,InpReleaseIntelligenceMatrixPassed?"1":"0");
   ReleaseCsvAppend(row,InpReleaseAdaptivePortfolioPassed?"1":"0");
   ReleaseCsvAppend(row,InpReleaseExecutionLearningPassed?"1":"0");
   ReleaseCsvAppend(row,InpReleaseChampionChallengerPassed?"1":"0");
   ReleaseCsvAppend(row,InpReleaseLifecycleIntegrityPassed?"1":"0");
   ReleaseCsvAppend(row,InpReleaseBrokerMatrixPassed?"1":"0");
   ReleaseCsvAppend(row,InpReleaseDeploymentProfilePassed?"1":"0");
   ReleaseCsvAppend(row,InpReleaseRecoveryTestsPassed?"1":"0");
   ReleaseCsvAppend(row,InpReleaseStopMatrixPassed?"1":"0");
   ReleaseCsvAppend(row,InpReleaseBrokerStopPolicyPassed?"1":"0");
   ReleaseCsvAppend(row,InpReleasePartialProtectionPassed?"1":"0");
   ReleaseCsvAppend(row,InpReleaseStopObservabilityPassed?"1":"0");
   ReleaseCsvAppend(row,InpReleaseLiveNewsIntermarketPassed?"1":"0");
   ReleaseCsvAppend(row,InpReleaseWebFailureInjectionPassed?"1":"0");
   ReleaseCsvAppend(row,InpReleaseDemoSoakPassed?"1":"0");
   ReleaseCsvAppend(row,InpReleaseSoakSchemaVersion);
   ReleaseCsvAppend(row,InpReleaseSoakEvidenceId);
   ReleaseCsvAppend(row,InpReleaseSoakEvidenceDigest);
   ReleaseCsvAppend(row,(string)InpReleaseSoakTradingDays);
   ReleaseCsvAppend(row,(string)InpReleaseSoakLondonSessions);
   ReleaseCsvAppend(row,(string)InpReleaseSoakNYSessions);
   ReleaseCsvAppend(row,InpReleaseSoakOverlapObserved?"1":"0");
   ReleaseCsvAppend(row,InpReleaseSoakNewsDayObserved?"1":"0");
   ReleaseCsvAppend(row,InpReleaseSoakRolloverObserved?"1":"0");
   ReleaseCsvAppend(row,InpReleaseSoakRestartObserved?"1":"0");
   ReleaseCsvAppend(row,InpReleaseSoakReconnectObserved?"1":"0");
   ReleaseCsvAppend(row,(string)InpReleaseSoakScheduledScans);
   ReleaseCsvAppend(row,(string)InpReleaseSoakContinuousScans);
   ReleaseCsvAppend(row,(string)InpReleaseSoakCheckpointUpdates);
   ReleaseCsvAppend(row,(string)InpReleaseSoakBackupCheckpointUpdates);
   ReleaseCsvAppend(row,(string)InpReleaseSoakZeroToleranceFailures);
   ReleaseCsvAppend(row,(string)InpReleaseSoakUnresolvedCriticalStates);
   ReleaseCsvAppend(row,(string)InpReleaseSoakDuplicateOrders);
   ReleaseCsvAppend(row,(string)InpReleaseSoakDuplicatePartials);
   ReleaseCsvAppend(row,(string)InpReleaseSoakSLRegressions);
   ReleaseCsvAppend(row,(string)InpReleaseSoakUnprotectedAuthorizations);
   ReleaseCsvAppend(row,(string)InpReleaseSoakReleaseGateBypasses);
   ReleaseCsvAppend(row,(string)InpReleaseSoakAnalyticsDuplicateFinal);
   ReleaseCsvAppend(row,(string)InpReleaseSoakStopJoinFailures);
   ReleaseCsvAppend(row,(string)InpReleaseSoakDashboardMismatches);
   ReleaseCsvAppend(row,(string)InpReleaseSoakRuntimeCriticalErrors);
   ReleaseCsvAppend(row,(string)InpReleaseSoakSecretsExposed);
   ReleaseCsvAppend(row,InpReleaseSoakExecutionLogPresent?"1":"0");
   ReleaseCsvAppend(row,InpReleaseSoakStopLogPresent?"1":"0");
   ReleaseCsvAppend(row,InpReleaseSoakReleaseLogPresent?"1":"0");
   ReleaseCsvAppend(row,InpReleaseOperatorReviewPassed?"1":"0");
   ReleaseCsvAppend(row,InpReleaseFinalReviewEvidenceId);
   ReleaseCsvAppend(row,InpReleaseFinalReviewDigest);
   ReleaseCsvAppend(row,InpReleaseFinalDecision);
   ReleaseCsvAppend(row,InpReleaseFinalReviewer);
   ReleaseCsvAppend(row,InpReleaseFinalReviewTimestamp);
   ReleaseCsvAppend(row,ok?"PASS":"BLOCK");
   ReleaseCsvAppend(row,why);

   FileWriteString(h,row+"\r\n");
   FileFlush(h);
   FileClose(h);
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
// GPT_EA Part 29 - Deployment identity and broker contract drift guard

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
      if(sym=="") continue;
      // In ALL/full-broker mode do not force-load the complete catalog merely to capture metadata.
      // Symbols become selected naturally as the round-robin scanner reaches them.
      if(g_fullBrokerUniverseMode)
      {
         if(!(bool)SymbolInfoInteger(sym,SYMBOL_SELECT)) continue;
      }
      else if(!EnsureSymbol(sym)) continue;
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
   if(g_fullBrokerUniverseMode)
   {
      // Broker catalogs are dynamic. Live per-symbol broker gates still validate tick size,
      // volume, stops, margin and order modes before any new entry.
      why="Full broker universe uses live per-symbol execution validation.";
      return true;
   }
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
// GPT_EA Part 28B - R6 supplemental CI / runner / MT5 / soak evidence binding
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
// GPT_EA Part 37A - API transport compatibility helpers

string APITrim(const string source)
{
   string value=source;
   StringTrimLeft(value);
   StringTrimRight(value);
   return value;
}
#define Trim APITrim
// GPT_EA Part 37 - OpenAI/WebRequest transport abstraction and release guard
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
   return OpenAILocalCredential();
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
      if(StringLen(OpenAILocalCredential())<20)
      {
         why="Direct mode requires an OpenAI API key in the local key file or EA input.";
         return false;
      }
      why="DIRECT_OPENAI configured using "+OpenAIKeySourceText()+". MT5 allow-list must contain https://api.openai.com.";
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
   string localOpenAIKey=OpenAILocalCredential();
   if(localOpenAIKey!="" && Trim(InpAPIProxyToken)==localOpenAIKey)
   {
      why="Proxy token must not reuse the OpenAI API key.";
      return false;
   }
   why="SECURE_PROXY configured. Add the proxy HTTPS origin/endpoint to the MT5 WebRequest allow-list.";
   return true;
}

string APITransportVisualState()
{
   if(!InpUseOpenAI) return "OFF";
   if((bool)MQLInfoInteger(MQL_TESTER)) return "TESTER OFFLINE";

   string mode=APITransportModeText();
   string why="";
   if(!APITransportConfigurationAllows(why)) return mode+" • BLOCKED";

   datetime now=TimeLocal();
   if(g_apiTransportNextRetry>now)
      return mode+" • BACKOFF";
   if(g_apiTransportFailures>0)
      return mode+" • DEGRADED";

   datetime lastOK=(datetime)GVRead(SysKey("MODEL_LAST_TRANSPORT_OK"),0);
   string source=(InpAPITransportMode==GPT_API_SECURE_PROXY?"SCOPED PROXY TOKEN":OpenAIKeySourceText());
   if(lastOK>0)
      return mode+" • ONLINE • "+source;
   return mode+" • READY • "+source;
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
#undef Trim
// GPT_EA Part 38 - Commercial license / legal acknowledgement release gate
// This is an operational acknowledgement gate, not a substitute for a signed
// commercial agreement and not an unbreakable license server.
//
// REAL accounts require explicit acceptance of the current commercial terms,
// trading-risk disclosure and acknowledgement phrase before new entries can be
// authorized. Existing positions continue to be managed by the normal safety
// stack even when this gate blocks new entries.

const string GPT_EA_LEGAL_TERMS_VERSION = "GPT_EA_TERMS_20260917_V1";
const string GPT_EA_REQUIRED_ACCEPTANCE_PHRASE = "I ACCEPT GPT_EA TERMS AND TRADING RISK";

input bool   InpAcceptGPTCommercialTerms = false;
input bool   InpAcceptGPTTradingRisk     = false;
input string InpGPTTermsAcceptancePhrase = "";
input string InpCustomerLicenseReference = "";
input bool   InpRequireLicenseReferenceOnReal = true;

string LegalTrim(string value)
{
   StringTrimLeft(value);
   StringTrimRight(value);
   return value;
}

bool GPTLegalAcknowledgementAllows(string &why)
{
   why="";

   if((bool)MQLInfoInteger(MQL_TESTER))
   {
      why="Strategy Tester: legal acknowledgement is informational only.";
      return true;
   }

   ENUM_ACCOUNT_TRADE_MODE mode=(ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE);
   if(mode!=ACCOUNT_TRADE_MODE_REAL)
   {
      why="Demo/contest: legal acknowledgement is informational until REAL arming.";
      return true;
   }

   if(!InpAcceptGPTCommercialTerms)
   {
      why="REAL account blocked: commercial license/terms not accepted.";
      return false;
   }

   if(!InpAcceptGPTTradingRisk)
   {
      why="REAL account blocked: trading-risk disclosure not accepted.";
      return false;
   }

   if(LegalTrim(InpGPTTermsAcceptancePhrase)!=GPT_EA_REQUIRED_ACCEPTANCE_PHRASE)
   {
      why="REAL account blocked: legal acceptance phrase does not match the required phrase.";
      return false;
   }

   string licenseRef=LegalTrim(InpCustomerLicenseReference);
   if(InpRequireLicenseReferenceOnReal && StringLen(licenseRef)<6)
   {
      why="REAL account blocked: valid customer license reference is required.";
      return false;
   }

   why="Legal/risk acknowledgement PASS | terms="+GPT_EA_LEGAL_TERMS_VERSION;
   return true;
}

bool ReleaseSafetyAllowsR8Legal(const string sym,string &why)
{
   string base="";
   if(!ReleaseSafetyAllowsR7API(sym,base))
   {
      why=base;
      return false;
   }

   string legal="";
   if(!GPTLegalAcknowledgementAllows(legal))
   {
      why=legal;
      return false;
   }

   why=base+(base!=""?" | ":"")+legal;
   return true;
}

void RefreshR8LegalReleaseState()
{
   bool oldBlocked=g_releaseBlocked;
   string oldReason=g_releaseBlockReason;
   string why="";
   bool ok=ReleaseSafetyAllowsR8Legal("",why);

   g_releaseBlocked=!ok;
   g_releaseBlockReason=(ok?"All R8 legal/API/release evidence gates pass.":why);

   if(g_releaseBlocked && (!oldBlocked || oldReason!=g_releaseBlockReason))
      Print("GPT_EA R8 LEGAL RELEASE BLOCK: ",g_releaseBlockReason);
   else if(!g_releaseBlocked && oldBlocked)
      Print("GPT_EA R8 LEGAL RELEASE GATE CLEARED.");
}

string ReleaseGateSummaryR8Legal()
{
   string why="";
   return ReleaseSafetyAllowsR8Legal("",why)?"PASS - "+why:"BLOCKED - "+why;
}

void AdvancedSafetyInitR8Legal()
{
   AdvancedSafetyInitR7API();
   RefreshR8LegalReleaseState();
}

void AdvancedSafetyTimerR8Legal()
{
   AdvancedSafetyTimerR7API();
   RefreshR8LegalReleaseState();
}

void StopFailureObservabilityInitR8Legal()
{
   StopFailureObservabilityInitR7API();
   RefreshR8LegalReleaseState();
}
// GPT_EA Part 39 - Customer-facing risk acknowledgement gate
// Adds explicit, versioned risk acknowledgements on top of R8 legal acceptance.
// REAL accounts must affirm each material risk statement before new entries.
// Existing positions remain managed even when acknowledgement is incomplete.

const string GPT_EA_RISK_ACK_SCHEMA_VERSION = "GPT_EA_RISK_ACK_V1";

input bool   InpAcknowledgeNoProfitGuarantee        = false;
input bool   InpAcknowledgePossibleTotalLoss        = false;
input bool   InpAcknowledgeAILimitations            = false;
input bool   InpAcknowledgeBrokerThirdPartyRisk     = false;
input bool   InpAcknowledgePersonalResponsibility   = false;
input bool   InpAcknowledgeDemoFirst                = false;
input string InpCustomerJurisdiction                = "";
input string InpAcceptedGPTTermsVersion              = "";
input string InpAcceptedGPTRiskAckVersion            = "";
input bool   InpWriteRiskAcknowledgementLog         = true;
input string InpRiskAcknowledgementLogFile          = "GPT_EA_RiskAcknowledgements.csv";

bool g_riskAckPassLogged=false;

string RiskAckTrim(string value)
{
   StringTrimLeft(value);
   StringTrimRight(value);
   return value;
}

string RiskAckMaskLicense(const string value)
{
   string v=RiskAckTrim(value);
   int n=StringLen(v);
   if(n<=4) return "****";
   return "****"+StringSubstr(v,n-4,4);
}

bool GPTCustomerRiskAcknowledgementAllows(string &why)
{
   why="";

   if((bool)MQLInfoInteger(MQL_TESTER))
   {
      why="Strategy Tester: customer risk acknowledgement is informational only.";
      return true;
   }

   ENUM_ACCOUNT_TRADE_MODE mode=(ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE);
   if(mode!=ACCOUNT_TRADE_MODE_REAL)
   {
      why="Demo/contest: customer risk acknowledgement is informational until REAL arming.";
      return true;
   }

   if(!InpAcknowledgeNoProfitGuarantee)
   {
      why="REAL account blocked: no-profit/no-wealth guarantee acknowledgement is missing.";
      return false;
   }
   if(!InpAcknowledgePossibleTotalLoss)
   {
      why="REAL account blocked: possible substantial/total trading-loss acknowledgement is missing.";
      return false;
   }
   if(!InpAcknowledgeAILimitations)
   {
      why="REAL account blocked: AI/automation limitations acknowledgement is missing.";
      return false;
   }
   if(!InpAcknowledgeBrokerThirdPartyRisk)
   {
      why="REAL account blocked: broker/third-party execution risk acknowledgement is missing.";
      return false;
   }
   if(!InpAcknowledgePersonalResponsibility)
   {
      why="REAL account blocked: personal trading responsibility acknowledgement is missing.";
      return false;
   }
   if(!InpAcknowledgeDemoFirst)
   {
      why="REAL account blocked: demo-first testing acknowledgement is missing.";
      return false;
   }

   if(RiskAckTrim(InpAcceptedGPTTermsVersion)!=GPT_EA_LEGAL_TERMS_VERSION)
   {
      why="REAL account blocked: accepted terms version is missing or stale.";
      return false;
   }
   if(RiskAckTrim(InpAcceptedGPTRiskAckVersion)!=GPT_EA_RISK_ACK_SCHEMA_VERSION)
   {
      why="REAL account blocked: risk acknowledgement version is missing or stale.";
      return false;
   }

   string jurisdiction=RiskAckTrim(InpCustomerJurisdiction);
   if(StringLen(jurisdiction)<2)
   {
      why="REAL account blocked: customer jurisdiction code is required.";
      return false;
   }

   why="Customer risk acknowledgement PASS | schema="+GPT_EA_RISK_ACK_SCHEMA_VERSION+" | jurisdiction="+jurisdiction;
   return true;
}

void WriteRiskAcknowledgementEvent(const bool passed,const string reason)
{
   if(!InpWriteRiskAcknowledgementLog || (bool)MQLInfoInteger(MQL_TESTER)) return;

   int h=FileOpen(InpRiskAcknowledgementLogFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(h==INVALID_HANDLE) return;

   if(FileSize(h)==0)
      FileWrite(h,"time","terms_version","ack_schema","jurisdiction","license_ref_masked","broker","server","state","reason");

   FileSeek(h,0,SEEK_END);
   FileWrite(h,
      TimeToString(TimeLocal(),TIME_DATE|TIME_SECONDS),
      GPT_EA_LEGAL_TERMS_VERSION,
      GPT_EA_RISK_ACK_SCHEMA_VERSION,
      RiskAckTrim(InpCustomerJurisdiction),
      RiskAckMaskLicense(InpCustomerLicenseReference),
      AccountInfoString(ACCOUNT_COMPANY),
      AccountInfoString(ACCOUNT_SERVER),
      passed?"PASS":"BLOCK",
      reason
   );
   FileFlush(h);
   FileClose(h);
}

bool ReleaseSafetyAllowsR9CustomerAck(const string sym,string &why)
{
   string base="";
   if(!ReleaseSafetyAllowsR8Legal(sym,base))
   {
      why=base;
      return false;
   }

   string risk="";
   if(!GPTCustomerRiskAcknowledgementAllows(risk))
   {
      why=risk;
      return false;
   }

   why=base+(base!=""?" | ":"")+risk;
   return true;
}

void RefreshR9CustomerAckReleaseState()
{
   bool oldBlocked=g_releaseBlocked;
   string oldReason=g_releaseBlockReason;
   string why="";
   bool ok=ReleaseSafetyAllowsR9CustomerAck("",why);

   g_releaseBlocked=!ok;
   g_releaseBlockReason=(ok?"All R9 customer-acknowledgement/API/release gates pass.":why);

   if(g_releaseBlocked && (!oldBlocked || oldReason!=g_releaseBlockReason))
   {
      Print("GPT_EA R9 CUSTOMER ACK RELEASE BLOCK: ",g_releaseBlockReason);
      WriteRiskAcknowledgementEvent(false,g_releaseBlockReason);
   }
   else if(!g_releaseBlocked && oldBlocked)
   {
      Print("GPT_EA R9 CUSTOMER ACK RELEASE GATE CLEARED.");
      WriteRiskAcknowledgementEvent(true,why);
   }
}

string ReleaseGateSummaryR9CustomerAck()
{
   string why="";
   return ReleaseSafetyAllowsR9CustomerAck("",why)?"PASS - "+why:"BLOCKED - "+why;
}

void AdvancedSafetyInitR9CustomerAck()
{
   AdvancedSafetyInitR8Legal();
   RefreshR9CustomerAckReleaseState();

   if(!g_riskAckPassLogged &&
      (ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_REAL)
   {
      string why="";
      if(GPTCustomerRiskAcknowledgementAllows(why))
      {
         WriteRiskAcknowledgementEvent(true,why);
         g_riskAckPassLogged=true;
      }
   }
}

void AdvancedSafetyTimerR9CustomerAck()
{
   AdvancedSafetyTimerR8Legal();
   RefreshR9CustomerAckReleaseState();
}

void StopFailureObservabilityInitR9CustomerAck()
{
   StopFailureObservabilityInitR8Legal();
   RefreshR9CustomerAckReleaseState();
}
// GPT_EA Part 40 - Privacy sign-off release gate
// R10 privacy governance gate. This is a release/deployment sign-off layer,
// not a substitute for jurisdiction-specific legal/privacy advice.
//
// REAL-account new entries require a versioned, evidence-bound privacy sign-off
// for the customer's jurisdiction. Existing positions continue to be managed
// by the underlying R9/R8/R7 safety stack when this gate blocks new entries.

const string GPT_EA_PRIVACY_SIGNOFF_SCHEMA_VERSION = "gpt_ea_privacy_signoff_v1";

input bool   InpReleasePrivacySignoffPassed              = false;
input string InpReleasePrivacySignoffSchemaVersion       = "";
input string InpReleasePrivacySignoffId                  = "";
input string InpReleasePrivacySignoffDigest              = "";
input string InpReleasePrivacyReviewer                   = "";
input string InpReleasePrivacyReviewerRole               = "";
input string InpReleasePrivacySignedAt                   = "";
input string InpReleasePrivacyJurisdiction               = "";
input bool   InpReleasePrivacyDataInventoryApproved      = false;
input bool   InpReleasePrivacyRetentionApproved          = false;
input bool   InpReleasePrivacyCustomerNoticeApproved     = false;
input bool   InpReleasePrivacySecretHandlingApproved     = false;
input bool   InpReleasePrivacyCrossBorderApproved        = false;
input bool   InpReleasePrivacyDeletionWorkflowApproved   = false;
input bool   InpReleasePrivacyIncidentResponseApproved   = false;
input string InpReleasePrivacyTelemetryState             = ""; // DISABLED or APPROVED
input int    InpReleasePrivacyUnresolvedCriticalFindings = 0;
input bool   InpWritePrivacySignoffLog                   = true;
input string InpPrivacySignoffLogFile                    = "GPT_EA_PrivacyRelease.csv";

bool g_privacyPassLogged=false;

string PrivacyTrim(string value)
{
   StringTrimLeft(value);
   StringTrimRight(value);
   return value;
}

bool PrivacyHex64(const string value)
{
   if(StringLen(value)!=64) return false;
   const string hex="0123456789abcdefABCDEF";
   for(int i=0;i<64;i++)
   {
      string ch=StringSubstr(value,i,1);
      if(StringFind(hex,ch)<0) return false;
   }
   return true;
}

void WritePrivacySignoffEvent(const bool passed,const string reason)
{
   if(!InpWritePrivacySignoffLog || (bool)MQLInfoInteger(MQL_TESTER)) return;

   int h=FileOpen(InpPrivacySignoffLogFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(h==INVALID_HANDLE) return;

   if(FileSize(h)==0)
      FileWrite(h,"time","schema","signoff_id","jurisdiction","reviewer","reviewer_role","telemetry_state","critical_findings","state","reason");

   FileSeek(h,0,SEEK_END);
   FileWrite(h,
      TimeToString(TimeLocal(),TIME_DATE|TIME_SECONDS),
      PrivacyTrim(InpReleasePrivacySignoffSchemaVersion),
      PrivacyTrim(InpReleasePrivacySignoffId),
      PrivacyTrim(InpReleasePrivacyJurisdiction),
      PrivacyTrim(InpReleasePrivacyReviewer),
      PrivacyTrim(InpReleasePrivacyReviewerRole),
      PrivacyTrim(InpReleasePrivacyTelemetryState),
      IntegerToString(InpReleasePrivacyUnresolvedCriticalFindings),
      passed?"PASS":"BLOCK",
      reason
   );
   FileFlush(h);
   FileClose(h);
}

bool GPTPrivacySignoffAllows(string &why)
{
   why="";

   if((bool)MQLInfoInteger(MQL_TESTER))
   {
      why="Strategy Tester: privacy sign-off is informational only.";
      return true;
   }

   ENUM_ACCOUNT_TRADE_MODE mode=(ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE);
   if(mode!=ACCOUNT_TRADE_MODE_REAL)
   {
      why="Demo/contest: privacy sign-off is informational until REAL arming.";
      return true;
   }

   if(!InpReleasePrivacySignoffPassed)
   {
      why="REAL account blocked: privacy release sign-off has not been attested.";
      return false;
   }
   if(PrivacyTrim(InpReleasePrivacySignoffSchemaVersion)!=GPT_EA_PRIVACY_SIGNOFF_SCHEMA_VERSION)
   {
      why="REAL account blocked: privacy sign-off schema is missing or stale.";
      return false;
   }
   if(StringLen(PrivacyTrim(InpReleasePrivacySignoffId))<6)
   {
      why="REAL account blocked: privacy sign-off evidence ID is missing.";
      return false;
   }
   if(!PrivacyHex64(PrivacyTrim(InpReleasePrivacySignoffDigest)))
   {
      why="REAL account blocked: privacy sign-off digest must be a 64-character SHA-256 value.";
      return false;
   }
   if(StringLen(PrivacyTrim(InpReleasePrivacyReviewer))<2 ||
      StringLen(PrivacyTrim(InpReleasePrivacyReviewerRole))<2 ||
      StringLen(PrivacyTrim(InpReleasePrivacySignedAt))<8)
   {
      why="REAL account blocked: privacy reviewer identity/role/timestamp is incomplete.";
      return false;
   }

   string customerJurisdiction=PrivacyTrim(InpCustomerJurisdiction);
   string approvedJurisdiction=PrivacyTrim(InpReleasePrivacyJurisdiction);
   if(StringLen(approvedJurisdiction)<2 || approvedJurisdiction!=customerJurisdiction)
   {
      why="REAL account blocked: privacy sign-off jurisdiction does not match the customer jurisdiction.";
      return false;
   }

   if(!InpReleasePrivacyDataInventoryApproved ||
      !InpReleasePrivacyRetentionApproved ||
      !InpReleasePrivacyCustomerNoticeApproved ||
      !InpReleasePrivacySecretHandlingApproved ||
      !InpReleasePrivacyCrossBorderApproved ||
      !InpReleasePrivacyDeletionWorkflowApproved ||
      !InpReleasePrivacyIncidentResponseApproved)
   {
      why="REAL account blocked: one or more mandatory privacy controls are not approved.";
      return false;
   }

   string telemetry=PrivacyTrim(InpReleasePrivacyTelemetryState);
   if(telemetry!="DISABLED" && telemetry!="APPROVED")
   {
      why="REAL account blocked: privacy telemetry state must be DISABLED or APPROVED.";
      return false;
   }

   if(InpReleasePrivacyUnresolvedCriticalFindings!=0)
   {
      why="REAL account blocked: privacy review has unresolved critical findings.";
      return false;
   }

   why="Privacy sign-off PASS | schema="+GPT_EA_PRIVACY_SIGNOFF_SCHEMA_VERSION+
       " | jurisdiction="+approvedJurisdiction+" | telemetry="+telemetry;
   return true;
}

bool ReleaseSafetyAllowsR10Privacy(const string sym,string &why)
{
   string base="";
   if(!ReleaseSafetyAllowsR9CustomerAck(sym,base))
   {
      why=base;
      return false;
   }

   string privacy="";
   if(!GPTPrivacySignoffAllows(privacy))
   {
      why=privacy;
      return false;
   }

   why=base+(base!=""?" | ":"")+privacy;
   return true;
}

void RefreshR10PrivacyReleaseState()
{
   bool oldBlocked=g_releaseBlocked;
   string oldReason=g_releaseBlockReason;
   string why="";
   bool ok=ReleaseSafetyAllowsR10Privacy("",why);

   g_releaseBlocked=!ok;
   g_releaseBlockReason=(ok?"All R10 privacy/customer/legal/API/release gates pass.":why);

   if(g_releaseBlocked && (!oldBlocked || oldReason!=g_releaseBlockReason))
   {
      Print("GPT_EA R10 PRIVACY RELEASE BLOCK: ",g_releaseBlockReason);
      WritePrivacySignoffEvent(false,g_releaseBlockReason);
   }
   else if(!g_releaseBlocked && oldBlocked)
   {
      Print("GPT_EA R10 PRIVACY RELEASE GATE CLEARED.");
      if(!g_privacyPassLogged)
      {
         WritePrivacySignoffEvent(true,why);
         g_privacyPassLogged=true;
      }
   }
}

string ReleaseGateSummaryR10Privacy()
{
   string why="";
   return ReleaseSafetyAllowsR10Privacy("",why)?"PASS - "+why:"BLOCKED - "+why;
}

void AdvancedSafetyInitR10Privacy()
{
   AdvancedSafetyInitR9CustomerAck();
   RefreshR10PrivacyReleaseState();

   if(!g_privacyPassLogged &&
      (ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_REAL)
   {
      string why="";
      if(GPTPrivacySignoffAllows(why))
      {
         WritePrivacySignoffEvent(true,why);
         g_privacyPassLogged=true;
      }
   }
}

void AdvancedSafetyTimerR10Privacy()
{
   AdvancedSafetyTimerR9CustomerAck();
   RefreshR10PrivacyReleaseState();
}

void StopFailureObservabilityInitR10Privacy()
{
   StopFailureObservabilityInitR9CustomerAck();
   RefreshR10PrivacyReleaseState();
}
#define ReleaseSafetyAllows ReleaseSafetyAllowsR10Privacy
#define ReleaseGateSummary ReleaseGateSummaryR10Privacy
#define StopFailureObservabilityInit StopFailureObservabilityInitR10Privacy
#define AdvancedSafetyInit AdvancedSafetyInitR10Privacy
#define AdvancedSafetyTimer AdvancedSafetyTimerR10Privacy
// GPT_EA Part 15 - Full regime-driven strategy intelligence

input bool   InpUseFullStrategyIntelligence      = true;
input int    InpMinStrategyScore                 = 72;
input int    InpMinCounterTrendScore             = 82;
input double InpDeepRetracementATR               = 0.85;
input double InpExhaustionATR                    = 2.00;
input double InpRangeBoundaryFraction            = 0.22;
input bool   InpAllowCounterTrendScalp            = true;
input bool   InpAllowCounterTrendSwing            = true;
input bool   InpAllowRangeTrades                  = true;
input bool   InpAllowMeanReversion                = true;
input bool   InpUseHistoricalStrategyEvidence     = true;
input int    InpStrategyEvidenceMinTrades         = 15;
input double InpStrategyEvidenceMinProfitFactor   = 1.05;
input double InpStrategyEvidenceMinAverageR       = 0.05;
input bool   InpBlockNegativeStrategyEvidence     = true;
input bool   InpRequireEvidenceSampleForLive      = false;
input int    InpStrategyHistoryLookbackDays       = 45;

// Display classifications requested by the strategy contract.
enum StrategyClass
{
   STRATEGY_NO_TRADE=0,
   STRATEGY_TREND_CONTINUATION=1,
   STRATEGY_RETRACEMENT_ENTRY=2,
   STRATEGY_COUNTER_TREND_SCALP=3,
   STRATEGY_COUNTER_TREND_SWING=4,
   STRATEGY_POTENTIAL_REVERSAL=5,
   STRATEGY_BREAKOUT=6,
   STRATEGY_BREAKOUT_RETEST=7,
   STRATEGY_RANGE_TRADE=8,
   STRATEGY_MEAN_REVERSION=9
};

enum MarketStateClass
{
   STATE_UNKNOWN=0,
   STATE_TREND_CONTINUATION=1,
   STATE_HEALTHY_RETRACEMENT=2,
   STATE_DEEP_RETRACEMENT=3,
   STATE_CORRECTION=4,
   STATE_COUNTER_TREND_MOVE=5,
   STATE_TREND_FAILURE=6,
   STATE_REVERSAL=7,
   STATE_BREAKOUT=8,
   STATE_BREAKOUT_RETEST=9,
   STATE_FALSE_BREAKOUT=10,
   STATE_LIQUIDITY_SWEEP=11,
   STATE_RANGE_EXPANSION=12,
   STATE_RANGE_REVERSAL=13,
   STATE_MEAN_REVERSION=14,
   STATE_MOMENTUM_CONTINUATION=15,
   STATE_EXHAUSTION=16,
   STATE_ACCUMULATION=17,
   STATE_DISTRIBUTION=18,
   STATE_CONSOLIDATION=19
};

enum StrategyAction
{
   STRATEGY_ACTION_NO_TRADE=0,
   STRATEGY_ACTION_WAIT=1,
   STRATEGY_ACTION_HIGH_CONFIDENCE=2
};

struct StrategySnapshot
{
   string symbol;
   bool dominantBull;
   bool htfStrong;
   int bullVotes;
   int bearVotes;
   double adx;
   double plusDI;
   double minusDI;
   double atr;
   double atrAverage;
   double atrRatio;
   double openingRangeRatio;
   double rsi15;
   double rsi5;
   double ema20;
   double ema50;
   double mid;
   double priorHigh;
   double priorLow;
   double previousDayHigh;
   double previousDayLow;
   double asianHigh;
   double asianLow;
   double rangePosition;
   double overextensionATR;
   double volumeRatio;
   bool m15BullStructure;
   bool m15BearStructure;
   bool ltfBullBreak;
   bool ltfBearBreak;
   bool bullishSweep;
   bool bearishSweep;
   bool bullishDivergence;
   bool bearishDivergence;
   bool doubleBottom;
   bool doubleTop;
   bool breakoutUp;
   bool breakoutDown;
   bool falseBreakUp;
   bool falseBreakDown;
   bool compression;
   bool expansion;
   bool exhaustion;
   bool possibleAccumulation;
   bool possibleDistribution;
   bool trendFailure;
   bool chochAgainstTrend;
   string baseRegime;
   string session;
   MarketStateClass state;
};

struct StrategyDecision
{
   TradeSetup setup;
   StrategyClass strategy;
   MarketStateClass state;
   StrategyAction action;
   bool counterTrend;
   int score;
   int counterTrendScore;
   string strategyName;
   string regime;
   string stateText;
   string rationale;
   string confirmation;
   string counterargument;
   string librarySummary;
   string evidence;
   string session;
};

string StrategyClassName(StrategyClass c)
{
   switch(c)
   {
      case STRATEGY_TREND_CONTINUATION: return "TREND CONTINUATION";
      case STRATEGY_RETRACEMENT_ENTRY: return "RETRACEMENT ENTRY";
      case STRATEGY_COUNTER_TREND_SCALP: return "COUNTER-TREND SCALP";
      case STRATEGY_COUNTER_TREND_SWING: return "COUNTER-TREND SWING";
      case STRATEGY_POTENTIAL_REVERSAL: return "POTENTIAL REVERSAL";
      case STRATEGY_BREAKOUT: return "BREAKOUT";
      case STRATEGY_BREAKOUT_RETEST: return "BREAKOUT-RETEST";
      case STRATEGY_RANGE_TRADE: return "RANGE TRADE";
      case STRATEGY_MEAN_REVERSION: return "MEAN-REVERSION SETUP";
      default: return "NO TRADE";
   }
}

string StrategyCode(StrategyClass c)
{
   switch(c)
   {
      case STRATEGY_TREND_CONTINUATION: return "TC";
      case STRATEGY_RETRACEMENT_ENTRY: return "RE";
      case STRATEGY_COUNTER_TREND_SCALP: return "CTS";
      case STRATEGY_COUNTER_TREND_SWING: return "CTW";
      case STRATEGY_POTENTIAL_REVERSAL: return "REV";
      case STRATEGY_BREAKOUT: return "BO";
      case STRATEGY_BREAKOUT_RETEST: return "BRT";
      case STRATEGY_RANGE_TRADE: return "RNG";
      case STRATEGY_MEAN_REVERSION: return "MR";
      default: return "NT";
   }
}

string MarketStateName(MarketStateClass s)
{
   switch(s)
   {
      case STATE_TREND_CONTINUATION: return "TREND CONTINUATION";
      case STATE_HEALTHY_RETRACEMENT: return "HEALTHY RETRACEMENT";
      case STATE_DEEP_RETRACEMENT: return "DEEP RETRACEMENT";
      case STATE_CORRECTION: return "CORRECTION";
      case STATE_COUNTER_TREND_MOVE: return "COUNTER-TREND MOVEMENT";
      case STATE_TREND_FAILURE: return "TREND FAILURE";
      case STATE_REVERSAL: return "REVERSAL";
      case STATE_BREAKOUT: return "BREAKOUT";
      case STATE_BREAKOUT_RETEST: return "BREAKOUT-RETEST";
      case STATE_FALSE_BREAKOUT: return "FALSE BREAKOUT";
      case STATE_LIQUIDITY_SWEEP: return "LIQUIDITY SWEEP";
      case STATE_RANGE_EXPANSION: return "RANGE EXPANSION";
      case STATE_RANGE_REVERSAL: return "RANGE REVERSAL";
      case STATE_MEAN_REVERSION: return "MEAN REVERSION";
      case STATE_MOMENTUM_CONTINUATION: return "MOMENTUM CONTINUATION";
      case STATE_EXHAUSTION: return "EXHAUSTION";
      case STATE_ACCUMULATION: return "POSSIBLE ACCUMULATION";
      case STATE_DISTRIBUTION: return "POSSIBLE DISTRIBUTION";
      case STATE_CONSOLIDATION: return "CONSOLIDATION";
      default: return "UNCLASSIFIED";
   }
}

string CurrentSessionBucket()
{
   datetime utc=TimeGMT();
   MqlDateTime l={}; TimeToStruct(LondonLocal(utc),l);
   MqlDateTime n={}; TimeToStruct(NewYorkLocal(utc),n);
   if(l.hour>=7 && l.hour<9) return "LONDON_PREOPEN";
   if(l.hour>=9 && l.hour<12) return "LONDON";
   if(n.hour>=8 && n.hour<9) return "NEW_YORK_PREOPEN";
   if(n.hour>=9 && n.hour<12) return "NEW_YORK_OPEN";
   if(l.hour>=13 && n.hour<12) return "LONDON_NY_OVERLAP";
   if(l.hour>=0 && l.hour<7) return "ASIAN";
   return "OTHER";
}

bool PreviousDayHighLow(const string sym,double &hi,double &lo)
{
   hi=iHigh(sym,PERIOD_D1,1); lo=iLow(sym,PERIOD_D1,1);
   return (hi>0 && lo>0 && hi>lo);
}

bool AsianRange(const string sym,double &hi,double &lo)
{
   hi=-1.0e100; lo=1.0e100;
   MqlRates r[]; ArraySetAsSeries(r,true);
   int n=CopyRates(sym,PERIOD_M15,0,160,r);
   if(n<=0) return false;
   int chosenDate=-1,found=0;
   for(int i=0;i<n;i++)
   {
      datetime utc=ServerToUTC(r[i].time);
      MqlDateTime t={}; TimeToStruct(utc,t);
      int d=t.year*10000+t.mon*100+t.day;
      if(t.hour>=0 && t.hour<6)
      {
         if(chosenDate<0) chosenDate=d;
         if(d!=chosenDate) continue;
         hi=MathMax(hi,r[i].high); lo=MathMin(lo,r[i].low); found++;
      }
   }
   return (found>=8 && hi>lo);
}

bool RSIDivergenceSignal(const string sym,bool bullish)
{
   double h1=0,l1=0,h2=0,l2=0;
   if(!RecentHighLow(sym,PERIOD_M15,1,5,h1,l1) || !RecentHighLow(sym,PERIOD_M15,7,5,h2,l2)) return false;
   double r2=50,r8=50;
   RSIValue(sym,PERIOD_M15,InpRSIPeriod,2,r2);
   RSIValue(sym,PERIOD_M15,InpRSIPeriod,8,r8);
   if(bullish) return (l1<l2 && r2>r8+2.0);
   return (h1>h2 && r2<r8-2.0);
}

bool DoubleTopBottomSignal(const string sym,bool bottom)
{
   double h1=0,l1=0,h2=0,l2=0,atr=0;
   if(!RecentHighLow(sym,PERIOD_M15,1,6,h1,l1) || !RecentHighLow(sym,PERIOD_M15,8,6,h2,l2) ||
      !ATRValue(sym,PERIOD_M15,InpATRPeriod,1,atr) || atr<=0) return false;
   double tol=0.25*atr;
   return bottom ? (MathAbs(l1-l2)<=tol) : (MathAbs(h1-h2)<=tol);
}

bool LowerTimeframeStructureBreak(const string sym,bool bullishBreak)
{
   double h1=0,l1=0,h2=0,l2=0;
   if(!RecentHighLow(sym,PERIOD_M5,1,5,h1,l1) || !RecentHighLow(sym,PERIOD_M5,7,5,h2,l2)) return false;
   return bullishBreak ? (h1>h2 && l1>l2) : (h1<h2 && l1<l2);
}

bool FalseBreakSignal(const string sym,bool upside)
{
   MqlRates r[]; ArraySetAsSeries(r,true);
   if(CopyRates(sym,PERIOD_M15,1,16,r)<14) return false;
   double ph=-1.0e100,pl=1.0e100;
   for(int i=2;i<=12;i++){ ph=MathMax(ph,r[i].high); pl=MathMin(pl,r[i].low); }
   if(upside) return (r[0].high>ph && r[0].close<ph);
   return (r[0].low<pl && r[0].close>pl);
}

bool ConfirmedBreakoutSignal(const string sym,bool upside,double atr)
{
   MqlRates r[]; ArraySetAsSeries(r,true);
   if(CopyRates(sym,PERIOD_M15,1,16,r)<14 || atr<=0) return false;
   double ph=-1.0e100,pl=1.0e100;
   for(int i=1;i<=12;i++){ ph=MathMax(ph,r[i].high); pl=MathMin(pl,r[i].low); }
   double body=MathAbs(r[0].close-r[0].open);
   if(upside) return (r[0].close>ph && body>=0.45*atr);
   return (r[0].close<pl && body>=0.45*atr);
}

void BuildStrategySnapshot(const string sym,StrategySnapshot &x)
{
   ZeroMemory(x);
   x.symbol=sym;
   x.baseRegime=DetectMarketRegime(sym);
   x.session=CurrentSessionBucket();
   x.bullVotes=0; x.bearVotes=0;
   ENUM_TIMEFRAMES htf[3]={PERIOD_D1,PERIOD_H4,PERIOD_H1};
   for(int i=0;i<3;i++)
   {
      if(TrendVote(sym,htf[i],true)>0) x.bullVotes++;
      if(TrendVote(sym,htf[i],false)>0) x.bearVotes++;
   }
   x.dominantBull=(x.bullVotes>=x.bearVotes);
   x.htfStrong=(MathMax(x.bullVotes,x.bearVotes)>=2 && MathMin(x.bullVotes,x.bearVotes)==0);
   ADXSnapshot(sym,PERIOD_M15,InpADXPeriod,x.adx,x.plusDI,x.minusDI);
   ATRValue(sym,PERIOD_M15,InpATRPeriod,1,x.atr);
   x.atrAverage=AverageATR(sym,PERIOD_M15,InpATRPeriod,50);
   x.atrRatio=(x.atrAverage>0?x.atr/x.atrAverage:1.0);
   x.openingRangeRatio=OpeningRangeRatio(sym);
   RSIValue(sym,PERIOD_M15,InpRSIPeriod,1,x.rsi15);
   RSIValue(sym,PERIOD_M5,InpRSIPeriod,1,x.rsi5);
   EMAValue(sym,PERIOD_M15,InpFastEMA,1,x.ema20);
   EMAValue(sym,PERIOD_M15,InpSlowEMA,1,x.ema50);
   MqlTick t={}; GetTickSafe(sym,t); x.mid=(t.ask+t.bid)*0.5;
   RecentHighLow(sym,PERIOD_M15,2,InpSwingBars,x.priorHigh,x.priorLow);
   PreviousDayHighLow(sym,x.previousDayHigh,x.previousDayLow);
   AsianRange(sym,x.asianHigh,x.asianLow);
   double width=x.priorHigh-x.priorLow;
   x.rangePosition=(width>0?(x.mid-x.priorLow)/width:0.5);
   x.overextensionATR=(x.atr>0?(x.mid-x.ema20)/x.atr:0);
   x.volumeRatio=M5VolumeRatio(sym);
   x.m15BullStructure=StructureAligned(sym,true);
   x.m15BearStructure=StructureAligned(sym,false);
   x.ltfBullBreak=LowerTimeframeStructureBreak(sym,true);
   x.ltfBearBreak=LowerTimeframeStructureBreak(sym,false);
   x.bullishSweep=LiquiditySweepAligned(sym,true);
   x.bearishSweep=LiquiditySweepAligned(sym,false);
   x.bullishDivergence=RSIDivergenceSignal(sym,true);
   x.bearishDivergence=RSIDivergenceSignal(sym,false);
   x.doubleBottom=DoubleTopBottomSignal(sym,true);
   x.doubleTop=DoubleTopBottomSignal(sym,false);
   x.breakoutUp=ConfirmedBreakoutSignal(sym,true,x.atr);
   x.breakoutDown=ConfirmedBreakoutSignal(sym,false,x.atr);
   x.falseBreakUp=FalseBreakSignal(sym,true);
   x.falseBreakDown=FalseBreakSignal(sym,false);
   x.compression=(x.baseRegime=="COMPRESSION" || (x.atrRatio<0.75 && x.adx<18));
   x.expansion=(x.baseRegime=="HIGH_VOL_EXPANSION" || x.atrRatio>1.40 || x.openingRangeRatio>1.75);
   x.exhaustion=(MathAbs(x.overextensionATR)>=InpExhaustionATR &&
                 ((x.overextensionATR>0 && (x.bearishDivergence || x.rsi15>=70)) ||
                  (x.overextensionATR<0 && (x.bullishDivergence || x.rsi15<=30))));
   bool against=(x.dominantBull?x.ltfBearBreak:x.ltfBullBreak);
   x.chochAgainstTrend=against;
   x.trendFailure=(x.htfStrong && against &&
                   (x.dominantBull?x.m15BearStructure:x.m15BullStructure));
   x.possibleAccumulation=(x.baseRegime=="RANGING" && x.rangePosition<0.40 && x.bullishDivergence && x.volumeRatio>=0.9);
   x.possibleDistribution=(x.baseRegime=="RANGING" && x.rangePosition>0.60 && x.bearishDivergence && x.volumeRatio>=0.9);

   // State precedence: structural failure/reversal > breakout/fakeout > retracement > range/compression > trend.
   if(x.trendFailure && ((x.dominantBull && x.bearishSweep) || (!x.dominantBull && x.bullishSweep))) x.state=STATE_REVERSAL;
   else if(x.trendFailure) x.state=STATE_TREND_FAILURE;
   else if(x.falseBreakUp || x.falseBreakDown) x.state=STATE_FALSE_BREAKOUT;
   else if(x.breakoutUp || x.breakoutDown) x.state=(x.expansion?STATE_RANGE_EXPANSION:STATE_BREAKOUT);
   else if(x.bullishSweep || x.bearishSweep) x.state=STATE_LIQUIDITY_SWEEP;
   else if(x.exhaustion) x.state=STATE_EXHAUSTION;
   else if(x.possibleAccumulation) x.state=STATE_ACCUMULATION;
   else if(x.possibleDistribution) x.state=STATE_DISTRIBUTION;
   else if(x.compression) x.state=STATE_CONSOLIDATION;
   else if(x.baseRegime=="RANGING")
   {
      if(x.rangePosition<=InpRangeBoundaryFraction || x.rangePosition>=1.0-InpRangeBoundaryFraction) x.state=STATE_RANGE_REVERSAL;
      else x.state=STATE_MEAN_REVERSION;
   }
   else if(x.htfStrong)
   {
      bool againstEMA=(x.dominantBull?x.mid<x.ema20:x.mid>x.ema20);
      bool deep=(x.dominantBull?x.mid<=x.ema50:x.mid>=x.ema50) || MathAbs(x.mid-x.ema20)>=InpDeepRetracementATR*x.atr;
      if(againstEMA && deep) x.state=STATE_DEEP_RETRACEMENT;
      else if(againstEMA) x.state=STATE_HEALTHY_RETRACEMENT;
      else if(x.expansion && x.volumeRatio>=1.15) x.state=STATE_MOMENTUM_CONTINUATION;
      else x.state=STATE_TREND_CONTINUATION;
   }
   else x.state=STATE_CORRECTION;
}

string FibRetracementText(const StrategySnapshot &x)
{
   double w=x.priorHigh-x.priorLow;
   if(w<=0) return "Fibonacci: unavailable.";
   double f382=(x.dominantBull?x.priorHigh-0.382*w:x.priorLow+0.382*w);
   double f618=(x.dominantBull?x.priorHigh-0.618*w:x.priorLow+0.618*w);
   double lo=MathMin(f382,f618),hi=MathMax(f382,f618);
   bool inside=(x.mid>=lo && x.mid<=hi);
   return StringFormat("Fibonacci 38.2-61.8%% retracement zone %.5f-%.5f; price %s.",lo,hi,inside?"inside":"outside");
}

string SupplyDemandText(const StrategySnapshot &x)
{
   if(x.atr<=0) return "Supply/demand: unavailable.";
   double demandLo=x.priorLow,demandHi=x.priorLow+0.35*x.atr;
   double supplyLo=x.priorHigh-0.35*x.atr,supplyHi=x.priorHigh;
   return StringFormat("Demand %.5f-%.5f | Supply %.5f-%.5f",demandLo,demandHi,supplyLo,supplyHi);
}

int CounterTrendScore(const StrategySnapshot &x,bool counterBull)
{
   int s=0;
   if(x.exhaustion) s+=18;
   if(counterBull?x.bullishSweep:x.bearishSweep) s+=16;
   if(counterBull?x.bullishDivergence:x.bearishDivergence) s+=14;
   if(counterBull?x.doubleBottom:x.doubleTop) s+=8;
   if(counterBull?x.ltfBullBreak:x.ltfBearBreak) s+=18;
   if(x.chochAgainstTrend) s+=10;
   bool major=(counterBull?(x.rangePosition<=0.20 || (x.previousDayLow>0 && x.mid<=x.previousDayLow+0.25*x.atr)):
                           (x.rangePosition>=0.80 || (x.previousDayHigh>0 && x.mid>=x.previousDayHigh-0.25*x.atr)));
   if(major) s+=10;
   if(x.adx>=32 && x.htfStrong) s-=12; // fighting a powerful trend requires exceptional evidence.
   if(x.expansion && !x.exhaustion) s-=8;
   return MathMax(0,MathMin(100,s));
}

void SetConservativeTargets(TradeSetup &s,double r1,double r2,double r3)
{
   double R=MathAbs(s.preferred-s.sl); if(R<=0) return;
   if(s.bullish){ s.tp1=s.preferred+r1*R; s.tp2=s.preferred+r2*R; s.tp3=s.preferred+r3*R; }
   else { s.tp1=s.preferred-r1*R; s.tp2=s.preferred-r2*R; s.tp3=s.preferred-r3*R; }
   s.tp1=NormPrice(s.symbol,s.tp1); s.tp2=NormPrice(s.symbol,s.tp2); s.tp3=NormPrice(s.symbol,s.tp3);
   s.nominalRR1=r1;
   s.effectiveRR1=EffectiveRRDynamic(s);
}

TradeSetup BuildCounterTrendCandidate(const StrategySnapshot &x,bool bull,int score,bool swing)
{
   TradeSetup s; InitSetup(s,x.symbol,SETUP_PULLBACK,bull);
   double atr=x.atr; if(atr<=0) return s;
   double extreme=(bull?x.priorLow:x.priorHigh);
   s.name=(swing?"COUNTER-TREND SWING":"COUNTER-TREND SCALP");
   s.zoneLow=NormPrice(x.symbol,extreme-0.12*atr);
   s.zoneHigh=NormPrice(x.symbol,extreme+0.12*atr);
   s.preferred=NormPrice(x.symbol,extreme);
   s.sl=NormPrice(x.symbol,bull?extreme-0.45*atr:extreme+0.45*atr);
   SetConservativeTargets(s,swing?0.90:0.70,swing?1.60:1.15,swing?2.30:1.70);
   s.confidence=MathMin(94,score);
   s.expiryM15=AdaptiveExpiry(x.symbol,swing?4:2);
   s.valid=(score>=InpMinCounterTrendScore && s.effectiveRR1>=MathMax(1.05,InpMinEffectiveRR-0.35));
   s.reason=StringFormat("COUNTER-TREND TRADE | HTF %s but exhaustion/structure evidence supports a %s counter move. Score %d/100.",
                         x.dominantBull?"bullish":"bearish",bull?"bullish":"bearish",score);
   s.invalidation=(bull?"M15 acceptance below the swept/major support extreme invalidates the counter-trend thesis.":
                        "M15 acceptance above the swept/major resistance extreme invalidates the counter-trend thesis.");
   s.failurePattern="Failure: dominant higher-timeframe trend re-accelerates before lower-timeframe reversal structure develops.";
   s.executionRule="Counter-trend entry requires liquidity rejection plus M5 change-of-character/break-of-structure and a confirming rejection. No blind fading.";
   return s;
}

TradeSetup BuildRangeCandidate(const StrategySnapshot &x,bool meanReversion)
{
   bool bull=(x.rangePosition<=0.50);
   TradeSetup s; InitSetup(s,x.symbol,SETUP_PULLBACK,bull);
   if(x.atr<=0 || x.priorHigh<=x.priorLow) return s;
   double boundary=(bull?x.priorLow:x.priorHigh);
   s.name=(meanReversion?"MEAN-REVERSION SETUP":"RANGE TRADE");
   s.zoneLow=NormPrice(x.symbol,boundary-0.12*x.atr);
   s.zoneHigh=NormPrice(x.symbol,boundary+0.12*x.atr);
   s.preferred=NormPrice(x.symbol,boundary);
   s.sl=NormPrice(x.symbol,bull?boundary-0.45*x.atr:boundary+0.45*x.atr);
   double eq=(x.priorHigh+x.priorLow)*0.5;
   double R=MathAbs(s.preferred-s.sl);
   s.tp1=NormPrice(x.symbol,eq);
   s.tp2=NormPrice(x.symbol,bull?x.priorHigh-0.15*x.atr:x.priorLow+0.15*x.atr);
   s.tp3=NormPrice(x.symbol,bull?x.priorHigh:x.priorLow);
   s.nominalRR1=(R>0?MathAbs(s.tp1-s.preferred)/R:0);
   s.effectiveRR1=EffectiveRRDynamic(s);
   int boundaryScore=(x.rangePosition<=InpRangeBoundaryFraction || x.rangePosition>=1.0-InpRangeBoundaryFraction?82:64);
   if(bull && (x.bullishSweep || x.doubleBottom)) boundaryScore+=8;
   if(!bull && (x.bearishSweep || x.doubleTop)) boundaryScore+=8;
   s.confidence=MathMin(94,boundaryScore);
   s.expiryM15=AdaptiveExpiry(x.symbol,5);
   s.valid=(InpAllowRangeTrades && boundaryScore>=InpMinStrategyScore && s.effectiveRR1>=1.05);
   s.reason=StringFormat("%s at range boundary %.5f-%.5f; equilibrium %.5f.",s.name,x.priorLow,x.priorHigh,eq);
   s.invalidation="A decisive M15 close outside the range boundary in the adverse direction invalidates the range/mean-reversion thesis.";
   s.failurePattern="Failure: range transitions into directional expansion and boundary rejection does not hold.";
   s.executionRule="Enter only at a range boundary after rejection/reclaim; never initiate a range trade in the middle of the range.";
   return s;
}

int StrategyBaseScore(const StrategySnapshot &x,StrategyClass c)
{
   int s=45;
   switch(c)
   {
      case STRATEGY_TREND_CONTINUATION:
         s+=(x.htfStrong?18:5)+(x.adx>=25?12:4)+((x.dominantBull?x.m15BullStructure:x.m15BearStructure)?12:0)+(x.volumeRatio>=1.0?6:0);
         break;
      case STRATEGY_RETRACEMENT_ENTRY:
         s+=(x.htfStrong?20:5)+((x.state==STATE_HEALTHY_RETRACEMENT)?16:(x.state==STATE_DEEP_RETRACEMENT?10:0))+(MathAbs(x.overextensionATR)<1.5?8:0);
         break;
      case STRATEGY_BREAKOUT:
         s+=(x.breakoutUp||x.breakoutDown?20:0)+(x.expansion?15:0)+(x.volumeRatio>=1.15?10:0)+(x.adx>=23?8:0);
         break;
      case STRATEGY_BREAKOUT_RETEST:
         s+=(x.expansion?10:0)+(x.adx>=20?8:0)+(x.volumeRatio>=0.95?6:0);
         break;
      case STRATEGY_POTENTIAL_REVERSAL:
         s+=(x.trendFailure?20:0)+(x.chochAgainstTrend?15:0)+(x.exhaustion?10:0)+((x.bullishDivergence||x.bearishDivergence)?8:0);
         break;
      case STRATEGY_RANGE_TRADE:
         s+=(x.baseRegime=="RANGING"?20:0)+((x.rangePosition<=0.22||x.rangePosition>=0.78)?18:0)+((x.bullishSweep||x.bearishSweep)?8:0);
         break;
      case STRATEGY_MEAN_REVERSION:
         s+=(x.baseRegime=="RANGING"?18:0)+(MathAbs(x.overextensionATR)>=1.0?15:0)+(x.exhaustion?8:0);
         break;
      default: break;
   }
   return MathMax(0,MathMin(100,s));
}

string StrategyStatsKey(StrategyClass c,const string suffix)
{
   return SysKey(StringFormat("STRAT_%d_%s",(int)c,suffix));
}

void UpdateStrategyBucket(const string prefix,double R)
{
   double n=GVRead(prefix+"_N",0)+1;
   double wins=GVRead(prefix+"_WIN",0)+(R>0?1:0);
   double sum=GVRead(prefix+"_SUMR",0)+R;
   double pos=GVRead(prefix+"_POSR",0)+(R>0?R:0);
   double neg=GVRead(prefix+"_NEGR",0)+(R<0?-R:0);
   double curve=GVRead(prefix+"_CURVE",0)+R;
   double peak=MathMax(GVRead(prefix+"_PEAK",0),curve);
   double dd=MathMax(GVRead(prefix+"_MAXDD",0),peak-curve);
   double run=(R<0?GVRead(prefix+"_LOSSRUN",0)+1:0);
   double maxRun=MathMax(GVRead(prefix+"_MAXLOSSRUN",0),run);
   GVWrite(prefix+"_N",n); GVWrite(prefix+"_WIN",wins); GVWrite(prefix+"_SUMR",sum);
   GVWrite(prefix+"_POSR",pos); GVWrite(prefix+"_NEGR",neg); GVWrite(prefix+"_CURVE",curve);
   GVWrite(prefix+"_PEAK",peak); GVWrite(prefix+"_MAXDD",dd); GVWrite(prefix+"_LOSSRUN",run); GVWrite(prefix+"_MAXLOSSRUN",maxRun);
}

string StrategyEvidenceText(StrategyClass c)
{
   string p=SysKey(StringFormat("STRAT_%d",(int)c));
   double n=GVRead(p+"_N",0),win=GVRead(p+"_WIN",0),sum=GVRead(p+"_SUMR",0);
   double pos=GVRead(p+"_POSR",0),neg=GVRead(p+"_NEGR",0),dd=GVRead(p+"_MAXDD",0),maxL=GVRead(p+"_MAXLOSSRUN",0);
   double wr=(n>0?win/n*100.0:0),avg=(n>0?sum/n:0),pf=(neg>0?pos/neg:(pos>0?99.0:0));
   return StringFormat("%s evidence: N %.0f | win %.1f%% | avg %.2fR | PF %.2f | max DD %.2fR | max losses %.0f",
      StrategyClassName(c),n,wr,avg,pf,dd,maxL);
}

bool StrategyEvidenceAllows(StrategyClass c,string &detail)
{
   detail=StrategyEvidenceText(c);
   if(!InpUseHistoricalStrategyEvidence || c==STRATEGY_NO_TRADE) return true;
   string p=SysKey(StringFormat("STRAT_%d",(int)c));
   double n=GVRead(p+"_N",0),sum=GVRead(p+"_SUMR",0),pos=GVRead(p+"_POSR",0),neg=GVRead(p+"_NEGR",0);
   if(n<InpStrategyEvidenceMinTrades)
   {
      if(InpRequireEvidenceSampleForLive && AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_REAL)
      { detail+=" | BLOCK: minimum live evidence sample not reached."; return false; }
      detail+=" | evidence sample still developing; treated as neutral, not proof of edge.";
      return true;
   }
   double avg=sum/n,pf=(neg>0?pos/neg:(pos>0?99.0:0));
   if(InpBlockNegativeStrategyEvidence && (avg<InpStrategyEvidenceMinAverageR || pf<InpStrategyEvidenceMinProfitFactor))
   { detail+=StringFormat(" | BLOCK: evidence below thresholds avg %.2fR / PF %.2f.",InpStrategyEvidenceMinAverageR,InpStrategyEvidenceMinProfitFactor); return false; }
   detail+=" | historical/internal evidence gate PASS; past results are not a guarantee.";
   return true;
}

void PersistStrategyCandidate(const string sym,const StrategyDecision &d)
{
   GVWrite(SymKey(sym,"CAND_STRATEGY"),(double)d.strategy);
   GVWrite(SymKey(sym,"CAND_STATE"),(double)d.state);
   GVWrite(SymKey(sym,"CAND_SCORE"),(double)d.score);
   GVWrite(SymKey(sym,"CAND_TIME"),(double)TimeTradeServer());
   GVWrite(SymKey(sym,"CAND_SESSION"),(double)StringFind("ASIAN,LONDON_PREOPEN,LONDON,LONDON_NY_OVERLAP,NEW_YORK_PREOPEN,NEW_YORK_OPEN,OTHER",d.session));
}

void PersistStrategyPlanForExecution(const TradeSetup &s)
{
   datetime ct=(datetime)GVRead(SymKey(s.symbol,"CAND_TIME"),0);
   int cls=(int)GVRead(SymKey(s.symbol,"CAND_STRATEGY"),STRATEGY_NO_TRADE);
   int state=(int)GVRead(SymKey(s.symbol,"CAND_STATE"),STATE_UNKNOWN);
   if(ct<=0 || TimeTradeServer()-ct>900) cls=STRATEGY_NO_TRADE;
   GVWrite(SymKey(s.symbol,"PLAN_STRATEGY"),cls);
   GVWrite(SymKey(s.symbol,"PLAN_STATE"),state);
   GVWrite(SymKey(s.symbol,"PLAN_STRAT_TIME"),(double)TimeTradeServer());
   GVWrite(SymKey(s.symbol,"PLAN_DIR"),s.bullish?1:0);
   StrategySnapshot x; BuildStrategySnapshot(s.symbol,x);
   GVWrite(SymKey(s.symbol,"PLAN_VOL"),(x.atrRatio>=1.35?2:(x.atrRatio<=0.75?0:1)));
   GVWrite(SymKey(s.symbol,"PLAN_SESSION_HASH"),(double)StringLen(x.session));
}

bool PositionIdStillOpenStrategy(ulong pid)
{
   return PositionIdentifierOpen(pid);
}

double StrategyPositionRealized(ulong pid)
{
   if(!HistorySelectByPosition(pid)) return 0;
   double pnl=0;
   int n=HistoryDealsTotal();
   for(int i=0;i<n;i++)
   {
      ulong d=HistoryDealGetTicket(i); if(d==0) continue;
      ENUM_DEAL_ENTRY e=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(d,DEAL_ENTRY);
      if(e==DEAL_ENTRY_OUT || e==DEAL_ENTRY_OUT_BY || e==DEAL_ENTRY_INOUT)
         pnl+=HistoryDealGetDouble(d,DEAL_PROFIT)+HistoryDealGetDouble(d,DEAL_COMMISSION)+HistoryDealGetDouble(d,DEAL_SWAP);
   }
   return pnl;
}

void AttachStrategyMetadataToOpenPositions()
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
      if(GVRead(PosKey(pid,"STRATEGY"),0)>0) continue;
      string sym=PositionGetString(POSITION_SYMBOL);
      datetime pt=(datetime)GVRead(SymKey(sym,"PLAN_STRAT_TIME"),0);
      if(pt<=0 || MathAbs((long)PositionGetInteger(POSITION_TIME)-(long)pt)>1200) continue;
      GVWrite(PosKey(pid,"STRATEGY"),GVRead(SymKey(sym,"PLAN_STRATEGY"),0));
      GVWrite(PosKey(pid,"MARKET_STATE"),GVRead(SymKey(sym,"PLAN_STATE"),0));
      GVWrite(PosKey(pid,"STRAT_DIR"),GVRead(SymKey(sym,"PLAN_DIR"),0));
      GVWrite(PosKey(pid,"STRAT_VOL"),GVRead(SymKey(sym,"PLAN_VOL"),1));
      GVWrite(PosKey(pid,"STRAT_SESSION"),GVRead(SymKey(sym,"PLAN_SESSION_HASH"),0));
   }
}

void FinalizeStrategyHistory()
{
   datetime now=TimeTradeServer();
   datetime from=now-MathMax(3,InpStrategyHistoryLookbackDays)*86400;
   if(!HistorySelect(from,now)) return;
   int n=HistoryDealsTotal();
   for(int i=MathMax(0,n-400);i<n;i++)
   {
      ulong deal=HistoryDealGetTicket(i); if(deal==0) continue;
      if((long)HistoryDealGetInteger(deal,DEAL_MAGIC)!=InpMagic) continue;
      ENUM_DEAL_ENTRY e=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal,DEAL_ENTRY);
      if(e!=DEAL_ENTRY_OUT && e!=DEAL_ENTRY_OUT_BY && e!=DEAL_ENTRY_INOUT) continue;
      ulong pid=(ulong)HistoryDealGetInteger(deal,DEAL_POSITION_ID);
      if(PositionIdStillOpenStrategy(pid) || GVRead(PosKey(pid,"STRAT_FINAL"),0)>0.5) continue;
      StrategyClass c=(StrategyClass)(int)GVRead(PosKey(pid,"STRATEGY"),0);
      if(c==STRATEGY_NO_TRADE) continue;

      bool quarantined=(GVRead(PosKey(pid,"LEARN_QUARANTINE"),0)>0.5 ||
                        GVRead(PosKey(pid,"MANUAL_INTERVENTION"),0)>0.5 ||
                        GVRead(PosKey(pid,"BROKER_ANOMALY"),0)>0.5 ||
                        GVRead(PosKey(pid,"CONNECTION_ANOMALY"),0)>0.5 ||
                        GVRead(PosKey(pid,"CHAOS_SAMPLE"),0)>0.5 ||
                        GVRead(PosKey(pid,"STORAGE_ANOMALY"),0)>0.5);
      int storedCfg=(int)GVRead(PosKey(pid,"CONFIG_HASH"),0);
      if(storedCfg>0 && storedCfg!=IntegrityTextHash(CurrentSensitiveConfigText())) quarantined=true;
      if(quarantined)
      {
         GVWrite(PosKey(pid,"STRAT_FINAL"),2);
         continue;
      }

      double risk=GVRead(PosKey(pid,"RISK"),0);
      double realized=StrategyPositionRealized(pid);
      double R=(risk>0?realized/risk:0);
      string p=SysKey(StringFormat("STRAT_%d",(int)c));
      UpdateStrategyBucket(p,R);
      int state=(int)GVRead(PosKey(pid,"MARKET_STATE"),0);
      UpdateStrategyBucket(SysKey(StringFormat("STRAT_%d_STATE_%d",(int)c,state)),R);
      int dir=(int)GVRead(PosKey(pid,"STRAT_DIR"),0);
      UpdateStrategyBucket(SysKey(StringFormat("STRAT_%d_DIR_%d",(int)c,dir)),R);
      int vol=(int)GVRead(PosKey(pid,"STRAT_VOL"),1);
      UpdateStrategyBucket(SysKey(StringFormat("STRAT_%d_VOL_%d",(int)c,vol)),R);
      GVWrite(PosKey(pid,"STRAT_FINAL"),1);
   }
}

bool StrategyExecutionTrigger(const TradeSetup &s,StrategyClass c)
{
   if(c==STRATEGY_COUNTER_TREND_SCALP || c==STRATEGY_COUNTER_TREND_SWING || c==STRATEGY_POTENTIAL_REVERSAL)
   {
      bool reject=M5RejectionAligned(s.symbol,s.bullish);
      bool bos=LowerTimeframeStructureBreak(s.symbol,s.bullish);
      bool sweep=LiquiditySweepAligned(s.symbol,s.bullish);
      return PriceInsideZone(s) && reject && bos && sweep;
   }
   if(c==STRATEGY_RANGE_TRADE || c==STRATEGY_MEAN_REVERSION)
      return PriceInsideZone(s) && M5RejectionAligned(s.symbol,s.bullish);
   if(c==STRATEGY_BREAKOUT)
   {
      // Direct breakout is a first-class execution path. It must never inherit
      // breakout-retest semantics from a legacy setup-kind value.
      if(s.kind!=SETUP_BREAKOUT) return false;
      return PriceInsideZone(s) && M5Trigger(s) && EMAImpulseAligned(s.symbol,s.bullish);
   }
   if(c==STRATEGY_BREAKOUT_RETEST)
   {
      if(s.kind!=SETUP_BREAKOUT_RETEST) return false;
      return PriceInsideZone(s) && M5Trigger(s);
   }
   return PriceInsideZone(s) && M5Trigger(s);
}

void SelectDynamicStrategy(const string sym,TradeSetup &pb,TradeSetup &br,StrategyDecision &d)
{
   ZeroMemory(d);
   d.strategy=STRATEGY_NO_TRADE; d.state=STATE_UNKNOWN; d.action=STRATEGY_ACTION_NO_TRADE;
   StrategySnapshot x; BuildStrategySnapshot(sym,x);
   d.state=x.state; d.regime=x.baseRegime; d.stateText=MarketStateName(x.state); d.session=x.session;

   int trendScore=StrategyBaseScore(x,STRATEGY_TREND_CONTINUATION);
   int retraceScore=StrategyBaseScore(x,STRATEGY_RETRACEMENT_ENTRY);
   int breakoutScore=StrategyBaseScore(x,STRATEGY_BREAKOUT);
   int brScore=StrategyBaseScore(x,STRATEGY_BREAKOUT_RETEST)+(br.valid?10:0);
   int reversalScore=StrategyBaseScore(x,STRATEGY_POTENTIAL_REVERSAL);
   int rangeScore=StrategyBaseScore(x,STRATEGY_RANGE_TRADE);
   int meanScore=StrategyBaseScore(x,STRATEGY_MEAN_REVERSION);
   bool counterBull=!x.dominantBull;
   int counterScore=CounterTrendScore(x,counterBull);
   d.counterTrendScore=counterScore;

   d.librarySummary=StringFormat("Library scores: trend %d | retracement %d | breakout %d | breakout-retest %d | reversal %d | range %d | mean-reversion %d | counter-trend %d",
                                  trendScore,retraceScore,breakoutScore,brScore,reversalScore,rangeScore,meanScore,counterScore);

   // Regime-driven selection. We intentionally do not force a setup when the regime and strategy disagree.
   if((x.state==STATE_REVERSAL || x.state==STATE_TREND_FAILURE) && reversalScore>=InpMinStrategyScore)
   {
      d.strategy=STRATEGY_POTENTIAL_REVERSAL; d.score=reversalScore; d.counterTrend=true;
      d.setup=BuildCounterTrendCandidate(x,counterBull,MathMax(reversalScore,counterScore),true);
   }
   else if((x.state==STATE_EXHAUSTION || x.state==STATE_FALSE_BREAKOUT || x.state==STATE_LIQUIDITY_SWEEP) &&
           InpAllowCounterTrendScalp && counterScore>=InpMinCounterTrendScore)
   {
      d.strategy=(InpAllowCounterTrendSwing && x.trendFailure?STRATEGY_COUNTER_TREND_SWING:STRATEGY_COUNTER_TREND_SCALP);
      d.score=counterScore; d.counterTrend=true;
      d.setup=BuildCounterTrendCandidate(x,counterBull,counterScore,d.strategy==STRATEGY_COUNTER_TREND_SWING);
   }
   else if((x.state==STATE_BREAKOUT || x.state==STATE_RANGE_EXPANSION || x.state==STATE_MOMENTUM_CONTINUATION) && breakoutScore>=InpMinStrategyScore)
   {
      d.strategy=(br.valid?STRATEGY_BREAKOUT_RETEST:STRATEGY_BREAKOUT); d.score=(br.valid?MathMax(brScore,breakoutScore):breakoutScore);
      d.setup=br;
      d.setup.name=StrategyClassName(d.strategy);
      if(d.strategy==STRATEGY_BREAKOUT && !br.valid)
      {
         d.setup.valid=false; // breakout identified, but do not chase it; wait for executable structure.
         d.setup.reason+=" | Breakout detected but entry is not authorized until a controlled retest/shallow execution structure appears.";
      }
   }
   else if((x.state==STATE_HEALTHY_RETRACEMENT || x.state==STATE_DEEP_RETRACEMENT || x.state==STATE_CORRECTION) && retraceScore>=InpMinStrategyScore)
   {
      d.strategy=STRATEGY_RETRACEMENT_ENTRY; d.score=retraceScore; d.setup=pb; d.setup.name=StrategyClassName(d.strategy);
   }
   else if((x.state==STATE_RANGE_REVERSAL || x.state==STATE_ACCUMULATION || x.state==STATE_DISTRIBUTION) && InpAllowRangeTrades && rangeScore>=InpMinStrategyScore)
   {
      d.strategy=STRATEGY_RANGE_TRADE; d.score=rangeScore; d.setup=BuildRangeCandidate(x,false);
   }
   else if((x.state==STATE_MEAN_REVERSION || x.state==STATE_CONSOLIDATION) && InpAllowMeanReversion && meanScore>=InpMinStrategyScore)
   {
      d.strategy=STRATEGY_MEAN_REVERSION; d.score=meanScore; d.setup=BuildRangeCandidate(x,true);
   }
   else if((x.state==STATE_TREND_CONTINUATION || x.state==STATE_MOMENTUM_CONTINUATION) && trendScore>=InpMinStrategyScore)
   {
      d.strategy=STRATEGY_TREND_CONTINUATION; d.score=trendScore; d.setup=(pb.valid?pb:br); d.setup.name=StrategyClassName(d.strategy);
   }
   else
   {
      d.strategy=STRATEGY_NO_TRADE; d.score=MathMax(MathMax(trendScore,retraceScore),MathMax(rangeScore,breakoutScore)); d.setup=(pb.confidence>=br.confidence?pb:br); d.setup.valid=false;
   }

   d.strategyName=StrategyClassName(d.strategy);
   d.counterTrend=(d.strategy==STRATEGY_COUNTER_TREND_SCALP || d.strategy==STRATEGY_COUNTER_TREND_SWING || d.strategy==STRATEGY_POTENTIAL_REVERSAL);
   d.rationale=StringFormat("State %s | regime %s | HTF bull %d/3 bear %d/3 | ADX %.1f | ATR %.2fx | OR %.2fx | overextension %.2f ATR | volume %.2fx. %s %s",
      d.stateText,x.baseRegime,x.bullVotes,x.bearVotes,x.adx,x.atrRatio,x.openingRangeRatio,x.overextensionATR,x.volumeRatio,
      FibRetracementText(x),SupplyDemandText(x));
   d.confirmation=(d.counterTrend?"Require liquidity rejection + M5 change of character/break of structure + rejection candle.":
                   (d.strategy==STRATEGY_RANGE_TRADE||d.strategy==STRATEGY_MEAN_REVERSION?"Require range-boundary rejection/reclaim; avoid mid-range entry.":
                    "Require price in zone plus strategy-aligned M5 confirmation; do not chase displacement."));
   d.counterargument=StringFormat("Opposing evidence: HTF opposite votes %d, trend strength ADX %.1f, false-break up/down %s/%s, exhaustion %s. Main risk is mistaking %s for a durable directional move.",
      x.dominantBull?x.bearVotes:x.bullVotes,x.adx,x.falseBreakUp?"YES":"NO",x.falseBreakDown?"YES":"NO",x.exhaustion?"YES":"NO",d.stateText);

   bool evidenceOK=StrategyEvidenceAllows(d.strategy,d.evidence);
   if(d.strategy==STRATEGY_NO_TRADE)
   {
      d.action=STRATEGY_ACTION_NO_TRADE; d.setup.valid=false;
   }
   else if(!evidenceOK)
   {
      d.action=STRATEGY_ACTION_NO_TRADE; d.setup.valid=false; d.rationale+=" | Historical/internal evidence gate rejected this strategy.";
   }
   else if(d.score<InpMinStrategyScore || !d.setup.valid)
   {
      d.action=STRATEGY_ACTION_WAIT;
   }
   else
   {
      d.action=STRATEGY_ACTION_HIGH_CONFIDENCE;
   }
   PersistStrategyCandidate(sym,d);
}

string StrategyDecisionHeader(const StrategyDecision &d)
{
   string action=(d.action==STRATEGY_ACTION_HIGH_CONFIDENCE?"HIGH-CONFIDENCE TRADE SETUP":d.action==STRATEGY_ACTION_WAIT?"WAIT FOR CONFIRMATION":"NO TRADE");
   string ct=d.counterTrend?"\n⚠️ COUNTER-TREND TRADE — stricter confirmation and conservative targets apply.":"";
   return "━━━━━━━━━━━━━━━━━━━━\n🧠 STRATEGY INTELLIGENCE\n━━━━━━━━━━━━━━━━━━━━\n"
          "Classification: "+d.strategyName+"\n"
          "Market state: "+d.stateText+"\n"
          "Regime: "+d.regime+"\n"
          "Session: "+d.session+"\n"
          "Decision: "+action+ct+"\n"
          "Strategy score: "+IntegerToString(d.score)+"/100\n"
          "Counter-trend score: "+IntegerToString(d.counterTrendScore)+"/100\n"
          +d.librarySummary+"\n"+d.evidence+"\n";
}

bool RevalidateStrategyIdentity(const TradeSetup &stored,string &why)
{
   TradeSetup pb=BuildPullback(stored.symbol,stored.bullish,stored.confidence,"");
   TradeSetup br=BuildBreakoutRetest(stored.symbol,stored.bullish,stored.confidence,"");
   StrategyDecision d; SelectDynamicStrategy(stored.symbol,pb,br,d);
   StrategyClass expected=(StrategyClass)(int)GVRead(SymKey(stored.symbol,"CAND_STRATEGY"),STRATEGY_NO_TRADE);
   if(d.strategy==STRATEGY_NO_TRADE || d.action==STRATEGY_ACTION_NO_TRADE)
   { why="Strategy engine now classifies the market as NO TRADE."; return false; }
   if(d.setup.bullish!=stored.bullish)
   { why="Strategy engine direction changed during revalidation."; return false; }
   if(expected!=STRATEGY_NO_TRADE && d.strategy!=expected)
   { why="Strategy classification changed from "+StrategyClassName(expected)+" to "+StrategyClassName(d.strategy)+"."; return false; }
   why="Strategy identity remains valid: "+d.strategyName+" / "+d.stateText+".";
   return true;
}

void StrategyIntelligenceInit()
{
   AttachStrategyMetadataToOpenPositions();
   FinalizeStrategyHistory();
}

void StrategyIntelligenceTimer()
{
   AttachStrategyMetadataToOpenPositions();
   FinalizeStrategyHistory();
}
// GPT_EA Part 15B - Named strategy framework library

string SelectedStrategyFramework(const StrategySnapshot &x,StrategyClass c)
{
   bool nearPDH=(x.previousDayHigh>0 && x.atr>0 && MathAbs(x.mid-x.previousDayHigh)<=0.35*x.atr);
   bool nearPDL=(x.previousDayLow>0 && x.atr>0 && MathAbs(x.mid-x.previousDayLow)<=0.35*x.atr);
   bool nearAsianH=(x.asianHigh>-1.0e90 && x.atr>0 && MathAbs(x.mid-x.asianHigh)<=0.35*x.atr);
   bool nearAsianL=(x.asianLow<1.0e90 && x.atr>0 && MathAbs(x.mid-x.asianLow)<=0.35*x.atr);
   bool london=(x.session=="LONDON" || x.session=="LONDON_PREOPEN" || x.session=="LONDON_NY_OVERLAP");
   bool ny=(x.session=="NEW_YORK_OPEN" || x.session=="NEW_YORK_PREOPEN" || x.session=="LONDON_NY_OVERLAP");

   if(c==STRATEGY_TREND_CONTINUATION)
   {
      if(x.state==STATE_MOMENTUM_CONTINUATION) return "Momentum Continuation / Volatility Expansion";
      if(x.dominantBull?x.m15BullStructure:x.m15BearStructure) return "Higher-High/Higher-Low or Lower-High/Lower-Low Continuation";
      return "Multi-Timeframe Trend Alignment / Dynamic EMA Support-Resistance";
   }
   if(c==STRATEGY_RETRACEMENT_ENTRY)
   {
      if((x.bullishSweep||x.bearishSweep)) return "Liquidity-Sweep Retracement into Structure";
      if(nearPDH||nearPDL) return "Previous-Day Structure Retracement";
      if(MathAbs(x.mid-x.ema20)<=0.35*x.atr || MathAbs(x.mid-x.ema50)<=0.35*x.atr) return "Moving-Average / Dynamic-Support Retracement";
      return "Fibonacci 38.2-61.8% + Previous Breakout Structure Retracement";
   }
   if(c==STRATEGY_BREAKOUT || c==STRATEGY_BREAKOUT_RETEST)
   {
      if(london && (nearAsianH||nearAsianL)) return (c==STRATEGY_BREAKOUT?"London Open / Asian-Range Breakout":"London Open / Asian-Range Breakout-Retest");
      if(london && (x.bullishSweep||x.bearishSweep)) return "London Liquidity Sweep then Breakout-Retest";
      if(ny && x.openingRangeRatio>0.5) return (c==STRATEGY_BREAKOUT?"New York / U.S. Cash Opening-Range Breakout":"U.S. Cash Opening-Range Breakout-Retest");
      if(nearPDH||nearPDL) return "Previous-Day High/Low Breakout-Retest";
      if(x.expansion) return "Consolidation / Volatility-Expansion Breakout";
      return "Support/Resistance Breakout and Retest";
   }
   if(c==STRATEGY_COUNTER_TREND_SCALP || c==STRATEGY_COUNTER_TREND_SWING || c==STRATEGY_POTENTIAL_REVERSAL)
   {
      if(x.falseBreakUp||x.falseBreakDown) return "Failed Breakout / Liquidity Sweep Reversal";
      if(x.doubleTop||x.doubleBottom) return "Double Top/Bottom + Structural Confirmation";
      if(x.exhaustion && (x.bullishDivergence||x.bearishDivergence)) return "Exhaustion + Momentum Divergence + CHOCH";
      if(london && (x.bullishSweep||x.bearishSweep)) return "London Liquidity Sweep Reversal";
      if(ny && (x.bullishSweep||x.bearishSweep)) return "U.S. Cash-Session Sweep/Reversal";
      return "Major Support/Resistance Rejection + Change of Character / Break of Structure";
   }
   if(c==STRATEGY_RANGE_TRADE)
   {
      if(x.falseBreakUp||x.falseBreakDown) return "Failed Range Breakout / Range Reversal";
      if(london||ny) return "Session-Range Boundary Reversal";
      return "Range Support Buy / Range Resistance Sell";
   }
   if(c==STRATEGY_MEAN_REVERSION)
      return "Mean Reversion Toward Range Equilibrium / VWAP";
   return "No executable framework";
}

void EnrichStrategyDecision(const string sym,StrategyDecision &d)
{
   StrategySnapshot x; BuildStrategySnapshot(sym,x);
   string framework=SelectedStrategyFramework(x,d.strategy);
   if(d.strategy!=STRATEGY_NO_TRADE)
   {
      d.strategyName=StrategyClassName(d.strategy)+" — "+framework;
      d.rationale+=" | Framework: "+framework+".";
      if(StringFind(framework,"Fibonacci")>=0) d.confirmation+=" Confirm price is reacting within the measured 38.2-61.8% retracement/value zone.";
      if(StringFind(framework,"Opening-Range")>=0) d.confirmation+=" Require a completed opening-range break and controlled hold/retest; opening volatility alone is not confirmation.";
      if(StringFind(framework,"Liquidity Sweep")>=0) d.confirmation+=" Require the swept level to be reclaimed/rejected before entry.";
      if(StringFind(framework,"Previous-Day")>=0) d.confirmation+=" Treat the previous-day high/low as a liquidity level and require acceptance/rejection appropriate to the strategy.";
   }
}

void SelectDynamicStrategyEnriched(const string sym,TradeSetup &pb,TradeSetup &br,StrategyDecision &d)
{
   SelectDynamicStrategy(sym,pb,br,d);
   EnrichStrategyDecision(sym,d);
   PersistStrategyCandidate(sym,d);
}
// GPT_EA Part 15C - Strategy context analytics (session/timeframe/news)

input int InpStrategyNewsContextMinutes = 120;

int StrategySessionCode(const string s)
{
   if(s=="ASIAN") return 1;
   if(s=="LONDON_PREOPEN") return 2;
   if(s=="LONDON") return 3;
   if(s=="LONDON_NY_OVERLAP") return 4;
   if(s=="NEW_YORK_PREOPEN") return 5;
   if(s=="NEW_YORK_OPEN") return 6;
   return 7;
}

bool HighImpactEventWithin(const string sym,int minutes)
{
   if(!InpUseEconomicCalendar || (bool)MQLInfoInteger(MQL_TESTER)) return false;
   string ccy=RelatedCurrencies(sym); if(ccy=="") return false;
   string arr[]; int nc=StringSplit(ccy,',',arr);
   datetime now=TimeTradeServer(),from=now-MathMax(1,minutes)*60,to=now+MathMax(1,minutes)*60;
   for(int c=0;c<nc;c++)
   {
      MqlCalendarValue vals[]; int n=CalendarValueHistory(vals,from,to,NULL,arr[c]);
      if(n<=0) continue;
      for(int i=0;i<n;i++)
      {
         MqlCalendarEvent ev={};
         if(CalendarEventById(vals[i].event_id,ev) && ev.importance==CALENDAR_IMPORTANCE_HIGH) return true;
      }
   }
   return false;
}

void PersistStrategyPlanForExecutionFull(const TradeSetup &s)
{
   PersistStrategyPlanForExecution(s);
   StrategySnapshot x; BuildStrategySnapshot(s.symbol,x);
   GVWrite(SymKey(s.symbol,"PLAN_SESSION_CODE"),StrategySessionCode(x.session));
   GVWrite(SymKey(s.symbol,"PLAN_SETUP_TF"),15);  // current strategy construction timeframe
   GVWrite(SymKey(s.symbol,"PLAN_EXEC_TF"),5);    // current execution confirmation timeframe
   GVWrite(SymKey(s.symbol,"PLAN_NEWS_CONTEXT"),HighImpactEventWithin(s.symbol,InpStrategyNewsContextMinutes)?1:0);
}

void AttachStrategyContextMetadata()
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
      string sym=PositionGetString(POSITION_SYMBOL);
      datetime pt=(datetime)GVRead(SymKey(sym,"PLAN_STRAT_TIME"),0);
      if(pt<=0 || MathAbs((long)PositionGetInteger(POSITION_TIME)-(long)pt)>1200) continue;
      if(GVRead(PosKey(pid,"STRAT_SESSION_CODE"),0)<=0) GVWrite(PosKey(pid,"STRAT_SESSION_CODE"),GVRead(SymKey(sym,"PLAN_SESSION_CODE"),7));
      if(GVRead(PosKey(pid,"STRAT_SETUP_TF"),0)<=0) GVWrite(PosKey(pid,"STRAT_SETUP_TF"),GVRead(SymKey(sym,"PLAN_SETUP_TF"),15));
      if(GVRead(PosKey(pid,"STRAT_EXEC_TF"),0)<=0) GVWrite(PosKey(pid,"STRAT_EXEC_TF"),GVRead(SymKey(sym,"PLAN_EXEC_TF"),5));
      if(!GlobalVariableCheck(PosKey(pid,"STRAT_NEWS_CONTEXT"))) GVWrite(PosKey(pid,"STRAT_NEWS_CONTEXT"),GVRead(SymKey(sym,"PLAN_NEWS_CONTEXT"),0));
   }
}

void FinalizeStrategyContextHistory()
{
   datetime now=TimeTradeServer(),from=now-MathMax(3,InpStrategyHistoryLookbackDays)*86400;
   if(!HistorySelect(from,now)) return;
   int n=HistoryDealsTotal();
   for(int i=MathMax(0,n-400);i<n;i++)
   {
      ulong deal=HistoryDealGetTicket(i); if(deal==0) continue;
      if((long)HistoryDealGetInteger(deal,DEAL_MAGIC)!=InpMagic) continue;
      ENUM_DEAL_ENTRY e=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal,DEAL_ENTRY);
      if(e!=DEAL_ENTRY_OUT && e!=DEAL_ENTRY_OUT_BY && e!=DEAL_ENTRY_INOUT) continue;
      ulong pid=(ulong)HistoryDealGetInteger(deal,DEAL_POSITION_ID);
      if(PositionIdentifierOpen(pid) || GVRead(PosKey(pid,"STRAT_CONTEXT_FINAL"),0)>0.5) continue;
      int cls=(int)GVRead(PosKey(pid,"STRATEGY"),0); if(cls<=0) continue;
      double risk=GVRead(PosKey(pid,"RISK"),0); if(risk<=0) continue;
      double R=StrategyPositionRealized(pid)/risk;
      int ses=(int)GVRead(PosKey(pid,"STRAT_SESSION_CODE"),7);
      int stf=(int)GVRead(PosKey(pid,"STRAT_SETUP_TF"),15);
      int etf=(int)GVRead(PosKey(pid,"STRAT_EXEC_TF"),5);
      int news=(int)GVRead(PosKey(pid,"STRAT_NEWS_CONTEXT"),0);
      UpdateStrategyBucket(SysKey(StringFormat("STRAT_%d_SESSION_%d",cls,ses)),R);
      UpdateStrategyBucket(SysKey(StringFormat("STRAT_%d_TF_%d_%d",cls,stf,etf)),R);
      UpdateStrategyBucket(SysKey(StringFormat("STRAT_%d_NEWS_%d",cls,news)),R);
      GVWrite(PosKey(pid,"STRAT_CONTEXT_FINAL"),1);
   }
}

void StrategyIntelligenceInitFull()
{
   StrategyIntelligenceInit();
   AttachStrategyContextMetadata();
   FinalizeStrategyContextHistory();
}

void StrategyIntelligenceTimerFull()
{
   StrategyIntelligenceTimer();
   AttachStrategyContextMetadata();
   FinalizeStrategyContextHistory();
}
// GPT_EA Part 20 - Realistic execution-cost and partial-profit R:R model

input bool   InpUseHistoricalCommissionEstimate = true;
input double InpFallbackCommissionPerLotRoundTurn = 0.0; // account currency per 1.0 lot round turn
input int    InpCommissionHistoryDays = 30;
input int    InpCommissionMinDeals    = 6;

struct RealisticRRReport
{
   double grossRiskMoney;
   double modeledSpreadSlipMoney;
   double commissionMoney;
   double totalRiskMoney;
   double weightedRewardMoney;
   double rr;
   string detail;
};

double EstimateCommissionPerLotRoundTurn(const string sym)
{
   if(!InpUseHistoricalCommissionEstimate) return MathMax(0.0,InpFallbackCommissionPerLotRoundTurn);
   datetime now=TimeTradeServer(),from=now-MathMax(1,InpCommissionHistoryDays)*86400;
   if(!HistorySelect(from,now)) return MathMax(0.0,InpFallbackCommissionPerLotRoundTurn);
   double commission=0,volume=0; int deals=0;
   int n=HistoryDealsTotal();
   for(int i=MathMax(0,n-1000);i<n;i++)
   {
      ulong d=HistoryDealGetTicket(i); if(d==0) continue;
      if(HistoryDealGetString(d,DEAL_SYMBOL)!=sym) continue;
      ENUM_DEAL_TYPE type=(ENUM_DEAL_TYPE)HistoryDealGetInteger(d,DEAL_TYPE);
      if(type!=DEAL_TYPE_BUY && type!=DEAL_TYPE_SELL) continue;
      double v=HistoryDealGetDouble(d,DEAL_VOLUME); if(v<=0) continue;
      double c=MathAbs(HistoryDealGetDouble(d,DEAL_COMMISSION));
      if(c<=0) continue;
      commission+=c; volume+=v; deals++;
   }
   if(deals<InpCommissionMinDeals || volume<=0) return MathMax(0.0,InpFallbackCommissionPerLotRoundTurn);
   // History usually records commission per side/deal. Double the per-side average to estimate round turn.
   return 2.0*commission/volume;
}

double OneLotProfitBetween(const string sym,bool bull,double from,double to)
{
   double p=0; ENUM_ORDER_TYPE ot=(bull?ORDER_TYPE_BUY:ORDER_TYPE_SELL);
   if(!OrderCalcProfit(ot,sym,1.0,from,to,p)) return 0;
   return p;
}

RealisticRRReport RealisticRiskReward(const TradeSetup &s)
{
   RealisticRRReport r; ZeroMemory(r); r.detail="";
   MqlTick t={}; if(!GetTickSafe(s.symbol,t)){ r.detail="No live tick."; return r; }
   double pt=PointFor(s.symbol); if(pt<=0){ r.detail="No point size."; return r; }

   double entry=s.preferred;
   double spread=MathMax(0.0,t.ask-t.bid);
   double slip=DynamicSlippagePoints(s.symbol)*pt;
   double modeledEntry=(s.bullish?entry+spread+slip:entry-spread-slip);
   double riskPnl=OneLotProfitBetween(s.symbol,s.bullish,modeledEntry,s.sl);
   r.grossRiskMoney=MathAbs(riskPnl);

   double rawRiskPnl=OneLotProfitBetween(s.symbol,s.bullish,entry,s.sl);
   r.modeledSpreadSlipMoney=MathMax(0.0,r.grossRiskMoney-MathAbs(rawRiskPnl));
   r.commissionMoney=EstimateCommissionPerLotRoundTurn(s.symbol);
   r.totalRiskMoney=r.grossRiskMoney+r.commissionMoney;

   double f1=MathMax(0.0,MathMin(1.0,InpPartialAtTP1Percent/100.0));
   double remain1=1.0-f1;
   double f2=MathMax(0.0,MathMin(1.0,InpPartialAtTP2Percent/100.0))*remain1;
   double f3=MathMax(0.0,1.0-f1-f2);

   double p1=MathMax(0.0,OneLotProfitBetween(s.symbol,s.bullish,modeledEntry,s.tp1));
   double p2=MathMax(0.0,OneLotProfitBetween(s.symbol,s.bullish,modeledEntry,s.tp2));
   double p3=MathMax(0.0,OneLotProfitBetween(s.symbol,s.bullish,modeledEntry,s.tp3));
   r.weightedRewardMoney=f1*p1+f2*p2+f3*p3-r.commissionMoney;
   if(r.weightedRewardMoney<0) r.weightedRewardMoney=0;
   r.rr=(r.totalRiskMoney>0?r.weightedRewardMoney/r.totalRiskMoney:0);
   r.detail=StringFormat("Realistic weighted R:R %.2f | 1-lot modeled risk %.2f | spread/slippage cost %.2f | commission %.2f | weighted reward %.2f | partial weights TP1 %.0f%% / TP2 %.0f%% / runner %.0f%%",
      r.rr,r.totalRiskMoney,r.modeledSpreadSlipMoney,r.commissionMoney,r.weightedRewardMoney,f1*100.0,f2*100.0,f3*100.0);
   return r;
}

double EffectiveRRFullRatio(const TradeSetup &s)
{
   return RealisticRiskReward(s).rr;
}

bool RealisticRRGate(const TradeSetup &s,double floor,string &why)
{
   RealisticRRReport r=RealisticRiskReward(s);
   why=r.detail;
   return r.rr>=floor;
}
// GPT_EA Part 15D - Structure/liquidity-aware target refinement

void AddObjective(double &arr[],const string sym,double v,double entry,bool bull)
{
   if(v<=0) return;
   if((bull && v<=entry) || (!bull && v>=entry)) return;
   double tol=MathMax(PointFor(sym)*2.0,SymbolInfoDouble(sym,SYMBOL_TRADE_TICK_SIZE));
   for(int i=0;i<ArraySize(arr);i++) if(MathAbs(arr[i]-v)<=tol) return;
   int n=ArraySize(arr); ArrayResize(arr,n+1); arr[n]=v;
}

void SortObjectives(double &arr[],bool bull)
{
   int n=ArraySize(arr);
   for(int i=0;i<n-1;i++) for(int j=i+1;j<n;j++)
   {
      bool swap=(bull?arr[j]<arr[i]:arr[j]>arr[i]);
      if(swap){ double t=arr[i]; arr[i]=arr[j]; arr[j]=t; }
   }
}

void RefineTargetsToStructure(TradeSetup &s)
{
   if(s.preferred<=0 || s.sl<=0) return;
   StrategySnapshot x; BuildStrategySnapshot(s.symbol,x);
   double R=MathAbs(s.preferred-s.sl); if(R<=0) return;
   double objs[];
   AddObjective(objs,s.symbol,x.priorHigh,s.preferred,s.bullish);
   AddObjective(objs,s.symbol,x.priorLow,s.preferred,s.bullish);
   AddObjective(objs,s.symbol,x.previousDayHigh,s.preferred,s.bullish);
   AddObjective(objs,s.symbol,x.previousDayLow,s.preferred,s.bullish);
   AddObjective(objs,s.symbol,x.asianHigh,s.preferred,s.bullish);
   AddObjective(objs,s.symbol,x.asianLow,s.preferred,s.bullish);
   SortObjectives(objs,s.bullish);

   double fallback1=(s.bullish?s.preferred+R:s.preferred-R);
   double fallback2=(s.bullish?s.preferred+2.0*R:s.preferred-2.0*R);
   double fallback3=(s.bullish?s.preferred+3.0*R:s.preferred-3.0*R);
   double chosen1=0,chosen2=0,chosen3=0;
   for(int i=0;i<ArraySize(objs);i++)
   {
      double rr=MathAbs(objs[i]-s.preferred)/R;
      if(chosen1==0 && rr>=0.70) { chosen1=objs[i]; continue; }
      if(chosen2==0 && rr>=1.25 && MathAbs(objs[i]-chosen1)>0.20*R) { chosen2=objs[i]; continue; }
      if(chosen3==0 && rr>=1.80 && MathAbs(objs[i]-(chosen2>0?chosen2:chosen1))>0.20*R) { chosen3=objs[i]; break; }
   }
   if(chosen1==0) chosen1=fallback1;
   if(chosen2==0) chosen2=fallback2;
   if(chosen3==0) chosen3=fallback3;

   bool counter=(StringFind(s.name,"COUNTER-TREND")>=0 || StringFind(s.name,"POTENTIAL REVERSAL")>=0);
   if(counter)
   {
      if(s.bullish){ chosen1=MathMin(chosen1,s.tp1); chosen2=MathMin(chosen2,s.tp2); chosen3=MathMin(chosen3,s.tp3); }
      else { chosen1=MathMax(chosen1,s.tp1); chosen2=MathMax(chosen2,s.tp2); chosen3=MathMax(chosen3,s.tp3); }
   }

   s.tp1=NormalizePriceToTick(s.symbol,chosen1);
   s.tp2=NormalizePriceToTick(s.symbol,chosen2);
   s.tp3=NormalizePriceToTick(s.symbol,chosen3);
   s.nominalRR1=MathAbs(s.tp1-s.preferred)/R;
   s.effectiveRR1=EffectiveRRDynamic(s);
   s.reason+=StringFormat(" | Structure/liquidity targets refined to TP1 %.5f, TP2 %.5f, TP3 %.5f from swing/previous-day/Asian objectives with measured-R fallback.",s.tp1,s.tp2,s.tp3);
}

void SelectDynamicStrategyComplete(const string sym,TradeSetup &pb,TradeSetup &br,StrategyDecision &d)
{
   SelectDynamicStrategyEnriched(sym,pb,br,d);
   if(d.strategy!=STRATEGY_NO_TRADE && d.setup.preferred>0)
   {
      RefineTargetsToStructure(d.setup);
      string ev="";
      if(!StrategyEvidenceAllows(d.strategy,ev)){ d.action=STRATEGY_ACTION_NO_TRADE; d.setup.valid=false; }
      d.evidence=ev;
   }
   PersistStrategyCandidate(sym,d);
}
// GPT_EA Part 21 - Research validation, context evidence and retracement logic

input bool   InpUseContextualEvidenceGate       = true;
input int    InpContextEvidenceMinTrades        = 8;
input double InpContextEvidenceMinProfitFactor  = 0.90;
input double InpContextEvidenceMinAverageR      = -0.05;
input bool   InpUseWalkForwardValidation        = true;
input int    InpWalkForwardMinTrades            = 12;
input double InpWalkForwardRecentFraction       = 0.35;
input double InpWalkForwardMinRecentPF          = 0.90;
input double InpWalkForwardMinRecentAverageR    = -0.05;
input bool   InpBlockNegativeWalkForward        = true;
input double InpChaseOverextensionATR           = 1.25;
input bool   InpBlockExtremeRegimes             = true;
input double InpExtremeATRRatioHigh             = 2.50;
input double InpExtremeATRRatioLow              = 0.35;
input double InpExtremeOpeningRangeRatio        = 3.00;

void StrategyBucketMetrics(const string key,double &n,double &wr,double &avg,double &pf,double &dd,double &maxLosses)
{
   n=GVRead(key+"_N",0);
   double wins=GVRead(key+"_WIN",0),sum=GVRead(key+"_SUMR",0);
   double pos=GVRead(key+"_POSR",0),neg=GVRead(key+"_NEGR",0);
   dd=GVRead(key+"_MAXDD",0); maxLosses=GVRead(key+"_MAXLOSSRUN",0);
   wr=(n>0?wins/n*100.0:0.0);
   avg=(n>0?sum/n:0.0);
   pf=(neg>0?pos/neg:(pos>0?99.0:0.0));
}

bool ContextBucketAllows(const string key,const string label,string &line)
{
   double n=0,wr=0,avg=0,pf=0,dd=0,ml=0;
   StrategyBucketMetrics(key,n,wr,avg,pf,dd,ml);
   line=StringFormat("%s N %.0f | win %.1f%% | avg %.2fR | PF %.2f | DD %.2fR | maxL %.0f",label,n,wr,avg,pf,dd,ml);
   if(!InpUseContextualEvidenceGate || n<InpContextEvidenceMinTrades)
   {
      line+=(n<InpContextEvidenceMinTrades?" | developing sample":" | informational only");
      return true;
   }
   bool ok=(avg>=InpContextEvidenceMinAverageR && pf>=InpContextEvidenceMinProfitFactor);
   line+=(ok?" | PASS":" | BLOCK: negative current-context evidence");
   return ok;
}

string CurrentStrategyContextEvidence(const string sym,StrategyClass c,bool directionBull,bool &allows)
{
   allows=true;
   if(c==STRATEGY_NO_TRADE) return "Context evidence: no executable strategy.";
   StrategySnapshot x; BuildStrategySnapshot(sym,x);
   int cls=(int)c;
   int dir=(directionBull?1:0);
   int vol=(x.atrRatio>=1.35?2:(x.atrRatio<=0.75?0:1));
   int ses=StrategySessionCode(x.session);
   int news=(HighImpactEventWithin(sym,InpStrategyNewsContextMinutes)?1:0);
   string a="",b="",d="",e="",f="";
   bool okDir=ContextBucketAllows(SysKey(StringFormat("STRAT_%d_DIR_%d",cls,dir)),directionBull?"LONG":"SHORT",a);
   bool okVol=ContextBucketAllows(SysKey(StringFormat("STRAT_%d_VOL_%d",cls,vol)),vol==2?"HIGH-VOL":vol==0?"LOW-VOL":"NORMAL-VOL",b);
   bool okSes=ContextBucketAllows(SysKey(StringFormat("STRAT_%d_SESSION_%d",cls,ses)),"SESSION "+x.session,d);
   bool okTF=ContextBucketAllows(SysKey(StringFormat("STRAT_%d_TF_%d_%d",cls,15,5)),"TF M15/M5",e);
   bool okNews=ContextBucketAllows(SysKey(StringFormat("STRAT_%d_NEWS_%d",cls,news)),news?"NEAR-HIGH-IMPACT":"NO-NEAR-HIGH-IMPACT",f);
   allows=(okDir && okVol && okSes && okTF && okNews);
   return "Context evidence: "+a+" | "+b+" | "+d+" | "+e+" | "+f;
}

void RSegmentStats(double &arr[],int from,int to,double &avg,double &pf)
{
   avg=0; pf=0;
   if(from<0) from=0;
   if(to>ArraySize(arr)) to=ArraySize(arr);
   int n=to-from; if(n<=0) return;
   double pos=0,neg=0,sum=0;
   for(int i=from;i<to;i++)
   {
      double r=arr[i]; sum+=r;
      if(r>0) pos+=r; else if(r<0) neg+=-r;
   }
   avg=sum/n;
   pf=(neg>0?pos/neg:(pos>0?99.0:0.0));
}

bool StrategyWalkForwardEvidence(StrategyClass c,string &detail)
{
   detail="Walk-forward: disabled.";
   if(!InpUseWalkForwardValidation || c==STRATEGY_NO_TRADE) return true;
   datetime now=TimeTradeServer(),from=now-MathMax(10,InpStrategyHistoryLookbackDays)*86400;
   if(!HistorySelect(from,now)){ detail="Walk-forward: history unavailable; neutral."; return true; }

   ulong pids[]; datetime closes[];
   int total=HistoryDealsTotal();
   for(int i=0;i<total;i++)
   {
      ulong deal=HistoryDealGetTicket(i); if(deal==0) continue;
      if((long)HistoryDealGetInteger(deal,DEAL_MAGIC)!=InpMagic) continue;
      ENUM_DEAL_ENTRY en=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal,DEAL_ENTRY);
      if(en!=DEAL_ENTRY_OUT && en!=DEAL_ENTRY_OUT_BY && en!=DEAL_ENTRY_INOUT) continue;
      ulong pid=(ulong)HistoryDealGetInteger(deal,DEAL_POSITION_ID);
      if((int)GVRead(PosKey(pid,"STRATEGY"),0)!=(int)c) continue;
      datetime tm=(datetime)HistoryDealGetInteger(deal,DEAL_TIME);
      int at=-1;
      for(int j=0;j<ArraySize(pids);j++) if(pids[j]==pid){ at=j; break; }
      if(at<0)
      {
         int n=ArraySize(pids); ArrayResize(pids,n+1); ArrayResize(closes,n+1);
         pids[n]=pid; closes[n]=tm;
      }
      else if(tm>closes[at]) closes[at]=tm;
   }

   double rs[]; datetime ts[];
   for(int i=0;i<ArraySize(pids);i++)
   {
      double risk=GVRead(PosKey(pids[i],"RISK"),0); if(risk<=0) continue;
      double r=StrategyPositionRealized(pids[i])/risk;
      int n=ArraySize(rs); ArrayResize(rs,n+1); ArrayResize(ts,n+1);
      rs[n]=r; ts[n]=closes[i];
   }
   int n=ArraySize(rs);
   if(n<InpWalkForwardMinTrades)
   {
      detail=StringFormat("Walk-forward: N %d below minimum %d; developing sample, not proof of edge.",n,InpWalkForwardMinTrades);
      return true;
   }

   for(int i=0;i<n-1;i++) for(int j=i+1;j<n;j++) if(ts[j]<ts[i])
   {
      datetime tt=ts[i]; ts[i]=ts[j]; ts[j]=tt;
      double rr=rs[i]; rs[i]=rs[j]; rs[j]=rr;
   }
   double frac=MathMax(0.20,MathMin(0.50,InpWalkForwardRecentFraction));
   int recentN=(int)MathRound(n*frac); if(recentN<3) recentN=3; if(recentN>=n) recentN=n-1;
   int split=n-recentN;
   double trainAvg=0,trainPF=0,recentAvg=0,recentPF=0;
   RSegmentStats(rs,0,split,trainAvg,trainPF);
   RSegmentStats(rs,split,n,recentAvg,recentPF);
   bool recentOK=(recentAvg>=InpWalkForwardMinRecentAverageR && recentPF>=InpWalkForwardMinRecentPF);
   bool drift=(trainAvg>0 && trainPF>=1.0 && (recentAvg<0 || recentPF<1.0));
   detail=StringFormat("Walk-forward N %d | train N %d avg %.2fR PF %.2f | recent N %d avg %.2fR PF %.2f | drift %s",
                       n,split,trainAvg,trainPF,recentN,recentAvg,recentPF,drift?"YES":"NO");
   if(InpBlockNegativeWalkForward && !recentOK)
   {
      detail+=" | BLOCK: recent out-of-sample segment below configured thresholds.";
      return false;
   }
   detail+=" | PASS; historical results remain non-guaranteed evidence.";
   return true;
}

bool RecentMoveImpulsiveAgainstTrend(const StrategySnapshot &x,double &netATR,double &bodyATR,int &directionalBars)
{
   netATR=0; bodyATR=0; directionalBars=0;
   if(x.atr<=0) return false;
   MqlRates r[]; ArraySetAsSeries(r,true);
   if(CopyRates(x.symbol,PERIOD_M15,1,4,r)<3) return false;
   double start=r[2].open,end=r[0].close;
   netATR=MathAbs(end-start)/x.atr;
   for(int i=0;i<3;i++)
   {
      bodyATR+=MathAbs(r[i].close-r[i].open)/x.atr;
      bool against=(x.dominantBull?r[i].close<r[i].open:r[i].close>r[i].open);
      if(against) directionalBars++;
   }
   bool directionAgainst=(x.dominantBull?end<start:end>start);
   return (directionAgainst && netATR>=1.10 && bodyATR>=1.35 && directionalBars>=2 && x.volumeRatio>=1.05);
}

void ConsiderRetracementDestination(const StrategySnapshot &x,double v,const string label,double &best,string &bestLabel)
{
   if(v<=0 || x.atr<=0) return;
   if(x.dominantBull)
   {
      if(v>x.mid+0.10*x.atr) return;
      if(best<=0 || v>best){ best=v; bestLabel=label; }
   }
   else
   {
      if(v<x.mid-0.10*x.atr) return;
      if(best<=0 || v<best){ best=v; bestLabel=label; }
   }
}

string RetracementDestinationText(const StrategySnapshot &x)
{
   double best=0; string label="";
   double w=x.priorHigh-x.priorLow;
   double f382=0,f618=0;
   if(w>0)
   {
      f382=(x.dominantBull?x.priorHigh-0.382*w:x.priorLow+0.382*w);
      f618=(x.dominantBull?x.priorHigh-0.618*w:x.priorLow+0.618*w);
   }
   ConsiderRetracementDestination(x,x.ema20,"EMA20 / dynamic value",best,label);
   ConsiderRetracementDestination(x,x.ema50,"EMA50 / deep value",best,label);
   ConsiderRetracementDestination(x,IntradayVWAP(x.symbol),"rolling VWAP",best,label);
   ConsiderRetracementDestination(x,x.dominantBull?x.priorLow:x.priorHigh,"prior swing structure",best,label);
   ConsiderRetracementDestination(x,x.dominantBull?x.previousDayLow:x.previousDayHigh,"previous-day structure",best,label);
   ConsiderRetracementDestination(x,x.dominantBull?x.asianLow:x.asianHigh,"Asian-session liquidity",best,label);
   ConsiderRetracementDestination(x,f382,"38.2% retracement",best,label);
   ConsiderRetracementDestination(x,f618,"61.8% retracement",best,label);
   if(best<=0) return "Likely retracement destination: no clean nearby value level; wait for structure rather than guessing.";
   return StringFormat("Likely retracement destination: %s around %.*f, subject to fresh structure/liquidity confirmation.",label,DigitsFor(x.symbol),best);
}

bool ChaseRiskDetected(const StrategySnapshot &x)
{
   bool stretched=(MathAbs(x.overextensionATR)>=InpChaseOverextensionATR);
   bool stretchedWithTrend=(x.dominantBull?x.overextensionATR>0:x.overextensionATR<0);
   return stretched && stretchedWithTrend &&
          (x.state==STATE_TREND_CONTINUATION || x.state==STATE_MOMENTUM_CONTINUATION || x.state==STATE_BREAKOUT || x.state==STATE_RANGE_EXPANSION);
}

string RetracementIntelligenceText(const StrategySnapshot &x)
{
   double net=0,bodies=0; int bars=0;
   bool impulsive=RecentMoveImpulsiveAgainstTrend(x,net,bodies,bars);
   bool intact=!x.trendFailure;
   int ct=CounterTrendScore(x,!x.dominantBull);
   string reversal=(x.dominantBull?
      StringFormat("A genuine bearish reversal requires acceptance below key swing support near %.*f plus sustained opposite M15/M5 structure/CHOCH.",DigitsFor(x.symbol),x.priorLow):
      StringFormat("A genuine bullish reversal requires acceptance above key swing resistance near %.*f plus sustained opposite M15/M5 structure/CHOCH.",DigitsFor(x.symbol),x.priorHigh));
   string counter=(ct>=InpMinCounterTrendScore?"A short-term counter-trend opportunity is conditionally present, but still requires the strict sweep + BOS/CHOCH + rejection trigger.":"Counter-trend evidence is below the strict threshold; do not trade the correction merely because it moves against trend.");
   return StringFormat("Retracement intelligence: current against-trend move is %s (net %.2f ATR, bodies %.2f ATR, directional bars %d/3); HTF thesis intact=%s. %s Chase risk=%s. Waiting for value generally improves structural R:R when chase risk is present. %s %s",
      impulsive?"IMPULSIVE / possible trend-failure pressure":"CORRECTIVE / non-impulsive",net,bodies,bars,intact?"YES":"NO",
      RetracementDestinationText(x),ChaseRiskDetected(x)?"YES":"NO",counter,reversal);
}

bool ExtremeRegimeDetected(const StrategySnapshot &x,string &why)
{
   why="";
   if(!InpBlockExtremeRegimes) return false;
   if(x.atrRatio>=InpExtremeATRRatioHigh)
      why=StringFormat("ATR regime %.2fx exceeds extreme high threshold %.2fx.",x.atrRatio,InpExtremeATRRatioHigh);
   else if(x.atrRatio<=InpExtremeATRRatioLow)
      why=StringFormat("ATR regime %.2fx is below extreme low threshold %.2fx.",x.atrRatio,InpExtremeATRRatioLow);
   else if(x.openingRangeRatio>=InpExtremeOpeningRangeRatio)
      why=StringFormat("Opening range %.2fx ATR exceeds extreme threshold %.2fx.",x.openingRangeRatio,InpExtremeOpeningRangeRatio);
   return (why!="");
}

bool StrategyResearchEvidenceAllows(const string sym,StrategyClass c,bool bull,string &detail)
{
   string aggregate=""; bool baseOK=StrategyEvidenceAllows(c,aggregate);
   bool contextOK=true; string context=CurrentStrategyContextEvidence(sym,c,bull,contextOK);
   string wf=""; bool wfOK=StrategyWalkForwardEvidence(c,wf);
   detail=aggregate+" | "+context+" | "+wf;
   return (baseOK && contextOK && wfOK);
}

void SelectDynamicStrategyResearch(const string sym,TradeSetup &pb,TradeSetup &br,StrategyDecision &d)
{
   SelectDynamicStrategyComplete(sym,pb,br,d);
   StrategySnapshot x; BuildStrategySnapshot(sym,x);
   d.rationale+=" | "+RetracementIntelligenceText(x);

   string extreme="";
   if(ExtremeRegimeDetected(x,extreme))
   {
      d.action=STRATEGY_ACTION_NO_TRADE;
      d.setup.valid=false;
      d.rationale+=" | Extreme/out-of-distribution regime guard BLOCK: "+extreme;
   }

   if(d.strategy!=STRATEGY_NO_TRADE)
   {
      string research="";
      bool researchOK=StrategyResearchEvidenceAllows(sym,d.strategy,d.setup.bullish,research);
      d.evidence=research;
      if(!researchOK)
      {
         d.action=STRATEGY_ACTION_NO_TRADE;
         d.setup.valid=false;
         d.rationale+=" | Research validation gate BLOCKED the strategy in its current evidence/context segment.";
      }
      else if(ChaseRiskDetected(x) &&
              (d.strategy==STRATEGY_TREND_CONTINUATION || d.strategy==STRATEGY_BREAKOUT) &&
              d.action==STRATEGY_ACTION_HIGH_CONFIDENCE)
      {
         d.action=STRATEGY_ACTION_WAIT;
         d.setup.valid=false;
         d.rationale+=" | Chase filter: trend direction may remain valid, but entry is overextended. WAIT for retracement/retest rather than chase.";
      }
   }
   PersistStrategyCandidate(sym,d);
}
// GPT_EA Part 24 - Session accuracy, late-session risk and strategy expiry

input bool InpDowngradeLateSessionLiquidity = true;
input int  InpLateSessionScorePenalty       = 8;

string AccurateSessionBucket()
{
   datetime utc=TimeGMT();
   MqlDateTime l={}; TimeToStruct(LondonLocal(utc),l);
   MqlDateTime n={}; TimeToStruct(NewYorkLocal(utc),n);

   // Overlap must be evaluated before generic London/NY buckets.
   if(l.hour>=13 && l.hour<17 && n.hour>=8 && n.hour<12) return "LONDON_NY_OVERLAP";
   if(l.hour>=7 && l.hour<9) return "LONDON_PREOPEN";
   if(l.hour>=9 && l.hour<13) return "LONDON";
   if(n.hour>=8 && n.hour<9) return "NEW_YORK_PREOPEN";
   if(n.hour>=9 && n.hour<12) return "NEW_YORK_OPEN";
   if(l.hour>=0 && l.hour<7) return "ASIAN";
   if(l.hour>=16 && l.hour<18) return "LONDON_CLOSE";
   if(n.hour>=15 && n.hour<17) return "NEW_YORK_CLOSE";
   return "OTHER";
}

bool LateSessionLiquidityRisk(string &why)
{
   why="";
   if(!InpDowngradeLateSessionLiquidity) return false;
   string s=AccurateSessionBucket();
   if(s=="LONDON_CLOSE" || s=="NEW_YORK_CLOSE")
   {
      why=s+" liquidity/flow transition can increase fakeouts, spread instability and poor follow-through.";
      return true;
   }
   return false;
}

int StrategyAdaptiveExpiry(const string sym,StrategyClass c)
{
   int base=5;
   switch(c)
   {
      case STRATEGY_BREAKOUT:            base=2; break;
      case STRATEGY_BREAKOUT_RETEST:     base=3; break;
      case STRATEGY_COUNTER_TREND_SCALP: base=2; break;
      case STRATEGY_COUNTER_TREND_SWING: base=4; break;
      case STRATEGY_POTENTIAL_REVERSAL:  base=4; break;
      case STRATEGY_RANGE_TRADE:         base=4; break;
      case STRATEGY_MEAN_REVERSION:      base=4; break;
      case STRATEGY_TREND_CONTINUATION:  base=5; break;
      case STRATEGY_RETRACEMENT_ENTRY:   base=6; break;
      default:                           base=4; break;
   }
   return AdaptiveExpiry(sym,base);
}

void RefreshFrameworkForAccurateSession(const string sym,StrategyDecision &d)
{
   if(d.strategy==STRATEGY_NO_TRADE) return;
   StrategySnapshot x; BuildStrategySnapshot(sym,x);
   x.session=AccurateSessionBucket();
   string framework=SelectedStrategyFramework(x,d.strategy);
   d.session=x.session;
   d.strategyName=StrategyClassName(d.strategy)+" — "+framework;
   d.rationale+=" | Accurate session context: "+x.session+"; framework refreshed to "+framework+".";
}

bool AccurateSessionEvidenceAllows(const string sym,StrategyClass c,string &detail)
{
   detail="Accurate-session evidence: not applicable.";
   if(c==STRATEGY_NO_TRADE) return true;
   string session=AccurateSessionBucket();
   int code=StrategySessionCode(session);
   return ContextBucketAllows(SysKey(StringFormat("STRAT_%d_SESSION_%d",(int)c,code)),
                              "ACCURATE SESSION "+session,detail);
}

void PersistStrategyPlanForExecutionAccurate(const TradeSetup &s)
{
   PersistStrategyPlanForExecutionFull(s);
   string session=AccurateSessionBucket();
   GVWrite(SymKey(s.symbol,"PLAN_SESSION_CODE"),StrategySessionCode(session));
   GVWrite(SymKey(s.symbol,"PLAN_SESSION_HASH"),(double)StringLen(session));
}

void SelectDynamicStrategyFinal(const string sym,TradeSetup &pb,TradeSetup &br,StrategyDecision &d)
{
   SelectDynamicStrategyResearch(sym,pb,br,d);
   RefreshFrameworkForAccurateSession(sym,d);

   if(d.strategy!=STRATEGY_NO_TRADE)
      d.setup.expiryM15=StrategyAdaptiveExpiry(sym,d.strategy);

   if(d.strategy!=STRATEGY_NO_TRADE)
   {
      string sessionEvidence="";
      bool sessionEvidenceOK=AccurateSessionEvidenceAllows(sym,d.strategy,sessionEvidence);
      d.evidence+=" | "+sessionEvidence;
      if(!sessionEvidenceOK)
      {
         d.action=STRATEGY_ACTION_NO_TRADE;
         d.setup.valid=false;
         d.rationale+=" | Corrected-session evidence gate BLOCKED the strategy in the current session segment.";
      }
   }

   string lateWhy="";
   if(LateSessionLiquidityRisk(lateWhy) && d.strategy!=STRATEGY_NO_TRADE && d.action!=STRATEGY_ACTION_NO_TRADE)
   {
      int penalty=(InpLateSessionScorePenalty>0?InpLateSessionScorePenalty:0);
      d.score=(d.score>penalty?d.score-penalty:0);
      d.rationale+=" | Late-session liquidity warning: "+lateWhy;
      bool fastSetup=(d.strategy==STRATEGY_BREAKOUT || d.strategy==STRATEGY_BREAKOUT_RETEST ||
                      d.strategy==STRATEGY_COUNTER_TREND_SCALP || d.strategy==STRATEGY_MEAN_REVERSION);
      if(fastSetup && d.action==STRATEGY_ACTION_HIGH_CONFIDENCE)
      {
         d.action=STRATEGY_ACTION_WAIT;
         d.setup.valid=false;
         d.rationale+=" | Fast setup downgraded to WAIT because end-session liquidity can invalidate normal follow-through assumptions.";
      }
      else if(d.action==STRATEGY_ACTION_HIGH_CONFIDENCE && d.score<InpMinStrategyScore)
      {
         d.action=STRATEGY_ACTION_WAIT;
         d.setup.valid=false;
      }
   }
   PersistStrategyCandidate(sym,d);
}
// GPT_EA Part 27 - Reachable first-class breakout / counter-trend strategy paths

input bool   InpAllowDirectBreakoutExecution = true;
input double InpDirectBreakoutMinVolumeRatio = 1.15;
input double InpDirectBreakoutMinADX         = 22.0;
input double InpDirectBreakoutZoneATR        = 0.18;
input double InpDirectBreakoutInsideStopATR  = 0.45;

TradeSetup BuildDirectBreakoutCandidate(const StrategySnapshot &x,int score)
{
   bool bull=(x.breakoutUp && !x.breakoutDown ? true :
              (!x.breakoutUp && x.breakoutDown ? false : x.dominantBull));
   TradeSetup s; InitSetup(s,x.symbol,SETUP_BREAKOUT,bull);
   if(x.atr<=0) return s;

   double level=(bull?x.priorHigh:x.priorLow);
   if(level<=0) return s;
   double width=MathMax(0.05,InpDirectBreakoutZoneATR)*x.atr;
   s.name="BREAKOUT";
   if(bull)
   {
      s.zoneLow=NormPrice(x.symbol,level+0.02*x.atr);
      s.zoneHigh=NormPrice(x.symbol,level+width);
      s.preferred=NormPrice(x.symbol,level+0.07*x.atr);
      s.sl=NormPrice(x.symbol,level-MathMax(0.25,InpDirectBreakoutInsideStopATR)*x.atr);
   }
   else
   {
      s.zoneLow=NormPrice(x.symbol,level-width);
      s.zoneHigh=NormPrice(x.symbol,level-0.02*x.atr);
      s.preferred=NormPrice(x.symbol,level-0.07*x.atr);
      s.sl=NormPrice(x.symbol,level+MathMax(0.25,InpDirectBreakoutInsideStopATR)*x.atr);
   }

   SetConservativeTargets(s,1.0,2.0,3.0);
   RefineTargetsToStructure(s);
   s.confidence=(score>95?95:score);
   s.expiryM15=StrategyAdaptiveExpiry(x.symbol,STRATEGY_BREAKOUT);
   RealisticRRReport rr=RealisticRiskReward(s);
   bool breakout=(bull?x.breakoutUp:x.breakoutDown);
   bool fake=(bull?x.falseBreakUp:x.falseBreakDown);
   bool quality=(x.expansion && x.volumeRatio>=InpDirectBreakoutMinVolumeRatio && x.adx>=InpDirectBreakoutMinADX);
   s.valid=(InpAllowDirectBreakoutExecution && breakout && !fake && quality && !ChaseRiskDetected(x) && rr.rr>=InpMinEffectiveRR);
   s.reason=StringFormat("Direct breakout through %.5f | expansion %s | ADX %.1f | volume %.2fx | chase %s | realistic weighted R:R %.2f.",
                         level,x.expansion?"YES":"NO",x.adx,x.volumeRatio,ChaseRiskDetected(x)?"YES":"NO",rr.rr);
   s.invalidation=(bull?
      "M15 acceptance back below the broken resistance/old range invalidates the breakout thesis.":
      "M15 acceptance back above the broken support/old range invalidates the breakdown thesis.");
   s.failurePattern="Failure: displacement cannot hold outside the old range, momentum collapses, or price returns through the breakout level as a false break/liquidity sweep.";
   s.executionRule="Direct breakout execution requires fresh expansion, volume/ADX support, price inside the shallow post-break zone, M5 trigger and EMA impulse. Do not chase beyond the breakout zone; otherwise WAIT for retest.";
   return s;
}

bool OverrideResearchAllows(const string sym,StrategyDecision &d,string &detail)
{
   string research="";
   bool ok=StrategyResearchEvidenceAllows(sym,d.strategy,d.setup.bullish,research);
   string ses="";
   bool sesOK=AccurateSessionEvidenceAllows(sym,d.strategy,ses);
   detail=research+" | "+ses;
   return (ok && sesOK);
}

void CompleteOverrideDecision(const string sym,StrategyDecision &d)
{
   RefreshFrameworkForAccurateSession(sym,d);
   d.setup.expiryM15=StrategyAdaptiveExpiry(sym,d.strategy);
   string evidence="";
   bool evidenceOK=OverrideResearchAllows(sym,d,evidence);
   d.evidence=evidence;
   if(!evidenceOK)
   {
      d.action=STRATEGY_ACTION_NO_TRADE;
      d.setup.valid=false;
      d.rationale+=" | Override strategy rejected by research/context evidence.";
      return;
   }
   if(d.score<InpMinStrategyScore || !d.setup.valid) d.action=STRATEGY_ACTION_WAIT;
   else d.action=STRATEGY_ACTION_HIGH_CONFIDENCE;
}

void SelectDynamicStrategyUltimate(const string sym,TradeSetup &pb,TradeSetup &br,StrategyDecision &d)
{
   SelectDynamicStrategyFinal(sym,pb,br,d);
   StrategySnapshot x; BuildStrategySnapshot(sym,x);
   string extreme="";
   if(ExtremeRegimeDetected(x,extreme))
   {
      d.action=STRATEGY_ACTION_NO_TRADE;
      d.setup.valid=false;
      d.rationale+=" | Ultimate strategy guard retains extreme-regime BLOCK: "+extreme;
      PersistStrategyCandidate(sym,d);
      return;
   }

   // Trend failure is not yet a completed reversal. Always keep this state classified
   // as Counter-Trend Swing; if its stricter score/trigger is insufficient the result is WAIT.
   if(x.state==STATE_TREND_FAILURE && InpAllowCounterTrendSwing)
   {
      bool counterBull=!x.dominantBull;
      int ct=CounterTrendScore(x,counterBull);
      int reversalScore=StrategyBaseScore(x,STRATEGY_POTENTIAL_REVERSAL);
      d.strategy=STRATEGY_COUNTER_TREND_SWING;
      d.counterTrend=true;
      d.counterTrendScore=ct;
      d.score=(ct>reversalScore?ct:reversalScore);
      d.state=STATE_TREND_FAILURE;
      d.stateText=MarketStateName(d.state);
      d.setup=BuildCounterTrendCandidate(x,counterBull,ct,true);
      d.strategyName=StrategyClassName(d.strategy);
      d.rationale+=" | Trend failure is classified as COUNTER-TREND SWING until full reversal acceptance is established.";
      d.confirmation="COUNTER-TREND TRADE: require major-level/sweep rejection plus M5 BOS/CHOCH and rejection; targets remain conservative until reversal structure proves durable.";
      CompleteOverrideDecision(sym,d);
      if(ct<InpMinCounterTrendScore)
      {
         d.action=STRATEGY_ACTION_WAIT;
         d.setup.valid=false;
         d.rationale+=StringFormat(" | Counter-trend swing score %d/100 is below strict threshold %d; WAIT, do not relabel as reversal.",ct,InpMinCounterTrendScore);
      }
   }

   // A completed structural reversal remains Potential Reversal rather than being diluted
   // into the counter-trend swing class.
   if(x.state==STATE_REVERSAL && d.strategy!=STRATEGY_NO_TRADE)
   {
      d.state=STATE_REVERSAL;
      d.stateText=MarketStateName(d.state);
   }

   // Make BREAKOUT a true executable class when displacement quality is high and the
   // price is still in a shallow post-break zone. Overextended breaks remain WAIT/retest.
   if(d.strategy==STRATEGY_BREAKOUT && InpAllowDirectBreakoutExecution)
   {
      TradeSetup direct=BuildDirectBreakoutCandidate(x,d.score);
      d.setup=direct;
      d.strategyName=StrategyClassName(d.strategy);
      d.rationale+=" | Direct breakout execution path evaluated. "+direct.reason;
      d.confirmation=direct.executionRule;
      CompleteOverrideDecision(sym,d);
   }

   if(d.strategy==STRATEGY_BREAKOUT_RETEST)
   {
      d.state=STATE_BREAKOUT_RETEST;
      d.stateText=MarketStateName(d.state);
   }

   // Mean reversion has its own enable switch; do not accidentally depend on the range-trade toggle.
   if(d.strategy==STRATEGY_MEAN_REVERSION && InpAllowMeanReversion && !d.setup.valid && d.setup.preferred>0)
   {
      RealisticRRReport rr=RealisticRiskReward(d.setup);
      if(d.setup.confidence>=InpMinStrategyScore && rr.rr>=1.05)
      {
         d.setup.valid=true;
         d.rationale+=" | Mean-reversion validity repaired using its dedicated enable switch and realistic R:R gate.";
         CompleteOverrideDecision(sym,d);
      }
   }

   PersistStrategyCandidate(sym,d);
}
// GPT_EA Part 19 - Continuous intelligence scan scheduler

input bool InpContinuousIntelligenceScan = true;
input bool InpScanOnEveryNewM5Bar        = true;
input int  InpContinuousScanMinutes      = 5;

datetime g_lastContinuousScanTime=0;
datetime g_lastContinuousM5Bar=0;

bool ContinuousIntelligenceScanDue(string &why)
{
   why="";
   if(!InpContinuousIntelligenceScan || ArraySize(g_symbols)<=0) return false;
   datetime now=TimeTradeServer();

   if(InpScanOnEveryNewM5Bar)
   {
      datetime newest=0;
      int total=ArraySize(g_symbols);
      int probes=InpUniverseClockProbeSymbols;
      if(probes<1) probes=1;
      if(probes>total) probes=total;
      for(int p=0;p<probes;p++)
      {
         int i=(g_universalScanCursor+p)%total;
         if(g_symbols[i]=="") continue;
         datetime bt=iTime(g_symbols[i],PERIOD_M5,0);
         if(bt>newest) newest=bt;
      }
      if(newest>0 && g_lastContinuousM5Bar>0 && newest!=g_lastContinuousM5Bar)
      {
         g_lastContinuousM5Bar=newest;
         g_lastContinuousScanTime=now;
         why="Continuous new-M5-bar intelligence scan";
         return true;
      }
      if(g_lastContinuousM5Bar==0 && newest>0) g_lastContinuousM5Bar=newest;
   }

   int mins=MathMax(1,InpContinuousScanMinutes);
   if(g_lastContinuousScanTime==0)
   {
      g_lastContinuousScanTime=now;
      return false;
   }
   if(now-g_lastContinuousScanTime>=mins*60)
   {
      g_lastContinuousScanTime=now;
      why=StringFormat("Continuous %d-minute intelligence scan",mins);
      return true;
   }
   return false;
}

bool ScheduledOrContinuousScanDue(string &why)
{
   if(ScheduledScanDue(why))
   {
      g_lastContinuousScanTime=TimeTradeServer();
      return true;
   }
   return ContinuousIntelligenceScanDue(why);
}
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
// GPT_EA Part 16 - Live web news, macro and intermarket intelligence

input bool   InpUseLiveWebIntelligence          = true;
input bool   InpWebIntelHighConfidenceOnly      = true;
input bool   InpBlockIfWebIntelUnavailable      = false;
input bool   InpBlockOnWebIntelVerdictBLOCK     = true;
input int    InpWebIntelRefreshMinutes          = 10;
input int    InpIntermarketLookbackM15          = 8;
input int    InpIntermarketSevereConflictScore  = -5;
input string InpDXYAliases                      = "DXY,USDX,DX";
input string InpVIXAliases                      = "VIX,USVIX,VIX.cash";
input string InpGoldAliases                     = "XAUUSD,GOLD";
input string InpOilAliases                      = "WTI,USOIL,WTICOIL";
input string InpUS100Aliases                    = "US100,NAS100,USTEC,NQ100";
input string InpUS500Aliases                    = "US500,SPX500,SP500";

struct IntermarketReport
{
   int score;
   bool severeConflict;
   string detail;
};

string g_webIntelSymbols[];
string g_webIntelText[];
datetime g_webIntelTime[];
bool g_webIntelBlock[];
bool g_webIntelWatch[];

int WebIntelCacheIndex(const string sym)
{
   for(int i=0;i<ArraySize(g_webIntelSymbols);i++) if(g_webIntelSymbols[i]==sym) return i;
   int n=ArraySize(g_webIntelSymbols);
   ArrayResize(g_webIntelSymbols,n+1); ArrayResize(g_webIntelText,n+1); ArrayResize(g_webIntelTime,n+1);
   ArrayResize(g_webIntelBlock,n+1); ArrayResize(g_webIntelWatch,n+1);
   g_webIntelSymbols[n]=sym; g_webIntelText[n]=""; g_webIntelTime[n]=0; g_webIntelBlock[n]=false; g_webIntelWatch[n]=false;
   return n;
}

string ResolveFirstAlias(const string csv)
{
   string a[]; int n=StringSplit(csv,',',a);
   for(int i=0;i<n;i++)
   {
      string s=ResolveBrokerSymbol(Trim(a[i]));
      if(s!="") return s;
   }
   return "";
}

bool SymbolMovePct(const string sym,ENUM_TIMEFRAMES tf,int bars,double &pct)
{
   pct=0; if(sym=="") return false;
   double now=0,old=0;
   if(!CloseValue(sym,tf,1,now) || !CloseValue(sym,tf,MathMax(2,bars+1),old) || old==0) return false;
   pct=(now-old)/old*100.0;
   return true;
}

void AddIntermarketComponent(IntermarketReport &r,const string label,double move,bool bullishEffect,double weight)
{
   int delta=(int)MathRound(MathMin(3.0,MathAbs(move)*weight));
   if(delta<1 && MathAbs(move)>0.01) delta=1;
   if(!bullishEffect) delta=-delta;
   r.score+=delta;
   if(r.detail!="") r.detail+=" | ";
   r.detail+=StringFormat("%s %+.3f%% => %s%d",label,move,delta>=0?"+":"",delta);
}

IntermarketReport AssessIntermarket(const string target,bool bull)
{
   IntermarketReport r; r.score=0; r.severeConflict=false; r.detail="";
   string key=CanonicalBrokerInstrumentKey(target);
   string dxy=ResolveFirstAlias(InpDXYAliases),vix=ResolveFirstAlias(InpVIXAliases);
   string gold=ResolveFirstAlias(InpGoldAliases),oil=ResolveFirstAlias(InpOilAliases);
   string us100=ResolveFirstAlias(InpUS100Aliases),us500=ResolveFirstAlias(InpUS500Aliases);
   string y10=ResolveBrokerSymbol(InpYieldSymbol);
   double mD=0,mV=0,mY=0,mG=0,mO=0,mN=0,mS=0;
   bool hD=SymbolMovePct(dxy,PERIOD_M15,InpIntermarketLookbackM15,mD);
   bool hV=SymbolMovePct(vix,PERIOD_M15,InpIntermarketLookbackM15,mV);
   bool hY=SymbolMovePct(y10,PERIOD_M15,InpIntermarketLookbackM15,mY);
   bool hG=SymbolMovePct(gold,PERIOD_M15,InpIntermarketLookbackM15,mG);
   bool hO=SymbolMovePct(oil,PERIOD_M15,InpIntermarketLookbackM15,mO);
   bool hN=SymbolMovePct(us100,PERIOD_M15,InpIntermarketLookbackM15,mN);
   bool hS=SymbolMovePct(us500,PERIOD_M15,InpIntermarketLookbackM15,mS);

   if(StringFind(key,"METAL:XAU")==0 || StringFind(key,"METAL:XAG")==0)
   {
      if(hD) AddIntermarketComponent(r,"DXY",mD,bull?(mD<0):(mD>0),35.0);
      if(hY) AddIntermarketComponent(r,"US10Y",mY,bull?(mY<0):(mY>0),40.0);
      if(hV) AddIntermarketComponent(r,"VIX",mV,bull?(mV>0):(mV<0),18.0);
   }
   else if(StringFind(key,"INDEX:US100")==0 || StringFind(key,"INDEX:US500")==0 || StringFind(key,"INDEX:US30")==0)
   {
      if(hY) AddIntermarketComponent(r,"US10Y",mY,bull?(mY<0):(mY>0),45.0);
      if(hV) AddIntermarketComponent(r,"VIX",mV,bull?(mV<0):(mV>0),25.0);
      if(hS && target!=us500) AddIntermarketComponent(r,"US500",mS,bull?(mS>0):(mS<0),20.0);
   }
   else if(StringFind(key,"INDEX:GER40")==0 || StringFind(key,"INDEX:UK100")==0)
   {
      if(hV) AddIntermarketComponent(r,"VIX",mV,bull?(mV<0):(mV>0),20.0);
      if(hN) AddIntermarketComponent(r,"US100",mN,bull?(mN>0):(mN<0),18.0);
      if(hS) AddIntermarketComponent(r,"US500",mS,bull?(mS>0):(mS<0),18.0);
   }
   else if(StringFind(key,"ENERGY:")==0)
   {
      if(hD) AddIntermarketComponent(r,"DXY",mD,bull?(mD<0):(mD>0),22.0);
      if(hS) AddIntermarketComponent(r,"US500",mS,bull?(mS>0):(mS<0),12.0);
      if(hO && target!=oil) AddIntermarketComponent(r,"WTI",mO,bull?(mO>0):(mO<0),15.0);
   }
   else if(StringFind(key,"FX:")==0)
   {
      string pair=StringSubstr(key,3);
      bool usdBase=(StringSubstr(pair,0,3)=="USD");
      bool usdQuote=(StringSubstr(pair,3,3)=="USD");
      if(hD && (usdBase || usdQuote))
      {
         bool supports=(usdBase?(bull?(mD>0):(mD<0)):(bull?(mD<0):(mD>0)));
         AddIntermarketComponent(r,"DXY",mD,supports,35.0);
      }
      if(hY && StringFind(pair,"JPY")>=0)
      {
         bool supports=(usdBase?(bull?(mY>0):(mY<0)):(bull?(mY<0):(mY>0)));
         AddIntermarketComponent(r,"US10Y",mY,supports,25.0);
      }
   }
   else if(StringFind(key,"CRYPTO:")==0)
   {
      if(hD) AddIntermarketComponent(r,"DXY",mD,bull?(mD<0):(mD>0),20.0);
      if(hV) AddIntermarketComponent(r,"VIX",mV,bull?(mV<0):(mV>0),15.0);
      if(hN) AddIntermarketComponent(r,"US100",mN,bull?(mN>0):(mN<0),15.0);
   }

   if(r.detail=="") r.detail="Intermarket: relevant broker instruments unavailable; no fabricated confirmation.";
   r.score=MathMax(-10,MathMin(10,r.score));
   r.severeConflict=(r.score<=InpIntermarketSevereConflictScore);
   r.detail=StringFormat("Intermarket score %+d/10 | %s",r.score,r.detail);
   return r;
}

string WebIntelInstrumentContext(const string sym)
{
   string key=CanonicalBrokerInstrumentKey(sym);
   if(StringFind(key,"INDEX:")==0) return "equity-index macro, rates, earnings/sector, volatility and geopolitical sensitivity";
   if(StringFind(key,"METAL:")==0) return "USD, real/nominal yields, central-bank expectations, inflation, safe-haven and commodity-specific flows";
   if(StringFind(key,"ENERGY:")==0) return "oil/gas inventories, OPEC+, geopolitical supply, demand growth, USD and risk sentiment";
   if(StringFind(key,"COMMODITY:")==0) return "weather, crop/production reports, inventories, supply-demand, freight, USD, geopolitics and commodity-specific events";
   if(StringFind(key,"FX:")==0) return "central banks, inflation, labor, GDP/PMI, rates/yields, political and currency-specific headlines";
   if(StringFind(key,"CRYPTO:")==0) return "liquidity, regulation, ETF/flow, risk sentiment, rates, USD and crypto-specific headlines";
   if(StringFind(key,"STOCK:")==0) return "company earnings/guidance, sector flows, valuation, rates, corporate actions and material company-specific news";
   if(StringFind(key,"ETF:")==0) return "underlying holdings/index drivers, fund flows, rates, volatility, sector/macro and issuer-specific developments";
   if(StringFind(key,"FUTURE:")==0) return "underlying spot/forward market, term structure, inventory/supply-demand, rates, session liquidity, expiry/roll and contract-specific events";
   if(StringFind(key,"BOND_RATE:")==0) return "central-bank policy, inflation, labor, GDP/PMI, sovereign issuance, yield-curve moves, auctions and rate-specific events";
   return "macro, sector/company where relevant, rates, volatility and instrument-specific breaking news";
}

bool CallOpenAIWebIntel(const string prompt,string &answer,string &errorText)
{
   answer=""; errorText="";
   if(!InpUseLiveWebIntelligence){ errorText="Live web intelligence disabled."; return false; }
   if((bool)MQLInfoInteger(MQL_TESTER)){ errorText="WebRequest/web search unavailable in Strategy Tester."; return false; }
   if(StringLen(Trim(InpOpenAIAPIKey))<20){ errorText="OpenAI API key not configured."; return false; }

   string body="{\"model\":\""+JsonEscape(InpOpenAIModel)+"\",\"tools\":[{\"type\":\"web_search\",\"search_context_size\":\"medium\"}],\"input\":\""+JsonEscape(prompt)+"\"}";
   string headers="Content-Type: application/json\r\nAuthorization: Bearer "+InpOpenAIAPIKey+"\r\n";
   char data[],result[]; string resultHeaders="";
   int n=StringToCharArray(body,data,0,WHOLE_ARRAY,CP_UTF8); if(n>0) ArrayResize(data,n-1);
   ResetLastError();
   int code=WebRequest("POST",InpOpenAIEndpoint,headers,InpOpenAITimeoutMs,data,result,resultHeaders);
   if(code==-1){ errorText=StringFormat("Web intel WebRequest failed (%d).",GetLastError()); return false; }
   string json=CharArrayToString(result,0,-1,CP_UTF8);
   if(code<200 || code>=300){ errorText=StringFormat("Web intel HTTP %d: %s",code,StringSubstr(json,0,500)); return false; }
   answer=ExtractOpenAIText(json);
   if(answer=="" || StringFind(answer,"could not be parsed")>=0){ errorText="Web intel response text unavailable."; return false; }
   return true;
}

string BuildLiveNewsPrompt(const string sym,const TradeSetup &s,const StrategyDecision &d,const IntermarketReport &im)
{
   return "You are the live-news risk layer of a MetaTrader EA. Use web search for CURRENT information. Do not invent headlines, prices, event times, yields or sources. "
          "Instrument: "+sym+". Direction: "+(s.bullish?"LONG":"SHORT")+". Strategy: "+d.strategyName+". Market state: "+d.stateText+". "
          "Instrument context: "+WebIntelInstrumentContext(sym)+". Broker intermarket snapshot: "+im.detail+". "
          "Search scheduled and unexpected market-moving information: central-bank rate decisions; CPI/inflation; PPI; employment/NFP/unemployment; GDP; PMI; retail sales; "
          "FOMC/ECB/BoE and other central-bank speeches/communications; Treasury yields and bond volatility; USD strength; geopolitical developments; unexpected political/economic headlines; "
          "company or sector news where relevant; commodity-specific supply/demand/OPEC/inventory news; volatility/risk events; and any other high-impact development relevant to the instrument. "
          "Explain HOW a headline could invalidate the technical setup before entry or during the trade. Distinguish confirmed facts from uncertain reports. "
          "Return concise plain text in this exact structure: VERDICT: CLEAR or WATCH or BLOCK; RISK_SCORE: 0-100; EVENTS: ...; BREAKING_NEWS: ...; "
          "INVALIDATION_CHANNEL: ...; INTERMARKET: ...; SOURCES: include source names and URLs with dates/times where available. BLOCK only for materially setup-threatening current risk, not merely because news exists.";
}

void InterpretWebIntel(const string text,bool &block,bool &watch)
{
   block=false; watch=false; string u=text; StringToUpper(u);
   if(StringFind(u,"VERDICT: BLOCK")>=0) block=true;
   else if(StringFind(u,"VERDICT: WATCH")>=0) watch=true;
}

bool GetLiveWebIntel(const string sym,const TradeSetup &s,const StrategyDecision &d,bool force,string &text,bool &block,bool &watch,string &errorText)
{
   text=""; block=false; watch=false; errorText="";
   if(!InpUseLiveWebIntelligence){ text="Live web intelligence disabled."; return true; }
   if(InpWebIntelHighConfidenceOnly && !force && d.score<InpMinStrategyScore){ text="Web search deferred until a strategy candidate reaches quality threshold."; return true; }
   int idx=WebIntelCacheIndex(sym);
   datetime now=TimeTradeServer();
   if(!force && g_webIntelTime[idx]>0 && now-g_webIntelTime[idx]<MathMax(1,InpWebIntelRefreshMinutes)*60)
   {
      text=g_webIntelText[idx]; block=g_webIntelBlock[idx]; watch=g_webIntelWatch[idx]; return true;
   }
   IntermarketReport im=AssessIntermarket(sym,s.bullish);
   bool ok=CallOpenAIWebIntel(BuildLiveNewsPrompt(sym,s,d,im),text,errorText);
   if(!ok)
   {
      text="Live web intelligence unavailable: "+errorText;
      block=InpBlockIfWebIntelUnavailable; watch=!block;
      return !InpBlockIfWebIntelUnavailable;
   }
   InterpretWebIntel(text,block,watch);
   g_webIntelText[idx]=text; g_webIntelBlock[idx]=block; g_webIntelWatch[idx]=watch; g_webIntelTime[idx]=now;
   return true;
}

bool PreEntryIntelligenceRevalidation(const TradeSetup &s,string &why)
{
   string strategyWhy="";
   if(!RevalidateStrategyIdentity(s,strategyWhy)){ why=strategyWhy; return false; }

   TradeSetup pb=BuildPullback(s.symbol,s.bullish,s.confidence,"");
   TradeSetup br=BuildBreakoutRetest(s.symbol,s.bullish,s.confidence,"");
   StrategyDecision d; SelectDynamicStrategy(s.symbol,pb,br,d);
   IntermarketReport im=AssessIntermarket(s.symbol,s.bullish);
   if(im.severeConflict){ why="Severe intermarket contradiction: "+im.detail; return false; }

   string web="",err=""; bool block=false,watch=false;
   bool webOK=GetLiveWebIntel(s.symbol,s,d,true,web,block,watch,err);
   if(!webOK || (InpBlockOnWebIntelVerdictBLOCK && block))
   { why="Live news/web intelligence invalidated execution: "+web; return false; }

   string cal=""; if(CalendarBlock(s.symbol,cal)){ why="Economic calendar now blocks execution: "+cal; return false; }
   string yield=""; if(YieldShock(yield)){ why="Treasury-yield shock now blocks execution: "+yield; return false; }
   why="Pre-entry strategy/news/intermarket revalidation PASS | "+strategyWhy+" | "+im.detail+(watch?" | web news WATCH":" | web news CLEAR");
   return true;
}

void NewsIntermarketInit()
{
   ArrayResize(g_webIntelSymbols,0); ArrayResize(g_webIntelText,0); ArrayResize(g_webIntelTime,0);
   ArrayResize(g_webIntelBlock,0); ArrayResize(g_webIntelWatch,0);
}

void NewsIntermarketTimer()
{
   // Deliberately no unconditional web calls. Scheduled/manual scans and pre-entry validation refresh intelligence.
}
// Forward declaration used to route Part22 web prompts through fresh intermarket data.
IntermarketReport AssessIntermarketHardened(const string target,bool bull);
// GPT_EA Part 22P - Wider Responses API text extraction for intelligence data

input int InpIntelligenceResponseMaxChars = 12000;

string ExtractOpenAITextWide(const string json)
{
   int typePos=StringFind(json,"\"type\":\"output_text\"");
   int start=(typePos>=0?typePos:0);
   string key="\"text\":\"";
   int p=StringFind(json,key,start);
   if(p<0)
   {
      key="\"output_text\":\"";
      p=StringFind(json,key,start);
   }
   if(p<0) return "OpenAI response received, but text could not be parsed.";
   p+=StringLen(key);

   int cap=(InpIntelligenceResponseMaxChars<2000?2000:InpIntelligenceResponseMaxChars);
   string out="";
   bool esc=false;
   for(int i=p;i<StringLen(json);i++)
   {
      ushort ch=StringGetCharacter(json,i);
      if(ch=='\\' && !esc){ esc=true; out+="\\"; continue; }
      if(ch=='\"' && !esc) break;
      esc=false;
      out+=ShortToString(ch);
      if(StringLen(out)>=cap) break;
   }
   return JsonUnescape(out);
}
#define AssessIntermarket AssessIntermarketHardened
#define ExtractOpenAIText ExtractOpenAITextWide
// GPT_EA Part 22 - Structured live-news contract and fresh intermarket data

input bool InpUseStructuredWebIntel            = true;
input bool InpFailClosedHighConfidenceNews     = true;
input bool InpRequireWebIntelSources            = true;
input int  InpWebIntelRiskWatchScore            = 50;
input int  InpWebIntelRiskBlockScore            = 80;
input int  InpWebIntelFailureCircuitThreshold   = 3;
input int  InpWebIntelMaxCacheAgeMinutes        = 12;
input int  InpIntermarketMaxBarAgeMinutes       = 90;
input int  InpIntermarketMinFreshComponents     = 1;
input int  InpWebIntelMaxAsOfAgeMinutes          = 15;
input int  InpWebIntelMaxFutureSkewSeconds       = 120;
input int  InpWebIntelMinAnnotationURLs          = 1;
input bool InpRequirePrimarySourceForHighRisk    = true;
input string InpWebIntelProvenanceFile           = "GPT_EA_WebIntelProvenance.csv";

string g_lastWebIntelAnnotationURLs="";
string g_lastWebIntelAsOfUTC="";
bool   g_lastWebIntelHasPrimarySource=false;
bool   g_lastWebIntelProvenanceHardFail=false;
string g_lastWebIntelFailureClass="NONE"; // NONE / UNAVAILABLE / SCHEMA / PROVENANCE / STALE / VERDICT_BLOCK

string g_webHardFailSymbols[];
int    g_webHardFailCounts[];

int WebHardFailureIndex(const string sym)
{
   for(int i=0;i<ArraySize(g_webHardFailSymbols);i++) if(g_webHardFailSymbols[i]==sym) return i;
   int n=ArraySize(g_webHardFailSymbols);
   ArrayResize(g_webHardFailSymbols,n+1); ArrayResize(g_webHardFailCounts,n+1);
   g_webHardFailSymbols[n]=sym; g_webHardFailCounts[n]=0;
   return n;
}

int JsonValueStart(const string json,const string key)
{
   string needle="\""+key+"\"";
   int p=StringFind(json,needle); if(p<0) return -1;
   p=StringFind(json,":",p+StringLen(needle)); if(p<0) return -1;
   p++;
   while(p<StringLen(json))
   {
      ushort ch=StringGetCharacter(json,p);
      if(ch!=' ' && ch!='\t' && ch!='\r' && ch!='\n') break;
      p++;
   }
   return p;
}

bool JsonStringFieldSimple(const string json,const string key,string &out)
{
   out=""; int p=JsonValueStart(json,key); if(p<0 || p>=StringLen(json)) return false;
   if(StringGetCharacter(json,p)!='\"') return false;
   p++; bool esc=false;
   for(int i=p;i<StringLen(json);i++)
   {
      ushort ch=StringGetCharacter(json,i);
      if(ch=='\\' && !esc){ esc=true; out+="\\"; continue; }
      if(ch=='\"' && !esc){ out=JsonUnescape(out); return true; }
      esc=false; out+=ShortToString(ch);
   }
   return false;
}

bool JsonIntFieldSimple(const string json,const string key,int &out)
{
   out=0; int p=JsonValueStart(json,key); if(p<0) return false;
   string s="";
   for(int i=p;i<StringLen(json);i++)
   {
      ushort ch=StringGetCharacter(json,i);
      if((ch>='0' && ch<='9') || (ch=='-' && StringLen(s)==0)) s+=ShortToString(ch);
      else break;
   }
   if(s=="" || s=="-") return false;
   out=(int)StringToInteger(s); return true;
}

bool WebIntelLeapYear(int y)
{
   return ((y%4==0 && y%100!=0) || y%400==0);
}

int WebIntelDaysInMonth(int y,int m)
{
   int d[12]={31,28,31,30,31,30,31,31,30,31,30,31};
   if(m==2 && WebIntelLeapYear(y)) return 29;
   if(m<1 || m>12) return 0;
   return d[m-1];
}

bool ParseISO8601UTC(const string value,datetime &out)
{
   out=0;
   if(StringLen(value)<20) return false;
   int y=(int)StringToInteger(StringSubstr(value,0,4));
   int mo=(int)StringToInteger(StringSubstr(value,5,2));
   int da=(int)StringToInteger(StringSubstr(value,8,2));
   int hh=(int)StringToInteger(StringSubstr(value,11,2));
   int mm=(int)StringToInteger(StringSubstr(value,14,2));
   int ss=(int)StringToInteger(StringSubstr(value,17,2));
   if(y<1970 || mo<1 || mo>12 || da<1 || da>WebIntelDaysInMonth(y,mo) ||
      hh<0 || hh>23 || mm<0 || mm>59 || ss<0 || ss>60) return false;
   long days=0;
   for(int yy=1970;yy<y;yy++) days+=(WebIntelLeapYear(yy)?366:365);
   for(int m=1;m<mo;m++) days+=WebIntelDaysInMonth(y,m);
   days+=da-1;
   out=(datetime)(days*86400L+hh*3600+mm*60+MathMin(ss,59));
   return true;
}

bool WebIntelOfficialDomain(const string url)
{
   string u=url; StringToLower(u);
   string domains="federalreserve.gov|bls.gov|bea.gov|treasury.gov|census.gov|eia.gov|energy.gov|"
                  "ecb.europa.eu|eurostat.ec.europa.eu|ec.europa.eu|bankofengland.co.uk|ons.gov.uk|"
                  "boj.or.jp|rba.gov.au|rbnz.govt.nz|bankofcanada.ca|statcan.gc.ca|bis.org|opec.org|imf.org|worldbank.org";
   string a[]; int n=StringSplit(domains,'|',a);
   for(int i=0;i<n;i++) if(StringFind(u,a[i])>=0) return true;
   return false;
}

void ExtractResponseAnnotationURLs(const string response,string &urls,int &count,bool &hasPrimary)
{
   urls=""; count=0; hasPrimary=false;
   string key="\"url\":\"";
   int pos=0;
   while(pos<StringLen(response) && count<20)
   {
      int p=StringFind(response,key,pos); if(p<0) break;
      p+=StringLen(key);
      string raw=""; bool esc=false;
      int end=p;
      for(;end<StringLen(response);end++)
      {
         ushort ch=StringGetCharacter(response,end);
         if(ch=='\\' && !esc){ esc=true; raw+="\\"; continue; }
         if(ch=='\"' && !esc) break;
         esc=false; raw+=ShortToString(ch);
      }
      string url=JsonUnescape(raw);
      if(StringFind(url,"https://")==0)
      {
         bool duplicate=(StringFind("|"+urls+"|","|"+url+"|")>=0);
         if(!duplicate)
         {
            if(urls!="") urls+="|";
            urls+=url; count++;
            if(WebIntelOfficialDomain(url)) hasPrimary=true;
         }
      }
      pos=end+1;
   }
}

void EnsureWebIntelProvenanceHeader()
{
   bool exists=FileIsExist(InpWebIntelProvenanceFile,FILE_COMMON);
   int h=FileOpen(InpWebIntelProvenanceFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(h==INVALID_HANDLE) return;
   if(!exists || FileSize(h)==0)
      FileWrite(h,"schema_version","time","as_of_utc","annotation_count","primary_source","urls","verdict","risk_score","status");
   FileClose(h);
}

void WriteWebIntelProvenance(const string asof,const string urls,int count,bool primary,const string verdict,int risk,const string status)
{
   EnsureWebIntelProvenanceHeader();
   int h=FileOpen(InpWebIntelProvenanceFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(h==INVALID_HANDLE) return;
   FileSeek(h,0,SEEK_END);
   FileWrite(h,"web_intel_provenance_v1",TimeToString(TimeGMT(),TIME_DATE|TIME_SECONDS),asof,count,
      primary?"1":"0",urls,verdict,risk,status);
   FileFlush(h); FileClose(h);
}

bool WebIntelAsOfFresh(const string asof,string &why)
{
   datetime ts=0;
   if(!ParseISO8601UTC(asof,ts)){ why="as_of_utc is not valid UTC ISO-8601"; return false; }
   datetime now=TimeGMT();
   long age=(long)now-(long)ts;
   if(age < -MathMax(0,InpWebIntelMaxFutureSkewSeconds))
   { why=StringFormat("as_of_utc is %d seconds in the future",(int)(-age)); return false; }
   if(age > MathMax(1,InpWebIntelMaxAsOfAgeMinutes)*60)
   { why=StringFormat("as_of_utc is stale by %d minutes",(int)(age/60)); return false; }
   why=StringFormat("as_of_utc age %d seconds",(int)MathMax(0,(long)age));
   return true;
}

string WebIntelJsonSchema()
{
   return "{"
          "\"type\":\"object\","
          "\"properties\":{"
             "\"verdict\":{\"type\":\"string\",\"enum\":[\"CLEAR\",\"WATCH\",\"BLOCK\"]},"
             "\"risk_score\":{\"type\":\"integer\",\"minimum\":0,\"maximum\":100},"
             "\"events\":{\"type\":\"string\"},"
             "\"breaking_news\":{\"type\":\"string\"},"
             "\"invalidation_channel\":{\"type\":\"string\"},"
             "\"intermarket\":{\"type\":\"string\"},"
             "\"sources\":{\"type\":\"string\"},"
             "\"as_of_utc\":{\"type\":\"string\"}"
          "},"
          "\"required\":[\"verdict\",\"risk_score\",\"events\",\"breaking_news\",\"invalidation_channel\",\"intermarket\",\"sources\",\"as_of_utc\"],"
          "\"additionalProperties\":false"
          "}";
}

bool CallOpenAIWebIntelStructured(const string prompt,string &answer,string &verdict,int &riskScore,string &sources,string &errorText)
{
   answer=""; verdict=""; riskScore=0; sources=""; errorText="";
   g_lastWebIntelAnnotationURLs=""; g_lastWebIntelAsOfUTC="";
   g_lastWebIntelHasPrimarySource=false; g_lastWebIntelProvenanceHardFail=false; g_lastWebIntelFailureClass="NONE";
   if(!InpUseLiveWebIntelligence){ g_lastWebIntelFailureClass="UNAVAILABLE"; errorText="Live web intelligence disabled."; return false; }
   if((bool)MQLInfoInteger(MQL_TESTER)){ g_lastWebIntelFailureClass="UNAVAILABLE"; errorText="WebRequest/web search unavailable in Strategy Tester."; return false; }
   if(StringLen(Trim(InpOpenAIAPIKey))<20){ g_lastWebIntelFailureClass="UNAVAILABLE"; errorText="OpenAI API key not configured."; return false; }

   string schema=WebIntelJsonSchema();
   string body="{\"model\":\""+JsonEscape(InpOpenAIModel)+"\","
               "\"tools\":[{\"type\":\"web_search\"}],"
               "\"input\":\""+JsonEscape(prompt+" Return the requested result as strict JSON matching the supplied schema.")+"\","
               "\"text\":{\"format\":{\"type\":\"json_schema\",\"name\":\"market_intelligence\",\"strict\":true,\"schema\":"+schema+"}}}";
   string headers="Content-Type: application/json\r\nAuthorization: Bearer "+InpOpenAIAPIKey+"\r\n";
   char data[],result[]; string resultHeaders="";
   int n=StringToCharArray(body,data,0,WHOLE_ARRAY,CP_UTF8); if(n>0) ArrayResize(data,n-1);
   ResetLastError();
   int code=WebRequest("POST",InpOpenAIEndpoint,headers,InpOpenAITimeoutMs,data,result,resultHeaders);
   if(code==-1){ g_lastWebIntelFailureClass="UNAVAILABLE"; errorText=StringFormat("Structured web-intel WebRequest failed (%d).",GetLastError()); return false; }
   string response=CharArrayToString(result,0,-1,CP_UTF8);
   if(code<200 || code>=300){ g_lastWebIntelFailureClass="UNAVAILABLE"; errorText=StringFormat("Structured web-intel HTTP %d: %s",code,StringSubstr(response,0,500)); return false; }
   int annotationCount=0; bool hasPrimary=false; string annotationURLs="";
   ExtractResponseAnnotationURLs(response,annotationURLs,annotationCount,hasPrimary);
   g_lastWebIntelAnnotationURLs=annotationURLs;
   g_lastWebIntelHasPrimarySource=hasPrimary;
   answer=ExtractOpenAIText(response);
   if(answer=="" || StringFind(answer,"could not be parsed")>=0){ g_lastWebIntelFailureClass="SCHEMA"; errorText="Structured web-intel response text unavailable."; return false; }

   string events="",breaking="",invalidation="",intermarket="",asof="";
   bool ok=(JsonStringFieldSimple(answer,"verdict",verdict) &&
            JsonIntFieldSimple(answer,"risk_score",riskScore) &&
            JsonStringFieldSimple(answer,"events",events) &&
            JsonStringFieldSimple(answer,"breaking_news",breaking) &&
            JsonStringFieldSimple(answer,"invalidation_channel",invalidation) &&
            JsonStringFieldSimple(answer,"intermarket",intermarket) &&
            JsonStringFieldSimple(answer,"sources",sources) &&
            JsonStringFieldSimple(answer,"as_of_utc",asof));
   if(!ok){ g_lastWebIntelFailureClass="SCHEMA"; GVWrite(SysKey("MODEL_SCHEMA_FAIL"),GVRead(SysKey("MODEL_SCHEMA_FAIL"),0)+1); errorText="Structured web-intel JSON failed required-field validation."; return false; }
   StringToUpper(verdict);
   if(verdict!="CLEAR" && verdict!="WATCH" && verdict!="BLOCK")
   { g_lastWebIntelFailureClass="SCHEMA"; GVWrite(SysKey("MODEL_SCHEMA_FAIL"),GVRead(SysKey("MODEL_SCHEMA_FAIL"),0)+1); errorText="Structured web-intel verdict is outside CLEAR/WATCH/BLOCK contract."; return false; }
   if(riskScore<0 || riskScore>100){ g_lastWebIntelFailureClass="SCHEMA"; GVWrite(SysKey("MODEL_SCHEMA_FAIL"),GVRead(SysKey("MODEL_SCHEMA_FAIL"),0)+1); errorText="Structured web-intel risk_score is outside 0-100."; return false; }
   if(InpRequireWebIntelSources && StringLen(Trim(sources))<8)
   {
      GVWrite(SysKey("MODEL_PROV_FAIL"),GVRead(SysKey("MODEL_PROV_FAIL"),0)+1);
      g_lastWebIntelProvenanceHardFail=true; g_lastWebIntelFailureClass="PROVENANCE";
      errorText="PROVENANCE_HARD_FAIL: structured web-intel did not provide source attribution.";
      WriteWebIntelProvenance(asof,annotationURLs,annotationCount,hasPrimary,verdict,riskScore,"FAIL_MODEL_SOURCES");
      return false;
   }

   g_lastWebIntelAsOfUTC=asof;
   string freshWhy="";
   if(!WebIntelAsOfFresh(asof,freshWhy))
   {
      GVWrite(SysKey("MODEL_STALE"),GVRead(SysKey("MODEL_STALE"),0)+1);
      g_lastWebIntelProvenanceHardFail=true; g_lastWebIntelFailureClass="STALE";
      errorText="STALE_AS_OF: "+freshWhy;
      WriteWebIntelProvenance(asof,annotationURLs,annotationCount,hasPrimary,verdict,riskScore,"FAIL_AS_OF");
      return false;
   }
   if(annotationCount<MathMax(1,InpWebIntelMinAnnotationURLs))
   {
      GVWrite(SysKey("MODEL_PROV_FAIL"),GVRead(SysKey("MODEL_PROV_FAIL"),0)+1);
      g_lastWebIntelProvenanceHardFail=true; g_lastWebIntelFailureClass="PROVENANCE";
      errorText=StringFormat("PROVENANCE_HARD_FAIL: Responses payload supplied %d URL annotations; minimum %d.",
                             annotationCount,MathMax(1,InpWebIntelMinAnnotationURLs));
      WriteWebIntelProvenance(asof,annotationURLs,annotationCount,hasPrimary,verdict,riskScore,"FAIL_ANNOTATIONS");
      return false;
   }
   bool highRisk=(riskScore>=InpWebIntelRiskWatchScore || verdict=="WATCH" || verdict=="BLOCK");
   if(InpRequirePrimarySourceForHighRisk && highRisk && !hasPrimary)
   {
      GVWrite(SysKey("MODEL_PROV_FAIL"),GVRead(SysKey("MODEL_PROV_FAIL"),0)+1);
      g_lastWebIntelProvenanceHardFail=true; g_lastWebIntelFailureClass="PROVENANCE";
      errorText="PROVENANCE_HARD_FAIL: high-risk intelligence lacks an authoritative/primary-source URL annotation.";
      WriteWebIntelProvenance(asof,annotationURLs,annotationCount,hasPrimary,verdict,riskScore,"FAIL_PRIMARY");
      return false;
   }
   WriteWebIntelProvenance(asof,annotationURLs,annotationCount,hasPrimary,verdict,riskScore,"PASS");
   g_lastWebIntelFailureClass=(verdict=="BLOCK"?"VERDICT_BLOCK":"NONE");
   GVWrite(SysKey("MODEL_LAST_OK"),(double)TimeTradeServer());

   answer=StringFormat("VERDICT: %s; RISK_SCORE: %d; AS_OF_UTC: %s; EVENTS: %s; BREAKING_NEWS: %s; INVALIDATION_CHANNEL: %s; INTERMARKET: %s; SOURCES: %s; RESPONSE_URL_ANNOTATIONS: %s",
                       verdict,riskScore,asof,events,breaking,invalidation,intermarket,sources,annotationURLs);
   return true;
}

bool GetLiveWebIntelHardened(const string sym,const TradeSetup &s,const StrategyDecision &d,bool force,string &text,bool &block,bool &watch,string &errorText)
{
   text=""; block=false; watch=false; errorText=""; g_lastWebIntelFailureClass="NONE";
   if(!InpUseLiveWebIntelligence){ g_lastWebIntelFailureClass="UNAVAILABLE"; text="Live web intelligence disabled."; return true; }
   if(InpWebIntelHighConfidenceOnly && !force && d.score<InpMinStrategyScore)
   { text="Web search deferred until the candidate reaches the strategy-quality threshold."; return true; }

   int idx=WebIntelCacheIndex(sym),fidx=WebHardFailureIndex(sym);
   datetime now=TimeTradeServer();
   int cacheMins=MathMax(1,MathMin(InpWebIntelRefreshMinutes,InpWebIntelMaxCacheAgeMinutes));
   if(!force && g_webIntelTime[idx]>0 && now-g_webIntelTime[idx]<cacheMins*60)
   {
      text=g_webIntelText[idx]; block=g_webIntelBlock[idx]; watch=g_webIntelWatch[idx]; return true;
   }

   IntermarketReport im=AssessIntermarket(sym,s.bullish);
   string prompt=BuildLiveNewsPrompt(sym,s,d,im);
   bool ok=false; string verdict="",sources=""; int riskScore=0;
   if(InpUseStructuredWebIntel)
      ok=CallOpenAIWebIntelStructured(prompt,text,verdict,riskScore,sources,errorText);

   if(!ok)
   {
      bool highQualityCandidate=(d.action==STRATEGY_ACTION_HIGH_CONFIDENCE || d.score>=InpMinStrategyScore);
      bool hardStructuredFailure=(g_lastWebIntelFailureClass=="SCHEMA" ||
                                  g_lastWebIntelFailureClass=="PROVENANCE" ||
                                  g_lastWebIntelFailureClass=="STALE");
      if((g_lastWebIntelProvenanceHardFail || hardStructuredFailure) && highQualityCandidate)
      {
         g_webHardFailCounts[fidx]++;
         block=true; watch=false;
         text="Structured web intelligence hard-failed "+g_lastWebIntelFailureClass+": "+errorText;
         return false;
      }

      // Compatibility fallback is allowed only for transport/availability-type
      // failures. Schema, stale or provenance failures on a high-quality
      // candidate are semantic integrity failures and cannot be rescued.
      string fallback="",fallbackErr="";
      bool fallbackOK=CallOpenAIWebIntel(prompt,fallback,fallbackErr);
      if(fallbackOK)
      {
         text="UNSTRUCTURED FALLBACK — downgraded confidence. "+fallback;
         InterpretWebIntel(fallback,block,watch);
         g_lastWebIntelFailureClass=(block?"VERDICT_BLOCK":"NONE");
         watch=true;
         g_webHardFailCounts[fidx]++;
      }
      else
      {
         g_webHardFailCounts[fidx]++;
         errorText+=(errorText!=""?" | ":"")+fallbackErr;
         if(g_lastWebIntelFailureClass=="NONE") g_lastWebIntelFailureClass="UNAVAILABLE";
         block=(InpBlockIfWebIntelUnavailable || (InpFailClosedHighConfidenceNews && highQualityCandidate));
         watch=!block;
         text=StringFormat("Live web intelligence unavailable after structured/fallback attempts. Consecutive failures %d/%d. %s",
                           g_webHardFailCounts[fidx],InpWebIntelFailureCircuitThreshold,errorText);
         if(g_webHardFailCounts[fidx]>=InpWebIntelFailureCircuitThreshold)
            text+=" | WEB-INTELLIGENCE CIRCUIT BREAKER OPEN: no silent HIGH-CONFIDENCE authorization without fresh news intelligence.";
         return !block;
      }
   }
   else
   {
      g_webHardFailCounts[fidx]=0;
      block=(verdict=="BLOCK" || riskScore>=InpWebIntelRiskBlockScore);
      if(block) g_lastWebIntelFailureClass="VERDICT_BLOCK";
      watch=(!block && (verdict=="WATCH" || riskScore>=InpWebIntelRiskWatchScore));
   }

   g_webIntelText[idx]=text; g_webIntelBlock[idx]=block; g_webIntelWatch[idx]=watch; g_webIntelTime[idx]=now;
   return true;
}

bool FreshSymbolMovePct(const string sym,ENUM_TIMEFRAMES tf,int bars,double &pct,string &why)
{
   pct=0; why=""; if(sym==""){ why="symbol unavailable"; return false; }
   datetime bt=iTime(sym,tf,1);
   if(bt<=0){ why="no closed bar"; return false; }
   datetime now=TimeTradeServer();
   if(now>bt && now-bt>MathMax(15,InpIntermarketMaxBarAgeMinutes)*60)
   { why=StringFormat("stale closed bar age %d min",(int)((now-bt)/60)); return false; }
   double current=0,old=0;
   if(!CloseValue(sym,tf,1,current) || !CloseValue(sym,tf,MathMax(2,bars+1),old) || old==0)
   { why="insufficient history"; return false; }
   pct=(current-old)/old*100.0; return true;
}

void AddFreshIntermarketComponent(IntermarketReport &r,int &used,const string label,double move,bool bullishEffect,double weight)
{
   AddIntermarketComponent(r,label,move,bullishEffect,weight); used++;
}

IntermarketReport AssessIntermarketHardened(const string target,bool bull)
{
   IntermarketReport r; r.score=0; r.severeConflict=false; r.detail="";
   string key=CanonicalBrokerInstrumentKey(target);
   string dxy=ResolveFirstAlias(InpDXYAliases),vix=ResolveFirstAlias(InpVIXAliases);
   string gold=ResolveFirstAlias(InpGoldAliases),oil=ResolveFirstAlias(InpOilAliases);
   string us100=ResolveFirstAlias(InpUS100Aliases),us500=ResolveFirstAlias(InpUS500Aliases);
   string y10=ResolveBrokerSymbol(InpYieldSymbol);
   double mD=0,mV=0,mY=0,mG=0,mO=0,mN=0,mS=0; string q="";
   bool hD=FreshSymbolMovePct(dxy,PERIOD_M15,InpIntermarketLookbackM15,mD,q);
   bool hV=FreshSymbolMovePct(vix,PERIOD_M15,InpIntermarketLookbackM15,mV,q);
   bool hY=FreshSymbolMovePct(y10,PERIOD_M15,InpIntermarketLookbackM15,mY,q);
   bool hG=FreshSymbolMovePct(gold,PERIOD_M15,InpIntermarketLookbackM15,mG,q);
   bool hO=FreshSymbolMovePct(oil,PERIOD_M15,InpIntermarketLookbackM15,mO,q);
   bool hN=FreshSymbolMovePct(us100,PERIOD_M15,InpIntermarketLookbackM15,mN,q);
   bool hS=FreshSymbolMovePct(us500,PERIOD_M15,InpIntermarketLookbackM15,mS,q);
   int used=0;

   if(StringFind(key,"METAL:XAU")==0 || StringFind(key,"METAL:XAG")==0)
   {
      if(hD) AddFreshIntermarketComponent(r,used,"DXY",mD,bull?(mD<0):(mD>0),35.0);
      if(hY) AddFreshIntermarketComponent(r,used,"US10Y",mY,bull?(mY<0):(mY>0),40.0);
      if(hV) AddFreshIntermarketComponent(r,used,"VIX",mV,bull?(mV>0):(mV<0),18.0);
   }
   else if(StringFind(key,"INDEX:US100")==0 || StringFind(key,"INDEX:US500")==0 || StringFind(key,"INDEX:US30")==0)
   {
      if(hY) AddFreshIntermarketComponent(r,used,"US10Y",mY,bull?(mY<0):(mY>0),45.0);
      if(hV) AddFreshIntermarketComponent(r,used,"VIX",mV,bull?(mV<0):(mV>0),25.0);
      if(hS && target!=us500) AddFreshIntermarketComponent(r,used,"US500",mS,bull?(mS>0):(mS<0),20.0);
   }
   else if(StringFind(key,"INDEX:GER40")==0 || StringFind(key,"INDEX:UK100")==0)
   {
      if(hV) AddFreshIntermarketComponent(r,used,"VIX",mV,bull?(mV<0):(mV>0),20.0);
      if(hN) AddFreshIntermarketComponent(r,used,"US100",mN,bull?(mN>0):(mN<0),18.0);
      if(hS) AddFreshIntermarketComponent(r,used,"US500",mS,bull?(mS>0):(mS<0),18.0);
   }
   else if(StringFind(key,"ENERGY:")==0)
   {
      if(hD) AddFreshIntermarketComponent(r,used,"DXY",mD,bull?(mD<0):(mD>0),22.0);
      if(hS) AddFreshIntermarketComponent(r,used,"US500",mS,bull?(mS>0):(mS<0),12.0);
      if(hO && target!=oil) AddFreshIntermarketComponent(r,used,"WTI",mO,bull?(mO>0):(mO<0),15.0);
   }
   else if(StringFind(key,"FX:")==0)
   {
      string pair=StringSubstr(key,3);
      bool usdBase=(StringSubstr(pair,0,3)=="USD"),usdQuote=(StringSubstr(pair,3,3)=="USD");
      if(hD && (usdBase || usdQuote))
      {
         bool supports=(usdBase?(bull?(mD>0):(mD<0)):(bull?(mD<0):(mD>0)));
         AddFreshIntermarketComponent(r,used,"DXY",mD,supports,35.0);
      }
      if(hY && StringFind(pair,"JPY")>=0)
      {
         bool supports=(usdBase?(bull?(mY>0):(mY<0)):(bull?(mY<0):(mY>0)));
         AddFreshIntermarketComponent(r,used,"US10Y",mY,supports,25.0);
      }
   }
   else if(StringFind(key,"CRYPTO:")==0)
   {
      if(hD) AddFreshIntermarketComponent(r,used,"DXY",mD,bull?(mD<0):(mD>0),20.0);
      if(hV) AddFreshIntermarketComponent(r,used,"VIX",mV,bull?(mV<0):(mV>0),15.0);
      if(hN) AddFreshIntermarketComponent(r,used,"US100",mN,bull?(mN>0):(mN<0),15.0);
   }

   r.score=MathMax(-10,MathMin(10,r.score));
   if(used<InpIntermarketMinFreshComponents)
   {
      r.score=0; r.severeConflict=false;
      r.detail=StringFormat("Intermarket freshness: %d fresh relevant components (<%d required). No confirmation or contradiction is fabricated from stale/closed-market data.",used,InpIntermarketMinFreshComponents);
      return r;
   }
   r.severeConflict=(r.score<=InpIntermarketSevereConflictScore);
   r.detail=StringFormat("Fresh intermarket score %+d/10 from %d component(s) | %s",r.score,used,r.detail);
   return r;
}
#undef ExtractOpenAIText
#define GetLiveWebIntel GetLiveWebIntelHardened
// GPT_EA Part 16A - Strict pre-entry strategy identity revalidation

bool PreEntryIntelligenceRevalidationStrict(const TradeSetup &s,string &why)
{
   StrategyClass expected=(StrategyClass)(int)GVRead(SymKey(s.symbol,"CAND_STRATEGY"),STRATEGY_NO_TRADE);
   MarketStateClass expectedState=(MarketStateClass)(int)GVRead(SymKey(s.symbol,"CAND_STATE"),STATE_UNKNOWN);
   if(expected==STRATEGY_NO_TRADE)
   { why="No stored executable strategy classification exists."; return false; }

   TradeSetup pb=BuildPullback(s.symbol,s.bullish,s.confidence,"");
   TradeSetup br=BuildBreakoutRetest(s.symbol,s.bullish,s.confidence,"");
   StrategyDecision d; SelectDynamicStrategy(s.symbol,pb,br,d);

   if(d.strategy==STRATEGY_NO_TRADE || d.action==STRATEGY_ACTION_NO_TRADE)
   {
      GVWrite(SymKey(s.symbol,"CAND_STRATEGY"),(double)expected);
      GVWrite(SymKey(s.symbol,"CAND_STATE"),(double)expectedState);
      why="Fresh strategy engine now returns NO TRADE.";
      return false;
   }
   if(d.setup.bullish!=s.bullish)
   {
      GVWrite(SymKey(s.symbol,"CAND_STRATEGY"),(double)expected);
      GVWrite(SymKey(s.symbol,"CAND_STATE"),(double)expectedState);
      why="Fresh strategy direction differs from the approved direction.";
      return false;
   }
   if(d.strategy!=expected)
   {
      string change=StrategyClassName(expected)+" -> "+StrategyClassName(d.strategy);
      GVWrite(SymKey(s.symbol,"CAND_STRATEGY"),(double)expected);
      GVWrite(SymKey(s.symbol,"CAND_STATE"),(double)expectedState);
      why="Strategy classification changed during approval: "+change+". Reanalyze instead of executing stale authorization.";
      return false;
   }

   IntermarketReport im=AssessIntermarket(s.symbol,s.bullish);
   if(im.severeConflict)
   { why="Severe intermarket contradiction: "+im.detail; return false; }

   string web="",err=""; bool block=false,watch=false;
   bool webOK=GetLiveWebIntel(s.symbol,s,d,true,web,block,watch,err);
   string emergencyWebWhy="";
   bool emergencyWebBypass=(!webOK && g_lastWebIntelFailureClass=="UNAVAILABLE" &&
                            DeterministicEmergencyExecutionActive(s.symbol,expected,emergencyWebWhy));
   if((!webOK && !emergencyWebBypass) || (webOK && InpBlockOnWebIntelVerdictBLOCK && block))
   { why="Live news/web intelligence invalidated execution: "+web+" | class "+g_lastWebIntelFailureClass; return false; }
   if(emergencyWebBypass)
   {
      block=false; watch=true;
      web="DETERMINISTIC_ONLY external-intelligence transport outage bypass | "+emergencyWebWhy+" | "+web;
   }

   string cal=""; if(CalendarBlock(s.symbol,cal)){ why="Economic calendar now blocks execution: "+cal; return false; }
   string yield=""; if(YieldShock(yield)){ why="Treasury-yield shock now blocks execution: "+yield; return false; }

   string ev="";
   if(!StrategyEvidenceAllows(expected,ev)){ why="Historical strategy evidence gate changed to BLOCK: "+ev; return false; }

   // Keep the original approved class, but refresh time/state only after identity is proven stable.
   GVWrite(SymKey(s.symbol,"CAND_STRATEGY"),(double)expected);
   GVWrite(SymKey(s.symbol,"CAND_STATE"),(double)d.state);
   GVWrite(SymKey(s.symbol,"CAND_SCORE"),(double)d.score);
   GVWrite(SymKey(s.symbol,"CAND_TIME"),(double)TimeTradeServer());
   why="Strict pre-entry intelligence PASS | "+StrategyClassName(expected)+" remains valid | "+MarketStateName(d.state)+" | "+im.detail+
       (emergencyWebBypass?" | deterministic-only transport fallback":(watch?" | web WATCH":" | web CLEAR"));
   return true;
}
#define PreEntryIntelligenceRevalidation PreEntryIntelligenceRevalidationStrict
// GPT_EA Part 17 - Mandatory 25-point trade thesis and GPT critique engine

string MultiTFAlignmentText(const string sym,bool bull)
{
   ENUM_TIMEFRAMES tf[6]={PERIOD_D1,PERIOD_H4,PERIOD_H1,PERIOD_M30,PERIOD_M15,PERIOD_M5};
   string nm[6]={"D1","H4","H1","M30","M15","M5"};
   string out="";
   for(int i=0;i<6;i++)
   {
      int v=TrendVote(sym,tf[i],bull);
      if(i>0) out+=" | ";
      out+=nm[i]+":"+(v>0?"ALIGNED":v<0?"OPPOSED":"NEUTRAL");
   }
   return out;
}

string PriceInvalidationText(const TradeSetup &s)
{
   return StringFormat("Immediate price invalidation: %.*f plus the stated structural close/acceptance failure. %s",
      DigitsFor(s.symbol),s.sl,s.invalidation);
}

string TargetLogicText(const TradeSetup &s,const StrategySnapshot &x)
{
   return StringFormat("TP1 %.*f, TP2 %.*f, TP3 %.*f. Objectives are checked against prior/session liquidity %.5f/%.5f, prior-day %.5f/%.5f and current range %.5f/%.5f rather than arbitrary pip distances.",
      DigitsFor(s.symbol),s.tp1,DigitsFor(s.symbol),s.tp2,DigitsFor(s.symbol),s.tp3,
      x.asianHigh,x.asianLow,x.previousDayHigh,x.previousDayLow,x.priorHigh,x.priorLow);
}

string LiquidityFakeoutText(const StrategySnapshot &x)
{
   return StringFormat("Bull sweep %s | Bear sweep %s | False break up/down %s/%s | Asian H/L %.5f/%.5f | Previous-day H/L %.5f/%.5f. Thin/opening volatility risk rises when OR is %.2fx ATR.",
      x.bullishSweep?"YES":"NO",x.bearishSweep?"YES":"NO",x.falseBreakUp?"YES":"NO",x.falseBreakDown?"YES":"NO",
      x.asianHigh,x.asianLow,x.previousDayHigh,x.previousDayLow,x.openingRangeRatio);
}

string VolatilityThesisText(const StrategySnapshot &x)
{
   return StringFormat("M15 ATR %.5f versus trailing ATR %.5f = %.2fx; opening range %.2fx ATR; regime %s. High volatility requires wider structural tolerance and faster invalidation; compression requires smaller target expectations until expansion confirms.",
      x.atr,x.atrAverage,x.atrRatio,x.openingRangeRatio,x.baseRegime);
}

string BuildMandatory25PointThesis(const string sym,TradeSetup &primary,TradeSetup &pb,TradeSetup &br,
                                   const StrategyDecision &d,const ConfluenceReport &c,
                                   const string calendarText,const string webText,const IntermarketReport &im,
                                   const string spreadText,const string sessionText)
{
   StrategySnapshot x; BuildStrategySnapshot(sym,x);
   string s="\n━━━━━━━━━━━━━━━━━━━━\n📚 MANDATORY 25-POINT TRADE THESIS\n━━━━━━━━━━━━━━━━━━━━\n";
   s+="1. Multi-Timeframe Alignment: "+MultiTFAlignmentText(sym,primary.bullish)+". HTF context establishes bias; M15/M5 are execution layers.\n";
   s+="2. Market Regime: "+d.regime+" / "+d.stateText+". "+d.rationale+"\n";
   s+=StringFormat("3. Market Structure: M15 bullish/bearish structure %s/%s; LTF bullish/bearish break %s/%s; CHOCH against trend %s; compression %s; expansion %s.\n",
      x.m15BullStructure?"YES":"NO",x.m15BearStructure?"YES":"NO",x.ltfBullBreak?"YES":"NO",x.ltfBearBreak?"YES":"NO",x.chochAgainstTrend?"YES":"NO",x.compression?"YES":"NO",x.expansion?"YES":"NO");
   s+="4. Strategy Selection: "+d.strategyName+" selected from the regime-driven library. "+d.librarySummary+"\n";
   s+="5. Trend vs Retracement Assessment: current state is "+d.stateText+". HTF dominant direction is "+(x.dominantBull?"BULLISH":"BEARISH")+"; trend failure="+(x.trendFailure?"YES":"NO")+".\n";
   s+=StringFormat("6. Entry Logic: zone %.*f-%.*f around preferred %.*f. %s\n",DigitsFor(sym),primary.zoneLow,DigitsFor(sym),primary.zoneHigh,DigitsFor(sym),primary.preferred,primary.reason);
   s+="7. Confirmation Logic: "+d.confirmation+" Execution rule: "+primary.executionRule+"\n";
   s+=StringFormat("8. Stop-Loss Logic: SL %.*f sits beyond the structural thesis invalidation rather than using a fixed pip distance. %s\n",DigitsFor(sym),primary.sl,primary.invalidation);
   s+="9. Take-Profit Logic: "+TargetLogicText(primary,x)+"\n";
   s+=StringFormat("10. Risk-to-Reward Analysis: theoretical geometry %.2fR to TP1 family; realistic effective R:R to TP2 after spread/slippage %.2f. %s Partials at TP1/TP2 alter realized portfolio R and are tracked in analytics.\n",
      primary.nominalRR1,EffectiveRRDynamic(primary),spreadText);
   s+="11. Pullback vs Breakout-Retest Analysis: Pullback => "+SetupSummaryLine(pb)+"; Breakout-Retest => "+SetupSummaryLine(br)+". Pullback failure is acceptance through value/structure; breakout-retest failure is a false break and return inside the old range.\n";
   s+="12. Counter-Trend Assessment: "+(d.counterTrend?("COUNTER-TREND TRADE. Score "+IntegerToString(d.counterTrendScore)+"/100; strict sweep + CHOCH/BOS + rejection confirmation required, with more conservative targets."):"Trade is not classified as counter-trend against dominant HTF structure.")+"\n";
   s+="13. Liquidity & Fakeout Assessment: "+LiquidityFakeoutText(x)+"\n";
   s+="14. Volatility Analysis: "+VolatilityThesisText(x)+"\n";
   s+="15. News Risk Assessment: Scheduled calendar => "+calendarText+" | Live web intelligence => "+webText+"\n";
   s+="16. Treasury-Yield & Intermarket Analysis: "+im.detail+"; dedicated yield-shock filter is also checked independently before authorization.\n";
   s+="17. Session Analysis: "+d.session+". "+sessionText+" Session/previous-day/Asian highs-lows are treated as liquidity objectives and fakeout locations.\n";
   s+=StringFormat("18. Time-Based Invalidation: base setup expiry %d M15 candles; AdaptiveExpiry() shortens fast/high-ATR or oversized-opening-range setups and extends slow regimes within safety bounds. Breakouts demand faster follow-through than swing retracements.\n",primary.expiryM15);
   s+="19. Price-Based Invalidation: "+PriceInvalidationText(primary)+"\n";
   s+="20. Counterargument Analysis: "+d.counterargument+" Ask explicitly: could liquidity run the opposite side first, is this a retracement mistaken for reversal, is this breakout actually a sweep, is price overextended, and does effective R:R still survive costs?\n";
   s+="21. Setup Quality Filtering: strategy action is "+(d.action==STRATEGY_ACTION_HIGH_CONFIDENCE?"HIGH-CONFIDENCE TRADE SETUP":d.action==STRATEGY_ACTION_WAIT?"WAIT FOR CONFIRMATION":"NO TRADE")+". Contradictory/marginal evidence is not forced into a signal.\n";
   s+=StringFormat("22. Confidence Validation: strategy %d/100 | advanced confluence %d/100 | HTF votes %d/3 | ADX %.1f | volume %.2fx | spread %s. Confidence is multi-factor, not a single-indicator label.\n",
      d.score,c.score,c.htfVotes,c.adx,c.volumeRatio,c.spreadOK?"OK":"BLOCK");
   s+="23. Historical Strategy Validation: "+d.evidence+" Contextual strategy stats are accumulated by strategy/state/direction/volatility. Historical/forward evidence is treated as evidence, never as a guarantee.\n";
   s+="24. Pre-Entry Revalidation: immediately before execution the EA re-checks strategy identity, D1/H4/H1/M30/M15/M5 data freshness, current zone/trigger, spread, ATR/opening range, calendar, live web news, Treasury yields, intermarket conflict, release/risk/broker gates and original invalidation. Changed conditions cancel the setup.\n";
   s+="25. Detailed Trade Thesis: The trade exists because "+d.strategyName+" matches "+d.stateText+" with the stated structure/confluence. Entry requires "+d.confirmation+" SL invalidates the thesis at structure, targets follow liquidity/structural objectives, failure channels are explicitly listed, and execution is authorized only if realistic reward still justifies total risk.\n";
   return s;
}

string BuildDeepGPTPrompt(const string sym,const string card,const string thesis,const string webIntel,const StrategyDecision &d)
{
   return "You are the secondary adversarial validation layer for a MetaTrader EA. The broker-derived technical data, strategy classification and live-news intelligence below are authoritative inputs. "
          "Do not invent prices, economic events, yields, headlines or statistics. Actively try to DISPROVE the proposed trade before validating it. "
          "Confirm that the classification distinguishes trend continuation, retracement/correction, counter-trend movement, reversal, breakout/retest/fakeout, sweep, range, mean reversion, momentum, exhaustion and consolidation correctly. "
          "If the trade is counter-trend, demand stronger evidence and conservative objectives. If evidence is insufficient say WAIT; if invalid say NO TRADE/INVALID; only say VALID when independent evidence genuinely aligns. "
          "Return compact lines: VERDICT: VALID|WAIT|INVALID; CLASSIFICATION: ...; STRATEGY: ...; MTF: ...; RETRACEMENT_OR_REVERSAL: ...; COUNTER_TREND: ...; ENTRY_CONFIRMATION: ...; "
          "SL_LOGIC: ...; TARGET_LOGIC: ...; RR_AFTER_COSTS: ...; LIQUIDITY_FAKEOUT: ...; VOLATILITY: ...; NEWS: ...; INTERMARKET: ...; COUNTERARGUMENT: ...; TIME_INVALIDATION: ...; PRICE_INVALIDATION: ...; EXECUTION_WARNING: ... .\n"
          "Symbol: "+sym+"\nSelected strategy: "+d.strategyName+"\nSignal card:\n"+card+"\nMandatory thesis:\n"+thesis+"\nLive web intelligence:\n"+webIntel;
}
// GPT_EA Part 25 - Thesis hardening and explicit disproof/RR comparison

string DeterministicDisproofChecklist(const StrategySnapshot &x,const StrategyDecision &d,const TradeSetup &s)
{
   string out="Disproof checklist: ";
   out+=(x.trendFailure?"trend failure already detected; ":"HTF structure not yet failed; ");
   out+=(x.falseBreakUp||x.falseBreakDown?"false-break evidence present; ":"no current false-break flag; ");
   out+=(x.exhaustion?"exhaustion present; ":"no exhaustion flag; ");
   out+=(ChaseRiskDetected(x)?"entry is vulnerable to chasing; ":"chase filter clear; ");
   out+=(d.counterTrend?"counter-trend thesis requires strict sweep/BOS/rejection; ":"direction is not classified counter-trend; ");
   out+=StringFormat("SL invalidation %.5f; strategy score %d/100.",s.sl,d.score);
   return out;
}

string BuildMandatory25PointThesisFinal(const string sym,TradeSetup &primary,TradeSetup &pb,TradeSetup &br,
                                        const StrategyDecision &d,const ConfluenceReport &c,
                                        const string calendarText,const string webText,const IntermarketReport &im,
                                        const string spreadText,const string sessionText)
{
   string thesis=BuildMandatory25PointThesis(sym,primary,pb,br,d,c,calendarText,webText,im,spreadText,sessionText);
   StrategySnapshot x; BuildStrategySnapshot(sym,x);
   RealisticRRReport pbr=RealisticRiskReward(pb);
   RealisticRRReport brr=RealisticRiskReward(br);
   RealisticRRReport pr=RealisticRiskReward(primary);

   thesis+="\n━━━━━━━━━━━━━━━━━━━━\n🔬 EXECUTION / RESEARCH HARDENING ADDENDUM\n━━━━━━━━━━━━━━━━━━━━\n";
   thesis+="Retracement model: "+RetracementIntelligenceText(x)+"\n";
   thesis+="Pullback realistic execution: "+pbr.detail+"\n";
   thesis+="Breakout-retest realistic execution: "+brr.detail+"\n";
   thesis+="Selected setup realistic execution: "+pr.detail+"\n";
   thesis+="Comparison rule: choose neither setup merely because its theoretical R multiple is larger. The executable setup must retain structure, trigger quality and weighted R:R after spread, slippage, commission and partial exits.\n";
   thesis+="Strategy-specific candle invalidation: "+IntegerToString(primary.expiryM15)+" M15 candles for the currently selected strategy after ATR/opening-range adaptation; breakout/counter-trend scalp setups require faster follow-through than retracement/swing setups.\n";
   thesis+="Historical/context/walk-forward validation: "+d.evidence+"\n";
   thesis+=DeterministicDisproofChecklist(x,d,primary)+"\n";
   thesis+="News freshness contract: a HIGH-CONFIDENCE authorization must not silently rely on unavailable/stale live-news intelligence when fail-closed high-confidence news mode is enabled. Intermarket contradiction is accepted only from fresh broker bars.\n";
   return thesis;
}
#define ExtractOpenAIText ExtractOpenAITextWide
// GPT_EA Part 26 - Deep GPT policy for final adversarial validation

input bool   InpUseDeepGPTReviewModel       = true;
input string InpDeepGPTReviewModel          = "gpt-5.6-sol";
input string InpDeepGPTReasoningEffort      = "high";
input int    InpDeepGPTMaxOutputTokens      = 1200;

string ValidReasoningEffort(string effort)
{
   StringToLower(effort);
   if(effort=="none" || effort=="low" || effort=="medium" || effort=="high" ||
      effort=="xhigh" || effort=="max") return effort;
   return "high";
}

bool CallOpenAIDeep(const string prompt,string &answer,string &errorText)
{
   answer=""; errorText="";
   if(!InpUseOpenAI){ errorText="OpenAI disabled."; return false; }
   if((bool)MQLInfoInteger(MQL_TESTER)){ errorText="WebRequest unavailable in Strategy Tester."; return false; }
   if(StringLen(Trim(InpOpenAIAPIKey))<20){ errorText="OpenAI API key not configured in EA inputs."; return false; }

   string model=(InpUseDeepGPTReviewModel?Trim(InpDeepGPTReviewModel):Trim(InpOpenAIModel));
   if(model=="") model=InpOpenAIModel;
   string effort=ValidReasoningEffort(InpDeepGPTReasoningEffort);
   int maxTokens=(InpDeepGPTMaxOutputTokens<200?200:InpDeepGPTMaxOutputTokens);
   string body="{\"model\":\""+JsonEscape(model)+"\","
               "\"reasoning\":{\"effort\":\""+JsonEscape(effort)+"\"},"
               "\"max_output_tokens\":"+IntegerToString(maxTokens)+","
               "\"input\":\""+JsonEscape(prompt)+"\"}";
   string headers="Content-Type: application/json\r\nAuthorization: Bearer "+InpOpenAIAPIKey+"\r\n";
   char data[],result[]; string resultHeaders="";
   int n=StringToCharArray(body,data,0,WHOLE_ARRAY,CP_UTF8); if(n>0) ArrayResize(data,n-1);

   ResetLastError();
   int code=WebRequest("POST",InpOpenAIEndpoint,headers,InpOpenAITimeoutMs,data,result,resultHeaders);
   if(code==-1)
   {
      errorText=StringFormat("Deep GPT WebRequest failed (%d). Add https://api.openai.com to MT5 WebRequest allow-list.",GetLastError());
      return false;
   }
   string json=CharArrayToString(result,0,-1,CP_UTF8);
   if(code<200 || code>=300)
   {
      errorText=StringFormat("Deep GPT HTTP %d: %s",code,StringSubstr(json,0,600));
      return false;
   }
   answer=ExtractOpenAIText(json);
   if(answer=="" || StringFind(answer,"could not be parsed")>=0)
   {
      errorText="Deep GPT response text unavailable.";
      return false;
   }
   return true;
}
#undef ExtractOpenAIText
#undef WebRequest
#undef InpOpenAIAPIKey

// GPT_EA Part 40 - Clock integrity, model degradation and deterministic fallback

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
         "contradictions","latency_ewma_ms","last_latency_ms","clock_offset_seconds","clock_drift_seconds","note");
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

bool DeterministicEmergencyExecutionActive(const string sym,int strategyValue,string &why)
{
   why="";
   StrategyClass c=(StrategyClass)strategyValue;
   string health="";
   int mode=CurrentModelTrustMode(health);
   if(mode!=MODEL_TRUST_DETERMINISTIC_ONLY)
   { why=health+" | deterministic-only mode not active"; return false; }
   string det="";
   if(!DeterministicEmergencyStrategyAllowed(sym,c,det))
   { why=health+" | "+det; return false; }
   why=health+" | "+det;
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
      DoubleToString(GVRead(SysKey("MODEL_LATENCY_EWMA_MS"),0),0),DoubleToString(GVRead(SysKey("MODEL_LAST_LATENCY_MS"),0),0),
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
// GPT_EA Part 41 - Portfolio scenario stress, gap/margin risk and decision age

input bool   InpUsePortfolioScenarioStress       = true;
input double InpMaxScenarioStressLossPctEquity   = 4.00;
input double InpStressIndexShockPct              = 2.00;
input double InpStressFXShockPct                 = 1.00;
input double InpStressMetalShockPct              = 2.00;
input double InpStressEnergyShockPct             = 4.00;
input double InpStressCryptoShockPct             = 5.00;
input double InpStressOtherShockPct              = 1.50;
input bool   InpUseMacroScenarioStress            = true;
input double InpStressUSDStrengthPct              = 1.00;
input double InpStressYieldShockBps               = 20.0;
input double InpStressYieldIndexEffectPct         = 1.50;
input double InpStressYieldGoldEffectPct          = 1.00;
input double InpStressYieldCryptoEffectPct        = 2.00;
input double InpStressEquityRiskOffPct            = 2.00;
input double InpStressVolatilityIndexDropPct      = 3.00;
input double InpStressCorrelatedGapMultiplier     = 1.50;
input bool   InpUseGapRiskSizingGate             = true;
input double InpMaxGapLossMultipleOfPlannedRisk  = 2.00;
input bool   InpUseMarginStressGate              = true;
input double InpMinimumStressedMarginLevelPct    = 250.0;
input bool   InpUseDecisionHalfLife              = true;
input bool   InpUseExecutionLatencyBudget        = true;
input double InpMaxLatencyBudgetFraction         = 0.35;

enum PortfolioStressScenario
{
   PORT_STRESS_USD_UP=0,
   PORT_STRESS_YIELDS_UP=1,
   PORT_STRESS_EQUITY_RISK_OFF=2,
   PORT_STRESS_GOLD_UP=3,
   PORT_STRESS_GOLD_DOWN=4,
   PORT_STRESS_OIL_UP=5,
   PORT_STRESS_OIL_DOWN=6,
   PORT_STRESS_VOLATILITY_SPIKE=7,
   PORT_STRESS_CORRELATED_GAP_DOWN=8,
   PORT_STRESS_CORRELATED_GAP_UP=9
};

string PortfolioStressScenarioName(int scenario)
{
   switch(scenario)
   {
      case PORT_STRESS_USD_UP: return StringFormat("USD +%.2f%%",InpStressUSDStrengthPct);
      case PORT_STRESS_YIELDS_UP: return StringFormat("YIELDS +%.0f bps",InpStressYieldShockBps);
      case PORT_STRESS_EQUITY_RISK_OFF: return StringFormat("EQUITY INDICES -%.2f%%",InpStressEquityRiskOffPct);
      case PORT_STRESS_GOLD_UP: return StringFormat("GOLD +%.2f%%",InpStressMetalShockPct);
      case PORT_STRESS_GOLD_DOWN: return StringFormat("GOLD -%.2f%%",InpStressMetalShockPct);
      case PORT_STRESS_OIL_UP: return StringFormat("OIL +%.2f%%",InpStressEnergyShockPct);
      case PORT_STRESS_OIL_DOWN: return StringFormat("OIL -%.2f%%",InpStressEnergyShockPct);
      case PORT_STRESS_VOLATILITY_SPIKE: return "VOLATILITY SPIKE";
      case PORT_STRESS_CORRELATED_GAP_DOWN: return "CORRELATED GAP RISK-OFF";
      case PORT_STRESS_CORRELATED_GAP_UP: return "CORRELATED GAP RISK-ON";
   }
   return "UNKNOWN";
}

double FXUSDScenarioShockPct(const string sym,double usdStrengthPct)
{
   string key=CanonicalBrokerInstrumentKey(sym);
   if(StringFind(key,"FX:")!=0 || StringLen(key)<9) return 0.0;
   string pair=StringSubstr(key,3,6);
   if(StringLen(pair)!=6) return 0.0;
   string base=StringSubstr(pair,0,3),quote=StringSubstr(pair,3,3);
   if(base=="USD") return usdStrengthPct;
   if(quote=="USD") return -usdStrengthPct;
   return 0.0;
}

double MacroScenarioShockPct(const string sym,int scenario)
{
   string cls=StressAssetClass(sym);
   string key=CanonicalBrokerInstrumentKey(sym);
   double gap=MathMax(1.0,InpStressCorrelatedGapMultiplier);

   if(scenario==PORT_STRESS_USD_UP)
   {
      if(cls=="FX") return FXUSDScenarioShockPct(sym,InpStressUSDStrengthPct);
      if(cls=="METAL") return -0.75*InpStressUSDStrengthPct;
      if(cls=="CRYPTO") return -1.50*InpStressUSDStrengthPct;
      if(cls=="STOCK" || cls=="ETF" || cls=="FUTURE") return -0.50*InpStressUSDStrengthPct;
      if(cls=="COMMODITY") return -0.75*InpStressUSDStrengthPct;
      return 0.0;
   }

   if(scenario==PORT_STRESS_YIELDS_UP)
   {
      double scale=MathMax(0.10,InpStressYieldShockBps/20.0);
      if(cls=="INDEX" || cls=="STOCK" || cls=="ETF" || cls=="FUTURE") return -InpStressYieldIndexEffectPct*scale;
      if(cls=="METAL") return -InpStressYieldGoldEffectPct*scale;
      if(cls=="CRYPTO") return -InpStressYieldCryptoEffectPct*scale;
      if(cls=="FX") return FXUSDScenarioShockPct(sym,0.40*scale);
      if(cls=="ENERGY") return -0.40*scale;
      return 0.0;
   }

   if(scenario==PORT_STRESS_EQUITY_RISK_OFF)
   {
      if(cls=="INDEX" || cls=="STOCK" || cls=="ETF" || cls=="FUTURE") return -InpStressEquityRiskOffPct;
      if(cls=="CRYPTO") return -MathMax(InpStressCryptoShockPct,InpStressEquityRiskOffPct*1.75);
      if(cls=="ENERGY") return -MathMax(2.0,InpStressEquityRiskOffPct);
      if(cls=="COMMODITY") return -MathMax(1.5,InpStressEquityRiskOffPct*0.75);
      if(cls=="METAL") return (StringFind(key,"METAL:XAU")==0?1.00:0.50);
      if(cls=="FX") return FXUSDScenarioShockPct(sym,0.50);
      return 0.0;
   }

   if(scenario==PORT_STRESS_GOLD_UP)
      return (StringFind(key,"METAL:XAU")==0?MathAbs(InpStressMetalShockPct):0.0);
   if(scenario==PORT_STRESS_GOLD_DOWN)
      return (StringFind(key,"METAL:XAU")==0?-MathAbs(InpStressMetalShockPct):0.0);
   if(scenario==PORT_STRESS_OIL_UP)
      return (cls=="ENERGY"?MathAbs(InpStressEnergyShockPct):0.0);
   if(scenario==PORT_STRESS_OIL_DOWN)
      return (cls=="ENERGY"?-MathAbs(InpStressEnergyShockPct):0.0);

   if(scenario==PORT_STRESS_VOLATILITY_SPIKE)
   {
      string u=sym; StringToUpper(u);
      if(StringFind(u,"VIX")>=0 || StringFind(u,"VOLATILITY")>=0) return 40.0;
      if(cls=="INDEX" || cls=="STOCK" || cls=="ETF" || cls=="FUTURE") return -MathAbs(InpStressVolatilityIndexDropPct);
      if(cls=="CRYPTO") return -MathMax(5.0,InpStressCryptoShockPct);
      if(cls=="ENERGY") return -MathMax(3.0,InpStressEnergyShockPct*0.75);
      if(cls=="METAL") return (StringFind(key,"METAL:XAU")==0?1.50:0.75);
      if(cls=="FX") return FXUSDScenarioShockPct(sym,0.75);
      return 0.0;
   }

   if(scenario==PORT_STRESS_CORRELATED_GAP_DOWN)
   {
      if(cls=="INDEX" || cls=="STOCK" || cls=="ETF" || cls=="FUTURE") return -InpStressIndexShockPct*gap;
      if(cls=="CRYPTO") return -InpStressCryptoShockPct*gap;
      if(cls=="ENERGY" || cls=="COMMODITY") return -InpStressEnergyShockPct*gap;
      if(cls=="METAL") return (StringFind(key,"METAL:XAU")==0?InpStressMetalShockPct:0.5*InpStressMetalShockPct);
      if(cls=="FX") return FXUSDScenarioShockPct(sym,InpStressUSDStrengthPct*gap);
      return -InpStressOtherShockPct*gap;
   }

   if(scenario==PORT_STRESS_CORRELATED_GAP_UP)
   {
      if(cls=="INDEX" || cls=="STOCK" || cls=="ETF" || cls=="FUTURE") return InpStressIndexShockPct*gap;
      if(cls=="CRYPTO") return InpStressCryptoShockPct*gap;
      if(cls=="ENERGY" || cls=="COMMODITY") return InpStressEnergyShockPct*gap;
      if(cls=="METAL") return -InpStressMetalShockPct;
      if(cls=="FX") return FXUSDScenarioShockPct(sym,-InpStressUSDStrengthPct*gap);
      return InpStressOtherShockPct*gap;
   }
   return 0.0;
}

double ScenarioPositionPnLMoney(ulong ticket,int scenario)
{
   if(ticket==0 || !PositionSelectByTicket(ticket)) return 0.0;
   string sym=PositionGetString(POSITION_SYMBOL);
   double shock=MacroScenarioShockPct(sym,scenario);
   if(MathAbs(shock)<0.000001) return 0.0;
   long type=PositionGetInteger(POSITION_TYPE);
   double entry=PositionGetDouble(POSITION_PRICE_OPEN);
   double vol=PositionGetDouble(POSITION_VOLUME);
   double stressed=entry*(1.0+shock/100.0);
   double pnl=0;
   ENUM_ORDER_TYPE ot=(type==POSITION_TYPE_BUY?ORDER_TYPE_BUY:ORDER_TYPE_SELL);
   if(!OrderCalcProfit(ot,sym,vol,entry,stressed,pnl)) return 0.0;
   return pnl;
}

double ScenarioProposedPnLMoney(const TradeSetup &s,double lots,int scenario)
{
   double shock=MacroScenarioShockPct(s.symbol,scenario);
   if(MathAbs(shock)<0.000001) return 0.0;
   double stressed=s.preferred*(1.0+shock/100.0);
   double pnl=0;
   ENUM_ORDER_TYPE ot=(s.bullish?ORDER_TYPE_BUY:ORDER_TYPE_SELL);
   if(!OrderCalcProfit(ot,s.symbol,lots,s.preferred,stressed,pnl)) return 0.0;
   return pnl;
}

double WorstMacroScenarioPortfolioLoss(const TradeSetup &s,double lots,string &worstName)
{
   worstName="none";
   if(!InpUseMacroScenarioStress) return 0.0;
   double worst=0.0;
   for(int scenario=PORT_STRESS_USD_UP;scenario<=PORT_STRESS_CORRELATED_GAP_UP;scenario++)
   {
      double pnl=ScenarioProposedPnLMoney(s,lots,scenario);
      for(int i=PositionsTotal()-1;i>=0;i--)
      {
         ulong tk=PositionGetTicket(i); if(tk==0 || !PositionSelectByTicket(tk)) continue;
         if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
         pnl+=ScenarioPositionPnLMoney(tk,scenario);
      }
      double loss=MathMax(0.0,-pnl);
      if(loss>worst)
      {
         worst=loss;
         worstName=PortfolioStressScenarioName(scenario);
      }
   }
   return worst;
}

double WorstMacroScenarioProposedLoss(const TradeSetup &s,double lots,string &worstName)
{
   worstName="none";
   if(!InpUseMacroScenarioStress) return 0.0;
   double worst=0.0;
   for(int scenario=PORT_STRESS_USD_UP;scenario<=PORT_STRESS_CORRELATED_GAP_UP;scenario++)
   {
      double loss=MathMax(0.0,-ScenarioProposedPnLMoney(s,lots,scenario));
      if(loss>worst){ worst=loss; worstName=PortfolioStressScenarioName(scenario); }
   }
   return worst;
}

string StressAssetClass(const string sym)
{
   return AssetClassFromCanonical(CanonicalBrokerInstrumentKey(sym));
}

double StressShockPct(const string sym)
{
   string cls=StressAssetClass(sym);
   if(cls=="INDEX" || cls=="STOCK" || cls=="ETF" || cls=="FUTURE") return InpStressIndexShockPct;
   if(cls=="FX") return InpStressFXShockPct;
   if(cls=="METAL") return InpStressMetalShockPct;
   if(cls=="ENERGY" || cls=="COMMODITY") return InpStressEnergyShockPct;
   if(cls=="CRYPTO") return InpStressCryptoShockPct;
   if(cls=="BOND_RATE") return MathMax(InpStressFXShockPct,InpStressOtherShockPct);
   return InpStressOtherShockPct;
}

StrategyClass StressCandidateStrategyForSymbol(const string sym)
{
   int c=(int)GVRead(SymKey(sym,"PLAN_STRATEGY"),STRATEGY_NO_TRADE);
   if(c<=0) c=(int)GVRead(SymKey(sym,"CAND_STRATEGY"),STRATEGY_NO_TRADE);
   return (StrategyClass)c;
}

int StrategyDecisionHalfLifeSeconds(StrategyClass c)
{
   switch(c)
   {
      case STRATEGY_BREAKOUT: return 120;
      case STRATEGY_BREAKOUT_RETEST: return 300;
      case STRATEGY_COUNTER_TREND_SCALP: return 180;
      case STRATEGY_COUNTER_TREND_SWING: return 480;
      case STRATEGY_POTENTIAL_REVERSAL: return 600;
      case STRATEGY_RETRACEMENT_ENTRY: return 900;
      case STRATEGY_RANGE_TRADE: return 600;
      case STRATEGY_MEAN_REVERSION: return 600;
      case STRATEGY_TREND_CONTINUATION: return 1200;
      default: return 300;
   }
}

double PositionStressLossMoney(ulong ticket)
{
   if(ticket==0 || !PositionSelectByTicket(ticket)) return 0;
   string sym=PositionGetString(POSITION_SYMBOL);
   long type=PositionGetInteger(POSITION_TYPE);
   double entry=PositionGetDouble(POSITION_PRICE_OPEN);
   double vol=PositionGetDouble(POSITION_VOLUME);
   double shock=MathMax(0.10,StressShockPct(sym))/100.0;
   double stressed=(type==POSITION_TYPE_BUY?entry*(1.0-shock):entry*(1.0+shock));
   double pnl=0;
   ENUM_ORDER_TYPE ot=(type==POSITION_TYPE_BUY?ORDER_TYPE_BUY:ORDER_TYPE_SELL);
   if(!OrderCalcProfit(ot,sym,vol,entry,stressed,pnl)) return 0;
   return MathMax(0.0,-pnl);
}

double ProposedStressLossMoney(const TradeSetup &s,double lots)
{
   double shock=MathMax(0.10,StressShockPct(s.symbol))/100.0;
   double entry=s.preferred;
   double stressed=(s.bullish?entry*(1.0-shock):entry*(1.0+shock));
   double pnl=0;
   ENUM_ORDER_TYPE ot=(s.bullish?ORDER_TYPE_BUY:ORDER_TYPE_SELL);
   if(!OrderCalcProfit(ot,s.symbol,lots,entry,stressed,pnl)) return 0;
   return MathMax(0.0,-pnl);
}

double CurrentPortfolioScenarioStressLoss()
{
   double loss=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0) continue;
      loss+=PositionStressLossMoney(tk);
   }
   return loss;
}

bool GapRiskAllows(const TradeSetup &s,double lots,string &why)
{
   why="";
   if(!InpUseGapRiskSizingGate){ why="gap-risk gate disabled"; return true; }
   double planned=ProposedRiskMoney(s,lots);
   if(planned<=0){ why="planned stop risk unavailable"; return false; }
   double gap=ProposedStressLossMoney(s,lots);
   string macroName="";
   double macro=WorstMacroScenarioProposedLoss(s,lots,macroName);
   if(macro>gap) gap=macro;
   double multiple=gap/planned;
   why=StringFormat("gap/scenario loss %.2f vs planned %.2f = %.2fx | worst macro %s %.2f",
                    gap,planned,multiple,macroName,macro);
   return multiple<=MathMax(1.0,InpMaxGapLossMultipleOfPlannedRisk);
}

bool MarginStressAllows(const TradeSetup &s,double lots,double totalStressLoss,string &why)
{
   why="";
   if(!InpUseMarginStressGate){ why="margin stress disabled"; return true; }
   MqlTick t={}; if(!GetTickSafe(s.symbol,t)){ why="no fresh tick for margin stress"; return false; }
   double px=(s.bullish?t.ask:t.bid),newMargin=0;
   ENUM_ORDER_TYPE ot=(s.bullish?ORDER_TYPE_BUY:ORDER_TYPE_SELL);
   if(!OrderCalcMargin(ot,s.symbol,lots,px,newMargin)){ why="OrderCalcMargin failed in stress test"; return false; }
   double equity=AccountInfoDouble(ACCOUNT_EQUITY);
   double margin=AccountInfoDouble(ACCOUNT_MARGIN);
   double portfolioStress=MathMax(0.0,totalStressLoss);
   double stressedEquity=MathMax(0.0,equity-portfolioStress);
   double stressedMargin=margin+newMargin;
   double level=(stressedMargin>0?stressedEquity/stressedMargin*100.0:99999.0);
   why=StringFormat("stressed margin level %.1f%% | stress loss %.2f | projected margin %.2f",
                    level,portfolioStress,stressedMargin);
   return level>=MathMax(100.0,InpMinimumStressedMarginLevelPct);
}

bool DecisionAgeLatencyAllows(const TradeSetup &s,StrategyClass c,string &why)
{
   why="";
   int halfLife=StrategyDecisionHalfLifeSeconds(c);
   datetime candidate=(datetime)GVRead(SymKey(s.symbol,"CAND_TIME"),0);
   datetime now=TimeTradeServer();
   int age=(candidate>0?(int)MathMax(0,(long)(now-candidate)):999999);
   if(InpUseDecisionHalfLife && (candidate<=0 || age>halfLife))
   {
      why=StringFormat("decision half-life expired: age %d sec > %d sec for %s",age,halfLife,StrategyClassName(c));
      return false;
   }
   double latency=GVRead(SymKey(s.symbol,"EXEC_LATENCY_EWMA_MS"),0);
   double budgetMs=halfLife*1000.0*MathMax(0.05,MathMin(0.90,InpMaxLatencyBudgetFraction));
   if(InpUseExecutionLatencyBudget && latency>0 && latency>budgetMs)
   {
      why=StringFormat("learned execution latency %.0f ms exceeds %.0f ms decision budget",latency,budgetMs);
      return false;
   }
   why=StringFormat("decision age %d/%d sec | learned latency %.0f/%.0f ms",age,halfLife,latency,budgetMs);
   return true;
}

bool PortfolioStressLatencyAllows(const TradeSetup &s,double lots,string &why)
{
   why="";
   StrategyClass c=StressCandidateStrategyForSymbol(s.symbol);
   string age="";
   if(!DecisionAgeLatencyAllows(s,c,age)){ why=age; return false; }

   double proposedStress=ProposedStressLossMoney(s,lots);
   double assetClassStress=CurrentPortfolioScenarioStressLoss()+proposedStress;
   string worstMacro="";
   double macroStress=WorstMacroScenarioPortfolioLoss(s,lots,worstMacro);
   double total=MathMax(assetClassStress,macroStress);
   double equity=AccountInfoDouble(ACCOUNT_EQUITY);
   double pct=(equity>0?total/equity*100.0:999.0);
   if(InpUsePortfolioScenarioStress && pct>InpMaxScenarioStressLossPctEquity)
   {
      why=StringFormat("scenario-stress BLOCK %.2f%% equity > %.2f%% | asset adverse %.2f | worst macro %s %.2f | %s",
                       pct,InpMaxScenarioStressLossPctEquity,assetClassStress,worstMacro,macroStress,age);
      return false;
   }

   string gap="";
   if(!GapRiskAllows(s,lots,gap)){ why="gap risk BLOCK: "+gap+" | "+age; return false; }
   string margin="";
   if(!MarginStressAllows(s,lots,total,margin)){ why="margin stress BLOCK: "+margin+" | "+age; return false; }

   why=StringFormat("scenario stress %.2f%% equity PASS | asset adverse %.2f | worst macro %s %.2f | %s | %s | %s",
                    pct,assetClassStress,worstMacro,macroStress,gap,margin,age);
   return true;
}

// Adaptive execution, portfolio risk, integrity/quarantine, shadow validation, lifecycle,
// exactly-once reconciliation, causal analytics, demo-soak evidence and dashboard stack.
// GPT_EA Part 30 - Adaptive portfolio risk, correlation and independent supervisor
// This module is deliberately deterministic. GPT can never override these gates.

input bool   InpUseAdaptivePortfolioEngine          = true;
input bool   InpUseRollingCorrelationRisk           = true;
input int    InpCorrelationLookbackM15              = 96;
input double InpCorrelationRiskThreshold            = 0.70;
input double InpMaxCorrelationWeightedRiskPercent   = 2.25;
input double InpMaxMacroFactorRiskPercent           = 2.25;

input bool   InpUsePerStrategyRiskBudgets           = true;
input double InpTrendDailyRiskBudgetPct              = 2.00;
input double InpTrendWeeklyRiskBudgetPct             = 5.00;
input double InpRetracementDailyRiskBudgetPct        = 2.00;
input double InpRetracementWeeklyRiskBudgetPct       = 5.00;
input double InpCounterScalpDailyRiskBudgetPct       = 0.75;
input double InpCounterScalpWeeklyRiskBudgetPct      = 2.00;
input double InpCounterSwingDailyRiskBudgetPct       = 1.00;
input double InpCounterSwingWeeklyRiskBudgetPct      = 2.50;
input double InpReversalDailyRiskBudgetPct           = 1.00;
input double InpReversalWeeklyRiskBudgetPct          = 2.50;
input double InpBreakoutDailyRiskBudgetPct           = 1.50;
input double InpBreakoutWeeklyRiskBudgetPct          = 4.00;
input double InpBreakoutRetestDailyRiskBudgetPct     = 2.00;
input double InpBreakoutRetestWeeklyRiskBudgetPct    = 5.00;
input double InpRangeDailyRiskBudgetPct              = 1.00;
input double InpRangeWeeklyRiskBudgetPct             = 3.00;
input double InpMeanReversionDailyRiskBudgetPct      = 1.00;
input double InpMeanReversionWeeklyRiskBudgetPct     = 3.00;

input bool   InpUseDynamicQualitySizing              = true;
input double InpMinAdaptiveRiskMultiplier            = 0.25;
input double InpMaxAdaptiveRiskMultiplier            = 1.00;
input double InpDrawdownRiskReductionStartPct        = 3.00;
input double InpDrawdownRiskMinimumAtPct             = 7.00;

input bool   InpUseMarketConditionKillSwitch         = true;
input int    InpAbnormalMarketKillScore              = 3;
input double InpKillSpreadATRFrac                    = 0.20;
input double InpKillM1RangeM15ATRFrac                = 0.60;
input double InpKillATRRatio                         = 2.25;
input double InpKillOpeningRangeRatio                = 2.75;
input int    InpKillQuoteAgeSeconds                  = 10;

input bool   InpUseBrokerHealthGate                  = true;
input double InpBrokerHealthMinimum                  = 55.0;
input bool   InpUseIndependentRiskSupervisor         = true;
input double InpDrawdownAccelerationBlockPct         = 2.00;
input int    InpDrawdownAccelerationWindowMinutes    = 60;

// Strategy health modes written by Part31 and enforced here.
enum AdaptiveStrategyMode
{
   ADAPTIVE_MODE_ACTIVE=0,
   ADAPTIVE_MODE_REDUCED_RISK=1,
   ADAPTIVE_MODE_SHADOW=2,
   ADAPTIVE_MODE_DISABLED=3
};

string AdaptiveStrategyModeName(int mode)
{
   if(mode==ADAPTIVE_MODE_REDUCED_RISK) return "REDUCED_RISK";
   if(mode==ADAPTIVE_MODE_SHADOW) return "SHADOW";
   if(mode==ADAPTIVE_MODE_DISABLED) return "DISABLED";
   return "ACTIVE";
}

StrategyClass CandidateStrategyForSymbol(const string sym)
{
   int c=(int)GVRead(SymKey(sym,"PLAN_STRATEGY"),STRATEGY_NO_TRADE);
   if(c<=0) c=(int)GVRead(SymKey(sym,"CAND_STRATEGY"),STRATEGY_NO_TRADE);
   return (StrategyClass)c;
}

void StrategyRiskBudgetCaps(StrategyClass c,double &daily,double &weekly)
{
   daily=InpTrendDailyRiskBudgetPct; weekly=InpTrendWeeklyRiskBudgetPct;
   switch(c)
   {
      case STRATEGY_RETRACEMENT_ENTRY: daily=InpRetracementDailyRiskBudgetPct; weekly=InpRetracementWeeklyRiskBudgetPct; break;
      case STRATEGY_COUNTER_TREND_SCALP: daily=InpCounterScalpDailyRiskBudgetPct; weekly=InpCounterScalpWeeklyRiskBudgetPct; break;
      case STRATEGY_COUNTER_TREND_SWING: daily=InpCounterSwingDailyRiskBudgetPct; weekly=InpCounterSwingWeeklyRiskBudgetPct; break;
      case STRATEGY_POTENTIAL_REVERSAL: daily=InpReversalDailyRiskBudgetPct; weekly=InpReversalWeeklyRiskBudgetPct; break;
      case STRATEGY_BREAKOUT: daily=InpBreakoutDailyRiskBudgetPct; weekly=InpBreakoutWeeklyRiskBudgetPct; break;
      case STRATEGY_BREAKOUT_RETEST: daily=InpBreakoutRetestDailyRiskBudgetPct; weekly=InpBreakoutRetestWeeklyRiskBudgetPct; break;
      case STRATEGY_RANGE_TRADE: daily=InpRangeDailyRiskBudgetPct; weekly=InpRangeWeeklyRiskBudgetPct; break;
      case STRATEGY_MEAN_REVERSION: daily=InpMeanReversionDailyRiskBudgetPct; weekly=InpMeanReversionWeeklyRiskBudgetPct; break;
      default: break;
   }
}

datetime StartOfTradingDay()
{
   MqlDateTime t={}; TimeToStruct(TimeTradeServer(),t);
   t.hour=0; t.min=0; t.sec=0;
   return StructToTime(t);
}

datetime StartOfTradingWeek()
{
   datetime d=StartOfTradingDay();
   MqlDateTime t={}; TimeToStruct(d,t);
   int back=(t.day_of_week==0?6:t.day_of_week-1); // Monday start
   return d-back*86400;
}

double StrategyOpenRiskMoney(StrategyClass c)
{
   double sum=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
      if((int)GVRead(PosKey(pid,"STRATEGY"),0)!=(int)c) continue;
      double r=PositionRiskMoney(tk);
      if(r>1.0e90) return r;
      sum+=r;
   }
   return sum;
}

double StrategyRealizedLossMoneySince(StrategyClass c,datetime from)
{
   datetime now=TimeTradeServer();
   if(from<=0 || !HistorySelect(from,now)) return 0;
   double loss=0;
   int n=HistoryDealsTotal();
   for(int i=0;i<n;i++)
   {
      ulong d=HistoryDealGetTicket(i); if(d==0) continue;
      if((long)HistoryDealGetInteger(d,DEAL_MAGIC)!=InpMagic) continue;
      ENUM_DEAL_ENTRY e=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(d,DEAL_ENTRY);
      if(e!=DEAL_ENTRY_OUT && e!=DEAL_ENTRY_OUT_BY && e!=DEAL_ENTRY_INOUT) continue;
      ulong pid=(ulong)HistoryDealGetInteger(d,DEAL_POSITION_ID);
      if((int)GVRead(PosKey(pid,"STRATEGY"),0)!=(int)c) continue;
      double p=HistoryDealGetDouble(d,DEAL_PROFIT)+HistoryDealGetDouble(d,DEAL_COMMISSION)+HistoryDealGetDouble(d,DEAL_SWAP);
      if(p<0) loss+=-p;
   }
   return loss;
}

double StrategyBudgetAvailableMoney(StrategyClass c,bool weekly,string &detail)
{
   detail="";
   if(!InpUsePerStrategyRiskBudgets || c==STRATEGY_NO_TRADE) return 1.0e100;
   double capital=(InpUseEquity?AccountInfoDouble(ACCOUNT_EQUITY):AccountInfoDouble(ACCOUNT_BALANCE));
   if(capital<=0) return 0;
   double dailyCap=0,weeklyCap=0; StrategyRiskBudgetCaps(c,dailyCap,weeklyCap);
   double pct=(weekly?weeklyCap:dailyCap);
   if(pct<=0) return 0;
   datetime from=(weekly?StartOfTradingWeek():StartOfTradingDay());
   double consumed=StrategyOpenRiskMoney(c)+StrategyRealizedLossMoneySince(c,from);
   double capMoney=capital*pct/100.0;
   double avail=MathMax(0.0,capMoney-consumed);
   detail=StringFormat("%s %s budget %.2f%% | consumed %.2f | available %.2f",
      StrategyClassName(c),weekly?"weekly":"daily",pct,consumed,avail);
   return avail;
}

bool StrategyRiskBudgetAllows(StrategyClass c,double proposedMoney,string &why)
{
   why="Strategy risk budgets disabled.";
   if(!InpUsePerStrategyRiskBudgets || c==STRATEGY_NO_TRADE) return true;
   string d="",w="";
   double da=StrategyBudgetAvailableMoney(c,false,d);
   double wa=StrategyBudgetAvailableMoney(c,true,w);
   double avail=MathMin(da,wa);
   why=d+" | "+w+StringFormat(" | proposed %.2f",proposedMoney);
   return proposedMoney<=avail+0.01;
}

bool ReturnSeriesM15(const string sym,int lookback,double &r[])
{
   int bars=MathMax(24,lookback)+1;
   double c[]; ArraySetAsSeries(c,true);
   int n=CopyClose(sym,PERIOD_M15,1,bars,c);
   if(n<25) return false;
   int m=n-1; ArrayResize(r,m);
   for(int i=0;i<m;i++) r[i]=(c[i+1]!=0?(c[i]-c[i+1])/c[i+1]:0);
   return true;
}

double RollingM15Correlation(const string a,const string b)
{
   if(a==b) return 1.0;
   double x[],y[];
   if(!ReturnSeriesM15(a,InpCorrelationLookbackM15,x) || !ReturnSeriesM15(b,InpCorrelationLookbackM15,y)) return 0;
   int n=MathMin(ArraySize(x),ArraySize(y)); if(n<20) return 0;
   double sx=0,sy=0; for(int i=0;i<n;i++){ sx+=x[i]; sy+=y[i]; }
   double mx=sx/n,my=sy/n,num=0,dx=0,dy=0;
   for(int i=0;i<n;i++)
   {
      double ax=x[i]-mx,ay=y[i]-my;
      num+=ax*ay; dx+=ax*ax; dy+=ay*ay;
   }
   if(dx<=0 || dy<=0) return 0;
   return MathMax(-1.0,MathMin(1.0,num/MathSqrt(dx*dy)));
}

double DirectionSign(bool bull){ return bull?1.0:-1.0; }

double CorrelationWeightedOpenRiskMoney(const TradeSetup &s)
{
   if(!InpUseRollingCorrelationRisk) return 0;
   double sum=0,psign=DirectionSign(s.bullish);
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      string os=PositionGetString(POSITION_SYMBOL);
      bool obull=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
      double corr=RollingM15Correlation(s.symbol,os);
      double aligned=corr*psign*DirectionSign(obull);
      if(aligned<InpCorrelationRiskThreshold) continue;
      double r=PositionRiskMoney(tk); if(r>1.0e90) return r;
      sum+=r*MathMax(0.0,MathMin(1.0,aligned));
   }
   return sum;
}

void MacroFactorBetas(const string sym,bool bull,double &usd,double &riskOn)
{
   usd=0; riskOn=0;
   string u=sym; StringToUpper(u);
   double dir=DirectionSign(bull);
   if(StringFind(u,"XAU")>=0 || StringFind(u,"XAG")>=0){ usd=-0.75*dir; riskOn=-0.20*dir; return; }
   if(StringFind(u,"US100")>=0 || StringFind(u,"NAS")>=0 || StringFind(u,"USTEC")>=0 ||
      StringFind(u,"US500")>=0 || StringFind(u,"SPX")>=0 || StringFind(u,"US30")>=0 ||
      StringFind(u,"GER40")>=0 || StringFind(u,"DE40")>=0 || StringFind(u,"DAX")>=0)
   { riskOn=1.0*dir; usd=-0.15*dir; return; }
   if(StringFind(u,"BTC")>=0 || StringFind(u,"ETH")>=0){ riskOn=0.80*dir; usd=-0.30*dir; return; }
   if(StringFind(u,"WTI")>=0 || StringFind(u,"BRENT")>=0 || StringFind(u,"USOIL")>=0 || StringFind(u,"UKOIL")>=0)
   { riskOn=0.45*dir; usd=-0.25*dir; return; }

   // Major FX USD leg approximation. Suffixes are allowed because we search the canonical six-letter sequence.
   string majors[7]={"EURUSD","GBPUSD","AUDUSD","NZDUSD","USDJPY","USDCHF","USDCAD"};
   for(int i=0;i<7;i++) if(StringFind(u,majors[i])>=0)
   {
      bool usdBase=(StringFind(majors[i],"USD")==0);
      usd=(usdBase?1.0:-1.0)*dir;
      riskOn=(majors[i]=="AUDUSD" || majors[i]=="NZDUSD"?0.35*dir:0.0);
      return;
   }
}

void CurrentMacroFactorRisk(double &usdMoney,double &riskMoney)
{
   usdMoney=0; riskMoney=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      double pr=PositionRiskMoney(tk); if(pr<=0 || pr>1.0e90) continue;
      string sym=PositionGetString(POSITION_SYMBOL);
      bool bull=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
      double u=0,r=0; MacroFactorBetas(sym,bull,u,r);
      usdMoney+=u*pr; riskMoney+=r*pr;
   }
}

bool AdvancedPortfolioRiskAllows(const TradeSetup &s,double lots,string &why)
{
   string base="";
   if(!PortfolioRiskAllows(s,lots,base)){ why=base; return false; }
   if(!InpUseAdaptivePortfolioEngine){ why=base+" | adaptive portfolio layer disabled."; return true; }
   double eq=AccountInfoDouble(ACCOUNT_EQUITY); if(eq<=0){ why="Account equity unavailable."; return false; }
   double proposed=ProposedRiskMoney(s,lots);

   double weighted=CorrelationWeightedOpenRiskMoney(s);
   if(weighted>1.0e90){ why="Correlation layer found unprotected position."; return false; }
   double weightedPct=(weighted+proposed)/eq*100.0;
   if(InpUseRollingCorrelationRisk && InpMaxCorrelationWeightedRiskPercent>0 && weightedPct>InpMaxCorrelationWeightedRiskPercent)
   {
      why=StringFormat("Correlation-weighted risk %.2f%% > %.2f%% cap. | %s",weightedPct,InpMaxCorrelationWeightedRiskPercent,base);
      return false;
   }

   double usd=0,risk=0,pu=0,pr=0; CurrentMacroFactorRisk(usd,risk); MacroFactorBetas(s.symbol,s.bullish,pu,pr);
   double usdPct=MathAbs(usd+pu*proposed)/eq*100.0;
   double riskPct=MathAbs(risk+pr*proposed)/eq*100.0;
   if(InpMaxMacroFactorRiskPercent>0 && MathMax(usdPct,riskPct)>InpMaxMacroFactorRiskPercent)
   {
      why=StringFormat("Macro factor concentration %.2f%% (USD %.2f%% / risk-on %.2f%%) > %.2f%% cap.",
                       MathMax(usdPct,riskPct),usdPct,riskPct,InpMaxMacroFactorRiskPercent);
      return false;
   }
   why=StringFormat("%s | correlation-weighted %.2f%% | macro USD %.2f%% risk-on %.2f%%",base,weightedPct,usdPct,riskPct);
   return true;
}

int AbnormalMarketConditionScore(const string sym,string &detail)
{
   int score=0; string d="";
   MqlTick t={}; double atr5=0,atr15=0;
   if(GetTickSafe(sym,t) && ATRValue(sym,PERIOD_M5,InpATRPeriod,1,atr5) && atr5>0)
   {
      double spread=(t.ask-t.bid)/atr5;
      if(spread>=InpKillSpreadATRFrac){ score++; d+="spread/ATR; "; }
   }
   ATRValue(sym,PERIOD_M15,InpATRPeriod,1,atr15);
   MqlRates m1[]; ArraySetAsSeries(m1,true);
   if(atr15>0 && CopyRates(sym,PERIOD_M1,1,2,m1)>=1)
   {
      double r=m1[0].high-m1[0].low;
      if(r/atr15>=InpKillM1RangeM15ATRFrac){ score++; d+="violent-M1; "; }
   }
   StrategySnapshot x; BuildStrategySnapshot(sym,x);
   if(x.atrRatio>=InpKillATRRatio){ score++; d+="ATR-regime; "; }
   if(x.openingRangeRatio>=InpKillOpeningRangeRatio){ score++; d+="opening-range; "; }
   if(StopQuoteAgeSeconds(sym)>InpKillQuoteAgeSeconds){ score++; d+="stale-quote; "; }
   string y=""; if(InpUseYieldShockFilter && YieldShock(y)){ score++; d+="yield-shock; "; }
   detail=StringFormat("abnormal-market score %d/%d [%s]",score,InpAbnormalMarketKillScore,d);
   return score;
}

double BrokerHealthScore(const string sym,string &detail)
{
   double score=100.0;
   int age=StopQuoteAgeSeconds(sym);
   if(age>InpKillQuoteAgeSeconds) score-=25;
   double atr=0; MqlTick t={};
   if(GetTickSafe(sym,t) && ATRValue(sym,PERIOD_M5,InpATRPeriod,1,atr) && atr>0)
   {
      double sf=(t.ask-t.bid)/atr;
      if(sf>InpMaxSpreadATRFrac) score-=MathMin(25.0,100.0*(sf-InpMaxSpreadATRFrac));
   }
   double attempts=GVRead(SymKey(sym,"EXEC_ATTEMPTS"),0),fails=GVRead(SymKey(sym,"EXEC_FAILS"),0);
   if(attempts>=5) score-=MathMin(25.0,(fails/attempts)*50.0);
   double slip=GVRead(SymKey(sym,"EXEC_SLIP_EWMA_PTS"),0);
   double spreadPts=0,pt=PointFor(sym); if(pt>0 && t.ask>t.bid) spreadPts=(t.ask-t.bid)/pt;
   if(spreadPts>0 && slip>2.0*spreadPts) score-=15;
   int activeStopFails=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic || PositionGetString(POSITION_SYMBOL)!=sym) continue;
      ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
      activeStopFails+=StopFailureCount(pid);
   }
   score-=MathMin(20.0,activeStopFails*3.0);
   score=MathMax(0.0,MathMin(100.0,score));
   detail=StringFormat("broker health %.1f/100 | quote %ds | attempts %.0f fails %.0f | slipEWMA %.1f pts | active stop failures %d",
                       score,age,attempts,fails,slip,activeStopFails);
   return score;
}

void RefreshDrawdownAccelerationBaseline()
{
   datetime now=TimeTradeServer();
   datetime saved=(datetime)GVRead(SysKey("DD_ACCEL_TIME"),0);
   double current=EquityDrawdownPercent();
   int window=MathMax(5,InpDrawdownAccelerationWindowMinutes)*60;
   if(saved<=0 || now-saved>=window)
   {
      GVWrite(SysKey("DD_ACCEL_TIME"),(double)now);
      GVWrite(SysKey("DD_ACCEL_BASE"),current);
   }
}

bool DrawdownAccelerationBlocked(string &why)
{
   RefreshDrawdownAccelerationBaseline();
   double base=GVRead(SysKey("DD_ACCEL_BASE"),EquityDrawdownPercent());
   double now=EquityDrawdownPercent();
   double delta=now-base;
   if(InpDrawdownAccelerationBlockPct>0 && delta>=InpDrawdownAccelerationBlockPct)
   {
      why=StringFormat("Drawdown accelerated %.2f percentage points within supervisor window (%.2f -> %.2f).",delta,base,now);
      return true;
   }
   why=StringFormat("Drawdown acceleration %.2fpp within supervisor window.",delta);
   return false;
}

int StrategyHealthMode(StrategyClass c)
{
   if(c==STRATEGY_NO_TRADE) return ADAPTIVE_MODE_DISABLED;
   return (int)GVRead(SysKey(StringFormat("HEALTH_MODE_%d",(int)c)),ADAPTIVE_MODE_ACTIVE);
}

double StrategyHealthRiskMultiplier(StrategyClass c)
{
   int mode=StrategyHealthMode(c);
   if(mode==ADAPTIVE_MODE_REDUCED_RISK) return 0.50;
   if(mode==ADAPTIVE_MODE_SHADOW || mode==ADAPTIVE_MODE_DISABLED) return 0.0;
   return MathMax(0.25,MathMin(1.0,GVRead(SysKey(StringFormat("HEALTH_RISK_MULT_%d",(int)c)),1.0)));
}

bool IndependentRiskSupervisorAllows(const TradeSetup &s,string &why)
{
   if(!InpUseIndependentRiskSupervisor){ why="Independent risk supervisor disabled."; return true; }
   string base=""; if(RiskKillSwitchActive(base)){ why="Account kill switch: "+base; return false; }
   StrategyClass c=CandidateStrategyForSymbol(s.symbol);
   int mode=StrategyHealthMode(c);
   if(mode==ADAPTIVE_MODE_SHADOW || mode==ADAPTIVE_MODE_DISABLED)
   { why=StrategyClassName(c)+" is "+AdaptiveStrategyModeName(mode)+"; live exposure prohibited."; return false; }

   if(InpUseMarketConditionKillSwitch)
   {
      string abnormal=""; int score=AbnormalMarketConditionScore(s.symbol,abnormal);
      if(score>=MathMax(1,InpAbnormalMarketKillScore)){ why="Market-condition kill switch: "+abnormal; return false; }
   }
   if(InpUseBrokerHealthGate)
   {
      string bh=""; double h=BrokerHealthScore(s.symbol,bh);
      if(h<InpBrokerHealthMinimum){ why="Broker-health gate: "+bh; return false; }
   }
   string dd=""; if(DrawdownAccelerationBlocked(dd)){ why="Independent supervisor: "+dd; return false; }
   why="Independent supervisor PASS.";
   return true;
}

double AdaptiveRiskMultiplier(const TradeSetup &s,string &detail)
{
   if(!InpUseDynamicQualitySizing){ detail="Dynamic quality sizing disabled."; return 1.0; }
   StrategyClass c=CandidateStrategyForSymbol(s.symbol);
   double conf=MathMax(0.0,MathMin(100.0,(double)s.confidence));
   double confF=MathMax(0.40,MathMin(1.0,0.40+(conf-50.0)*0.012));
   double healthF=StrategyHealthRiskMultiplier(c);
   string bh=""; double broker=BrokerHealthScore(s.symbol,bh);
   double brokerF=MathMax(0.50,MathMin(1.0,(broker-35.0)/65.0));
   double dd=EquityDrawdownPercent(),ddF=1.0;
   if(dd>InpDrawdownRiskReductionStartPct)
   {
      double den=MathMax(0.25,InpDrawdownRiskMinimumAtPct-InpDrawdownRiskReductionStartPct);
      ddF=1.0-0.65*MathMin(1.0,(dd-InpDrawdownRiskReductionStartPct)/den);
   }
   double histF=1.0;
   if(c!=STRATEGY_NO_TRADE)
   {
      double n=0,wr=0,avg=0,pf=0,maxdd=0,ml=0;
      StrategyBucketMetrics(SysKey(StringFormat("STRAT_%d",(int)c)),n,wr,avg,pf,maxdd,ml);
      if(n>=8 && (avg<0 || pf<1.0)) histF=0.65;
      else if(n>=15 && avg>=0.15 && pf>=1.25) histF=1.0;
      else if(n>=8) histF=0.85;
   }
   double eventF=HighImpactEventWithin(s.symbol,InpStrategyNewsContextMinutes)?0.60:1.0;
   double modelF=ModelTrustRiskMultiplier();
   double f=confF*healthF*brokerF*ddF*histF*eventF*modelF;
   f=MathMax(InpMinAdaptiveRiskMultiplier,MathMin(InpMaxAdaptiveRiskMultiplier,f));
   if(healthF<=0 || modelF<=0) f=0;
   detail=StringFormat("adaptive risk x%.2f | conf %.2f health %.2f broker %.2f DD %.2f history %.2f event %.2f model %.2f",
                       f,confF,healthF,brokerF,ddF,histF,eventF,modelF);
   return f;
}

double AdaptiveLotSizeForRisk(const TradeSetup &s,double &riskMoney,double &oneLotLoss)
{
   riskMoney=0; oneLotLoss=0;
   double capital=(InpUseEquity?AccountInfoDouble(ACCOUNT_EQUITY):AccountInfoDouble(ACCOUNT_BALANCE));
   if(capital<=0) return 0;
   string q=""; double mult=AdaptiveRiskMultiplier(s,q);
   if(mult<=0) return 0;
   double desired=capital*InpRiskPercent/100.0*mult;
   StrategyClass c=CandidateStrategyForSymbol(s.symbol);
   if(InpUsePerStrategyRiskBudgets && c!=STRATEGY_NO_TRADE)
   {
      string d="",w="";
      desired=MathMin(desired,MathMin(StrategyBudgetAvailableMoney(c,false,d),StrategyBudgetAvailableMoney(c,true,w)));
   }
   if(desired<=0) return 0;
   ENUM_ORDER_TYPE ot=(s.bullish?ORDER_TYPE_BUY:ORDER_TYPE_SELL);
   double loss=0;
   if(!OrderCalcProfit(ot,s.symbol,1.0,s.preferred,s.sl,loss)) return 0;
   oneLotLoss=MathAbs(loss); if(oneLotLoss<=0) return 0;
   double lots=NormalizeVolumeDown(s.symbol,desired/oneLotLoss);
   if(lots<=0) return 0;
   riskMoney=lots*oneLotLoss; // actual normalized risk, not pre-rounding target.
   return lots;
}

bool AdaptivePreEntryAllows(const TradeSetup &s,double lots,string &why)
{
   StrategyClass c=CandidateStrategyForSymbol(s.symbol);
   string modelClock="";
   if(!ModelClockExecutionAllows(s,c,modelClock)){ why="Model/clock trust: "+modelClock; return false; }

   string sup=""; if(!IndependentRiskSupervisorAllows(s,sup)){ why=sup; return false; }
   double proposed=ProposedRiskMoney(s,lots);
   string budget=""; if(!StrategyRiskBudgetAllows(c,proposed,budget)){ why="Strategy budget: "+budget; return false; }
   string portfolio=""; if(!AdvancedPortfolioRiskAllows(s,lots,portfolio)){ why="Adaptive portfolio: "+portfolio; return false; }
   string stress=""; if(!PortfolioStressLatencyAllows(s,lots,stress)){ why="Scenario/latency supervisor: "+stress; return false; }
   why=modelClock+" | "+sup+" | "+budget+" | "+portfolio+" | "+stress;
   return true;
}

string AdaptiveRiskSummary(const TradeSetup &s)
{
   StrategyClass c=CandidateStrategyForSymbol(s.symbol);
   string mult="",bh="",ab="",dd="";
   double f=AdaptiveRiskMultiplier(s,mult);
   double h=BrokerHealthScore(s.symbol,bh);
   int a=AbnormalMarketConditionScore(s.symbol,ab);
   bool ddb=DrawdownAccelerationBlocked(dd);
   double daily=0,weekly=0; string d="",w="";
   daily=StrategyBudgetAvailableMoney(c,false,d); weekly=StrategyBudgetAvailableMoney(c,true,w);
   return StringFormat("Adaptive risk: %s | mode %s | risk multiplier %.2f | broker health %.1f | abnormal score %d | DD acceleration %s | daily/weekly available %.2f/%.2f",
      StrategyClassName(c),AdaptiveStrategyModeName(StrategyHealthMode(c)),f,h,a,ddb?"BLOCK":"OK",daily,weekly);
}

void AdaptiveRiskSupervisorInit()
{
   RefreshDrawdownAccelerationBaseline();
   Print("GPT_EA adaptive portfolio/risk supervisor initialized.");
}

void AdaptiveRiskSupervisorTimer()
{
   RefreshDrawdownAccelerationBaseline();
}
// GPT_EA Part 39 - Data integrity versioning, strategy registry and quarantine
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
      "model=%s|policy=%s|symbols=%s|universe=%d:%d:%d:%d:%d:%d:%d:%s",
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
      InpOpenAIModel,InpModelPolicyVersion,InpSymbols,
      InpAutoResolveBrokerSymbols?1:0,InpUseMarketWatchUniverse?1:0,InpMaxMarketWatchSymbols,
      InpIncludeCloseOnlySymbols?1:0,InpMaxBrokerUniverseSymbols,InpUniversalScanBatchSize,
      InpUniverseClockProbeSymbols,InpAutoMajorUniverse);

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

   cfg+=StringFormat(
      "|openai=%d:model%s:endpoint%s:timeout%d:hc%d|aiveto=%d:blockunavail%d|"
      "web=%d:hconly%d:blockunavail%d:blockverdict%d:refresh%d|"
      "structured=%d:failclosed%d:reqsources%d:circuit%d:cache%d|"
      "deep=%d:model%s:effort%s:max%d|"
      "confluence=%d:min%d:htf%d:adx%.2f:sweep%d:fvg%d:vol%d:minvol%.3f:maxdist%.3f",
      InpUseOpenAI?1:0,InpOpenAIModel,InpOpenAIEndpoint,InpOpenAITimeoutMs,InpAIReviewHighConfidenceOnly?1:0,
      InpAICanVetoTrade?1:0,InpBlockIfAIUnavailable?1:0,
      InpUseLiveWebIntelligence?1:0,InpWebIntelHighConfidenceOnly?1:0,InpBlockIfWebIntelUnavailable?1:0,
      InpBlockOnWebIntelVerdictBLOCK?1:0,InpWebIntelRefreshMinutes,
      InpUseStructuredWebIntel?1:0,InpFailClosedHighConfidenceNews?1:0,InpRequireWebIntelSources?1:0,
      InpWebIntelFailureCircuitThreshold,InpWebIntelMaxCacheAgeMinutes,
      InpUseDeepGPTReviewModel?1:0,InpDeepGPTReviewModel,InpDeepGPTReasoningEffort,InpDeepGPTMaxOutputTokens,
      InpUseAdvancedConfluence?1:0,InpMinAdvancedConfluence,InpRequireHTFMajority?1:0,InpMinADX,
      InpUseLiquiditySweep?1:0,InpUseFairValueGap?1:0,InpUseVolumeImpulse?1:0,InpMinVolumeRatio,InpMaxEntryDistanceATR);

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
// GPT_EA Part 31 - Execution-quality learning, calibration and strategy health

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
                   "analysis_time","approval_time","model_latency_ms","sent_time","ack_time","fill_time",
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
      TimeToString((datetime)GVRead(PosKey(pid,"EXEC_ANALYSIS_TIME"),0),TIME_DATE|TIME_SECONDS),
      TimeToString((datetime)GVRead(PosKey(pid,"EXEC_APPROVAL_TIME"),0),TIME_DATE|TIME_SECONDS),
      DoubleToString(GVRead(PosKey(pid,"EXEC_MODEL_LATENCY_MS"),0),0),
      TimeToString((datetime)GVRead(PosKey(pid,"EXEC_SENT_TIME"),0),TIME_DATE|TIME_SECONDS),
      TimeToString((datetime)GVRead(PosKey(pid,"EXEC_ACK_TIME"),0),TIME_DATE|TIME_SECONDS),
      TimeToString((datetime)GVRead(PosKey(pid,"EXEC_FILL_TIME"),0),TIME_DATE|TIME_SECONDS),
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
   GVWrite(PosKey(pid,"EXEC_ANALYSIS_TIME"),GVRead(SymKey(sym,"EXEC_ANALYSIS_TIME"),GVRead(SymKey(sym,"CAND_TIME"),0)));
   GVWrite(PosKey(pid,"EXEC_APPROVAL_TIME"),GVRead(SymKey(sym,"EXEC_APPROVAL_TIME"),0));
   GVWrite(PosKey(pid,"EXEC_MODEL_LATENCY_MS"),GVRead(SymKey(sym,"EXEC_MODEL_LATENCY_MS"),0));
   GVWrite(PosKey(pid,"EXEC_SENT_TIME"),GVRead(SymKey(sym,"EXEC_SENT_TIME"),0));
   GVWrite(PosKey(pid,"EXEC_ACK_TIME"),GVRead(SymKey(sym,"EXEC_ACK_TIME"),0));
   GVWrite(PosKey(pid,"EXEC_FILL_TIME"),(double)TimeTradeServer());
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
// GPT_EA Part 31A - Final adaptive sizing with regime-transition caution

double AdaptiveLotSizeForRiskFinal(const TradeSetup &s,double &riskMoney,double &oneLotLoss)
{
   riskMoney=0; oneLotLoss=0;
   double baseRisk=0,baseOneLot=0;
   double baseLots=AdaptiveLotSizeForRisk(s,baseRisk,baseOneLot);
   if(baseLots<=0 || baseOneLot<=0) return 0;

   double transition=MathMax(0.25,MathMin(1.0,GVRead(SymKey(s.symbol,"REGIME_RISK_MULT"),1.0)));
   double lots=NormalizeVolumeDown(s.symbol,baseLots*transition);
   if(lots<=0) return 0;
   oneLotLoss=baseOneLot;
   riskMoney=lots*oneLotLoss;
   return lots;
}

string FinalAdaptiveSizingText(const TradeSetup &s)
{
   string q="";
   double base=AdaptiveRiskMultiplier(s,q);
   double transition=MathMax(0.25,MathMin(1.0,GVRead(SymKey(s.symbol,"REGIME_RISK_MULT"),1.0)));
   return StringFormat("final adaptive sizing x%.2f = quality x%.2f * regime-transition x%.2f",base*transition,base,transition);
}
// GPT_EA Part 31B - History-safe adaptive execution finalization

double AdaptivePositionCommission(const ulong pid)
{
   double commission=0;
   if(!HistorySelectByPosition(pid)) return 0;
   int n=HistoryDealsTotal();
   for(int i=0;i<n;i++)
   {
      ulong d=HistoryDealGetTicket(i); if(d==0) continue;
      commission+=MathAbs(HistoryDealGetDouble(d,DEAL_COMMISSION));
   }
   return commission;
}

void FinalizeAdaptiveLearningHistoryR5()
{
   datetime now=TimeTradeServer(),from=now-MathMax(10,InpStrategyHistoryLookbackDays)*86400;
   if(!HistorySelect(from,now)) return;

   ulong pids[];
   string syms[];
   int total=HistoryDealsTotal();
   for(int i=MathMax(0,total-1200);i<total;i++)
   {
      ulong d=HistoryDealGetTicket(i); if(d==0 || (long)HistoryDealGetInteger(d,DEAL_MAGIC)!=InpMagic) continue;
      ENUM_DEAL_ENTRY e=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(d,DEAL_ENTRY);
      if(e!=DEAL_ENTRY_OUT && e!=DEAL_ENTRY_OUT_BY && e!=DEAL_ENTRY_INOUT) continue;
      ulong pid=(ulong)HistoryDealGetInteger(d,DEAL_POSITION_ID);
      if(pid==0 || PositionIdentifierOpen(pid) || GVRead(PosKey(pid,"ADAPT_FINAL"),0)>0.5 || GVRead(PosKey(pid,"ADAPT_META"),0)<0.5) continue;
      bool duplicate=false;
      for(int j=0;j<ArraySize(pids);j++) if(pids[j]==pid){ duplicate=true; break; }
      if(duplicate) continue;
      int n=ArraySize(pids); ArrayResize(pids,n+1); ArrayResize(syms,n+1);
      pids[n]=pid; syms[n]=HistoryDealGetString(d,DEAL_SYMBOL);
   }

   for(int i=0;i<ArraySize(pids);i++)
   {
      ulong pid=pids[i];
      int cls=(int)GVRead(PosKey(pid,"STRATEGY"),0); if(cls<=0) continue;
      double risk=GVRead(PosKey(pid,"RISK"),0); if(risk<=0) continue;
      double pnl=StrategyPositionRealized(pid),R=pnl/risk;

      string quarantine="";
      if(LearningSampleShouldQuarantine(pid,syms[i],quarantine))
      {
         MarkLearningQuarantine(pid,syms[i],quarantine);
         WriteExecutionLearningRow("QUARANTINED",syms[i],pid,"excluded from learning: "+quarantine,R);
         GVWrite(PosKey(pid,"ADAPT_FINAL"),2);
         continue;
      }

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

      double commission=AdaptivePositionCommission(pid);
      GVWrite(PosKey(pid,"ACTUAL_COMMISSION"),commission);
      WriteExecutionLearningRow("CLOSED",syms[i],pid,"history-safe post-trade learning finalized",R);
      GVWrite(PosKey(pid,"ADAPT_FINAL"),1);
   }
   GlobalVariablesFlush();
}

void ExecutionLearningInitR5()
{
   EnsureExecutionLearningHeader();
   RefreshStrategyHealthModes();
   for(int i=0;i<ArraySize(g_symbols);i++) if(g_symbols[i]!="") RefreshRegimeTransition(g_symbols[i]);
   FinalizeAdaptiveLearningHistoryR5();
   Print("GPT_EA R5 execution-quality learning initialized.");
}

void ExecutionLearningTimerR5()
{
   UpdateOpenMAEMFE();
   FinalizeAdaptiveLearningHistoryR5();
   RefreshStrategyHealthModes();
   for(int i=0;i<ArraySize(g_symbols);i++) if(g_symbols[i]!="") RefreshRegimeTransition(g_symbols[i]);
}
// GPT_EA Part 32 - Champion/challenger shadow validation and counterfactuals

input bool   InpUseChampionChallenger             = true;
input bool   InpAutoPromoteChallenger             = false; // conservative default: research recommendation only
input int    InpChampionChallengerMinSamples      = 30;
input double InpChallengerMinAvgRAdvantage        = 0.10;
input double InpChallengerMinPFAdvantage          = 0.15;
input double InpChallengerMaxExtraDrawdownR       = 0.25;
input double InpChallengerMaxInstabilityR         = 1.50;
input bool   InpUsePromotionSignificance          = true;
input double InpPromotionSignificanceZ            = 1.64; // conservative one-sided ~95% lower bound
input double InpPromotionMinLowerAdvantageR       = 0.02;
input bool   InpUsePromotionProbationRollback     = true;
input int    InpPromotionProbationTrades          = 15;
input int    InpPromotionRollbackMinTrades        = 5;
input double InpPromotionRollbackMinAvgR          = 0.00;
input double InpPromotionRollbackMinPF            = 1.00;
input double InpPromotionRollbackMaxExtraDDR      = 0.50;
input int    InpRollbackRequalifyNewSamples       = 20;
input int    InpShadowMaxExpiryM15                = 12;
input string InpShadowValidationFile              = "GPT_EA_ShadowValidationV2.csv";
input bool   InpTrackRejectedCounterfactuals      = true;

enum ShadowVariant
{
   SHADOW_CHAMPION=0,
   SHADOW_PULLBACK=1,
   SHADOW_BREAKOUT_RETEST=2,
   SHADOW_REJECTED_COUNTERFACTUAL=3
};

string ShadowVariantName(int v)
{
   if(v==SHADOW_PULLBACK) return "CHALLENGER_PULLBACK";
   if(v==SHADOW_BREAKOUT_RETEST) return "CHALLENGER_BREAKOUT_RETEST";
   if(v==SHADOW_REJECTED_COUNTERFACTUAL) return "REJECTED_COUNTERFACTUAL";
   return "CHAMPION";
}

string ShadowKey(const string sym,int variant,const string suffix)
{
   return SymKey(sym,StringFormat("SHADOW_V%d_%s",variant,suffix));
}

string ShadowStatsKey(StrategyClass c,int variant)
{
   return SysKey(StringFormat("CC_STRAT_%d_V%d",(int)c,variant));
}

bool ShadowGeometryUsable(const TradeSetup &s)
{
   if(s.symbol=="" || s.preferred<=0 || s.sl<=0) return false;
   if(s.bullish && !(s.sl<s.preferred && s.tp1>s.preferred && s.tp2>s.tp1)) return false;
   if(!s.bullish && !(s.sl>s.preferred && s.tp1<s.preferred && s.tp2<s.tp1)) return false;
   return true;
}

void EnsureShadowValidationHeader()
{
   if(!InpUseChampionChallenger) return;
   bool exists=FileIsExist(InpShadowValidationFile,FILE_COMMON);
   int h=FileOpen(InpShadowValidationFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(h==INVALID_HANDLE) return;
   if(!exists || FileSize(h)==0)
      FileWrite(h,"schema_version","time","event","symbol","strategy","variant","side","entry","sl","tp2","expiry_m15","outcome_r","mae_r","mfe_r",
         "release_id","strategy_engine","model_policy","config_fingerprint","symbol_fingerprint","strategy_config","reason");
   FileClose(h);
}

void WriteShadowRow(const string eventName,const string sym,StrategyClass c,int variant,bool bull,double entry,double sl,double tp2,int expiry,double outcome,double mae,double mfe,const string reason)
{
   if(!InpUseChampionChallenger) return;
   EnsureShadowValidationHeader();
   int h=FileOpen(InpShadowValidationFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(h==INVALID_HANDLE) return;
   FileSeek(h,0,SEEK_END);
   FileWrite(h,"shadow_validation_v2",TimeToString(TimeTradeServer(),TIME_DATE|TIME_SECONDS),eventName,sym,StrategyClassName(c),ShadowVariantName(variant),bull?"BUY":"SELL",
      DoubleToString(entry,DigitsFor(sym)),DoubleToString(sl,DigitsFor(sym)),DoubleToString(tp2,DigitsFor(sym)),expiry,
      DoubleToString(outcome,3),DoubleToString(mae,3),DoubleToString(mfe,3),
      GPT_EA_REQUIRED_RELEASE_VALIDATION_ID,InpStrategyEngineVersion,InpModelPolicyVersion,CurrentConfigFingerprint(),
      (sym!=""?SymbolContractFingerprint(sym):""),StrategyConfigVersion(c),reason);
   FileFlush(h); FileClose(h);
}

bool ShadowVariantActive(const string sym,int variant)
{
   return GVRead(ShadowKey(sym,variant,"ACTIVE"),0)>0.5;
}

void RegisterShadowTrade(const TradeSetup &s,StrategyClass c,int variant,const string reason)
{
   if(!InpUseChampionChallenger || !ShadowGeometryUsable(s) || c==STRATEGY_NO_TRADE) return;
   if(ShadowVariantActive(s.symbol,variant)) return;
   double R=MathAbs(s.preferred-s.sl); if(R<=PointFor(s.symbol)) return;
   GVWrite(ShadowKey(s.symbol,variant,"ACTIVE"),1);
   GVWrite(ShadowKey(s.symbol,variant,"STRATEGY"),(int)c);
   GVWrite(ShadowKey(s.symbol,variant,"BULL"),s.bullish?1:0);
   GVWrite(ShadowKey(s.symbol,variant,"ENTRY"),s.preferred);
   GVWrite(ShadowKey(s.symbol,variant,"SL"),s.sl);
   GVWrite(ShadowKey(s.symbol,variant,"TP1"),s.tp1);
   GVWrite(ShadowKey(s.symbol,variant,"TP2"),s.tp2);
   GVWrite(ShadowKey(s.symbol,variant,"TP3"),s.tp3);
   GVWrite(ShadowKey(s.symbol,variant,"START"),(double)TimeTradeServer());
   GVWrite(ShadowKey(s.symbol,variant,"EXP"),MathMax(1,MathMin(InpShadowMaxExpiryM15,s.expiryM15)));
   GVWrite(ShadowKey(s.symbol,variant,"MAE"),0);
   GVWrite(ShadowKey(s.symbol,variant,"MFE"),0);
   GVWrite(ShadowKey(s.symbol,variant,"LASTBAR"),0);
   WriteShadowRow("OPEN",s.symbol,c,variant,s.bullish,s.preferred,s.sl,s.tp2,s.expiryM15,0,0,0,reason);
}

void UpdateShadowStability(const string key,double outcome)
{
   double ew=GVRead(key+"_EWMA",0);
   double newE=EWMA(ew,outcome,0.20);
   double dev=MathAbs(outcome-newE);
   GVWrite(key+"_EWMA",newE);
   GVWrite(key+"_DEV",EWMA(GVRead(key+"_DEV",0),dev,0.20));
}

void FinalizeShadowTrade(const string sym,int variant,double outcome,const string reason)
{
   if(!ShadowVariantActive(sym,variant)) return;
   StrategyClass c=(StrategyClass)(int)GVRead(ShadowKey(sym,variant,"STRATEGY"),0);
   bool bull=GVRead(ShadowKey(sym,variant,"BULL"),0)>0.5;
   double entry=GVRead(ShadowKey(sym,variant,"ENTRY"),0),sl=GVRead(ShadowKey(sym,variant,"SL"),0),tp2=GVRead(ShadowKey(sym,variant,"TP2"),0);
   int exp=(int)GVRead(ShadowKey(sym,variant,"EXP"),0);
   double mae=GVRead(ShadowKey(sym,variant,"MAE"),0),mfe=GVRead(ShadowKey(sym,variant,"MFE"),0);
   string key=ShadowStatsKey(c,variant);
   UpdateStrategyBucket(key,outcome);
   UpdateShadowStability(key,outcome);
   WriteShadowRow("CLOSED",sym,c,variant,bull,entry,sl,tp2,exp,outcome,mae,mfe,reason);
   GVWrite(ShadowKey(sym,variant,"ACTIVE"),0);
}

void UpdateOneShadowTrade(const string sym,int variant)
{
   if(!ShadowVariantActive(sym,variant) || !EnsureSymbol(sym)) return;
   bool bull=GVRead(ShadowKey(sym,variant,"BULL"),0)>0.5;
   double entry=GVRead(ShadowKey(sym,variant,"ENTRY"),0),sl=GVRead(ShadowKey(sym,variant,"SL"),0),tp2=GVRead(ShadowKey(sym,variant,"TP2"),0);
   datetime start=(datetime)GVRead(ShadowKey(sym,variant,"START"),0);
   int expiry=(int)GVRead(ShadowKey(sym,variant,"EXP"),4);
   double R=MathAbs(entry-sl); if(R<=0){ FinalizeShadowTrade(sym,variant,0,"invalid shadow geometry"); return; }

   MqlTick t={}; if(!GetTickSafe(sym,t)) return;
   double px=(bull?t.bid:t.ask);
   double rNow=(bull?px-entry:entry-px)/R;
   if(rNow>GVRead(ShadowKey(sym,variant,"MFE"),0)) GVWrite(ShadowKey(sym,variant,"MFE"),rNow);
   double mae=MathMax(0.0,-rNow); if(mae>GVRead(ShadowKey(sym,variant,"MAE"),0)) GVWrite(ShadowKey(sym,variant,"MAE"),mae);

   // Use the most recently closed M5 bar to catch target/stop touches between timer cycles.
   MqlRates b[]; ArraySetAsSeries(b,true);
   bool stopHit=false,targetHit=false;
   if(CopyRates(sym,PERIOD_M5,1,1,b)>=1)
   {
      stopHit=(bull?b[0].low<=sl:b[0].high>=sl);
      targetHit=(bull?b[0].high>=tp2:b[0].low<=tp2);
   }
   if(stopHit && targetHit)
   {
      // Conservative ambiguity rule prevents optimistic shadow statistics.
      FinalizeShadowTrade(sym,variant,-1.0,"same-bar stop/TP2 ambiguity; conservative stop outcome");
      return;
   }
   if(stopHit || (bull?px<=sl:px>=sl)){ FinalizeShadowTrade(sym,variant,-1.0,"shadow stop reached"); return; }
   if(targetHit || (bull?px>=tp2:px<=tp2))
   {
      double targetR=MathAbs(tp2-entry)/R;
      FinalizeShadowTrade(sym,variant,targetR,"shadow TP2 reached"); return;
   }
   if(start>0 && BarsSince(sym,PERIOD_M15,start)>=expiry)
   {
      FinalizeShadowTrade(sym,variant,MathMax(-1.0,MathMin(2.5,rNow)),"shadow candle expiry mark-to-market");
      return;
   }
}

void ChampionChallengerMetrics(StrategyClass c,int variant,double &n,double &avg,double &pf,double &dd,double &dev)
{
   double wr=0,ml=0; string k=ShadowStatsKey(c,variant);
   StrategyBucketMetrics(k,n,wr,avg,pf,dd,ml);
   dev=GVRead(k+"_DEV",0);
}

bool ChallengerRollbackCooldownAllows(StrategyClass c,int variant,string &why)
{
   double rollbackN=GVRead(SysKey(StringFormat("CC_ROLLBACK_N_%d_V%d",(int)c,variant)),0);
   if(rollbackN<=0){ why="no rollback cooldown"; return true; }
   double n=0,a=0,pf=0,dd=0,dev=0;
   ChampionChallengerMetrics(c,variant,n,a,pf,dd,dev);
   double added=n-rollbackN;
   if(added<MathMax(1,InpRollbackRequalifyNewSamples))
   {
      why=StringFormat("rollback cooldown: %.0f/%d new shadow samples",added,InpRollbackRequalifyNewSamples);
      return false;
   }
   why=StringFormat("rollback cooldown cleared after %.0f new samples",added);
   return true;
}

bool ChallengerSignificanceAllows(StrategyClass c,int variant,string &why)
{
   why="";
   if(!InpUsePromotionSignificance){ why="statistical significance gate disabled"; return true; }
   double cn=0,ca=0,cp=0,cdd=0,cdev=0,nn=0,na=0,np=0,ndd=0,ndev=0;
   ChampionChallengerMetrics(c,SHADOW_CHAMPION,cn,ca,cp,cdd,cdev);
   ChampionChallengerMetrics(c,variant,nn,na,np,ndd,ndev);
   if(cn<2 || nn<2){ why="insufficient sample for significance"; return false; }

   // DEV is an EWMA absolute deviation. Multiplying by 1.253 approximates
   // sigma from mean absolute deviation and intentionally errs conservatively.
   double cs=MathMax(0.05,cdev*1.253);
   double ns=MathMax(0.05,ndev*1.253);
   double se=MathSqrt(cs*cs/cn+ns*ns/nn);
   double advantage=na-ca;
   double lower=advantage-MathMax(0.0,InpPromotionSignificanceZ)*se;
   why=StringFormat("promotion significance: advantage %.3fR | SE %.3f | lower bound %.3fR vs %.3fR",
                    advantage,se,lower,InpPromotionMinLowerAdvantageR);
   return lower>=InpPromotionMinLowerAdvantageR;
}

void CapturePromotionProbationBaseline(StrategyClass c,int variant)
{
   string k=ShadowStatsKey(c,variant);
   string p=SysKey(StringFormat("CC_PROB_%d_V%d",(int)c,variant));
   GVWrite(p+"_N",GVRead(k+"_N",0));
   GVWrite(p+"_SUMR",GVRead(k+"_SUMR",0));
   GVWrite(p+"_POSR",GVRead(k+"_POSR",0));
   GVWrite(p+"_NEGR",GVRead(k+"_NEGR",0));
   GVWrite(p+"_MAXDD",GVRead(k+"_MAXDD",0));
   GVWrite(p+"_TIME",(double)TimeTradeServer());
   GVWrite(p+"_PASSED",0);
}

bool PromotionProbationShouldRollback(StrategyClass c,int variant,string &why)
{
   why="";
   if(!InpUsePromotionProbationRollback || variant==SHADOW_CHAMPION) return false;
   string k=ShadowStatsKey(c,variant);
   string p=SysKey(StringFormat("CC_PROB_%d_V%d",(int)c,variant));
   double baseN=GVRead(p+"_N",-1);
   if(baseN<0){ CapturePromotionProbationBaseline(c,variant); why="probation baseline initialized"; return false; }

   double n=GVRead(k+"_N",0);
   double postN=n-baseN;
   if(postN<MathMax(1,InpPromotionRollbackMinTrades))
   {
      why=StringFormat("promotion probation %.0f/%d minimum review trades",postN,InpPromotionRollbackMinTrades);
      return false;
   }

   double sum=GVRead(k+"_SUMR",0)-GVRead(p+"_SUMR",0);
   double pos=GVRead(k+"_POSR",0)-GVRead(p+"_POSR",0);
   double neg=GVRead(k+"_NEGR",0)-GVRead(p+"_NEGR",0);
   double avg=(postN>0?sum/postN:0);
   double pf=(neg>0?pos/neg:(pos>0?99.0:0.0));
   double ddNow=GVRead(k+"_MAXDD",0),ddBase=GVRead(p+"_MAXDD",0);
   bool bad=(avg<InpPromotionRollbackMinAvgR ||
             pf<InpPromotionRollbackMinPF ||
             ddNow>ddBase+InpPromotionRollbackMaxExtraDDR);
   why=StringFormat("promotion probation N %.0f | avg %.2fR | PF %.2f | DD %.2f vs base %.2f",
                    postN,avg,pf,ddNow,ddBase);
   if(bad) return true;
   if(postN>=MathMax(InpPromotionRollbackMinTrades,InpPromotionProbationTrades))
      GVWrite(p+"_PASSED",1);
   return false;
}

void EvaluateChampionRollback(StrategyClass c)
{
   if(!InpUseChampionChallenger || !InpAutoPromoteChallenger || !InpUsePromotionProbationRollback) return;
   string promotedKey=SysKey(StringFormat("CC_PROMOTED_%d",(int)c));
   int current=(int)GVRead(promotedKey,SHADOW_CHAMPION);
   if(current==SHADOW_CHAMPION) return;
   string why="";
   if(PromotionProbationShouldRollback(c,current,why))
   {
      double n=0,a=0,pf=0,dd=0,dev=0;
      ChampionChallengerMetrics(c,current,n,a,pf,dd,dev);
      GVWrite(SysKey(StringFormat("CC_ROLLBACK_N_%d_V%d",(int)c,current)),n);
      GVWrite(SysKey(StringFormat("CC_ROLLBACK_TIME_%d",(int)c)),(double)TimeTradeServer());
      GVWrite(SysKey(StringFormat("CC_ROLLBACK_VARIANT_%d",(int)c)),current);
      GVWrite(promotedKey,SHADOW_CHAMPION);
      Print("GPT_EA champion rollback: ",StrategyClassName(c)," ",ShadowVariantName(current)," -> CHAMPION | ",why);
   }
}

bool ChallengerEligibleForPromotion(StrategyClass c,int variant,string &why)
{
   why="";
   if(variant!=SHADOW_PULLBACK && variant!=SHADOW_BREAKOUT_RETEST) return false;
   string cooldown="";
   if(!ChallengerRollbackCooldownAllows(c,variant,cooldown)){ why=cooldown; return false; }
   double cn=0,ca=0,cp=0,cdd=0,cdev=0,nn=0,na=0,np=0,ndd=0,ndev=0;
   ChampionChallengerMetrics(c,SHADOW_CHAMPION,cn,ca,cp,cdd,cdev);
   ChampionChallengerMetrics(c,variant,nn,na,np,ndd,ndev);
   if(cn<InpChampionChallengerMinSamples || nn<InpChampionChallengerMinSamples)
   {
      why=StringFormat("developing shadow sample champion %.0f / challenger %.0f; minimum %d",cn,nn,InpChampionChallengerMinSamples);
      return false;
   }
   bool avgOK=(na>=ca+InpChallengerMinAvgRAdvantage);
   bool pfOK=(np>=cp+InpChallengerMinPFAdvantage);
   bool ddOK=(ndd<=cdd+InpChallengerMaxExtraDrawdownR);
   bool stable=(ndev<=InpChallengerMaxInstabilityR);
   string sig="";
   bool significant=ChallengerSignificanceAllows(c,variant,sig);
   why=StringFormat("champ avg %.2f PF %.2f DD %.2f dev %.2f | challenger %s avg %.2f PF %.2f DD %.2f dev %.2f | %s | %s",
      ca,cp,cdd,cdev,ShadowVariantName(variant),na,np,ndd,ndev,sig,cooldown);
   return avgOK && pfOK && ddOK && stable && significant;
}

int PromotedChallengerVariant(StrategyClass c)
{
   return (int)GVRead(SysKey(StringFormat("CC_PROMOTED_%d",(int)c)),SHADOW_CHAMPION);
}

void RefreshChampionChallengerPromotion()
{
   if(!InpUseChampionChallenger) return;
   for(int ci=1;ci<=9;ci++)
   {
      StrategyClass c=(StrategyClass)ci;
      EvaluateChampionRollback(c);
      int current=(int)GVRead(SysKey(StringFormat("CC_PROMOTED_%d",ci)),SHADOW_CHAMPION);
      string p="",b="";
      bool pb=ChallengerEligibleForPromotion(c,SHADOW_PULLBACK,p);
      bool br=ChallengerEligibleForPromotion(c,SHADOW_BREAKOUT_RETEST,b);
      int chosen=SHADOW_CHAMPION;
      if(pb && br)
      {
         double n1=0,a1=0,pf1=0,d1=0,v1=0,n2=0,a2=0,pf2=0,d2=0,v2=0;
         ChampionChallengerMetrics(c,SHADOW_PULLBACK,n1,a1,pf1,d1,v1);
         ChampionChallengerMetrics(c,SHADOW_BREAKOUT_RETEST,n2,a2,pf2,d2,v2);
         chosen=(a2>a1?SHADOW_BREAKOUT_RETEST:SHADOW_PULLBACK);
      }
      else if(pb) chosen=SHADOW_PULLBACK;
      else if(br) chosen=SHADOW_BREAKOUT_RETEST;
      if(!InpAutoPromoteChallenger) chosen=SHADOW_CHAMPION;
      if(chosen!=current && chosen!=SHADOW_CHAMPION)
      {
         CapturePromotionProbationBaseline(c,chosen);
         GVWrite(SysKey(StringFormat("CC_PREVIOUS_%d",ci)),current);
         GVWrite(SysKey(StringFormat("CC_PROMOTION_TIME_%d",ci)),(double)TimeTradeServer());
      }
      // A rollback performed above is not immediately undone unless the
      // challenger has cleared its requalification sample cooldown.
      GVWrite(SysKey(StringFormat("CC_PROMOTED_%d",ci)),chosen);
      GVWrite(SysKey(StringFormat("CC_PB_ELIGIBLE_%d",ci)),pb?1:0);
      GVWrite(SysKey(StringFormat("CC_BRT_ELIGIBLE_%d",ci)),br?1:0);
   }
}

void ApplyChampionChallengerSelection(TradeSetup &primary,const TradeSetup &pb,const TradeSetup &br,StrategyDecision &d,string &note)
{
   note="Champion selector retained.";
   if(!InpUseChampionChallenger || !InpAutoPromoteChallenger || d.strategy==STRATEGY_NO_TRADE) return;
   int v=PromotedChallengerVariant(d.strategy);
   if(v==SHADOW_PULLBACK && ShadowGeometryUsable(pb) && pb.valid)
   {
      primary=pb; d.setup=pb; note="Promoted pullback challenger selected after shadow validation."; return;
   }
   if(v==SHADOW_BREAKOUT_RETEST && ShadowGeometryUsable(br) && br.valid)
   {
      primary=br; d.setup=br; note="Promoted breakout-retest challenger selected after shadow validation."; return;
   }
}

void ChampionChallengerScanHook(const TradeSetup &primary,const TradeSetup &pb,const TradeSetup &br,const StrategyDecision &d,bool liveReady,const string reason)
{
   if(!InpUseChampionChallenger || d.strategy==STRATEGY_NO_TRADE) return;
   if(ShadowGeometryUsable(primary)) RegisterShadowTrade(primary,d.strategy,SHADOW_CHAMPION,"selected strategy shadow benchmark");
   if(ShadowGeometryUsable(pb)) RegisterShadowTrade(pb,d.strategy,SHADOW_PULLBACK,"alternative pullback execution path");
   if(ShadowGeometryUsable(br)) RegisterShadowTrade(br,d.strategy,SHADOW_BREAKOUT_RETEST,"alternative breakout-retest execution path");
   if(InpTrackRejectedCounterfactuals && !liveReady && ShadowGeometryUsable(primary))
      RegisterShadowTrade(primary,d.strategy,SHADOW_REJECTED_COUNTERFACTUAL,"rejected/no-trade counterfactual: "+reason);
}

string ChampionChallengerSummary(StrategyClass c)
{
   if(!InpUseChampionChallenger || c==STRATEGY_NO_TRADE) return "Champion/challenger disabled or no strategy.";
   double cn=0,ca=0,cp=0,cdd=0,cd=0,pn=0,pa=0,pp=0,pdd=0,pd=0,bn=0,ba=0,bp=0,bdd=0,bd=0;
   ChampionChallengerMetrics(c,SHADOW_CHAMPION,cn,ca,cp,cdd,cd);
   ChampionChallengerMetrics(c,SHADOW_PULLBACK,pn,pa,pp,pdd,pd);
   ChampionChallengerMetrics(c,SHADOW_BREAKOUT_RETEST,bn,ba,bp,bdd,bd);
   string pwhy="",bwhy=""; bool pe=ChallengerEligibleForPromotion(c,SHADOW_PULLBACK,pwhy),be=ChallengerEligibleForPromotion(c,SHADOW_BREAKOUT_RETEST,bwhy);
   return StringFormat("Champion/challenger %s | champion N %.0f avg %.2f PF %.2f DD %.2f | PB N %.0f avg %.2f PF %.2f eligible %s | BRT N %.0f avg %.2f PF %.2f eligible %s | promoted %s",
      StrategyClassName(c),cn,ca,cp,cdd,pn,pa,pp,pe?"YES":"NO",bn,ba,bp,be?"YES":"NO",ShadowVariantName(PromotedChallengerVariant(c)));
}

void ChampionChallengerInit()
{
   EnsureShadowValidationHeader();
   RefreshChampionChallengerPromotion();
   Print("GPT_EA champion/challenger shadow engine initialized. Auto-promotion=",InpAutoPromoteChallenger?"ON":"OFF");
}

void ChampionChallengerTimer()
{
   if(!InpUseChampionChallenger) return;
   for(int i=0;i<ArraySize(g_symbols);i++)
   {
      string sym=g_symbols[i]; if(sym=="") continue;
      for(int v=0;v<=3;v++) UpdateOneShadowTrade(sym,v);
   }
   RefreshChampionChallengerPromotion();
}
// GPT_EA Part 33 - Trade lifecycle, GPT disagreement/integrity and replay snapshots

input bool   InpUseLifecycleStateMachine          = true;
input string InpLifecycleJournalFile              = "GPT_EA_LifecycleV2.csv";
input bool   InpWriteDecisionSnapshots            = true;
input string InpDecisionSnapshotFile              = "GPT_EA_DecisionSnapshotsV2.csv";
input int    InpDecisionSnapshotMaxText            = 1600;
input bool   InpUseGPTDisagreementGate            = true;
input int    InpGPTStrongDisagreementScore        = 2;
input bool   InpUseModelOutputIntegrity            = true;
input int    InpMinimumGPTReviewChars              = 20;
input int    InpStoredAIReviewMaxAgeSeconds        = 180;

enum TradeLifecycleState
{
   LIFE_NONE=0,
   LIFE_CANDIDATE=1,
   LIFE_WAIT_CONFIRMATION=2,
   LIFE_APPROVED=3,
   LIFE_SENT=4,
   LIFE_FILLED=5,
   LIFE_TP1_PARTIAL=6,
   LIFE_PROTECTED=7,
   LIFE_RUNNER=8,
   LIFE_CLOSED=9,
   LIFE_REJECTED=10,
   LIFE_INVALIDATED=11
};

string LifecycleStateName(int s)
{
   switch(s)
   {
      case LIFE_CANDIDATE: return "CANDIDATE";
      case LIFE_WAIT_CONFIRMATION: return "WAIT_CONFIRMATION";
      case LIFE_APPROVED: return "APPROVED";
      case LIFE_SENT: return "SENT";
      case LIFE_FILLED: return "FILLED";
      case LIFE_TP1_PARTIAL: return "TP1_PARTIAL";
      case LIFE_PROTECTED: return "PROTECTED";
      case LIFE_RUNNER: return "RUNNER";
      case LIFE_CLOSED: return "CLOSED";
      case LIFE_REJECTED: return "REJECTED";
      case LIFE_INVALIDATED: return "INVALIDATED";
      default: return "NONE";
   }
}

bool LifecycleTransitionAllowed(int from,int to)
{
   if(from==to) return true;
   if(from==LIFE_NONE) return (to==LIFE_CANDIDATE || to==LIFE_FILLED || to==LIFE_CLOSED);
   if(from==LIFE_CANDIDATE) return (to==LIFE_WAIT_CONFIRMATION || to==LIFE_APPROVED || to==LIFE_REJECTED || to==LIFE_INVALIDATED);
   if(from==LIFE_WAIT_CONFIRMATION) return (to==LIFE_APPROVED || to==LIFE_REJECTED || to==LIFE_INVALIDATED);
   if(from==LIFE_APPROVED) return (to==LIFE_SENT || to==LIFE_REJECTED || to==LIFE_INVALIDATED);
   if(from==LIFE_SENT) return (to==LIFE_FILLED || to==LIFE_REJECTED || to==LIFE_INVALIDATED);
   if(from==LIFE_FILLED) return (to==LIFE_TP1_PARTIAL || to==LIFE_PROTECTED || to==LIFE_RUNNER || to==LIFE_CLOSED);
   if(from==LIFE_TP1_PARTIAL) return (to==LIFE_PROTECTED || to==LIFE_RUNNER || to==LIFE_CLOSED);
   if(from==LIFE_PROTECTED) return (to==LIFE_RUNNER || to==LIFE_CLOSED);
   if(from==LIFE_RUNNER) return (to==LIFE_CLOSED);
   if(from==LIFE_REJECTED || from==LIFE_INVALIDATED || from==LIFE_CLOSED) return (to==LIFE_CANDIDATE || to==LIFE_CLOSED);
   return false;
}

void EnsureLifecycleHeader()
{
   if(!InpUseLifecycleStateMachine) return;
   bool exists=FileIsExist(InpLifecycleJournalFile,FILE_COMMON);
   int h=FileOpen(InpLifecycleJournalFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(h==INVALID_HANDLE) return;
   if(!exists || FileSize(h)==0)
      FileWrite(h,"schema_version","time","symbol","position_id","from_state","to_state","strategy",
         "release_id","strategy_engine","model_policy","config_fingerprint","symbol_fingerprint","strategy_config","reason");
   FileClose(h);
}

void WriteLifecycleEvent(const string sym,ulong pid,int from,int to,StrategyClass c,const string reason)
{
   if(!InpUseLifecycleStateMachine) return;
   EnsureLifecycleHeader();
   int h=FileOpen(InpLifecycleJournalFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(h==INVALID_HANDLE) return;
   FileSeek(h,0,SEEK_END);
   FileWrite(h,"lifecycle_v2",TimeToString(TimeTradeServer(),TIME_DATE|TIME_SECONDS),sym,(string)pid,
      LifecycleStateName(from),LifecycleStateName(to),StrategyClassName(c),
      GPT_EA_REQUIRED_RELEASE_VALIDATION_ID,InpStrategyEngineVersion,InpModelPolicyVersion,CurrentConfigFingerprint(),
      (sym!=""?SymbolContractFingerprint(sym):""),StrategyConfigVersion(c),reason);
   FileFlush(h); FileClose(h);
}

bool SetSymbolLifecycle(const string sym,int to,const string reason)
{
   if(!InpUseLifecycleStateMachine) return true;
   string k=SymKey(sym,"LIFECYCLE_STATE");
   int from=(int)GVRead(k,LIFE_NONE);
   if(!LifecycleTransitionAllowed(from,to))
   {
      PrintFormat("%s lifecycle transition BLOCKED: %s -> %s | %s",sym,LifecycleStateName(from),LifecycleStateName(to),reason);
      return false;
   }
   StrategyClass c=CandidateStrategyForSymbol(sym);
   GVWrite(k,to); GVWrite(SymKey(sym,"LIFECYCLE_TIME"),(double)TimeTradeServer());
   WriteLifecycleEvent(sym,0,from,to,c,reason);
   return true;
}

bool SetPositionLifecycle(ulong ticket,int to,const string reason)
{
   if(!InpUseLifecycleStateMachine) return true;
   if(!PositionSelectByTicket(ticket)) return false;
   ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
   string sym=PositionGetString(POSITION_SYMBOL);
   int from=(int)GVRead(PosKey(pid,"LIFECYCLE_STATE"),LIFE_NONE);
   if(!LifecycleTransitionAllowed(from,to))
   {
      // Recovery may discover a broker-filled position before the pre-trade state was persisted.
      if(from==LIFE_NONE && (to==LIFE_FILLED || to==LIFE_PROTECTED || to==LIFE_RUNNER)) from=LIFE_FILLED;
      else
      {
         PrintFormat("%s position lifecycle transition BLOCKED: %s -> %s | %s",sym,LifecycleStateName(from),LifecycleStateName(to),reason);
         return false;
      }
   }
   StrategyClass c=(StrategyClass)(int)GVRead(PosKey(pid,"STRATEGY"),CandidateStrategyForSymbol(sym));
   GVWrite(PosKey(pid,"LIFECYCLE_STATE"),to); GVWrite(PosKey(pid,"LIFECYCLE_TIME"),(double)TimeTradeServer());
   WriteLifecycleEvent(sym,pid,from,to,c,reason);
   return true;
}

void AttachLifecycleToNewestPosition(ulong ticket,const string reason)
{
   if(!PositionSelectByTicket(ticket)) return;
   ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
   if(GVRead(PosKey(pid,"LIFECYCLE_STATE"),0)<=0)
      GVWrite(PosKey(pid,"LIFECYCLE_STATE"),LIFE_SENT);
   SetPositionLifecycle(ticket,LIFE_FILLED,reason);
}

void RefreshOpenPositionLifecycles()
{
   if(!InpUseLifecycleStateMachine) return;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
      int current=(int)GVRead(PosKey(pid,"LIFECYCLE_STATE"),LIFE_NONE);
      if(current==LIFE_NONE) SetPositionLifecycle(tk,LIFE_FILLED,"restart/recovery lifecycle reconstruction");
      bool partial=PositionFlag(pid,tk,"TP1PARTIAL");
      bool done=PositionFlag(pid,tk,"TP1DONE");
      bool tp2=PositionFlag(pid,tk,"TP2PARTIAL");
      if(partial && !done) SetPositionLifecycle(tk,LIFE_TP1_PARTIAL,"TP1 partial complete; protection pending");
      else if(done && tp2) SetPositionLifecycle(tk,LIFE_RUNNER,"TP2 scale-out complete; runner active");
      else if(done) SetPositionLifecycle(tk,LIFE_PROTECTED,"TP1 and required protection complete");
   }
}

void FinalizeClosedLifecycles()
{
   datetime now=TimeTradeServer(),from=now-MathMax(3,InpStrategyHistoryLookbackDays)*86400;
   if(!HistorySelect(from,now)) return;
   int n=HistoryDealsTotal();
   for(int i=MathMax(0,n-600);i<n;i++)
   {
      ulong d=HistoryDealGetTicket(i); if(d==0 || (long)HistoryDealGetInteger(d,DEAL_MAGIC)!=InpMagic) continue;
      ENUM_DEAL_ENTRY e=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(d,DEAL_ENTRY);
      if(e!=DEAL_ENTRY_OUT && e!=DEAL_ENTRY_OUT_BY && e!=DEAL_ENTRY_INOUT) continue;
      ulong pid=(ulong)HistoryDealGetInteger(d,DEAL_POSITION_ID);
      if(PositionIdentifierOpen(pid) || GVRead(PosKey(pid,"LIFE_FINAL"),0)>0.5) continue;
      string sym=HistoryDealGetString(d,DEAL_SYMBOL);
      int fromState=(int)GVRead(PosKey(pid,"LIFECYCLE_STATE"),LIFE_FILLED);
      StrategyClass c=(StrategyClass)(int)GVRead(PosKey(pid,"STRATEGY"),0);
      GVWrite(PosKey(pid,"LIFECYCLE_STATE"),LIFE_CLOSED);
      GVWrite(PosKey(pid,"LIFECYCLE_TIME"),(double)HistoryDealGetInteger(d,DEAL_TIME));
      GVWrite(PosKey(pid,"LIFE_FINAL"),1);
      WriteLifecycleEvent(sym,pid,fromState,LIFE_CLOSED,c,"position no longer open; history finalized");
   }
}

int TextChecksum(const string s)
{
   long h=2166136261;
   int n=StringLen(s);
   for(int i=0;i<n;i++) h=(h ^ StringGetCharacter(s,i))*16777619;
   if(h<0) h=-h;
   return (int)(h%2147483647);
}

bool DeterministicSetupIntegrity(const TradeSetup &s,string &why)
{
   if(s.symbol=="" || s.preferred<=0 || s.sl<=0 || s.tp1<=0 || s.tp2<=0 || s.tp3<=0)
   { why="setup has missing symbol/price geometry"; return false; }
   if(s.zoneLow>s.zoneHigh){ why="entry zone low exceeds zone high"; return false; }
   if(s.bullish && !(s.sl<s.preferred && s.tp1>s.preferred && s.tp2>s.tp1 && s.tp3>s.tp2))
   { why="bullish setup has contradictory SL/TP geometry"; return false; }
   if(!s.bullish && !(s.sl>s.preferred && s.tp1<s.preferred && s.tp2<s.tp1 && s.tp3<s.tp2))
   { why="bearish setup has contradictory SL/TP geometry"; return false; }
   datetime ct=(datetime)GVRead(SymKey(s.symbol,"CAND_TIME"),0);
   if(ct>0 && TimeTradeServer()-ct>900){ why="candidate strategy identity is stale"; return false; }
   why="deterministic setup geometry and candidate freshness PASS";
   return true;
}

int GPTDisagreementScore(const TradeSetup &s,const string answer,bool available,string &detail)
{
   detail="GPT review unavailable or not requested.";
   if(!available || answer=="") return 0;
   string u=answer; StringToUpper(u);
   int score=0; string why="";
   bool opposite=(s.bullish?(StringFind(u,"BEARISH")>=0 || StringFind(u,"SHORT")>=0):
                            (StringFind(u,"BULLISH")>=0 || StringFind(u,"LONG")>=0));
   if(opposite){ score+=2; why+="explicit opposite direction; "; }
   if(StringFind(u,"BLOCK")>=0 || StringFind(u,"NO TRADE")>=0 || StringFind(u,"VETO")>=0){ score+=2; why+="explicit veto/no-trade; "; }
   else if(StringFind(u,"WAIT")>=0 || StringFind(u,"REANALYZE")>=0){ score+=1; why+="wait/reanalyze; "; }
   if(StringFind(u,"INVALID")>=0 && StringFind(u,"VALID")<0){ score+=1; why+="invalidity language; "; }
   detail=StringFormat("GPT disagreement score %d | %s",score,why);
   return score;
}

bool GPTReviewIntegrityAllows(const string sym,const TradeSetup &s,const string answer,bool available,bool requested,string &why)
{
   string det=""; if(!DeterministicSetupIntegrity(s,det)){ why="Deterministic integrity BLOCK: "+det; return false; }
   if(!InpUseModelOutputIntegrity){ why=det+" | model-output integrity disabled."; return true; }
   if(!requested){ why=det+" | GPT review not requested."; return true; }
   if(!available){ why=det+" | GPT unavailable; availability policy handled separately."; return true; }
   if(StringLen(answer)<InpMinimumGPTReviewChars){ why="GPT integrity BLOCK: response too short/malformed."; return false; }
   string u=answer; StringToUpper(u);
   if(StringFind(u,"API KEY")>=0 || StringFind(u,"AUTHORIZATION: BEARER")>=0)
   { why="GPT integrity BLOCK: response unexpectedly contains credential-like text."; return false; }
   if(StringFind(u,"OPENAI RESPONSE RECEIVED, BUT TEXT COULD NOT BE PARSED")>=0)
   { why="GPT integrity BLOCK: parser fallback text detected."; return false; }
   why=det+StringFormat(" | GPT review integrity PASS len %d checksum %d",StringLen(answer),TextChecksum(answer));
   return true;
}

bool GPTDisagreementAllowsHighConfidence(const TradeSetup &s,const string answer,bool available,string &why)
{
   if(!InpUseGPTDisagreementGate){ why="GPT disagreement gate disabled."; return true; }
   int d=GPTDisagreementScore(s,answer,available,why);
   if(d>=InpGPTStrongDisagreementScore)
   {
      why+=" | DOWNGRADE: deterministic setup retained, but high-confidence execution is withheld.";
      return false;
   }
   why+=" | no strong disagreement.";
   return true;
}

void PersistAIIntegrityDecision(const string sym,bool integrityOK,bool disagreementOK,bool requested,bool available,const string answer)
{
   GVWrite(SymKey(sym,"AI_INTEGRITY_OK"),integrityOK?1:0);
   GVWrite(SymKey(sym,"AI_DISAGREE_OK"),disagreementOK?1:0);
   GVWrite(SymKey(sym,"AI_REVIEW_REQUESTED"),requested?1:0);
   GVWrite(SymKey(sym,"AI_REVIEW_AVAILABLE"),available?1:0);
   GVWrite(SymKey(sym,"AI_REVIEW_TIME"),(double)TimeTradeServer());
   GVWrite(SymKey(sym,"AI_REVIEW_CHECKSUM"),TextChecksum(answer));
   if(requested && available && !disagreementOK)
      GVWrite(SysKey("MODEL_CONTRADICTION"),GVRead(SysKey("MODEL_CONTRADICTION"),0)+1);
}

bool StoredAIIntegrityAllows(const string sym,string &why)
{
   bool requested=GVRead(SymKey(sym,"AI_REVIEW_REQUESTED"),0)>0.5;
   if(!requested){ why="No GPT review was required for stored candidate."; return true; }
   datetime tm=(datetime)GVRead(SymKey(sym,"AI_REVIEW_TIME"),0);
   if(tm<=0 || TimeTradeServer()-tm>InpStoredAIReviewMaxAgeSeconds)
   { why="Stored GPT integrity decision is stale; reanalysis required."; return false; }
   if(GVRead(SymKey(sym,"AI_INTEGRITY_OK"),0)<0.5){ why="Stored GPT output integrity failed."; return false; }
   if(GVRead(SymKey(sym,"AI_DISAGREE_OK"),0)<0.5){ why="Stored GPT/deterministic disagreement requires WAIT/REANALYZE."; return false; }
   why="Stored GPT integrity/disagreement state PASS.";
   return true;
}

void EnsureDecisionSnapshotHeader()
{
   if(!InpWriteDecisionSnapshots) return;
   bool exists=FileIsExist(InpDecisionSnapshotFile,FILE_COMMON);
   int h=FileOpen(InpDecisionSnapshotFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(h==INVALID_HANDLE) return;
   if(!exists || FileSize(h)==0)
      FileWrite(h,"schema_version","time","symbol","strategy","market_state","decision","side","entry","zone_low","zone_high","sl","tp1","tp2","tp3",
         "confidence","strategy_score","atr_ratio","opening_range_ratio","adx","rsi15","overextension_atr","volume_ratio","realistic_rr","risk_multiplier",
         "broker_health","strategy_mode","regime_transition","filters","web_summary","gpt_checksum","gpt_excerpt",
         "release_id","strategy_engine","model_policy","config_fingerprint","symbol_fingerprint","strategy_config","reason");
   FileClose(h);
}

string SnapshotText(string s)
{
   int maxLen=MathMax(100,InpDecisionSnapshotMaxText);
   if(StringLen(s)>maxLen) s=StringSubstr(s,0,maxLen);
   StringReplace(s,"\r"," "); StringReplace(s,"\n"," ");
   return s;
}

void WriteDecisionSnapshot(const TradeSetup &s,const StrategyDecision &d,const string finalDecision,const string filters,const string webText,const string aiAnswer,const string reason)
{
   if(!InpWriteDecisionSnapshots || s.symbol=="") return;
   EnsureDecisionSnapshotHeader();
   StrategySnapshot x; BuildStrategySnapshot(s.symbol,x);
   string rm="",bh=""; double mult=AdaptiveRiskMultiplier(s,rm),health=BrokerHealthScore(s.symbol,bh);
   int h=FileOpen(InpDecisionSnapshotFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(h==INVALID_HANDLE) return;
   FileSeek(h,0,SEEK_END);
   FileWrite(h,"decision_snapshot_v2",TimeToString(TimeTradeServer(),TIME_DATE|TIME_SECONDS),s.symbol,StrategyClassName(d.strategy),MarketStateName(d.state),finalDecision,
      s.bullish?"BUY":"SELL",DoubleToString(s.preferred,DigitsFor(s.symbol)),DoubleToString(s.zoneLow,DigitsFor(s.symbol)),DoubleToString(s.zoneHigh,DigitsFor(s.symbol)),
      DoubleToString(s.sl,DigitsFor(s.symbol)),DoubleToString(s.tp1,DigitsFor(s.symbol)),DoubleToString(s.tp2,DigitsFor(s.symbol)),DoubleToString(s.tp3,DigitsFor(s.symbol)),
      s.confidence,d.score,DoubleToString(x.atrRatio,3),DoubleToString(x.openingRangeRatio,3),DoubleToString(x.adx,2),DoubleToString(x.rsi15,2),
      DoubleToString(x.overextensionATR,3),DoubleToString(x.volumeRatio,3),DoubleToString(RealisticRiskReward(s).rr,3),DoubleToString(mult,3),DoubleToString(health,1),
      AdaptiveStrategyModeName(StrategyHealthMode(d.strategy)),SnapshotText(RegimeTransitionText(s.symbol)),SnapshotText(filters),SnapshotText(webText),
      TextChecksum(aiAnswer),SnapshotText(aiAnswer),GPT_EA_REQUIRED_RELEASE_VALIDATION_ID,InpStrategyEngineVersion,InpModelPolicyVersion,
      CurrentConfigFingerprint(),SymbolContractFingerprint(s.symbol),StrategyConfigVersion(d.strategy),
      SnapshotText(reason+" | "+rm+" | "+bh));
   FileFlush(h); FileClose(h);
}

string LifecycleIntegritySummary(const string sym)
{
   int life=(int)GVRead(SymKey(sym,"LIFECYCLE_STATE"),LIFE_NONE);
   string ai=""; bool ok=StoredAIIntegrityAllows(sym,ai);
   return "Lifecycle "+LifecycleStateName(life)+" | stored AI integrity "+(ok?"PASS":"BLOCK")+" | "+ai;
}

void LifecycleIntegrityInit()
{
   EnsureLifecycleHeader(); EnsureDecisionSnapshotHeader();
   RefreshOpenPositionLifecycles(); FinalizeClosedLifecycles();
   Print("GPT_EA lifecycle/integrity/replay engine initialized.");
}

void LifecycleIntegrityTimer()
{
   RefreshOpenPositionLifecycles(); FinalizeClosedLifecycles();
}
// GPT_EA Part 42 - Atomic intent ledger, exactly-once execution and reconciliation

input bool   InpUseAtomicTradeIntentLedger       = true;
input bool   InpUseExactlyOnceExecution          = true;
input string InpTradeIntentFile                  = "GPT_EA_TradeIntentLedger.csv";
input int    InpIntentAmbiguityResolveSeconds    = 300;
input bool   InpUseBrokerEAReconciliation        = true;
input string InpBrokerReconciliationFile         = "GPT_EA_BrokerReconciliation.csv";
input bool   InpBlockUnexpectedManualExposure    = true;
input bool   InpUseStorageHealthGate             = true;
input string InpStorageHeartbeatFile             = "GPT_EA_StorageHealth.csv";
input int    InpStorageHealthIntervalSeconds     = 60;
input bool   InpUseConfigurationDriftGate        = true;
input bool   InpAllowLegacyOpenPositionsOnUpgrade= true;

string LateResilienceConfigText()
{
   return StringFormat(
      "|intent=%d:%d:amb%d|reconcile=%d:manual%d|storage=%d:int%d|configdrift=%d:legacy%d|"
      "cc=%d:auto%d:min%d:avg%.3f:pf%.3f:dd%.3f:inst%.3f|"
      "sig=%d:z%.3f:lower%.3f|prob=%d:trades%d:min%d:avg%.3f:pf%.3f:dd%.3f:requal%d",
      InpUseAtomicTradeIntentLedger?1:0,InpUseExactlyOnceExecution?1:0,InpIntentAmbiguityResolveSeconds,
      InpUseBrokerEAReconciliation?1:0,InpBlockUnexpectedManualExposure?1:0,
      InpUseStorageHealthGate?1:0,InpStorageHealthIntervalSeconds,
      InpUseConfigurationDriftGate?1:0,InpAllowLegacyOpenPositionsOnUpgrade?1:0,
      InpUseChampionChallenger?1:0,InpAutoPromoteChallenger?1:0,InpChampionChallengerMinSamples,
      InpChallengerMinAvgRAdvantage,InpChallengerMinPFAdvantage,InpChallengerMaxExtraDrawdownR,InpChallengerMaxInstabilityR,
      InpUsePromotionSignificance?1:0,InpPromotionSignificanceZ,InpPromotionMinLowerAdvantageR,
      InpUsePromotionProbationRollback?1:0,InpPromotionProbationTrades,InpPromotionRollbackMinTrades,
      InpPromotionRollbackMinAvgR,InpPromotionRollbackMinPF,InpPromotionRollbackMaxExtraDDR,
      InpRollbackRequalifyNewSamples);
}

enum IntentState
{
   INTENT_NONE=0,
   INTENT_PREPARED=1,
   INTENT_SENT=2,
   INTENT_FILLED=3,
   INTENT_FAILED=4,
   INTENT_CLOSED=5,
   INTENT_UNCERTAIN=6
};

bool g_storageHealthy=true;
string g_storageWhy="not checked";
bool g_reconciliationBlocked=false;
string g_reconciliationWhy="";
datetime g_lastStorageCheck=0;
datetime g_lastReconcile=0;
int g_lastTransactionSignature=0;
datetime g_lastTransactionTime=0;

string IntentStateName(int s)
{
   switch(s)
   {
      case INTENT_PREPARED: return "PREPARED";
      case INTENT_SENT: return "SENT";
      case INTENT_FILLED: return "FILLED";
      case INTENT_FAILED: return "FAILED";
      case INTENT_CLOSED: return "CLOSED";
      case INTENT_UNCERTAIN: return "UNCERTAIN";
      default: return "NONE";
   }
}

string ExtractIntentNonce(const string comment)
{
   int p=StringFind(comment,"GEA-");
   if(p<0) return "";
   string tail=StringSubstr(comment,p+4);
   int dash=StringFind(tail,"-");
   if(dash>=0) tail=StringSubstr(tail,dash+1);
   if(StringLen(tail)>8) tail=StringSubstr(tail,0,8);
   return tail;
}

int IntentNonceHash(const string nonce){ return IntegrityTextHash(nonce); }

string TradeIntentComment(const string nonce,StrategyClass c)
{
   string code=StrategyCode(c);
   string out="GEA-"+code+"-"+nonce;
   if(StringLen(out)>31) out=StringSubstr(out,0,31);
   return out;
}

string IntentDecisionText(const TradeSetup &s,double lots,double riskMoney)
{
   StrategyClass c=CandidateStrategyForSymbol(s.symbol);
   return StringFormat("%s|%d|%d|%d|%.10f|%.10f|%.10f|%.10f|%.10f|%.4f|%.2f|%s|%s",
      s.symbol,s.bullish?1:0,(int)s.kind,(int)c,s.preferred,s.sl,s.tp1,s.tp2,s.tp3,lots,riskMoney,
      CurrentConfigFingerprint(),StrategyConfigVersion(c));
}

string IntentDecisionDigest(const TradeSetup &s,double lots,double riskMoney)
{
   return StringFormat("%08X",IntegrityTextHash(IntentDecisionText(s,lots,riskMoney)));
}

string GenerateExecutionNonce(const TradeSetup &s)
{
   long seq=(long)GVRead(SysKey("INTENT_SEQ"),0)+1;
   GVWrite(SysKey("INTENT_SEQ"),(double)seq);
   string raw=StringFormat("%I64d|%I64d|%s|%d|%I64d|%d",
      AccountInfoInteger(ACCOUNT_LOGIN),InpMagic,s.symbol,s.bullish?1:0,GetTickCount64(),(int)seq);
   return StringFormat("%08X",IntegrityTextHash(raw));
}

void EnsureIntentHeader()
{
   if(!InpUseAtomicTradeIntentLedger) return;
   bool exists=FileIsExist(InpTradeIntentFile,FILE_COMMON);
   int h=FileOpen(InpTradeIntentFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(h==INVALID_HANDLE) return;
   if(!exists || FileSize(h)==0)
      FileWrite(h,"schema_version","time","state","nonce","nonce_hash","symbol","side","setup_kind","strategy",
         "lots","risk_money","expected_entry","sl","tp1","tp2","tp3","decision_digest","config_fingerprint",
         "symbol_fingerprint","position_id","broker_ticket","retcode","note");
   FileClose(h);
}

bool WriteIntentLedgerRow(const string state,const string nonce,const TradeSetup &s,double lots,double riskMoney,
                          ulong pid,ulong ticket,uint retcode,const string note)
{
   if(!InpUseAtomicTradeIntentLedger) return true;
   if(ChaosInjectStorageFailure())
   {
      g_storageHealthy=false; g_storageWhy="CHAOS synthetic intent-ledger storage failure";
      return false;
   }
   EnsureIntentHeader();
   int h=FileOpen(InpTradeIntentFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(h==INVALID_HANDLE)
   {
      g_storageHealthy=false; g_storageWhy=StringFormat("intent ledger FileOpen failed %d",GetLastError());
      return false;
   }
   FileSeek(h,0,SEEK_END);
   StrategyClass c=CandidateStrategyForSymbol(s.symbol);
   FileWrite(h,"trade_intent_v1",TimeToString(TimeTradeServer(),TIME_DATE|TIME_SECONDS),state,nonce,IntentNonceHash(nonce),
      s.symbol,s.bullish?"BUY":"SELL",(int)s.kind,StrategyClassName(c),DoubleToString(lots,4),DoubleToString(riskMoney,2),
      DoubleToString(s.preferred,DigitsFor(s.symbol)),DoubleToString(s.sl,DigitsFor(s.symbol)),
      DoubleToString(s.tp1,DigitsFor(s.symbol)),DoubleToString(s.tp2,DigitsFor(s.symbol)),DoubleToString(s.tp3,DigitsFor(s.symbol)),
      IntentDecisionDigest(s,lots,riskMoney),CurrentConfigFingerprint(),SymbolContractFingerprint(s.symbol),
      (string)pid,(string)ticket,(string)retcode,note);
   FileFlush(h); FileClose(h);
   return true;
}

void EnsureReconciliationHeader()
{
   bool exists=FileIsExist(InpBrokerReconciliationFile,FILE_COMMON);
   int h=FileOpen(InpBrokerReconciliationFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(h==INVALID_HANDLE) return;
   if(!exists || FileSize(h)==0)
      FileWrite(h,"schema_version","time","severity","event","symbol","position_id","ticket","magic","comment","detail");
   FileClose(h);
}

void WriteReconciliationRow(const string severity,const string eventName,const string sym,ulong pid,ulong ticket,long magic,const string comment,const string detail)
{
   EnsureReconciliationHeader();
   int h=FileOpen(InpBrokerReconciliationFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(h==INVALID_HANDLE){ g_storageHealthy=false; g_storageWhy="broker reconciliation journal unavailable"; return; }
   FileSeek(h,0,SEEK_END);
   FileWrite(h,"broker_reconciliation_v1",TimeToString(TimeTradeServer(),TIME_DATE|TIME_SECONDS),severity,eventName,
      sym,(string)pid,(string)ticket,(string)magic,comment,detail);
   FileFlush(h); FileClose(h);
}

void MarkOpenPositionsStorageAnomaly(const string reason)
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
      GVWrite(PosKey(pid,"STORAGE_ANOMALY"),1);
      MarkLearningQuarantine(pid,PositionGetString(POSITION_SYMBOL),"storage anomaly: "+reason);
   }
}

bool CriticalStorageHealthCheck(string &why)
{
   why="";
   if(!InpUseStorageHealthGate){ why="storage-health gate disabled"; return true; }
   if(ChaosInjectStorageFailure())
   {
      g_storageHealthy=false; g_storageWhy="CHAOS synthetic storage heartbeat failure";
      MarkOpenPositionsStorageAnomaly(g_storageWhy);
      why=g_storageWhy; return false;
   }
   int h=FileOpen(InpStorageHeartbeatFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(h==INVALID_HANDLE)
   {
      g_storageHealthy=false;
      g_storageWhy=StringFormat("critical storage FileOpen failed %d",GetLastError());
      MarkOpenPositionsStorageAnomaly(g_storageWhy);
      why=g_storageWhy; return false;
   }
   if(FileSize(h)==0) FileWrite(h,"schema_version","time","release_id","config_fingerprint","status");
   FileSeek(h,0,SEEK_END);
   FileWrite(h,"storage_health_v1",TimeToString(TimeTradeServer(),TIME_DATE|TIME_SECONDS),
      GPT_EA_REQUIRED_RELEASE_VALIDATION_ID,CurrentConfigFingerprint(),"PASS");
   FileFlush(h); FileClose(h);
   g_storageHealthy=true; g_storageWhy="critical storage writable";
   g_lastStorageCheck=TimeTradeServer();
   why=g_storageWhy; return true;
}

bool ConfigurationDriftAllows(string &why)
{
   why="";
   if(!InpUseConfigurationDriftGate){ why="configuration drift gate disabled"; return true; }
   string current=CurrentConfigFingerprint();
   ENUM_ACCOUNT_TRADE_MODE mode=(ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE);
   if(mode==ACCOUNT_TRADE_MODE_REAL)
   {
      if(StringLen(Trim(InpReleaseCertifiedConfigFingerprint))<8)
      { why="REAL account requires certified configuration fingerprint."; return false; }
      if(current!=Trim(InpReleaseCertifiedConfigFingerprint))
      { why="CONFIGURATION DRIFT: runtime "+current+" != certified "+Trim(InpReleaseCertifiedConfigFingerprint); return false; }
      why="configuration fingerprint matches certified "+current;
      return true;
   }

   int currentHash=IntegrityTextHash(CurrentSensitiveConfigText());
   int baseline=(int)GVRead(SysKey("CONFIG_BASELINE_HASH"),0);
   if(baseline==0)
   {
      GVWrite(SysKey("CONFIG_BASELINE_HASH"),currentHash);
      why="demo/test configuration baseline established "+current;
      return true;
   }
   if(baseline!=currentHash)
   {
      // A non-real reinitialization may intentionally change settings. We flag
      // the drift but permit evidence-generation only after the new baseline is explicit.
      GVWrite(SysKey("CONFIG_DRIFT_SEEN"),1);
      GVWrite(SysKey("CONFIG_BASELINE_HASH"),currentHash);
      why="demo/test configuration changed; baseline refreshed and evidence generation must identify new fingerprint "+current;
      return true;
   }
   why="configuration fingerprint stable "+current;
   return true;
}

bool ReliabilityOpenPositionForSymbol(const string sym)
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)==InpMagic && PositionGetString(POSITION_SYMBOL)==sym) return true;
   }
   return false;
}

bool IntentStateBlocksNewSubmission(const string sym,string &why)
{
   why="";
   if(!InpUseExactlyOnceExecution) return false;
   int state=(int)GVRead(SymKey(sym,"INTENT_STATE"),INTENT_NONE);
   datetime tm=(datetime)GVRead(SymKey(sym,"INTENT_TIME"),0);
   if(state==INTENT_PREPARED || state==INTENT_SENT || state==INTENT_UNCERTAIN)
   {
      why=StringFormat("exactly-once gate: unresolved %s intent age %d sec",IntentStateName(state),
                       tm>0?(int)(TimeTradeServer()-tm):0);
      return true;
   }
   if(state==INTENT_FILLED && ReliabilityOpenPositionForSymbol(sym))
   {
      why="exactly-once gate: filled intent still has an open position";
      return true;
   }
   return false;
}

bool ExecutionReliabilityPreEntryAllows(const TradeSetup &s,string &why)
{
   why="";
   string storage="";
   if(!CriticalStorageHealthCheck(storage)){ why="Storage health: "+storage; return false; }
   string cfg="";
   if(!ConfigurationDriftAllows(cfg)){ why=cfg; return false; }
   if(ChaosInjectStaleQuote()){ why="CHAOS synthetic stale quote"; return false; }
   if(ChaosInjectConnectionLoss()){ why="CHAOS synthetic terminal connection loss"; return false; }
   if(!(bool)TerminalInfoInteger(TERMINAL_CONNECTED)){ why="terminal disconnected"; return false; }
   string intent="";
   if(IntentStateBlocksNewSubmission(s.symbol,intent)){ why=intent; return false; }
   if(g_reconciliationBlocked){ why="broker/EA reconciliation BLOCK: "+g_reconciliationWhy; return false; }
   why=storage+" | "+cfg+" | reconciliation PASS | exactly-once PASS";
   return true;
}

bool PrepareAtomicTradeIntent(const TradeSetup &s,double lots,double riskMoney,string &nonce,string &why)
{
   nonce=""; why="";
   if(!InpUseAtomicTradeIntentLedger){ why="atomic intent ledger disabled"; return true; }
   string pre="";
   if(!ExecutionReliabilityPreEntryAllows(s,pre)){ why=pre; return false; }

   nonce=GenerateExecutionNonce(s);
   int nh=IntentNonceHash(nonce);
   GVWrite(SymKey(s.symbol,"INTENT_STATE"),INTENT_PREPARED);
   GVWrite(SymKey(s.symbol,"EXEC_ANALYSIS_TIME"),GVRead(SymKey(s.symbol,"CAND_TIME"),(double)TimeTradeServer()));
   GVWrite(SymKey(s.symbol,"EXEC_APPROVAL_TIME"),(double)TimeTradeServer());
   GVWrite(SymKey(s.symbol,"EXEC_MODEL_LATENCY_MS"),GVRead(SysKey("MODEL_LATENCY_EWMA_MS"),0));
   GVWrite(SymKey(s.symbol,"INTENT_NONCE_HASH"),nh);
   GVWrite(SymKey(s.symbol,"INTENT_TIME"),(double)TimeTradeServer());
   GVWrite(SymKey(s.symbol,"INTENT_DECISION_HASH"),IntegrityTextHash(IntentDecisionText(s,lots,riskMoney)));
   GVWrite(SymKey(s.symbol,"INTENT_KIND"),(int)s.kind);
   GVWrite(SymKey(s.symbol,"INTENT_BULL"),s.bullish?1:0);
   GVWrite(SymKey(s.symbol,"INTENT_LOTS"),lots);
   GVWrite(SymKey(s.symbol,"INTENT_RISK"),riskMoney);
   if(!WriteIntentLedgerRow("PREPARED",nonce,s,lots,riskMoney,0,0,0,"durable intent prepared before broker submission"))
   {
      GVWrite(SymKey(s.symbol,"INTENT_STATE"),INTENT_NONE);
      GlobalVariablesFlush();
      why="atomic intent persistence failed; broker submission prohibited";
      return false;
   }
   GlobalVariablesFlush();
   why="atomic intent PREPARED nonce "+nonce+" | "+pre;
   return true;
}

bool MarkTradeIntentSent(const TradeSetup &s,const string nonce,double lots,double riskMoney,string &why)
{
   why="";
   if(!InpUseAtomicTradeIntentLedger){ why="intent ledger disabled"; return true; }
   if((int)GVRead(SymKey(s.symbol,"INTENT_NONCE_HASH"),0)!=IntentNonceHash(nonce))
   { why="intent nonce mismatch before SENT transition"; return false; }
   GVWrite(SymKey(s.symbol,"INTENT_STATE"),INTENT_SENT);
   GVWrite(SymKey(s.symbol,"INTENT_TIME"),(double)TimeTradeServer());
   GVWrite(SymKey(s.symbol,"EXEC_SENT_TIME"),(double)TimeTradeServer());
   if(!WriteIntentLedgerRow("SENT",nonce,s,lots,riskMoney,0,0,0,"SENT persisted before network order call"))
   {
      GVWrite(SymKey(s.symbol,"INTENT_STATE"),INTENT_UNCERTAIN);
      GlobalVariablesFlush();
      why="could not durably persist SENT state; order call prohibited";
      return false;
   }
   GlobalVariablesFlush();
   why="intent SENT durably persisted";
   return true;
}

void MarkTradeIntentUncertain(const TradeSetup &s,const string nonce,double lots,double riskMoney,uint retcode,const string note)
{
   if(!InpUseAtomicTradeIntentLedger) return;
   GVWrite(SymKey(s.symbol,"INTENT_STATE"),INTENT_UNCERTAIN);
   GVWrite(SymKey(s.symbol,"INTENT_TIME"),(double)TimeTradeServer());
   WriteIntentLedgerRow("UNCERTAIN",nonce,s,lots,riskMoney,0,0,retcode,note);
   GlobalVariablesFlush();
}

void MarkTradeIntentFailed(const TradeSetup &s,const string nonce,double lots,double riskMoney,uint retcode,const string note)
{
   if(!InpUseAtomicTradeIntentLedger) return;
   GVWrite(SymKey(s.symbol,"INTENT_STATE"),INTENT_FAILED);
   GVWrite(SymKey(s.symbol,"INTENT_TIME"),(double)TimeTradeServer());
   WriteIntentLedgerRow("FAILED",nonce,s,lots,riskMoney,0,0,retcode,note);
   GlobalVariablesFlush();
}

void BindTradeIntentToPosition(ulong ticket,const TradeSetup &s,const string nonce,double lots,double riskMoney)
{
   if(ticket==0 || !PositionSelectByTicket(ticket)) return;
   ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
   GVWrite(SymKey(s.symbol,"INTENT_STATE"),INTENT_FILLED);
   GVWrite(SymKey(s.symbol,"INTENT_TIME"),(double)TimeTradeServer());
   GVWrite(PosKey(pid,"INTENT_NONCE_HASH"),IntentNonceHash(nonce));
   GVWrite(PosKey(pid,"INTENT_BOUND"),1);
   GVWrite(PosKey(pid,"DECISION_HASH"),IntegrityTextHash(IntentDecisionText(s,lots,riskMoney)));
   GVWrite(PosKey(pid,"EXEC_ANALYSIS_TIME"),GVRead(SymKey(s.symbol,"EXEC_ANALYSIS_TIME"),GVRead(SymKey(s.symbol,"CAND_TIME"),0)));
   GVWrite(PosKey(pid,"EXEC_APPROVAL_TIME"),GVRead(SymKey(s.symbol,"EXEC_APPROVAL_TIME"),0));
   GVWrite(PosKey(pid,"EXEC_SENT_TIME"),GVRead(SymKey(s.symbol,"EXEC_SENT_TIME"),0));
   GVWrite(PosKey(pid,"EXEC_ACK_TIME"),GVRead(SymKey(s.symbol,"EXEC_ACK_TIME"),0));
   GVWrite(PosKey(pid,"EXEC_FILL_TIME"),(double)TimeTradeServer());
   GVWrite(PosKey(pid,"OPEN_TIME"),(double)PositionGetInteger(POSITION_TIME));
   GVWrite(PosKey(pid,"RECON_VOL"),PositionGetDouble(POSITION_VOLUME));
   GVWrite(PosKey(pid,"RECON_SL"),PositionGetDouble(POSITION_SL));
   GVWrite(PosKey(pid,"RECON_TP"),PositionGetDouble(POSITION_TP));
   if(GVRead(SysKey("CHAOS_ACTIVE_SAMPLE"),0)>0.5) GVWrite(PosKey(pid,"CHAOS_SAMPLE"),1);
   AttachIntegrityMetadataToPosition(ticket);
   WriteIntentLedgerRow("FILLED",nonce,s,lots,riskMoney,pid,ticket,trade.ResultRetcode(),"broker position bound to durable intent");
   GlobalVariablesFlush();
}

bool IntentGeometryMatchesPosition(const string sym,ulong ticket)
{
   if(ticket==0 || !PositionSelectByTicket(ticket)) return false;
   if(PositionGetString(POSITION_SYMBOL)!=sym || PositionGetInteger(POSITION_MAGIC)!=InpMagic) return false;
   datetime intentTime=(datetime)GVRead(SymKey(sym,"INTENT_TIME"),0);
   datetime posTime=(datetime)PositionGetInteger(POSITION_TIME);
   if(intentTime<=0 || posTime<intentTime-15 || posTime>intentTime+MathMax(600,InpIntentAmbiguityResolveSeconds)) return false;
   bool bull=GVRead(SymKey(sym,"INTENT_BULL"),0)>0.5;
   long type=PositionGetInteger(POSITION_TYPE);
   if((bull && type!=POSITION_TYPE_BUY) || (!bull && type!=POSITION_TYPE_SELL)) return false;
   double expected=GVRead(SymKey(sym,"INTENT_LOTS"),0);
   double actual=PositionGetDouble(POSITION_VOLUME);
   double step=MathMax(SymbolInfoDouble(sym,SYMBOL_VOLUME_STEP),0.0000001);
   return (expected>0 && MathAbs(actual-expected)<=0.5*step);
}

bool IntentGeometryMatchesDeal(const string sym,ulong deal)
{
   if(deal==0) return false;
   if(HistoryDealGetString(deal,DEAL_SYMBOL)!=sym || HistoryDealGetInteger(deal,DEAL_MAGIC)!=InpMagic) return false;
   ENUM_DEAL_ENTRY entry=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal,DEAL_ENTRY);
   if(entry!=DEAL_ENTRY_IN && entry!=DEAL_ENTRY_INOUT) return false;
   datetime intentTime=(datetime)GVRead(SymKey(sym,"INTENT_TIME"),0);
   datetime dealTime=(datetime)HistoryDealGetInteger(deal,DEAL_TIME);
   if(intentTime<=0 || dealTime<intentTime-15 || dealTime>intentTime+MathMax(600,InpIntentAmbiguityResolveSeconds)) return false;
   bool bull=GVRead(SymKey(sym,"INTENT_BULL"),0)>0.5;
   ENUM_DEAL_TYPE type=(ENUM_DEAL_TYPE)HistoryDealGetInteger(deal,DEAL_TYPE);
   if((bull && type!=DEAL_TYPE_BUY) || (!bull && type!=DEAL_TYPE_SELL)) return false;
   double expected=GVRead(SymKey(sym,"INTENT_LOTS"),0);
   double actual=HistoryDealGetDouble(deal,DEAL_VOLUME);
   double step=MathMax(SymbolInfoDouble(sym,SYMBOL_VOLUME_STEP),0.0000001);
   return (expected>0 && MathAbs(actual-expected)<=0.5*step);
}

bool IntentGeometryMatchesHistoryOrder(const string sym,ulong order)
{
   if(order==0) return false;
   if(HistoryOrderGetString(order,ORDER_SYMBOL)!=sym || HistoryOrderGetInteger(order,ORDER_MAGIC)!=InpMagic) return false;
   datetime intentTime=(datetime)GVRead(SymKey(sym,"INTENT_TIME"),0);
   datetime orderTime=(datetime)HistoryOrderGetInteger(order,ORDER_TIME_SETUP);
   if(intentTime<=0 || orderTime<intentTime-15 || orderTime>intentTime+MathMax(600,InpIntentAmbiguityResolveSeconds)) return false;
   bool bull=GVRead(SymKey(sym,"INTENT_BULL"),0)>0.5;
   ENUM_ORDER_TYPE type=(ENUM_ORDER_TYPE)HistoryOrderGetInteger(order,ORDER_TYPE);
   if((bull && type!=ORDER_TYPE_BUY) || (!bull && type!=ORDER_TYPE_SELL)) return false;
   double expected=GVRead(SymKey(sym,"INTENT_LOTS"),0);
   double actual=HistoryOrderGetDouble(order,ORDER_VOLUME_INITIAL);
   double step=MathMax(SymbolInfoDouble(sym,SYMBOL_VOLUME_STEP),0.0000001);
   return (expected>0 && MathAbs(actual-expected)<=0.5*step);
}

bool PositionOrHistoryMatchesIntent(const string sym,int nonceHash,ulong &ticket,ulong &pid,bool &closed)
{
   ticket=0; pid=0; closed=false;
   if(nonceHash<=0) return false;

   ulong fallbackPosition=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=sym || PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      string nonce=ExtractIntentNonce(PositionGetString(POSITION_COMMENT));
      if(nonce!="" && IntentNonceHash(nonce)==nonceHash)
      {
         ticket=tk; pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER); return true;
      }
      if(IntentGeometryMatchesPosition(sym,tk)) fallbackPosition=tk;
   }
   if(fallbackPosition>0 && PositionSelectByTicket(fallbackPosition))
   {
      ticket=fallbackPosition;
      pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
      WriteReconciliationRow("WARN","INTENT_COMMENT_FALLBACK_POSITION",sym,pid,ticket,InpMagic,
         PositionGetString(POSITION_COMMENT),"broker comment did not preserve nonce; strict time/side/volume geometry matched");
      return true;
   }

   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong ot=OrderGetTicket(i); if(ot==0) continue;
      if(OrderGetString(ORDER_SYMBOL)!=sym || OrderGetInteger(ORDER_MAGIC)!=InpMagic) continue;
      string nonce=ExtractIntentNonce(OrderGetString(ORDER_COMMENT));
      if(nonce!="" && IntentNonceHash(nonce)==nonceHash){ ticket=ot; return true; }
   }

   datetime now=TimeTradeServer();
   if(!HistorySelect(now-86400*3,now)) return false;
   ulong fallbackDeal=0;
   int nd=HistoryDealsTotal();
   for(int i=nd-1;i>=0;i--)
   {
      ulong d=HistoryDealGetTicket(i); if(d==0) continue;
      if(HistoryDealGetString(d,DEAL_SYMBOL)!=sym || HistoryDealGetInteger(d,DEAL_MAGIC)!=InpMagic) continue;
      string nonce=ExtractIntentNonce(HistoryDealGetString(d,DEAL_COMMENT));
      if(nonce!="" && IntentNonceHash(nonce)==nonceHash)
      {
         pid=(ulong)HistoryDealGetInteger(d,DEAL_POSITION_ID);
         closed=!PositionIdentifierOpen(pid);
         return true;
      }
      if(fallbackDeal==0 && IntentGeometryMatchesDeal(sym,d)) fallbackDeal=d;
   }
   if(fallbackDeal>0)
   {
      pid=(ulong)HistoryDealGetInteger(fallbackDeal,DEAL_POSITION_ID);
      closed=!PositionIdentifierOpen(pid);
      WriteReconciliationRow("WARN","INTENT_COMMENT_FALLBACK_DEAL",sym,pid,0,InpMagic,
         HistoryDealGetString(fallbackDeal,DEAL_COMMENT),"broker comment did not preserve nonce; strict entry time/side/volume geometry matched");
      return true;
   }

   ulong fallbackOrder=0;
   int no=HistoryOrdersTotal();
   for(int i=no-1;i>=0;i--)
   {
      ulong o=HistoryOrderGetTicket(i); if(o==0) continue;
      if(HistoryOrderGetString(o,ORDER_SYMBOL)!=sym || HistoryOrderGetInteger(o,ORDER_MAGIC)!=InpMagic) continue;
      string nonce=ExtractIntentNonce(HistoryOrderGetString(o,ORDER_COMMENT));
      if(nonce!="" && IntentNonceHash(nonce)==nonceHash){ ticket=o; closed=true; return true; }
      if(fallbackOrder==0 && IntentGeometryMatchesHistoryOrder(sym,o)) fallbackOrder=o;
   }
   if(fallbackOrder>0)
   {
      ticket=fallbackOrder; closed=true;
      WriteReconciliationRow("WARN","INTENT_COMMENT_FALLBACK_ORDER",sym,0,ticket,InpMagic,"",
         "broker comment did not preserve nonce; strict order time/side/volume geometry matched");
      return true;
   }
   return false;
}

void ReconcileIntentForSymbol(const string sym)
{
   if(!InpUseExactlyOnceExecution || sym=="") return;
   int state=(int)GVRead(SymKey(sym,"INTENT_STATE"),INTENT_NONE);
   int nh=(int)GVRead(SymKey(sym,"INTENT_NONCE_HASH"),0);
   datetime tm=(datetime)GVRead(SymKey(sym,"INTENT_TIME"),0);
   if(state==INTENT_NONE || state==INTENT_FAILED || state==INTENT_CLOSED) return;

   ulong ticket=0,pid=0; bool closed=false;
   bool found=PositionOrHistoryMatchesIntent(sym,nh,ticket,pid,closed);
   if(found)
   {
      if(pid>0 && PositionIdentifierOpen(pid))
      {
         GVWrite(SymKey(sym,"INTENT_STATE"),INTENT_FILLED);
         GVWrite(PosKey(pid,"INTENT_NONCE_HASH"),nh);
         GVWrite(PosKey(pid,"INTENT_BOUND"),1);
         WriteReconciliationRow("INFO","INTENT_RECONCILED_OPEN",sym,pid,ticket,InpMagic,"","broker evidence joined to intent");
      }
      else if(closed)
      {
         GVWrite(SymKey(sym,"INTENT_STATE"),INTENT_CLOSED);
         WriteReconciliationRow("INFO","INTENT_RECONCILED_CLOSED",sym,pid,ticket,InpMagic,"","historical broker evidence joined to intent");
      }
      GlobalVariablesFlush();
      return;
   }

   if((state==INTENT_SENT || state==INTENT_UNCERTAIN || state==INTENT_PREPARED) &&
      tm>0 && TimeTradeServer()-tm>=MathMax(60,InpIntentAmbiguityResolveSeconds) &&
      (bool)TerminalInfoInteger(TERMINAL_CONNECTED))
   {
      // After a conservative reconciliation window with synchronized history and
      // no matching broker position/order/deal, resolve as FAILED. Until then,
      // exactly-once semantics prohibit resubmission.
      GVWrite(SymKey(sym,"INTENT_STATE"),INTENT_FAILED);
      WriteReconciliationRow("WARN","INTENT_RESOLVED_NO_BROKER_EVIDENCE",sym,0,0,InpMagic,"",
         "ambiguity window elapsed; no matching position/order/deal found; future new intent allowed");
      GlobalVariablesFlush();
   }
}

void ReconcileBrokerAgainstEA()
{
   if(!InpUseBrokerEAReconciliation) return;
   g_reconciliationBlocked=false; g_reconciliationWhy="";

   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0 || !PositionSelectByTicket(tk)) continue;
      string sym=PositionGetString(POSITION_SYMBOL);
      long magic=PositionGetInteger(POSITION_MAGIC);
      ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
      string comment=PositionGetString(POSITION_COMMENT);

      if(magic==InpMagic)
      {
         double vol=PositionGetDouble(POSITION_VOLUME);
         double sl=PositionGetDouble(POSITION_SL);
         double tp=PositionGetDouble(POSITION_TP);
         double oldVol=GVRead(PosKey(pid,"RECON_VOL"),0);
         double oldSL=GVRead(PosKey(pid,"RECON_SL"),0);
         double oldTP=GVRead(PosKey(pid,"RECON_TP"),0);
         double step=MathMax(SymbolInfoDouble(sym,SYMBOL_VOLUME_STEP),0.0000001);
         double tick=MathMax(SymbolInfoDouble(sym,SYMBOL_TRADE_TICK_SIZE),PointFor(sym));

         if(oldVol>0 && vol>oldVol+0.5*step)
         {
            GVWrite(PosKey(pid,"BROKER_ANOMALY"),1);
            MarkLearningQuarantine(pid,sym,"position volume increased outside recorded EA intent");
            g_reconciliationBlocked=true;
            g_reconciliationWhy=sym+" broker volume exceeds last reconciled EA volume";
            WriteReconciliationRow("CRITICAL","UNEXPECTED_VOLUME_INCREASE",sym,pid,tk,magic,comment,g_reconciliationWhy);
         }
         if(oldVol>0 && vol<oldVol-0.5*step &&
            !PositionFlag(pid,tk,"TP1PARTIAL") && !PositionFlag(pid,tk,"TP2PARTIAL") &&
            GVRead(PosKey(pid,"MANUAL_INTERVENTION"),0)<0.5)
         {
            GVWrite(PosKey(pid,"BROKER_ANOMALY"),1);
            MarkLearningQuarantine(pid,sym,"unexplained broker-side/partial volume reduction");
            WriteReconciliationRow("WARN","UNEXPLAINED_VOLUME_REDUCTION",sym,pid,tk,magic,comment,
               StringFormat("volume %.4f -> %.4f without recorded partial state",oldVol,vol));
         }
         datetime expectedUntil=(datetime)GVRead(PosKey(pid,"EA_EXPECT_MOD_UNTIL"),0);
         double expectedSL=GVRead(PosKey(pid,"EA_EXPECT_SL"),oldSL);
         double expectedTP=GVRead(PosKey(pid,"EA_EXPECT_TP"),oldTP);
         bool expectedWindow=(expectedUntil>0 && TimeTradeServer()<=expectedUntil);
         bool expectedSLMatch=(MathAbs(sl-expectedSL)<=0.5*tick);
         bool expectedTPMatch=(MathAbs(tp-expectedTP)<=0.5*tick);
         bool expectedModification=(expectedWindow && expectedSLMatch && expectedTPMatch);

         if(oldSL>0 && MathAbs(sl-oldSL)>0.5*tick && GVRead(PosKey(pid,"MANUAL_INTERVENTION"),0)<0.5 && !expectedModification)
         {
            double tracked=GVRead(PosKey(pid,"LASTSL"),GVRead(PosKey(pid,"INITSL"),oldSL));
            if(tracked>0 && MathAbs(sl-tracked)>0.5*tick)
            {
               GVWrite(PosKey(pid,"MANUAL_INTERVENTION"),1);
               MarkLearningQuarantine(pid,sym,"external SL modification differs from EA-tracked protection state");
               WriteReconciliationRow("WARN","EXTERNAL_SL_CHANGE",sym,pid,tk,magic,comment,
                  StringFormat("SL %.10f -> %.10f tracked %.10f; no matching EA modification intent",oldSL,sl,tracked));
            }
         }
         if(oldTP>0 && MathAbs(tp-oldTP)>0.5*tick && GVRead(PosKey(pid,"MANUAL_INTERVENTION"),0)<0.5 && !expectedModification)
         {
            int stage=(int)GVRead(PosKey(pid,"SL_STAGE"),0);
            bool expectedTrailRemoval=(stage>=4 && !InpKeepTP3WhileTrailing && tp<=0);
            if(!expectedTrailRemoval)
            {
               GVWrite(PosKey(pid,"MANUAL_INTERVENTION"),1);
               MarkLearningQuarantine(pid,sym,"external TP modification differs from EA-tracked target state");
               WriteReconciliationRow("WARN","EXTERNAL_TP_CHANGE",sym,pid,tk,magic,comment,
                  StringFormat("TP %.10f -> %.10f; no matching EA modification intent",oldTP,tp));
            }
         }
         if(expectedModification)
         {
            GVWrite(PosKey(pid,"EA_EXPECT_MOD_UNTIL"),0);
            WriteReconciliationRow("INFO","EA_MODIFICATION_RECONCILED",sym,pid,tk,magic,comment,
               StringFormat("expected EA SL/TP modification reconciled at SL %.10f TP %.10f",sl,tp));
         }
         else if(expectedUntil>0 && TimeTradeServer()>expectedUntil)
         {
            GVWrite(PosKey(pid,"EA_EXPECT_MOD_UNTIL"),0);
         }

         GVWrite(PosKey(pid,"RECON_VOL"),vol);
         GVWrite(PosKey(pid,"RECON_SL"),sl);
         GVWrite(PosKey(pid,"RECON_TP"),tp);

         bool intentBound=(GVRead(PosKey(pid,"INTENT_BOUND"),0)>0.5 || ExtractIntentNonce(comment)!="");
         bool lifecycle=(GVRead(PosKey(pid,"LIFECYCLE_STATE"),0)>0);
         if(!lifecycle)
         {
            g_reconciliationBlocked=true;
            g_reconciliationWhy=sym+" EA position missing lifecycle metadata";
            WriteReconciliationRow("CRITICAL","MISSING_LIFECYCLE",sym,pid,tk,magic,comment,g_reconciliationWhy);
         }
         if(!intentBound && !InpAllowLegacyOpenPositionsOnUpgrade)
         {
            g_reconciliationBlocked=true;
            g_reconciliationWhy=sym+" EA position missing intent binding";
            WriteReconciliationRow("CRITICAL","ORPHAN_EA_POSITION",sym,pid,tk,magic,comment,g_reconciliationWhy);
         }
      }
      else if(InpBlockUnexpectedManualExposure)
      {
         bool configured=false;
         for(int j=0;j<ArraySize(g_symbols);j++) if(g_symbols[j]==sym){ configured=true; break; }
         if(configured)
         {
            g_reconciliationBlocked=true;
            g_reconciliationWhy=sym+" has external/manual position exposure";
            WriteReconciliationRow("WARN","EXTERNAL_POSITION",sym,pid,tk,magic,comment,g_reconciliationWhy);
         }
      }
   }

   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong ot=OrderGetTicket(i); if(ot==0) continue;
      if(OrderGetInteger(ORDER_MAGIC)!=InpMagic) continue;
      string sym=OrderGetString(ORDER_SYMBOL);
      // GPT_EA submits market orders, not durable pending entries.
      ENUM_ORDER_TYPE t=(ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(t==ORDER_TYPE_BUY_LIMIT || t==ORDER_TYPE_SELL_LIMIT || t==ORDER_TYPE_BUY_STOP || t==ORDER_TYPE_SELL_STOP ||
         t==ORDER_TYPE_BUY_STOP_LIMIT || t==ORDER_TYPE_SELL_STOP_LIMIT)
      {
         g_reconciliationBlocked=true;
         g_reconciliationWhy=sym+" unexpected EA pending order exists";
         WriteReconciliationRow("CRITICAL","UNEXPECTED_PENDING_ORDER",sym,0,ot,InpMagic,OrderGetString(ORDER_COMMENT),g_reconciliationWhy);
      }
   }

   for(int j=0;j<ArraySize(g_symbols);j++) if(g_symbols[j]!="") ReconcileIntentForSymbol(g_symbols[j]);
}

void MarkManualIntervention(ulong pid,const string sym,const string detail)
{
   if(pid==0) return;
   GVWrite(PosKey(pid,"MANUAL_INTERVENTION"),1);
   MarkLearningQuarantine(pid,sym,"manual intervention: "+detail);
   WriteReconciliationRow("WARN","MANUAL_INTERVENTION",sym,pid,0,0,"",detail);
}

void HandleReliabilityTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result)
{
   if(ChaosDropTradeTransaction())
   {
      GVWrite(SysKey("CHAOS_DROPPED_TRANSACTION"),GVRead(SysKey("CHAOS_DROPPED_TRANSACTION"),0)+1);
      return;
   }

   string sig=StringFormat("%d|%I64u|%I64u|%I64u|%I64u",(int)trans.type,trans.deal,trans.order,trans.position,trans.position_by);
   int h=IntegrityTextHash(sig);
   datetime now=TimeTradeServer();
   if(h==g_lastTransactionSignature && now-g_lastTransactionTime<=2)
   {
      GVWrite(SysKey("DUPLICATE_TRADE_CALLBACK"),GVRead(SysKey("DUPLICATE_TRADE_CALLBACK"),0)+1);
      return;
   }
   g_lastTransactionSignature=h; g_lastTransactionTime=now;

   bool injectDuplicate=ChaosDuplicateTradeTransaction();

   ulong pid=trans.position;
   string sym=trans.symbol;
   if(trans.deal>0 && HistoryDealSelect(trans.deal))
   {
      pid=(ulong)HistoryDealGetInteger(trans.deal,DEAL_POSITION_ID);
      sym=HistoryDealGetString(trans.deal,DEAL_SYMBOL);
      ENUM_DEAL_REASON reason=(ENUM_DEAL_REASON)HistoryDealGetInteger(trans.deal,DEAL_REASON);
      if(reason==DEAL_REASON_CLIENT || reason==DEAL_REASON_MOBILE || reason==DEAL_REASON_WEB)
      {
         if(pid>0 && (GVRead(PosKey(pid,"STRATEGY"),0)>0 || GVRead(PosKey(pid,"INTENT_BOUND"),0)>0.5))
            MarkManualIntervention(pid,sym,"deal reason "+EnumToString(reason));
      }
   }

   // MqlTradeRequest is authoritative only for TRADE_TRANSACTION_REQUEST.
   // Do not infer manual POSITION modifications from request.magic here.
   // Periodic broker reconciliation compares current SL/TP/volume with explicit
   // EA modification intents and flags only unexplained external changes.

   if(injectDuplicate)
   {
      // Simulate delivery of the same callback a second time. The duplicate
      // signature guard is the only state transition the duplicate may cause.
      if(h==g_lastTransactionSignature && now-g_lastTransactionTime<=2)
         GVWrite(SysKey("DUPLICATE_TRADE_CALLBACK"),GVRead(SysKey("DUPLICATE_TRADE_CALLBACK"),0)+1);
   }
}

void ExecutionReliabilityInit()
{
   string storage=""; CriticalStorageHealthCheck(storage);
   string cfg=""; ConfigurationDriftAllows(cfg);
   ReconcileBrokerAgainstEA();
   Print("GPT_EA execution reliability initialized | ",storage," | ",cfg,
         " | reconciliation ",g_reconciliationBlocked?"BLOCK":"PASS");
}

void ExecutionReliabilityTimer()
{
   datetime now=TimeTradeServer();
   if(g_lastStorageCheck==0 || now-g_lastStorageCheck>=MathMax(10,InpStorageHealthIntervalSeconds))
   {
      string q=""; CriticalStorageHealthCheck(q);
   }
   if(g_lastReconcile==0 || now-g_lastReconcile>=30)
   {
      ReconcileBrokerAgainstEA();
      g_lastReconcile=now;
   }
}

void ExecutionReliabilityShutdown()
{
   ReconcileBrokerAgainstEA();
   string q=""; CriticalStorageHealthCheck(q);
}
// GPT_EA Part 43 - Post-trade causal attribution

input bool   InpUsePostTradeCausalAttribution = true;
input string InpCausalAttributionFile         = "GPT_EA_CausalAttribution.csv";
input double InpCausalHighSlippageR           = 0.15;
input double InpCausalGivebackMFER             = 1.00;

void EnsureCausalAttributionHeader()
{
   if(!InpUsePostTradeCausalAttribution) return;
   bool exists=FileIsExist(InpCausalAttributionFile,FILE_COMMON);
   int h=FileOpen(InpCausalAttributionFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(h==INVALID_HANDLE) return;
   if(!exists || FileSize(h)==0)
      FileWrite(h,"schema_version","time","position_id","symbol","strategy","strategy_config","release_id",
         "config_fingerprint","model_policy","realized_r","mae_r","mfe_r","slippage_pts","latency_ms","event_class",
         "stored_market_state","current_market_state","cause","detail","quarantined");
   FileClose(h);
}

string CausalAttributionForPosition(ulong pid,const string sym,double realizedR,string &detail)
{
   detail="";
   StrategyClass c=(StrategyClass)(int)GVRead(PosKey(pid,"STRATEGY"),0);
   double mae=GVRead(PosKey(pid,"MAE_R"),0);
   double mfe=GVRead(PosKey(pid,"MFE_R"),0);
   double slipPts=MathMax(0.0,GVRead(PosKey(pid,"EXEC_SLIP_PTS"),0));
   double latency=GVRead(PosKey(pid,"EXEC_LATENCY_MS"),0);
   int ev=(int)GVRead(PosKey(pid,"EVENT_CLASS"),0);
   int storedState=(int)GVRead(PosKey(pid,"MARKET_STATE"),STATE_UNKNOWN);

   if(GVRead(PosKey(pid,"MANUAL_INTERVENTION"),0)>0.5)
   { detail="trade path was changed from outside the EA"; return "MANUAL_INTERVENTION"; }
   if(GVRead(PosKey(pid,"STORAGE_ANOMALY"),0)>0.5 || GVRead(PosKey(pid,"BROKER_ANOMALY"),0)>0.5 ||
      GVRead(PosKey(pid,"CONNECTION_ANOMALY"),0)>0.5 || GVRead(PosKey(pid,"CHAOS_SAMPLE"),0)>0.5)
   { detail="operational/broker/storage/fault-injection anomaly present"; return "OPERATIONAL_ERROR"; }

   double riskMoney=GVRead(PosKey(pid,"RISK"),0);
   double onePointMoney=0;
   if(riskMoney>0)
   {
      double lots=GVRead(PosKey(pid,"EXEC_LOTS"),0);
      double pt=PointFor(sym);
      if(lots>0 && pt>0)
      {
         double pnl=0,entry=GVRead(PosKey(pid,"EXEC_FILL"),GVRead(PosKey(pid,"EXEC_EXPECTED"),0));
         if(entry>0 && OrderCalcProfit(ORDER_TYPE_BUY,sym,lots,entry,entry+pt,pnl))
            onePointMoney=MathAbs(pnl);
      }
   }
   double slipR=(riskMoney>0?slipPts*onePointMoney/riskMoney:0);
   if(realizedR<=0 && slipR>=InpCausalHighSlippageR)
   { detail=StringFormat("slippage cost estimated %.2fR",slipR); return "EXECUTION_COST"; }

   int halfLife=StrategyDecisionHalfLifeSeconds(c);
   double budgetMs=halfLife*1000.0*MathMax(0.05,MathMin(0.90,InpMaxLatencyBudgetFraction));
   if(realizedR<=0 && latency>budgetMs && latency>0)
   { detail=StringFormat("execution latency %.0f ms exceeded %.0f ms budget",latency,budgetMs); return "DELAYED_ENTRY"; }

   if(realizedR<=0 && ev!=EVENT_NONE)
   { detail="loss occurred in event-specific context "+AdaptiveEventName(ev); return "NEWS_OR_EVENT_SHOCK"; }

   StrategySnapshot x; BuildStrategySnapshot(sym,x);
   if(realizedR<=0 && storedState!=STATE_UNKNOWN && (int)x.state!=storedState)
   {
      detail="market state transitioned from "+MarketStateName((MarketStateClass)storedState)+" to "+MarketStateName(x.state);
      return "REGIME_TRANSITION";
   }

   if(realizedR<=0 && mfe>=MathMax(0.5,InpCausalGivebackMFER))
   {
      detail=StringFormat("trade reached %.2fR favorable excursion before closing at %.2fR",mfe,realizedR);
      return "PROFIT_GIVEBACK_OR_EXIT_TIMING";
   }
   if(realizedR<0 && mae>=0.90 && mfe<0.35)
   {
      detail=StringFormat("adverse excursion %.2fR with only %.2fR favorable excursion",mae,mfe);
      return "THESIS_OR_ENTRY_FAILURE";
   }
   if(realizedR<0)
   {
      detail=StringFormat("negative outcome %.2fR without dominant operational attribution",realizedR);
      return "STRATEGY_THESIS_FAILURE";
   }
   if(realizedR>0 && mfe>realizedR+0.75)
   {
      detail=StringFormat("realized %.2fR from %.2fR MFE; runner/exit efficiency review",realizedR,mfe);
      return "PROFITABLE_WITH_EXIT_OPPORTUNITY";
   }
   detail=StringFormat("positive outcome %.2fR with no dominant failure attribution",realizedR);
   return "SUCCESSFUL_STRATEGY_EXECUTION";
}

void WriteCausalAttribution(ulong pid,const string sym,double realizedR,const string cause,const string detail)
{
   EnsureCausalAttributionHeader();
   int h=FileOpen(InpCausalAttributionFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(h==INVALID_HANDLE) return;
   StrategyClass c=(StrategyClass)(int)GVRead(PosKey(pid,"STRATEGY"),0);
   StrategySnapshot x; BuildStrategySnapshot(sym,x);
   FileSeek(h,0,SEEK_END);
   FileWrite(h,"causal_attribution_v1",TimeToString(TimeTradeServer(),TIME_DATE|TIME_SECONDS),(string)pid,sym,
      StrategyClassName(c),StrategyConfigVersion(c),GPT_EA_REQUIRED_RELEASE_VALIDATION_ID,CurrentConfigFingerprint(),
      InpModelPolicyVersion,DoubleToString(realizedR,3),DoubleToString(GVRead(PosKey(pid,"MAE_R"),0),3),
      DoubleToString(GVRead(PosKey(pid,"MFE_R"),0),3),DoubleToString(GVRead(PosKey(pid,"EXEC_SLIP_PTS"),0),1),
      DoubleToString(GVRead(PosKey(pid,"EXEC_LATENCY_MS"),0),0),(int)GVRead(PosKey(pid,"EVENT_CLASS"),0),
      MarketStateName((MarketStateClass)(int)GVRead(PosKey(pid,"MARKET_STATE"),STATE_UNKNOWN)),
      MarketStateName(x.state),cause,detail,GVRead(PosKey(pid,"LEARN_QUARANTINE"),0)>0.5?"1":"0");
   FileFlush(h); FileClose(h);
}

void FinalizeCausalAttributionHistory()
{
   if(!InpUsePostTradeCausalAttribution) return;
   datetime now=TimeTradeServer(),from=now-MathMax(10,InpStrategyHistoryLookbackDays)*86400;
   if(!HistorySelect(from,now)) return;

   ulong pids[]; string syms[];
   int n=HistoryDealsTotal();
   for(int i=MathMax(0,n-1200);i<n;i++)
   {
      ulong d=HistoryDealGetTicket(i); if(d==0) continue;
      ENUM_DEAL_ENTRY e=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(d,DEAL_ENTRY);
      if(e!=DEAL_ENTRY_OUT && e!=DEAL_ENTRY_OUT_BY && e!=DEAL_ENTRY_INOUT) continue;
      ulong pid=(ulong)HistoryDealGetInteger(d,DEAL_POSITION_ID);
      if(pid==0 || PositionIdentifierOpen(pid) || GVRead(PosKey(pid,"CAUSE_FINAL"),0)>0.5) continue;
      if(GVRead(PosKey(pid,"STRATEGY"),0)<=0 || GVRead(PosKey(pid,"RISK"),0)<=0) continue;
      bool dup=false; for(int j=0;j<ArraySize(pids);j++) if(pids[j]==pid){ dup=true; break; }
      if(dup) continue;
      int at=ArraySize(pids); ArrayResize(pids,at+1); ArrayResize(syms,at+1);
      pids[at]=pid; syms[at]=HistoryDealGetString(d,DEAL_SYMBOL);
   }

   for(int i=0;i<ArraySize(pids);i++)
   {
      ulong pid=pids[i];
      double risk=GVRead(PosKey(pid,"RISK"),0); if(risk<=0) continue;
      double realized=StrategyPositionRealized(pid)/risk;
      string detail="";
      string cause=CausalAttributionForPosition(pid,syms[i],realized,detail);
      WriteCausalAttribution(pid,syms[i],realized,cause,detail);
      GVWrite(PosKey(pid,"CAUSE_FINAL"),1);
   }
   GlobalVariablesFlush();
}

void CausalAttributionInit()
{
   EnsureCausalAttributionHeader();
   FinalizeCausalAttributionHistory();
}

void CausalAttributionTimer()
{
   FinalizeCausalAttributionHistory();
}
// GPT_EA Part 34 - Strategy health dashboard and adaptive telemetry
// Strategy health status contract: ACTIVE / REDUCED_RISK / SHADOW / DISABLED.

input bool   InpShowStrategyHealthDashboard       = true;
input bool   InpWriteStrategyHealthJournal        = true;
input string InpStrategyHealthJournalFile         = "GPT_EA_StrategyHealthV2.csv";
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
         "champion_challenger","risk_multiplier","release_id","strategy_engine","model_policy",
         "config_fingerprint","symbol_fingerprint","strategy_config");
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
      FileWrite(h,"strategy_health_v2",TimeToString(now,TIME_DATE|TIME_SECONDS),StrategyClassName(c),AdaptiveStrategyModeName(StrategyHealthMode(c)),
         n,DoubleToString(wr,1),DoubleToString(avg,3),DoubleToString(pf,3),DoubleToString(dd,3),ml,
         rn,DoubleToString(ravg,3),DoubleToString(rpf,3),DoubleToString(realRR,3),DoubleToString(slip,1),regime,
         regN,DoubleToString(regAvg,3),DoubleToString(regPF,3),SnapshotText(ChampionChallengerSummary(c)),DoubleToString(StrategyHealthRiskMultiplier(c),2),
         GPT_EA_REQUIRED_RELEASE_VALIDATION_ID,InpStrategyEngineVersion,InpModelPolicyVersion,CurrentConfigFingerprint(),
         SymbolContractFingerprint(ref),StrategyConfigVersion(c));
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
// GPT_EA Part 36 - Machine-observed R6 demo-soak evidence
// This module does NOT self-certify a release. It records durable observations
// and writes an exportable demo_soak JSON object. The operator must reconcile
// the machine evidence with terminal logs, complete the report, finalize the
// SHA-256 digest offline and pass the R6 release-evidence validators.

input bool   InpEnableDemoSoakEvidence              = false;
input string InpDemoSoakEvidenceId                  = ""; // >= 8 chars; unique per candidate soak
input string InpDemoSoakEvidenceFile                = "GPT_EA_DemoSoakEvidence.csv";
input string InpDemoSoakSnapshotJsonFile            = "GPT_EA_DemoSoakSnapshot.json";
input string InpDemoSoakReportReference             = "artifacts/demo-soak-report.md";
input int    InpDemoSoakObservationSeconds          = 60;
input int    InpDemoSoakSummaryMinutes              = 15;
input int    InpDemoSoakFreshQuoteSeconds           = 60;
input bool   InpDemoSoakCountWeekendTradingDays     = false;
input int    InpDemoSoakRolloverStartHourUTC        = 20;
input int    InpDemoSoakRolloverEndHourUTC          = 23;
input double InpDemoSoakRolloverSpreadATRFrac       = 0.12;

const string GPT_EA_DEMO_SOAK_RUNTIME_SCHEMA="demo_soak_evidence_v1";

enum LifecycleWaitReasonClass
{
   LIFECYCLE_WAIT_UNSPECIFIED=0,
   LIFECYCLE_WAIT_MARKET_CONFIRMATION=1,
   LIFECYCLE_WAIT_HUMAN_APPROVAL=2
};

string DemoSoakKey(const string suffix){ return SysKey("SOAK_"+suffix); }

bool DemoSoakEligible()
{
   if(!InpEnableDemoSoakEvidence || (bool)MQLInfoInteger(MQL_TESTER)) return false;
   if(AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_REAL) return false;
   return StringLen(InpDemoSoakEvidenceId)>=8;
}

string DemoSoakIso(datetime tm)
{
   MqlDateTime t={}; TimeToStruct(tm,t);
   return StringFormat("%04d-%02d-%02dT%02d:%02d:%02d",t.year,t.mon,t.day,t.hour,t.min,t.sec);
}

datetime DemoSoakDayStart(datetime tm)
{
   MqlDateTime t={}; TimeToStruct(tm,t);
   t.hour=0; t.min=0; t.sec=0;
   return StructToTime(t);
}

bool DemoSoakTradingDay(datetime tm)
{
   if(InpDemoSoakCountWeekendTradingDays) return true;
   MqlDateTime t={}; TimeToStruct(tm,t);
   return (t.day_of_week>=1 && t.day_of_week<=5);
}

bool DemoSoakConsecutiveTradingDay(datetime prevDay,datetime curDay)
{
   if(prevDay<=0 || curDay<=prevDay) return false;
   int gap=(int)((curDay-prevDay)/86400);
   if(InpDemoSoakCountWeekendTradingDays) return gap==1;
   MqlDateTime p={},c={}; TimeToStruct(prevDay,p); TimeToStruct(curDay,c);
   if(gap==1) return true;
   if(p.day_of_week==5 && c.day_of_week==1 && gap==3) return true; // Fri -> Mon
   return false;
}

bool DemoSoakHasFreshQuote(string &observedSymbol)
{
   observedSymbol="";
   datetime now=TimeTradeServer();
   int maxAge=MathMax(5,InpDemoSoakFreshQuoteSeconds);
   for(int i=0;i<ArraySize(g_symbols);i++)
   {
      string sym=g_symbols[i]; if(sym=="") continue;
      MqlTick t={}; if(!GetTickSafe(sym,t) || t.bid<=0 || t.ask<=0 || t.time<=0) continue;
      if(MathAbs((double)(now-t.time))<=maxAge){ observedSymbol=sym; return true; }
   }
   return false;
}

bool DemoSoakHasOpenPosition(const string sym)
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)==InpMagic && PositionGetString(POSITION_SYMBOL)==sym) return true;
   }
   return false;
}

bool DemoSoakPendingApprovalActive(const string sym)
{
   for(int i=0;i<ArraySize(g_pending);i++)
      if(g_pending[i].active && g_pending[i].setup.symbol==sym) return true;
   return false;
}

bool DemoSoakAnyPendingApproval()
{
   for(int i=0;i<ArraySize(g_pending);i++) if(g_pending[i].active) return true;
   return false;
}

void EnsureDemoSoakEvidenceHeader()
{
   if(!DemoSoakEligible()) return;
   bool exists=FileIsExist(InpDemoSoakEvidenceFile,FILE_COMMON);
   int h=FileOpen(InpDemoSoakEvidenceFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(h==INVALID_HANDLE){ Print("Demo-soak evidence file open failed: ",GetLastError()); return; }
   if(!exists || FileSize(h)==0)
      FileWrite(h,"schema_version","time","run_id","event","symbol","detail",
         "trading_days","current_consecutive_days","london_sessions","ny_sessions","overlap_observed","news_day_observed","rollover_observed",
         "restart_observed","reconnect_observed","scheduled_scans","continuous_scans","manual_scans","checkpoint_updates","backup_checkpoint_updates",
         "zero_tolerance_failures","unresolved_critical_states","duplicate_orders","duplicate_partials","sl_regressions","unprotected_new_authorizations",
         "release_gate_bypasses","analytics_duplicate_finalizations","stop_failure_join_failures","dashboard_gate_mismatches","runtime_critical_errors",
         "secrets_exposed","execution_log_present","stop_log_present","release_evidence_log_present","machine_coverage_ready","broker","server");
   FileClose(h);
}

bool DemoSoakLogPresent(const string fileName)
{
   if(fileName=="") return false;
   return FileIsExist(fileName,FILE_COMMON);
}

void RefreshDemoSoakLogPresence()
{
   GVWrite(DemoSoakKey("EXEC_LOG"),DemoSoakLogPresent(InpExecutionJournalFile)?1:0);
   GVWrite(DemoSoakKey("STOP_LOG"),DemoSoakLogPresent(InpStopFailureObservabilityFile)?1:0);
   GVWrite(DemoSoakKey("RELEASE_LOG"),DemoSoakLogPresent(InpReleaseEvidenceSnapshotFile)?1:0);
}

bool DemoSoakFailureCountersClear()
{
   string keys[]={"ZERO_TOL","UNRESOLVED_CURRENT","DUP_ORDERS","DUP_PARTIALS","SL_REGRESSIONS","UNPROTECTED_AUTH",
                  "RELEASE_BYPASS","ANALYTICS_DUP_FINAL","STOP_JOIN_FAIL","DASH_MISMATCH","RUNTIME_CRITICAL","SECRETS"};
   for(int i=0;i<ArraySize(keys);i++) if(GVRead(DemoSoakKey(keys[i]),0)!=0) return false;
   return true;
}

bool DemoSoakCoverageReady()
{
   if(!DemoSoakEligible()) return false;
   RefreshDemoSoakLogPresence();
   return (GVRead(DemoSoakKey("MAX_CONSEC_DAYS"),0)>=5 &&
           GVRead(DemoSoakKey("LONDON_DAYS"),0)>=3 && GVRead(DemoSoakKey("NY_DAYS"),0)>=3 &&
           GVRead(DemoSoakKey("OVERLAP_DAYS"),0)>=1 && GVRead(DemoSoakKey("NEWS_DAYS"),0)>=1 &&
           GVRead(DemoSoakKey("ROLLOVER_SPREAD"),0)>0.5 && GVRead(DemoSoakKey("RESTARTS"),0)>=1 &&
           GVRead(DemoSoakKey("RECONNECTS"),0)>=1 && GVRead(DemoSoakKey("SCHEDULED_SCANS"),0)>=1 &&
           GVRead(DemoSoakKey("CONTINUOUS_SCANS"),0)>=1 && GVRead(DemoSoakKey("MANUAL_SCANS"),0)>=1 &&
           GVRead(DemoSoakKey("CHECKPOINT_UPDATES"),0)>=1 && GVRead(DemoSoakKey("BACKUP_CHECKPOINT_UPDATES"),0)>=1 &&
           DemoSoakFailureCountersClear() && GVRead(DemoSoakKey("EXEC_LOG"),0)>0.5 &&
           GVRead(DemoSoakKey("STOP_LOG"),0)>0.5 && GVRead(DemoSoakKey("RELEASE_LOG"),0)>0.5);
}

void WriteDemoSoakEvidenceEvent(const string eventName,const string symbol,const string detail)
{
   if(!DemoSoakEligible()) return;
   EnsureDemoSoakEvidenceHeader();
   RefreshDemoSoakLogPresence();
   int h=FileOpen(InpDemoSoakEvidenceFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(h==INVALID_HANDLE) return;
   FileSeek(h,0,SEEK_END);
   FileWrite(h,GPT_EA_DEMO_SOAK_RUNTIME_SCHEMA,TimeToString(TimeTradeServer(),TIME_DATE|TIME_SECONDS),InpDemoSoakEvidenceId,eventName,symbol,detail,
      (int)GVRead(DemoSoakKey("MAX_CONSEC_DAYS"),0),(int)GVRead(DemoSoakKey("CONSEC_DAYS"),0),
      (int)GVRead(DemoSoakKey("LONDON_DAYS"),0),(int)GVRead(DemoSoakKey("NY_DAYS"),0),
      GVRead(DemoSoakKey("OVERLAP_DAYS"),0)>0?1:0,GVRead(DemoSoakKey("NEWS_DAYS"),0)>0?1:0,GVRead(DemoSoakKey("ROLLOVER_SPREAD"),0)>0.5?1:0,
      GVRead(DemoSoakKey("RESTARTS"),0)>0?1:0,GVRead(DemoSoakKey("RECONNECTS"),0)>0?1:0,
      (int)GVRead(DemoSoakKey("SCHEDULED_SCANS"),0),(int)GVRead(DemoSoakKey("CONTINUOUS_SCANS"),0),(int)GVRead(DemoSoakKey("MANUAL_SCANS"),0),
      (int)GVRead(DemoSoakKey("CHECKPOINT_UPDATES"),0),(int)GVRead(DemoSoakKey("BACKUP_CHECKPOINT_UPDATES"),0),
      (int)GVRead(DemoSoakKey("ZERO_TOL"),0),(int)GVRead(DemoSoakKey("UNRESOLVED_CURRENT"),0),(int)GVRead(DemoSoakKey("DUP_ORDERS"),0),
      (int)GVRead(DemoSoakKey("DUP_PARTIALS"),0),(int)GVRead(DemoSoakKey("SL_REGRESSIONS"),0),(int)GVRead(DemoSoakKey("UNPROTECTED_AUTH"),0),
      (int)GVRead(DemoSoakKey("RELEASE_BYPASS"),0),(int)GVRead(DemoSoakKey("ANALYTICS_DUP_FINAL"),0),(int)GVRead(DemoSoakKey("STOP_JOIN_FAIL"),0),
      (int)GVRead(DemoSoakKey("DASH_MISMATCH"),0),(int)GVRead(DemoSoakKey("RUNTIME_CRITICAL"),0),(int)GVRead(DemoSoakKey("SECRETS"),0),
      GVRead(DemoSoakKey("EXEC_LOG"),0)>0.5?1:0,GVRead(DemoSoakKey("STOP_LOG"),0)>0.5?1:0,GVRead(DemoSoakKey("RELEASE_LOG"),0)>0.5?1:0,
      DemoSoakCoverageReady()?1:0,AccountInfoString(ACCOUNT_COMPANY),AccountInfoString(ACCOUNT_SERVER));
   FileFlush(h); FileClose(h);
}

void ResetDemoSoakRunState()
{
   string keys[]={"START_TIME","LAST_INIT","LAST_OBSERVE","LAST_SUMMARY","LAST_DAY","CONSEC_DAYS","MAX_CONSEC_DAYS","TOTAL_DAYS",
      "LAST_LONDON_DAY","LONDON_DAYS","LAST_NY_DAY","NY_DAYS","LAST_OVERLAP_DAY","OVERLAP_DAYS","LAST_NEWS_DAY","NEWS_DAYS",
      "ROLLOVER_WINDOW","ROLLOVER_SPREAD","RESTARTS","RECONNECTS","CONNECTED_PREV","SAW_DISCONNECT",
      "MANUAL_SCANS","SCHEDULED_SCANS","CONTINUOUS_SCANS","LAST_SCAN_TIME","LAST_SCAN_HASH",
      "CHECKPOINT_UPDATES","BACKUP_CHECKPOINT_UPDATES","LAST_CHECKPOINT_TIME",
      "ZERO_TOL","INCIDENTS","UNRESOLVED_CURRENT","CRITICAL_LATCH","UNPROTECTED_AUTH_LATCH","DASH_MISMATCH_LATCH",
      "DUP_ORDERS","DUP_PARTIALS","SL_REGRESSIONS","UNPROTECTED_AUTH","RELEASE_BYPASS","ANALYTICS_DUP_FINAL","STOP_JOIN_FAIL",
      "DASH_MISMATCH","RUNTIME_CRITICAL","SECRETS","EXEC_LOG","STOP_LOG","RELEASE_LOG"};
   for(int i=0;i<ArraySize(keys);i++) GVWrite(DemoSoakKey(keys[i]),0);
   GVWrite(DemoSoakKey("RUN_HASH"),TextChecksum(InpDemoSoakEvidenceId));
   GVWrite(DemoSoakKey("START_TIME"),(double)TimeTradeServer());
   GlobalVariablesFlush();
}

bool EnsureDemoSoakRun()
{
   if(!DemoSoakEligible()) return false;
   int hash=TextChecksum(InpDemoSoakEvidenceId);
   int stored=(int)GVRead(DemoSoakKey("RUN_HASH"),0);
   if(stored!=hash) ResetDemoSoakRunState();
   return true;
}

void IncrementDemoSoakFailureMetric(const string code)
{
   string u=code; StringToUpper(u);
   if(u=="DUPLICATE_ORDER") GVWrite(DemoSoakKey("DUP_ORDERS"),GVRead(DemoSoakKey("DUP_ORDERS"),0)+1);
   else if(u=="DUPLICATE_PARTIAL") GVWrite(DemoSoakKey("DUP_PARTIALS"),GVRead(DemoSoakKey("DUP_PARTIALS"),0)+1);
   else if(u=="SL_REGRESSION") GVWrite(DemoSoakKey("SL_REGRESSIONS"),GVRead(DemoSoakKey("SL_REGRESSIONS"),0)+1);
   else if(u=="UNPROTECTED_NEW_AUTHORIZATION") GVWrite(DemoSoakKey("UNPROTECTED_AUTH"),GVRead(DemoSoakKey("UNPROTECTED_AUTH"),0)+1);
   else if(u=="RELEASE_GATE_BYPASS") GVWrite(DemoSoakKey("RELEASE_BYPASS"),GVRead(DemoSoakKey("RELEASE_BYPASS"),0)+1);
   else if(u=="ANALYTICS_DUPLICATE_FINALIZATION") GVWrite(DemoSoakKey("ANALYTICS_DUP_FINAL"),GVRead(DemoSoakKey("ANALYTICS_DUP_FINAL"),0)+1);
   else if(u=="STOP_FAILURE_JOIN_FAILURE") GVWrite(DemoSoakKey("STOP_JOIN_FAIL"),GVRead(DemoSoakKey("STOP_JOIN_FAIL"),0)+1);
   else if(u=="DASHBOARD_GATE_MISMATCH") GVWrite(DemoSoakKey("DASH_MISMATCH"),GVRead(DemoSoakKey("DASH_MISMATCH"),0)+1);
   else if(u=="RUNTIME_CRITICAL_ERROR" || u=="CRITICAL_PROTECTION_STATE") GVWrite(DemoSoakKey("RUNTIME_CRITICAL"),GVRead(DemoSoakKey("RUNTIME_CRITICAL"),0)+1);
   else if(u=="SECRET_EXPOSED") GVWrite(DemoSoakKey("SECRETS"),GVRead(DemoSoakKey("SECRETS"),0)+1);
}

void RecordDemoSoakIncident(const string code,const string detail,bool zeroTolerance)
{
   if(!EnsureDemoSoakRun()) return;
   GVWrite(DemoSoakKey("INCIDENTS"),GVRead(DemoSoakKey("INCIDENTS"),0)+1);
   if(zeroTolerance)
   {
      GVWrite(DemoSoakKey("ZERO_TOL"),GVRead(DemoSoakKey("ZERO_TOL"),0)+1);
      IncrementDemoSoakFailureMetric(code);
   }
   WriteDemoSoakEvidenceEvent(zeroTolerance?"ZERO_TOLERANCE_INCIDENT":"INCIDENT","",code+" | "+detail);
   GlobalVariablesFlush();
}

void DemoSoakMarkUniqueDay(const string lastKey,const string countKey,datetime day,const string eventName)
{
   datetime last=(datetime)GVRead(DemoSoakKey(lastKey),0);
   if(last==day) return;
   GVWrite(DemoSoakKey(lastKey),(double)day);
   GVWrite(DemoSoakKey(countKey),GVRead(DemoSoakKey(countKey),0)+1);
   WriteDemoSoakEvidenceEvent(eventName,"",TimeToString(day,TIME_DATE));
}

void ObserveDemoSoakTradingDay(datetime now)
{
   if(!DemoSoakTradingDay(now)) return;
   string sym=""; if(!DemoSoakHasFreshQuote(sym)) return;
   datetime day=DemoSoakDayStart(now);
   datetime last=(datetime)GVRead(DemoSoakKey("LAST_DAY"),0);
   if(last==day) return;
   int consecutive=1;
   if(last>0 && DemoSoakConsecutiveTradingDay(last,day)) consecutive=(int)GVRead(DemoSoakKey("CONSEC_DAYS"),0)+1;
   GVWrite(DemoSoakKey("LAST_DAY"),(double)day);
   GVWrite(DemoSoakKey("CONSEC_DAYS"),consecutive);
   GVWrite(DemoSoakKey("MAX_CONSEC_DAYS"),MathMax(GVRead(DemoSoakKey("MAX_CONSEC_DAYS"),0),(double)consecutive));
   GVWrite(DemoSoakKey("TOTAL_DAYS"),GVRead(DemoSoakKey("TOTAL_DAYS"),0)+1);
   WriteDemoSoakEvidenceEvent("TRADING_DAY_OBSERVED",sym,StringFormat("day %s | consecutive %d",TimeToString(day,TIME_DATE),consecutive));
}

void ObserveDemoSoakSessions(datetime now)
{
   string sym=""; if(!DemoSoakHasFreshQuote(sym)) return;
   datetime day=DemoSoakDayStart(now);
   string ses=AccurateSessionBucket();
   if(ses=="LONDON") DemoSoakMarkUniqueDay("LAST_LONDON_DAY","LONDON_DAYS",day,"LONDON_SESSION_OBSERVED");
   else if(ses=="NEW_YORK_OPEN") DemoSoakMarkUniqueDay("LAST_NY_DAY","NY_DAYS",day,"NEW_YORK_SESSION_OBSERVED");
   else if(ses=="LONDON_NY_OVERLAP")
   {
      DemoSoakMarkUniqueDay("LAST_OVERLAP_DAY","OVERLAP_DAYS",day,"LONDON_NY_OVERLAP_OBSERVED");
      DemoSoakMarkUniqueDay("LAST_LONDON_DAY","LONDON_DAYS",day,"LONDON_SESSION_OBSERVED_VIA_OVERLAP");
      DemoSoakMarkUniqueDay("LAST_NY_DAY","NY_DAYS",day,"NEW_YORK_SESSION_OBSERVED_VIA_OVERLAP");
   }
}

void ObserveDemoSoakNews(datetime now)
{
   datetime day=DemoSoakDayStart(now);
   if((datetime)GVRead(DemoSoakKey("LAST_NEWS_DAY"),0)==day) return;
   for(int i=0;i<ArraySize(g_symbols);i++)
   {
      string sym=g_symbols[i]; if(sym=="") continue;
      if(HighImpactEventWithin(sym,MathMax(30,InpStrategyNewsContextMinutes)))
      {
         GVWrite(DemoSoakKey("LAST_NEWS_DAY"),(double)day);
         GVWrite(DemoSoakKey("NEWS_DAYS"),GVRead(DemoSoakKey("NEWS_DAYS"),0)+1);
         WriteDemoSoakEvidenceEvent("HIGH_IMPACT_NEWS_DAY_OBSERVED",sym,UpcomingEventSummary(sym));
         return;
      }
   }
}

bool DemoSoakRolloverHourUTC(int h)
{
   int a=MathMax(0,MathMin(23,InpDemoSoakRolloverStartHourUTC));
   int b=MathMax(0,MathMin(23,InpDemoSoakRolloverEndHourUTC));
   if(a<=b) return (h>=a && h<=b);
   return (h>=a || h<=b);
}

void ObserveDemoSoakRollover()
{
   MqlDateTime u={}; TimeToStruct(TimeGMT(),u);
   if(!DemoSoakRolloverHourUTC(u.hour)) return;
   if(GVRead(DemoSoakKey("ROLLOVER_WINDOW"),0)<0.5)
   {
      GVWrite(DemoSoakKey("ROLLOVER_WINDOW"),1);
      WriteDemoSoakEvidenceEvent("ROLLOVER_WINDOW_OBSERVED","",StringFormat("UTC hour %d",u.hour));
   }
   if(GVRead(DemoSoakKey("ROLLOVER_SPREAD"),0)>0.5) return;
   for(int i=0;i<ArraySize(g_symbols);i++)
   {
      string sym=g_symbols[i]; if(sym=="") continue;
      MqlTick t={}; double atr=0;
      if(!GetTickSafe(sym,t) || !ATRValue(sym,PERIOD_M5,InpATRPeriod,1,atr) || atr<=0) continue;
      double ratio=(t.ask-t.bid)/atr;
      if(ratio>=MathMax(0.01,InpDemoSoakRolloverSpreadATRFrac))
      {
         GVWrite(DemoSoakKey("ROLLOVER_SPREAD"),1);
         WriteDemoSoakEvidenceEvent("ROLLOVER_SPREAD_EXPANSION_OBSERVED",sym,StringFormat("spread/M5 ATR %.3f",ratio));
         return;
      }
   }
}

void ObserveDemoSoakConnection()
{
   bool connected=(bool)TerminalInfoInteger(TERMINAL_CONNECTED);
   bool prev=GVRead(DemoSoakKey("CONNECTED_PREV"),connected?1:0)>0.5;
   if(!connected)
   {
      if(prev) WriteDemoSoakEvidenceEvent("DISCONNECT_OBSERVED","","terminal connection transitioned to disconnected");
      GVWrite(DemoSoakKey("SAW_DISCONNECT"),1);
   }
   else if(!prev && GVRead(DemoSoakKey("SAW_DISCONNECT"),0)>0.5)
   {
      GVWrite(DemoSoakKey("RECONNECTS"),GVRead(DemoSoakKey("RECONNECTS"),0)+1);
      WriteDemoSoakEvidenceEvent("RECONNECT_OBSERVED","","terminal connection recovered after observed disconnect");
   }
   GVWrite(DemoSoakKey("CONNECTED_PREV"),connected?1:0);
}

void ObserveDemoSoakRecoveryCheckpoints()
{
   datetime cp=g_lastUniversalCheckpoint;
   datetime last=(datetime)GVRead(DemoSoakKey("LAST_CHECKPOINT_TIME"),0);
   if(cp<=0 || cp==last) return;
   GVWrite(DemoSoakKey("LAST_CHECKPOINT_TIME"),(double)cp);
   GVWrite(DemoSoakKey("CHECKPOINT_UPDATES"),GVRead(DemoSoakKey("CHECKPOINT_UPDATES"),0)+1);
   bool backupOK=(InpKeepRecoveryBackup && RecoveryCheckpointHeaderValid(RecoveryBackupFileName()));
   if(backupOK) GVWrite(DemoSoakKey("BACKUP_CHECKPOINT_UPDATES"),GVRead(DemoSoakKey("BACKUP_CHECKPOINT_UPDATES"),0)+1);
   WriteDemoSoakEvidenceEvent("RECOVERY_CHECKPOINT_OBSERVED","",backupOK?"primary + validated backup present":"primary checkpoint update observed; validated backup not yet observed");
}

int DemoSoakCurrentCriticalStates(string &detail)
{
   int count=0; detail="";
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      if(PositionGetDouble(POSITION_SL)<=0){ count++; detail+="unprotected position "+PositionGetString(POSITION_SYMBOL)+"; "; }
   }
   string stopWhy="";
   if(!StopObservabilityAllowsNewEntries(stopWhy))
   {
      string u=stopWhy; StringToUpper(u);
      if(StringFind(u,"CRITICAL")>=0 || StringFind(u,"UNPROTECTED")>=0 || StringFind(u,"OPERATOR")>=0)
      { count++; detail+="stop observability: "+stopWhy+"; "; }
   }
   return count;
}

void ReconcileStaleApprovalWaitStates()
{
   if(!InpUseLifecycleStateMachine) return;
   for(int i=0;i<ArraySize(g_symbols);i++)
   {
      string sym=g_symbols[i]; if(sym=="" || DemoSoakHasOpenPosition(sym)) continue;
      int state=(int)GVRead(SymKey(sym,"LIFECYCLE_STATE"),LIFE_NONE);
      int kind=(int)GVRead(SymKey(sym,"LIFECYCLE_WAIT_KIND"),LIFECYCLE_WAIT_UNSPECIFIED);
      if(state!=LIFE_WAIT_CONFIRMATION || kind!=LIFECYCLE_WAIT_HUMAN_APPROVAL) continue;
      if(DemoSoakPendingApprovalActive(sym)) continue;
      string reason="human-approval WAIT state has no active pending approval; approval/revalidation path ended without a fill";
      if(SetSymbolLifecycle(sym,LIFE_INVALIDATED,reason))
      {
         GVWrite(SymKey(sym,"LIFECYCLE_WAIT_KIND"),LIFECYCLE_WAIT_UNSPECIFIED);
         if(DemoSoakEligible()) WriteDemoSoakEvidenceEvent("STALE_APPROVAL_LIFECYCLE_RECONCILED",sym,reason);
      }
   }
}

void ObserveDemoSoakCriticalStates()
{
   string detail=""; int n=DemoSoakCurrentCriticalStates(detail);
   GVWrite(DemoSoakKey("UNRESOLVED_CURRENT"),n);
   bool latched=GVRead(DemoSoakKey("CRITICAL_LATCH"),0)>0.5;
   if(n>0 && !latched)
   {
      GVWrite(DemoSoakKey("CRITICAL_LATCH"),1);
      RecordDemoSoakIncident("CRITICAL_PROTECTION_STATE",detail,true);
   }
   else if(n==0 && latched)
   {
      GVWrite(DemoSoakKey("CRITICAL_LATCH"),0);
      WriteDemoSoakEvidenceEvent("CRITICAL_STATE_CLEARED","","all machine-observed critical protection states cleared");
   }

   bool unprotected=(n>0);
   bool auth=DemoSoakAnyPendingApproval();
   bool authLatched=GVRead(DemoSoakKey("UNPROTECTED_AUTH_LATCH"),0)>0.5;
   if(unprotected && auth && !authLatched)
   {
      GVWrite(DemoSoakKey("UNPROTECTED_AUTH_LATCH"),1);
      RecordDemoSoakIncident("UNPROTECTED_NEW_AUTHORIZATION","pending approval existed while a machine-observed critical/unprotected state was active",true);
   }
   else if((!unprotected || !auth) && authLatched) GVWrite(DemoSoakKey("UNPROTECTED_AUTH_LATCH"),0);
}

void ObserveDemoSoakReleaseDashboardConsistency()
{
   string summary=ReleaseGateSummary();
   bool reportedPass=(StringFind(summary,"PASS") == 0);
   bool actualPass=!g_releaseBlocked;
   bool mismatch=(reportedPass!=actualPass);
   bool latched=GVRead(DemoSoakKey("DASH_MISMATCH_LATCH"),0)>0.5;
   if(mismatch && !latched)
   {
      GVWrite(DemoSoakKey("DASH_MISMATCH_LATCH"),1);
      RecordDemoSoakIncident("DASHBOARD_GATE_MISMATCH","release summary and runtime g_releaseBlocked disagree: "+summary,true);
   }
   else if(!mismatch && latched) GVWrite(DemoSoakKey("DASH_MISMATCH_LATCH"),0);
}

string DemoSoakCardLine(const string card,const string prefix)
{
   int p=StringFind(card,prefix); if(p<0) return "";
   p+=StringLen(prefix);
   int e=StringFind(card,"\n",p); if(e<0) e=StringLen(card);
   string out=StringSubstr(card,p,e-p); StringTrimLeft(out); StringTrimRight(out); return out;
}

void ObserveDemoSoakScanCard(const string card)
{
   if(!EnsureDemoSoakRun()) return;
   string reason=DemoSoakCardLine(card,"Scan:"); if(reason=="") return;
   if(StringFind(reason,"startup / restart recovery")>=0) return;
   datetime now=TimeTradeServer();
   int hash=TextChecksum(reason);
   datetime last=(datetime)GVRead(DemoSoakKey("LAST_SCAN_TIME"),0);
   int oldHash=(int)GVRead(DemoSoakKey("LAST_SCAN_HASH"),0);
   if(last>0 && now-last<=15 && oldHash==hash) return; // same multi-symbol scan
   GVWrite(DemoSoakKey("LAST_SCAN_TIME"),(double)now); GVWrite(DemoSoakKey("LAST_SCAN_HASH"),hash);

   string u=reason; StringToUpper(u);
   if(StringFind(u,"MANUAL SCAN NOW")>=0)
   {
      GVWrite(DemoSoakKey("MANUAL_SCANS"),GVRead(DemoSoakKey("MANUAL_SCANS"),0)+1);
      WriteDemoSoakEvidenceEvent("MANUAL_SCAN_OBSERVED","",reason);
   }
   else if(StringFind(u,"CONTINUOUS")>=0 || StringFind(u,"NEW-M5-BAR")>=0)
   {
      GVWrite(DemoSoakKey("CONTINUOUS_SCANS"),GVRead(DemoSoakKey("CONTINUOUS_SCANS"),0)+1);
      WriteDemoSoakEvidenceEvent("CONTINUOUS_SCAN_OBSERVED","",reason);
   }
   else
   {
      GVWrite(DemoSoakKey("SCHEDULED_SCANS"),GVRead(DemoSoakKey("SCHEDULED_SCANS"),0)+1);
      WriteDemoSoakEvidenceEvent("SCHEDULED_SCAN_OBSERVED","",reason);
   }
}

void WriteDemoSoakJsonSnapshot()
{
   if(!DemoSoakEligible()) return;
   RefreshDemoSoakLogPresence();
   int h=FileOpen(InpDemoSoakSnapshotJsonFile,FILE_WRITE|FILE_TXT|FILE_COMMON|FILE_ANSI);
   if(h==INVALID_HANDLE){ Print("Demo-soak JSON snapshot open failed: ",GetLastError()); return; }
   datetime start=(datetime)GVRead(DemoSoakKey("START_TIME"),TimeTradeServer());
   datetime now=TimeTradeServer();
   string json="{\n";
   json+="  \"schema_version\": \""+GPT_EA_DEMO_SOAK_RUNTIME_SCHEMA+"\",\n";
   json+="  \"evidence_id\": \""+JsonEscape(InpDemoSoakEvidenceId)+"\",\n";
   json+="  \"evidence_digest\": \"\",\n"; // finalized offline by validator/finalizer
   json+="  \"start\": \""+DemoSoakIso(start)+"\",\n";
   json+="  \"end\": \""+DemoSoakIso(now)+"\",\n";
   json+=StringFormat("  \"trading_days\": %d,\n",(int)GVRead(DemoSoakKey("MAX_CONSEC_DAYS"),0));
   json+=StringFormat("  \"london_sessions\": %d,\n",(int)GVRead(DemoSoakKey("LONDON_DAYS"),0));
   json+=StringFormat("  \"ny_sessions\": %d,\n",(int)GVRead(DemoSoakKey("NY_DAYS"),0));
   json+="  \"overlap_observed\": "+(GVRead(DemoSoakKey("OVERLAP_DAYS"),0)>0?"true":"false")+",\n";
   json+="  \"news_day_observed\": "+(GVRead(DemoSoakKey("NEWS_DAYS"),0)>0?"true":"false")+",\n";
   json+="  \"rollover_observed\": "+(GVRead(DemoSoakKey("ROLLOVER_SPREAD"),0)>0.5?"true":"false")+",\n";
   json+="  \"restart_observed\": "+(GVRead(DemoSoakKey("RESTARTS"),0)>0?"true":"false")+",\n";
   json+="  \"reconnect_observed\": "+(GVRead(DemoSoakKey("RECONNECTS"),0)>0?"true":"false")+",\n";
   json+=StringFormat("  \"scheduled_scans\": %d,\n",(int)GVRead(DemoSoakKey("SCHEDULED_SCANS"),0));
   json+=StringFormat("  \"continuous_scans\": %d,\n",(int)GVRead(DemoSoakKey("CONTINUOUS_SCANS"),0));
   json+=StringFormat("  \"checkpoint_updates\": %d,\n",(int)GVRead(DemoSoakKey("CHECKPOINT_UPDATES"),0));
   json+=StringFormat("  \"backup_checkpoint_updates\": %d,\n",(int)GVRead(DemoSoakKey("BACKUP_CHECKPOINT_UPDATES"),0));
   json+=StringFormat("  \"zero_tolerance_failures\": %d,\n",(int)GVRead(DemoSoakKey("ZERO_TOL"),0));
   json+=StringFormat("  \"unresolved_critical_states\": %d,\n",(int)GVRead(DemoSoakKey("UNRESOLVED_CURRENT"),0));
   json+=StringFormat("  \"duplicate_orders\": %d,\n",(int)GVRead(DemoSoakKey("DUP_ORDERS"),0));
   json+=StringFormat("  \"duplicate_partials\": %d,\n",(int)GVRead(DemoSoakKey("DUP_PARTIALS"),0));
   json+=StringFormat("  \"sl_regressions\": %d,\n",(int)GVRead(DemoSoakKey("SL_REGRESSIONS"),0));
   json+=StringFormat("  \"unprotected_new_authorizations\": %d,\n",(int)GVRead(DemoSoakKey("UNPROTECTED_AUTH"),0));
   json+=StringFormat("  \"release_gate_bypasses\": %d,\n",(int)GVRead(DemoSoakKey("RELEASE_BYPASS"),0));
   json+=StringFormat("  \"analytics_duplicate_finalizations\": %d,\n",(int)GVRead(DemoSoakKey("ANALYTICS_DUP_FINAL"),0));
   json+=StringFormat("  \"stop_failure_join_failures\": %d,\n",(int)GVRead(DemoSoakKey("STOP_JOIN_FAIL"),0));
   json+=StringFormat("  \"dashboard_gate_mismatches\": %d,\n",(int)GVRead(DemoSoakKey("DASH_MISMATCH"),0));
   json+=StringFormat("  \"runtime_critical_errors\": %d,\n",(int)GVRead(DemoSoakKey("RUNTIME_CRITICAL"),0));
   json+=StringFormat("  \"secrets_exposed\": %d,\n",(int)GVRead(DemoSoakKey("SECRETS"),0));
   json+="  \"execution_log_present\": "+(GVRead(DemoSoakKey("EXEC_LOG"),0)>0.5?"true":"false")+",\n";
   json+="  \"stop_log_present\": "+(GVRead(DemoSoakKey("STOP_LOG"),0)>0.5?"true":"false")+",\n";
   json+="  \"release_evidence_log_present\": "+(GVRead(DemoSoakKey("RELEASE_LOG"),0)>0.5?"true":"false")+",\n";
   json+="  \"report_path\": \""+JsonEscape(InpDemoSoakReportReference)+"\"\n";
   json+="}\n";
   FileWriteString(h,json); FileFlush(h); FileClose(h);
}

string DemoSoakEvidenceSummary()
{
   if(!InpEnableDemoSoakEvidence) return "Demo soak evidence: disabled.";
   if(!DemoSoakEligible()) return "Demo soak evidence: inactive (requires demo/contest terminal, non-tester run and evidence ID >= 8 chars).";
   return StringFormat("Demo soak %s [%s] | consecutive %d/5 | London %d/3 | NY %d/3 | overlap/news/rollover %s/%s/%s | restart/reconnect %s/%s | scheduled/continuous/manual %d/%d/%d | checkpoint/backup %d/%d | zero-tolerance %d | unresolved critical %d | logs E/S/R %s/%s/%s | machine coverage %s",
      InpDemoSoakEvidenceId,GPT_EA_DEMO_SOAK_RUNTIME_SCHEMA,(int)GVRead(DemoSoakKey("MAX_CONSEC_DAYS"),0),
      (int)GVRead(DemoSoakKey("LONDON_DAYS"),0),(int)GVRead(DemoSoakKey("NY_DAYS"),0),
      GVRead(DemoSoakKey("OVERLAP_DAYS"),0)>0?"Y":"N",GVRead(DemoSoakKey("NEWS_DAYS"),0)>0?"Y":"N",GVRead(DemoSoakKey("ROLLOVER_SPREAD"),0)>0.5?"Y":"N",
      GVRead(DemoSoakKey("RESTARTS"),0)>0?"Y":"N",GVRead(DemoSoakKey("RECONNECTS"),0)>0?"Y":"N",
      (int)GVRead(DemoSoakKey("SCHEDULED_SCANS"),0),(int)GVRead(DemoSoakKey("CONTINUOUS_SCANS"),0),(int)GVRead(DemoSoakKey("MANUAL_SCANS"),0),
      (int)GVRead(DemoSoakKey("CHECKPOINT_UPDATES"),0),(int)GVRead(DemoSoakKey("BACKUP_CHECKPOINT_UPDATES"),0),
      (int)GVRead(DemoSoakKey("ZERO_TOL"),0),(int)GVRead(DemoSoakKey("UNRESOLVED_CURRENT"),0),
      GVRead(DemoSoakKey("EXEC_LOG"),0)>0.5?"Y":"N",GVRead(DemoSoakKey("STOP_LOG"),0)>0.5?"Y":"N",GVRead(DemoSoakKey("RELEASE_LOG"),0)>0.5?"Y":"N",
      DemoSoakCoverageReady()?"READY_FOR_HUMAN_RECONCILIATION":"INCOMPLETE");
}

void DemoSoakEvidenceInit()
{
   ReconcileStaleApprovalWaitStates();
   if(!InpEnableDemoSoakEvidence) return;
   if((bool)MQLInfoInteger(MQL_TESTER)){ Print("Demo-soak evidence disabled in Strategy Tester; use a demo/contest terminal."); return; }
   if(AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_REAL){ Print("Demo-soak evidence capture refuses REAL-account mode."); return; }
   if(StringLen(InpDemoSoakEvidenceId)<8){ Print("Demo-soak evidence enabled but InpDemoSoakEvidenceId must contain at least 8 characters."); return; }

   bool existing=((int)GVRead(DemoSoakKey("RUN_HASH"),0)==TextChecksum(InpDemoSoakEvidenceId));
   datetime lastInit=(datetime)GVRead(DemoSoakKey("LAST_INIT"),0);
   EnsureDemoSoakRun(); EnsureDemoSoakEvidenceHeader();
   if(existing && lastInit>0)
   {
      GVWrite(DemoSoakKey("RESTARTS"),GVRead(DemoSoakKey("RESTARTS"),0)+1);
      WriteDemoSoakEvidenceEvent("EA_RESTART_OR_REINIT_OBSERVED","",StringFormat("previous init %s",TimeToString(lastInit,TIME_DATE|TIME_SECONDS)));
   }
   GVWrite(DemoSoakKey("LAST_INIT"),(double)TimeTradeServer());
   GVWrite(DemoSoakKey("CONNECTED_PREV"),(bool)TerminalInfoInteger(TERMINAL_CONNECTED)?1:0);
   ObserveDemoSoakRecoveryCheckpoints();
   RefreshDemoSoakLogPresence();
   WriteDemoSoakEvidenceEvent("SOAK_INIT","",DemoSoakEvidenceSummary());
   WriteDemoSoakJsonSnapshot();
   GlobalVariablesFlush();
}

void DemoSoakEvidenceTimer()
{
   // Lifecycle stale-state reconciliation is always active, even when soak capture is disabled.
   ReconcileStaleApprovalWaitStates();
   if(!EnsureDemoSoakRun()) return;
   datetime now=TimeTradeServer();
   datetime last=(datetime)GVRead(DemoSoakKey("LAST_OBSERVE"),0);
   if(last>0 && now-last<MathMax(10,InpDemoSoakObservationSeconds)) return;
   GVWrite(DemoSoakKey("LAST_OBSERVE"),(double)now);

   ObserveDemoSoakConnection();
   ObserveDemoSoakTradingDay(now);
   ObserveDemoSoakSessions(now);
   ObserveDemoSoakNews(now);
   ObserveDemoSoakRollover();
   ObserveDemoSoakRecoveryCheckpoints();
   ObserveDemoSoakCriticalStates();
   ObserveDemoSoakReleaseDashboardConsistency();
   RefreshDemoSoakLogPresence();

   datetime lastSummary=(datetime)GVRead(DemoSoakKey("LAST_SUMMARY"),0);
   if(lastSummary<=0 || now-lastSummary>=MathMax(1,InpDemoSoakSummaryMinutes)*60)
   {
      GVWrite(DemoSoakKey("LAST_SUMMARY"),(double)now);
      WriteDemoSoakEvidenceEvent("SUMMARY","",DemoSoakEvidenceSummary());
      WriteDemoSoakJsonSnapshot();
   }
   GlobalVariablesFlush();
}

void DemoSoakEvidenceShutdown()
{
   ReconcileStaleApprovalWaitStates();
   if(!DemoSoakEligible()) return;
   ObserveDemoSoakRecoveryCheckpoints();
   ObserveDemoSoakCriticalStates();
   ObserveDemoSoakReleaseDashboardConsistency();
   RefreshDemoSoakLogPresence();
   WriteDemoSoakEvidenceEvent("SOAK_SHUTDOWN","",DemoSoakEvidenceSummary());
   WriteDemoSoakJsonSnapshot();
   GlobalVariablesFlush();
}
// GPT_EA Part 35 - Adaptive stack integration wrappers
// These wrappers preserve the proven legacy paths and insert Parts 30-36 at
// selector, authorization, AI-veto, telemetry and runtime lifecycle boundaries.

TradeSetup       g_r5Primary;
TradeSetup       g_r5Pullback;
TradeSetup       g_r5BreakoutRetest;
StrategyDecision g_r5Decision;
string           g_r5SelectionNote="";
string           g_r5CalibrationNote="";
string           g_r5ExpiryNote="";
string           g_r5AIAnswer="";
bool             g_r5ContextReady=false;

bool AdaptiveOpenPositionForSymbol(const string sym)
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)==InpMagic && PositionGetString(POSITION_SYMBOL)==sym) return true;
   }
   return false;
}

void SelectDynamicStrategyR5(const string sym,TradeSetup &pb,TradeSetup &br,StrategyDecision &d)
{
   string pbCal="",brCal="";
   CalibratedConfidenceValue(pb.confidence,pbCal);
   CalibratedConfidenceValue(br.confidence,brCal);

   SelectDynamicStrategyUltimate(sym,pb,br,d);
   TradeSetup primary=d.setup;
   if(primary.symbol=="") primary=(pb.confidence>=br.confidence?pb:br);

   string cc="";
   ApplyChampionChallengerSelection(primary,pb,br,d,cc);

   string selectedCal="";
   ApplyConfidenceCalibration(primary,selectedCal);
   if(d.strategy!=STRATEGY_NO_TRADE && d.action==STRATEGY_ACTION_HIGH_CONFIDENCE && !primary.valid)
      d.action=STRATEGY_ACTION_WAIT;
   d.setup=primary;

   string expiry="";
   int learned=LearnedStrategyExpiryM15(d.strategy,MathMax(1,primary.expiryM15),expiry);
   d.setup.expiryM15=learned;
   primary.expiryM15=learned;

   g_r5Primary=primary;
   g_r5Pullback=pb;
   g_r5BreakoutRetest=br;
   g_r5Decision=d;
   g_r5SelectionNote=cc;
   g_r5CalibrationNote=pbCal+" | "+brCal+" | selected: "+selectedCal;
   g_r5ExpiryNote=expiry;
   g_r5AIAnswer="";
   g_r5ContextReady=true;

   PersistStrategyCandidate(sym,d);
}

bool AdaptivePreAuthorizationRiskAllowsR5(const TradeSetup &s,string &why)
{
   string kill="";
   if(RiskKillSwitchActive(kill)){ why=kill; return false; }
   string cd="";
   if(CooldownActive(s.symbol,cd)){ why=cd; return false; }

   StrategyClass c=CandidateStrategyForSymbol(s.symbol);
   string emergencyAI="";
   bool deterministicOnly=DeterministicEmergencyExecutionActive(s.symbol,c,emergencyAI);
   bool storedRequested=GVRead(SymKey(s.symbol,"AI_REVIEW_REQUESTED"),0)>0.5;
   bool storedAvailable=GVRead(SymKey(s.symbol,"AI_REVIEW_AVAILABLE"),0)>0.5;
   string ai="";
   if(deterministicOnly && (!storedRequested || !storedAvailable))
      ai="DETERMINISTIC_ONLY: unavailable stored GPT review bypassed; "+emergencyAI;
   else if(!StoredAIIntegrityAllows(s.symbol,ai))
   { why="GPT integrity/disagreement: "+ai; return false; }

   string learn="";
   if(!AdaptiveExecutionLearningAllows(s,learn)){ why="Execution learning: "+learn; return false; }

   double rm=0,ol=0;
   double lots=AdaptiveLotSizeForRiskFinal(s,rm,ol);
   if(lots<=0){ why="Adaptive final lot-size calculation returned zero."; return false; }

   string adaptive="";
   if(!AdaptivePreEntryAllows(s,lots,adaptive)){ why=adaptive; return false; }
   why=StringFormat("%s | %s | %s | final lots %.3f risk %.2f | %s",
                    kill,ai,learn,lots,rm,FinalAdaptiveSizingText(s));
   return true;
}

int AdaptiveExecutionSlippagePointsR5(const string sym)
{
   StrategyClass c=CandidateStrategyForSymbol(sym);
   string detail="";
   double forecast=ExecutionSlippageForecastPoints(sym,c,detail);
   int pts=(int)MathCeil(MathMax((double)DynamicSlippagePoints(sym),forecast));
   return MathMax(1,MathMin(InpMaxDynamicSlippagePoints,pts));
}

bool AIReviewAllowsExecutionR5(const string aiText,bool aiAvailable,string &why)
{
   g_r5AIAnswer=aiText;
   if(g_r5ContextReady)
   {
      string emergency="";
      if(!aiAvailable && DeterministicEmergencyExecutionActive(g_r5Primary.symbol,g_r5Decision.strategy,emergency))
      {
         string det="";
         bool detOK=DeterministicSetupIntegrity(g_r5Primary,det);
         PersistAIIntegrityDecision(g_r5Primary.symbol,detOK,true,false,false,"");
         why="DETERMINISTIC_ONLY: unavailable GPT transport bypassed by emergency policy | "+emergency+" | "+det;
         return detOK;
      }
   }

   string legacy="";
   bool legacyOK=AIReviewAllowsExecution(aiText,aiAvailable,legacy);
   if(!g_r5ContextReady)
   {
      why=legacy+" | adaptive scan context unavailable.";
      return legacyOK;
   }

   bool requested=(InpUseOpenAI && (!InpAIReviewHighConfidenceOnly || g_r5Decision.score>=InpMinStrategyScore));
   string integrity="",disagreement="";
   bool integrityOK=GPTReviewIntegrityAllows(g_r5Primary.symbol,g_r5Primary,aiText,aiAvailable,requested,integrity);
   bool disagreementOK=GPTDisagreementAllowsHighConfidence(g_r5Primary,aiText,aiAvailable,disagreement);
   PersistAIIntegrityDecision(g_r5Primary.symbol,integrityOK,disagreementOK,requested,aiAvailable,aiText);
   why=legacy+" | "+integrity+" | "+disagreement;
   return legacyOK && integrityOK && disagreementOK;
}

string AdaptiveFinalDecisionFromCard(const string card)
{
   if(StringFind(card,"FINAL DECISION: ✅ HIGH-CONFIDENCE TRADE SETUP")>=0) return "HIGH_CONFIDENCE";
   if(StringFind(card,"FINAL DECISION: ❌ NO TRADE")>=0) return "NO_TRADE";
   return "WAIT_REANALYZE";
}

void RefreshAdaptiveLifecycleFromDecision(const string decision)
{
   if(!g_r5ContextReady || g_r5Primary.symbol=="" || AdaptiveOpenPositionForSymbol(g_r5Primary.symbol)) return;
   string sym=g_r5Primary.symbol;
   int cur=(int)GVRead(SymKey(sym,"LIFECYCLE_STATE"),LIFE_NONE);
   if(cur==LIFE_REJECTED || cur==LIFE_INVALIDATED || cur==LIFE_CLOSED || cur==LIFE_NONE)
      SetSymbolLifecycle(sym,LIFE_CANDIDATE,"fresh adaptive scan candidate");

   if(decision=="HIGH_CONFIDENCE" && InpRequireApproval)
   {
      if(SetSymbolLifecycle(sym,LIFE_WAIT_CONFIRMATION,"high-confidence setup awaiting human approval"))
         GVWrite(SymKey(sym,"LIFECYCLE_WAIT_KIND"),LIFECYCLE_WAIT_HUMAN_APPROVAL);
   }
   else if(decision=="WAIT_REANALYZE")
   {
      if(SetSymbolLifecycle(sym,LIFE_WAIT_CONFIRMATION,"strategy valid but market confirmation/reanalysis still required"))
         GVWrite(SymKey(sym,"LIFECYCLE_WAIT_KIND"),LIFECYCLE_WAIT_MARKET_CONFIRMATION);
   }
   else if(decision=="NO_TRADE")
   {
      if(SetSymbolLifecycle(sym,LIFE_INVALIDATED,"fresh scan classified NO TRADE"))
         GVWrite(SymKey(sym,"LIFECYCLE_WAIT_KIND"),LIFECYCLE_WAIT_UNSPECIFIED);
   }
}

void NotifyCardR5(const string card)
{
   if(!g_r5ContextReady)
   {
      ObserveDemoSoakScanCard(card);
      NotifyCardObserved(card);
      return;
   }
   string decision=AdaptiveFinalDecisionFromCard(card);
   bool liveReady=(decision=="HIGH_CONFIDENCE");
   string enriched=card+AdaptiveCardAddendum(g_r5Primary,g_r5Decision);
   enriched+="Champion/challenger selection: "+g_r5SelectionNote+"\n";
   enriched+="Confidence calibration: "+g_r5CalibrationNote+"\n";
   enriched+="Learned candle expiry: "+g_r5ExpiryNote+"\n";
   enriched+="Final sizing: "+FinalAdaptiveSizingText(g_r5Primary)+"\n";
   if(InpEnableDemoSoakEvidence) enriched+=DemoSoakEvidenceSummary()+"\n";

   ChampionChallengerScanHook(g_r5Primary,g_r5Pullback,g_r5BreakoutRetest,g_r5Decision,liveReady,decision);
   WriteDecisionSnapshot(g_r5Primary,g_r5Decision,decision,"scanner hard filters and news/web state are retained in the emitted card","",g_r5AIAnswer,decision);
   RefreshAdaptiveLifecycleFromDecision(decision);
   ObserveDemoSoakScanCard(card);
   NotifyCardObserved(enriched);
}

void MarkSignalCooldownR5(const string sym)
{
   MarkSignalCooldown(sym);
   if(!AdaptiveOpenPositionForSymbol(sym))
   {
      SetSymbolLifecycle(sym,LIFE_INVALIDATED,"approval denied/expired; cooldown activated");
      GVWrite(SymKey(sym,"LIFECYCLE_WAIT_KIND"),LIFECYCLE_WAIT_UNSPECIFIED);
   }
}

void NewsIntermarketInitR5()
{
   NewsIntermarketInit();
   ChaosInit();
   ModelClockTrustInit();
   AdaptiveRiskSupervisorInit();
   DataIntegrityInit();
   ExecutionLearningInitR5();
   ChampionChallengerInit();
   LifecycleIntegrityInit();
   ExecutionReliabilityInit();
   CausalAttributionInit();
   DemoSoakEvidenceInit();
   StrategyHealthDashboardInit();
}

void NewsIntermarketTimerR5()
{
   NewsIntermarketTimer();
   ModelClockTrustTimer();
   AdaptiveRiskSupervisorTimer();
   DataIntegrityTimer();
   ExecutionLearningTimerR5();
   ChampionChallengerTimer();
   LifecycleIntegrityTimer();
   ExecutionReliabilityTimer();
   CausalAttributionTimer();
   DemoSoakEvidenceTimer();
   StrategyHealthDashboardTimer();
}

void DeleteAdvancedDashboardR5()
{
   ExecutionReliabilityShutdown();
   DataIntegrityShutdown();
   DemoSoakEvidenceShutdown();
   DeleteAdvancedDashboard();
   DeleteStrategyHealthDashboard();
}

// Part05 order execution consumes final adaptive sizing and learned slippage.
#define LotSizeForRisk AdaptiveLotSizeForRiskFinal
#define AdaptiveLotSizeForRisk AdaptiveLotSizeForRiskFinal
#define DynamicSlippagePoints AdaptiveExecutionSlippagePointsR5
string SetupSummaryLine(const TradeSetup &s)
{
   return StringFormat("%s: zone %.*f–%.*f | preferred %.*f | SL %.*f | TP1 %.*f | conf %d%% | eff R:R %.2f",
      s.name,DigitsFor(s.symbol),s.zoneLow,DigitsFor(s.symbol),s.zoneHigh,
      DigitsFor(s.symbol),s.preferred,DigitsFor(s.symbol),s.sl,DigitsFor(s.symbol),s.tp1,s.confidence,s.effectiveRR1);
}

string BuildCard(TradeSetup &primary,TradeSetup &pullback,TradeSetup &breakout,const string scanReason,bool newsBlock,const string news,string spreadText,bool spreadOK,bool yieldBlock,const string yieldText,bool sessionBlock,const string sessionText)
{
   string s="━━━━━━━━━━━━━━━━━━━━\n";
   string icon=(primary.bullish?"🟢":"🔴");
   s+=StringFormat("%s %s %s — PRIMARY SETUP\n",icon,primary.symbol,Arrow(primary.bullish));
   s+="━━━━━━━━━━━━━━━━━━━━\n\n";
   s+="Asset: "+primary.symbol+"\n";
   s+="TF: D1 / H4 / H1 / M30 / M15 / M5\n";
   s+="Bias: "+DirText(primary.bullish)+" — "+primary.name+"\n";
   s+="Scan: "+scanReason+"\n\n";
   s+="Analysis:\n"+primary.reason+"\n\n";
   s+="Confirmation:\n";
   s+="✅ Multi-timeframe context evaluated\n";
   s+=StringFormat("%s Setup rule satisfied\n",primary.valid?"✅":"⚠️");
   s+=StringFormat("%s %s\n",spreadOK?"✅":"❌",spreadText);
   s+=StringFormat("%s %s\n",newsBlock?"❌":"✅",news);
   s+=StringFormat("%s %s\n",yieldBlock?"❌":"✅",yieldText);
   s+=StringFormat("%s %s\n",sessionBlock?"❌":"✅",sessionText);

   int d=DigitsFor(primary.symbol);
   s+=StringFormat("\nEntry: %.*f – %.*f\nPreferred Entry: %.*f\nSL: %.*f\nTP1: %.*f\nTP2: %.*f\nTP3: %.*f\n",
      d,primary.zoneLow,d,primary.zoneHigh,d,primary.preferred,d,primary.sl,d,primary.tp1,d,primary.tp2,d,primary.tp3);
   s+=StringFormat("R:R: nominal TP1 family %.2fR; effective R:R to TP2 after spread/slippage ≈ 1:%.2f\n",primary.nominalRR1,primary.effectiveRR1);
   s+=StringFormat("Confidence: %d%%\n",primary.confidence);
   s+=StringFormat("Time invalidation: TP1 should be reached within %d M15 candles after entry (strategy/ATR/opening-range plus learned time-to-TP1 evidence).\n",primary.expiryM15);
   s+="Invalidation: "+primary.invalidation+"\n";
   s+="Failure pattern: "+primary.failurePattern+"\n\n";

   s+="Pullback vs Breakout-Retest:\n"+SetupSummaryLine(pullback)+"\n"+SetupSummaryLine(breakout)+"\n";
   s+="Pullback usually fails by acceptance through support/resistance/value; breakout-retest usually fails by a false break and close back inside the old range.\n";
   s+="Spread/slippage penalize tighter setups more; effective R:R below the configured threshold invalidates authorization.\n\n";

   s+="Position management:\n";
   s+=StringFormat("• Base risk ceiling = %.2f%% of %s; adaptive quality/strategy/broker/drawdown/regime sizing may reduce it before lot calculation.\n",InpRiskPercent,(InpUseEquity?"equity":"balance"));
   s+=StringFormat("• TP1: take %.0f%% partial; cost-aware BE protection is retried until broker-valid.\n",InpPartialAtTP1Percent);
   s+=StringFormat("• Profit lock: at %.2fR lock %.2fR; at %.2fR lock %.2fR.\n",
                   InpProfitLockTriggerR,InpProfitLockR,InpStrongLockTriggerR,InpStrongLockR);
   s+=StringFormat("• Trail: from %.2fR use ATR + M5 structure; minimum stop improvement %.2fR; stops never loosen.\n",
                   InpTrailStartR,InpTrailMinStepR);
   s+=StringFormat("• TP2: optionally close %.0f%% of the remaining volume, then manage the runner toward TP3/trailing exit.\n",InpPartialAtTP2Percent);
   s+=StringFormat("• After TP1: if price stalls near the next M15 resistance/support for %d M5 candles and momentum deteriorates, close the remainder.\n",InpPostTP1StallM5);
   s+="• News/intermarket, execution learning, correlation/macro concentration, strategy budget/health, broker health, market kill switch, release-safety, stop observability, cooldown, OrderCheck and R:R deterioration can invalidate entry before execution.\n\n";

   bool tradable=(primary.valid && !newsBlock && !yieldBlock && !sessionBlock && spreadOK && primary.effectiveRR1>=InpMinEffectiveRR);
   s+="Preferred Trade: "+(tradable?"✅ HIGH-CONFIDENCE SETUP VALID":"⏳ WAIT — CONDITIONS NOT FULLY VALID")+"\n";
   s+="Execution rule: "+primary.executionRule+"\n";
   s+="Risk note: execution costs, gaps and fast markets can make realized loss larger than modelled stop risk.\n";
   return s;
}

void NotifyCard(const string card)
{
   Print("\n",card);
   g_lastCard=card;
   Comment(card);
   if(InpEnableAlerts) Alert(StringSubstr(card,0,(int)MathMin(240,StringLen(card))));
   if(InpEnablePush && !(bool)MQLInfoInteger(MQL_TESTER)) SendNotification(StringSubstr(card,0,(int)MathMin(250,StringLen(card))));
}

// ------------------------- Optional execution ---------------------
string GVKey(ulong ticket,string suffix){ return StringFormat("CGPT_%I64u_%s",ticket,suffix); }
void GVSet(ulong ticket,string suffix,double v){ GlobalVariableSet(GVKey(ticket,suffix),v); }
double GVGet(ulong ticket,string suffix,double def=0){ string k=GVKey(ticket,suffix); return GlobalVariableCheck(k)?GlobalVariableGet(k):def; }

int CountPositions(const string sym)
{
   int n=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0) continue;
      if(PositionGetString(POSITION_SYMBOL)==sym && PositionGetInteger(POSITION_MAGIC)==InpMagic) n++;
   }
   return n;
}

bool PriceInsideZone(const TradeSetup &s)
{
   MqlTick t; if(!GetTickSafe(s.symbol,t)) return false;
   double p=(s.bullish?t.ask:t.bid);
   return (p>=s.zoneLow && p<=s.zoneHigh);
}

bool M5Trigger(const TradeSetup &s)
{
   MqlRates r[]; ArraySetAsSeries(r,true);
   if(CopyRates(s.symbol,PERIOD_M5,1,3,r)<3) return false;
   if(s.bullish)
      return (r[0].close>r[0].open && r[0].low>=r[1].low && r[0].close>r[1].close);
   return (r[0].close<r[0].open && r[0].high<=r[1].high && r[0].close<r[1].close);
}

bool ApprovedPlaceTrade(const TradeSetup &s)
{
   // Approval is authorization only. Every strategy, news, release, adaptive risk, broker and market condition is revalidated here.
   if(!InpEnableApprovedExecution || !s.valid) return false;

   string releaseWhy="";
   if(!ReleaseSafetyAllows(s.symbol,releaseWhy))
   {
      Print(s.symbol,": RELEASE SAFETY BLOCK - ",releaseWhy);
      return false;
   }

   string stopPolicyWhy="";
   if(!StopFailurePolicyConfigSafe(stopPolicyWhy))
   {
      StopFailurePauseNewEntries("invalid stop failure policy: "+stopPolicyWhy);
      Print(s.symbol,": STOP FAILURE POLICY BLOCK - ",stopPolicyWhy);
      return false;
   }

   string stopObsWhy="";
   if(!StopObservabilityAllowsNewEntries(stopObsWhy))
   {
      Print(s.symbol,": PARTIAL PROTECTION/STOP OBSERVABILITY BLOCK - ",stopObsWhy);
      return false;
   }

   TradeSetup x=s;
   x.sl=NormalizePriceToTick(x.symbol,x.sl);
   x.tp1=NormalizePriceToTick(x.symbol,x.tp1);
   x.tp2=NormalizePriceToTick(x.symbol,x.tp2);
   x.tp3=NormalizePriceToTick(x.symbol,x.tp3);

   string integrity="";
   if(!DeterministicSetupIntegrity(x,integrity))
   {
      Print(x.symbol,": SETUP INTEGRITY BLOCK - ",integrity);
      SetSymbolLifecycle(x.symbol,LIFE_INVALIDATED,integrity);
      return false;
   }

   string intelWhy="";
   if(!PreEntryIntelligenceRevalidation(x,intelWhy))
   {
      Print(x.symbol,": STRATEGY/NEWS/INTERMARKET REVALIDATION BLOCK - ",intelWhy);
      SetSymbolLifecycle(x.symbol,LIFE_INVALIDATED,intelWhy);
      return false;
   }

   string storedAI="";
   if(!StoredAIIntegrityAllows(x.symbol,storedAI))
   {
      Print(x.symbol,": GPT INTEGRITY/DISAGREEMENT BLOCK - ",storedAI);
      SetSymbolLifecycle(x.symbol,LIFE_INVALIDATED,storedAI);
      return false;
   }

   if(!PriceInsideZone(x)) return false;
   StrategyClass cls=(StrategyClass)(int)GVRead(SymKey(x.symbol,"CAND_STRATEGY"),STRATEGY_NO_TRADE);
   if(!StrategyExecutionTrigger(x,cls)) return false;
   if(CountPositions(x.symbol)>=InpMaxPositionsPerSymbol) return false;

   string kill=""; if(RiskKillSwitchActive(kill)){ Print(x.symbol,": execution blocked - ",kill); return false; }
   string cd=""; if(CooldownActive(x.symbol,cd)){ Print(x.symbol,": execution blocked - ",cd); return false; }
   string sp; if(!SpreadOK(x.symbol,sp)) return false;
   string news; if(CalendarBlock(x.symbol,news)) return false;
   string y; if(YieldShock(y)) return false;

   double liveRR=EffectiveRRDynamic(x);
   if(liveRR<InpMinEffectiveRR)
   {
      PrintFormat("%s: dynamic execution R:R %.2f below %.2f minimum.",x.symbol,liveRR,InpMinEffectiveRR);
      return false;
   }

   string learningWhy="";
   if(!AdaptiveExecutionLearningAllows(x,learningWhy))
   {
      Print(x.symbol,": EXECUTION LEARNING BLOCK - ",learningWhy);
      return false;
   }

   double riskMoney=0,oneLot=0;
   double lots=AdaptiveLotSizeForRisk(x,riskMoney,oneLot);
   if(lots<=0){ Print(x.symbol,": adaptive lot calculation returned 0."); return false; }

   string adaptiveWhy="";
   if(!AdaptivePreEntryAllows(x,lots,adaptiveWhy))
   {
      Print(x.symbol,": adaptive risk/portfolio supervisor blocked execution - ",adaptiveWhy);
      return false;
   }

   string brokerWhy="";
   if(!BrokerExecutionAllows(x,lots,brokerWhy))
   {
      Print(x.symbol,": broker execution gate blocked order - ",brokerWhy);
      return false;
   }

   string slipForecast="";
   double forecastPts=ExecutionSlippageForecastPoints(x.symbol,cls,slipForecast);
   int slipPts=(int)MathCeil(MathMax((double)DynamicSlippagePoints(x.symbol),forecastPts));
   slipPts=MathMax(1,MathMin(InpMaxDynamicSlippagePoints,slipPts));
   string serverWhy="";
   if(!ServerOrderCheckAllows(x,lots,slipPts,serverWhy))
   {
      Print(x.symbol,": OrderCheck preflight blocked order - ",serverWhy);
      return false;
   }

   string reliabilityWhy="";
   if(!ExecutionReliabilityPreEntryAllows(x,reliabilityWhy))
   {
      Print(x.symbol,": EXECUTION RELIABILITY BLOCK - ",reliabilityWhy);
      return false;
   }

   string intentNonce="",intentWhy="";
   if(!PrepareAtomicTradeIntent(x,lots,riskMoney,intentNonce,intentWhy))
   {
      Print(x.symbol,": ATOMIC INTENT BLOCK - ",intentWhy);
      return false;
   }

   PersistAdaptivePlanMetadata(x);
   PersistStrategyPlanForExecution(x);
   RegisterPlannedExecution(x,lots,riskMoney);
   SafeUniversalCheckpointNow();

   int currentLife=(int)GVRead(SymKey(x.symbol,"LIFECYCLE_STATE"),LIFE_NONE);
   if(currentLife==LIFE_NONE || currentLife==LIFE_REJECTED || currentLife==LIFE_INVALIDATED || currentLife==LIFE_CLOSED)
      SetSymbolLifecycle(x.symbol,LIFE_CANDIDATE,"final execution path candidate reconstruction");
   SetSymbolLifecycle(x.symbol,LIFE_APPROVED,"all final deterministic/adaptive/release/reliability gates passed");

   string sentWhy="";
   if(!MarkTradeIntentSent(x,intentNonce,lots,riskMoney,sentWhy))
   {
      SetSymbolLifecycle(x.symbol,LIFE_INVALIDATED,"atomic intent could not enter durable SENT state");
      return false;
   }
   if(!SetSymbolLifecycle(x.symbol,LIFE_SENT,"durable intent SENT; market order request about to be submitted"))
   {
      MarkTradeIntentFailed(x,intentNonce,lots,riskMoney,0,"lifecycle could not enter SENT before network submission");
      return false;
   }

   RegisterAdaptiveExecutionRequest(x,lots,riskMoney);
   if(ChaosInjectBeforeOrderSend())
   {
      MarkTradeIntentUncertain(x,intentNonce,lots,riskMoney,0,
         "CHAOS: simulated crash/ambiguity after durable SENT and before broker call");
      Print(x.symbol,": CHAOS ambiguous pre-send window injected; no retry is permitted until reconciliation.");
      return false;
   }

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(slipPts);
   trade.SetTypeFillingBySymbol(x.symbol);
   cls=(StrategyClass)(int)GVRead(SymKey(x.symbol,"PLAN_STRATEGY"),STRATEGY_NO_TRADE);
   string comment=(intentNonce!=""?TradeIntentComment(intentNonce,cls):"GPT-"+StrategyCode(cls)+"-OK");
   bool ok=(x.bullish?trade.Buy(lots,x.symbol,0,x.sl,x.tp3,comment):trade.Sell(lots,x.symbol,0,x.sl,x.tp3,comment));
   GVWrite(SymKey(x.symbol,"EXEC_ACK_TIME"),(double)TimeTradeServer());
   if(!ok)
   {
      RegisterAdaptiveExecutionFailure(x.symbol,trade.ResultRetcodeDescription());
      MarkTradeIntentUncertain(x,intentNonce,lots,riskMoney,trade.ResultRetcode(),
         "CTrade returned failure; broker acknowledgement is treated as ambiguous until reconciliation: "+trade.ResultRetcodeDescription());
      Print("Approved trade returned failure/ambiguity: ",trade.ResultRetcodeDescription(),
            " | exactly-once retry prohibited until broker reconciliation | ",brokerWhy," | ",serverWhy);
      return false;
   }

   if(ChaosInjectPostFillPreBind())
   {
      MarkTradeIntentUncertain(x,intentNonce,lots,riskMoney,trade.ResultRetcode(),
         "CHAOS: broker call succeeded but local fill binding intentionally skipped");
      Print(x.symbol,": CHAOS post-fill/pre-bind window injected; reconciliation must reconstruct metadata.");
      return true;
   }

   ulong newest=0; datetime newestTime=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0) continue;
      if(PositionGetString(POSITION_SYMBOL)!=x.symbol || PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      if(intentNonce!="")
      {
         string posNonce=ExtractIntentNonce(PositionGetString(POSITION_COMMENT));
         if(posNonce==intentNonce){ newest=tk; newestTime=(datetime)PositionGetInteger(POSITION_TIME); break; }
      }
      datetime pt=(datetime)PositionGetInteger(POSITION_TIME);
      if(pt>=newestTime){ newestTime=pt; newest=tk; }
   }
   if(newest>0)
   {
      GVSet(newest,"INITSL",x.sl); GVSet(newest,"TP1",x.tp1); GVSet(newest,"TP2",x.tp2);
      GVSet(newest,"TP3",x.tp3); GVSet(newest,"EXP",x.expiryM15); GVSet(newest,"TP1DONE",0);
      LegacyTicketWrite(newest,"TP1PARTIAL",0); LegacyTicketWrite(newest,"TP2PARTIAL",0);
   }
   AttachStrategyMetadataToOpenPositions();
   AttachStrategyContextMetadata();
   if(newest>0)
   {
      BindTradeIntentToPosition(newest,x,intentNonce,lots,riskMoney);
      RegisterAdaptiveExecutionFill(newest,x,lots,riskMoney);
      AttachLifecycleToNewestPosition(newest,"broker market order fill confirmed and bound to exactly-once intent");
   }
   else
   {
      MarkTradeIntentUncertain(x,intentNonce,lots,riskMoney,trade.ResultRetcode(),
         "broker call reported success but matching open position was not immediately discoverable");
   }
   SafeUniversalCheckpointNow();
   PrintFormat("%s APPROVED: %s %s opened %.2f lots; adaptive risk %.2f; execution slippage ceiling %d pts; live R:R %.2f | intelligence PASS | adaptive supervisor PASS | release PASS | %s | %s | %s",
               x.symbol,StrategyClassName(cls),Arrow(x.bullish),lots,riskMoney,slipPts,liveRR,
               adaptiveWhy,learningWhy,slipForecast+" | "+reliabilityWhy+" | "+intentWhy);
   return true;
}
#undef DynamicSlippagePoints
#undef AdaptiveLotSizeForRisk
#undef LotSizeForRisk

// GPT_EA Part 23 - Full intelligence decision observability

input bool   InpWriteIntelligenceJournal = true;
input string InpIntelligenceJournalFile  = "GPT_EA_Intelligence.csv";
input int    InpIntelligenceCardMaxChars = 30000;

string CardLineValue(const string card,const string prefix)
{
   int p=StringFind(card,prefix); if(p<0) return "";
   p+=StringLen(prefix);
   int e=StringFind(card,"\n",p); if(e<0) e=StringLen(card);
   string out=StringSubstr(card,p,e-p);
   StringTrimLeft(out); StringTrimRight(out);
   return out;
}

void PersistLastIntelligenceDecision(const string card)
{
   string asset=CardLineValue(card,"Asset:");
   if(asset=="") return;
   GVWrite(SymKey(asset,"INTEL_LAST_TIME"),(double)TimeTradeServer());
   string finalDecision=CardLineValue(card,"FINAL DECISION:");
   int code=(StringFind(finalDecision,"HIGH-CONFIDENCE")>=0?2:(StringFind(finalDecision,"WAIT")>=0?1:0));
   GVWrite(SymKey(asset,"INTEL_LAST_DECISION"),code);
}

void WriteIntelligenceDecisionJournal(const string card)
{
   if(!InpWriteIntelligenceJournal || (bool)MQLInfoInteger(MQL_TESTER)) return;
   int h=FileOpen(InpIntelligenceJournalFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI,',');
   if(h==INVALID_HANDLE)
   {
      Print("Intelligence journal open failed: ",GetLastError());
      return;
   }
   if(FileSize(h)==0)
      FileWrite(h,"server_time","asset","classification","market_state","strategy_decision","final_decision","full_card");
   FileSeek(h,0,SEEK_END);
   int maxChars=(int)MathMax(1000,InpIntelligenceCardMaxChars);
   string payload=StringSubstr(card,0,maxChars);
   FileWrite(h,
      TimeToString(TimeTradeServer(),TIME_DATE|TIME_SECONDS),
      CardLineValue(card,"Asset:"),
      CardLineValue(card,"Classification:"),
      CardLineValue(card,"Market state:"),
      CardLineValue(card,"Decision:"),
      CardLineValue(card,"FINAL DECISION:"),
      payload);
   FileFlush(h); FileClose(h);
}

void NotifyCardObserved(const string card)
{
   PersistLastIntelligenceDecision(card);
   WriteIntelligenceDecisionJournal(card);
   NotifyCard(card);
}
bool ReducePosition(ulong ticket,double closeVolume)
{
   if(!PositionSelectByTicket(ticket)) return false;
   string sym=PositionGetString(POSITION_SYMBOL);
   long type=PositionGetInteger(POSITION_TYPE);
   double vol=PositionGetDouble(POSITION_VOLUME);
   closeVolume=NormalizeVolumeDown(sym,MathMin(closeVolume,vol));
   if(closeVolume<=0 || closeVolume>=vol) return trade.PositionClose(ticket,InpMaxSlippagePoints);

   long marginMode=AccountInfoInteger(ACCOUNT_MARGIN_MODE);
   if(marginMode==ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
      return trade.PositionClosePartial(ticket,closeVolume,InpMaxSlippagePoints);

   // Netting/exchange: reduce by opposite market deal.
   trade.SetExpertMagicNumber(InpMagic); trade.SetDeviationInPoints(InpMaxSlippagePoints); trade.SetTypeFillingBySymbol(sym);
   if(type==POSITION_TYPE_BUY) return trade.Sell(closeVolume,sym,0,0,0,"CGPT-partial");
   return trade.Buy(closeVolume,sym,0,0,0,"CGPT-partial");
}

int BarsSince(const string sym,ENUM_TIMEFRAMES tf,datetime from)
{
   int n=Bars(sym,tf,from,TimeTradeServer());
   return MathMax(0,n-1);
}

bool MomentumStillAligned(const string sym,bool bull)
{
   double e20h1,e50h1,r15;
   if(!EMAValue(sym,PERIOD_H1,InpFastEMA,1,e20h1) || !EMAValue(sym,PERIOD_H1,InpSlowEMA,1,e50h1) || !RSIValue(sym,PERIOD_M15,InpRSIPeriod,1,r15)) return false;
   return bull ? (e20h1>e50h1 && r15>=50.0) : (e20h1<e50h1 && r15<=50.0);
}

bool NearNextBarrier(const string sym,bool bull,double &barrier)
{
   double hi,lo,atr;
   if(!RecentHighLow(sym,PERIOD_M15,1,InpSwingBars,hi,lo) || !ATRValue(sym,PERIOD_M15,InpATRPeriod,1,atr)) return false;
   barrier=(bull?hi:lo);
   MqlTick t; if(!GetTickSafe(sym,t)) return false;
   double p=(bull?t.bid:t.ask);
   return MathAbs(p-barrier)<=0.25*atr;
}

bool M5ReversalAgainst(const string sym,bool bull)
{
   double rsi,e20,c;
   if(!RSIValue(sym,PERIOD_M5,InpRSIPeriod,1,rsi) || !EMAValue(sym,PERIOD_M5,InpFastEMA,1,e20) || !CloseValue(sym,PERIOD_M5,1,c)) return false;
   return bull ? (rsi<48.0 && c<e20) : (rsi>52.0 && c>e20);
}

void ManagePositions()
{
   trade.SetExpertMagicNumber(InpMagic); trade.SetDeviationInPoints(InpMaxSlippagePoints);
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i); if(ticket==0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      string sym=PositionGetString(POSITION_SYMBOL);
      long type=PositionGetInteger(POSITION_TYPE);
      bool bull=(type==POSITION_TYPE_BUY);
      double entry=PositionGetDouble(POSITION_PRICE_OPEN);
      double sl=PositionGetDouble(POSITION_SL);
      double vol=PositionGetDouble(POSITION_VOLUME);
      datetime opened=(datetime)PositionGetInteger(POSITION_TIME);
      MqlTick t; if(!GetTickSafe(sym,t)) continue;
      double px=(bull?t.bid:t.ask);

      double initSL=GVGet(ticket,"INITSL",sl);
      double tp1=GVGet(ticket,"TP1",0);
      double tp2=GVGet(ticket,"TP2",0);
      int expiry=(int)GVGet(ticket,"EXP",InpPullbackExpiryM15);
      bool tp1done=(GVGet(ticket,"TP1DONE",0)>0.5);
      if(tp1<=0)
      {
         double R=MathAbs(entry-initSL); tp1=(bull?entry+R:entry-R); tp2=(bull?entry+2*R:entry-2*R);
         GVSet(ticket,"TP1",tp1); GVSet(ticket,"TP2",tp2); GVSet(ticket,"EXP",expiry);
      }

      bool reached=(bull?px>=tp1:px<=tp1);
      if(reached && !tp1done)
      {
         double closeVol=vol*InpPartialAtTP1Percent/100.0;
         if(InpPartialAtTP1Percent>0 && InpPartialAtTP1Percent<100) ReducePosition(ticket,closeVol);
         if(PositionSelectByTicket(ticket) && InpMoveSLToBEAfterTP1)
         {
            double atr=0; ATRValue(sym,PERIOD_M5,InpATRPeriod,1,atr);
            double be=(bull?entry+InpBECostATRFrac*atr:entry-InpBECostATRFrac*atr);
            double currentTP=PositionGetDouble(POSITION_TP);
            ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
            double expectedSL=NormPrice(sym,be);
            GVWrite(PosKey(pid,"EA_EXPECT_SL"),expectedSL);
            GVWrite(PosKey(pid,"EA_EXPECT_TP"),currentTP);
            GVWrite(PosKey(pid,"EA_EXPECT_MOD_UNTIL"),(double)(TimeTradeServer()+10));
            if(!trade.PositionModify(ticket,expectedSL,currentTP))
               GVWrite(PosKey(pid,"EA_EXPECT_MOD_UNTIL"),0);
         }
         GVSet(ticket,"TP1DONE",1);
         tp1done=true;
      }

      // Time-based invalidation: before TP1, no result after adaptive candle budget => exit.
      if(!tp1done && BarsSince(sym,PERIOD_M15,opened)>=expiry)
      {
         Print(sym,": time invalidation — TP1 not reached within ",expiry," M15 candles.");
         trade.PositionClose(ticket,InpMaxSlippagePoints);
         continue;
      }

      // After TP1, stale near next barrier + momentum failure => close remainder.
      if(tp1done)
      {
         double barrier=0;
         bool near=NearNextBarrier(sym,bull,barrier);
         bool stalled=(BarsSince(sym,PERIOD_M5,opened)>=InpPostTP1StallM5);
         if(near && stalled && (!MomentumStillAligned(sym,bull) || M5ReversalAgainst(sym,bull)))
         {
            PrintFormat("%s: closing remainder after TP1; stall near %.5f with momentum deterioration.",sym,barrier);
            trade.PositionClose(ticket,InpMaxSlippagePoints);
            continue;
         }
      }
   }
}

// ---------------------- Approval workflow -------------------------
void DeleteApprovalObjects()
{
   ObjectDelete(0,BTN_APPROVE);
   ObjectDelete(0,BTN_DENY);
   ObjectDelete(0,LBL_PROMPT);
   ObjectDelete(0,APP_PANEL); ObjectDelete(0,APP_ACCENT); ObjectDelete(0,APP_TITLE);
   ObjectDelete(0,APP_STATUS); ObjectDelete(0,APP_META); ObjectDelete(0,APP_LADDER);
   ObjectDelete(0,APP_TIMER); ObjectDelete(0,APP_PROGRESS_BG); ObjectDelete(0,APP_PROGRESS_FG);
   ObjectDelete(0,APP_HINT);
   g_approvalHoverApprove=false;
   g_approvalHoverDeny=false;
   ChartRedraw();
}

int FirstActivePending()
{
   for(int i=0;i<ArraySize(g_pending);i++) if(g_pending[i].active) return i;
   return -1;
}

int ActivePendingForSymbol(const string sym)
{
   for(int i=0;i<ArraySize(g_pending);i++)
      if(g_pending[i].active && g_pending[i].setup.symbol==sym) return i;
   return -1;
}

void RenderApprovalPrompt()
{
   int idx=FirstActivePending();
   g_displayPending=idx;

   bool feedback=ApprovalFeedbackActive();
   if(idx<0 && !feedback)
   {
      if(g_approvalFeedbackText!="" && TimeTradeServer()>g_approvalFeedbackUntil)
      {
         g_approvalFeedbackText="";
         g_approvalFeedbackKind=0;
      }
      DeleteApprovalObjects();
      return;
   }

   int x=InpApprovalHeroX;
   int y=InpApprovalHeroY;
   int w=(int)MathMax(420,InpApprovalHeroWidth);
   int h=(int)MathMax(226,InpApprovalHeroHeight);
   color accent=C'67,157,232';
   color statusColor=C'241,194,88';
   string title="TRADE APPROVAL  •  GPT EA";
   string status="";
   string meta="";
   string ladder="";
   string timerText="";
   string hint="";
   double progress=1.0;

   if(idx>=0)
   {
      TradeSetup s=g_pending[idx].setup;
      datetime now=TimeTradeServer();
      int remain=(int)MathMax(0,(long)(g_pending[idx].expiresAt-now));
      int total=(int)MathMax(1,(long)(g_pending[idx].expiresAt-g_pending[idx].createdAt));
      progress=MathMax(0.0,MathMin(1.0,(double)remain/(double)total));
      bool danger=(remain<=MathMax(5,InpApprovalDangerSeconds));
      accent=danger?PremiumPulseColor(C'206,71,77',C'255,116,123'):PremiumPulseColor(C'58,142,217',C'94,188,255');
      statusColor=danger?C'255,122,128':C'247,203,99';

      string kind=(s.kind==SETUP_PULLBACK?"PULLBACK":(s.kind==SETUP_BREAKOUT?"BREAKOUT":"BREAKOUT-RETEST"));
      int d=DigitsFor(s.symbol);
      double R=MathAbs(s.preferred-s.sl);
      double beBuffer=MathMax(InpBELockMinR*R,PointFor(s.symbol)*2.0);
      double be=NormalizePriceToTick(s.symbol,s.bullish?s.preferred+beBuffer:s.preferred-beBuffer);
      StrategyClass cls=(StrategyClass)(int)GVRead(SymKey(s.symbol,"CAND_STRATEGY"),STRATEGY_NO_TRADE);

      status=danger?"● EXPIRING — DECISION REQUIRED":"● WAITING FOR YOUR DECISION";
      meta=StringFormat("%s  •  %s  •  %s  •  %s  •  confidence %d%%  •  eff R:R %.2f",
                        s.symbol,s.bullish?"LONG":"SHORT",StrategyClassName(cls),kind,s.confidence,s.effectiveRR1);
      ladder=StringFormat(
         "ENTRY  %.*f   │   SL  %.*f   │   B.E.  %.*f\n"
         "TP1  %.*f   │   TP2  %.*f   │   TP3  %.*f   │   TRAIL %.2fR",
         d,s.preferred,d,s.sl,d,be,d,s.tp1,d,s.tp2,d,s.tp3,InpTrailStartR);
      timerText=StringFormat("◉  %02d s LEFT   •   NO RESPONSE = AUTO-DENY / EXPIRED",remain);
      hint="Fresh validation still runs after APPROVE  •  OpenAI "+APITransportVisualState()+"  •  release/risk/broker gates remain fail-closed";
   }
   else
   {
      if(g_approvalFeedbackKind==1){ accent=C'34,180,122'; statusColor=C'99,232,171'; }
      else if(g_approvalFeedbackKind==2 || g_approvalFeedbackKind==3){ accent=C'201,64,75'; statusColor=C'255,123,132'; }
      else { accent=C'224,168,73'; statusColor=C'247,204,104'; }
      status="● "+g_approvalFeedbackText;
      meta="Decision recorded safely. No visual action can bypass execution, risk, release, recovery, news or broker validation.";
      ladder="ENTRY / SL / B.E. / TP / TRAIL state remains controlled by the authoritative trade-management engine.";
      timerText="STATUS CONFIRMED";
      hint="GPT EA  •  approval-only execution  •  fail-closed safety preserved";
      progress=1.0;
   }

   SetPremiumRect(APP_PANEL,CORNER_LEFT_UPPER,x,y,w,h,C'8,14,23',accent,10);
   SetPremiumRect(APP_ACCENT,CORNER_LEFT_UPPER,x,y,5,h,accent,11);
   SetPremiumLabel(APP_TITLE,CORNER_LEFT_UPPER,x+20,y+14,title,C'232,201,115',14,InpDashboardTitleFont,12);
   SetPremiumLabel(APP_STATUS,CORNER_LEFT_UPPER,x+20,y+45,status,statusColor,10,"Segoe UI Semibold",13);
   SetPremiumLabel(APP_META,CORNER_LEFT_UPPER,x+20,y+70,meta,C'190,207,226',8,"Segoe UI",13);
   SetPremiumLabel(APP_LADDER,CORNER_LEFT_UPPER,x+20,y+95,ladder,clrWhiteSmoke,9,"Segoe UI Semibold",13);
   SetPremiumLabel(APP_TIMER,CORNER_LEFT_UPPER,x+20,y+137,timerText,statusColor,9,"Segoe UI Semibold",13);

   int barW=w-44;
   SetPremiumRect(APP_PROGRESS_BG,CORNER_LEFT_UPPER,x+22,y+158,barW,7,C'31,40,54',C'31,40,54',12);
   int fill=(int)MathMax(3,MathRound((double)barW*progress));
   SetPremiumRect(APP_PROGRESS_FG,CORNER_LEFT_UPPER,x+22,y+158,fill,7,accent,accent,13);

   if(idx>=0)
   {
      if(ObjectFind(0,BTN_APPROVE)<0) ObjectCreate(0,BTN_APPROVE,OBJ_BUTTON,0,0,0);
      if(ObjectFind(0,BTN_DENY)<0) ObjectCreate(0,BTN_DENY,OBJ_BUTTON,0,0,0);
      ObjectSetInteger(0,BTN_APPROVE,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,BTN_DENY,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,BTN_APPROVE,OBJPROP_HIDDEN,true);
      ObjectSetInteger(0,BTN_DENY,OBJPROP_HIDDEN,true);
      StyleApprovalUI();
   }
   else
   {
      ObjectDelete(0,BTN_APPROVE);
      ObjectDelete(0,BTN_DENY);
   }

   SetPremiumLabel(APP_HINT,CORNER_LEFT_UPPER,x+20,y+h-23,hint,C'137,158,184',7,"Segoe UI",13);
   ChartRedraw();
}

void AnimateApprovalHero(const bool force=false)
{
   bool hasPending=(FirstActivePending()>=0);
   bool hasFeedback=(g_approvalFeedbackText!="");
   if(!hasPending && !hasFeedback) return;

   ulong now=GetTickCount64();
   int interval=(int)MathMax(100,InpApprovalAnimationMs);
   if(!force && g_lastApprovalVisualMS>0 && now-g_lastApprovalVisualMS<(ulong)interval) return;
   g_lastApprovalVisualMS=now;

   if(hasFeedback && !ApprovalFeedbackActive() && !hasPending)
   {
      g_approvalFeedbackText="";
      g_approvalFeedbackKind=0;
   }
   RenderApprovalPrompt();
   StyleApprovalUI();
}
// GPT_EA Part 13 - Advanced position manager

bool RestoreMissingProtectiveStop(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return false;
   if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) return false;
   double currentSL=PositionGetDouble(POSITION_SL);
   if(currentSL>0) return true;

   ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
   string sym=PositionGetString(POSITION_SYMBOL);
   bool bull=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
   double initSL=GVRead(PosKey(pid,"INITSL"),LegacyTicketRead(ticket,"INITSL",0));
   if(initSL<=0) initSL=HistoricalInitialSL(pid);
   if(initSL<=0)
   {
      Print(sym,": CRITICAL - open GPT_EA position has no SL and no recoverable original SL.");
      return false;
   }

   string why="";
   double restoredSL=NormalizePriceToTick(sym,initSL);
   if(!StopBrokerSafe(sym,bull,restoredSL,why))
   {
      Print(sym,": cannot restore missing protective SL yet - ",why);
      return false;
   }
   double tp=PositionGetDouble(POSITION_TP);
   if(ChaosInjectStopModifyFailure())
   {
      GVWrite(PosKey(pid,"CHAOS_SAMPLE"),1);
      Print(sym,": CHAOS synthetic protective-stop restoration failure.");
      return false;
   }
   GVWrite(PosKey(pid,"EA_EXPECT_SL"),restoredSL);
   GVWrite(PosKey(pid,"EA_EXPECT_TP"),tp);
   GVWrite(PosKey(pid,"EA_EXPECT_MOD_UNTIL"),(double)(TimeTradeServer()+10));
   if(!trade.PositionModify(ticket,restoredSL,tp))
   {
      GVWrite(PosKey(pid,"EA_EXPECT_MOD_UNTIL"),0);
      Print(sym,": failed to restore missing protective SL - ",trade.ResultRetcodeDescription());
      return false;
   }
   Print(sym,": CRITICAL recovery action - protective SL restored from durable state/history.");
   ClearStopFailureState(ticket,"missing protective SL restored");
   SafeUniversalCheckpointNow();
   return true;
}

ulong RefreshTicketFromPositionId(ulong pid,ulong fallback)
{
   ulong current=FindOpenTicketByIdentifier(pid);
   return current>0?current:fallback;
}

bool PositionFlag(ulong pid,ulong ticket,const string field)
{
   return (GVRead(PosKey(pid,field),LegacyTicketRead(ticket,field,0))>0.5);
}

void WritePositionFlag(ulong pid,ulong ticket,const string field,double value)
{
   GVWrite(PosKey(pid,field),value);
   LegacyTicketWrite(ticket,field,value);
}

void EnsurePartialProtectionStartObserved(ulong ticket,const string reason)
{
   if(!PositionSelectByTicket(ticket)) return;
   ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
   if(GVRead(PosKey(pid,"PARTIAL_PROTECT_STARTED_LOGGED"),0)>0.5) return;
   GVWrite(PosKey(pid,"PARTIAL_PROTECT_STARTED_LOGGED"),1);
   RecordPartialProtectionObservation(ticket,"PARTIAL_PROTECTION_STARTED",reason);
}

void CompletePartialProtectionObservation(ulong ticket,const string reason)
{
   if(!PositionSelectByTicket(ticket)) return;
   ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
   if(GVRead(PosKey(pid,"PARTIAL_PROTECT_STARTED_LOGGED"),0)<=0.5) return;
   RecordPartialProtectionObservation(ticket,"PARTIAL_PROTECTION_COMPLETED",reason);
   GVWrite(PosKey(pid,"PARTIAL_PROTECT_STARTED_LOGGED"),0);
}

bool HandleTP1State(ulong &ticket,double px,double tp1,bool bull)
{
   if(!PositionSelectByTicket(ticket)) return false;
   ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
   string sym=PositionGetString(POSITION_SYMBOL);
   bool reached=(bull?px>=tp1:px<=tp1);
   if(!reached) return PositionFlag(pid,ticket,"TP1DONE");

   bool partialDone=PositionFlag(pid,ticket,"TP1PARTIAL");
   if(!partialDone)
   {
      bool partialOK=true;
      double vol=PositionGetDouble(POSITION_VOLUME);
      if(InpPartialAtTP1Percent>0 && InpPartialAtTP1Percent<100.0)
      {
         double closeVol=vol*InpPartialAtTP1Percent/100.0;
         partialOK=ReducePosition(ticket,closeVol);
      }
      else if(InpPartialAtTP1Percent>=100.0)
      {
         partialOK=trade.PositionClose(ticket,InpMaxSlippagePoints);
         if(partialOK) return true;
      }
      if(!partialOK)
      {
         Print(sym,": TP1 reached but partial close failed; state remains retryable - ",trade.ResultRetcodeDescription());
         return false;
      }
      ticket=RefreshTicketFromPositionId(pid,ticket);
      if(!PositionSelectByTicket(ticket)) return true;
      WritePositionFlag(pid,ticket,"TP1PARTIAL",1);
      double now=(double)TimeTradeServer();
      GVWrite(PosKey(pid,"TP1_TIME"),now);
      LegacyTicketWrite(ticket,"TP1_TIME",now);
      if(InpMoveSLToBEAfterTP1 && !PositionProtectedAtOrBeyondBE(ticket))
         EnsurePartialProtectionStartObserved(ticket,"TP1 scale-out completed; required breakeven protection is pending.");
      SafeUniversalCheckpointNow();
   }

   double rNow=0,R=0,entry=0,livePx=0; bool liveBull=true;
   if(!CurrentPositionR(ticket,rNow,R,entry,livePx,liveBull)) return false;
   bool protectionReady=!InpMoveSLToBEAfterTP1;
   if(InpMoveSLToBEAfterTP1)
   {
      if(PositionProtectedAtOrBeyondBE(ticket))
      {
         protectionReady=true;
         ClearStopFailureState(ticket,"TP1 breakeven protection already satisfied");
      }
      else
      {
         EnsurePartialProtectionStartObserved(ticket,"TP1 partial remains complete while breakeven protection is pending.");
         if(StopUpdateRetryDue(pid))
         {
            EnsureBreakEvenProtection(ticket,rNow,R,entry,liveBull);
            protectionReady=PositionProtectedAtOrBeyondBE(ticket);
            AuditStopUpdateAttempt(ticket,rNow,"TP1 breakeven");
         }
      }
   }

   if(protectionReady)
   {
      WritePositionFlag(pid,ticket,"TP1DONE",1);
      if(GVRead(PosKey(pid,"TP1_TIME"),LegacyTicketRead(ticket,"TP1_TIME",0))<=0)
      {
         double now=(double)TimeTradeServer();
         GVWrite(PosKey(pid,"TP1_TIME"),now);
         LegacyTicketWrite(ticket,"TP1_TIME",now);
      }
      CompletePartialProtectionObservation(ticket,"TP1 partial and required breakeven protection are complete.");
      SafeUniversalCheckpointNow();
      return true;
   }

   Print(sym,": TP1 partial completed, but BE protection is not yet broker-valid; retry policy remains active.");
   return false;
}

bool HandleTP2Partial(ulong &ticket,double px,double tp2,bool bull,double rNow)
{
   if(!PositionSelectByTicket(ticket)) return false;
   ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
   if(PositionFlag(pid,ticket,"TP2PARTIAL")) return true;
   bool reached=(bull?px>=tp2:px<=tp2) || rNow>=2.0;
   if(!reached) return false;

   string sym=PositionGetString(POSITION_SYMBOL);
   double vol=PositionGetDouble(POSITION_VOLUME);
   bool ok=true;
   if(InpPartialAtTP2Percent>0 && InpPartialAtTP2Percent<100.0)
      ok=ReducePosition(ticket,vol*InpPartialAtTP2Percent/100.0);
   else if(InpPartialAtTP2Percent>=100.0)
      ok=trade.PositionClose(ticket,InpMaxSlippagePoints);

   if(!ok)
   {
      Print(sym,": TP2 partial failed; state remains retryable - ",trade.ResultRetcodeDescription());
      return false;
   }

   ticket=RefreshTicketFromPositionId(pid,ticket);
   if(PositionSelectByTicket(ticket))
   {
      WritePositionFlag(pid,ticket,"TP2PARTIAL",1);
      double now=(double)TimeTradeServer();
      GVWrite(PosKey(pid,"TP2_TIME"),now);
      LegacyTicketWrite(ticket,"TP2_TIME",now);
      SafeUniversalCheckpointNow();
   }
   return true;
}

void ManagePositionsAdvanced()
{
   RefreshStopFailurePolicyConfigGate();
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpMaxSlippagePoints);

   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;

      string sym=PositionGetString(POSITION_SYMBOL);
      ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
      bool bull=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
      double entry=PositionGetDouble(POSITION_PRICE_OPEN);
      datetime opened=(datetime)PositionGetInteger(POSITION_TIME);

      // Existing positions remain managed even when release gates block new entries.
      if(!RestoreMissingProtectiveStop(ticket))
      {
         HandleUnprotectedStopFailure(ticket,"protective SL missing and restoration did not succeed");
         continue;
      }
      if(!PositionSelectByTicket(ticket)) continue;

      double initSL=GVRead(PosKey(pid,"INITSL"),LegacyTicketRead(ticket,"INITSL",PositionGetDouble(POSITION_SL)));
      if(initSL<=0) initSL=HistoricalInitialSL(pid);
      double R=MathAbs(entry-initSL);
      if(R<=0) continue;

      double tp1=LegacyTicketRead(ticket,"TP1",bull?entry+R:entry-R);
      double tp2=LegacyTicketRead(ticket,"TP2",bull?entry+2*R:entry-2*R);
      double tp3=LegacyTicketRead(ticket,"TP3",bull?entry+3*R:entry-3*R);
      int expiry=(int)LegacyTicketRead(ticket,"EXP",InpPullbackExpiryM15);
      LegacyTicketWrite(ticket,"TP1",tp1);
      LegacyTicketWrite(ticket,"TP2",tp2);
      LegacyTicketWrite(ticket,"TP3",tp3);
      LegacyTicketWrite(ticket,"EXP",expiry);

      MqlTick tick; if(!GetTickSafe(sym,tick)) continue;
      double px=(bull?tick.bid:tick.ask);

      bool tp1done=HandleTP1State(ticket,px,tp1,bull);
      ticket=RefreshTicketFromPositionId(pid,ticket);
      if(!PositionSelectByTicket(ticket)) continue;

      if(!tp1done && BarsSince(sym,PERIOD_M15,opened)>=expiry)
      {
         Print(sym,": time invalidation — TP1 not reached within ",expiry," M15 candles.");
         trade.PositionClose(ticket,InpMaxSlippagePoints);
         continue;
      }

      double rNow=0,liveR=0,liveEntry=0,livePx=0; bool liveBull=true;
      if(!CurrentPositionR(ticket,rNow,liveR,liveEntry,livePx,liveBull)) continue;

      if(tp1done)
      {
         if(StopUpdateRetryDue(pid))
         {
            AdvanceProfitProtection(ticket,rNow,liveR,liveEntry,livePx,liveBull);
            AuditStopUpdateAttempt(ticket,rNow,"post-TP1 profit protection");
         }
         ticket=RefreshTicketFromPositionId(pid,ticket);
         if(!PositionSelectByTicket(ticket)) continue;

         HandleTP2Partial(ticket,livePx,tp2,liveBull,rNow);
         ticket=RefreshTicketFromPositionId(pid,ticket);
         if(!PositionSelectByTicket(ticket)) continue;

         datetime tp1Time=(datetime)GVRead(PosKey(pid,"TP1_TIME"),LegacyTicketRead(ticket,"TP1_TIME",0));
         if(tp1Time<=0) tp1Time=TimeTradeServer();
         double barrier=0;
         bool near=NearNextBarrier(sym,liveBull,barrier);
         bool stalled=(BarsSince(sym,PERIOD_M5,tp1Time)>=InpPostTP1StallM5);
         if(near && stalled && (!MomentumStillAligned(sym,liveBull) || M5ReversalAgainst(sym,liveBull)))
         {
            PrintFormat("%s: closing managed remainder; post-TP1 stall near %.5f with momentum deterioration.",sym,barrier);
            trade.PositionClose(ticket,InpMaxSlippagePoints);
            continue;
         }
      }
   }
}

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
// GPT_EA Part 07 - Approval workflow, full intelligence scanner and MT5 hooks

void DeletePending(const int idx,const string reason)
{
   if(idx<0 || idx>=ArraySize(g_pending) || !g_pending[idx].active) return;
   string sym=g_pending[idx].setup.symbol;

   if(StringFind(reason,"timeout")>=0)
      SetApprovalFeedback("EXPIRED  •  "+sym+"  •  NO ORDER OPENED",3);
   else if(StringFind(reason,"denied")>=0)
      SetApprovalFeedback("DENIED  •  "+sym+"  •  NO ORDER OPENED",2);
   else
      SetApprovalFeedback("BLOCKED  •  "+sym+"  •  SETUP INVALIDATED",4);

   g_pending[idx].active=false;
   if(StringFind(reason,"denied")>=0 || StringFind(reason,"timeout")>=0)
      MarkSignalCooldown(sym);
   PersistPendingApprovals();
   SafeUniversalCheckpointNow();
   PrintFormat("%s pending setup deleted: %s",sym,reason);
   if(InpEnablePush && !(bool)MQLInfoInteger(MQL_TESTER))
      SendNotification(StringFormat("%s pending setup deleted: %s",sym,reason));
   RenderApprovalPrompt();
   StyleApprovalUI();
}

void QueueForApproval(const TradeSetup &s,const string card,const string scanReason)
{
   if(!s.valid) return;
   string releaseWhy="";
   if(!ReleaseSafetyAllows(s.symbol,releaseWhy))
   {
      Print(s.symbol,": approval prompt suppressed by release gate - ",releaseWhy);
      return;
   }
   string stopWhy="";
   if(!StopObservabilityAllowsNewEntries(stopWhy))
   {
      Print(s.symbol,": approval prompt suppressed by partial-protection/stop gate - ",stopWhy);
      return;
   }

   datetime now=TimeTradeServer();
   int timeout=MathMax(10,InpApprovalTimeoutSeconds);
   int idx=ActivePendingForSymbol(s.symbol);
   if(idx<0)
   {
      idx=ArraySize(g_pending);
      ArrayResize(g_pending,idx+1);
   }
   g_pending[idx].active=true;
   g_pending[idx].setup=s;
   g_pending[idx].card=card;
   g_pending[idx].scanReason=scanReason;
   g_pending[idx].createdAt=now;
   g_pending[idx].expiresAt=now+timeout;
   PersistPendingApprovals();
   SafeUniversalCheckpointNow();
   RenderApprovalPrompt();
   StyleApprovalUI();

   StrategyClass cls=(StrategyClass)(int)GVRead(SymKey(s.symbol,"CAND_STRATEGY"),STRATEGY_NO_TRADE);
   string msg=StringFormat("GPT_EA approval required: %s %s %s. APPROVE or DENY within %d seconds.",s.symbol,StrategyClassName(cls),Arrow(s.bullish),timeout);
   Print(msg);
   if(InpApprovalAlert && InpEnableAlerts) Alert(msg);
   if(InpEnablePush && !(bool)MQLInfoInteger(MQL_TESTER)) SendNotification(msg);
}

void ProcessApprovalTimeouts()
{
   datetime now=TimeTradeServer();
   for(int i=0;i<ArraySize(g_pending);i++)
      if(g_pending[i].active && now>=g_pending[i].expiresAt)
         DeletePending(i,"approval timeout - no user response");
   RenderApprovalPrompt();
   StyleApprovalUI();
}

bool StrategyAwareConfluenceGate(TradeSetup &s,ConfluenceReport &r,StrategyClass cls,string &why)
{
   why="";
   bool nonTrend=(cls==STRATEGY_COUNTER_TREND_SCALP || cls==STRATEGY_COUNTER_TREND_SWING || cls==STRATEGY_POTENTIAL_REVERSAL ||
                  cls==STRATEGY_RANGE_TRADE || cls==STRATEGY_MEAN_REVERSION);
   if(!nonTrend)
   {
      ApplyAdvancedConfluence(s,r);
      if(InpUseAdvancedConfluence && !r.valid){ why=StringFormat("standard confluence invalid at %d/100",r.score); return false; }
   }
   else
   {
      // Counter-trend/range strategies are intentionally allowed to disagree with HTF direction,
      // but must still pass spread/proximity/strategy-specific confirmation and a demanding score.
      int required=(cls==STRATEGY_COUNTER_TREND_SCALP || cls==STRATEGY_COUNTER_TREND_SWING || cls==STRATEGY_POTENTIAL_REVERSAL)?InpMinCounterTrendScore:InpMinStrategyScore;
      s.confidence=(int)MathRound(0.65*s.confidence+0.35*r.score);
      if(!r.spreadOK || s.confidence<MathMin(99,required-5))
      { s.valid=false; why=StringFormat("non-trend confluence insufficient: score %d confidence %d",r.score,s.confidence); return false; }
      r.valid=true;
   }
   why=StringFormat("strategy-aware confluence PASS %d/100",r.score);
   return true;
}

bool FreshApprovalValidation(const TradeSetup &s,string &why)
{
   why="";
   if(!s.valid){ why="Stored setup is no longer marked valid."; return false; }

   string releaseWhy="";
   if(!ReleaseSafetyAllows(s.symbol,releaseWhy))
   { why="Release safety gate failed: "+releaseWhy; return false; }

   string stopWhy="";
   if(!StopObservabilityAllowsNewEntries(stopWhy))
   { why="Partial-protection/stop gate failed: "+stopWhy; return false; }

   StrategyClass cls=(StrategyClass)(int)GVRead(SymKey(s.symbol,"CAND_STRATEGY"),STRATEGY_NO_TRADE);
   if(cls==STRATEGY_NO_TRADE){ why="No valid strategy classification remains."; return false; }
   if(!PriceInsideZone(s)){ why="Price left the approved entry zone."; return false; }
   if(!StrategyExecutionTrigger(s,cls)){ why="Strategy-specific M5 execution trigger is no longer present."; return false; }

   TradeSetup live=s;
   live.sl=NormalizePriceToTick(live.symbol,live.sl);
   live.tp1=NormalizePriceToTick(live.symbol,live.tp1);
   live.tp2=NormalizePriceToTick(live.symbol,live.tp2);
   live.tp3=NormalizePriceToTick(live.symbol,live.tp3);

   ConfluenceReport fresh=EvaluateConfluence(live);
   string confWhy="";
   if(!StrategyAwareConfluenceGate(live,fresh,cls,confWhy))
   { why="Confluence revalidation failed: "+confWhy; return false; }

   string institutional="";
   EnhanceSetupWithInstitutionalFilters(live,fresh,institutional);
   if(!live.valid && cls!=STRATEGY_COUNTER_TREND_SCALP && cls!=STRATEGY_COUNTER_TREND_SWING && cls!=STRATEGY_POTENTIAL_REVERSAL)
   { why="Institutional/regime validation failed: "+institutional; return false; }

   string intelWhy="";
   if(!PreEntryIntelligenceRevalidation(live,intelWhy))
   { why="Deep pre-entry intelligence failed: "+intelWhy; return false; }

   double liveRR=EffectiveRRDynamic(live);
   double rrFloor=(cls==STRATEGY_COUNTER_TREND_SCALP?MathMax(1.10,InpMinEffectiveRR-0.30):InpMinEffectiveRR);
   if(liveRR<rrFloor)
   { why=StringFormat("Effective R:R deteriorated to %.2f below %.2f strategy floor.",liveRR,rrFloor); return false; }

   double atr=0; ATRValue(s.symbol,PERIOD_M15,InpATRPeriod,1,atr);
   string sessionText="";
   if(SessionConditionInvalidates(s.symbol,s.preferred,atr,sessionText))
   { why=sessionText; return false; }

   string riskWhy="";
   if(!PreAuthorizationRiskAllows(live,riskWhy))
   { why="Risk authorization failed: "+riskWhy; return false; }

   double rm=0,ol=0;
   double lots=LotSizeForRisk(live,rm,ol);
   string brokerWhy="";
   if(lots<=0 || !BrokerExecutionAllows(live,lots,brokerWhy))
   { why="Broker execution validation failed: "+brokerWhy; return false; }

   string serverWhy="";
   if(!ServerOrderCheckAllows(live,lots,DynamicSlippagePoints(live.symbol),serverWhy))
   { why="Server OrderCheck failed: "+serverWhy; return false; }
   why="Fresh strategy + news + intermarket + confluence + risk + broker validation PASS.";
   return true;
}

void ApprovePending(const int idx)
{
   if(idx<0 || idx>=ArraySize(g_pending) || !g_pending[idx].active) return;
   if(TimeTradeServer()>=g_pending[idx].expiresAt)
   {
      DeletePending(idx,"approval arrived after timeout");
      return;
   }

   TradeSetup s=g_pending[idx].setup;
   SetApprovalFeedback("APPROVED  •  "+s.symbol+"  •  FINAL REVALIDATION",1);
   g_pending[idx].active=false;
   PersistPendingApprovals();
   SafeUniversalCheckpointNow();
   RenderApprovalPrompt();
   StyleApprovalUI();

   string why="";
   if(!FreshApprovalValidation(s,why))
   {
      SetApprovalFeedback("BLOCKED AFTER APPROVAL  •  "+s.symbol+"  •  FRESH VALIDATION FAILED",4);
      RenderApprovalPrompt();
      Print(s.symbol,": APPROVED but final validation failed: ",why," No order opened.");
      if(InpEnablePush && !(bool)MQLInfoInteger(MQL_TESTER))
         SendNotification(s.symbol+": approval rejected by fresh validation - "+why);
      return;
   }

   if(ApprovedPlaceTrade(s))
   {
      SetApprovalFeedback("ACTIVE  •  "+s.symbol+"  •  TRADE EXECUTED",1);
      RenderApprovalPrompt();
      if(InpEnablePush && !(bool)MQLInfoInteger(MQL_TESTER)) SendNotification(s.symbol+": APPROVED - trade executed.");
   }
   else
   {
      SetApprovalFeedback("BLOCKED AFTER APPROVAL  •  "+s.symbol+"  •  EXECUTION GATE FAILED",4);
      RenderApprovalPrompt();
      Print(s.symbol,": APPROVED but final strategy/news/release/broker/risk validation failed. No order opened.");
      if(InpEnablePush && !(bool)MQLInfoInteger(MQL_TESTER))
         SendNotification(s.symbol+": approved, but final execution validation failed; no trade opened.");
   }
}

string FilterStateText(bool newsBlock,bool yieldBlock,bool spreadOk,bool sessionBlock,bool aiAllows)
{
   return StringFormat("Filters: Calendar %s | Yield %s | Spread %s | Session %s | AI %s",
      newsBlock?"BLOCK":"OK",yieldBlock?"BLOCK":"OK",spreadOk?"OK":"BLOCK",sessionBlock?"BLOCK":"OK",aiAllows?"OK":"VETO");
}

// ------------------- Elegant live chart observability -------------------
string VisualShortText(string value,int maxLen=92)
{
   StringReplace(value,"\n"," ");
   StringReplace(value,"\r"," ");
   if(StringLen(value)<=maxLen) return value;
   return StringSubstr(value,0,MathMax(8,maxLen-3))+"...";
}

void DeleteVisualObject(const string name)
{
   if(ObjectFind(0,name)>=0) ObjectDelete(0,name);
}

void ClearTrailMovementSegments()
{
   int maxSeg=(int)MathMax(3,InpTrailMovementSegments);
   for(int i=0;i<maxSeg;i++) ObjectDelete(0,StringFormat("GPT_EA_TRAIL_SEG_%02d",i));
   g_visualTrailLastSL=0.0;
   g_visualTrailLastTime=0;
   g_visualTrailPid=0;
   g_visualTrailSeq=0;
}

void DeleteLiveManagementVisuals()
{
   DeleteVisualObject(LEVEL_BE);
   DeleteVisualObject(LEVEL_LIVE_SL);
   DeleteVisualObject(TAG_ENTRY);
   DeleteVisualObject(TAG_SL);
   DeleteVisualObject(TAG_BE);
   DeleteVisualObject(TAG_TP1);
   DeleteVisualObject(TAG_TP2);
   DeleteVisualObject(TAG_TP3);
   DeleteVisualObject(TAG_TRAIL);
   DeleteVisualObject("GPT_EA_RISK_ZONE");
   DeleteVisualObject("GPT_EA_REWARD_ZONE");
   ClearTrailMovementSegments();
}

bool FindChartManagedPosition(ulong &ticket)
{
   ticket=0;
   datetime newest=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i);
      if(tk==0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic || PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      datetime opened=(datetime)PositionGetInteger(POSITION_TIME);
      if(opened>=newest){ newest=opened; ticket=tk; }
   }
   return ticket>0;
}

void SetVisualPriceTag(const string name,double price,const string label,color c)
{
   if(price<=0) { DeleteVisualObject(name); return; }
   int sec=PeriodSeconds(_Period);
   if(sec<=0) sec=60;
   datetime t=TimeCurrent()+sec*4;
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_TEXT,0,t,price);
   else ObjectMove(0,name,0,t,price);
   ObjectSetString(0,name,OBJPROP_TEXT,label);
   ObjectSetString(0,name,OBJPROP_FONT,"Segoe UI Semibold");
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,8);
   ObjectSetInteger(0,name,OBJPROP_COLOR,c);
   ObjectSetInteger(0,name,OBJPROP_ANCHOR,ANCHOR_LEFT);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
}

void SetVisualBand(const string name,double p1,double p2,color c)
{
   if(p1<=0 || p2<=0){ DeleteVisualObject(name); return; }
   datetime left=TimeCurrent()-6*3600;
   datetime right=TimeCurrent()+6*3600;
   double hi=MathMax(p1,p2),lo=MathMin(p1,p2);
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_RECTANGLE,0,left,hi,right,lo);
   else
   {
      ObjectMove(0,name,0,left,hi);
      ObjectMove(0,name,1,right,lo);
   }
   ObjectSetInteger(0,name,OBJPROP_COLOR,c);
   ObjectSetInteger(0,name,OBJPROP_FILL,true);
   ObjectSetInteger(0,name,OBJPROP_BACK,true);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
}

double VisualBreakEvenLevel(const string sym,bool bull,double entry,double R)
{
   MqlTick t={}; double atr=0;
   if(!GetTickSafe(sym,t)) return entry;
   ATRValue(sym,PERIOD_M5,InpATRPeriod,1,atr);
   double cost=MathMax(InpBECostATRFrac*atr,(t.ask-t.bid)+DynamicSlippagePoints(sym)*PointFor(sym));
   double buffer=MathMax(cost,InpBELockMinR*R);
   return NormalizePriceToTick(sym,bull?entry+buffer:entry-buffer);
}

string VisualTPState(bool reached,bool partial)
{
   if(partial) return "SCALED";
   if(reached) return "HIT";
   return "WAIT";
}

string LiveManagementAction(bool tp1done,bool tp2done,int stage,double rNow,int expiry,int elapsedM15)
{
   if(!tp1done)
   {
      int remaining=MathMax(0,expiry-elapsedM15);
      return StringFormat("Protective SL active; monitoring TP1. Time invalidation in ~%d M15 candles if TP1 is not reached.",remaining);
   }
   if(stage<1) return "TP1 scale-out completed; EA is retrying broker-valid break-even protection.";
   if(stage==1) return StringFormat("Break-even protected. EA will lock %.2fR when price reaches %.2fR.",InpProfitLockR,InpProfitLockTriggerR);
   if(stage==2) return StringFormat("Profit locked at %.2fR. EA is waiting for %.2fR strong-lock trigger.",InpProfitLockR,InpStrongLockTriggerR);
   if(stage==3 && rNow<InpTrailStartR) return StringFormat("Strong profit lock active at %.2fR. ATR + M5 structure trail starts at %.2fR.",InpStrongLockR,InpTrailStartR);
   if(stage>=4) return StringFormat("ATR + M5 structure trailing ACTIVE. SL ratchets only in the profitable direction; TP2 %s and TP3/runner remain monitored.",tp2done?"completed":"pending");
   return "EA is protecting the runner and checking TP2, momentum, structure and the next barrier.";
}

void RecordTrailingMovement(ulong pid,double currentSL,int stage)
{
   if(!InpDrawTrailingMovement || currentSL<=0) return;
   if(g_visualTrailPid!=pid)
   {
      ClearTrailMovementSegments();
      g_visualTrailPid=pid;
      g_visualTrailLastSL=currentSL;
      g_visualTrailLastTime=TimeCurrent();
      return;
   }

   double pt=PointFor(_Symbol);
   if(g_visualTrailLastSL<=0)
   {
      g_visualTrailLastSL=currentSL;
      g_visualTrailLastTime=TimeCurrent();
      return;
   }
   if(MathAbs(currentSL-g_visualTrailLastSL)<=MathMax(pt*0.5,0.0000001)) return;

   int maxSeg=(int)MathMax(3,InpTrailMovementSegments);
   int slot=g_visualTrailSeq%maxSeg;
   string name=StringFormat("GPT_EA_TRAIL_SEG_%02d",slot);
   ObjectDelete(0,name);
   datetime now=TimeCurrent();
   if(ObjectCreate(0,name,OBJ_TREND,0,g_visualTrailLastTime,g_visualTrailLastSL,now,currentSL))
   {
      ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,false);
      ObjectSetInteger(0,name,OBJPROP_COLOR,stage>=4?C'218,126,255':C'80,211,211');
      ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_SOLID);
      ObjectSetInteger(0,name,OBJPROP_WIDTH,2);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,name,OBJPROP_BACK,false);
   }
   g_visualTrailSeq++;
   g_visualTrailLastSL=currentSL;
   g_visualTrailLastTime=now;
}

void DrawLiveManagementMap(ulong ticket)
{
   if(!InpDrawTradeLevels || !InpDrawLiveManagementLevels || !PositionSelectByTicket(ticket)) return;
   string sym=PositionGetString(POSITION_SYMBOL);
   if(sym!=_Symbol) return;
   ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
   bool bull=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
   double entry=PositionGetDouble(POSITION_PRICE_OPEN);
   double currentSL=PositionGetDouble(POSITION_SL);
   double initSL=GVRead(PosKey(pid,"INITSL"),LegacyTicketRead(ticket,"INITSL",currentSL));
   if(initSL<=0) initSL=HistoricalInitialSL(pid);
   double R=MathAbs(entry-initSL);
   if(R<=0) return;
   double tp1=LegacyTicketRead(ticket,"TP1",bull?entry+R:entry-R);
   double tp2=LegacyTicketRead(ticket,"TP2",bull?entry+2*R:entry-2*R);
   double tp3=LegacyTicketRead(ticket,"TP3",bull?entry+3*R:entry-3*R);
   double be=VisualBreakEvenLevel(sym,bull,entry,R);
   int stage=(int)GVRead(PosKey(pid,"SL_STAGE"),LegacyTicketRead(ticket,"ADV_STAGE",0));

   DeleteVisualObject(ZONE_BOX);
   SetVisualBand("GPT_EA_RISK_ZONE",entry,initSL,C'45,20,24');
   SetVisualBand("GPT_EA_REWARD_ZONE",entry,tp3,C'13,45,35');

   SetHLine(LEVEL_ENTRY,entry,C'232,199,104',STYLE_SOLID,2);
   SetHLine(LEVEL_SL,initSL,C'132,76,82',STYLE_DASH,1);
   SetHLine(LEVEL_BE,be,C'80,211,211',STYLE_DASHDOT,1);
   color liveSLColor=(stage>=4?C'218,126,255':(stage>=1?C'80,211,211':C'244,82,82'));
   SetHLine(LEVEL_LIVE_SL,currentSL,liveSLColor,STYLE_SOLID,2);
   SetHLine(LEVEL_TP1,tp1,C'94,210,142',STYLE_DASH,1);
   SetHLine(LEVEL_TP2,tp2,C'72,190,125',STYLE_DASH,1);
   SetHLine(LEVEL_TP3,tp3,C'53,167,106',STYLE_DOT,2);

   int d=DigitsFor(sym);
   double slR=(bull?currentSL-entry:entry-currentSL)/R;
   SetVisualPriceTag(TAG_ENTRY,entry,StringFormat("ENTRY  %.*f  •  0.00R",d,entry),C'75,165,255');
   SetVisualPriceTag(TAG_SL,initSL,StringFormat("INITIAL SL  %.*f  •  -1.00R",d,initSL),C'180,105,110');
   SetVisualPriceTag(TAG_BE,be,StringFormat("B.E.  %.*f  •  COST-PROTECTED",d,be),C'229,194,96');
   SetVisualPriceTag(TAG_TP1,tp1,StringFormat("TP1  %.*f  •  +1.00R",d,tp1),C'94,210,142');
   SetVisualPriceTag(TAG_TP2,tp2,StringFormat("TP2  %.*f  •  +2.00R",d,tp2),C'72,190,125');
   SetVisualPriceTag(TAG_TP3,tp3,StringFormat("TP3 / RUNNER  %.*f  •  +3.00R",d,tp3),C'53,167,106');
   SetVisualPriceTag(TAG_TRAIL,currentSL,StringFormat("%s SL  %.*f  •  LOCK %.2fR",StopStageName(stage),d,currentSL,slR),liveSLColor);
   RecordTrailingMovement(pid,currentSL,stage);
}

void RenderLiveManagementDashboard(ulong ticket)
{
   if(!InpDrawDashboard || !PositionSelectByTicket(ticket)) return;
   string sym=PositionGetString(POSITION_SYMBOL);
   if(sym!=_Symbol) return;

   ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
   bool bull=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
   double entry=PositionGetDouble(POSITION_PRICE_OPEN);
   double currentSL=PositionGetDouble(POSITION_SL);
   double volume=PositionGetDouble(POSITION_VOLUME);
   double floating=PositionGetDouble(POSITION_PROFIT);
   datetime opened=(datetime)PositionGetInteger(POSITION_TIME);
   double initSL=GVRead(PosKey(pid,"INITSL"),LegacyTicketRead(ticket,"INITSL",currentSL));
   if(initSL<=0) initSL=HistoricalInitialSL(pid);
   double R=MathAbs(entry-initSL);
   if(R<=0) return;

   double rNow=0,liveR=0,liveEntry=0,px=0; bool liveBull=bull;
   if(CurrentPositionR(ticket,rNow,liveR,liveEntry,px,liveBull))
   {
      R=liveR; entry=liveEntry; bull=liveBull;
   }

   double tp1=LegacyTicketRead(ticket,"TP1",bull?entry+R:entry-R);
   double tp2=LegacyTicketRead(ticket,"TP2",bull?entry+2*R:entry-2*R);
   double tp3=LegacyTicketRead(ticket,"TP3",bull?entry+3*R:entry-3*R);
   int expiry=(int)LegacyTicketRead(ticket,"EXP",InpPullbackExpiryM15);
   int elapsedM15=BarsSince(sym,PERIOD_M15,opened);
   bool tp1done=PositionFlag(pid,ticket,"TP1DONE");
   bool tp1partial=PositionFlag(pid,ticket,"TP1PARTIAL");
   bool tp2partial=PositionFlag(pid,ticket,"TP2PARTIAL");
   bool tp1reached=(bull?px>=tp1:px<=tp1) || tp1done;
   bool tp2reached=(bull?px>=tp2:px<=tp2) || tp2partial;
   bool tp3reached=(bull?px>=tp3:px<=tp3);
   int stage=(int)GVRead(PosKey(pid,"SL_STAGE"),LegacyTicketRead(ticket,"ADV_STAGE",0));
   double be=VisualBreakEvenLevel(sym,bull,entry,R);
   double lockedR=(currentSL>0?(bull?currentSL-entry:entry-currentSL)/R:-1.0);

   StrategyClass strategy=(StrategyClass)(int)GVRead(PosKey(pid,"STRATEGY"),CandidateStrategyForSymbol(sym));
   int life=(int)GVRead(PosKey(pid,"LIFECYCLE_STATE"),LIFE_FILLED);
   string modelDetail=""; int modelMode=CurrentModelTrustMode(modelDetail);
   string brokerDetail=""; double brokerHealth=BrokerHealthScore(sym,brokerDetail);
   string modelBrief=VisualShortText(modelDetail,76);
   string brokerBrief=VisualShortText(brokerDetail,76);
   double riskMoney=GVRead(PosKey(pid,"RISK"),0);
   string action=LiveManagementAction(tp1done,tp2partial,stage,rNow,expiry,elapsedM15);
   string releaseState=g_releaseBlocked?"BLOCK":"PASS";
   string releaseWhy=VisualShortText(g_releaseBlockReason,80);
   int d=DigitsFor(sym);

   string lifecycleBadge="ACTIVE";
   if(stage>=4) lifecycleBadge="TRAILING";
   else if(tp2reached) lifecycleBadge="TP2 HIT / RUNNER";
   else if(stage>=1 && tp1done) lifecycleBadge="B.E. ACTIVE";
   else if(tp1reached) lifecycleBadge="TP1 HIT";

   int panelW=(int)MathMax(590,InpDashboardWidth);
   int panelH=(int)MathMax(500,InpDashboardHeight);
   SetPremiumRect(DASH_PANEL,CORNER_RIGHT_UPPER,InpDashboardX,InpDashboardY,panelW,panelH,C'7,12,21',C'122,96,170',1);
   SetPremiumLabel(DASH_TITLE,CORNER_RIGHT_UPPER,InpDashboardX+20,InpDashboardY+13,
      "GPT EA  •  Live Trade Atelier",C'232,201,115',15,InpDashboardTitleFont,5);
   SetPremiumLabel(DASH_SUBTITLE,CORNER_RIGHT_UPPER,InpDashboardX+22,InpDashboardY+46,
      StringFormat("%s  •  %s  •  %s  •  lifecycle %s",sym,bull?"LONG":"SHORT",StrategyClassName(strategy),LifecycleStateName(life)),
      C'162,187,214',9,InpDashboardBodyFont,5);

   color stateColor=C'91,220,156';
   if(rNow<0) stateColor=C'244,110,110';
   else if(stage>=4) stateColor=PremiumPulseColor(C'190,120,255',C'226,162,255');
   else if(tp1done) stateColor=PremiumPulseColor(C'82,210,179',C'118,241,207');
   SetPremiumLabel(DASH_STATUS,CORNER_RIGHT_UPPER,InpDashboardX+22,InpDashboardY+70,
      StringFormat("● %s   •   %.2fR   •   floating %.2f   •   locked %.2fR",lifecycleBadge,rNow,floating,lockedR),
      stateColor,10,"Segoe UI Semibold",6);
   if(ObjectFind(0,DASH_TEXT)>=0) ObjectSetString(0,DASH_TEXT,OBJPROP_TEXT,"");

   int sx=InpDashboardX+18, sw=panelW-36;
   SetDashboardSection(DASH_MARKET_CARD,DASH_MARKET_LABEL,sx,InpDashboardY+94,sw,82,
      "MARKET / POSITION INTELLIGENCE",
      StringFormat("Ticket #%I64u  •  %s  •  Volume %.2f  •  Open %s\nMarket %.*f  •  Entry %.*f  •  Current %.2fR  •  Floating %.2f",
                   ticket,StrategyClassName(strategy),volume,TimeToString(opened,TIME_DATE|TIME_MINUTES),
                   d,px,d,entry,rNow,floating),
      C'64,137,204');

   SetDashboardSection(DASH_TRADE_CARD,DASH_TRADE_LABEL,sx,InpDashboardY+184,sw,110,
      "TRADE LADDER / PROFIT PROTECTION",
      StringFormat("SL %.*f  •  Live SL %.*f  •  B.E. %.*f  •  Stage %s  •  Locked %.2fR\n"
                   "TP1 %.*f [%s]  •  TP2 %.*f [%s]  •  TP3 %.*f [%s]\n"
                   "Trail start %.2fR  •  Time window %d/%d M15 candles",
                   d,initSL,d,currentSL,d,be,StopStageName(stage),lockedR,
                   d,tp1,VisualTPState(tp1reached,tp1partial),d,tp2,VisualTPState(tp2reached,tp2partial),
                   d,tp3,tp3reached?"HIT":"RUNNER",InpTrailStartR,elapsedM15,expiry),
      C'71,184,132');

   SetDashboardSection(DASH_RISK_CARD,DASH_RISK_LABEL,sx,InpDashboardY+302,sw,96,
      "RISK & SAFETY",
      StringFormat("Initial risk %.2f  •  Portfolio %.2f%%  •  Daily loss %.2f%%  •  Drawdown %.2f%%\n"
                   "Broker %.0f/100  •  Model %s  •  OpenAI %s  •  Release %s\nBroker: %s",
                   riskMoney,CurrentPortfolioRiskPercent(),DailyLossPercent(),EquityDrawdownPercent(),
                   brokerHealth,ModelTrustModeName(modelMode),APITransportVisualState(),releaseState,brokerBrief),
      g_releaseBlocked?C'214,76,82':C'215,173,82');

   SetDashboardSection(DASH_ACTION_CARD,DASH_ACTION_LABEL,sx,InpDashboardY+406,sw,64,
      "EA MANAGEMENT NOW",
      VisualShortText(action,126)+"\nSafety: "+VisualShortText(releaseWhy+" | "+modelBrief,126),
      stage>=4?C'187,119,250':C'116,101,181');

   if(ObjectFind(0,BTN_SCAN_NOW)<0) ObjectCreate(0,BTN_SCAN_NOW,OBJ_BUTTON,0,0,0);
   ObjectSetInteger(0,BTN_SCAN_NOW,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger(0,BTN_SCAN_NOW,OBJPROP_XDISTANCE,InpDashboardX+22);
   ObjectSetInteger(0,BTN_SCAN_NOW,OBJPROP_YDISTANCE,InpDashboardY+panelH-38);
   ObjectSetInteger(0,BTN_SCAN_NOW,OBJPROP_XSIZE,142);
   ObjectSetInteger(0,BTN_SCAN_NOW,OBJPROP_YSIZE,27);
   ObjectSetInteger(0,BTN_SCAN_NOW,OBJPROP_BGCOLOR,C'54,65,105');
   ObjectSetInteger(0,BTN_SCAN_NOW,OBJPROP_COLOR,clrWhite);
   ObjectSetInteger(0,BTN_SCAN_NOW,OBJPROP_BORDER_COLOR,C'122,105,175');
   ObjectSetString(0,BTN_SCAN_NOW,OBJPROP_FONT,"Segoe UI Semibold");
   ObjectSetString(0,BTN_SCAN_NOW,OBJPROP_TEXT,"↻  REANALYZE");

   DrawLiveManagementMap(ticket);
   StyleApprovalUI();
   ChartRedraw();
}

void RenderCandidateOperationalDashboard()
{
   if(!InpDrawDashboard || !g_visualHasSetup || g_visualLastSetup.symbol!=_Symbol) return;
   TradeSetup s=g_visualLastSetup;
   ConfluenceReport r=g_visualLastReport;

   MqlTick tick={};
   double market=0;
   if(GetTickSafe(s.symbol,tick)) market=(tick.bid+tick.ask)*0.5;
   double atr=0; ATRValue(s.symbol,PERIOD_M15,InpATRPeriod,1,atr);
   double distATR=(atr>0?MathAbs(market-s.preferred)/atr:0);
   bool inZone=PriceInsideZone(s);
   StrategyClass strategy=CandidateStrategyForSymbol(s.symbol);
   string modelDetail=""; int modelMode=CurrentModelTrustMode(modelDetail);
   string brokerDetail=""; double brokerHealth=BrokerHealthScore(s.symbol,brokerDetail);
   string modelBrief=VisualShortText(modelDetail,76);
   string brokerBrief=VisualShortText(brokerDetail,76);
   int pending=ActivePendingForSymbol(s.symbol);
   string releaseState=g_releaseBlocked?"BLOCK":"PASS";
   string releaseWhy=VisualShortText(g_releaseBlockReason,80);
   string action="";
   if(pending>=0) action="High-confidence setup passed scan gates; waiting for your timed APPROVE / DENY decision.";
   else if(g_visualLastReady && inZone) action="Price/trigger is ready; EA is running final fresh intelligence, risk, broker and release validation.";
   else if(inZone) action="Price is in the entry zone, but at least one strategy/confirmation gate is still waiting.";
   else action="Monitoring price toward preferred entry while continuously rechecking structure, news, costs and risk.";

   int remain=0;
   if(pending>=0) remain=(int)MathMax(0,(long)(g_pending[pending].expiresAt-TimeTradeServer()));
   int d=DigitsFor(s.symbol);
   double R=MathAbs(s.preferred-s.sl);
   double beBuffer=MathMax(InpBELockMinR*R,PointFor(s.symbol)*2.0);
   double be=NormalizePriceToTick(s.symbol,s.bullish?s.preferred+beBuffer:s.preferred-beBuffer);
   double trailStart=NormalizePriceToTick(s.symbol,s.bullish?s.preferred+InpTrailStartR*R:s.preferred-InpTrailStartR*R);

   int panelW=(int)MathMax(590,InpDashboardWidth);
   int panelH=(int)MathMax(500,InpDashboardHeight);
   SetPremiumRect(DASH_PANEL,CORNER_RIGHT_UPPER,InpDashboardX,InpDashboardY,panelW,panelH,C'8,14,23',C'73,126,169',1);
   SetPremiumLabel(DASH_TITLE,CORNER_RIGHT_UPPER,InpDashboardX+20,InpDashboardY+13,
      "GPT EA  •  Market Intelligence Atelier",C'232,201,115',15,InpDashboardTitleFont,5);
   SetPremiumLabel(DASH_SUBTITLE,CORNER_RIGHT_UPPER,InpDashboardX+22,InpDashboardY+46,
      StringFormat("%s  •  %s  •  %s  •  D1 H4 H1 M30 M15 M5",
                   s.symbol,s.bullish?"LONG BIAS":"SHORT BIAS",StrategyClassName(strategy)),
      C'162,187,214',9,InpDashboardBodyFont,5);

   bool operationalReady=(g_visualLastReady && inZone && !g_releaseBlocked);
   string statusText=pending>=0?StringFormat("● APPROVAL PENDING  •  AUTO-DENY IN %ds",remain):
                     operationalReady?"● FINAL EXECUTION CHECKS ACTIVE":"● ANALYZING / WAITING";
   color statusColor=pending>=0 && remain<=MathMax(5,InpApprovalDangerSeconds)?
                     PremiumPulseColor(C'225,83,91',C'255,129,136'):
                     (operationalReady?C'91,220,156':C'245,184,86');
   SetPremiumLabel(DASH_STATUS,CORNER_RIGHT_UPPER,InpDashboardX+22,InpDashboardY+70,
      statusText,statusColor,10,"Segoe UI Semibold",6);
   if(ObjectFind(0,DASH_TEXT)>=0) ObjectSetString(0,DASH_TEXT,OBJPROP_TEXT,"");

   int sx=InpDashboardX+18, sw=panelW-36;
   SetDashboardSection(DASH_MARKET_CARD,DASH_MARKET_LABEL,sx,InpDashboardY+94,sw,92,
      "MARKET INTELLIGENCE",
      StringFormat("Market %.*f  •  Preferred %.*f  •  Distance %.2f ATR  •  In zone %s\n"
                   "Confidence %d%%  •  Confluence %d/100  •  ADX %.1f  •  Volume %.2fx\n"
                   "Structure %s  •  Sweep %s  •  FVG %s  •  Rejection %s",
                   d,market,d,s.preferred,distATR,inZone?"YES":"NO",
                   s.confidence,r.score,r.adx,r.volumeRatio,
                   r.structureAligned?"YES":"NO",r.liquiditySweep?"YES":"NO",r.fairValueGap?"YES":"NO",r.rejectionCandle?"YES":"NO"),
      C'64,137,204');

   SetDashboardSection(DASH_TRADE_CARD,DASH_TRADE_LABEL,sx,InpDashboardY+194,sw,112,
      "TRADE APPROVAL / LEVEL LADDER",
      StringFormat("%s  •  Entry %.*f – %.*f  •  Preferred %.*f  •  Eff R:R %.2f\n"
                   "SL %.*f [-1R]  •  B.E. %.*f  •  Trail start %.*f [%.2fR]\n"
                   "TP1 %.*f [+1R]  •  TP2 %.*f [+2R]  •  TP3 %.*f [+3R]",
                   StrategyClassName(strategy),d,s.zoneLow,d,s.zoneHigh,d,s.preferred,s.effectiveRR1,
                   d,s.sl,d,be,d,trailStart,InpTrailStartR,
                   d,s.tp1,d,s.tp2,d,s.tp3),
      pending>=0?PremiumPulseColor(C'76,147,215',C'106,190,248'):C'84,156,213');

   SetDashboardSection(DASH_RISK_CARD,DASH_RISK_LABEL,sx,InpDashboardY+314,sw,96,
      "RISK & SAFETY",
      StringFormat("Portfolio %.2f%%  •  Daily loss %.2f%%  •  Drawdown %.2f%%  •  Broker %.0f/100\n"
                   "Model %s  •  OpenAI %s  •  Release %s\nFilters: %s",
                   CurrentPortfolioRiskPercent(),DailyLossPercent(),EquityDrawdownPercent(),brokerHealth,
                   ModelTrustModeName(modelMode),APITransportVisualState(),releaseState,VisualShortText(g_visualLastFilter,104)),
      g_releaseBlocked?C'214,76,82':C'215,173,82');

   SetDashboardSection(DASH_ACTION_CARD,DASH_ACTION_LABEL,sx,InpDashboardY+418,sw,54,
      "EA ACTION NOW",
      VisualShortText(action,132)+"\n"+VisualShortText("Broker "+brokerBrief+" | Model "+modelBrief+" | Release "+releaseWhy,132),
      pending>=0?C'92,174,229':C'116,101,181');

   if(ObjectFind(0,BTN_SCAN_NOW)<0) ObjectCreate(0,BTN_SCAN_NOW,OBJ_BUTTON,0,0,0);
   ObjectSetInteger(0,BTN_SCAN_NOW,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger(0,BTN_SCAN_NOW,OBJPROP_XDISTANCE,InpDashboardX+22);
   ObjectSetInteger(0,BTN_SCAN_NOW,OBJPROP_YDISTANCE,InpDashboardY+panelH-38);
   ObjectSetInteger(0,BTN_SCAN_NOW,OBJPROP_XSIZE,142);
   ObjectSetInteger(0,BTN_SCAN_NOW,OBJPROP_YSIZE,27);
   ObjectSetInteger(0,BTN_SCAN_NOW,OBJPROP_BGCOLOR,C'34,87,139');
   ObjectSetInteger(0,BTN_SCAN_NOW,OBJPROP_COLOR,clrWhite);
   ObjectSetInteger(0,BTN_SCAN_NOW,OBJPROP_BORDER_COLOR,C'107,173,221');
   ObjectSetString(0,BTN_SCAN_NOW,OBJPROP_FONT,"Segoe UI Semibold");
   ObjectSetString(0,BTN_SCAN_NOW,OBJPROP_TEXT,"↻  SCAN NOW");

   DrawTradeMap(s);
   StyleApprovalUI();
   ChartRedraw();
}

void RefreshElegantChartDashboard(bool force=false)
{
   if(!InpElegantChartDashboard) return;
   ulong nowMS=GetTickCount64();
   int refreshMs=(int)MathMax(100,InpDashboardRefreshMs);
   if(!force && g_visualLastRefreshMS>0 && nowMS-g_visualLastRefreshMS<(ulong)refreshMs) return;
   g_visualLastRefreshMS=nowMS;

   ulong ticket=0;
   if(FindChartManagedPosition(ticket))
   {
      RenderLiveManagementDashboard(ticket);
      return;
   }

   if(g_visualTrailPid!=0)
   {
      DeleteLiveManagementVisuals();
      DeleteVisualObject(LEVEL_ENTRY);
      DeleteVisualObject(LEVEL_SL);
      DeleteVisualObject(LEVEL_TP1);
      DeleteVisualObject(LEVEL_TP2);
      DeleteVisualObject(LEVEL_TP3);
   }

   if(g_visualHasSetup && g_visualLastSetup.symbol==_Symbol)
      RenderCandidateOperationalDashboard();
   else
      ChartRedraw();
}

// ----------------------------- Scanner ----------------------------
void ScanSymbol(const string sym,const string scanReason)
{
   if(!EnsureSymbol(sym)){ Print("Symbol unavailable: ",sym); return; }
   if(!BrokerSymbolEligibleForUniverse(sym))
   {
      if(InpPrintBrokerSymbolProfiles) Print("GPT_EA universe skip (not entry-eligible): ",sym);
      return;
   }

   string trend="";
   bool alignedBull=false,alignedBear=false;
   int mtfScore=MultiTFScore(sym,trend,alignedBull,alignedBear);
   bool baseBull=(mtfScore>=0);
   if(alignedBear) baseBull=false; else if(alignedBull) baseBull=true;
   int base=BaseConfidenceFromScore(mtfScore,alignedBull,alignedBear,baseBull);

   TradeSetup pb=BuildPullback(sym,baseBull,base,trend);
   TradeSetup br=BuildBreakoutRetest(sym,baseBull,base,trend);

   // First classify the market and choose the strategy; never force pullback/breakout on every chart.
   StrategyDecision decision;
   SelectDynamicStrategy(sym,pb,br,decision);
   TradeSetup primary=decision.setup;
   if(primary.symbol=="") primary=(pb.confidence>=br.confidence?pb:br);

   ConfluenceReport pbReport=EvaluateConfluence(pb),brReport=EvaluateConfluence(br),primaryReport=EvaluateConfluence(primary);
   ApplyAdvancedConfluence(pb,pbReport); ApplyAdvancedConfluence(br,brReport);
   string pbInstitutional="",brInstitutional="";
   EnhanceSetupWithInstitutionalFilters(pb,pbReport,pbInstitutional);
   EnhanceSetupWithInstitutionalFilters(br,brReport,brInstitutional);

   string strategyConfWhy="";
   bool strategyConfluence=StrategyAwareConfluenceGate(primary,primaryReport,decision.strategy,strategyConfWhy);
   string primaryInstitutional="";
   bool institutionalOK=EnhanceSetupWithInstitutionalFilters(primary,primaryReport,primaryInstitutional);
   if(decision.counterTrend && strategyConfluence)
   {
      // HTF opposition is expected for a valid counter-trend setup. Institutional filters remain informative,
      // while counter-trend score/trigger and hard risk/news gates carry the stricter authorization burden.
      primary.valid=(primary.valid && primary.effectiveRR1>=MathMax(1.10,InpMinEffectiveRR-0.30));
      institutionalOK=primary.valid;
   }

   string newsText="",yieldText="",spreadText="",sessionText="";
   bool newsBlock=CalendarBlock(sym,newsText);
   bool yieldBlock=YieldShock(yieldText);
   bool spreadOk=SpreadOK(sym,spreadText);
   double atr=0; ATRValue(sym,PERIOD_M15,InpATRPeriod,1,atr);
   bool sessionBlock=SessionConditionInvalidates(sym,primary.preferred,atr,sessionText);

   IntermarketReport intermarket=AssessIntermarket(sym,primary.bullish);
   string webText="",webError=""; bool webBlock=false,webWatch=false;
   bool webAvailable=GetLiveWebIntel(sym,primary,decision,false,webText,webBlock,webWatch,webError);
   string emergencyWebWhy="";
   bool emergencyWebBypass=(!webAvailable && g_lastWebIntelFailureClass=="UNAVAILABLE" &&
                            DeterministicEmergencyExecutionActive(sym,decision.strategy,emergencyWebWhy));
   if(!webAvailable && InpBlockIfWebIntelUnavailable && !emergencyWebBypass) webBlock=true;
   if(emergencyWebBypass)
   {
      webBlock=false; webWatch=true;
      webText="DETERMINISTIC_ONLY external-intelligence transport outage bypass | "+emergencyWebWhy+" | "+webText;
   }

   bool readyNow=(primary.valid && decision.action==STRATEGY_ACTION_HIGH_CONFIDENCE && StrategyExecutionTrigger(primary,decision.strategy));
   string upcoming=UpcomingEventSummary(sym);

   string card=StrategyDecisionHeader(decision);
   card+=BuildCard(primary,pb,br,scanReason,newsBlock,newsText,spreadText,spreadOk,yieldBlock,yieldText,sessionBlock,sessionText);
   card+=ConfluenceCardBlock(primaryReport,upcoming,readyNow);
   card+=StringFormat("Pullback confluence: %d/100 | Breakout-retest confluence: %d/100 | Selected strategy confluence: %d/100\n",pbReport.score,brReport.score,primaryReport.score);
   card+="Strategy rationale: "+decision.rationale+"\n";
   card+="Strategy confirmation: "+decision.confirmation+"\n";
   card+="Counterargument: "+decision.counterargument+"\n";
   card+="Institutional validation: "+primaryInstitutional+"\n";
   card+="Pullback institutional: "+pbInstitutional+"\n";
   card+="Breakout institutional: "+brInstitutional+"\n";
   card+="Intermarket: "+intermarket.detail+"\n";
   card+="Live web/news intelligence: "+webText+"\n";
   card+="Broker environment: "+BrokerEnvironmentSummary()+"\n";
   card+="Broker symbol profile: "+SymbolProfileSummary(sym)+"\n";

   string thesis=BuildMandatory25PointThesis(sym,primary,pb,br,decision,primaryReport,newsText,webText,intermarket,spreadText,sessionText);
   card+=thesis;

   bool aiAvailable=false; string aiAnswer="",aiError="";
   bool requestAI=(InpUseOpenAI && (!InpAIReviewHighConfidenceOnly || decision.score>=InpMinStrategyScore));
   if(requestAI)
   {
      aiAvailable=CallOpenAI(BuildDeepGPTPrompt(sym,card,thesis,webText,decision),aiAnswer,aiError);
      if(aiAvailable) card+="\n━━━━━━━━━━━━━━━━━━━━\n🤖 GPT ADVERSARIAL VALIDATION\n━━━━━━━━━━━━━━━━━━━━\n"+aiAnswer+"\n";
      else card+="\nGPT secondary validation unavailable: "+aiError+"\n";
   }

   string aiGateWhy="";
   bool aiAllows=AIReviewAllowsExecution(aiAnswer,aiAvailable,aiGateWhy);
   if(!requestAI && InpAICanVetoTrade){ aiAllows=true; aiGateWhy="AI review not requested for this candidate."; }

   string releaseWhy=""; bool releaseAllows=ReleaseSafetyAllows(sym,releaseWhy);
   string stopObsWhy=""; bool stopObsAllows=StopObservabilityAllowsNewEntries(stopObsWhy);
   string evidenceText=""; bool evidenceAllows=StrategyEvidenceAllows(decision.strategy,evidenceText);

   string riskWhy=""; bool riskAllows=PreAuthorizationRiskAllows(primary,riskWhy);
   double previewRisk=0,previewOneLot=0;
   double previewLots=LotSizeForRisk(primary,previewRisk,previewOneLot);
   string brokerWhy=""; bool brokerAllows=(previewLots>0 && BrokerExecutionAllows(primary,previewLots,brokerWhy));
   if(previewLots<=0) brokerWhy="Preview lot calculation returned zero.";

   string serverWhy=""; bool serverAllows=false;
   if(brokerAllows) serverAllows=ServerOrderCheckAllows(primary,previewLots,DynamicSlippagePoints(sym),serverWhy);
   else serverWhy="Skipped because broker execution gate did not pass.";

   double rrFloor=(decision.strategy==STRATEGY_COUNTER_TREND_SCALP?MathMax(1.10,InpMinEffectiveRR-0.30):InpMinEffectiveRR);
   bool strategyActionOK=(decision.action==STRATEGY_ACTION_HIGH_CONFIDENCE);
   bool hardValid=(strategyActionOK && primary.valid && strategyConfluence && institutionalOK && evidenceAllows &&
                   !newsBlock && !yieldBlock && !sessionBlock && spreadOk && EffectiveRRDynamic(primary)>=rrFloor &&
                   !intermarket.severeConflict && !(InpBlockOnWebIntelVerdictBLOCK && webBlock) && aiAllows &&
                   releaseAllows && stopObsAllows && riskAllows && brokerAllows && serverAllows);
   bool approvalReady=(hardValid && readyNow);

   string filterState=FilterStateText(newsBlock,yieldBlock,spreadOk,sessionBlock,aiAllows);
   filterState+=" | Web "+(webBlock?"BLOCK":webWatch?"WATCH":"OK");
   filterState+=" | Intermarket "+(intermarket.severeConflict?"BLOCK":"OK");
   filterState+=" | Release "+(releaseAllows?"OK":"BLOCK");
   filterState+=" | StopRisk "+(stopObsAllows?"OK":"BLOCK");
   card+="\n"+filterState+"\n";
   card+="Strategy decision: "+(strategyActionOK?"HIGH-CONFIDENCE":"WAIT/NO TRADE")+" | "+strategyConfWhy+"\n";
   card+="Historical strategy evidence gate: "+evidenceText+"\n";
   card+="GPT execution gate: "+aiGateWhy+"\n";
   card+="Release safety gate: "+(releaseAllows?"PASS":"BLOCK - "+releaseWhy)+"\n";
   card+="Partial-protection/stop gate: "+stopObsWhy+"\n";
   card+="Portfolio/risk gate: "+riskWhy+"\n";
   card+="Broker execution gate: "+brokerWhy+"\n";
   card+="MT5 OrderCheck gate: "+serverWhy+"\n";
   card+=StringFormat("Portfolio risk %.2f%% | daily loss %.2f%% | drawdown %.2f%% | consecutive losses %d\n",
                      CurrentPortfolioRiskPercent(),DailyLossPercent(),EquityDrawdownPercent(),ConsecutiveLosses());
   card+=StringFormat("Dynamic slippage ceiling %d points | dynamic effective R:R %.2f\n",DynamicSlippagePoints(sym),EffectiveRRDynamic(primary));
   card+=StringFormat("FINAL DECISION: %s\n",approvalReady?"✅ HIGH-CONFIDENCE TRADE SETUP — APPROVE / DENY ACTIVE":
                     decision.action==STRATEGY_ACTION_NO_TRADE?"❌ NO TRADE":"⏳ WAIT FOR CONFIRMATION / REANALYZE");

   NotifyCard(card);
   RenderAdvancedDashboard(primary,primaryReport,filterState,readyNow);
   UpdateRiskAnalyticsPanel();

   int existing=ActivePendingForSymbol(sym);
   if(approvalReady)
   {
      PersistStrategyCandidate(sym,decision);
      if(InpRequireApproval) QueueForApproval(primary,card,scanReason);
      else
      {
         string freshWhy="";
         if(FreshApprovalValidation(primary,freshWhy)) ApprovedPlaceTrade(primary);
         else Print(sym,": execution skipped after final validation: ",freshWhy);
      }
   }
   else if(existing>=0)
   {
      DeletePending(existing,"fresh scan no longer meets complete intelligence/entry conditions");
   }
}

void ScanAll(const string reason)
{
   int total=ArraySize(g_symbols);
   if(total<=0) return;

   int batch=(InpUniversalScanBatchSize<=0?total:MathMin(total,InpUniversalScanBatchSize));
   int scanned=0;
   int visited=0;
   int start=g_universalScanCursor;
   while(scanned<batch && visited<total)
   {
      int idx=(start+visited)%total;
      string sym=g_symbols[idx];
      visited++;
      if(sym=="") continue;
      ScanSymbol(sym,reason);
      scanned++;
   }

   g_universalScanCursor=(start+visited)%total;
   PrintFormat("GPT_EA universe scan: %d/%d symbols processed | next cursor=%d | reason=%s",
               scanned,total,g_universalScanCursor,reason);
}

// -------------------------- MT5 event hooks -----------------------
int OnInit()
{
   if(SplitSymbols()<=0){ Print("No symbols configured."); return INIT_PARAMETERS_INCORRECT; }
   if(!ResolveConfiguredSymbolsUniversal())
   { Print("No configured symbols could be resolved on this broker."); return INIT_PARAMETERS_INCORRECT; }

   PrintResolvedBrokerProfiles();
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpMaxSlippagePoints);
   ApplyChartPolish();
   ChartSetInteger(0,CHART_EVENT_MOUSE_MOVE,true);
   EventSetTimer(MathMax(1,InpTimerSeconds));
   RiskRecoveryInit();
   PrepareRecoveryCheckpointFallback();
   UniversalRecoveryInit();
   RecoverySafetyAudit();
   SafeUniversalCheckpointNow();
   AdvancedSafetyInit();
   StopFailurePolicyInit();
   StopFailureObservabilityInit();
   StrategyIntelligenceInit();
   NewsIntermarketInit();

   Print("GPT_EA Full Intelligence initialized. Approval=",InpRequireApproval?"REQUIRED":"DISABLED",
         ", Timeout=",InpApprovalTimeoutSeconds,"s",
         ", Min strategy=",InpMinStrategyScore,
         ", Min confluence=",InpMinAdvancedConfluence,
         ", Portfolio cap=",DoubleToString(InpMaxPortfolioRiskPercent,2),"%",
         ", Live web intel=",InpUseLiveWebIntelligence?"ON":"OFF",
         ", ReleaseGate=",ReleaseGateSummary());

   if(InpUseOpenAI && InpAPITransportMode==GPT_API_DIRECT_OPENAI && StringLen(OpenAILocalCredential())<20)
      Print("OpenAI enabled but no direct-mode key was found. Create the local key file or enter the key locally in EA Inputs; never commit it.");
   if(InpUseOpenAI || InpUseLiveWebIntelligence)
      Print("MT5 WebRequest allow-list target: ",APITransportAllowListURL());
   Print("OpenAI credential source=",InpAPITransportMode==GPT_API_SECURE_PROXY?"SCOPED PROXY TOKEN":OpenAIKeySourceText(),
         ". Secret value is never printed.");
   Print("Premium dashboard=",InpPremiumDashboard?"ON":"OFF",
         ", OpenAI visual status=",APITransportVisualState(),
         ", Approval hero timeout=",InpApprovalTimeoutSeconds,"s");

   ScanAll("EA startup / restart recovery full-intelligence scan");
   RefreshElegantChartDashboard(true);
   RenderApprovalPrompt(); StyleApprovalUI(); UpdateRiskAnalyticsPanel(); SafeUniversalCheckpointNow();
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   UniversalRecoveryShutdown();
   BackupRecoveryCheckpointIfValid();
   RiskRecoveryShutdown();
   DeleteApprovalObjects();
   DeleteAdvancedDashboard();
   Comment("");
}

void OnTimer()
{
   // Existing positions remain managed even if new-entry intelligence or release gates are blocked.
   ManagePositionsAdvanced();
   RefreshElegantChartDashboard(true);
   ProcessApprovalTimeouts();
   AnimateApprovalHero(true);
   RiskRecoveryTimer();
   SafeUniversalRecoveryTimer();
   AdvancedSafetyTimer();
   StopFailurePolicyTimer();
   StopFailureObservabilityTimer();
   StrategyIntelligenceTimer();
   NewsIntermarketTimer();
   StyleApprovalUI();

   string why="";
   if(ScheduledScanDue(why))
   {
      ScanAll(why);
      RefreshElegantChartDashboard(true);
   }
}

void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result)
{
   HandleReliabilityTradeTransaction(trans,request,result);
   HandleRiskAnalyticsTradeTransaction(trans,request,result);
   RefreshElegantChartDashboard(true);
}

void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
   if(id==CHARTEVENT_MOUSE_MOVE)
   {
      bool oldA=g_approvalHoverApprove,oldD=g_approvalHoverDeny;
      UpdateApprovalHover(lparam,dparam);
      if(oldA!=g_approvalHoverApprove || oldD!=g_approvalHoverDeny)
      {
         StyleApprovalUI();
         ChartRedraw();
      }
      return;
   }

   if(id!=CHARTEVENT_OBJECT_CLICK) return;
   if(sparam==BTN_SCAN_NOW)
   {
      ObjectSetInteger(0,BTN_SCAN_NOW,OBJPROP_STATE,false);
      ScanAll("Manual SCAN NOW");
      RefreshElegantChartDashboard(true);
      return;
   }
   if(sparam==BTN_PAUSE)
   {
      ObjectSetInteger(0,BTN_PAUSE,OBJPROP_STATE,false);
      ToggleTradingPause(); SafeUniversalCheckpointNow(); UpdateRiskAnalyticsPanel();
      if(g_manualPaused) for(int i=0;i<ArraySize(g_pending);i++) if(g_pending[i].active) DeletePending(i,"manual trading pause");
      return;
   }
   if(g_displayPending<0) return;
   if(sparam==BTN_APPROVE)
   {
      ObjectSetInteger(0,BTN_APPROVE,OBJPROP_STATE,false);
      ApprovePending(g_displayPending);
   }
   else if(sparam==BTN_DENY)
   {
      ObjectSetInteger(0,BTN_DENY,OBJPROP_STATE,false);
      DeletePending(g_displayPending,"user denied trade");
   }
}

void OnTick()
{
   // Execution remains timer-driven. Tick handling refreshes premium observability only.
   RefreshElegantChartDashboard(false);
   AnimateApprovalHero(false);
}
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
