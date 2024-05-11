Remark

Usage of the avl library (irr) showed up in pdfTeX when Hartmut added some functionality. It therefore
also ended up in being used in LuaTeX. The two files avl.c and avl.h come from pyavl and are in the 
public domain:

  license: this package, pyavl, is donated to the public domain
  author : Richard McGraw
  email  : dasnar@fastmail.fm

In the pdfTeX/LuaTeX the files were just there but I could track them down to 

  https://github.com/pankajp/pyavl

where the dates indicate that nothing has changed in the meantime. In the copies used here I added the 
information mentioned above. The files had some (experimental) code as well as optional testing on NULL 
values. As I don't expect updates (the code has been okay for quite a while) I made the tests mandate 
and removed the experimental code. 

We can strip this library and save some 10K on the binary because we don't need that much of it. That 
might happen at some point. 

Hans Hagen 