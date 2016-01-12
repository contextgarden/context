%D \module
%D   [       file=demo-symbols.mp,
%D        version=2013.09.06,
%D          title=\CONTEXT\ \METAPOST\ graphics,
%D       subtitle=demo font,
%D         author=Hans Hagen,
%D           date=\currentdate,
%D      copyright={PRAGMA ADE \& \CONTEXT\ Development Team}]
%C
%C This module is part of the \CONTEXT\ macro||package and is
%C therefore copyrighted by \PRAGMA. See mreadme.pdf for
%C details.

passvariable("fontname","demo-symbols") ;
passvariable("fontversion","1.005") ;

beginglyph(9754,2,4,0) ; % high voltage
    interim ahlength := 1 ;
    drawarrow (1,4) -- (0,2) -- (2,3) -- (1,0) withcolor darkred ;
endglyph ;

