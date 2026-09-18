// ============================================================================
// GPT_EA Part 26 - Deep GPT policy for final adversarial validation
// ============================================================================

input bool   InpUseDeepGPTReviewModel       = true;
input string InpDeepGPTReviewModel          = "gpt-5.6-sol";
input string InpDeepGPTReasoningEffort      = "high";
input int    InpDeepGPTMaxOutputTokens      = 1200;

string ValidReasoningEffort(string effort)
{
   StringToLower(effort);
   if(effort=="none" || effort=="low" || effort=="medium" || effort=="high" ||
      effort=="xhigh" || effort=="max") return effort;
   return "high";
}

bool CallOpenAIDeep(const string prompt,string &answer,string &errorText)
{
   answer=""; errorText="";
   if(!InpUseOpenAI){ errorText="OpenAI disabled."; return false; }
   if((bool)MQLInfoInteger(MQL_TESTER)){ errorText="WebRequest unavailable in Strategy Tester."; return false; }
   if(StringLen(Trim(InpOpenAIAPIKey))<20){ errorText="OpenAI API key not configured in EA inputs."; return false; }

   string model=(InpUseDeepGPTReviewModel?Trim(InpDeepGPTReviewModel):Trim(InpOpenAIModel));
   if(model=="") model=InpOpenAIModel;
   string effort=ValidReasoningEffort(InpDeepGPTReasoningEffort);
   int maxTokens=(InpDeepGPTMaxOutputTokens<200?200:InpDeepGPTMaxOutputTokens);
   string body="{\"model\":\""+JsonEscape(model)+"\","
               "\"reasoning\":{\"effort\":\""+JsonEscape(effort)+"\"},"
               "\"max_output_tokens\":"+IntegerToString(maxTokens)+","
               "\"input\":\""+JsonEscape(prompt)+"\"}";
   string headers="Content-Type: application/json\r\nAuthorization: Bearer "+InpOpenAIAPIKey+"\r\n";
   char data[],result[]; string resultHeaders="";
   int n=StringToCharArray(body,data,0,WHOLE_ARRAY,CP_UTF8); if(n>0) ArrayResize(data,n-1);

   ResetLastError();
   int code=WebRequest("POST",InpOpenAIEndpoint,headers,InpOpenAITimeoutMs,data,result,resultHeaders);
   if(code==-1)
   {
      errorText=StringFormat("Deep GPT WebRequest failed (%d). Add https://api.openai.com to MT5 WebRequest allow-list.",GetLastError());
      return false;
   }
   string json=CharArrayToString(result,0,-1,CP_UTF8);
   if(code<200 || code>=300)
   {
      errorText=StringFormat("Deep GPT HTTP %d: %s",code,StringSubstr(json,0,600));
      return false;
   }
   answer=ExtractOpenAIText(json);
   if(answer=="" || StringFind(answer,"could not be parsed")>=0)
   {
      errorText="Deep GPT response text unavailable.";
      return false;
   }
   return true;
}
