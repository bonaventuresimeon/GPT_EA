// ============================================================================
// GPT_EA Part 25 - Thesis hardening and explicit disproof/RR comparison
// ============================================================================

string DeterministicDisproofChecklist(const StrategySnapshot &x,const StrategyDecision &d,const TradeSetup &s)
{
   string out="Disproof checklist: ";
   out+=(x.trendFailure?"trend failure already detected; ":"HTF structure not yet failed; ");
   out+=(x.falseBreakUp||x.falseBreakDown?"false-break evidence present; ":"no current false-break flag; ");
   out+=(x.exhaustion?"exhaustion present; ":"no exhaustion flag; ");
   out+=(ChaseRiskDetected(x)?"entry is vulnerable to chasing; ":"chase filter clear; ");
   out+=(d.counterTrend?"counter-trend thesis requires strict sweep/BOS/rejection; ":"direction is not classified counter-trend; ");
   out+=StringFormat("SL invalidation %.5f; strategy score %d/100.",s.sl,d.score);
   return out;
}

string BuildMandatory25PointThesisFinal(const string sym,TradeSetup &primary,TradeSetup &pb,TradeSetup &br,
                                        const StrategyDecision &d,const ConfluenceReport &c,
                                        const string calendarText,const string webText,const IntermarketReport &im,
                                        const string spreadText,const string sessionText)
{
   string thesis=BuildMandatory25PointThesis(sym,primary,pb,br,d,c,calendarText,webText,im,spreadText,sessionText);
   StrategySnapshot x; BuildStrategySnapshot(sym,x);
   RealisticRRReport pbr=RealisticRiskReward(pb);
   RealisticRRReport brr=RealisticRiskReward(br);
   RealisticRRReport pr=RealisticRiskReward(primary);

   thesis+="\n━━━━━━━━━━━━━━━━━━━━\n🔬 EXECUTION / RESEARCH HARDENING ADDENDUM\n━━━━━━━━━━━━━━━━━━━━\n";
   thesis+="Retracement model: "+RetracementIntelligenceText(x)+"\n";
   thesis+="Pullback realistic execution: "+pbr.detail+"\n";
   thesis+="Breakout-retest realistic execution: "+brr.detail+"\n";
   thesis+="Selected setup realistic execution: "+pr.detail+"\n";
   thesis+="Comparison rule: choose neither setup merely because its theoretical R multiple is larger. The executable setup must retain structure, trigger quality and weighted R:R after spread, slippage, commission and partial exits.\n";
   thesis+="Strategy-specific candle invalidation: "+IntegerToString(primary.expiryM15)+" M15 candles for the currently selected strategy after ATR/opening-range adaptation; breakout/counter-trend scalp setups require faster follow-through than retracement/swing setups.\n";
   thesis+="Historical/context/walk-forward validation: "+d.evidence+"\n";
   thesis+=DeterministicDisproofChecklist(x,d,primary)+"\n";
   thesis+="News freshness contract: a HIGH-CONFIDENCE authorization must not silently rely on unavailable/stale live-news intelligence when fail-closed high-confidence news mode is enabled. Intermarket contradiction is accepted only from fresh broker bars.\n";
   return thesis;
}
