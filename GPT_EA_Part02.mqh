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
