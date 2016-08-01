return {
 {
  ["off"]="0.399",
  ["on"]="0.081",
 },
 {
  ["off"]="1.339",
  ["on"]="0.081",
 },
 {
  ["off"]="4.527",
  ["on"]="2.817",
 },
 {
  ["off"]="0.644",
  ["on"]="0.640",
 },
 {
  ["off"]="3.032",
  ["on"]="3.007",
 },
 {
  ["off"]="4.046",
  ["on"]="4.977",
 },
 ["local fc = font.current\
\
function font.current()\
    return fc()\
end\
\
return function()\
    local a = 0\
    for i=1,10000 do\
        a = a + font.current()\
    end\
end"]={
  ["off"]="1.966",
  ["on"]="2.492",
 },
 ["local fc = font.current\
\
function font.xcurrent()\
    return fc()\
end\
\
return function()\
    local a = 0\
    for i=1,10000 do\
        a = a + font.xcurrent()\
    end\
end"]={
  ["off"]="1.912",
  ["on"]="1.915",
 },
 ["local function whatever(i)\
    return i\
end\
\
return function()\
    local a = 0\
    for i=1,10000 do\
        a = a + whatever(i)\
    end\
end"]={
  ["off"]="0.648",
  ["on"]="0.042",
 },
 ["local tostring, tonumber = tostring, tonumber\
return function()\
    local a = 0\
    for i=1,1000 do\
        local a = a + tonumber(tostring(i))\
    end\
end"]={
  ["off"]="2.620",
  ["on"]="0.162",
 },
 ["local tostring, tonumber = tostring, tonumber\
return function()\
    local a = 0\
    for i=1,10000 do\
        local a = a + tonumber(tostring(i))\
    end\
end"]={
  ["off"]="79.316",
  ["on"]="5.640",
 },
 ["return function()\
    local a = 0\
    for i=1,100 do\
        local a = a + tonumber(tostring(i))\
    end\
end"]={
  ["off"]="0.703",
  ["on"]="0.047",
 },
 ["return function()\
    local a = 0\
    for i=1,1000 do\
        local a = a + tonumber(tostring(i))\
    end\
end"]={
  ["off"]="2.607",
  ["on"]="0.162",
 },
 ["return function()\
    local a = 0\
    for i=1,10000 do\
        a = a + font.current()\
    end\
end"]={
  ["off"]="1.292",
  ["on"]="1.296",
 },
 ["return function()\
    local a = 0\
    for i=1,10000 do\
        a = a + i\
    end\
end"]={
  ["off"]="0.207",
  ["on"]="0.042",
 },
 ["return function()\
    local a = 0\
    for i=1,10000 do\
        a = a + math.sin(1/i)\
    end\
end"]={
  ["off"]="2.204",
  ["on"]="1.482",
 },
 ["return function()\
    local a = 0\
    for i=1,10000 do\
        local a = a + tonumber(tostring(i))\
    end\
end"]={
  ["off"]="79.456",
  ["on"]="5.703",
 },
 ["return function()\
    local a = 0\
    local p = (1-lpeg.P(\"5\"))^0 * lpeg.P(\"5\")\
    for i=1,100 do\
        local a = a + (tonumber(lpeg.match(p,tostring(i))) or 0)\
    end\
end"]={
  ["off"]="0.859",
  ["on"]="0.843",
 },
 ["return function()\
    local a = 0\
    local p = (1-lpeg.P(\"5\"))^0 * lpeg.P(\"5\") + lpeg.Cc(0)\
    for i=1,100 do\
        local a = a + lpeg.match(p,tostring(i))\
    end\
end"]={
  ["off"]="0.313",
  ["on"]="0.316",
 },
}