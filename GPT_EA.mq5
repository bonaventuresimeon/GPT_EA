// GPT_EA standalone MetaTrader 5 entry file
#include "GPT_EA_Part01.mqh"
#include "GPT_EA_Part02.mqh"
#include "GPT_EA_Part03.mqh"
#include "GPT_EA_Part04.mqh"
#include "GPT_EA_Part08_Advanced.mqh"
#include "GPT_EA_Part09_RiskRecoveryAnalytics.mqh"
#include "GPT_EA_Part10_BrokerUniversalRecovery.mqh"
#include "GPT_EA_Part11_PreflightRecoveryGuard.mqh"
#include "GPT_EA_Part12_SafetyStopManagement.mqh"
#include "GPT_EA_Part00_ForwardDeclarations.mqh"
#include "GPT_EA_Part14_StopFailurePolicy.mqh"
#include "GPT_EA_Part18_StopBrokerObservability.mqh"
#include "GPT_EA_Part15_StrategyIntelligence.mqh"
#include "GPT_EA_Part15B_StrategyFrameworks.mqh"
#include "GPT_EA_Part15C_StrategyContextAnalytics.mqh"
#include "GPT_EA_Part20_RealisticCostModel.mqh"
#include "GPT_EA_Part15D_StructureTargets.mqh"
#include "GPT_EA_Part21_ResearchValidation.mqh"
#include "GPT_EA_Part19_ContinuousIntelligence.mqh"
#define SelectDynamicStrategy SelectDynamicStrategyResearch
#define PersistStrategyPlanForExecution PersistStrategyPlanForExecutionFull
#define StrategyIntelligenceInit StrategyIntelligenceInitFull
#define StrategyIntelligenceTimer StrategyIntelligenceTimerFull
#define EffectiveRRDynamic EffectiveRRFullRatio
#define ScheduledScanDue ScheduledOrContinuousScanDue
#include "GPT_EA_Part16_NewsIntermarket.mqh"
#include "GPT_EA_Part22_IntelligenceFreshness.mqh"
#define GetLiveWebIntel GetLiveWebIntelHardened
#define AssessIntermarket AssessIntermarketHardened
#include "GPT_EA_Part16A_StrictRevalidation.mqh"
#define PreEntryIntelligenceRevalidation PreEntryIntelligenceRevalidationStrict
#include "GPT_EA_Part17_ThesisEngine.mqh"
#include "GPT_EA_Part05.mqh"
#include "GPT_EA_Part06.mqh"
#include "GPT_EA_Part13_AdvancedPositionManager.mqh"
#include "GPT_EA_Part07.mqh"
#undef PreEntryIntelligenceRevalidation
#undef AssessIntermarket
#undef GetLiveWebIntel
#undef ScheduledScanDue
#undef EffectiveRRDynamic
#undef StrategyIntelligenceTimer
#undef StrategyIntelligenceInit
#undef PersistStrategyPlanForExecution
#undef SelectDynamicStrategy
