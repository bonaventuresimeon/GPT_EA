// ============================================================================
// GPT_EA Part 37A - API transport compatibility helpers
// ============================================================================

string APITrim(const string source)
{
   string value=source;
   StringTrimLeft(value);
   StringTrimRight(value);
   return value;
}
