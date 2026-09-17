// ============================================================================
// GPT_EA Part 00 - Forward declarations for cross-module hooks
// ============================================================================

// Defined in Part05.
bool PriceInsideZone(const TradeSetup &s);
bool M5Trigger(const TradeSetup &s);
string SetupSummaryLine(const TradeSetup &s);

// Defined in Part13.
bool PositionFlag(ulong pid,ulong ticket,const string field);

// Defined in Part18 and called by Part14.
void RecordStopFailureObservation(ulong ticket,const string context,const string reason,bool critical,double requestedSL,double rNow);
