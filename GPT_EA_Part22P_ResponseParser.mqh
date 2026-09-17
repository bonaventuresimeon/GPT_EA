// ============================================================================
// GPT_EA Part 22P - Wider Responses API text extraction for intelligence data
// ============================================================================

input int InpIntelligenceResponseMaxChars = 12000;

string ExtractOpenAITextWide(const string json)
{
   int typePos=StringFind(json,"\"type\":\"output_text\"");
   int start=(typePos>=0?typePos:0);
   string key="\"text\":\"";
   int p=StringFind(json,key,start);
   if(p<0)
   {
      key="\"output_text\":\"";
      p=StringFind(json,key,start);
   }
   if(p<0) return "OpenAI response received, but text could not be parsed.";
   p+=StringLen(key);

   int cap=(InpIntelligenceResponseMaxChars<2000?2000:InpIntelligenceResponseMaxChars);
   string out="";
   bool esc=false;
   for(int i=p;i<StringLen(json);i++)
   {
      ushort ch=StringGetCharacter(json,i);
      if(ch=='\\' && !esc){ esc=true; out+="\\"; continue; }
      if(ch=='\"' && !esc) break;
      esc=false;
      out+=ShortToString(ch);
      if(StringLen(out)>=cap) break;
   }
   return JsonUnescape(out);
}
