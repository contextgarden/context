return {
    name         = "replacements",
    version      = "1.00",
    comment      = "Good riddance",
    author       = "Alan Braslau and Hans Hagen",
    copyright    = "ConTeXt development team",
    replacements = {
        [ [[Th\^e\llap{\raise0.5ex\hbox{\'{\relax}}}]] ] = "Thánh",
        [ [[Th\^e\llap{\raise 0.5ex\hbox{\'{\relax}}}]] ] = "Thánh",
        [ [[Th{\^e}\llap{\raise0.5ex\hbox{\'{\relax}}}]] ] = "Thánh",
        [ [[Th{\^e}\llap{\raise 0.5ex\hbox{\'{\relax}}}]] ] = "Thánh",
    },
}
