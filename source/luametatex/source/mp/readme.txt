Remark

When a CWEB (W) file is adapted we need to convert to C. This is normally done with the 
tangle program but as we want to be independent of other tools (which themselves can result 
in a chain of dependencies) we use a Lua script which happens to be run with LuaMetaTeX.

Of course there is a chicken egg issue here because we need the engine as Lua interpreter 
but at some point we started with C files so now we only need to update. 

The script is located in the "tools" path alongside the "source" path and it is run in its 
own directory (which for me means: hit the run key when the document is open). As we always 
ship the C files, there is no need for a user to run the script. 

The script does a reasonable good job on the conversion and tries to generate good looking 
C code denying the argument that "it is only a machine that looks at it". We also had to 
catch some compiler issues. As LuaMetaTeX evolved some new functionality has been added and 
the W files have been cleanup quite a bit. 

Per begin March 2024 we no longer start from the W files but use C files that have the 
documentation embedded. For a while we keep the old W files around. An patch to the convert
script tried to keep the documentation close to the code but some had to be manually moved
to the right spot. This is partly due to the fact that we want it in the C file and not 
the H file. One reason for this change is that it is easier to add (upcoming) new features
to the MetaPost engine. Due to changes over the years and the fact that the original code 
is used in the MP program we no longer have backporting on the agenda. 

In the current C files the documentation looks suboptimal but it will stepwise be cleaned up 
a bit without loosing the original. There is no intention to process the documentation but 
we keep using a mixture of Plain (the original) and ConTeXt (more structure). Although the C
code was already optimimized and reshuffled we start from a reasonable clean code base. The 
idea is to gradually improve it and maybe even split of the now monolithic |mp.c| file into 
smaller files, although it is not that important.  

For a while we will keep the W files around because they are also a timestamp but eventually 
they will be archived. After all, they are still in the GIT repository. By keeping them we 
can backtrack the documentation but as they are frozen you should not use them! 

Hans Hagen 
2018-2024+