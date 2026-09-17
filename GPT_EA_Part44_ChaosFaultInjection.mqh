// ============================================================================
// GPT_EA Part 44 - Non-production chaos / fault-injection hooks
// ============================================================================
// Test-only. Fault injection is categorically disabled on REAL accounts.

input bool InpEnableChaosFaultInjection = false;
input int  InpChaosFaultScenario        = 0;
input bool InpChaosOneShot              = true;

enum ChaosFaultScenario
{
   CHAOS_NONE=0,
   CHAOS_API_TIMEOUT=1,
   CHAOS_STALE_QUOTE=2,
   CHAOS_STORAGE_WRITE_FAIL=3,
   CHAOS_BEFORE_ORDER_SEND_AMBIGUOUS=4,
   CHAOS_POST_FILL_PRE_BIND=5,
   CHAOS_DROP_TRADE_TRANSACTION=6,
   CHAOS_DUPLICATE_TRADE_TRANSACTION=7,
   CHAOS_STOP_MODIFY_FAIL=8,
   CHAOS_CORRUPT_CHECKPOINT=9,
   CHAOS_CONNECTION_LOSS=10
};

bool g_chaosConsumed=false;

string ChaosFaultName(int s)
{
   switch(s)
   {
      case CHAOS_API_TIMEOUT: return "API_TIMEOUT";
      case CHAOS_STALE_QUOTE: return "STALE_QUOTE";
      case CHAOS_STORAGE_WRITE_FAIL: return "STORAGE_WRITE_FAIL";
      case CHAOS_BEFORE_ORDER_SEND_AMBIGUOUS: return "BEFORE_ORDER_SEND_AMBIGUOUS";
      case CHAOS_POST_FILL_PRE_BIND: return "POST_FILL_PRE_BIND";
      case CHAOS_DROP_TRADE_TRANSACTION: return "DROP_TRADE_TRANSACTION";
      case CHAOS_DUPLICATE_TRADE_TRANSACTION: return "DUPLICATE_TRADE_TRANSACTION";
      case CHAOS_STOP_MODIFY_FAIL: return "STOP_MODIFY_FAIL";
      case CHAOS_CORRUPT_CHECKPOINT: return "CORRUPT_CHECKPOINT";
      case CHAOS_CONNECTION_LOSS: return "CONNECTION_LOSS";
      default: return "NONE";
   }
}

bool ChaosEnvironmentAllows()
{
   if(!InpEnableChaosFaultInjection) return false;
   if(AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_REAL) return false;
   return ((bool)MQLInfoInteger(MQL_TESTER) || AccountInfoInteger(ACCOUNT_TRADE_MODE)!=ACCOUNT_TRADE_MODE_REAL);
}

bool ChaosFaultHit(int scenario)
{
   if(!ChaosEnvironmentAllows() || InpChaosFaultScenario!=scenario) return false;
   if(InpChaosOneShot && g_chaosConsumed) return false;
   g_chaosConsumed=true;
   GVWrite(SysKey("CHAOS_ACTIVE_SAMPLE"),1);
   GVWrite(SysKey("CHAOS_LAST_SCENARIO"),scenario);
   GVWrite(SysKey("CHAOS_LAST_TIME"),(double)TimeTradeServer());
   Print("GPT_EA CHAOS INJECTION: ",ChaosFaultName(scenario));
   return true;
}

bool ChaosInjectAPITimeout(){ return ChaosFaultHit(CHAOS_API_TIMEOUT); }
bool ChaosInjectStaleQuote(){ return ChaosFaultHit(CHAOS_STALE_QUOTE); }
bool ChaosInjectStorageFailure(){ return ChaosFaultHit(CHAOS_STORAGE_WRITE_FAIL); }
bool ChaosInjectBeforeOrderSend(){ return ChaosFaultHit(CHAOS_BEFORE_ORDER_SEND_AMBIGUOUS); }
bool ChaosInjectPostFillPreBind(){ return ChaosFaultHit(CHAOS_POST_FILL_PRE_BIND); }
bool ChaosDropTradeTransaction(){ return ChaosFaultHit(CHAOS_DROP_TRADE_TRANSACTION); }
bool ChaosDuplicateTradeTransaction(){ return ChaosFaultHit(CHAOS_DUPLICATE_TRADE_TRANSACTION); }
bool ChaosInjectStopModifyFailure(){ return ChaosFaultHit(CHAOS_STOP_MODIFY_FAIL); }
bool ChaosInjectCorruptCheckpoint(){ return ChaosFaultHit(CHAOS_CORRUPT_CHECKPOINT); }
bool ChaosInjectConnectionLoss(){ return ChaosFaultHit(CHAOS_CONNECTION_LOSS); }

void ChaosResetForTest()
{
   if(AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_REAL) return;
   g_chaosConsumed=false;
   GVWrite(SysKey("CHAOS_ACTIVE_SAMPLE"),0);
}

void ChaosInit()
{
   if(InpEnableChaosFaultInjection && AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_REAL)
   {
      Print("GPT_EA CHAOS REFUSED: fault injection is disabled on REAL accounts.");
      g_chaosConsumed=true;
      return;
   }
   if(InpEnableChaosFaultInjection)
      Print("GPT_EA chaos test enabled: ",ChaosFaultName(InpChaosFaultScenario)," | one-shot=",InpChaosOneShot?"YES":"NO");
}
