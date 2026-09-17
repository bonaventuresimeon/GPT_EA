// ============================================================================
// GPT_EA Part 16 - Live web news, macro and intermarket intelligence
// ============================================================================

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
   string key=CanonicalInstrumentKey(target,SymbolInfoString(target,SYMBOL_DESCRIPTION),SymbolInfoString(target,SYMBOL_PATH));
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
   string key=CanonicalInstrumentKey(sym,SymbolInfoString(sym,SYMBOL_DESCRIPTION),SymbolInfoString(sym,SYMBOL_PATH));
   if(StringFind(key,"INDEX:")==0) return "equity-index macro, rates, earnings/sector, volatility and geopolitical sensitivity";
   if(StringFind(key,"METAL:")==0) return "USD, real/nominal yields, central-bank expectations, inflation, safe-haven and commodity-specific flows";
   if(StringFind(key,"ENERGY:")==0) return "oil/gas inventories, OPEC+, geopolitical supply, demand growth, USD and risk sentiment";
   if(StringFind(key,"FX:")==0) return "central banks, inflation, labor, GDP/PMI, rates/yields, political and currency-specific headlines";
   if(StringFind(key,"CRYPTO:")==0) return "liquidity, regulation, ETF/flow, risk sentiment, rates, USD and crypto-specific headlines";
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
