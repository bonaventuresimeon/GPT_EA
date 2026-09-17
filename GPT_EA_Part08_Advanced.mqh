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
