% Remark:
%
% This file is a merge of the original punk files by Donald Knuth, who
% added this comment:
%
%   Font inspired by Gerard and Marjan Unger's lectures, Feb 1985
%
% The regular punk files are part of TeXLive and in metafont format. All
% errors introduced are ours. We also changed the encoding to unicode. In
% due time we might add a few more more characters. We still need to
% improve some of the metrics which involves a bit of trial and error. The
% font just covers basic latin shapes but in ConTeXt MkIV we add virtual
% composed shapes. There is a module m-punk.tex that implements this. This
% derivate is also used in mk.tex (mk.pdf) which is one of our tests for
% LuaTeX. We published an article on it in the MAPS (NTG magazine).
%
% 2008, Taco Hoekwater & Hans Hagen

if unknown punk_font_loaded :

    if unknown scale_factor :
        scale_factor := 1 ;
    fi ;

    boolean punk_font_loaded ;

    punk_font_loaded := true ;
    warningcheck     := 0 ;
    proofing         := 0 ;
    designsize       := 10pt#;
    font_identifier  := "Punk Nova" ; % dedicated to Don Knuth and Hermann Zapf

    ht#   :=   7pt# ; % height of characters
    u#    := 1/4pt# ; % unit width
    dev#  :=  .3pt# ; % standard deviation of punk points

    if known bold_punk :
        s#    := 1.2pt# ; % extra sidebar
        px#   :=   1pt# ; % horizontal thickness of pen
        py#   :=  .8pt# ; % vertical thickness of pen
        dot#  := 1.7pt# ; % diameter of dots
    else :
        s#    := 0      ; % extra sidebar, ok
        px#   :=  .6pt# ; % horizontal thickness of pen
        py#   :=  .5pt# ; % vertical thickness of pen
        dot#  := 1.3pt# ; % diameter of dots
    fi ;

    pt           := .1pt ;
    mag          := scale_factor * 10 ;
    bp_per_pixel := bpppix_ * mag ;

    define_pixels(u,dev) ;
    define_blacker_pixels(px,py,dot) ;
    define_whole_pixels(s) ;
    xoffset := s ;

    pickup pencircle xscaled px yscaled py ;
    punk_pen := savepen ;
    pickup pencircle scaled dot ;
    path dot_pen_path ;
    dot_pen_path := tensepath makepath currentpen ;

    defaultcolormodel := 1 ;

    if known slanted_punk :
        dot_pen_path := dot_pen_path slanted -0.25 ;
        extra_endchar := extra_endchar & "currentpicture := currentpicture slanted 0.25 ;" ;
    fi ;


    def beginpunkchar(expr c,n,h,v) = % code $c$; width is $n$ units
        hdev := h * dev ; % modify horizontal amounts of deviation
        vdev := v * dev ; % modify vertical amounts of deviation
        beginchar(c,n*u#,ht#,0) ;
        italcorr 0 ;
      % italcorr ht#*slant;
        pickup punk_pen
    enddef ;

    def ^ =
        transformed currenttransform
    enddef ;

    def makebox(text rule) =
        for y=0, h : % horizontals
            rule((-s,y)^,(w-s,y)^) ;
        endfor
        for x=-s, 0, w-2s, w-s : % verticals
            rule((x,0)^,(x,h)^) ;
        endfor
    enddef ;

    rulepen := pensquare ;

    vardef pp expr z =
        z + (hdev * normaldeviate, vdev * normaldeviate)
    enddef;

    def pd expr z = % {\bf drawdot}
        addto currentpicture contour dot_pen_path shifted z.t_ % withpen penspeck
    enddef;

    def initialize_punk_upper =
        ht# := 7pt# ; dev# := .3pt# ;
    enddef ;
    def initialize_punk_lower =
        sht# := ht#; sdev := dev;
        ht# := .6ht# ; dev := .7dev ;
    enddef ;
    def revert_punk_lower =
        ht# := sht#; dev := sdev;
    enddef ;

fi ;
