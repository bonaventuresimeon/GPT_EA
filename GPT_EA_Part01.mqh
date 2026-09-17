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
enum SetupKind { SETUP_NONE=0, SETUP_PULLBACK=1, SETUP_BREAKOUT_RETEST=2 };

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
