return {
    internals = {
        --
        "nocolormodel", "greycolormodel", "graycolormodel", "rgbcolormodel", "cmykcolormodel",
        "shadefactor", "shadeoffset",
        "textextoffset", "textextanchor",
        "normaltransparent", "multiplytransparent", "screentransparent", "overlaytransparent",
        "softlighttransparent", "hardlighttransparent", "colordodgetransparent", "colorburntransparent",
        "darkentransparent", "lightentransparent", "differencetransparent", "exclusiontransparent",
        "huetransparent", "saturationtransparent", "colortransparent", "luminositytransparent",
     -- "originlength", "tickstep ", "ticklength",
     -- "autoarrows", "ahfactor",
     -- "angleoffset", anglelength", anglemethod",
        "ahvariant", "ahdimple", "ahfactor", "ahscale",
        "metapostversion",
        "maxdimensions",
        "drawoptionsfactor",
        "dq", "sq",
        "crossingscale", "crossingoption",
        "contextlmtxmode", "metafunversion", "minifunversion",
        --
        -- for the moment we put these here as they need to stand out
        --
        "getparameters",
        "presetparameters",
        "hasparameter",
        "hasoption",
        "getparameter",
        "getparameterdefault",
        "getparametercount",
        "getmaxparametercount",
        "getparameterpath",
        "getparameterpen",
        "getparametertext",
     -- "getparameteroption",
        "applyparameters",
        "pushparameters",
        "popparameters",
        "definecolor",
        --
        "newrecord", "setrecord", "getrecord",
        --
        "anchorxy", "anchorx", "anchory",
        "anchorht", "anchordp",
        "anchorul", "anchorll", "anchorlr", "anchorur",
        "localanchorbox", "localanchorcell", "localanchorspan",
        "anchorbox", "anchorcell", "anchorspan",
        "matrixbox", "matrixcell", "matrixspan",
    },
    commands = {
        "loadfile", "loadimage", "loadmodule",
        "dispose", "nothing", "transparency", "tolist", "topath", "tocycle",
        --
        "sqr", "log", "ln", "exp", "inv", "pow", "pi", "radian",
        "tand", "cotd", "sin", "cos", "tan", "cot", "atan", "asin", "acos",
        "invsin", "invcos", "invtan", "acosh", "asinh", "sinh", "cosh", "tanh",
        "zmod",
        "paired", "tripled",
        "unitcircle", "fulldiamond", "unitdiamond", "fullsquare", "unittriangle", "fulltriangle",
     -- "halfcircle", "quartercircle",
        "llcircle", "lrcircle", "urcircle", "ulcircle",
        "tcircle", "bcircle", "lcircle", "rcircle",
        "lltriangle", "lrtriangle", "urtriangle", "ultriangle",
        "uptriangle", "downtriangle", "lefttriangle", "righttriangle", "triangle",
        "smoothed", "cornered", "superellipsed", "randomized", "randomizedcontrols", "squeezed", "enlonged", "shortened",
        "punked", "curved", "unspiked", "simplified", "blownup", "stretched",
        "enlarged", "leftenlarged", "topenlarged", "rightenlarged", "bottomenlarged",
        "crossed", "laddered", "randomshifted", "interpolated", "perpendicular", "paralleled", "cutends", "peepholed",
        "llenlarged", "lrenlarged", "urenlarged", "ulenlarged",
        "llmoved", "lrmoved", "urmoved", "ulmoved",
        "rightarrow", "leftarrow", "centerarrow", "drawdoublearrows",
        "boundingbox", "innerboundingbox", "outerboundingbox", "pushboundingbox", "popboundingbox",
        "boundingradius", "boundingcircle", "boundingpoint",
        "crossingunder", "insideof", "outsideof",
        "bottomboundary", "leftboundary", "topboundary", "rightboundary",
        "xsized", "ysized", "xysized", "sized", "xyscaled",
        "intersection_point", "intersection_found", "penpoint",
        "bbwidth", "bbheight",
        "withshade", "withcircularshade", "withlinearshade", -- old but kept
        "defineshade", "shaded",
     -- "withshading", "withlinearshading", "withcircularshading", "withfromshadecolor", "withtoshadecolor",
        "shadedinto", "withshadecolors",
        "withshadedomain", "withshademethod", "withshadefactor", "withshadevector",
        "withshadecenter", "withshadedirection", "withshaderadius", "withshadetransform", "withshadecenterone", "withshadecentertwo",
        "withshadestep", "withshadefraction", "withshadeorigin", "shownshadevector", "shownshadeorigin",
        "shownshadedirection", "shownshadecenter",
        "cmyk", "spotcolor", "multitonecolor", "namedcolor",
        "drawfill", "undrawfill",
        "inverted", "uncolored", "softened", "grayed", "greyed",
        "onlayer",
        "along",
        "graphictext", "loadfigure", "externalfigure", "figure", "register",
        "outlinetext", "filloutlinetext", "drawoutlinetext", "outlinetexttopath",
        "checkedbounds", "checkbounds", "strut", "rule",
        "withmask", "bitmapimage",
        "colordecimals", "ddecimal", "dddecimal", "ddddecimal", "colordecimalslist",
        "textext", "thetextext", "rawtextext", "textextoffset", "texbox", "thetexbox", "rawtexbox", "istextext",
        "rawmadetext", "validtexbox", "onetimetextext", "rawfmttext", "thefmttext", "fmttext", "onetimefmttext",
        "notcached", "keepcached",
        "verbatim",
        "thelabel", "label",
        "autoalign",
        "transparent", "withtransparency", "withopacity",
        "property", "properties", "withproperties",
        "asgroup",
        "withpattern", "withpatternscale", "withpatternfloat",
        "infont", -- redefined using textext
     -- "set_linear_vector", "set_circular_vector",
     -- "linear_shade", "circular_shade",
     -- "define_linear_shade", "define_circular_shade",
     -- "define_circular_linear_shade", "define_circular_linear_shade",
     -- "define_sampled_linear_shade", "define_sampled_circular_shade",
        "space", "crlf", "dquote", "percent", "SPACE", "CRLF", "DQUOTE", "PERCENT",
        "grayscale", "greyscale", "withgray", "withgrey",
        "colorpart", "colorlike",
        "readfile",
        "clearxy", "unitvector", "center", -- redefined
        "epsed", "anchored",
        "originpath", "infinite",
        "break",
        "xstretched", "ystretched", "snapped",
        --
        "pathconnectors", "function",
        "constructedfunction", "constructedpath", "constructedpairs",
     -- "punkedfunction", "punkedpath", "punkedpairs",
        "straightfunction", "straightpath", "straightpairs",
        "curvedfunction", "curvedpath", "curvedpairs",
     -- "tightfunction", "tightpath", "tightpairs",
        --
        "evenly", "oddly",
        --
        "condition",
        --
        "pushcurrentpicture", "popcurrentpicture",
        --
        "arrowpath", "resetarrows",
     -- "colorlike",  "dowithpath", "rangepath", "straightpath", "addbackground",
     -- "cleanstring", "asciistring", "setunstringed", "getunstringed", "unstringed",
     -- "showgrid",
     -- "phantom",
     -- "xshifted", "yshifted",
     -- "drawarrowpath", "midarrowhead", "arrowheadonpath",
     -- "drawxticks", "drawyticks", "drawticks",
     -- "pointarrow",
     -- "thefreelabel", "freelabel", "freedotlabel",
     -- "anglebetween", "colorcircle",
     -- "remapcolors", "normalcolors", "resetcolormap", "remapcolor", "remappedcolor",
     -- "recolor", "refill", "redraw", "retext", "untext", "restroke", "reprocess", "repathed",
        "tensecircle", "roundedsquare",
        "colortype", "whitecolor", "blackcolor", "basiccolors", "complementary", "complemented",
        "resolvedcolor",
        --
     -- "swappointlabels",
        "normalfill", "normaldraw", "visualizepaths", "detailpaths", "naturalizepaths",
        "drawboundary", "drawwholepath", "drawpathonly",
        "visualizeddraw", "visualizedfill", "detaileddraw",
        "draworigin", "drawboundingbox",
        "drawpath",
        "drawpoint", "drawpoints", "drawcontrolpoints", "drawcontrollines",
        "drawpointlabels",
        "drawlineoptions", "drawpointoptions", "drawcontroloptions", "drawlabeloptions",
        "draworiginoptions", "drawboundoptions", "drawpathoptions", "resetdrawoptions",
        --
        "undashed", "pencilled",
        --
        "decorated", "redecorated", "undecorated",
        --
        "passvariable", "passarrayvariable", "tostring", "topair", "format", "formatted", "quotation", "quote",
        "startpassingvariable", "stoppassingvariable",
        --
        "eofill", "eoclip", "nofill", "dofill", "fillup", "eofillup", "nodraw", "dodraw",
        "area",
        --
        "addbackground",
        --
        "shadedup", "shadeddown", "shadedleft", "shadedright",
        --
        "sortlist", "copylist", "shapedlist", "listtocurves", "listtolines", "listsize", "listlast", "uniquelist",
        --
        "circularpath", "squarepath", "linearpath",
        --
        "theoffset",
        --
        "texmode", "systemmode",
        "texvar", "texstr",
        "isarray", "prefix", "dimension",
        "getmacro", "getdimen", "getcount", "gettoks",
        "setmacro", "setdimen", "setcount", "settoks",
        "setglobalmacro", "setglobaldimen", "setglobalcount", "setglobaltoks",
        --
        "positionpath", "positioncurve", "positionxy", "positionpxy",
        "positionwhd", "positionpage", "positionregion", "positionbox",
        "positionanchor", "positioninregion", "positionatanchor",
        --
        "wdpart", "htpart", "dppart",
        --
        "texvar", "texstr",
        --
        "inpath", "pointof", "leftof", "rightof",
        --
        "utfnum", "utflen", "utfsub",
        --
        "newhash", "disposehash", "inhash", "tohash",
        --
        "isarray", "prefix", "isobject",
        --
        "comment", "report", "lua", "lualist", "mp", "MP", "luacall",
        --
        "mirrored", "mirroredabout",
        --
        "scriptindex", "newscriptindex",
        --
        "newcolor", "newrgbcolor", "newcmykcolor",
        "newnumeric", "newboolean", "newtransform", "newpath", "newpicture", "newstring", "newpair",
        --
        "mpvard", "mpvarn", "mpvars", "mpvar",
        --
        "withtolerance",
        --
    },
}
