// ============================================================================
// GPT_EA Part 28B - R6 supplemental CI / runner / MT5 / soak evidence binding
// ============================================================================
// Supplemental fail-closed release evidence layered on top of Part28/Part29.
// REAL arming requires runner recovery + acceptance, executed CI provenance,
// MT5 validation evidence, and the five-day reconciled soak record.

input bool   InpReleaseRunnerRecoveryPassed             = false;
input string InpReleaseRunnerRecoverySchemaVersion      = "";
input string InpReleaseRunnerRecoveryEvidenceId         = "";
input string InpReleaseRunnerRecoveryDigest             = "";

input bool   InpReleaseRunnerRecoveryAcceptancePassed        = false;
input string InpReleaseRunnerRecoveryAcceptanceSchemaVersion = "";
input string InpReleaseRunnerRecoveryAcceptanceId            = "";
input string InpReleaseRunnerRecoveryAcceptanceDigest        = "";

input bool   InpReleaseCIStaticEvidencePassed           = false;
input string InpReleaseCISchemaVersion                  = "";
input long   InpReleaseCIRunId                          = 0;
input int    InpReleaseCIRunAttempt                     = 0;
input long   InpReleaseCIJobId                          = 0;
input long   InpReleaseCIRunnerId                       = 0;
input int    InpReleaseCIStepsExecuted                  = 0;
input string InpReleaseCIHeadSha                        = "";
input string InpReleaseCIEvidenceDigest                 = "";
input string InpReleaseCIConclusion                     = "";
input string InpReleaseCIArtifactName                   = "";
input bool   InpReleaseCIArtifactArchived               = false;
input bool   InpReleaseCIAttestationVerified            = false;
input string InpReleaseCIBundleSchemaVersion            = "";
input string InpReleaseCIBundleDigest                   = "";
input bool   InpReleaseCIBundleValidated                = false;

input bool   InpReleaseMT5ValidationPassed              = false;
input string InpReleaseMT5ValidationSchemaVersion       = "";
input string InpReleaseMT5ValidationEvidenceId          = "";
input string InpReleaseMT5ValidationDigest              = "";

input string InpReleaseSoakAcceptanceSchemaVersion      = "";
input string InpReleaseSoakAcceptanceRecordId           = "";
input string InpReleaseSoakAcceptanceRecordDigest       = "";

input bool   InpWriteR6SupplementalEvidenceSnapshot     = true;
input string InpR6SupplementalEvidenceSnapshotFile      = "GPT_EA_R6SupplementalEvidence.csv";

const string GPT_EA_REQUIRED_RUNNER_RECOVERY_SCHEMA       = "runner_recovery_evidence_v1";
const string GPT_EA_REQUIRED_RUNNER_ACCEPTANCE_SCHEMA     = "runner_recovery_acceptance_v1";
const string GPT_EA_REQUIRED_CI_SCHEMA_VERSION            = "github_actions_static_evidence_v1";
const string GPT_EA_REQUIRED_CI_BUNDLE_SCHEMA             = "ci_evidence_bundle_v1";
const string GPT_EA_REQUIRED_MT5_VALIDATION_SCHEMA        = "mt5_validation_evidence_v1";
const string GPT_EA_REQUIRED_SOAK_RECORD_SCHEMA           = "five_day_soak_acceptance_v2";

bool ReleaseRunnerRecoveryEvidenceAllows(string &why)
{
   why="";
   if(!InpReleaseRunnerRecoveryPassed)
   {
      why="GitHub hosted-runner recovery evidence has not been attested.";
      return false;
   }
   if(InpReleaseRunnerRecoverySchemaVersion!=GPT_EA_REQUIRED_RUNNER_RECOVERY_SCHEMA)
   {
      why="Runner-recovery evidence schema is missing or stale.";
      return false;
   }
   if(StringLen(InpReleaseRunnerRecoveryEvidenceId)<8)
   {
      why="Runner-recovery evidence ID is missing.";
      return false;
   }
   if(!ReleaseHexString(InpReleaseRunnerRecoveryDigest,64))
   {
      why="Runner-recovery evidence digest must be a 64-character SHA-256 value.";
      return false;
   }
   why="Hosted-runner recovery evidence PASS.";
   return true;
}

bool ReleaseRunnerRecoveryAcceptanceAllows(string &why)
{
   why="";
   if(!InpReleaseRunnerRecoveryAcceptancePassed)
   {
      why="Runner-recovery production acceptance matrix has not been attested.";
      return false;
   }
   if(InpReleaseRunnerRecoveryAcceptanceSchemaVersion!=GPT_EA_REQUIRED_RUNNER_ACCEPTANCE_SCHEMA)
   {
      why="Runner-recovery acceptance schema is missing or stale.";
      return false;
   }
   if(StringLen(InpReleaseRunnerRecoveryAcceptanceId)<8)
   {
      why="Runner-recovery acceptance ID is missing.";
      return false;
   }
   if(!ReleaseHexString(InpReleaseRunnerRecoveryAcceptanceDigest,64))
   {
      why="Runner-recovery acceptance digest must be a 64-character SHA-256 value.";
      return false;
   }
   why="Runner-recovery production acceptance matrix PASS.";
   return true;
}

bool ReleaseCIStaticEvidenceAllows(string &why)
{
   why="";
   if(!InpReleaseCIStaticEvidencePassed)
   {
      why="GitHub Actions static evidence has not been attested.";
      return false;
   }
   if(InpReleaseCISchemaVersion!=GPT_EA_REQUIRED_CI_SCHEMA_VERSION)
   {
      why="GitHub Actions evidence schema is missing or stale.";
      return false;
   }
   if(InpReleaseCIRunId<=0 || InpReleaseCIRunAttempt<=0 || InpReleaseCIJobId<=0 || InpReleaseCIRunnerId<=0)
   {
      why="GitHub Actions evidence must identify an executed run/attempt/job with runner_id > 0.";
      return false;
   }
   if(InpReleaseCIStepsExecuted<7)
   {
      why="GitHub Actions evidence shows too few executed workflow steps.";
      return false;
   }
   if(!ReleaseHexString(InpReleaseCIHeadSha,40) || InpReleaseCIHeadSha!=InpReleaseSourceCommitSha)
   {
      why="GitHub Actions head SHA is invalid or does not match the certified source commit.";
      return false;
   }
   if(!ReleaseHexString(InpReleaseCIEvidenceDigest,64))
   {
      why="GitHub Actions evidence digest must be a 64-character SHA-256 value.";
      return false;
   }
   if(InpReleaseCIConclusion!="success")
   {
      why="GitHub Actions conclusion must be literal success.";
      return false;
   }
   if(StringLen(InpReleaseCIArtifactName)<8 || !InpReleaseCIArtifactArchived)
   {
      why="GitHub Actions evidence artifact is missing or not archived.";
      return false;
   }
   if(!InpReleaseCIAttestationVerified)
   {
      why="GitHub artifact provenance attestation has not been verified.";
      return false;
   }
   if(InpReleaseCIBundleSchemaVersion!=GPT_EA_REQUIRED_CI_BUNDLE_SCHEMA)
   {
      why="GitHub Actions CI bundle schema is missing or stale.";
      return false;
   }
   if(!ReleaseHexString(InpReleaseCIBundleDigest,64) || !InpReleaseCIBundleValidated)
   {
      why="GitHub Actions final CI evidence bundle has not been validated with a valid SHA-256 digest.";
      return false;
   }
   why="Executed GitHub Actions static evidence, completed-job identity, archive, provenance attestation and final bundle PASS.";
   return true;
}

bool ReleaseMT5ValidationEvidenceAllows(string &why)
{
   why="";
   if(!InpReleaseMT5ValidationPassed)
   {
      why="MT5/MetaEditor validation evidence has not been attested.";
      return false;
   }
   if(InpReleaseMT5ValidationSchemaVersion!=GPT_EA_REQUIRED_MT5_VALIDATION_SCHEMA)
   {
      why="MT5 validation evidence schema is missing or stale.";
      return false;
   }
   if(StringLen(InpReleaseMT5ValidationEvidenceId)<8)
   {
      why="MT5 validation evidence ID is missing.";
      return false;
   }
   if(!ReleaseHexString(InpReleaseMT5ValidationDigest,64))
   {
      why="MT5 validation evidence digest must be a 64-character SHA-256 value.";
      return false;
   }
   why="MT5/MetaEditor compile, tester, broker-runtime, protection and live API evidence PASS.";
   return true;
}

bool ReleaseFiveDaySoakRecordAllows(string &why)
{
   why="";
   if(InpReleaseSoakAcceptanceSchemaVersion!=GPT_EA_REQUIRED_SOAK_RECORD_SCHEMA)
   {
      why="Five-day soak acceptance schema is missing or stale.";
      return false;
   }
   if(StringLen(InpReleaseSoakAcceptanceRecordId)<8)
   {
      why="Five-day soak acceptance record ID is missing.";
      return false;
   }
   if(!ReleaseHexString(InpReleaseSoakAcceptanceRecordDigest,64))
   {
      why="Five-day soak acceptance record digest must be a 64-character SHA-256 value.";
      return false;
   }
   why="Five-day soak acceptance v2 identity/digest structurally PASS.";
   return true;
}

bool ReleaseSupplementalR6EvidenceAllows(string &why)
{
   why="";
   if((bool)MQLInfoInteger(MQL_TESTER))
   {
      why="Strategy Tester: supplemental R6 release evidence is informational only.";
      return true;
   }
   ENUM_ACCOUNT_TRADE_MODE mode=(ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE);
   if(mode!=ACCOUNT_TRADE_MODE_REAL)
   {
      why="Demo/contest account: supplemental R6 release evidence is informational only.";
      return true;
   }

   string runner="";
   if(!ReleaseRunnerRecoveryEvidenceAllows(runner))
   {
      why="REAL account blocked: "+runner;
      return false;
   }
   string runnerAcceptance="";
   if(!ReleaseRunnerRecoveryAcceptanceAllows(runnerAcceptance))
   {
      why="REAL account blocked: "+runnerAcceptance;
      return false;
   }
   string ci="";
   if(!ReleaseCIStaticEvidenceAllows(ci))
   {
      why="REAL account blocked: "+ci;
      return false;
   }
   string mt5="";
   if(!ReleaseMT5ValidationEvidenceAllows(mt5))
   {
      why="REAL account blocked: "+mt5;
      return false;
   }
   string soak="";
   if(!ReleaseFiveDaySoakRecordAllows(soak))
   {
      why="REAL account blocked: "+soak;
      return false;
   }
   why=runner+" | "+runnerAcceptance+" | "+ci+" | "+mt5+" | "+soak;
   return true;
}

bool ReleaseSafetyAllowsR6Evidence(const string sym,string &why)
{
   string base="";
   if(!ReleaseSafetyAllowsR6(sym,base))
   {
      why=base;
      return false;
   }
   string supplemental="";
   if(!ReleaseSupplementalR6EvidenceAllows(supplemental))
   {
      why=supplemental;
      return false;
   }
   why=base+(base!=""?" | ":"")+supplemental;
   return true;
}

void RefreshR6EvidenceReleaseState()
{
   bool oldBlocked=g_releaseBlocked;
   string oldReason=g_releaseBlockReason;
   string why="";
   bool ok=ReleaseSafetyAllowsR6Evidence("",why);
   g_releaseBlocked=!ok;
   g_releaseBlockReason=(ok?"All R6 release and supplemental evidence gates pass.":why);
   if(g_releaseBlocked && (!oldBlocked || oldReason!=g_releaseBlockReason))
      Print("GPT_EA R6 EVIDENCE RELEASE BLOCK: ",g_releaseBlockReason);
   else if(!g_releaseBlocked && oldBlocked)
      Print("GPT_EA R6 EVIDENCE RELEASE GATE CLEARED.");
}

string ReleaseGateSummaryR6Evidence()
{
   string why="";
   return ReleaseSafetyAllowsR6Evidence("",why)?"PASS - "+why:"BLOCKED - "+why;
}

void WriteR6SupplementalEvidenceSnapshot()
{
   if(!InpWriteR6SupplementalEvidenceSnapshot || (bool)MQLInfoInteger(MQL_TESTER)) return;
   int h=FileOpen(InpR6SupplementalEvidenceSnapshotFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(h==INVALID_HANDLE) return;
   if(FileSize(h)==0)
      FileWrite(h,"time","required_release_id","source_commit",
         "runner_recovery_passed","runner_recovery_schema","runner_recovery_id","runner_recovery_digest",
         "runner_acceptance_passed","runner_acceptance_schema","runner_acceptance_id","runner_acceptance_digest",
         "ci_passed","ci_schema","ci_run_id","ci_run_attempt","ci_job_id","ci_runner_id","ci_steps","ci_head_sha","ci_digest",
         "ci_conclusion","ci_artifact","ci_artifact_archived","ci_attestation_verified","ci_bundle_schema","ci_bundle_digest","ci_bundle_validated",
         "mt5_validation_passed","mt5_validation_schema","mt5_validation_id","mt5_validation_digest",
         "soak_acceptance_schema","soak_record_id","soak_record_digest","gate_result","reason");
   FileSeek(h,0,SEEK_END);
   string why=""; bool ok=ReleaseSafetyAllowsR6Evidence("",why);
   FileWrite(h,TimeToString(TimeTradeServer(),TIME_DATE|TIME_SECONDS),GPT_EA_REQUIRED_RELEASE_VALIDATION_ID,InpReleaseSourceCommitSha,
      InpReleaseRunnerRecoveryPassed?"1":"0",InpReleaseRunnerRecoverySchemaVersion,InpReleaseRunnerRecoveryEvidenceId,InpReleaseRunnerRecoveryDigest,
      InpReleaseRunnerRecoveryAcceptancePassed?"1":"0",InpReleaseRunnerRecoveryAcceptanceSchemaVersion,InpReleaseRunnerRecoveryAcceptanceId,InpReleaseRunnerRecoveryAcceptanceDigest,
      InpReleaseCIStaticEvidencePassed?"1":"0",InpReleaseCISchemaVersion,(string)InpReleaseCIRunId,(string)InpReleaseCIRunAttempt,
      (string)InpReleaseCIJobId,(string)InpReleaseCIRunnerId,(string)InpReleaseCIStepsExecuted,InpReleaseCIHeadSha,InpReleaseCIEvidenceDigest,
      InpReleaseCIConclusion,InpReleaseCIArtifactName,InpReleaseCIArtifactArchived?"1":"0",InpReleaseCIAttestationVerified?"1":"0",
      InpReleaseCIBundleSchemaVersion,InpReleaseCIBundleDigest,InpReleaseCIBundleValidated?"1":"0",
      InpReleaseMT5ValidationPassed?"1":"0",InpReleaseMT5ValidationSchemaVersion,InpReleaseMT5ValidationEvidenceId,InpReleaseMT5ValidationDigest,
      InpReleaseSoakAcceptanceSchemaVersion,InpReleaseSoakAcceptanceRecordId,InpReleaseSoakAcceptanceRecordDigest,
      ok?"PASS":"BLOCK",why);
   FileFlush(h); FileClose(h);
}

void AdvancedSafetyInitR6Evidence()
{
   AdvancedSafetyInitR6();
   RefreshR6EvidenceReleaseState();
}

void AdvancedSafetyTimerR6Evidence()
{
   AdvancedSafetyTimerR6();
   RefreshR6EvidenceReleaseState();
}

void StopFailureObservabilityInitR6Evidence()
{
   StopFailureObservabilityInitR6();
   RefreshR6EvidenceReleaseState();
   WriteR6SupplementalEvidenceSnapshot();
}
