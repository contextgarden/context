About luasocket and luasec:

Till mid 2021 we had the luasec code in the source tree but it was not used yet. It requires
openssl which is pretty large and we need a bunch of header files. In order to compile luasec
we need openssl headers and unfortunately there are a few included files that one need to
make. This create a depedency unless we make a few simple ones; after all we only need it for
a few platforms. I couldn't locate a neutral header set so it never came to compilation (I
started making a set myself but could not motivate myself to finish it). We could use it as
optional library (which then demands a bit different interface). But, no matter what we
decide, we definitely don't want to compile openssl and include it in the binary. One problem
with these additional libraries is that they add more code than luametatex itself has so that
makes no sense.

For the record, an alternative is to use the more lightweight armmbed or polarssl library but
then I need either to make wrappers or adapt the luasec code.

Anyway, when we consider secure http we also enter the endless updating of protocols because
the internet is more and more wrapped in security due to lack of control over bad behaviour
and abuse around it. Plugging holes is not among the objectives of this project also because
it conflicts with long term stability of what basically is a typesetting engine.

On a positive note, when we use sockets to serve http we can hide behind a proxy, for instance
nginx is easy to set up and Lua(Meta)TeX happily sits behind it. When downloading something we
need to cache anyway so then we can as well use libcurl for which we have interfaces built in
already. If installing openssl is considered a valid option, then libcurl can hardly be seen
as a hurdle. We probably need that anyway some day in the installer and updater.

The basic socket library is quite stable. In ConTeXt the Lua files already have been 'redone'
to fit it the lot. In the code base some C files have been removed (serial and unix specific
stuff) and at some point I might decide to strip away the files and functionality that we
don't need. Occasionally there are updates to the library but in general it's rather long
term stable.

So to summarize: luasocket stayed and luasec is no longer considered as a built-in.