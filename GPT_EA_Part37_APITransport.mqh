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

   string config="";
   if(!APITransportConfigurationAllows(config))
   {
      APIStringToResult("API transport configuration blocked: "+config,result);
      return 598;
   }

   datetime now=TimeLocal();
   if(InpAPIBlockDuringBackoff && g_apiTransportNextRetry>now)
   {
      APIStringToResult(StringFormat("API transport backoff active until %s.",TimeToString(g_apiTransportNextRetry,TIME_DATE|TIME_SECONDS)),result);
      result_headers="X-GPT-EA-Transport: backoff\r\n";
      return 598;
   }

   string trace=APINewTraceId();
   GVWrite(SysKey("MODEL_REQ"),GVRead(SysKey("MODEL_REQ"),0)+1);
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
