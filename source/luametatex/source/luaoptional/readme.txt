Nota bene,

This is the directory where optional module support ends up. Optional modules have an interface but
are not (nor will be) part of the binary. We might ship some at the context garden (like zint and
mujs) but the large one (read: with many dependencies or written in c++) have to come from the
operating system because if you use a library that is what you want: the external black box thing.
No sources end up in the distribution either, athough we will archive some.

There will be no user modules here, just those interfaces that we provide and maintain as part of
standard ConTeXt LMTX. What users add themselves is up to them, including (long time !) support. So,
this is the canonnical version of optional.

We might at some point add some safeguards so that we can be sure that ConTeXt is run with the
right binary because we want to prevent side effects (of any kind) resulting from a binary being
used with the same name and different features ... just because one of the objective is to have
a long term stable binary / macro package combination. Of course, what users do on their machines
is up to them.

It might take a while before the interfaces and way we do this is stable. Also, keep in mind that
regular users never deal with these matters directly and only use the interfaces at the TeX and
Lua end.

PS. The socket library (and maybe cerf) are also candidates for optional although cerf needs to be
compiled for windows which is not supported out of the box and sockets are way to large. We only
do optional libs that add little to the binary, a few KB at most! I'll definitely try to stick to
this principle!

PS. Todo: move function pointers into state structures.

Hans
