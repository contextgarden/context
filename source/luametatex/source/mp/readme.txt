Remark

When a CWEB file is adapted we need to convert to C. This is normally done with the tangle 
program but as we want to be independent of other tools (which themselves can result in a
chain of dependencies) we use a Lua script which happens to be run with LuaMetaTeX.

Of course there is a chicken egg issue here but at some point we started with C files so
now we only need to update. 

The script is located in the "tools" path alongside the "source" path and it is run in its 
own directory (which for me means: hit the run key when the document is open). As we always 
ship the C files, there is no need for a user to run the script. 

Hans Hagen 