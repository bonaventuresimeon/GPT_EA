// ============================================================================
// GPT_EA Part 00 - Forward declarations for cross-module hooks
// ============================================================================

// Defined in Part05.
bool PriceInsideZone(const TradeSetup &s);
bool M5Trigger(const TradeSetup &s);
string SetupSummaryLine(const TradeSetup &s);

// Defined in Part13.
bool PositionFlag(ulong pid,ulong ticket,const string field);

// Defined in Part14.
void RegisterStopUpdateFailure(ulong ticket,const string reason,bool critical,double requestedSL,double rNow);
bool StopUpdateRetryDue(ulong pid);

// Defined in Part18 and called by Part14 / Part13.
void RecordStopFailureObservation(ulong ticket,const string context,const string reason,bool critical,double requestedSL,double rNow);
void RecordStopRecoveryObservation(ulong ticket,const string context,const string note);
void RecordStopObservationEvent(ulong ticket,const string eventName,const string context,const string reason,bool critical,double requestedSL,double rNow);
void RecordPartialProtectionObservation(ulong ticket,const string eventName,const string reason);

// Defined in Part23 and used by adaptive notification integration in Part35.
void NotifyCardObserved(const string card);


// Defined in Part39 and used by pre-Part39 historical finalizers.
int IntegrityTextHash(const string text);
string CurrentSensitiveConfigText();
