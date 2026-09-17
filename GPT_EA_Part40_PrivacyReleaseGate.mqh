// ============================================================================
// GPT_EA Part 40 - Privacy sign-off release gate
// ============================================================================
// R10 privacy governance gate. This is a release/deployment sign-off layer,
// not a substitute for jurisdiction-specific legal/privacy advice.
//
// REAL-account new entries require a versioned, evidence-bound privacy sign-off
// for the customer's jurisdiction. Existing positions continue to be managed
// by the underlying R9/R8/R7 safety stack when this gate blocks new entries.

const string GPT_EA_PRIVACY_SIGNOFF_SCHEMA_VERSION = "gpt_ea_privacy_signoff_v1";

input bool   InpReleasePrivacySignoffPassed              = false;
input string InpReleasePrivacySignoffSchemaVersion       = "";
input string InpReleasePrivacySignoffId                  = "";
input string InpReleasePrivacySignoffDigest              = "";
input string InpReleasePrivacyReviewer                   = "";
input string InpReleasePrivacyReviewerRole               = "";
input string InpReleasePrivacySignedAt                   = "";
input string InpReleasePrivacyJurisdiction               = "";
input bool   InpReleasePrivacyDataInventoryApproved      = false;
input bool   InpReleasePrivacyRetentionApproved          = false;
input bool   InpReleasePrivacyCustomerNoticeApproved     = false;
input bool   InpReleasePrivacySecretHandlingApproved     = false;
input bool   InpReleasePrivacyCrossBorderApproved        = false;
input bool   InpReleasePrivacyDeletionWorkflowApproved   = false;
input bool   InpReleasePrivacyIncidentResponseApproved   = false;
input string InpReleasePrivacyTelemetryState             = ""; // DISABLED or APPROVED
input int    InpReleasePrivacyUnresolvedCriticalFindings = 0;
input bool   InpWritePrivacySignoffLog                   = true;
input string InpPrivacySignoffLogFile                    = "GPT_EA_PrivacyRelease.csv";

bool g_privacyPassLogged=false;

string PrivacyTrim(string value)
{
   StringTrimLeft(value);
   StringTrimRight(value);
   return value;
}

bool PrivacyHex64(const string value)
{
   if(StringLen(value)!=64) return false;
   const string hex="0123456789abcdefABCDEF";
   for(int i=0;i<64;i++)
   {
      string ch=StringSubstr(value,i,1);
      if(StringFind(hex,ch)<0) return false;
   }
   return true;
}

void WritePrivacySignoffEvent(const bool passed,const string reason)
{
   if(!InpWritePrivacySignoffLog || (bool)MQLInfoInteger(MQL_TESTER)) return;

   int h=FileOpen(InpPrivacySignoffLogFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(h==INVALID_HANDLE) return;

   if(FileSize(h)==0)
      FileWrite(h,"time","schema","signoff_id","jurisdiction","reviewer","reviewer_role","telemetry_state","critical_findings","state","reason");

   FileSeek(h,0,SEEK_END);
   FileWrite(h,
      TimeToString(TimeLocal(),TIME_DATE|TIME_SECONDS),
      PrivacyTrim(InpReleasePrivacySignoffSchemaVersion),
      PrivacyTrim(InpReleasePrivacySignoffId),
      PrivacyTrim(InpReleasePrivacyJurisdiction),
      PrivacyTrim(InpReleasePrivacyReviewer),
      PrivacyTrim(InpReleasePrivacyReviewerRole),
      PrivacyTrim(InpReleasePrivacyTelemetryState),
      IntegerToString(InpReleasePrivacyUnresolvedCriticalFindings),
      passed?"PASS":"BLOCK",
      reason
   );
   FileFlush(h);
   FileClose(h);
}

bool GPTPrivacySignoffAllows(string &why)
{
   why="";

   if((bool)MQLInfoInteger(MQL_TESTER))
   {
      why="Strategy Tester: privacy sign-off is informational only.";
      return true;
   }

   ENUM_ACCOUNT_TRADE_MODE mode=(ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE);
   if(mode!=ACCOUNT_TRADE_MODE_REAL)
   {
      why="Demo/contest: privacy sign-off is informational until REAL arming.";
      return true;
   }

   if(!InpReleasePrivacySignoffPassed)
   {
      why="REAL account blocked: privacy release sign-off has not been attested.";
      return false;
   }
   if(PrivacyTrim(InpReleasePrivacySignoffSchemaVersion)!=GPT_EA_PRIVACY_SIGNOFF_SCHEMA_VERSION)
   {
      why="REAL account blocked: privacy sign-off schema is missing or stale.";
      return false;
   }
   if(StringLen(PrivacyTrim(InpReleasePrivacySignoffId))<6)
   {
      why="REAL account blocked: privacy sign-off evidence ID is missing.";
      return false;
   }
   if(!PrivacyHex64(PrivacyTrim(InpReleasePrivacySignoffDigest)))
   {
      why="REAL account blocked: privacy sign-off digest must be a 64-character SHA-256 value.";
      return false;
   }
   if(StringLen(PrivacyTrim(InpReleasePrivacyReviewer))<2 ||
      StringLen(PrivacyTrim(InpReleasePrivacyReviewerRole))<2 ||
      StringLen(PrivacyTrim(InpReleasePrivacySignedAt))<8)
   {
      why="REAL account blocked: privacy reviewer identity/role/timestamp is incomplete.";
      return false;
   }

   string customerJurisdiction=PrivacyTrim(InpCustomerJurisdiction);
   string approvedJurisdiction=PrivacyTrim(InpReleasePrivacyJurisdiction);
   if(StringLen(approvedJurisdiction)<2 || approvedJurisdiction!=customerJurisdiction)
   {
      why="REAL account blocked: privacy sign-off jurisdiction does not match the customer jurisdiction.";
      return false;
   }

   if(!InpReleasePrivacyDataInventoryApproved ||
      !InpReleasePrivacyRetentionApproved ||
      !InpReleasePrivacyCustomerNoticeApproved ||
      !InpReleasePrivacySecretHandlingApproved ||
      !InpReleasePrivacyCrossBorderApproved ||
      !InpReleasePrivacyDeletionWorkflowApproved ||
      !InpReleasePrivacyIncidentResponseApproved)
   {
      why="REAL account blocked: one or more mandatory privacy controls are not approved.";
      return false;
   }

   string telemetry=PrivacyTrim(InpReleasePrivacyTelemetryState);
   if(telemetry!="DISABLED" && telemetry!="APPROVED")
   {
      why="REAL account blocked: privacy telemetry state must be DISABLED or APPROVED.";
      return false;
   }

   if(InpReleasePrivacyUnresolvedCriticalFindings!=0)
   {
      why="REAL account blocked: privacy review has unresolved critical findings.";
      return false;
   }

   why="Privacy sign-off PASS | schema="+GPT_EA_PRIVACY_SIGNOFF_SCHEMA_VERSION+
       " | jurisdiction="+approvedJurisdiction+" | telemetry="+telemetry;
   return true;
}

bool ReleaseSafetyAllowsR10Privacy(const string sym,string &why)
{
   string base="";
   if(!ReleaseSafetyAllowsR9CustomerAck(sym,base))
   {
      why=base;
      return false;
   }

   string privacy="";
   if(!GPTPrivacySignoffAllows(privacy))
   {
      why=privacy;
      return false;
   }

   why=base+(base!=""?" | ":"")+privacy;
   return true;
}

void RefreshR10PrivacyReleaseState()
{
   bool oldBlocked=g_releaseBlocked;
   string oldReason=g_releaseBlockReason;
   string why="";
   bool ok=ReleaseSafetyAllowsR10Privacy("",why);

   g_releaseBlocked=!ok;
   g_releaseBlockReason=(ok?"All R10 privacy/customer/legal/API/release gates pass.":why);

   if(g_releaseBlocked && (!oldBlocked || oldReason!=g_releaseBlockReason))
   {
      Print("GPT_EA R10 PRIVACY RELEASE BLOCK: ",g_releaseBlockReason);
      WritePrivacySignoffEvent(false,g_releaseBlockReason);
   }
   else if(!g_releaseBlocked && oldBlocked)
   {
      Print("GPT_EA R10 PRIVACY RELEASE GATE CLEARED.");
      if(!g_privacyPassLogged)
      {
         WritePrivacySignoffEvent(true,why);
         g_privacyPassLogged=true;
      }
   }
}

string ReleaseGateSummaryR10Privacy()
{
   string why="";
   return ReleaseSafetyAllowsR10Privacy("",why)?"PASS - "+why:"BLOCKED - "+why;
}

void AdvancedSafetyInitR10Privacy()
{
   AdvancedSafetyInitR9CustomerAck();
   RefreshR10PrivacyReleaseState();

   if(!g_privacyPassLogged &&
      (ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_REAL)
   {
      string why="";
      if(GPTPrivacySignoffAllows(why))
      {
         WritePrivacySignoffEvent(true,why);
         g_privacyPassLogged=true;
      }
   }
}

void AdvancedSafetyTimerR10Privacy()
{
   AdvancedSafetyTimerR9CustomerAck();
   RefreshR10PrivacyReleaseState();
}

void StopFailureObservabilityInitR10Privacy()
{
   StopFailureObservabilityInitR9CustomerAck();
   RefreshR10PrivacyReleaseState();
}
