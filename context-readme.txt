Welcome to context,

The standalone context distribution has the following structure. Installations
like texlive use a different organization.

    tex/texmf-context                 : the files in this tree (zip)
    tex/texmf-<platform>/bin          : the tex binaries and runners
    tex/texmf-modules                 : optional user installed modules
    tex/texmf-project                 : user project files
    tex/texmf-fonts/data/<collection> : user installed fonts

There is only one binary: luametatex, two if you also have luatex, so the amount
of binary code is rather small. The mtxrun and context runners (stubs) are links
but when that doesn't work you can make copies luametatex (which is not that
large anyway). Because luametatex is also its own runner, there are no
dependencies on other binaries.

    luametatex[.exe]   : the main tex binary, also runner [around 3MB]

    mtxrun[.exe]       : a (sym)link to luametatex
    context[.exe]      : a (sym)link to luametatex

    mtxrun.lua         : the main runner code
    context.lua        : the context runner code

    luatex[.exe]       : optional

The lua files have to be alongside its runner. Wrapping a runner in some launcher
makes no sense and is not supported. The whole idea is to have one single
independent framework that is the same on all main platforms (windows, linux,
osx). The mtxrun runner also handles the other mtx-* scripts that are in the
context tree, which is why we have only a few files in the binary path. It also
reduces the risk for clashes in binary names.

An installation can be done using the installer but also by unzipping the archive
or fetching from github (contextgarden). You can, if needed, compile the binary
yourself from the includes source code.

All tex resources (smacros, styles, fonts, patterns, etc.) are located relative
to the binary path so you only need to make sure that the binary is in the path.

The project and font trees can be shared (using links) and are untouched by the
installers. By keeping fonts in the tree you retain stability, By using the
project tree you can make sure that your styles are found when you process files
outside the tex tree.

After installing you need to run 'mtxrun --generate' so that a successive
'context' run can find the files it needs.

You can get help and more information on the context garden, mailing lists and user
forums cq. platforms.
