In order for context and its tools to be able to locate files in the tds
compliant tree you need to copy 'contextcnf.lua' to 'texmfcnf.lua'. There
is a fallback to 'contextcnf.lua' when no 'texmfcnf.lua' is found. You can
have multiple 'texmfcnf.lua' files which means that you can overload global
settings.
