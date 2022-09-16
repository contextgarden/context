--------------------------------------------------------------------------------
welcome
--------------------------------------------------------------------------------

There is not much information here. I normally keep track of developments in
articles or chapters in the history documents. These can (sometimes with a delay
when it's an article) be found in the ConTeXt distribution. The history and
development of LuaTeX is also documented there, often with examples or usage.

The ideas behind this project are discussed in documents in the regular ConTeXt
distribution. A short summary is: in order to make sure ConTeXt will work as
intended, we distribute an engine with it. That way we can control stability,
performance and features. It also permits experiments without the danger of
interference with the engines used in other macro packages. Also, we don't want
dependencies on large subsystems so we have a well defined set of libraries: we
want to stay lean and mean. Eventually the same applies as to original TeX: we
fix bugs and don't add all kind of stuff we don't (want or) need. Just that.

--------------------------------------------------------------------------------
codebase
--------------------------------------------------------------------------------

This codebase is a follow up on LuaTeX. It all started with a merge of files
that came from the Pascal to C converter (CWEB) plus some C libraries. That code
base evolved over time and there were the usual side effects of the translation
and merge of (also other engine) code, plus successive extensions as well as Lua
interfaces. In LuaMetaTeX I tried to smooth things a bit. The idea was to stay
close to the original (which in the end is TeX itself) so that is why many
variables, functions etc are named the way they are. Of course I reshuffled, and
renamed but I also tried to stay close to the original naming. More work needs
to be done to get it all right but it happens stepwise as I don't want to
introduce bugs. In the meantime the LuaTeX and LuaMetaTeX code bases differ
substantially but apart from some new features and stripping away backend and
font code, the core should work the same.

tex etex pdftex aleph:

Of course the main body of code comes from its ancestors. We started with pdfTeX
which has its frontend taken from standard TeX, later extended with the eTeX
additions. Some additional features from pdfTeX were rewritten to become core
functionality. We also took some from Aleph (Omega) but only some (in the
meantime adapted) r2l code is left (so we're not compatible).

mp:

The maintainance of MetaPost was delegated to the same people who do luaTeX and
as a step indevelopment a library was written. This library is used in
LuaMetaTeX but has been adapted a bit for it. In principle some of the additions
can be backported, but that is yet undecided.

lua:

This is the third major component of LuaMetaTeX. In LuaTeX a slightly patched
version has been used but here we use an unchanged version, although the version
number of the bytecode blob is adapted so that we can use intermediate versions
of lua 5.4 that expect different bytecode without crashing on existing bytecode;
this trick has been dropped but I hope at some point Lua will add a define for
this.

For the record: when we started with LuaTeX I'd gone through a pascal, modula 2,
perl, ruby with respect to the management helpers for ConTeXt, like dealing with
indexes, managing metapost subruns, and all kind of goodies that evolved over time.
I ran into Lua in the SciTE editor and the language and the concept of a small and
efficient embedded language. The language orginates in academia and is not under
the influence of (company and commercial driven) marketing. A lot of effort goes
into stepwise evolution. The authors are clear about the way they work on the
language:

	http://lua-users.org/lists/lua-l/2008-06/msg00407.html

which fits nicely in our philosophy. Just in case one wonders if other scripting
languages were considered the answer is: no, they were not. The alternatives all
are large and growing and come with large ecosystems (read: dependencies) and some
had (seemingly) drastic changes in the design over time. Of course Lua also evolves
but that is easy to deal with. And in the meantime also the performance of Lua made
it clear that it was the right choice.

avl:

This library has been in use in the backend code of LuaTeX but is currently only
used in the MP library. I'm not sure to what extend this (originally meant for
Python) module has been adapted for pdfTeX/LuaTeX but afaiks it has been stable
for a long time. It won't be updated but I might adapt it for instance wrt error
messages so that it fits in.

decnumber:

This is used in one of the additional number models that the mp library supports.
In LuaMetaTeX there is no support for the binary model. No one uses it and it
would add quite a bit to the codebase.

hnj:

This GPL licensed module is used in the hyphenation machinery. It has been
slightly adapted so that error messages and such fit in. I don't expect it to
change much in the future.

pplib:

This library is made for Lua(Meta)TeX and provides an efficient PDF parser in
pure C. In LuaTeX it was introduced a replacement for a larger library that
was overkill for our purpose, depended on C++ and kept changing. This library
itself uses libraries but that code is shipped with it. We use some of that
for additional Lua modules (like md5, sha2 and decoding).

lz4 | lzo | zstd:

For years this library was in the code base and even interfaced but not enabled
by default. When I played with zstd support as optional libary I decided that
these two should move out of the code base and also be done the optional way. The
amount of code was not that large, but the binary grew by some 10%. I also played
with the foreign module and zstd and there is no real difference in peformance. The
optionals are actually always enabled, but foreign is controlled by the command
line option that enables loading libraries, and it al;so depends on libffi.

zlib | miniz:

I started with the code taken from LuaTeX, which itself was a copy that saw some
adaptions over time (irr there were border case issues, like dealing with zero
length streams and so). It doesn't change so in due time I might strip away some
unused code. For a while libdeflate was used but because pplib also depends on
zlib and because libdeflate doesn't do streams that was abandoned (it might come
back as it is very nice and clean code.). One issue with (de)compression libraries
is that they use tricks that can be architecture dependent and we stay away from
that. I try to stay away from those and prefer to let the compiler sort things out.

Early 2021 we switched to miniz. One reason is that the codebase is smaller because
it doesn't deal with very old or rare platforms and architectures. Its performance
is comparable, definitely for our purpose, and sometimes even a bit better. I looked
at other alternatives but as soon as processor specific tricks are used, we end up
with architecture specific header files and code so it's a no-go for a presumed
long term stable and easy to compile program like luametatex. There is no gain in it
anyway.

complex:

There is a complex number interface inspired by the complex number lua module by
lhf. It also wraps libcerf usage.

lfs:

In LuaTeX we use a patched version of this library. In LuaMetaTeX I rewrote the
code because too many patches were needed to deal with mswindows properly.

socket:

The core library is used. The library is seldom adapted but I keep an eye on it.
We used to have a patched version in LuaTeX, but here we stay closer. I might
eventually do some rewrite (less code) or decide to make it an external library.
The related Lua code is not in the binary and context uses its own (derived)
variant so that it uses our helpers as well as fits in the reporting system. I
need to keep an eye on improvements upstream. We also need to keep an eye on
copas as we use that code in context.

luasec:

This is not used but here as a reference for a possible future use (maybe as
library).

curl, ghostscript, graphicmagick, zint, mujs, mysql, postgress, sqlite, ...:

The optional module mechamism supports some external libraries but we don't keep
their code in the luametatex codebase. We might come up with a separate source
tree for that, but only for some smaller ones. The large ones, those depending
on other libraries, or c++, or whatever resources, will just be taken from the
system.

libcerf:

This library might become external but is now in use as a plug into the complex
number support that itself is meant for MetaPost use. The code here has been
adapted to support the Microsoft compiler. I will keep an eye on what happens
upstream and I reconsider matters later. (There is no real need to bloat the
LuaMetaTeX binary with something that is rarely used.)

kpse:

There is optional library support for the KPSE library used in WEB2C. Although
it does provide the methods that make sense, it is not meant for usage in
ConTeXt, but more as a toolkit to identify issues and conflicts with parallel
installations like TeXLive.

hb:

I have a module that works the same as the ffi variant from a couple of years
ago and I might add it when it's needed (for oriental tex font development
checking purposes, but then I also need to cleanup and add some test styles for
that purpose). Looking at the many LuaTeX subversion checkins it looks a bit
like a moving target. It's also written in C++ which we don't (want to) use in
LuaMetaTeX. But the library comes with other programs so it's likely you can
find it on you system someplace.

general:

It's really nice to see all these libraries popping up on the web but in the
perspective of something like TeX one should be careful. Quite often what is hip
today is old fashioned tomorrow. And quite often the selling point of the new
thing comes with bashing the old, which can be a sign of something being a
temporary thing or itself something ot be superseded soon. Now, get me right:
TeX in itself is great, and so are successors. In that sense LuaMetaTeX is just
a follow up with no claims made for it being better. It just makes things easier
for ConTeXt. You can kick in libraries but be aware of the fact that they can
change, so if you have long running projects, make sure you save them. Or run a
virtual machine that can last forever. TeX systems can run for ages that way. We
might eventually add support for generating libs to the compile farm. The older
a library gets, the bigger the change that its api is stable. Compression
libraries are great examples, while libraries that deal with images, conversion
and rendering are more moving (and have way more dependencies too). Actually,
for the later category, in ConTeXt we prefer to call the command line variants
instead of using libraries, also because it seldom influences performance.

licenses:

Most files contain some notice about a the license and most are quite liberal.
I had to add some (notes) that were missing from LuaTeX. There is an occasional
readme file that tells a bit more.

explanations:

The TeX derived source code contains many comments that came with the code when
it was moved from "Pascal Web" to "C Web" (with web2c) to "C plus comments" (by
Taco). These comments are mostly from Don Knuth as they were part of TeX The
Program. However, some comments were added (or changed) in the perspective of
eTeX, pdfTeX, Aleph, etc. We also added some in LuaTeX and LuaMetaTeX. So, in
the meantime it's a mix. It us who made the mess, not Don! In due time I hope
to go over all the comments and let them fit the (extended) code.

dependencies:

Often the files here include more h files than needed but given the speed of
compilation that is no problem. It also helps to identify potential name clashes
and such.

legacy:

Occasionally there is a file texlegacy.c that has some older (maybe reworked)
code but I move it to another place when It gets too large and its code no
longer can be retrofit. For me is shows a bit what got done in the (many)
intermediate steps.

--------------------------------------------------------------------------------
documentation
--------------------------------------------------------------------------------

The code will be stepwise cleaned up a it (removing the web2c side effects),
making the many branches stand out etc so that some aspects can be documented
a bit better (in due time). All this will take time (and already quite some time
went into it.) The official interface of LuaMetaTeX is described in the manual
and examples of usage can be seen in ConTeXt. Of course TeX behaves as such.

The organization of files, names of functions can change as we progress but when
possible the knuthian naming is followed so that the documentation of "TeX The
Program" still (mostly) applies. Some of the improvements in LuaMetaTeX can
eventually trickle back into LuaTeX although we need to guard stability. The
files here can *not* be dropped into the LuaTeX source tree!

--------------------------------------------------------------------------------
reboot
--------------------------------------------------------------------------------

I'll experiment with a reboot engine option but for sure that also interferes
with a macro package initialization so it's a long term experiment. Quite
certainly it will not pay off anyway so it might never happen. But there are
some pending ideas so ...

--------------------------------------------------------------------------------
libraries | ffi | luajit
--------------------------------------------------------------------------------

We use optional libraries instead of ffi which is not supported because it is
cpu and platform bound and the project that the code was taken from seems to
be orphaned. Also luajit is not supported as that projects is stalled and uses
an old lua.

--------------------------------------------------------------------------------
cmake
--------------------------------------------------------------------------------

We (Mojca and Hans) try to make the build as simple as possible with a minimum
of depencies. There are some differences with respect to unix and windows (we
support msvc, crosscompiled mingw and clang). The code of libraries that we use
is included, apart from optional libraries. It can only get better.

We really try to make all compilers happy and minimize the number of messages,
even if that makes the code a bit less nice. It's a bit unfortunate that over
time the demands and default change a bit (what was needed before triggers a
warning later).

--------------------------------------------------------------------------------
experiments
--------------------------------------------------------------------------------

I've done quite some experiments but those that in the end didn't make sense, or
complicated the code, or where nice but not that useful after all were simply
deleted so that no traces are left that can clutter the codebase. I'll probably
for get (and for sure already have forgotten) about most of them so maybe some
day they will show up as (different) experiments. We'll see how that goes.

-- miniz    : smaller pdf files, less code, similar performance
-- mimalloc : especially faster for the lua subsystem

--------------------------------------------------------------------------------
performance
--------------------------------------------------------------------------------

By now the codebase is different from the LuaTeX one and as a consequence the
performance can also differ. But it's hard to measure in ConTeXt because much
more has to be done in Lua and that comes at a price. The native LuaTeX backend
is for instance much faster (last time meausred the penalty can be up to 20%).
On the Internet one can run into complaints about performance of LuaTeX with
other macro packages, so one might wonder why we made this move but speed is
not everything. On the average ConTeXt has not become less efficient, or
at least I don't see its users complain much about it, so we just moved on.

The memory footprint at the engine end is somewhat smaller but of course that
gets compensated by memory consumption at the Lua end. We also sacrifice the
significate gain of the faster LuaJIT virtual machine (although at some point
supporting that variant makes not much sense any more as it lacks some Lua
features). Because, contrary to other TeX's the Lua(Meta)TeX frontend code
is split up in separate units, compilers can probably do less optimization,
although we use large compilations units that are mostly independent of each
other.

Eventually, in a next stage, I might be able to compentate it but don't expect
miracles: I already explored all kind of variations. Buying a faster machine is
always an option. Multiple cores don't help, faster memory and caching of files
does. Already early in the LuaTeX development we found that a CPU cache matters
but (definitely on server with many a virtual machines) there LuaMetaTeX has to
compete.

So, at this point my objective is not so much to make LuaMetaTeX run faster but
more to make sure that it keeps the same performance, even if more functionality
gets added to the TeX, MetaPost and/or Lua parts. Also keep in mind that in the
end inefficient macros and styles play a bigger role that the already pretty
fast engine.

--------------------------------------------------------------------------------
rapid development cycle
--------------------------------------------------------------------------------

Because I don't want to divert too much (and fast) from the way traditional TeX
is coded, the transition is a stepwise process. This also means that much code
that first has been abstracted and cleaned up, later goes. The extra work that
is involved, combined with a fast test cycle with the help of ConTeXt users
ensures that we keep a working ConTeXt although there occasionally are periods
with issues, especially when fundamentals change or are extended. However, the
number of temporary bugs is small compared to the number of changes and
extensions and worth the risk. The alternative is to have long periods where we
don't update the engine, but that makes testing the related changes in ConTeXt
rather cumbersome. After all, the engine targets at ConTeXt. But of course it is
kind of a pity that no one sees what steps were used to get there.

--------------------------------------------------------------------------------
api
--------------------------------------------------------------------------------

Although some symbols can be visible due to the fact that we maek them extern as
past of a code splitup, there is no api at all. Don't expect the names of the
functions and variables that this applies to to remain the same. Blame yourself
for abusing this partial exposure. The abstraction is in the \LUA\ interface and
when possible that one stays the same. Adding more and more access (callbacks)
won't happen because it has an impact on performance.

Because we want to stay close to original TeX in many aspects, the names of
functions try to match those in ttp. However, because we're now in pure C, we
have more functions (and less macros). The compiler will inline many of them,
but plenty will show up in the symbols table, when exposed. For that reason we
prefix all functions in categories so that they at least show up in groups. It
is also the reason why in for instance the optional modules code we collect all
visible locals in structs. It's all a stepwise process.

The split in tex* modules is mostly for convenience. The original program is
monolithic (you can get an idea when you look at mp.c) so in a sense they should
all be seen as a whole. As a consequence we have tex_run_* as externals as well
as locals. It's just an on-purpose side effect, not a matter of inconsistency:
there is no tex api.

--------------------------------------------------------------------------------
todo (ongoing)
--------------------------------------------------------------------------------

-  All errors and warnings (lua|tex|fatal) have to be checked; what is critital
   and what not.
-  I need to figure out why filetime differs between msvc and mingw (daylight
   correction probably).
-  Nested runtime measurement is currently not working on unix (but it works ok
   on microsoft windows).
-  I will check the manual for obsolete, removed and added functionality. This
   is an ongoing effort.
-  Eventually I might do some more cleanup of the mp*.w code. For now we keep
   w files, but who knows ...
-  A bit more reshuffling of functions to functional units is possible but that
   happens stepwise as it's easy to introduce bug(let)s. I will occasionally go
   over all code.
-  I might turn some more macros into functions (needs some reshuffling too)
   because it's nicer wrt tracing issues. When we started with LuaTeX macros
   made more sense but compilers got better. In the meantime whole program
   optimization works okay, but we cannot do that when one also wants to load
   modules.
-  A side track of the lack of stripping (see previous note) is that we need to
   namespace locals more agressive ... most is done.
-  We can clean up the dependency chain i.e. header files and such but this is
   a long term activity. It's also not that important.
-  Maybe nodememoryword vs tokenmemoryword so that the compiler can warn for a
   mixup.
-  Remove some more (also cosmetic) side effects of mp library conversion.
-  Replace some more of the print* chains by the more compact print_format call
   (no hurry with that one).
-  The naming between modules (token, tex, node) of functions is (historically)
   a bit inconsistent (getfoo, get_foo etc) so I might make that better. It does
   have some impact on compatibility but one can alias (we can provide a file).
-  Some more interface related code might get abstracted (much already done).
-  I don't mention other (either or not already rejected) ideas and experiments
   here (like pushing/popping pagebuilder states which is messy and also demands
   too much from the macro package end.)
-  Stepwise I'll make the complete split of command codes (chr) and subtypes.
   This is mostly done but there are some leftovers. It also means that we no
   longer are completely in sync with the internal original \TEX\ naming but I'll
   try to remain close.
-  The glyph and math scale features do not yet check for overflow of maxdimen
   but I'll add some more checks and/or impose some limitations on the scale
   values. We have to keep in mind that TeX itself also hapilly accepts some
   wrap around because it doesn't really crash the engine; it just can have side
   effects.

--------------------------------------------------------------------------------
todo (second phase)
--------------------------------------------------------------------------------

Ideally we'd like to see more local variables (like some cur_val and such) but
it's kind of tricky because these globals are all over the place and sometimes
get saved and restored (so that needs careful checking), and sometimes such a
variable is expected to be set in a nested call. It also spoils the (still
mostly original) documentation. So, some will happen, some won't. I actually
tested some rather drastic localization and even with tripple checking there
were side effects, so I reverted that. (We probably end up with a mix that
shows the intention.)

Anyway, there are (and will be) some changes (return values instead of accessing
global) that give a bit less code on the one hand (and therefore look somewhat
cleaner) but are not always more efficient. It's all a matter of taste.

I'm on and off looking at the files and their internal documentation and in the
process rename some variables, do some extra checking, and remove unused code.
This is a bit random activity that I started doing pending the first official
release.

Now that the math engine has been partly redone the question is: should we keep
the font related control options? They might go away at some point and even
support for traditional eight bit fonts might be dropped. We'll see about that.

That is: we saw about it. End 2021 and beginning of 2022 Mikael Sundqvist and I
spent quite a few months on playing around with new features: more classes, inter
atom spacing, inter atom penalties, atom rules, a few more FontParameters, a bit
more control on top of what we already had, etc. In the end some of the control
already present became standardized in a way that now prefers OpenType fonts.
Persistent issues with fonts are now dealt with on a per font basis in ConteXt
using existing as well as new tweaking features. We started talking micro math
typography. Old fonts are still supported but one has to configure the engine
with respecty to the used technology. Another side effect is that we now store
math character specifications in nodes instead of a number.

It makes sense to simplify delimiters (just make them a mathchar) and get rid of 
the large family and char. These next in size and extensibles are to be related
anyway so one can always make a (runtime) virtual font. The main problem is that 
we then need to refactor some tex (format) code too becuase we no longer have 
delimiters there too.

--------------------------------------------------------------------------------
dependencies
--------------------------------------------------------------------------------

There are no depencies on code outside this tree and we keep it that way. If you
follow the TeXLive (LuaTeX) source update you'll notice that there are quite
often updates of libraries and sometimes they give (initial) issues when being
compiled, also because there can be further dependencies on compilers as well as
libraries specific to a (version of) an operating system. This is not something
that users should be bothered with.

Optional libraries are really optional and although an API can change we will
not include related code in the formal LuaMetaTeX code base. We might offer some
in the build farm (for building libraries) but that is not a formal dependency.
We will of course adapt code to changes in API's but also never provide more
than a minimal interface: use Lua when more is needed.

We keep in sync with Lua development, also because we consider LuaMetaTeX to be
a nice test case. We never really have issues with Lua anyway. Maybe at some
point I will replace the socket related code. The mimalloc libraries used gives
a performance boost but we could do without. The build cerf library might be
replaced by an optional but it also depends on the complex datatype being more
mature: there is now a fundamental difference between compilers so we have a
patched version; the code doesn't change anyway, so maybe it can be stripped.

In practice there have been hardly any updates to the libraries that we do use:
most changes are in auxiliary programs and make files anyway. When there is an
update (most are on github) this is what happens:

-- check out code
-- compare used subset (like /src) with working copy
-- merge with working copy if it makes sense (otherwise delay)
-- test for a while (local compilation etc.)
-- compare used subset again, this time with local repository
-- merge with local repository
-- push update to the build farm

So, each change is checked twice which in practice doesn't take much time but
gives a good idea of the kind of changes. So far we never had to roll back.

We still use CWEB formatting for MetaPost which then involves a conversion to C
code but the C code is included. This removes a depedency on the WEB toolchain.
The Lua based converter that is part of this source tree works quite well for
our purpose (and also gives nicer code).

We don't do any architecture (CPU) or operating system specific optimizations,
simply because there is no real gain for LuaMetaTeX. It would only introduce
issues, a more complex build, dependencies on assembly generators, etc. which
is a no-go.

--------------------------------------------------------------------------------
team / responsibilities
--------------------------------------------------------------------------------

The LuaTeX code base is part of the ConTeXt code base. That way we can guarantee
its working with the ConTeXt macro package and also experiment as much as we
like without harming this package. The ConTeXt code is maintained by Hans Hagen
and Wolfgang Schuster with of course help and input from others (those who are
on the mailing list will have no problem identifying who). Because we see the
LuaMetaTeX code as part of that effort, starting with its more or less official
release (version 2.05, early 2020), Hans and Wolfgang will be responsible for
the code (knowing that we can always fall back on Taco) and explore further
possibilities. Mojca Miklavec handles the compile farm, coordinates the
distributions, deals with integration in TeXLive, etc. Alan Braslau is the first
line tester so that in an early stage we can identify issues with for TeX,
MetaPost, Lua and compilation on the different platforms that users have.

If you run into problems with LuaMetaTeX, the ConTeXt mailing list is the place
to go to: ntg-context@ntg.nl. Of course you can also communicate LuaTeX problems
there, especially when you suspect that both engines share it, but for specific
LuaTeX issues there is dev-luatex@ntg.nl where the LuaTeX team can help you
further.

This (mid 2018 - begin 2020) is the first stage of the development. Before we
move on, we (read: users) will first test the current implementation more
extensively over a longer period of time, something that is really needed because
there are lots of accumulated changes, and I would not be surprised if subtle
issues have been introduced. In the meantime we will discuss how to follow up.

The version in the distribution is always tested with the ConteXt test suite,
which hopefully uncovers issues before users notice.

Stay tuned!
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
ConTeXt websites : http://contextgarden.net http://www.pragma-ade.nl
Development list : dev-context@ntg.nl
Support list     : context@ntg.nl
User groups      : http://ntg.nl http://tug.org etc
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
Hans Hagen       : j.hagen@xs4all.nl
--------------------------------------------------------------------------------
