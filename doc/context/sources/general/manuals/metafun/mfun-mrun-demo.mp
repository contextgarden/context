%D Downloading

beginfig (1) ;

  path p, q ;

  p := (0,110)..(50,110) shifted (0,-15)..(100,110)--
       (50,50) shifted (10,0) ..(50,50) shifted (0,2.5)..
       (50,50) shifted(-10,0)--cycle ;
  q := (5,0)--(95,0)--(95,30)..(50,0) shifted (0,10)..(5,30)--cycle ;

  pickup pencircle scaled 15 ;
  drawdot (80,100) withcolor .6red ;
  drawdot (65,95) withcolor .6red ;
  drawdot (50,95) withcolor .6red ;
  drawdot (35,95) withcolor .6red ;

  drawdot (50,60) withcolor .6red ;
  drawdot (50,35) withcolor .6red ;
  drawdot (50,10) withcolor .6red ;
  drawdot (70,10) withcolor .6red ;
  drawdot (32.5,10) withcolor .6red ;

  pickup pencircle scaled 5 ;
  fill p withcolor .6green ; draw p withcolor .4green ;
  fill q withcolor .6green ; draw q withcolor .4green ;

  bboxmargin := 2.5 ; p := bbox currentpicture ;
  picture s ; s := currentpicture ; currentpicture := nullpicture ;

  pickup pencircle scaled 2.5 ;
  fill p withcolor .4blue ;
  addto currentpicture also s ;

endfig ;

%D WWW Links

beginfig (2) ;

  boolean angles [], lengths[], colors [][][] ;
  numeric a, l, r, g, b, n ;
  path p ;
  color c ;

  draw fullsquare scaled 150 withpen pencircle scaled 1 withcolor .5white ;

  n := 0 ;
  forever :
    a := 6  * round(uniformdeviate 60) ;
    l := 40 + round(uniformdeviate 60) ;
    r := 2  + round(uniformdeviate 6) ;
    g := 2  + round(uniformdeviate 6) ;
    b := 2  + round(uniformdeviate 6) ;
    if (a>0) and not known angles [a] and not known lengths[l] and not known colors [r][g][b] :
       n := n + 1 ;
       angles [a] := true ;
       lengths[l] := true ;
       colors [r][g][b] := true ;
       p := (origin--origin shifted (0,.5l)) rotatedaround(origin,a) ;
       draw               p withpen pencircle scaled 2 withcolor (r/10,g/10,b/10) ;
       drawdot point 1 of p withpen pencircle scaled 4 withcolor (r/10,g/10,b/10)  ;
       p := (origin shifted (0,.5l+8)--origin shifted(0,100))  rotatedaround(origin,a) ;
       draw               p withpen pencircle scaled 2 withcolor (r/10,g/10,b/10) ;
       drawdot point 0 of p withpen pencircle scaled 4 withcolor (r/10,g/10,b/10)  ;
    fi ;
    exitif n >= 60 ;
  endfor ;

  drawdot
    origin
    withpen pencircle scaled 10
    withcolor white ;

  fill
    ((fullcircle scaled 130) peepholed (fullsquare scaled 150))
    withcolor (1,1,1)-(1,.62,.06);

  clip currentpicture to fullsquare scaled 130 ;

endfig ;

%D Mirrors

beginfig(3)

  path a, b, p, q  ;
  pair s, t, u, v ;
  color c ;
  numeric h, w, r ;

  pickup pencircle scaled 10 ;

  h := 120 ;
  w :=  80 ;
  r :=  30 ;

  a := (0,0)..(0,.5h) shifted (-r,0)..(0,h) ;
  b := (w,0)..(w,.5h) shifted ( r,0)..(w,h) ;

  draw a withcolor .4white;
  draw b withcolor .4white;

  def moved (expr i) =
    ((i) - 10 + uniformdeviate 20)
  enddef ;

  for i=5 step 10 until h-5 :
    s := (point (length(a)*(i/h))   of a) ;
    t := (point (length(b)*(1-i/h)) of b) ;
    u := (s--t) intersectionpoint ((.25w,0)--(.25w,h)) ;
    v := (s--t) intersectionpoint ((.75w,0)--(.75w,h)) ;
    p := s..(xpart u,moved(ypart u))..(xpart v,moved(ypart v))..t ;
    c := (0,.4+uniformdeviate.55,0) ;
    l := length(p) ;
    l := .25l+uniformdeviate.5l ;
    q := p cutafter point l of p ;
    pickup pencircle scaled 2.5 ;
    draw p withcolor c ;
    pickup pencircle scaled 5 ;
    drawdot point 0 of p withcolor c ;
    drawdot point infinity of p withcolor c ;
  endfor ;

  picture s ; s := currentpicture ; currentpicture := nullpicture ;

  bboxmargin := 2.5 ; fill bbox s withcolor .85white ;

  addto currentpicture also s ;

endfig;

%D Team

def dpuppet (expr v, w) =
  v - .5w + uniformdeviate w
enddef ;

def somepuppet (expr s, r) =
  picture p ; p := currentpicture ; currentpicture := nullpicture ;
  draw ((-10,0)--(10,0)) ;
  for i:=-10 step 5 until 10 :
    draw ((i,0)--(dpuppet(i,2),-10)) ;
  endfor ;
  currentpicture := currentpicture rotated r shifted s ;
  addto currentpicture also p ;
enddef ;

def puppet (expr loc, sca, col) =
  picture s ; s := currentpicture ; currentpicture := nullpicture ;

  pair a ; a := (dpuppet( 20,5),dpuppet( 0, 5)) ;
  pair b ; b := (dpuppet(-20,5),dpuppet( 0, 5)) ;
  pair c ; c := (dpuppet( 30,5),dpuppet(60,10)) ;
  pair d ; d := (dpuppet(-30,5),dpuppet(60,10)) ;
  pair e ; e := (dpuppet(  0,5),dpuppet(30,10)) ;
  pair f ; f := (dpuppet(  0,5),dpuppet(50,10)) ;
  pair g ; g := (dpuppet(  0,5),dpuppet(65,10)) ;

  pair f ; f := (.6+uniformdeviate.1)[e,g] ;

  drawoptions (withcolor col) ;

  somepuppet(a,dpuppet(  20,5)) ;
  somepuppet(b,dpuppet( -20,5)) ;
  somepuppet(c,dpuppet( 120,5)) ;
  somepuppet(d,dpuppet(-120,5)) ;

  draw a -- e ;
  draw b -- e ;
  draw c -- f ;
  draw d -- f ;
  draw e -- g ;
  draw fullcircle scaled 25 shifted (g shifted (0,12.5));

  drawoptions () ;

  currentpicture := currentpicture scaled sca shifted loc ;
  addto currentpicture also s ;
enddef ;

beginfig (4) ;

  pickup pencircle scaled 0 ;

  color col ; col := (.4,.8,.6) ;

  puppet((-20, 0) ,.20, 0.700col) ;
  puppet(( 10,10) ,.30, 0.750col) ;
  puppet(( 30,20) ,.40, 0.800col) ;
  puppet((-20,30) ,.35, 0.850col) ;
  puppet(( 20,60) ,.20, 0.900col) ;
  puppet(( -5,65) ,.25, 0.950col) ;

  picture s ; s := currentpicture ; currentpicture := nullpicture ;

  bboxmargin := 15 ; fill bbox s withcolor .8(1,1,0) ;

  addto currentpicture also s withpen pencircle scaled .8 ;

  path b ; bboxmargin := -10 ; b := bbox currentpicture ;
  numeric len ; len := length(b) ;
  numeric stp ; stp := 20 ;
  drawoptions(withpen pencircle scaled .8 withcolor .7red) ;
  for i=len/8stp step len/4stp until len+len/8stp   :
    pair ii ; ii := point (dpuppet(i,len/20stp)) of b ;
    pair dd ; dd := (direction i of b) rotated (dpuppet(-90,10)) ;
    draw ii shifted -.1dd withpen pencircle scaled 1.2 ;
    draw ii--(ii shifted .25dd) ;
  endfor ;

endfig ;
