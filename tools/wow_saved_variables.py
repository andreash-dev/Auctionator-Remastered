"""Read WoW SavedVariables as literal data; never execute Lua code."""
import re,json
from pathlib import Path
NUMBER = re.compile(r'-?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?')
IDENTIFIER = re.compile(r'[A-Za-z_][A-Za-z_0-9]*')
class Parser:
 def __init__(self,s): self.s=s;self.i=0
 def skip(self):
  while self.i<len(self.s):
   if self.s[self.i].isspace(): self.i+=1
   elif self.s.startswith('--',self.i):
    end=self.s.find('\n',self.i);self.i=len(self.s) if end<0 else end+1
   else: break
 def string(self):
  quote=self.s[self.i];self.i+=1;out=[]
  while self.i<len(self.s):
   c=self.s[self.i];self.i+=1
   if c==quote:return ''.join(out)
   if c=='\\':
    c=self.s[self.i];self.i+=1
    escapes={'n':'\n','r':'\r','t':'\t','a':'\a','b':'\b','f':'\f','v':'\v'}
    if c.isdigit():
     digits=c
     while len(digits)<3 and self.i<len(self.s) and self.s[self.i].isdigit():digits+=self.s[self.i];self.i+=1
     c=chr(int(digits))
    else:c=escapes.get(c,c)
   out.append(c)
  raise ValueError('Unclosed string')
 def char(self,c):
  self.skip();assert self.s.startswith(c,self.i),(self.i,c,self.s[self.i:self.i+30]);self.i+=len(c)
 def value(self):
  self.skip();c=self.s[self.i]
  if c in '\"\'':return self.string()
  if c=='{':
   self.i+=1;result={};index=1
   while True:
    self.skip()
    if self.s[self.i]=='}':self.i+=1;return result
    if self.s[self.i]=='[':
     self.i+=1;k=self.value();self.char(']');self.char('=');v=self.value()
    else:
     field=IDENTIFIER.match(self.s,self.i)
     end=field.end() if field else self.i
     while end<len(self.s) and self.s[end].isspace():end+=1
     if field and end<len(self.s) and self.s[end]=='=':
      k=field.group();self.i=end+1;v=self.value()
     else:k=index;index+=1;v=self.value()
    result[k]=v;self.skip()
    if self.s[self.i] in ',;':self.i+=1
  for word,v in [('true',True),('false',False),('nil',None)]:
   if self.s.startswith(word,self.i):self.i+=len(word);return v
  m=NUMBER.match(self.s,self.i)
  if m:
   token=m.group();self.i=m.end();return float(token) if any(c in token for c in '.eE') else int(token)
  raise ValueError(('Non-literal Lua at',self.i,self.s[self.i:self.i+40]))
 def document(self):
  result={}
  while True:
   self.skip()
   if self.i>=len(self.s):return result
   m=IDENTIFIER.match(self.s,self.i);assert m
   k=m.group();self.i+=len(k);self.char('=');result[k]=self.value();self.skip()
   if self.i<len(self.s) and self.s[self.i]==';':self.i+=1
