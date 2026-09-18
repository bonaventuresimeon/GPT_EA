// ============================================================================
// GPT_EA Part 28 - Live release certification / evidence gate
// ============================================================================
// This gate does not replace testing. It prevents a REAL account from being
// armed unless the operator explicitly attests that the release evidence for
// the current release ID has been completed, validated and archived.

input bool   InpRequireReleaseEvidenceOnReal          = true;
input string InpReleaseValidationId                   = "";
input bool   InpReleaseMetaEditorCompilePassed        = false;
input bool   InpReleaseArtifactIdentityArchived       = false;
input bool   InpReleaseStrategyTesterPassed           = false;
input bool   InpReleaseIntelligenceMatrixPassed       = false;
input bool   InpReleaseAdaptivePortfolioPassed        = false;
input bool   InpReleaseExecutionLearningPassed        = false;
input bool   InpReleaseChampionChallengerPassed       = false;
input bool   InpReleaseLifecycleIntegrityPassed       = false;
input bool   InpReleaseBrokerMatrixPassed             = false;
input bool   InpReleaseDeploymentProfilePassed        = false;
input bool   InpReleaseRecoveryTestsPassed            = false;
input bool   InpReleaseStopMatrixPassed               = false;
input bool   InpReleaseBrokerStopPolicyPassed         = false;
input bool   InpReleasePartialProtectionPassed        = false;
input bool   InpReleaseStopObservabilityPassed        = false;
input bool   InpReleaseLiveNewsIntermarketPassed      = false;
input bool   InpReleaseWebFailureInjectionPassed      = false;
input bool   InpReleaseDemoSoakPassed                 = false;
input bool   InpReleaseOperatorReviewPassed           = false;

// Concrete compile/artifact identity.
input string InpReleaseSourceCommitSha                = "";
input string InpReleaseEx5Sha256                      = "";
input string InpReleaseSetSha256                      = ""; // 64 hex or literal NONE
input string InpReleaseCompileEvidenceId              = "";
input string InpReleaseMetaEditorBuild                = "";
input string InpReleaseMT5Build                       = "";

// Versioned demo-soak evidence.
input string InpReleaseSoakSchemaVersion              = "";
input string InpReleaseSoakEvidenceId                 = "";
input string InpReleaseSoakEvidenceDigest             = "";
input int    InpReleaseSoakTradingDays                = 0;
input int    InpReleaseSoakLondonSessions             = 0;
input int    InpReleaseSoakNYSessions                 = 0;
input bool   InpReleaseSoakOverlapObserved            = false;
input bool   InpReleaseSoakNewsDayObserved            = false;
input bool   InpReleaseSoakRolloverObserved           = false;
input bool   InpReleaseSoakRestartObserved            = false;
input bool   InpReleaseSoakReconnectObserved          = false;
input int    InpReleaseSoakScheduledScans             = 0;
input int    InpReleaseSoakContinuousScans            = 0;
input int    InpReleaseSoakCheckpointUpdates          = 0;
input int    InpReleaseSoakBackupCheckpointUpdates    = 0;
input int    InpReleaseSoakZeroToleranceFailures      = 0;
input int    InpReleaseSoakUnresolvedCriticalStates   = 0;
input int    InpReleaseSoakDuplicateOrders            = 0;
input int    InpReleaseSoakDuplicatePartials          = 0;
input int    InpReleaseSoakSLRegressions              = 0;
input int    InpReleaseSoakUnprotectedAuthorizations  = 0;
input int    InpReleaseSoakReleaseGateBypasses        = 0;
input int    InpReleaseSoakAnalyticsDuplicateFinal    = 0;
input int    InpReleaseSoakStopJoinFailures           = 0;
input int    InpReleaseSoakDashboardMismatches        = 0;
input int    InpReleaseSoakRuntimeCriticalErrors      = 0;
input int    InpReleaseSoakSecretsExposed             = 0;
input bool   InpReleaseSoakExecutionLogPresent        = false;
input bool   InpReleaseSoakStopLogPresent             = false;
input bool   InpReleaseSoakReleaseLogPresent          = false;

// Final GO/NO-GO review identity.
input string InpReleaseFinalReviewEvidenceId          = "";
input string InpReleaseFinalReviewDigest              = "";
input string InpReleaseFinalDecision                  = ""; // must be GO
input string InpReleaseFinalReviewer                  = "";
input string InpReleaseFinalReviewTimestamp           = "";

input bool   InpWriteReleaseEvidenceSnapshot          = true;
input string InpReleaseEvidenceSnapshotFile           = "GPT_EA_ReleaseEvidence.csv";

const string GPT_EA_REQUIRED_RELEASE_VALIDATION_ID = "GPT_EA_FULL_INTELLIGENCE_R6_20260917";
const string GPT_EA_REQUIRED_SOAK_SCHEMA_VERSION   = "demo_soak_evidence_v1";

bool ReleaseHexString(const string value,const int expectedLen)
{
   if(StringLen(value)!=expectedLen) return false;
   const string hex="0123456789abcdefABCDEF";
   for(int i=0;i<expectedLen;i++)
   {
      string ch=StringSubstr(value,i,1);
      if(StringFind(hex,ch)<0) return false;
   }
   return true;
}

bool ReleaseArtifactIdentityAllows(string &why)
{
   why="";
   if(!InpReleaseArtifactIdentityArchived)
   {
      why="Artifact identity has not been archived.";
      return false;
   }
   if(!ReleaseHexString(InpReleaseSourceCommitSha,40))
   {
      why="Source commit SHA must be an exact 40-character hexadecimal Git commit.";
      return false;
   }
   if(!ReleaseHexString(InpReleaseEx5Sha256,64))
   {
      why="EX5 SHA-256 must be an exact 64-character hexadecimal digest.";
      return false;
   }
   if(InpReleaseSetSha256!="NONE" && !ReleaseHexString(InpReleaseSetSha256,64))
   {
      why="SET SHA-256 must be 64 hexadecimal characters or literal NONE.";
      return false;
   }
   if(StringLen(InpReleaseCompileEvidenceId)<4)
   {
      why="Compile evidence ID/reference is missing.";
      return false;
   }
   if(StringLen(InpReleaseMetaEditorBuild)<1 || StringLen(InpReleaseMT5Build)<1)
   {
      why="MetaEditor/MT5 build identity is incomplete.";
      return false;
   }
   why="Artifact identity fields are structurally valid.";
   return true;
}

bool ReleaseDemoSoakEvidenceAllows(string &why)
{
   why="";
   if(!InpReleaseDemoSoakPassed)
   {
      why="Demo-soak acceptance has not been attested.";
      return false;
   }
   if(InpReleaseSoakSchemaVersion!=GPT_EA_REQUIRED_SOAK_SCHEMA_VERSION)
   {
      why="Demo-soak schema version is missing or stale.";
      return false;
   }
   if(StringLen(InpReleaseSoakEvidenceId)<4)
   {
      why="Demo-soak evidence ID/reference is missing.";
      return false;
   }
   if(!ReleaseHexString(InpReleaseSoakEvidenceDigest,64))
   {
      why="Demo-soak evidence digest must be a 64-character SHA-256 value.";
      return false;
   }
   if(InpReleaseSoakTradingDays<5)
   {
      why="Demo soak requires at least 5 consecutive trading days.";
      return false;
   }
   if(InpReleaseSoakLondonSessions<3 || InpReleaseSoakNYSessions<3)
   {
      why="Demo soak requires at least 3 London and 3 New York/U.S. cash sessions.";
      return false;
   }
   if(!InpReleaseSoakOverlapObserved || !InpReleaseSoakNewsDayObserved || !InpReleaseSoakRolloverObserved ||
      !InpReleaseSoakRestartObserved || !InpReleaseSoakReconnectObserved)
   {
      why="Demo soak is missing overlap/news/rollover/restart/reconnect coverage.";
      return false;
   }
   if(InpReleaseSoakScheduledScans<1 || InpReleaseSoakContinuousScans<1)
   {
      why="Demo soak must observe both scheduled and continuous scanning.";
      return false;
   }
   if(InpReleaseSoakCheckpointUpdates<1 || InpReleaseSoakBackupCheckpointUpdates<1)
   {
      why="Demo soak must observe primary and backup recovery checkpoint updates.";
      return false;
   }
   if(InpReleaseSoakZeroToleranceFailures!=0 || InpReleaseSoakUnresolvedCriticalStates!=0 ||
      InpReleaseSoakDuplicateOrders!=0 || InpReleaseSoakDuplicatePartials!=0 || InpReleaseSoakSLRegressions!=0 ||
      InpReleaseSoakUnprotectedAuthorizations!=0 || InpReleaseSoakReleaseGateBypasses!=0 ||
      InpReleaseSoakAnalyticsDuplicateFinal!=0 || InpReleaseSoakStopJoinFailures!=0 ||
      InpReleaseSoakDashboardMismatches!=0 || InpReleaseSoakRuntimeCriticalErrors!=0 || InpReleaseSoakSecretsExposed!=0)
   {
      why="Demo soak contains a non-zero zero-tolerance, critical, duplicate, protection, release, analytics, observability, runtime or secret-exposure count.";
      return false;
   }
   if(!InpReleaseSoakExecutionLogPresent || !InpReleaseSoakStopLogPresent || !InpReleaseSoakReleaseLogPresent)
   {
      why="Demo soak is missing required execution/stop/release evidence logs.";
      return false;
   }
   why="Demo-soak schema and quantitative acceptance fields pass.";
   return true;
}

bool ReleaseFinalReviewAllows(string &why)
{
   why="";
   if(!InpReleaseOperatorReviewPassed)
   {
      why="Final operator release review has not been attested.";
      return false;
   }
   if(StringLen(InpReleaseFinalReviewEvidenceId)<4)
   {
      why="Final GO/NO-GO review evidence ID is missing.";
      return false;
   }
   if(!ReleaseHexString(InpReleaseFinalReviewDigest,64))
   {
      why="Final review digest must be a 64-character SHA-256 value.";
      return false;
   }
   if(InpReleaseFinalDecision!="GO")
   {
      why="Final release decision must be literal GO.";
      return false;
   }
   if(StringLen(InpReleaseFinalReviewer)<2 || StringLen(InpReleaseFinalReviewTimestamp)<8)
   {
      why="Final reviewer identity/timestamp is incomplete.";
      return false;
   }
   why="Final GO/NO-GO review identity is structurally valid.";
   return true;
}

bool ReleaseEvidenceAllows(string &why)
{
   why="";
   if(!InpRequireReleaseEvidenceOnReal)
   {
      why="Release-evidence gate disabled by input.";
      return true;
   }
   if((bool)MQLInfoInteger(MQL_TESTER))
   {
      why="Strategy Tester: release-evidence attestation not required.";
      return true;
   }
   ENUM_ACCOUNT_TRADE_MODE mode=(ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE);
   if(mode!=ACCOUNT_TRADE_MODE_REAL)
   {
      why="Demo/contest account: release-evidence attestation is informational only.";
      return true;
   }

   if(InpReleaseValidationId!=GPT_EA_REQUIRED_RELEASE_VALIDATION_ID)
   {
      why="REAL account blocked: release validation ID is missing or stale.";
      return false;
   }
   if(!InpReleaseMetaEditorCompilePassed){ why="REAL account blocked: MetaEditor compile gate has not been attested."; return false; }

   string artifactWhy="";
   if(!ReleaseArtifactIdentityAllows(artifactWhy))
   {
      why="REAL account blocked: "+artifactWhy;
      return false;
   }

   if(!InpReleaseStrategyTesterPassed){ why="REAL account blocked: Strategy Tester validation has not been attested."; return false; }
   if(!InpReleaseIntelligenceMatrixPassed){ why="REAL account blocked: full-intelligence matrix has not been attested."; return false; }
   if(!InpReleaseAdaptivePortfolioPassed){ why="REAL account blocked: adaptive portfolio/risk-supervisor matrix has not been attested."; return false; }
   if(!InpReleaseExecutionLearningPassed){ why="REAL account blocked: execution-learning matrix has not been attested."; return false; }
   if(!InpReleaseChampionChallengerPassed){ why="REAL account blocked: champion/challenger validation has not been attested."; return false; }
   if(!InpReleaseLifecycleIntegrityPassed){ why="REAL account blocked: lifecycle/integrity/replay validation has not been attested."; return false; }
   if(!InpReleaseBrokerMatrixPassed){ why="REAL account blocked: broker/account/symbol matrix has not been attested."; return false; }
   if(!InpReleaseDeploymentProfilePassed){ why="REAL account blocked: deployment profile/drift validation has not been attested."; return false; }
   if(!InpReleaseRecoveryTestsPassed){ why="REAL account blocked: restart/recovery tests have not been attested."; return false; }
   if(!InpReleaseStopMatrixPassed){ why="REAL account blocked: HIGH-priority stop-management matrix has not been attested."; return false; }
   if(!InpReleaseBrokerStopPolicyPassed){ why="REAL account blocked: broker-specific stop policy tests have not been attested."; return false; }
   if(!InpReleasePartialProtectionPassed){ why="REAL account blocked: partial-protection release test has not been attested."; return false; }
   if(!InpReleaseStopObservabilityPassed){ why="REAL account blocked: stop observability validation has not been attested."; return false; }
   if(!InpReleaseLiveNewsIntermarketPassed){ why="REAL account blocked: live news/intermarket validation has not been attested."; return false; }
   if(!InpReleaseWebFailureInjectionPassed){ why="REAL account blocked: OpenAI/WebRequest failure-injection has not been attested."; return false; }

   string soakWhy="";
   if(!ReleaseDemoSoakEvidenceAllows(soakWhy))
   {
      why="REAL account blocked: "+soakWhy;
      return false;
   }

   string reviewWhy="";
   if(!ReleaseFinalReviewAllows(reviewWhy))
   {
      why="REAL account blocked: "+reviewWhy;
      return false;
   }

   why="Release evidence attested for "+GPT_EA_REQUIRED_RELEASE_VALIDATION_ID+" | "+artifactWhy+" | "+soakWhy+" | "+reviewWhy;
   return true;
}

bool ReleaseSafetyAllowsCertified(const string sym,string &why)
{
   string base="";
   if(!ReleaseSafetyAllows(sym,base))
   {
      why=base;
      return false;
   }

   string stopHealth="";
   if(!StopObservabilityAllowsNewEntries(stopHealth))
   {
      why="Stop-health release gate failed: "+stopHealth;
      return false;
   }

   string evidence="";
   if(!ReleaseEvidenceAllows(evidence))
   {
      why=evidence;
      return false;
   }
   why=base+(base!=""?" | ":"")+stopHealth+(stopHealth!=""?" | ":"")+evidence;
   return true;
}

void RefreshCertifiedReleaseState()
{
   bool oldBlocked=g_releaseBlocked;
   string oldReason=g_releaseBlockReason;
   string why="";
   bool ok=ReleaseSafetyAllowsCertified("",why);
   g_releaseBlocked=!ok;
   g_releaseBlockReason=(ok?"All certified release gates pass.":why);
   if(g_releaseBlocked && (!oldBlocked || oldReason!=g_releaseBlockReason))
      Print("GPT_EA CERTIFIED RELEASE BLOCK: ",g_releaseBlockReason);
   else if(!g_releaseBlocked && oldBlocked)
      Print("GPT_EA CERTIFIED RELEASE GATE CLEARED.");
}

string ReleaseGateSummaryCertified()
{
   string why="";
   if(!ReleaseSafetyAllowsCertified("",why)) return "BLOCKED - "+why;
   return "PASS - "+why;
}

void WriteReleaseEvidenceSnapshot()
{
   if(!InpWriteReleaseEvidenceSnapshot || (bool)MQLInfoInteger(MQL_TESTER)) return;
   int h=FileOpen(InpReleaseEvidenceSnapshotFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(h==INVALID_HANDLE)
   {
      Print("Release evidence snapshot open failed: ",GetLastError());
      return;
   }
   if(FileSize(h)==0)
      FileWrite(h,"time","required_release_id","entered_release_id","account_mode","broker","server",
         "source_commit","ex5_sha256","set_sha256","compile_evidence_id","metaeditor_build","mt5_build",
         "compile","artifact_identity","strategy_tester","intelligence_matrix","adaptive_portfolio","execution_learning","champion_challenger","lifecycle_integrity",
         "broker_matrix","deployment_profile","recovery","stop_matrix","broker_stop_policy","partial_protection","stop_observability","live_news_intermarket",
         "web_failure_injection","demo_soak","soak_schema","soak_evidence_id","soak_digest","soak_trading_days","soak_london_sessions","soak_ny_sessions",
         "soak_overlap","soak_news_day","soak_rollover","soak_restart","soak_reconnect","soak_scheduled_scans","soak_continuous_scans",
         "soak_checkpoint_updates","soak_backup_updates","soak_zero_tolerance_failures","soak_unresolved_critical","soak_duplicate_orders","soak_duplicate_partials",
         "soak_sl_regressions","soak_unprotected_authorizations","soak_gate_bypasses","soak_analytics_duplicate_final","soak_stop_join_failures",
         "soak_dashboard_mismatches","soak_runtime_critical_errors","soak_secrets_exposed","soak_execution_log","soak_stop_log","soak_release_log",
         "operator_review","final_review_id","final_review_digest","final_decision","final_reviewer","final_review_timestamp","gate_result","reason");
   FileSeek(h,0,SEEK_END);
   string why=""; bool ok=ReleaseSafetyAllowsCertified("",why);
   FileWrite(h,TimeToString(TimeTradeServer(),TIME_DATE|TIME_SECONDS),GPT_EA_REQUIRED_RELEASE_VALIDATION_ID,InpReleaseValidationId,
      (string)AccountInfoInteger(ACCOUNT_TRADE_MODE),AccountInfoString(ACCOUNT_COMPANY),AccountInfoString(ACCOUNT_SERVER),
      InpReleaseSourceCommitSha,InpReleaseEx5Sha256,InpReleaseSetSha256,InpReleaseCompileEvidenceId,InpReleaseMetaEditorBuild,InpReleaseMT5Build,
      InpReleaseMetaEditorCompilePassed?"1":"0",InpReleaseArtifactIdentityArchived?"1":"0",InpReleaseStrategyTesterPassed?"1":"0",
      InpReleaseIntelligenceMatrixPassed?"1":"0",InpReleaseAdaptivePortfolioPassed?"1":"0",InpReleaseExecutionLearningPassed?"1":"0",
      InpReleaseChampionChallengerPassed?"1":"0",InpReleaseLifecycleIntegrityPassed?"1":"0",InpReleaseBrokerMatrixPassed?"1":"0",
      InpReleaseDeploymentProfilePassed?"1":"0",InpReleaseRecoveryTestsPassed?"1":"0",InpReleaseStopMatrixPassed?"1":"0",
      InpReleaseBrokerStopPolicyPassed?"1":"0",InpReleasePartialProtectionPassed?"1":"0",InpReleaseStopObservabilityPassed?"1":"0",
      InpReleaseLiveNewsIntermarketPassed?"1":"0",InpReleaseWebFailureInjectionPassed?"1":"0",InpReleaseDemoSoakPassed?"1":"0",
      InpReleaseSoakSchemaVersion,InpReleaseSoakEvidenceId,InpReleaseSoakEvidenceDigest,(string)InpReleaseSoakTradingDays,
      (string)InpReleaseSoakLondonSessions,(string)InpReleaseSoakNYSessions,InpReleaseSoakOverlapObserved?"1":"0",
      InpReleaseSoakNewsDayObserved?"1":"0",InpReleaseSoakRolloverObserved?"1":"0",InpReleaseSoakRestartObserved?"1":"0",
      InpReleaseSoakReconnectObserved?"1":"0",(string)InpReleaseSoakScheduledScans,(string)InpReleaseSoakContinuousScans,
      (string)InpReleaseSoakCheckpointUpdates,(string)InpReleaseSoakBackupCheckpointUpdates,(string)InpReleaseSoakZeroToleranceFailures,
      (string)InpReleaseSoakUnresolvedCriticalStates,(string)InpReleaseSoakDuplicateOrders,(string)InpReleaseSoakDuplicatePartials,
      (string)InpReleaseSoakSLRegressions,(string)InpReleaseSoakUnprotectedAuthorizations,(string)InpReleaseSoakReleaseGateBypasses,
      (string)InpReleaseSoakAnalyticsDuplicateFinal,(string)InpReleaseSoakStopJoinFailures,(string)InpReleaseSoakDashboardMismatches,
      (string)InpReleaseSoakRuntimeCriticalErrors,(string)InpReleaseSoakSecretsExposed,InpReleaseSoakExecutionLogPresent?"1":"0",
      InpReleaseSoakStopLogPresent?"1":"0",InpReleaseSoakReleaseLogPresent?"1":"0",InpReleaseOperatorReviewPassed?"1":"0",
      InpReleaseFinalReviewEvidenceId,InpReleaseFinalReviewDigest,InpReleaseFinalDecision,InpReleaseFinalReviewer,InpReleaseFinalReviewTimestamp,
      ok?"PASS":"BLOCK",why);
   FileFlush(h); FileClose(h);
}

void ReleaseCertificationInit()
{
   RefreshCertifiedReleaseState();
   WriteReleaseEvidenceSnapshot();
   Print("GPT_EA release certification: ",g_releaseBlocked?"BLOCK - ":"PASS - ",g_releaseBlockReason);
}

void AdvancedSafetyInitCertified()
{
   AdvancedSafetyInit();
   RefreshCertifiedReleaseState();
}

void AdvancedSafetyTimerCertified()
{
   AdvancedSafetyTimer();
   RefreshCertifiedReleaseState();
}

void StopFailureObservabilityInitCertified()
{
   StopFailureObservabilityInit();
   ReleaseCertificationInit();
}
