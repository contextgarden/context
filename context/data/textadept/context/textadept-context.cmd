@echo off

rem  This script starts textadept in an adapted mode, stripped from all the stuff we don't need,
rem  geared at the file formats that context deals with. The reason for this is that first of 
rem  all we come from scite, but also because the average user doesn't need that much and can 
rem  get confused by all kind of options that are irrelevant for editing text files. 
 
rem  This startup script assumes that the files can be found relative to this script. It's kind 
rem  of tricky because textadept, while being quite configurable, is not really made for such a 
rem  real bare startup situation but after some trial and error, so far it works out ok. There 
rem  are still some issues due to assumptions in the original code. In the meantime processing 
rem  a file from within the editing sessions works ok which is a huge improvement over earlier 
rem  versions of textadept (it was actually a show stopper) so now textadept can be used as a 
rem  drop in for scite. We're getting there!

rem  Although I like the idea of textadept, it is no longer a simple Lua binding to scintilla
rem  and the claim that it is small is no longer true. The number of Lua lines doesn't really
rem  say much if there are many third party dll dependencies (at least I see many files in the
rem  zip and most of them probably relate to parts of the graphical interface and therefore most
rem  is probably not used at all. The more dependencies there are, the less interesting it is to 
rem  officially support it as one of the reference editors for context, given that tex and friends
rem  aim at long term stability. It's huge and unless I'm mistaken there is no minimal lightweight 
rem  variant for building a stripped down variant (in editing with mono spaced fonts we don't need 
rem  all that stuff). A small static stripped binary would be really nice to have (and I'd 
rem  probably default to using textadept then). I might at some point decide to strip more and just 
rem  provide what we only need (which is less than is there now). We'll see how it evolves. 

rem  In the meantime support for scintillua has been dropped which makes scite vulnerable as there
rem  is no default scite (yet) with lpeg built in. Anyway, it means that we will not provide an
rem  installer for scite or textadept which does the reference highlighting we've been using for
rem  decades. It is up to the user: use lightweight scite or a more dependent but also more 
rem  configurable texadept. It would be really nice to have multiple options for editing (read: if 
rem  scite would have scintillua on board.) The same is true for notepad++. Each of them has its 
rem  advantage (and each is used by context users).  

rem  Unless the textadept api changes fundamentally (as happened a couple of times before) this
rem  should work:

start textadept -u %~dp0 %*

rem  I still need to port some of the extra functionality that we have in scite to textadept, which
rem  will happen in due time. We use our own lexers because they are more efficient and have some 
rem  extra options (they were also much faster at that time and could handle very large files; they
rem  also build on already existing code in context verbatim mode). By the way, editing char-def.lua 
rem  in textadept is actually now faster than in scite (using the same lpeg lexers), which is nice. 
rem  There is no language strip functionality yet as there is no strip (bottom area) as in scite. 

rem  The macros.lua file has some hard coded assumptions wrt menu items and the event crashes with a 
rem  error message that we can't get rid of. I need to figure out a way to close that buffer but 
rem  somehow the first buffer is closed anyway which is kind of weird. One way out is to just 
rem  comment: 
rem 
rem   -- textadept.menu.menubar[_L['_Tools']][_L['Select Co_mmand']][2],
rem 
rem  Maybe I should just copy all the files and remove code we don't need but ... let's delay that 
rem  as it might get fixed. I'm in no hurry. 