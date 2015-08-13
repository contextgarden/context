%!PS-Adobe-3.0 EPSF-3.0
%%Creator: Mayura Draw, Version 4.3
%%Title: fig-page-parameters-en.md
%%CreationDate: Fri Jan 10 17:04:54 2014
%%BoundingBox: 8 230 580 790
%%DocumentFonts: ArialMT
%%Orientation: Portrait
%%EndComments
%%BeginProlog
%%BeginResource: procset MayuraDraw_ops
%%Version: 4.3
%%Copyright: (c) 1993-2003 Mayura Software
/PDXDict 100 dict def
PDXDict begin
% width height matrix proc key cache
% definepattern -\> font
/definepattern { %def
  7 dict begin
    /FontDict 9 dict def
    FontDict begin
      /cache exch def
      /key exch def
      /proc exch cvx def
      /mtx exch matrix invertmatrix def
      /height exch def
      /width exch def
      /ctm matrix currentmatrix def
      /ptm matrix identmatrix def
      /str
      (xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx)
      def
    end
    /FontBBox [ %def
      0 0 FontDict /width get
      FontDict /height get
    ] def
    /FontMatrix FontDict /mtx get def
    /Encoding StandardEncoding def
    /FontType 3 def
    /BuildChar { %def
      pop begin
      FontDict begin
        width 0 cache { %ifelse
          0 0 width height setcachedevice
        }{ %else
          setcharwidth
        } ifelse
        0 0 moveto width 0 lineto
        width height lineto 0 height lineto
        closepath clip newpath
        gsave proc grestore
      end end
    } def
    FontDict /key get currentdict definefont
  end
} bind def

% dict patternpath -
% dict matrix patternpath -
/patternpath { %def
  dup type /dicttype eq { %ifelse
    begin FontDict /ctm get setmatrix
  }{ %else
    exch begin FontDict /ctm get setmatrix
    concat
  } ifelse
  currentdict setfont
  FontDict begin
    FontMatrix concat
    width 0 dtransform
    round width div exch round width div exch
    0 height dtransform
    round height div exch
    round height div exch
    0 0 transform round exch round exch
    ptm astore setmatrix

    pathbbox
    height div ceiling height mul 4 1 roll
    width div ceiling width mul 4 1 roll
    height div floor height mul 4 1 roll
    width div floor width mul 4 1 roll

    2 index sub height div ceiling cvi exch
    3 index sub width div ceiling cvi exch
    4 2 roll moveto

    FontMatrix ptm invertmatrix pop
    { %repeat
      gsave
        ptm concat
        dup str length idiv { %repeat
          str show
        } repeat
        dup str length mod str exch
        0 exch getinterval show
      grestore
      0 height rmoveto
    } repeat
    pop
  end end
} bind def

% dict patternfill -
% dict matrix patternfill -
/patternfill { %def
  gsave
    eoclip patternpath
  grestore
  newpath
} bind def

/img { %def
  gsave
  /imgh exch def
  /imgw exch def
  concat
  imgw imgh 8
  [imgw 0 0 imgh neg 0 imgh]
  /colorstr 768 string def
  /colorimage where {
    pop
    { currentfile colorstr readhexstring pop }
    false 3 colorimage
  }{
    /graystr 256 string def
    {
      currentfile colorstr readhexstring pop
      length 3 idiv
      dup 1 sub 0 1 3 -1 roll
      {
        graystr exch
        colorstr 1 index 3 mul get 30 mul
        colorstr 2 index 3 mul 1 add get 59 mul
        colorstr 3 index 3 mul 2 add get 11 mul
        add add 100 idiv
        put
      } for
      graystr 0 3 -1 roll getinterval
    } image
  } ifelse
  grestore
} bind def

/arrowhead {
  gsave
    [] 0 setdash
    strokeC strokeM strokeY strokeK setcmykcolor
    2 copy moveto
    4 2 roll exch 4 -1 roll exch
    sub 3 1 roll sub
    exch atan rotate dup scale
    arrowtype
    dup 0 eq {
      -1 2 rlineto 7 -2 rlineto -7 -2 rlineto
      closepath fill
    } if
    dup 1 eq {
      0 3 rlineto 9 -3 rlineto -9 -3 rlineto
      closepath fill
    } if
    dup 2 eq {
      -6 -6 rmoveto 6 6 rlineto -6 6 rlineto
      -1.4142 -1.4142 rlineto 4.5858 -4.5858 rlineto
      -4.5858 -4.5858 rlineto closepath fill
    } if
    dup 3 eq {
      -6 0 rmoveto -1 2 rlineto 7 -2 rlineto -7 -2 rlineto
      closepath fill
    } if
    dup 4 eq {
      -9 0 rmoveto 0 3 rlineto 9 -3 rlineto -9 -3 rlineto
      closepath fill
    } if
    dup 5 eq {
      currentpoint newpath 3 0 360 arc
      closepath fill
    } if
    dup 6 eq {
      2.5 2.5 rmoveto 0 -5 rlineto -5 0 rlineto 0 5 rlineto
      closepath fill
    } if
    pop
  grestore
} bind def

/setcmykcolor where { %ifelse
  pop
}{ %else
  /setcmykcolor {
     /black exch def /yellow exch def
     /magenta exch def /cyan exch def
     cyan black add dup 1 gt { pop 1 } if 1 exch sub
     magenta black add dup 1 gt { pop 1 } if 1 exch sub
     yellow black add dup 1 gt { pop 1 } if 1 exch sub
     setrgbcolor
  } bind def
} ifelse

/RE { %def
  findfont begin
  currentdict dup length dict begin
    { %forall
      1 index /FID ne { def } { pop pop } ifelse
    } forall
    /FontName exch def dup length 0 ne { %if
      /Encoding Encoding 256 array copy def
      0 exch { %forall
        dup type /nametype eq { %ifelse
          Encoding 2 index 2 index put
          pop 1 add
        }{ %else
          exch pop
        } ifelse
      } forall
    } if pop
  currentdict dup end end
  /FontName get exch definefont pop
} bind def

/spacecount { %def
  0 exch
  ( ) { %loop
    search { %ifelse
      pop 3 -1 roll 1 add 3 1 roll
    }{ pop exit } ifelse
  } loop
} bind def

/WinAnsiEncoding [
  39/quotesingle 96/grave 130/quotesinglbase/florin/quotedblbase
  /ellipsis/dagger/daggerdbl/circumflex/perthousand
  /Scaron/guilsinglleft/OE 145/quoteleft/quoteright
  /quotedblleft/quotedblright/bullet/endash/emdash
  /tilde/trademark/scaron/guilsinglright/oe/dotlessi
  159/Ydieresis 164/currency 166/brokenbar 168/dieresis/copyright
  /ordfeminine 172/logicalnot 174/registered/macron/ring
  177/plusminus/twosuperior/threesuperior/acute/mu
  183/periodcentered/cedilla/onesuperior/ordmasculine
  188/onequarter/onehalf/threequarters 192/Agrave/Aacute
  /Acircumflex/Atilde/Adieresis/Aring/AE/Ccedilla
  /Egrave/Eacute/Ecircumflex/Edieresis/Igrave/Iacute
  /Icircumflex/Idieresis/Eth/Ntilde/Ograve/Oacute
  /Ocircumflex/Otilde/Odieresis/multiply/Oslash
  /Ugrave/Uacute/Ucircumflex/Udieresis/Yacute/Thorn
  /germandbls/agrave/aacute/acircumflex/atilde/adieresis
  /aring/ae/ccedilla/egrave/eacute/ecircumflex
  /edieresis/igrave/iacute/icircumflex/idieresis
  /eth/ntilde/ograve/oacute/ocircumflex/otilde
  /odieresis/divide/oslash/ugrave/uacute/ucircumflex
  /udieresis/yacute/thorn/ydieresis
] def

/SymbolEncoding [
  32/space/exclam/universal/numbersign/existential/percent
  /ampersand/suchthat/parenleft/parenright/asteriskmath/plus
  /comma/minus/period/slash/zero/one/two/three/four/five/six
  /seven/eight/nine/colon/semicolon/less/equal/greater/question
  /congruent/Alpha/Beta/Chi/Delta/Epsilon/Phi/Gamma/Eta/Iota
  /theta1/Kappa/Lambda/Mu/Nu/Omicron/Pi/Theta/Rho/Sigma/Tau
  /Upsilon/sigma1/Omega/Xi/Psi/Zeta/bracketleft/therefore
  /bracketright/perpendicular/underscore/radicalex/alpha
  /beta/chi/delta/epsilon/phi/gamma/eta/iota/phi1/kappa/lambda
  /mu/nu/omicron/pi/theta/rho/sigma/tau/upsilon/omega1/omega
  /xi/psi/zeta/braceleft/bar/braceright/similar
  161/Upsilon1/minute/lessequal/fraction/infinity/florin/club
  /diamond/heart/spade/arrowboth/arrowleft/arrowup/arrowright
  /arrowdown/degree/plusminus/second/greaterequal/multiply
  /proportional/partialdiff/bullet/divide/notequal/equivalence
  /approxequal/ellipsis/arrowvertex/arrowhorizex/carriagereturn
  /aleph/Ifraktur/Rfraktur/weierstrass/circlemultiply
  /circleplus/emptyset/intersection/union/propersuperset
  /reflexsuperset/notsubset/propersubset/reflexsubset/element
  /notelement/angle/gradient/registerserif/copyrightserif
  /trademarkserif/product/radical/dotmath/logicalnot/logicaland
  /logicalor/arrowdblboth/arrowdblleft/arrowdblup/arrowdblright
  /arrowdbldown/lozenge/angleleft/registersans/copyrightsans
  /trademarksans/summation/parenlefttp/parenleftex/parenleftbt
  /bracketlefttp/bracketleftex/bracketleftbt/bracelefttp
  /braceleftmid/braceleftbt/braceex
  241/angleright/integral/integraltp/integralex/integralbt
  /parenrighttp/parenrightex/parenrightbt/bracketrighttp
  /bracketrightex/bracketrightbt/bracerighttp/bracerightmid
  /bracerightbt
] def

/patarray [
/leftdiagonal /rightdiagonal /crossdiagonal /horizontal
/vertical /crosshatch /fishscale /wave /brick
] def
/arrowtype 0 def
/fillC 0 def /fillM 0 def /fillY 0 def /fillK 0 def
/strokeC 0 def /strokeM 0 def /strokeY 0 def /strokeK 1 def
/pattern -1 def
/mat matrix def
/mat2 matrix def
/nesting 0 def
/deferred /N def
/c /curveto load def
/c2 { pop pop c } bind def
/C /curveto load def
/C2 { pop pop C } bind def
/e { gsave concat 0 0 moveto } bind def
/F {
  nesting 0 eq { %ifelse
    pattern -1 eq { %ifelse
      fillC fillM fillY fillK setcmykcolor eofill
    }{ %else
      gsave fillC fillM fillY fillK setcmykcolor eofill grestore
      0 0 0 1 setcmykcolor
      patarray pattern get findfont patternfill
    } ifelse
  }{ %else
    /deferred /F def
  } ifelse
} bind def
/f { closepath F } bind def
/K { /strokeK exch def /strokeY exch def
     /strokeM exch def /strokeC exch def } bind def
/k { /fillK exch def /fillY exch def
     /fillM exch def /fillC exch def } bind def
/opc { pop } bind def
/Opc { pop } bind def
/L /lineto load def
/L2 { pop pop L } bind def
/m /moveto load def
/m2 { pop pop m } bind def
/n /newpath load def
/N {
  nesting 0 eq { %ifelse
    newpath
  }{ %else
    /deferred /N def
  } ifelse
} def
/S {
  nesting 0 eq { %ifelse
    strokeC strokeM strokeY strokeK setcmykcolor stroke
  }{ %else
    /deferred /S def
  } ifelse
} bind def
/s { closepath S } bind def
/Tx { fillC fillM fillY fillK setcmykcolor show
      0 leading neg translate 0 0 moveto } bind def
/T { grestore } bind def
/TX { pop } bind def
/Ts { pop } bind def
/tal { pop } bind def
/tld { pop } bind def
/tbx { pop exch pop sub /jwidth exch def } def
/tpt { %def
  fillC fillM fillY fillK setcmykcolor
  moveto show
} bind def
/tpj { %def
  fillC fillM fillY fillK setcmykcolor
  moveto
  dup stringwidth pop
  3 -1 roll
  exch sub
  1 index spacecount
  dup 0 eq { %ifelse
    pop pop show
  }{ %else
    div 0 8#040 4 -1 roll widthshow
  } ifelse
} bind def
/u {} def
/U {} def
/*u { /nesting nesting 1 add def } def
/*U {
  /nesting nesting 1 sub def
  nesting 0 eq {
    deferred cvx exec
  } if
} def
/w /setlinewidth load def
/d /setdash load def
/B {
  nesting 0 eq { %ifelse
    gsave F grestore S
  }{ %else
    /deferred /B def
  } ifelse
} bind def
/b { closepath B } bind def
/z { /align exch def pop /leading exch def exch findfont
     exch scalefont setfont } bind def
/tfn { exch findfont
     exch scalefont setfont } bind def
/Pat { /pattern exch def } bind def
/cm { 6 array astore concat } bind def
/q { mat2 currentmatrix pop } bind def
/Q { mat2 setmatrix } bind def
/Ah {
  pop /arrowtype exch def
  currentlinewidth 5 1 roll arrowhead
} bind def
/Arc {
  mat currentmatrix pop
    translate scale 0 0 1 5 -2 roll arc
  mat setmatrix
} bind def
/Arc2 { pop pop Arc } bind def
/Bx {
  mat currentmatrix pop
    concat /y1 exch def /x1 exch def /y2 exch def /x2 exch def
    x1 y1 moveto x1 y2 lineto x2 y2 lineto x2 y1 lineto
  mat setmatrix
} bind def
/Rr {
  mat currentmatrix pop
    concat /yrad exch def /xrad exch def
    2 copy gt { exch } if /x2 exch def /x1 exch def
    2 copy gt { exch } if /y2 exch def /y1 exch def
    x1 xrad add y2 moveto
    matrix currentmatrix x1 xrad add y2 yrad sub translate xrad yrad scale
    0 0 1 90 -180 arc setmatrix
    matrix currentmatrix x1 xrad add y1 yrad add translate xrad yrad scale
    0 0 1 180 270 arc setmatrix
    matrix currentmatrix x2 xrad sub y1 yrad add translate xrad yrad scale
    0 0 1 270 0 arc setmatrix
    matrix currentmatrix x2 xrad sub y2 yrad sub translate xrad yrad scale
    0 0 1 0 90 arc setmatrix
    closepath
  mat setmatrix
} bind def
/Ov {
  mat currentmatrix pop
    concat translate scale 1 0 moveto 0 0 1 0 360 arc closepath
  mat setmatrix
} bind def
end
%%EndResource
%%EndProlog
%%BeginSetup
%PDX g 3 3 1 1
%%IncludeFont: ArialMT
PDXDict begin
%%EndSetup
%%Page: 1 1
%%BeginPageSetup
/_PDX_savepage save def

15 15 [300 72 div 0 0 300 72 div 0 0]
{ %definepattern
  2 setlinecap
  7.5 0 moveto 15 7.5 lineto
  0 7.5 moveto 7.5 15 lineto
  2 setlinewidth stroke
} bind
/rightdiagonal true definepattern pop

15 15 [300 72 div 0 0 300 72 div 0 0]
{ %definepattern
  2 setlinecap
  7.5 0 moveto 0 7.5 lineto
  15 7.5 moveto 7.5 15 lineto
  2 setlinewidth stroke
} bind
/leftdiagonal true definepattern pop

15 15 [300 72 div 0 0 300 72 div 0 0]
{ %definepattern
  2 setlinecap
  0 7.5 moveto 15 7.5 lineto
  2 setlinewidth stroke
} bind
/horizontal true definepattern pop

15 15 [300 72 div 0 0 300 72 div 0 0]
{ %definepattern
  2 setlinecap
  7.5 0 moveto 7.5 15 lineto
  2 setlinewidth stroke
} bind
/vertical true definepattern pop

15 15 [300 72 div 0 0 300 72 div 0 0]
{ %definepattern
  2 setlinecap
  0 7.5 moveto 15 7.5 lineto
  7.5 0 moveto 7.5 15 lineto
  2 setlinewidth stroke
} bind
/crosshatch true definepattern pop

30 30 [300 72 div 0 0 300 72 div 0 0]
{ %definepattern
  2 setlinecap
  0 7.5 moveto 30 7.5 lineto
  0 22.5 moveto 30 22.5 lineto
  7.5 0 moveto 7.5 7.5 lineto
  7.5 22.5 moveto 7.5 30 lineto
  22.5 7.5 moveto 22.5 22.5 lineto
  1 setlinewidth stroke
} bind
/brick true definepattern pop

30 30 [300 72 div 0 0 300 72 div 0 0]
{ %definepattern
  2 2 scale
  2 setlinecap
  7.5 0 moveto 15 7.5 lineto
  0 7.5 moveto 7.5 15 lineto
  7.5 0 moveto 0 7.5 lineto
  15 7.5 moveto 7.5 15 lineto
  0.5 setlinewidth stroke
} bind
/crossdiagonal true definepattern pop

30 30 [300 72 div 0 0 300 72 div 0 0]
{ %definepattern
  2 2 scale
  1 setlinecap
  0 7.5 moveto 0 15 7.5 270 360 arc
  7.5 15 moveto 15 15 7.5 180 270 arc
  0 7.5 moveto 7.5 7.5 7.5 180 360 arc
  0.5 setlinewidth stroke
} bind
/fishscale true definepattern pop

30 30 [300 72 div 0 0 300 72 div 0 0]
{ %definepattern
  1 setlinecap 0.5 setlinewidth
  7.5 0 10.6 135 45 arcn
  22.5 15 10.6 225 315 arc
  stroke
  7.5 15 10.6 135 45 arcn
  22.5 30 10.6 225 315 arc
  stroke
} bind
/wave true definepattern pop

WinAnsiEncoding /_ArialMT /ArialMT RE

newpath 2 setlinecap 0 setlinejoin 2 setmiterlimit
[] 0 setdash
8 230 moveto 8 790 lineto 580 790 lineto 580 230 lineto closepath clip
newpath
%%EndPageSetup
0.862745 0.956863 -1.42109e-016 0 K
2 w
543 249 -9 789 [1 0 0 1 27 -9] Bx
s
0.133333 0.133333 0.133333 0 k
0.133333 0.133333 0.133333 0 K
0.5 w
150 480 90 510 [1 0 0 1 -15 180] Bx
b
150 480 90 510 [1 0 0 1 60.33 180] Bx
b
150 480 90 510 [1 0 0 1 299.8 180] Bx
b
240 480 90 510 [1 0 0 1 135 180] Bx
b
150 480 90 510 [1 0 0 1 375.3 180] Bx
b
[1 0 0 1 15.05 0.702] e
33 681 33 681 tbx
0 tal
13 tld
1 1 1 0 k
/_ArialMT 12 tfn
(top) 33 670.14 tpt
T
0.133333 0.133333 0.133333 0 k
150 480 90 510 [1 0 0 1 -15 135] Bx
b
150 480 90 510 [1 0 0 1 60 135] Bx
b
150 480 90 510 [1 0 0 1 300 135] Bx
b
240 480 90 510 [1 0 0 1 135 135] Bx
b
150 480 90 510 [1 0 0 1 375 135] Bx
b
[1 0 0 1 -5.627 6.702] e
33 630 33 630 tbx
0 tal
13 tld
1 1 1 0 k
/_ArialMT 12 tfn
(header) 33 619.14 tpt
T
0.133333 0.133333 0.133333 0 k
150 480 90 510 [1 0 0 1 -15 -90.7] Bx
b
150 480 90 510 [1 0 0 1 60 -90.7] Bx
b
150 480 90 510 [1 0 0 1 300 -90.7] Bx
b
240 480 90 510 [1 0 0 1 135 -90.7] Bx
b
150 480 90 510 [1 0 0 1 375 -90.7] Bx
b
[1 0 0 1 1.045 9] e
33 402 33 402 tbx
0 tal
13 tld
1 1 1 0 k
/_ArialMT 12 tfn
(footer) 33 391.14 tpt
T
0.133333 0.133333 0.133333 0 k
150 480 90 510 [1 0 0 1 -15 -135] Bx
b
150 480 90 510 [1 0 0 1 60 -135] Bx
b
150 480 90 510 [1 0 0 1 300 -135] Bx
b
240 480 90 510 [1 0 0 1 135 -135] Bx
b
150 480 90 510 [1 0 0 1 375 -135] Bx
b
[1 0 0 1 -7.957 3.702] e
36 363 36 363 tbx
0 tal
13 tld
1 1 1 0 k
/_ArialMT 12 tfn
(bottom) 36 352.14 tpt
T
0.133333 0.133333 0.133333 0 k
150 345 90 510 [1 0 0 1 -15 90] Bx
b
150 345 90 510 [1 0 0 1 60 90] Bx
b
150 345 90 510 [1 0 0 1 300 90] Bx
b
-1.42109e-016 0.4 0.8 0 k
240 345 90 510 [1 0 0 1 135 90] Bx
b
0.133333 0.133333 0.133333 0 k
150 345 90 510 [1 0 0 1 375 90] Bx
b
[1 0 0 1 21.38 17.2] e
24 507 24 507 tbx
0 tal
13 tld
1 1 1 0 k
/_ArialMT 12 tfn
(text) 24 496.14 tpt
T
[1 0 0 1 -11.02 51.19] e
93 705 93 705 tbx
0 tal
13 tld
/_ArialMT 12 tfn
(left edge) 93 694.14 tpt
T
[1 0 0 1 -4.5 48.19] e
159 708 159 708 tbx
0 tal
13 tld
/_ArialMT 12 tfn
(left margin) 159 697.14 tpt
T
[1 0 0 1 17.33 51.19] e
273 705 273 705 tbx
0 tal
13 tld
/_ArialMT 12 tfn
(text) 273 694.14 tpt
T
[1 0 0 1 -13.87 54.19] e
402 702 402 702 tbx
0 tal
13 tld
/_ArialMT 12 tfn
(right margin) 402 691.14 tpt
T
[1 0 0 1 -11.34 51.19] e
480 705 480 705 tbx
0 tal
13 tld
/_ArialMT 12 tfn
(right edge) 480 694.14 tpt
T
[1 0 0 1 -13.64 0.702] e
75 352.596 39 366 tbx
0 tal
13 tld
/_ArialMT 12 tfn
() 39 355.14 tpt
T
-1.42109e-016 -1.42109e-016 -1.42109e-016 0 k
1 1 1 0 K
1 w
q
1 0 0 1 91.45 14.02 cm
150 712 150 720 m2
150 638 150 630 L2
Q
S
q
1 0 0 1 91.45 14.02 cm
150 630 150 720 4 1 Ah
150 720 150 630 4 2 Ah
Q
q
1 0 0 1 165 -30 cm
150 712 150 720 m2
150 698 150 690 L2
Q
S
q
1 0 0 1 165 -30 cm
150 690 150 720 4 1 Ah
150 720 150 690 4 2 Ah
Q
q
1 0 0 1 -47.91 0 cm
130.909 705 122.909 705 m2
265 705 273 705 L2
Q
S
q
1 0 0 1 -47.91 0 cm
273 705 122.909 705 4 1 Ah
122.909 705 273 705 4 2 Ah
Q
q
1 0 0 1 -45 -150 cm
128 705 120 705 m2
172 705 180 705 L2
Q
S
q
1 0 0 1 -45 -150 cm
180 705 120 705 4 1 Ah
120 705 180 705 4 2 Ah
Q
0.25 w
q
1 0 0 1 0.09051 53.27 cm
225 660 m
225 645 L
Q
S
q
1 0 0 1 6.094 0 cm
228 645 m
243 645 L
Q
S
[1 0 0 1 -2.909 66] e
126 654 126 654 tbx
0 tal
13 tld
1 1 1 0 k
/_ArialMT 12 tfn
(backspace) 126 643.14 tpt
T
[1 0 0 1 -9 30] e
255 690 255 690 tbx
0 tal
13 tld
/_ArialMT 12 tfn
(topspace) 255 679.14 tpt
T
-1.42109e-016 -1.42109e-016 -1.42109e-016 0 k
1 w
q
1 0 0 1 29.91 -210 cm
128 705 120 705 m2
172 705 180 705 L2
Q
S
q
1 0 0 1 29.91 -210 cm
180 705 120 705 4 1 Ah
120 705 180 705 4 2 Ah
Q
q
1 0 0 1 270 -210 cm
128 705 120 705 m2
172 705 180 705 L2
Q
S
q
1 0 0 1 270 -210 cm
180 705 120 705 4 1 Ah
120 705 180 705 4 2 Ah
Q
q
1 0 0 1 345 -150 cm
128 705 120 705 m2
172 705 180 705 L2
Q
S
q
1 0 0 1 345 -150 cm
180 705 120 705 4 1 Ah
120 705 180 705 4 2 Ah
Q
q
1 0 0 1 165 -75 cm
150 712 150 720 m2
150 698 150 690 L2
Q
S
q
1 0 0 1 165 -75 cm
150 690 150 720 4 1 Ah
150 720 150 690 4 2 Ah
Q
q
1 0 0 1 165 -300 cm
150 712 150 720 m2
150 698 150 690 L2
Q
S
q
1 0 0 1 165 -300 cm
150 690 150 720 4 1 Ah
150 720 150 690 4 2 Ah
Q
q
1 0 0 1 165 -345 cm
150 712 150 720 m2
150 698 150 690 L2
Q
S
q
1 0 0 1 165 -345 cm
150 690 150 720 4 1 Ah
150 720 150 690 4 2 Ah
Q
0.862745 0.956863 -1.42109e-016 0 K
2 w
q
1 0 0 1 104.9 -150 cm
136 705 120 705 m2
254.094 705 270.094 705 L2
Q
S
q
1 0 0 1 104.9 -150 cm
270.094 705 120 705 4 1 Ah
120 705 270.094 705 4 2 Ah
Q
q
1 0 0 1 105 -118.5 cm
150 747.547 150 763.547 m2
150 524.547 150 508.547 L2
Q
S
q
1 0 0 1 105 -118.5 cm
150 508.547 150 763.547 4 1 Ah
150 763.547 150 508.547 4 2 Ah
Q
[1 0 0 1 -3 6.702] e
324 675 324 675 tbx
0 tal
13 tld
1 1 1 0 k
/_ArialMT 12 tfn
(top) 324 664.14 tpt
T
[1 0 0 1 -3 3.702] e
324 633 324 633 tbx
0 tal
13 tld
/_ArialMT 12 tfn
(header) 324 622.14 tpt
T
[1 0 0 1 0 0] e
261 498 261 498 tbx
0 tal
13 tld
0.862745 0.956863 -1.42109e-016 0 k
/_ArialMT 12 tfn
(height) 261 487.14 tpt
T
[1 0 0 1 -14.05 7.406] e
291 564 291 564 tbx
0 tal
13 tld
/_ArialMT 12 tfn
(width) 291 553.14 tpt
T
[1 0 0 1 0 9.702] e
321 402 321 402 tbx
0 tal
13 tld
1 1 1 0 k
/_ArialMT 12 tfn
(footer) 321 391.14 tpt
T
[1 0 0 1 0 9.702] e
321 357 321 357 tbx
0 tal
13 tld
/_ArialMT 12 tfn
(bottom) 321 346.14 tpt
T
[1 0 0 1 -0.348 7.5] e
84 564 84 564 tbx
0 tal
13 tld
/_ArialMT 12 tfn
(leftedge) 84 553.14 tpt
T
[1 0 0 1 -13.08 4.359] e
168 507 168 507 tbx
0 tal
13 tld
/_ArialMT 12 tfn
(leftmargin) 168 496.14 tpt
T
[1 0 0 1 -17.44 7.359] e
408 504 408 504 tbx
0 tal
13 tld
/_ArialMT 12 tfn
(rightmargin) 408 493.14 tpt
T
[1 0 0 1 -13.01 7.5] e
483 564 483 564 tbx
0 tal
13 tld
/_ArialMT 12 tfn
(rightedge) 483 553.14 tpt
T
-1.42109e-016 -1.42109e-016 -1.42109e-016 0 k
1 1 1 0 K
1 w
q
1 0 0 1 165 -120 cm
150 712 150 720 m2
150 563 150 555 L2
Q
S
q
1 0 0 1 165 -120 cm
150 555 150 720 4 1 Ah
150 720 150 555 4 2 Ah
Q
[1 0 0 1 0 0] e
402 460.596 333 474 tbx
0 tal
13 tld
1 1 1 0 k
/_ArialMT 12 tfn
() 333 463.14 tpt
T
[1 0 0 1 -33 15.64] e
354 468 354 468 tbx
0 tal
13 tld
/_ArialMT 12 tfn
(textheight) 354 457.14 tpt
T
u
-1.42109e-016 -1.42109e-016 -1.42109e-016 0 k
0.5 w
q
1 0 0 1 255 -60 cm
150 716 150 720 m2
150 709 150 705 L2
Q
S
q
1 0 0 1 255 -60 cm
150 705 150 720 4 1 Ah
150 720 150 705 4 2 Ah
Q
[1 0 0 1 -2.33 7.659] e
411 651 411 651 tbx
0 tal
11 tld
1 1 1 0 k
/_ArialMT 10 tfn
(topdistance) 411 641.95 tpt
T
U
-1.42109e-016 -1.42109e-016 -1.42109e-016 0 k
q
1 0 0 1 255 -105 cm
150 716 150 720 m2
150 709 150 705 L2
Q
S
q
1 0 0 1 255 -105 cm
150 705 150 720 4 1 Ah
150 720 150 705 4 2 Ah
Q
[1 0 0 1 -2.33 -37.34] e
411 651 411 651 tbx
0 tal
11 tld
1 1 1 0 k
/_ArialMT 10 tfn
(headerdistance) 411 641.95 tpt
T
-1.42109e-016 -1.42109e-016 -1.42109e-016 0 k
q
1 0 0 1 255 -285 cm
150 716 150 720 m2
150 709 150 705 L2
Q
S
q
1 0 0 1 255 -285 cm
150 705 150 720 4 1 Ah
150 720 150 705 4 2 Ah
Q
[1 0 0 1 -2.33 -217.3] e
411 651 411 651 tbx
0 tal
11 tld
1 1 1 0 k
/_ArialMT 10 tfn
(footerdistance) 411 641.95 tpt
T
-1.42109e-016 -1.42109e-016 -1.42109e-016 0 k
q
1 0 0 1 255 -330 cm
150 716 150 720 m2
150 709 150 705 L2
Q
S
q
1 0 0 1 255 -330 cm
150 705 150 720 4 1 Ah
150 720 150 705 4 2 Ah
Q
[1 0 0 1 -2.33 -262.3] e
411 651 411 651 tbx
0 tal
11 tld
1 1 1 0 k
/_ArialMT 10 tfn
(bottomdistance) 411 641.95 tpt
T
u
-1.42109e-016 -1.42109e-016 -1.42109e-016 0 k
q
1 0 0 1 45 0 cm
109 330 105 330 m2
120 330 L
Q
S
q
1 0 0 1 45 0 cm
120 330 105 330 4 1 Ah
Q
q
1 0 0 1 30 0 cm
101 330 105 330 m2
90 330 L
Q
S
q
1 0 0 1 30 0 cm
90 330 105 330 4 1 Ah
Q
U
u
q
1 0 0 1 120 -15 cm
109 330 105 330 m2
120 330 L
Q
S
q
1 0 0 1 120 -15 cm
120 330 105 330 4 1 Ah
Q
q
1 0 0 1 105 -15 cm
101 330 105 330 m2
90 330 L
Q
S
q
1 0 0 1 105 -15 cm
90 330 105 330 4 1 Ah
Q
U
u
q
1 0 0 1 285 -15 cm
109 330 105 330 m2
120 330 L
Q
S
q
1 0 0 1 285 -15 cm
120 330 105 330 4 1 Ah
Q
q
1 0 0 1 270 -15 cm
101 330 105 330 m2
90 330 L
Q
S
q
1 0 0 1 270 -15 cm
90 330 105 330 4 1 Ah
Q
U
u
q
1 0 0 1 360 0 cm
109 330 105 330 m2
120 330 L
Q
S
q
1 0 0 1 360 0 cm
120 330 105 330 4 1 Ah
Q
q
1 0 0 1 345 0 cm
101 330 105 330 m2
90 330 L
Q
S
q
1 0 0 1 345 0 cm
90 330 105 330 4 1 Ah
Q
U
[1 0 0 1 -15 5.998] e
123 321 123 321 tbx
0 tal
11 tld
1 1 1 0 k
/_ArialMT 10 tfn
(leftedgedistance) 123 311.95 tpt
T
[1 0 0 1 -36 9.633] e
300.14 291.83 219 303 tbx
0 tal
11 tld
/_ArialMT 10 tfn
(leftmargindistance) 219 293.95 tpt
T
[1 0 0 1 120.2 8.906] e
306.25 291.83 219 303 tbx
0 tal
11 tld
/_ArialMT 10 tfn
(rightmargindistance) 219 293.95 tpt
T
[1 0 0 1 -27 8.998] e
450 318 450 318 tbx
0 tal
11 tld
/_ArialMT 10 tfn
(rightedgedistance) 450 308.95 tpt
T
[1 0 0 1 -6 58.55] e
183 246.83 120 258 tbx
0 tal
11 tld
/_ArialMT 10 tfn
(edgedistance) 120 248.95 tpt
T
[1 0 0 1 18 53.27] e
171 249 171 249 tbx
0 tal
11 tld
/_ArialMT 10 tfn
(margindistance) 171 239.95 tpt
T
[1 0 0 1 180 53.27] e
171 249 171 249 tbx
0 tal
11 tld
/_ArialMT 10 tfn
(margindistance) 171 239.95 tpt
T
[1 0 0 1 312 58.55] e
183 246.83 120 258 tbx
0 tal
11 tld
/_ArialMT 10 tfn
(edgedistance) 120 248.95 tpt
T
u
-1.42109e-016 -1.42109e-016 -1.42109e-016 0 k
1 w
q
1 0 0 1 -15 0 cm
60 285 m
90 285 L
Q
S
q
1 0 0 1 0 0 cm
75 285 m
75 255 L
Q
S
U
u
q
-1 0 0 1 615 0 cm
60 285 m
90 285 L
Q
S
q
-1 0 0 1 600 0 cm
75 285 m
75 255 L
Q
S
U
u
q
0 -1 -1 0 810 825 cm
60 285 m
90 285 L
Q
S
q
0 -1 -1 0 810 810 cm
75 285 m
75 255 L
Q
S
U
u
q
0 -1 1 0 -210 825 cm
60 285 m
90 285 L
Q
S
q
0 -1 1 0 -210 810 cm
75 285 m
75 255 L
Q
S
U
0.5 w
[3 3] 0 d
525 735 75 285 [1 0 0 1 0 0] Bx
s
1 w
[] 0 d
q
1 0 0 1 -45.09 -435 cm
128 705 120 705 m2
562.094 705 570.094 705 L2
Q
S
q
1 0 0 1 -45.09 -435 cm
570.094 705 120 705 4 1 Ah
120 705 570.094 705 4 2 Ah
Q
[1 0 0 1 0 0] e
271.57 246.83 246 258 tbx
0 tal
11 tld
0.862745 0.956863 -1.42109e-016 0 k
/_ArialMT 10 tfn
() 246 248.95 tpt
T
[1 0 0 1 0 0] e
261 255 261 255 tbx
0 tal
11 tld
1 1 1 0 k
/_ArialMT 10 tfn
() 261 245.95 tpt
T
[1 0 0 1 9.607 12.09] e
261 255 261 255 tbx
0 tal
13 tld
/_ArialMT 12 tfn
(paperwidth) 261 244.14 tpt
T
-1.42109e-016 -1.42109e-016 -1.42109e-016 0 k
q
0 1 -1 0 1244 164.3 cm
128 705 120 705 m2
562.094 705 570.094 705 L2
Q
S
q
0 1 -1 0 1244 164.3 cm
570.094 705 120 705 4 1 Ah
120 705 570.094 705 4 2 Ah
Q
[0 1 -1 0 797.2 219] e
261 255 261 255 tbx
0 tal
13 tld
1 1 1 0 k
/_ArialMT 12 tfn
(paperheight) 261 244.14 tpt
T
[1 0 0 1 -12 12] e
285 540 285 540 tbx
0 tal
13 tld
/_ArialMT 12 tfn
(textwidth) 285 529.14 tpt
T
[1 0 0 1 0 12] e
90 540 90 540 tbx
0 tal
13 tld
/_ArialMT 12 tfn
(edge) 90 529.14 tpt
T
[1 0 0 1 0 9] e
162 483 162 483 tbx
0 tal
13 tld
/_ArialMT 12 tfn
(margin) 162 472.14 tpt
T
[1 0 0 1 -6.336 12] e
408 480 408 480 tbx
0 tal
13 tld
/_ArialMT 12 tfn
(margin) 408 469.14 tpt
T
[1 0 0 1 -6 18] e
489 534 489 534 tbx
0 tal
13 tld
/_ArialMT 12 tfn
(edge) 489 523.14 tpt
T
-1.42109e-016 -1.42109e-016 -1.42109e-016 0 k
q
1 0 0 1 252.1 0 cm
130.909 705 122.909 705 m2
265 705 273 705 L2
Q
S
q
1 0 0 1 252.1 0 cm
273 705 122.909 705 4 1 Ah
122.909 705 273 705 4 2 Ah
Q
0.25 w
q
1 0 0 1 150.1 52.55 cm
225 660 m
225 645 L
Q
S
[1 0 0 1 297.1 66] e
126 654 126 654 tbx
0 tal
13 tld
1 1 1 0 k
/_ArialMT 12 tfn
(cutspace) 126 643.14 tpt
T
%%PageTrailer
_PDX_savepage restore
%%Trailer
end
showpage
%%EOF
