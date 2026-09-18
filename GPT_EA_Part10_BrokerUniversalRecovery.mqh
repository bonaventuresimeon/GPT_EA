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
