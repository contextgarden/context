%D \module
%D   [       file=bidi-symbols.mp,
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

passvariable("fontname","bidi-symbols") ;
passvariable("fontversion","1.009") ;

numeric font_bidi_dp ; font_bidi_dp := -6 ;
numeric font_bidi_wd ; font_bidi_wd := -12 ;

% beginfig(1) ; % lre
%     charcode := 8234 ; charwd := 0 ; charht := 0 ; chardp := 0 ;
%     drawarrow (0,0) -- (0,font_bidi_dp) -- (font_bidi_wd,font_bidi_dp) withcolor red ;
%     currentpicture := currentpicture scaled charscale ;
%     setbounds currentpicture to boundingbox nullpicture ;
% endfig ;
%
% beginfig(2) ; % rle
%     charcode := 8235 ; charwd := 0 ; charht := 0 ; chardp := 0 ;
%     drawarrow (0,0) -- (0,font_bidi_dp) -- (-font_bidi_wd,font_bidi_dp) withcolor green ;
%     currentpicture := currentpicture scaled charscale ;
%     setbounds currentpicture to boundingbox nullpicture ;
% endfig ;
%
% beginfig(3) ; % pdf
%     charcode := 8236 ; charwd := 0 ; charht := 0 ; chardp := 0 ;
%     draw (0,0) -- (0,font_bidi_dp) -- (-font_bidi_wd/2,font_bidi_dp) -- (font_bidi_wd/2,font_bidi_dp) withcolor blue ;
%     currentpicture := currentpicture scaled charscale ;
%     setbounds currentpicture to boundingbox nullpicture ;
% endfig ;
%
% beginfig(4) ; % lro
%     charcode := 8237 ; charwd := 0 ; charht := 0 ; chardp := 0 ;
%     drawarrow reverse ((0,0) -- (0,font_bidi_dp) -- (font_bidi_wd,font_bidi_dp)) withcolor red ;
%     currentpicture := currentpicture scaled charscale ;
%     setbounds currentpicture to boundingbox nullpicture ;
% endfig ;
%
% beginfig(5) ; % rlo
%     charcode := 8238 ; charwd := 0 ; charht := 0 ; chardp := 0 ;
%     drawarrow reverse ((0,0) -- (0,font_bidi_dp) -- (-font_bidi_wd,font_bidi_dp)) withcolor green ;
%     currentpicture := currentpicture scaled charscale ;
%     setbounds currentpicture to boundingbox nullpicture ;
% endfig ;

beginglyph(8234,0,0,0) ; % lre
    drawarrow (0,0) -- (0,font_bidi_dp) -- (font_bidi_wd,font_bidi_dp) withcolor red ;
endglyph ;

beginglyph(8235,0,0,0) ; % rle
    drawarrow (0,0) -- (0,font_bidi_dp) -- (-font_bidi_wd,font_bidi_dp) withcolor green ;
endglyph ;

beginglyph(8236,0,0,0) ; % pdf
    draw (0,0) -- (0,font_bidi_dp) -- (-font_bidi_wd/2,font_bidi_dp) -- (font_bidi_wd/2,font_bidi_dp) withcolor blue ;
endglyph ;

beginglyph(8237,0,0,0) ; % lro
    drawarrow reverse ((0,0) -- (0,font_bidi_dp) -- (font_bidi_wd,font_bidi_dp)) withcolor red ;
endglyph ;

beginglyph(8238,0,0,0) ; % rlo
    drawarrow reverse ((0,0) -- (0,font_bidi_dp) -- (-font_bidi_wd,font_bidi_dp)) withcolor green ;
endglyph ;
