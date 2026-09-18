// ============================================================================
// GPT_EA Part 38 - Commercial license / legal acknowledgement release gate
// ============================================================================
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
