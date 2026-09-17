// ============================================================================
// GPT_EA Part 19 - Continuous intelligence scan scheduler
// ============================================================================

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
      for(int i=0;i<ArraySize(g_symbols);i++)
      {
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
