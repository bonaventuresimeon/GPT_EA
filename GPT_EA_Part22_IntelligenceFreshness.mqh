// ============================================================================
// GPT_EA Part 22 - Structured live-news contract and fresh intermarket data
// ============================================================================

input bool InpUseStructuredWebIntel            = true;
input bool InpFailClosedHighConfidenceNews     = true;
input bool InpRequireWebIntelSources            = true;
input int  InpWebIntelRiskWatchScore            = 50;
input int  InpWebIntelRiskBlockScore            = 80;
input int  InpWebIntelFailureCircuitThreshold   = 3;
input int  InpWebIntelMaxCacheAgeMinutes        = 12;
input int  InpIntermarketMaxBarAgeMinutes       = 90;
input int  InpIntermarketMinFreshComponents     = 1;

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
   if(!InpUseLiveWebIntelligence){ errorText="Live web intelligence disabled."; return false; }
   if((bool)MQLInfoInteger(MQL_TESTER)){ errorText="WebRequest/web search unavailable in Strategy Tester."; return false; }
   if(StringLen(Trim(InpOpenAIAPIKey))<20){ errorText="OpenAI API key not configured."; return false; }

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
   if(code==-1){ errorText=StringFormat("Structured web-intel WebRequest failed (%d).",GetLastError()); return false; }
   string response=CharArrayToString(result,0,-1,CP_UTF8);
   if(code<200 || code>=300){ errorText=StringFormat("Structured web-intel HTTP %d: %s",code,StringSubstr(response,0,500)); return false; }
   answer=ExtractOpenAIText(response);
   if(answer=="" || StringFind(answer,"could not be parsed")>=0){ errorText="Structured web-intel response text unavailable."; return false; }

   string events="",breaking="",invalidation="",intermarket="",asof="";
   bool ok=(JsonStringFieldSimple(answer,"verdict",verdict) &&
            JsonIntFieldSimple(answer,"risk_score",riskScore) &&
            JsonStringFieldSimple(answer,"events",events) &&
            JsonStringFieldSimple(answer,"breaking_news",breaking) &&
            JsonStringFieldSimple(answer,"invalidation_channel",invalidation) &&
            JsonStringFieldSimple(answer,"intermarket",intermarket) &&
            JsonStringFieldSimple(answer,"sources",sources) &&
            JsonStringFieldSimple(answer,"as_of_utc",asof));
   if(!ok){ errorText="Structured web-intel JSON failed required-field validation."; return false; }
   StringToUpper(verdict);
   if(verdict!="CLEAR" && verdict!="WATCH" && verdict!="BLOCK")
   { errorText="Structured web-intel verdict is outside CLEAR/WATCH/BLOCK contract."; return false; }
   if(riskScore<0 || riskScore>100){ errorText="Structured web-intel risk_score is outside 0-100."; return false; }
   if(InpRequireWebIntelSources && StringLen(Trim(sources))<8)
   { errorText="Structured web-intel did not provide source attribution."; return false; }

   answer=StringFormat("VERDICT: %s; RISK_SCORE: %d; AS_OF_UTC: %s; EVENTS: %s; BREAKING_NEWS: %s; INVALIDATION_CHANNEL: %s; INTERMARKET: %s; SOURCES: %s",
                       verdict,riskScore,asof,events,breaking,invalidation,intermarket,sources);
   return true;
}

bool GetLiveWebIntelHardened(const string sym,const TradeSetup &s,const StrategyDecision &d,bool force,string &text,bool &block,bool &watch,string &errorText)
{
   text=""; block=false; watch=false; errorText="";
   if(!InpUseLiveWebIntelligence){ text="Live web intelligence disabled."; return true; }
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
      // Compatibility fallback retains current web-search behavior but is explicitly downgraded.
      string fallback="",fallbackErr="";
      bool fallbackOK=CallOpenAIWebIntel(prompt,fallback,fallbackErr);
      if(fallbackOK)
      {
         text="UNSTRUCTURED FALLBACK — downgraded confidence. "+fallback;
         InterpretWebIntel(fallback,block,watch);
         watch=true;
         g_webHardFailCounts[fidx]++;
      }
      else
      {
         g_webHardFailCounts[fidx]++;
         errorText+=(errorText!=""?" | ":"")+fallbackErr;
         bool highQualityCandidate=(d.action==STRATEGY_ACTION_HIGH_CONFIDENCE || d.score>=InpMinStrategyScore);
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
   string key=CanonicalInstrumentKey(target,SymbolInfoString(target,SYMBOL_DESCRIPTION),SymbolInfoString(target,SYMBOL_PATH));
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
