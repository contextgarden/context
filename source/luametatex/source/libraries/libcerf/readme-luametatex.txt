LS,

In the following files you can find the comment below. We don't want to bother or burden the
original authors with our problems. The cerf code is mostly used in MetaFun macros (by Alan
Braslau). The c.h and cpp.h files are gone.

    defs.h
    cerf.h

---------------------------------------------------------------------------------------------
This file is patched by Mojca Miklavec and Hans Hagen for usage in LuaMetaTeX where we use
only C and also want to compile with the Microsoft compiler. So, when updating this library
one has to check for changes. Not that we expect many as this is a rather stable library.

In the other files there are a few macros used that deal with the multiplication and addition
of complex and real nmbers. Of course the original code is kept as-is.
---------------------------------------------------------------------------------------------

So, when updating the library you need to diff for the changes that are needed in order to
compile the files with the Microsoft compiler.

At some point I might patch the files so that we can intercept error messages in a way that
permits recovery and also plugs them into our normal message handlers. Maybe I should also
merge the code into just one file because it doesn't change.

Hans
