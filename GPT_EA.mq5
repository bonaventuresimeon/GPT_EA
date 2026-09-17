// GPT_EA standalone MetaTrader 5 entry file
#include "GPT_EA_Part01.mqh"
#include "GPT_EA_Part02.mqh"
#include "GPT_EA_Part03.mqh"
#include "GPT_EA_Part04.mqh"
#include "GPT_EA_Part08_Advanced.mqh"
#include "GPT_EA_Part09_RiskRecoveryAnalytics.mqh"
#include "GPT_EA_Part10_BrokerUniversalRecovery.mqh"
#include "GPT_EA_Part11_PreflightRecoveryGuard.mqh"
#include "GPT_EA_Part00_ForwardDeclarations.mqh"
#include "GPT_EA_Part12_SafetyStopManagement.mqh"
#include "GPT_EA_Part14_StopFailurePolicy.mqh"
#include "GPT_EA_Part18_StopBrokerObservability.mqh"
#include "GPT_EA_Part28_ReleaseCertification.mqh"
#include "GPT_EA_Part29_DeploymentDriftGuard.mqh"
#include "GPT_EA_Part28B_CIReleaseEvidence.mqh"
#include "GPT_EA_Part37A_APICompat.mqh"
#define Trim APITrim
#include "GPT_EA_Part37_APITransport.mqh"
#undef Trim
#include "GPT_EA_Part38_LegalLicenseGate.mqh"
#include "GPT_EA_Part39_CustomerRiskAcknowledgement.mqh"
#define ReleaseSafetyAllows ReleaseSafetyAllowsR9CustomerAck
#define ReleaseGateSummary ReleaseGateSummaryR9CustomerAck
#define StopFailureObservabilityInit StopFailureObservabilityInitR9CustomerAck
#define AdvancedSafetyInit AdvancedSafetyInitR9CustomerAck
#define AdvancedSafetyTimer AdvancedSafetyTimerR9CustomerAck
#include "GPT_EA_Part15_StrategyIntelligence.mqh"
#include "GPT_EA_Part15B_StrategyFrameworks.mqh"
#include "GPT_EA_Part15C_StrategyContextAnalytics.mqh"
#include "GPT_EA_Part20_RealisticCostModel.mqh"
#include "GPT_EA_Part15D_StructureTargets.mqh"
#include "GPT_EA_Part21_ResearchValidation.mqh"
#include "GPT_EA_Part24_SessionStrategyHardening.mqh"
#include "GPT_EA_Part27_StrategyCompletion.mqh"
#include "GPT_EA_Part19_ContinuousIntelligence.mqh"
#define SelectDynamicStrategy SelectDynamicStrategyUltimate
#define PersistStrategyPlanForExecution PersistStrategyPlanForExecutionAccurate
#define StrategyIntelligenceInit StrategyIntelligenceInitFull
#define StrategyIntelligenceTimer StrategyIntelligenceTimerFull
#define EffectiveRRDynamic EffectiveRRFullRatio
#define ScheduledScanDue ScheduledOrContinuousScanDue

// Route all active OpenAI/news WebRequest calls through the R7 transport layer.
// In PROXY mode the legacy key check receives only a harmless local marker; the
// generated bearer header is then discarded before the proxy network request.
#define InpOpenAIAPIKey APITransportLegacyCredential()
#define WebRequest GPTAPIWebRequest
#include "GPT_EA_Part16_NewsIntermarket.mqh"
#include "GPT_EA_Part22A_IntermarketForward.mqh"
#include "GPT_EA_Part22P_ResponseParser.mqh"
#define AssessIntermarket AssessIntermarketHardened
#define ExtractOpenAIText ExtractOpenAITextWide
#include "GPT_EA_Part22_IntelligenceFreshness.mqh"
#undef ExtractOpenAIText
#define GetLiveWebIntel GetLiveWebIntelHardened
#include "GPT_EA_Part16A_StrictRevalidation.mqh"
#define PreEntryIntelligenceRevalidation PreEntryIntelligenceRevalidationStrict
#include "GPT_EA_Part17_ThesisEngine.mqh"
#include "GPT_EA_Part25_ThesisHardening.mqh"
#define ExtractOpenAIText ExtractOpenAITextWide
#include "GPT_EA_Part26_DeepGPTPolicy.mqh"
#undef ExtractOpenAIText
#undef WebRequest
#undef InpOpenAIAPIKey

// Adaptive execution, portfolio risk, shadow validation, lifecycle, demo-soak evidence and dashboard stack.
#include "GPT_EA_Part30_AdaptiveRiskPortfolio.mqh"
#include "GPT_EA_Part31_ExecutionLearning.mqh"
#include "GPT_EA_Part31A_RegimeSizing.mqh"
#include "GPT_EA_Part31B_ExecutionFinalizer.mqh"
#include "GPT_EA_Part32_ChampionChallenger.mqh"
#include "GPT_EA_Part33_LifecycleIntegrityReplay.mqh"
#include "GPT_EA_Part34_StrategyHealthDashboard.mqh"
#include "GPT_EA_Part36_DemoSoakEvidence.mqh"
#include "GPT_EA_Part35_AdaptiveIntegration.mqh"

// Part05 order execution consumes final adaptive sizing and learned slippage.
#define LotSizeForRisk AdaptiveLotSizeForRiskFinal
#define AdaptiveLotSizeForRisk AdaptiveLotSizeForRiskFinal
#define DynamicSlippagePoints AdaptiveExecutionSlippagePointsR5
#include "GPT_EA_Part05.mqh"
#undef DynamicSlippagePoints
#undef AdaptiveLotSizeForRisk
#undef LotSizeForRisk

#include "GPT_EA_Part23_IntelligenceObservability.mqh"
#include "GPT_EA_Part06.mqh"
#include "GPT_EA_Part13_AdvancedPositionManager.mqh"

// Scanner/approval path uses the adaptive execution wrappers while older modules retain
// their original deterministic functions.
#undef SelectDynamicStrategy
#define SelectDynamicStrategy SelectDynamicStrategyR5
#define CallOpenAI CallOpenAIDeep
#define NotifyCard NotifyCardR5
#define BuildMandatory25PointThesis BuildMandatory25PointThesisFinal
#define PreAuthorizationRiskAllows AdaptivePreAuthorizationRiskAllowsR5
#define LotSizeForRisk AdaptiveLotSizeForRiskFinal
#define DynamicSlippagePoints AdaptiveExecutionSlippagePointsR5
#define AIReviewAllowsExecution AIReviewAllowsExecutionR5
#define MarkSignalCooldown MarkSignalCooldownR5
#define NewsIntermarketInit NewsIntermarketInitR5
#define NewsIntermarketTimer NewsIntermarketTimerR5
#define DeleteAdvancedDashboard DeleteAdvancedDashboardR5
#include "GPT_EA_Part07.mqh"
#undef DeleteAdvancedDashboard
#undef NewsIntermarketTimer
#undef NewsIntermarketInit
#undef MarkSignalCooldown
#undef AIReviewAllowsExecution
#undef DynamicSlippagePoints
#undef LotSizeForRisk
#undef PreAuthorizationRiskAllows
#undef BuildMandatory25PointThesis
#undef NotifyCard
#undef CallOpenAI
#undef PreEntryIntelligenceRevalidation
#undef GetLiveWebIntel
#undef AssessIntermarket
#undef ScheduledScanDue
#undef EffectiveRRDynamic
#undef StrategyIntelligenceTimer
#undef StrategyIntelligenceInit
#undef PersistStrategyPlanForExecution
#undef SelectDynamicStrategy
#undef AdvancedSafetyTimer
#undef AdvancedSafetyInit
#undef StopFailureObservabilityInit
#undef ReleaseGateSummary
#undef ReleaseSafetyAllows
