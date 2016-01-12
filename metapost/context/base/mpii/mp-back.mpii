%D \module
%D   [       file=mp-back.mp,
%D        version=2000.05.31,
%D          title=\CONTEXT\ \METAPOST\ graphics,
%D       subtitle=backgrounds,
%D         author=Hans Hagen,
%D           date=\currentdate,
%D      copyright={PRAGMA / Hans Hagen \& Ton Otten}]
%C
%C This module is part of the \CONTEXT\ macro||package and is
%C therefore copyrighted by \PRAGMA. See licen-en.pdf for
%C details.

if known context_back : endinput ; fi ;

boolean context_back ; context_back := true ;

def some_hash ( expr hash_width     ,
                     hash_height    ,
                     hash_linewidth ,
                     hash_linecolor ,
                     hash_angle     ,
                     hash_gap       ) =

  stripe_gap := hash_gap ;
  stripe_angle := hash_angle ;
  drawoptions (withpen pencircle scaled hash_linewidth
               withcolor hash_linecolor) ;
  path p ; p := unitsquare xscaled hash_width yscaled hash_height ;
  stripe_path_a () (draw) p ;  % next we move it all to quadrant 1
  currentpicture := currentpicture shifted urcorner currentpicture ;

enddef ;

def some_double_back (expr back_type        ,
                           back_width       ,
                           back_height      ,
                           back_delta       ,
                           back_linewidth   ,
                           back_linecolor   ,
                           back_fillcolor   ,
                           back_topcolor    ,
                           back_bottomcolor ,
                           back_leftcolor   ,
                           back_rightcolor  ) =

  numeric ww ; ww := back_width  ;
  numeric hh ; hh := back_height ;
  numeric dd ; dd := back_delta  ;

  color back_nillcolor ; back_nillcolor := back_topcolor ;

  path p ; p := fullsquare xscaled  ww      yscaled  hh      ;
  path q ; q := fullsquare xscaled (ww-2dd) yscaled (hh-2dd) ;
  path r ; r := llcorner p --
                lrcorner p shifted (-3dd,0) .. controls lrcorner p ..
                lrcorner p shifted (0, 3dd) --
                urcorner p shifted (0,-3dd) .. controls urcorner p ..
                urcorner p shifted (-3dd,0) --
                ulcorner p -- cycle ;
  path s ; s := r xscaled ((ww-2dd)/ww) yscaled ((hh-2dd)/hh) ;
  path t ; t := llcorner p --
                lrcorner p --
                urcorner p shifted (0,-3dd) .. controls urcorner p ..
                urcorner p shifted (-3dd,0) --
                ulcorner p shifted ( 3dd,0) .. controls ulcorner p ..
                ulcorner p shifted (0,-3dd) --
                llcorner p -- cycle ;
  path u ; u := t xscaled ((ww-2dd)/ww) yscaled ((hh-2dd)/hh) ;
  path v ; v := llcorner p shifted ( 3dd,0) --
                lrcorner p shifted (-3dd,0) .. controls lrcorner p ..
                lrcorner p shifted (0, 3dd) --
                urcorner p shifted (0,-3dd) .. controls urcorner p ..
                urcorner p shifted (-3dd,0) --
                ulcorner p shifted ( 3dd,0) .. controls ulcorner p ..
                ulcorner p shifted (0,-3dd) ..
                llcorner p shifted (0, 3dd) .. controls llcorner p .. cycle ; % {down}  .. cycle ;
  path w ; w := t xscaled ((ww-2dd)/ww) yscaled ((hh-2dd)/hh) ;
  path a ; a := llcorner p -- ulcorner p --
                ulcorner q -- llcorner q -- cycle ;
  path b ; b := llcorner p -- lrcorner p --
                lrcorner q -- llcorner q -- cycle ;
  path c ; c := lrcorner p -- urcorner p --
                urcorner q -- lrcorner q -- cycle ;
  path d ; d := ulcorner p -- urcorner p --
                urcorner q -- ulcorner q -- cycle ;
  path e ; e := llcorner p -- lrcorner p --
                urcorner p -- urcorner q --
                lrcorner q -- llcorner q -- cycle ;
  path f ; f := llcorner p -- ulcorner p --
                urcorner p -- urcorner q --
                ulcorner q -- llcorner q -- cycle ;

  linecap := butt ; pickup pencircle scaled back_linewidth ;

  if back_type=1 :

    fill p withcolor back_fillcolor   ;
    fill a withcolor back_leftcolor   ;
    fill b withcolor back_bottomcolor ;
    fill c withcolor back_rightcolor  ;
    fill d withcolor back_topcolor    ;
    draw a withcolor back_linecolor   ;
    draw d withcolor back_linecolor   ;
    draw b withcolor back_linecolor   ;
    draw c withcolor back_linecolor   ;

  elseif back_type=2 :

    fill p withcolor back_fillcolor   ;
    fill e withcolor back_bottomcolor ;
    fill f withcolor back_topcolor    ;
    draw e withcolor back_linecolor   ;
    draw f withcolor back_linecolor   ;

  elseif back_type=3 :

    fill v withcolor back_nillcolor   ;
    fill w withcolor back_fillcolor   ;
    draw v withcolor back_linecolor   ;
    draw w withcolor back_linecolor   ;

  elseif back_type=4 :

    fill t withcolor back_nillcolor   ;
    fill u withcolor back_fillcolor   ;
    draw t withcolor back_linecolor   ;
    draw u withcolor back_linecolor   ;

  elseif back_type=5 :

    t := t rotatedaround(center t,180) ;
    u := u rotatedaround(center u,180) ;

    fill t withcolor back_nillcolor   ;
    fill u withcolor back_fillcolor   ;
    draw t withcolor back_linecolor   ;
    draw u withcolor back_linecolor   ;

  elseif back_type=6 :

    r := r rotatedaround(center r,180) ;
    s := s rotatedaround(center s,180) ;

    fill r withcolor back_nillcolor   ;
    fill s withcolor back_fillcolor   ;
    draw r withcolor back_linecolor   ;
    draw s withcolor back_linecolor   ;

  elseif back_type=7 :

    fill r withcolor back_nillcolor   ;
    fill s withcolor back_fillcolor   ;
    draw r withcolor back_linecolor   ;
    draw s withcolor back_linecolor   ;

fi ;

enddef ;

endinput ;

beginfig (1) ;

some_double_back (1, 4.5cm, 1.5cm, .25cm, 1mm,
           .5white, .8white, .7white, .6white, .7white, .6white)

currentpicture := currentpicture shifted (0,-3cm) ;

some_double_back (2, 4.5cm, 1.5cm, .25cm, 1mm,
           .5white, .8white, .7white, .6white, white, white)

currentpicture := currentpicture shifted (0,-3cm) ;

some_double_back (3, 4.5cm, 1.5cm, .25cm, 1mm,
           .5white, .8white, .7white, white, white, white)

currentpicture := currentpicture shifted (0,-3cm) ;

some_double_back (4, 4.5cm, 1.5cm, .25cm, 1mm,
           .5white, .8white, .7white, white, white, white)

currentpicture := currentpicture shifted (0,-3cm) ;

some_double_back (5, 4.5cm, 1.5cm, .25cm, 1mm,
           .5white, .8white, .7white, white, white, white)

currentpicture := currentpicture shifted (0,-3cm) ;

some_double_back (6, 4.5cm, 1.5cm, .25cm, 1mm,
           .5white, .8white, .7white, white, white, white)

currentpicture := currentpicture shifted (0,-3cm) ;

some_double_back (7, 4.5cm, 1.5cm, .25cm, 1mm,
           .5white, .8white, .7white, white, white, white)

currentpicture := currentpicture shifted (0,-3cm) ;

some_double_back (8, 4.5cm, 1.5cm, .25cm, 1mm,
           .5white, .8white, .7white, white, white, white)

endfig ;

end .
