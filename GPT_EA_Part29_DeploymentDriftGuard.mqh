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

bool ReleaseSafetyAllowsR4(const string sym,string &why)
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

void RefreshR4ReleaseState()
{
   bool oldBlocked=g_releaseBlocked;
   string oldReason=g_releaseBlockReason;
   string why="";
   bool ok=ReleaseSafetyAllowsR4("",why);
   g_deploymentDriftBlocked=!ok && StringFind(why,"Deployment drift gate failed")>=0;
   g_deploymentDriftReason=(g_deploymentDriftBlocked?why:"Deployment drift gate clear.");
   g_releaseBlocked=!ok;
   g_releaseBlockReason=(ok?"All R4 release gates pass.":why);
   if(g_releaseBlocked && (!oldBlocked || oldReason!=g_releaseBlockReason))
      Print("GPT_EA R4 RELEASE BLOCK: ",g_releaseBlockReason);
   else if(!g_releaseBlocked && oldBlocked)
      Print("GPT_EA R4 RELEASE GATE CLEARED.");
}

string ReleaseGateSummaryR4()
{
   string why="";
   return ReleaseSafetyAllowsR4("",why)?"PASS - "+why:"BLOCKED - "+why;
}

void AdvancedSafetyInitR4()
{
   AdvancedSafetyInitCertified();
   CaptureDeploymentBaseline();
   RefreshR4ReleaseState();
}

void AdvancedSafetyTimerR4()
{
   AdvancedSafetyTimerCertified();
   RefreshR4ReleaseState();
}

void StopFailureObservabilityInitR4()
{
   StopFailureObservabilityInit();
   ReleaseCertificationInit();
   if(ArraySize(g_deploymentBaseline)==0) CaptureDeploymentBaseline();
   RefreshR4ReleaseState();
}

void DeploymentDriftGuardInit()
{
   if(ArraySize(g_deploymentBaseline)==0) CaptureDeploymentBaseline();
   RefreshR4ReleaseState();
   Print("GPT_EA deployment drift guard: ",g_deploymentDriftBlocked?"BLOCK - ":"PASS - ",g_deploymentDriftReason);
}
