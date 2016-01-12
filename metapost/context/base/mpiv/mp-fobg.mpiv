%D \module
%D   [       file=mp-fobg.mp,
%D        version=2004.03.12,
%D          title=\CONTEXT\ \METAPOST\ graphics,
%D       subtitle=Formatting Objects,
%D         author=Hans Hagen,
%D           date=\currentdate,
%D      copyright={PRAGMA / Hans Hagen \& Ton Otten}]
%C
%C This module is part of the \CONTEXT\ macro||package and is
%C therefore copyrighted by \PRAGMA. See licen-en.pdf for
%C details.

if known context_fobg : endinput ; fi ;

boolean context_fobg ; context_fobg := true ;

FoNone   := 0 ; FoHidden := 1 ; FoDotted := 2 ; FoDashed := 3 ; FoSolid  := 4 ;
FoDouble := 5 ; FoGroove := 6 ; FoRidge  := 7 ; FoInset  := 8 ; FoOutset := 9 ;
FoAll    := 0 ; FoTop    := 1 ; FoBottom := 2 ; FoLeft   := 3 ; FoRight  := 4 ;
FoMedium := .5pt ; FoThin := FoMedium/2 ; FoThick := FoMedium*2 ;

color FoBackgroundColor, FoNoColor, FoLineColor[] ; FoNoColor := (-1,-1,-1) ;
numeric FoLineWidth[], FoLineStyle[] ;
boolean FoFrame, FoBackground, FoSplit ;

FoFrame := FoBackground := FoSplit := false ;
FoBackgroundColor := white ;
FoDashFactor := .5 ;
FoDotFactor := .375 ;

for i = FoAll upto FoRight :
  FoLineColor[i] := black ;
  FoLineWidth[i] := .5pt ;
  FoLineStyle[i] := FoNone ;
endfor ;

def DrawFoFrame(expr n, p) =
  drawoptions(withcolor FoLineColor[n] withpen pencircle scaled FoLineWidth[n]) ;
  if     FoLineStyle[n] = FoNone   :
    % nothing
  elseif FoLineStyle[n] = FoHidden :
    % nothing
  elseif FoLineStyle[n] = FoDotted :
    draw p dashed (withdots scaled (FoDotFactor*FoLineWidth[n])) ;
  elseif FoLineStyle[n] = FoDashed :
    draw p dashed (evenly scaled (FoDashFactor*FoLineWidth[n])) ;
  elseif FoLineStyle[n] = FoSolid  :
    draw p ;
  elseif FoLineStyle[n] = FoDouble :
    draw p enlarged  FoLineWidth[n] ; draw p enlarged -FoLineWidth[n] ;
  elseif FoLineStyle[n] = FoGroove :
    draw p ;
    draw p withpen pencircle scaled .5FoLineWidth[n] withcolor (inverted FoLineColor[n] softened .5) ;
  elseif FoLineStyle[n] = FoRidge  :
    draw p withcolor  (inverted FoLineColor[n] softened .5) ;
    draw p withpen pencircle scaled .5FoLineWidth[n] ;
  elseif FoLineStyle[n] = FoInset  :
    draw p ; draw p inset 2.5FoLineWidth[n] ;
  elseif FoLineStyle[n] = FoOutset :
    draw p ; draw p outset 2.5FoLineWidth[n] ;
 fi ;
enddef ;

primarydef p outset d =
  ((lrcorner p -- urcorner p -- ulcorner p -- llcorner p -- cycle)
      shifted (d*(-1,1)) cutbefore topboundary p) cutafter leftboundary p
enddef ;

primarydef p inset d =
  ((ulcorner p -- llcorner p -- lrcorner p -- urcorner p -- cycle)
      shifted (d*(1,-1)) cutbefore bottomboundary p) cutafter rightboundary p
enddef ;

vardef equalpaths(expr p, q) =
  if length(p) = length(q) :
    save ok ; boolean ok ; ok := true ;
    for i = 0 upto length(p)-1 :
      ok := ok and (round(point i of p) = round(point i of q)) ;
    endfor ;
    ok
  else :
    false
  fi
enddef ;

endinput ;
