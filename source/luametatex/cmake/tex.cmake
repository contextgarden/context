set(tex_sources

    source/utilities/auxmemory.c
    source/utilities/auxzlib.c
    source/utilities/auxsparsearray.c
    source/utilities/auxsystem.c
    source/utilities/auxunistring.c
    source/utilities/auxfile.c

    source/libraries/hnj/hnjhyphen.c

    source/lua/lmtinterface.c
    source/lua/lmtlibrary.c
    source/lua/lmtcallbacklib.c
    source/lua/lmtlanguagelib.c
    source/lua/lmtlualib.c
    source/lua/lmtluaclib.c
    source/lua/lmttexiolib.c
    source/lua/lmttexlib.c
    source/lua/lmttokenlib.c
    source/lua/lmtnodelib.c
    source/lua/lmtenginelib.c
    source/lua/lmtfontlib.c
    source/lua/lmtstatuslib.c

    source/luaoptional/lmtoptional.c

    source/luarest/lmtfilelib.c
    source/luarest/lmtpdfelib.c
    source/luarest/lmtiolibext.c
    source/luarest/lmtoslibext.c
    source/luarest/lmtstrlibext.c
    source/luarest/lmtdecodelib.c
    source/luarest/lmtsha2lib.c
    source/luarest/lmtmd5lib.c
    source/luarest/lmtaeslib.c
    source/luarest/lmtbasexxlib.c
    source/luarest/lmtxmathlib.c
    source/luarest/lmtxcomplexlib.c
    source/luarest/lmtziplib.c
    source/luarest/lmtsparselib.c

    source/tex/texalign.c
    source/tex/texarithmetic.c
    source/tex/texbuildpage.c
    source/tex/texcommands.c
    source/tex/texconditional.c
    source/tex/texdirections.c
    source/tex/texdumpdata.c
    source/tex/texequivalents.c
    source/tex/texerrors.c
    source/tex/texexpand.c
    source/tex/texmarks.c
    source/tex/texinputstack.c
    source/tex/texinserts.c
    source/tex/texadjust.c
    source/tex/texlinebreak.c
    source/tex/texlocalboxes.c
    source/tex/texmainbody.c
    source/tex/texmaincontrol.c
    source/tex/texmathcodes.c
    source/tex/texmlist.c
    source/tex/texnesting.c
    source/tex/texpackaging.c
    source/tex/texprimitive.c
    source/tex/texprinting.c
    source/tex/texscanning.c
    source/tex/texstringpool.c
    source/tex/textypes.c
    source/tex/texfont.c
    source/tex/texlanguage.c
    source/tex/texfileio.c
    source/tex/texmath.c
    source/tex/texnodes.c
    source/tex/textextcodes.c
    source/tex/textoken.c
    source/tex/texrules.c

)

add_library(tex STATIC ${tex_sources})

target_compile_definitions(tex PUBLIC
  # LUAI_HASHLIMIT=6 # obsolete
    ZLIB_CONST=1
    MINIZ_NO_ARCHIVE_APIS=1
    MINIZ_NO_STDIO=1
    MINIZ_NO_MALLOC=1
)

target_include_directories(tex PRIVATE
    .
    source/.
    source/libraries/miniz
    source/libraries/pplib
    source/libraries/pplib/util
    source/luacore/lua54/src
    source/libraries/mimalloc/include
)
