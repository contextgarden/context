-- Many bibtex databases are poluted. This is a side effect of 7 bit encoding on the
-- one hand and tweaking the outcome at the other. The worst examples are the use
-- of \rlap on whole names. We found that trying to cope with all can one drive insane
-- so we stopped at some point. Clean up your mess or pay the price. But, you can load
-- this file (and similar ones) to help you out. There is simply no reward in trying
-- to deal with it ourselves.

return {
    name         = "replacements",
    version      = "1.00",
    comment      = "Good riddance",
    author       = "Alan Braslau and Hans Hagen",
    copyright    = "ConTeXt development team",
    replacements = {
        [ [[\emdash]] ] = "—",
        [ [[\endash]] ] = "–",
        [ [[{\emdash}]] ] = "—",
        [ [[{\endash}]] ] = "–",
        [ [[Th\^e\llap{\raise 0.5ex\hbox{\'{\relax}}}]] ] = "Thánh",
        [ [[Th{\^e}\llap{\raise0.5ex\hbox{\'{\relax}}}]] ] = "Thánh",
        [ [[Th{\^e}\llap{\raise 0.5ex\hbox{\'{\relax}}}]] ] = "Thánh",
    },
}
