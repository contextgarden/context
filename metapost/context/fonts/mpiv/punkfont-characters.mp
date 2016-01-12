initialize_punk_upper ;

beginpunkchar("A",13,1,2);
z1=pp(1.5u,0); z2=(.5w,1.1h); z3=pp(w-1.5u,0);
pd z1; pd z3; draw z1--z2--z3;  % left and right diagonals
z4=pp .3[z1,z2]; z5=pp .3[z3,z2]; pd z4; pd z5; draw z4--z5; % crossbar
endchar;

beginpunkchar("B",12,1,1);
z1=pp(2u,0); z2=pp(2u,.6h); z3=pp(2u,h); pd z1; pd z3; draw z1--z3; % stem
z1.5=pp(w-u,.5y2); z2.5=pp(w-u,.5[y2,y3]); draw z2--z2.5--z3;  % upper lobe
draw flex(z2,z1.5,z1); % lower lobe
endchar;

beginpunkchar("C",13,1,2);
z1=pp(w-2u,.8h); z2=pp(.6w,h); z3=pp(u,.5h); z4=(.6w,0); z5=(w-2u,.2h);
pd z1; pd z5; draw z1..z2..z3..z4..z5;  % arc
endchar;

beginpunkchar("D",14,1,2);
z1=pp(2u,0); z2=pp(2u,h); z3=pp(w-u,.6h);
pd z1; pd z2; draw flex(z1,z3,z2); % lobe
draw z1--z2;  % stem
endchar;

beginpunkchar("E",12,.5,1);
z1=pp(2u,0); z2=pp(2u,h); z3=pp(w-2.5u,h); z4=pp(w-2u,0);
pd z3; pd z4; draw z4--z1--z2--z3; % stem and arms
z5=pp(2u,.6h); z6=pp(w-3u,.6h); pd z5; pd z6; draw z5--z6;  % crossbar
endchar;

beginpunkchar("F",12,.5,2);
z1=pp(2u,0); z2=pp(2u,h); z3=pp(w-2u,h);
pd z1; pd z3; draw z1--z2--z3;  % stem and arm
z5=pp(2u,.6h); z6=pp(w-3u,.6h); z4=pp .5[z5,z6]-(0,.1h);
pd z5; pd z6; draw flex (z5,z4,z6); % crossbar
endchar;

beginpunkchar("G",13,.5,.5);
z1=pp(w-2u,.8h); z2=pp(.6w,h); z3=pp(u,.5h); z4=pp(.6w,0); z5=(w-2u,0);
pd z1; draw z1..z2..z3..z4---z5;  % arc
z6=pp(.5[u,x5],.4h); pd z6; pd z5; draw z6--(pp(x5,y6))--z5; % spur
endchar;

beginpunkchar("H",14,1,.5);
z1=pp(2u,0); z2=pp(2u,h); z3=pp(w-2u,0); z4=pp(w-2u,h);
z5=pp(2u,.6h); z6=pp(w-2u,.6h);
pd z1; pd z2; pd z3; pd z4; draw z1--z2; draw flex(z3,z6,z4); % stems
pd z5; draw z5--z6;  % crossbar
endchar;

beginpunkchar("I",5,1,2);
z1=pp(.5w,0); z2=(.5w,1/3h); z3=(.5w,2/3h); z4=(.5w,h);
pd z1; pd z4; draw flex(z1,z2,z3,z4);  % stem
endchar;

beginpunkchar("J",9,1,2);
z1=pp(w-2u,h); z2=pp(w-2u,-.1h); z3=pp(u,0);
pd z1; pd z3; draw z1--z2--z3; % arc
endchar;

beginpunkchar("K",14,1,2);
z1=pp(2u,0); z2=pp(2u,h); z3=pp(2u,1/3h); z4=pp(w-1.5u,h);
pd z1; pd z2; draw z1--z2;  % stem
pd z3; pd z4; draw z3--z4;  % upper diagonal
z6=pp(w-u,0); z5=1/3[z3,z4];
pd z6; draw flex(z5,.8[z1,2/3[z5,z6] ],z6);% lower diagonal
endchar;

beginpunkchar("L",11,1,2);
z1=pp(2u,h); z2=pp(2u,0); z3=pp(w-1.5u,0);
pd z1; pd z3; draw z1--z2--z3;  % stem and arm
endchar;

beginpunkchar("M",17,.5,2);
z1=pp(2u,0); z2=pp(2u,h); z3=pp(.5w,0); z4=pp(w-2u,h); z5=pp(w-2u,0);
pd z1; pd z5; draw z1--z2--z3--z4--z5; % stems and diagonals
endchar;

beginpunkchar("N",13,.75,2);
z1=pp(2u,0); z2=pp(2u,h); z3=pp(w-2u,0); z4=pp(w-2u,h);
pd z1; pd z4; draw z1--z2--z3--z4; % stems and diagonals
endchar;

beginpunkchar("O",12,.5,2);
z1=pp(.5w,h); z2=pp(u,.55h); z3=pp(.5w,0); z4=pp(w-u,.55h);
pd z1; draw z1{left}..z2..z3..z4..z1; % bowl
endchar;

beginpunkchar("P",13,1,2);
z1=pp(2u,0); z2=pp(2u,1.1h); z3=pp(2u,.5h); z4=pp(w,.6[y3,y2]);
pd z1; pd z3; draw z1--z2--z4--z3; % stem and bowl
endchar;

beginpunkchar("Q",14,.5,2);
z1=pp(.5w,h); z2=pp(u,.55h); z3=pp(.5w,0); z4=pp(w-u,.55h);
pd z1; draw z1{curl 2}..z2..z3..z4..z1; % bowl
z5=pp(.4w,.2h); z6=pp(w-u,-.1h); z7=pp(.5[x5,x6],-.2h);
pd z5; pd z6; draw z5--z7--z6;  % tail
endchar;

beginpunkchar("R",16,1,2);
z1=pp(2u,0); z2=pp(2u,h); z3=pp(w-u,.6[y2,y4]); z4=pp(2u,.5h); z5=pp(w-1.5u,0);
pd z1; pd z2; pd z5; draw z1--flex(z2,z3,z4)--z5; % stem, bowl, and diagonal
endchar;

beginpunkchar("S",11,.3,1);
z1=pp(w-2u,.9h); z2=pp(.5w,h); z3=pp(u,.7h); z4=.6[z6,z2];
z5=pp(w-u,.35h); z6=pp(.5w,u); z7=pp(u,.2h);
pd z1; pd z7; draw z1--z2...z3..z4..z5...z6--z7;  % stroke
endchar;

beginpunkchar("T",13,.75,2);
z1=pp(u,h); z2=pp(w-u,h); z3=pp(.5w,0);
pd z1; pd z2; pd z3; draw z1--z2;  % arms
draw .5[z1,z2]--z3;  % stem
endchar;

beginpunkchar("U",13,.3,2);
z1=pp(2u,h); z2=pp(2u,.2h); z3=pp(.5w,0); z4=pp(w-2u,.2h); z5=pp(w-2u,h);
pd z1; pd z5; draw z1---z2...z3{z4-z2}...z4---z5; % stroke
endchar;

beginpunkchar("V",13,1,2);
z1=pp(1.5u,h); z2=pp(.5w,0); z3=pp(w-1.5u,h);
pd z1; pd z3; draw z1--z2--z3;  % diagonals
endchar;

beginpunkchar("W",18,1,2);
z1=pp(1.5u,h); z2=pp(.5[x1,x3],0); z3=pp(.5w,.8h); z4=pp(.5[x3,x5],0);
z5=pp(w-1.5u,h);
pd z1; pd z5; draw z1--z2--z3--z4--z5;  % diagonals
endchar;

beginpunkchar("X",13,1,1);
z1=pp(1.5u,h); z2=pp(w-1.5u,0); z3=pp(1.5u,0); z4=pp(w-2.5u,h);
pd z1; pd z2; draw z1--z2;  % main diagonal
pd z3; pd z4; draw z3--z4;  % cross diagonal
endchar;

beginpunkchar("Y",13,1,2);
z1=pp(1.5u,h); z2=pp(w-1.5u,h); z3=pp(.5w,.5h); z4=pp(.5w,0);
pd z1; pd z2; pd z4; draw z1--z3--z4; % stem and left diagonal
draw z2--z3;  % right diagonal
endchar;

beginpunkchar("Z",11,1,2);
z1=pp(1.5u,h); z2=pp(w-2.5u,h); z3=pp(1.5u,0); z4=pp(w-1.5u,0);
pd z1; pd z4; draw z1--z2--z3--z4;  % diagonals
endchar;

beginpunkchar(198,16,1,2); % \AE
z1=pp(1.5u,0); z2=pp(.6w,h); z3=pp(w-1.5u,h);
pd z1; pd z3; draw z1--z2--z3;  % left diagonal and upper arm
z4=pp .3[z1,z2]; z5=pp(.6w,0); z6=pp(w-2u,.3h);
pd z4; pd z6; draw z4--z6; % crossbar
z7=pp(w-u,0); pd z2; pd z7; draw z2--z5--z7; % stem and lower arm
endchar;

beginpunkchar(338,18,1,2); % \OE
z1=pp(.5w,h); z2=pp(u,.4h); z3=pp(.5w,0);
pd z1; draw z1..z2..{right}z3; % bowl
z4=pp(w-1.5u,h); z5=pp(w-2u,.4h); z6=pp(w-u,0);
pd z4; pd z6; draw z4--z1--z3--z6; % arms and stem
pd z5; draw z5--.4[z3,z1];  % crossbar
endchar;

beginpunkchar(216,14,1,1); % \O
z1=pp(.5w,h); z2=pp(u,.5h); z3=pp(.5w,0); z4=pp(w-u,.5h);
z5=pp(w-2u,1.1h); z6=pp(2u,-.1h);
pd z1; pd z6; draw z1..z2..z3..z4..z5--z6;  % bowl and diagonal
endchar;

beginpunkchar(915,11,1,2); % $\Gamma$
z1=pp(2u,0); z2=pp(2u,h); z3=pp(w-1.5u,h);
pd z1; pd z3; draw z1--z2--z3;  % stem and arm
endchar;

beginpunkchar(916,15,1,2); % $\Delta$
z1=pp(u,0); z2=pp(.5w,h); z3=pp(w-u,0);
pd z1; draw z1--z2..tension 5..z3..tension 5..z1; % triangle
endchar;

beginpunkchar(920,15,.5,2); % $\Theta$
z1=pp(.5w,h); z2=pp(u,.6h); z3=pp(.5w,0); z4=pp(w-u,.6h);
pd z1; draw z1..tension.8..z2..z3..z4..tension.8..z1; % bowl
z5=pp(x2+2u,.4h); z6=pp(x4-2u,.4h); pd z5; pd z6; draw z5--z6; % bar
endchar;

beginpunkchar(923,12,1,2); % $\Lambda$
z1=pp(u,0); z2=pp(.5w,h); z3=pp(w-u,0);
pd z1; pd z3; draw z1--z2--z3;  % diagonals
endchar;

beginpunkchar(926,12,1,1); % $\Xi$
z1=pp(u,h); z2=pp(w-u,h); pd z1; pd z2; draw z1--z2;  % upper arm
z3=pp(2u,.55h); z4=pp(w-2u,.55h); pd z3; pd z4; draw z3--z4;  % bar
z5=pp(u,0); z6=pp(w-u,0); pd z5; pd z6; draw z5--z6;  % lower arm
endchar;

beginpunkchar(928,13,1,.5); % $\Pi$
z1=pp(1.5u,0); z2=pp(1.5u,h); z3=pp(w-1.5u,h); z4=pp(w-1.5u,0);
pd z1; pd z4; draw z1--z2--z3--z4;  % stems and bar
endchar;

beginpunkchar(931,13,1,1); % $\Sigma$
z1=pp(w-u,h); z2=pp(u,h); z3=pp(.5w-u,.5h); z4=pp(u,0); z5=pp(w-u,0);
pd z1; pd z5; draw z1--z2{.5[z4,z5]-z2}..z3--z4--z5; % arms and diagonals
endchar;

beginpunkchar(933,15,1,.5); % $\Upsilon$
z1=pp(u,.8h); z2=pp(.3w,h); z3=pp(.5w,.5h); z4=pp(.5w,0);
pd z1; pd z4; draw z1..z2..tension2..z3---z4; % left arc and stem
z5=pp(w-u,.8h); z6=pp(.7w,h);
pd z5; draw z5..z6..tension2..{z4-z3}z3; % right arc
endchar;

beginpunkchar(934,13,1,2); % $\Phi$
z1=pp(.5w,h); z2=pp(.5w,0); pd z1; pd z2; draw z1--z2; % stem
z3=pp(.5w,2/3h); z4=pp(u,.5h); z5=pp(.5w,1/4h); z6=pp(w-u,.5h);
pd z3; draw z3..z4..z5..z6..z3; % bowl
endchar;

beginpunkchar(936,14,1,1); % $\Psi$
z1=pp(.5w,h); z2=pp(.5w,0); pd z1; pd z2; draw z1--z2; % stem
z3=pp(u,.8h); z4=pp(.5w,.2h); z5=pp(w-u,.8h);
pd z3; pd z5; draw z3{.4[z1,z2]-z3}..z4{right}..{z5-.4[z1,z2]}z5; % stroke
endchar;

beginpunkchar(937,13,1,2); % $\Omega$
z1=pp(u,0); z2=pp(1/3w,0); z3=pp(u,2/3h); z4=pp(.5w,h);
z5=pp(w-u,2/3h); z6=pp(2/3w,0); z7=pp(w-u,0);
pd z1; pd z7; draw z1--z2{up}..z3..z4..z5..{down}z6--z7; % bowl and arms
endchar;

beginpunkchar(".",5,1,2);
pd pp(.5w,0);  % dot
endchar;

beginpunkchar(",",5,.5,.5);
z1=pp(.5w,0); z2=pp(w-u,-.1h); z3=pp(.5w,-.3h);
pd z1; pd z3; draw z1--z2--z3;  % stroke
endchar;

beginpunkchar(":",5,1,.5);
pd pp(.5w,0); pd pp(.5w,.4h);  % dots
endchar;

beginpunkchar(";",5,.5,.5);
z1=pp(.5w,0); z2=pp(w-u,-.1h); z3=pp(.5w,-.3h);
pd z1; pd z3; draw z1--z2--z3;  % stroke
pd pp(.5w,.4h); % dot
endchar;

beginpunkchar("!",5,.5,.5);
pd pp(.5w,0); % dot
z1=pp(.5w,1.05h); z2=pp(.5w,.3h); pd z1; pd z2; draw z1--z2; % stem
endchar;

beginpunkchar(161,5,.5,.5); % spanish inverted !
pd pp(.5w,.9h); % dot
z1=pp(.5w,-.1h); z2=pp(.5w,.6h); pd z1; pd z2; draw z1--z2; % stem
endchar;

beginpunkchar("?",9,1,.5);
z1=pp(1.5u,.8h); z2=pp(.5w,h); z3=pp(w-u,.8h); z4=pp(.5w,.3h);
pd z1; pd z4; draw z1..z2..z3..{down}z4; % arc and stem
pd pp(.5w,0); % dot
endchar;

beginpunkchar(191,9,1,.5); % spanish inverted ?
z1=pp(1.5u,.1h); z2=pp(.5w,-.1h); z3=pp(w-u,.1h); z4=pp(.5w,.6h);
pd z1; pd z4; draw z1..z2..z3..{up}z4; % arc and stem
pd pp(.5w,.9h); % dot
endchar;

beginpunkchar("&",14,.5,.5);
z1=pp(w-2u,h); z2=pp(u,h); z3=pp(3u,0); z5=pp(w-u,.6h); z6=pp(w-2u,0);
pd z1; pd z5; draw z1--z2--z3--z5; % arms and stem
draw z1--.5[z2,z3]; pd z6; draw z6--.6[z3,z5]; % diagonals
endchar;

beginpunkchar("$",12,.5,.5);
z1=pp(w-1.5u,.7h); z2=pp(.5w,h); z3=pp(u,.7h); z4=.5[z3,z5];
z5=pp(w-u,.3h); z6=pp(.5w,0); z7=pp(u,.3h);
pd z1; pd z7; draw z1..z2..z3..z4..z5..z6..z7; % stroke
z8=z2+(0,.1h); pd z8; draw z8--z6; % stem
endchar;

beginpunkchar("%",18,.5,.5);
z1=pp(3.5u,1.1h); z2=pp(u,.8h); z3=pp(3.5u,.5h); z4=pp(6u,.8h);
z5=pp(w-3.5u,.5h); z6=pp(w-6u,.2h); z7=pp(w-3.5u,-.1h); z8=pp(w-u,.2h);
pd z1; draw z1..z2..z3..z4..z1; % upper bowl
pd z5; draw z5..z6..z7..z8..z5; % lower bowl
z9=pp(w-3u,1.1h); z0=pp(3u,-.1h); pd z0; draw z9--z0; % diagonal
draw z1{z5-z1}..z9; % link
endchar;

beginpunkchar("@",18,1,.5);
z1=pp(2u,0); z2=pp(1/3w,.7h); z3=pp(w-6u,0);
z4=pp(w,.3h); z5=pp(1/3w,h); z6=pp(u,.5h); z7=.7[z2,z3];
pd z1; pd z7; draw z1--z2--z3{right}..z4..z5..z6..z7; % diagonals and stroke
endchar;

beginpunkchar("-",7,.5,.5);
z1=pp(u,.4h); z2=pp(w-u,.5h); pd z1; pd z2; draw z1--z2;  % bar
endchar;

beginpunkchar(8211,9,.5,.5); % --
z1=pp(0,.5h); z2=pp(w,.4h); pd z1; pd z2; draw z1--z2;  % bar
endchar;

beginpunkchar(8212,18,.5,.5); % ---
z1=pp(0,.5h); z2=pp(w,.4h); pd z1; pd z2; draw z1--z2;  % bar
endchar;

beginpunkchar("+",9,.5,1);
z1=pp(0,.5h); z2=pp(w,.5h); pd z1; pd z2; draw z1--z2; % bar
z3=pp(.5w,.1h); z4=pp(.5w,.9h); pd z3; pd z4; draw z3--z4; % stem
endchar;

beginpunkchar("*",13,.5,1);
z0=pp(.5w,1.1h); z1=pp(u,.9h); z2=pp(2u,.3h); z3=pp(w-u,.3h); z4=pp(w-u,.9h);
pd z0; draw z0--z2..1/3[.5[z2,z4],z0]..z4--z1--z3--z0; % star
endchar;

beginpunkchar(39,5,.5,1.5); % ' apostrofe HH/TH (to be checked)
z1=pp(w/2,h); z2=pp(w/2+u,.85h); z3=pp(w/2,2/3h);
pd z1; pd z3; draw z1..z2..z3;  % stroke
endchar;

beginpunkchar(34,9,1,1.5); % "  HH/TH (to be checked)
z1=pp(1.5u,h); z2=pp(1.5u,.6h); z3=pp(w-1.5u,h); z4=pp(w-1.5u,.6h);
pd z1; pd z2; pd z3; pd z4; draw z1--z2; draw z3--z4;
endchar;

beginpunkchar(8216,5,.3,.5); % `
z1=pp(w-1.5u,h); z2=pp(u,.85h); z3=pp(w-u,2/3h);
pd z1; pd z3; draw z1--z2--z3;  % stroke
endchar;

beginpunkchar(8217,5,.3,.5); % '
z1=pp(1.5u,h); z2=pp(w-u,.85h); z3=pp(u,2/3h);
pd z1; pd z3; draw z1--z2--z3;  % stroke
endchar;

beginpunkchar(8220,9,.3,.5); % `` quotedblleft
z1=pp(.5w+.5u,h); z2=pp(w-u,.6h); z3=pp(u,.95h);
pd z1; pd z3; draw z1--z2--z3;  % stroke
endchar;

beginpunkchar(8221,9,.3,.5); % '' quotedblright
z1=pp(.5w-.5u,h); z2=pp(u,.6h); z3=pp(w-u,.95h);
pd z1; pd z3; draw z1--z2--z3;  % stroke
endchar;

beginpunkchar("(",7,.5,.5);
z1=pp(w-u,h); z2=pp(u,.5h); z3=pp(w-u,0);
pd z1; pd z3; draw z1..z2..z3;  % stroke
endchar;

beginpunkchar(")",7,.5,.5);
z1=pp(u,h); z2=pp(w-u,.5h); z3=pp(u,0); pd z1; pd z3; draw z1..z2..z3; % stroke
endchar;

beginpunkchar("[",8,.5,.5);
z1=pp(w-u,h); z2=pp(.5w,h); z3=pp(.5w,0); z4=pp(w-u,0);
pd z1; pd z4; draw z1--z2--z3--z4; % bars and stem
endchar;

beginpunkchar("]",8,.5,.5);
z1=pp(u,h); z2=pp(.5w,h); z3=pp(.5w,0); z4=pp(u,0);
pd z1; pd z4; draw z1--z2--z3--z4; % bars and stem
endchar;

beginpunkchar("<",9,.5,.5);
z1=pp(w-u,.9h); z2=pp(u,.5h); z3=pp(w-u,.1h);
pd z1; pd z3; draw z1--z2--z3; % diagonals
endchar;

beginpunkchar(">",9,.5,.5);
z1=pp(u,.9h); z2=pp(w-u,.5h); z3=pp(u,.1h);
pd z1; pd z3; draw z1--z2--z3; % diagonals
endchar;

beginpunkchar("{",10,.5,.5); % HH/TH
z1=pp(w-2u,h); z3=pp(2u,.5h); z5=pp(w-2u,0);
z2=pp(w-4u,.6h); z4=(w-4u,.4h);
pd z1; pd z3; pd z5; draw z1{left}..z2--z3 & z3--z4..{right}z5;
endchar;

beginpunkchar("}",10,.5,.5); % HH/TH
z1=pp(2u,h); z3=pp(w-2u,.5h); z5=pp(2u,0);
z2=pp(4u,.6h); z4=(4u,.4h);
pd z1; pd z3; pd z5; draw z1{right}..z2--z3 & z3--z4..{left}z5;
endchar;

beginpunkchar("=",9,.5,.5);
z5=pp(u,2/3h); z6=pp(w-u,2/3h); pd z5; pd z6; draw z5--z6; % upper bar
z7=pp(u,1/3h); z8=pp(w-u,1/3h); pd z7; pd z8; draw z7--z8; % lower bar
endchar;

beginpunkchar("#",15,.5,.5);
z1=pp(.5w,h); z2=pp(3u,0); z3=pp(w-3u,h); z4=pp(.5w,0);
pd z2; pd z3; draw z3--z1--z2; draw z3--z4--z2; % diagonals (linked)
z5=pp(u,2/3h); z6=pp(w-u,2/3h); pd z5; pd z6; draw z5--z6; % upper bar
z7=pp(u,1/3h); z8=pp(w-u,1/3h); pd z7; pd z8; draw z7--z8; % lower bar
endchar;

beginpunkchar("/",9,1,1);
z1=pp(1.5u,-.05h); z2=pp(w-1.5u,1.05h); pd z1; pd z2; draw z1--z2; % diagonal
endchar;

beginpunkchar("\",9,1,1); % HH/TH
z1=pp(1.5u,1.05h); z2=pp(w-1.5u,-.05h); pd z1; pd z2; draw z1--z2; % reverse diagonal
endchar;


beginpunkchar("0",9,.5,1);
z1=pp(.5w,h); z2=pp(u,.55h); z3=pp(.5w,0); z4=pp(w-u,.55h);
pd z1; draw z1{curl 2}..z2..z3..z4..z1; % bowl
endchar;

beginpunkchar("1",9,.3,1);
z1=pp(2u,.7h); z2=pp(.6w,h); z3=pp(.6w,0);
pd z1; pd z3; draw z1--z2--z3; % serif and stem
endchar;

beginpunkchar("2",9,1,1);
z1=pp(2u,.7h); z2=pp(.5w,h); z3=pp(w-u,.6h); z4=pp(u,0); z5=pp(w-2u,0);
pd z1; pd z5; draw z1..z2..z3..z4--z5; % stroke
endchar;

beginpunkchar("3",9,.5,.5);
z1=pp(2u,.7h); z2=pp(.5w,h); z3=pp(w-u,.5[y2,y4]);
z4=pp(.5w-u,.55h); z5=pp(w-u,.5[y4,y6]); z6=pp(.5w,0); z7=pp(1.5u,.2h);
pd z1; pd z7; draw z1..z2..z3..z4&z4..z5..z6..z7;  % arcs
endchar;

beginpunkchar("4",9,1,1);
z1=pp(w-u,.3h); z2=pp(u,.3h); z3=pp(2/3w,h); z4=pp(2/3w,0);
pd z1; pd z4; draw z1--z2--z3--z4; % stem and diagonals
endchar;

beginpunkchar("5",9,.5,.5);
z1=pp(w-2u,h); z2=pp(2u,h); z3=pp(u,.7h); z4=pp(w-u,.5[y3,y5]);
z5=pp(.5w,0); z6=pp(u,.2h);
pd z1; pd z6; draw z1--z2--z3..z4..z5..z6; % stroke
endchar;

beginpunkchar("6",9,1,1);
z1=pp(2/3w,h); z2=pp(u,.3h); z3=pp(.5w,0); z4=pp(w-u,.3h); z5=pp(.6w,.6h);
z6=pp z2; pd z1; pd z6; draw z1..z2..z3..z4..z5--z6; % stroke
endchar;

beginpunkchar("7",9,.5,1);
z1=pp(2u,h); z2=pp(w-.5u,h); z3=pp(.4w,0);
pd z1; pd z3; draw z1--z2&z2..z3{down}; % stroke
endchar;

beginpunkchar("8",9,.5,.5);
z1=pp(.5w,h); z2=pp(u,.5[y1,y3]); z3=pp(.5w,.6h); z4=pp(w-u,.5[y3,y5]);
z5=pp(.5w,0); z6=pp(u,.5[y5,y3]); z7=pp(w-u,.5[y1,y3]);
pd z1; draw z1{curl 8}..z2..z3..z4..z5..z6..z3..z7..z1; % stroke
endchar;

beginpunkchar("9",9,1,1);
z1=pp(1/3w,0); z2=pp(w-u,.7h); z3=pp(.5w,h); z4=pp(u,.7h); z5=pp(.5w,.4h);
pd z1; pd z5; draw z1..z2..z3..z4..z5; % stroke
endchar;

beginpunkchar(96,9,1,1); % \`{} grave
z1=pp(2.5u,h); z2=pp(.6w,.8h); pd z1; pd z2; draw z1--z2; % diagonal
endchar;

beginpunkchar(180,9,1,1); % \'{} acute
z1=pp(w-2.5u,h); z2=pp(.4w,.8h); pd z1; pd z2; draw z1--z2; % diagonal
endchar;

beginpunkchar(710,13,1,1); % \^{} circumflex
z1=pp(2.5u,.8h); z2=pp(.5w,h); z3=(w-2.5u,.8h);
pd z1; pd z3; draw z1--z2--z3; % diagonals
endchar;

beginpunkchar(711,13,1,1); % \v{} caron
z1=pp(2.5u,.9h); z2=pp(.5w,.7h); z3=pp(w-2.5u,.9h);
pd z1; pd z3; draw z1--z2--z3; % diagonals
endchar;

beginpunkchar(728,11,1,1); % \u{} breve
z1=pp(2u,h); z2=pp(.5w,.75h); z3=pp(w-2u,h);
pd z1; pd z3; draw flex(z1,z2,z3); % stroke
endchar;

beginpunkchar(175,12,1,1); % \={} macron
z1=pp(u,.8h); z2=pp(w-u,.8h); pd z1; pd z2; draw z1--z2; % bar
endchar;

beginpunkchar(729,5,1,1); % \.{}
pd pp(.5w,.9h); % dot
endchar;

beginpunkchar(168,13,1,1); % \"{} diaeresis
pd pp(1/5w,.9h); pd pp(4/5w,.9h); % dots
endchar;

beginpunkchar(732,13,1,1); % \~{} tilde
z1=pp(u,.75h); z2=pp(w-u,.9h); pd z1; pd z2; draw z1{up}..{up}z2; % stroke
endchar;

beginpunkchar(733,13,1,1); % \H{} hungarumlaut
z1=pp(4u,h); z2=pp(2.5u,.7h); z3=pp(w-2u,h); z4=pp(w-3.5u,.7h);
pd z1; pd z3; draw z1--z2--z4--z3; % diagonals (linked)
endchar;

beginpunkchar(730,13,0,0); % Scandinavian loop, for \AA\ and \aa (ring)
z0=(.5w,.66h); % point $z^2$ of lowercase A
z1=(.5w,.9h); draw z0{z0-(1.5u,0)}..z1..{(w-1.5u,0)-z0}z0; % loop
endchar;

beginpunkchar(184,13,.5,.5); % Cedilla, for \c c
z1=(.6w,0); z2=pp(.6w,-.1h); z3=pp(2.5u,-.1h);
pd z3; draw z1--z2--z3; % stroke
endchar;

initialize_punk_lower ;

beginpunkchar(305,5,1,2); % dotless I
z1=pp(.5w,0); z2=(.5w,1/3h); z3=(.5w,2/3h); z4=(.5w,h);
pd z1; pd z4; draw flex(z1,z2,z3,z4);  % stem
endchar;

beginpunkchar(567,9,1,2); % dotless J
z1=pp(w-2u,h); z2=pp(w-2u,-.1h); z3=pp(u,0);
pd z1; pd z3; draw z1--z2--z3; % arc
endchar;

beginpunkchar(223,18,.3,1); % German SS
z1=pp(.5w-u,.9h); z2=pp(1/3w,h); z3=pp(u,.7h); z4=.6[z6,z2];
z5=pp(.5w,.35h); z6=pp(1/3w,u); z7=pp(u,.2h);
pd z1; pd z7; draw z1--z2...z3..z4..z5...z6--z7;  % left stroke
for i=1 upto 7: z[i+10]=pp(z[i] shifted (.5w-u,0)); endfor
pd z11; pd z17; draw z11--z12...z13..z14..z15...z16--z17; % right stroke
endchar;

beginpunkchar("a",13,1,2);
z1=pp(1.5u,0); z2=(.5w,1.1h); z3=pp(w-1.5u,0);
pd z1; pd z3; draw z1--z2--z3;  % left and right diagonals
z4=pp .3[z1,z2]; z5=pp .3[z3,z2]; pd z4; pd z5; draw z4--z5; % crossbar
endchar;

beginpunkchar("b",12,1,1);
z1=pp(2u,0); z2=pp(2u,.6h); z3=pp(2u,h); pd z1; pd z3; draw z1--z3; % stem
z1.5=pp(w-u,.5y2); z2.5=pp(w-u,.5[y2,y3]); draw z2--z2.5--z3;  % upper lobe
draw flex(z2,z1.5,z1); % lower lobe
endchar;

beginpunkchar("c",13,1,2);
z1=pp(w-2u,.8h); z2=pp(.6w,h); z3=pp(u,.5h); z4=(.6w,0); z5=(w-2u,.2h);
pd z1; pd z5; draw z1..z2..z3..z4..z5;  % arc
endchar;

beginpunkchar("d",14,1,2);
z1=pp(2u,0); z2=pp(2u,h); z3=pp(w-u,.6h);
pd z1; pd z2; draw flex(z1,z3,z2); % lobe
draw z1--z2;  % stem
endchar;

beginpunkchar("e",12,.5,1);
z1=pp(2u,0); z2=pp(2u,h); z3=pp(w-2.5u,h); z4=pp(w-2u,0);
pd z3; pd z4; draw z4--z1--z2--z3; % stem and arms
z5=pp(2u,.6h); z6=pp(w-3u,.6h); pd z5; pd z6; draw z5--z6;  % crossbar
endchar;

beginpunkchar("f",12,.5,2);
z1=pp(2u,0); z2=pp(2u,h); z3=pp(w-2u,h);
pd z1; pd z3; draw z1--z2--z3;  % stem and arm
z5=pp(2u,.6h); z6=pp(w-3u,.6h); z4=pp .5[z5,z6]-(0,.1h);
pd z5; pd z6; draw flex (z5,z4,z6); % crossbar
endchar;

beginpunkchar("g",13,.5,.5);
z1=pp(w-2u,.8h); z2=pp(.6w,h); z3=pp(u,.5h); z4=pp(.6w,0); z5=(w-2u,0);
pd z1; draw z1..z2..z3..z4---z5;  % arc
z6=pp(.5[u,x5],.4h); pd z6; pd z5; draw z6--(pp(x5,y6))--z5; % spur
endchar;

beginpunkchar("h",14,1,.5);
z1=pp(2u,0); z2=pp(2u,h); z3=pp(w-2u,0); z4=pp(w-2u,h);
z5=pp(2u,.6h); z6=pp(w-2u,.6h);
pd z1; pd z2; pd z3; pd z4; draw z1--z2; draw flex(z3,z6,z4); % stems
pd z5; draw z5--z6;  % crossbar
endchar;

beginpunkchar("i",5,1,2);
z1=pp(.5w,0); z2=(.5w,1/3h); z3=(.5w,2/3h); z4=(.5w,h);
pd z1; pd z4; draw flex(z1,z2,z3,z4);  % stem
endchar;

beginpunkchar("j",9,1,2);
z1=pp(w-2u,h); z2=pp(w-2u,-.1h); z3=pp(u,0);
pd z1; pd z3; draw z1--z2--z3; % arc
endchar;

beginpunkchar("k",14,1,2);
z1=pp(2u,0); z2=pp(2u,h); z3=pp(2u,1/3h); z4=pp(w-1.5u,h);
pd z1; pd z2; draw z1--z2;  % stem
pd z3; pd z4; draw z3--z4;  % upper diagonal
z6=pp(w-u,0); z5=1/3[z3,z4];
pd z6; draw flex(z5,.8[z1,2/3[z5,z6] ],z6);% lower diagonal
endchar;

beginpunkchar("l",11,1,2);
z1=pp(2u,h); z2=pp(2u,0); z3=pp(w-1.5u,0);
pd z1; pd z3; draw z1--z2--z3;  % stem and arm
endchar;

beginpunkchar("m",17,.5,2);
z1=pp(2u,0); z2=pp(2u,h); z3=pp(.5w,0); z4=pp(w-2u,h); z5=pp(w-2u,0);
pd z1; pd z5; draw z1--z2--z3--z4--z5; % stems and diagonals
endchar;

beginpunkchar("n",13,.75,2);
z1=pp(2u,0); z2=pp(2u,h); z3=pp(w-2u,0); z4=pp(w-2u,h);
pd z1; pd z4; draw z1--z2--z3--z4; % stems and diagonals
endchar;

beginpunkchar("o",12,.5,2);
z1=pp(.5w,h); z2=pp(u,.55h); z3=pp(.5w,0); z4=pp(w-u,.55h);
pd z1; draw z1{left}..z2..z3..z4..z1; % bowl
endchar;

beginpunkchar("p",13,1,2);
z1=pp(2u,0); z2=pp(2u,1.1h); z3=pp(2u,.5h); z4=pp(w,.6[y3,y2]);
pd z1; pd z3; draw z1--z2--z4--z3; % stem and bowl
endchar;

beginpunkchar("q",14,.5,2);
z1=pp(.5w,h); z2=pp(u,.55h); z3=pp(.5w,0); z4=pp(w-u,.55h);
pd z1; draw z1{curl 2}..z2..z3..z4..z1; % bowl
z5=pp(.4w,.2h); z6=pp(w-u,-.1h); z7=pp(.5[x5,x6],-.2h);
pd z5; pd z6; draw z5--z7--z6;  % tail
endchar;

beginpunkchar("r",16,1,2);
z1=pp(2u,0); z2=pp(2u,h); z3=pp(w-u,.6[y2,y4]); z4=pp(2u,.5h); z5=pp(w-1.5u,0);
pd z1; pd z2; pd z5; draw z1--flex(z2,z3,z4)--z5; % stem, bowl, and diagonal
endchar;

beginpunkchar("s",11,.3,1);
z1=pp(w-2u,.9h); z2=pp(.5w,h); z3=pp(u,.7h); z4=.6[z6,z2];
z5=pp(w-u,.35h); z6=pp(.5w,u); z7=pp(u,.2h);
pd z1; pd z7; draw z1--z2...z3..z4..z5...z6--z7;  % stroke
endchar;

beginpunkchar("t",13,.75,2);
z1=pp(u,h); z2=pp(w-u,h); z3=pp(.5w,0);
pd z1; pd z2; pd z3; draw z1--z2;  % arms
draw .5[z1,z2]--z3;  % stem
endchar;

beginpunkchar("u",13,.3,2);
z1=pp(2u,h); z2=pp(2u,.2h); z3=pp(.5w,0); z4=pp(w-2u,.2h); z5=pp(w-2u,h);
pd z1; pd z5; draw z1---z2...z3{z4-z2}...z4---z5; % stroke
endchar;

beginpunkchar("v",13,1,2);
z1=pp(1.5u,h); z2=pp(.5w,0); z3=pp(w-1.5u,h);
pd z1; pd z3; draw z1--z2--z3;  % diagonals
endchar;

beginpunkchar("w",18,1,2);
z1=pp(1.5u,h); z2=pp(.5[x1,x3],0); z3=pp(.5w,.8h); z4=pp(.5[x3,x5],0);
z5=pp(w-1.5u,h);
pd z1; pd z5; draw z1--z2--z3--z4--z5;  % diagonals
endchar;

beginpunkchar("x",13,1,1);
z1=pp(1.5u,h); z2=pp(w-1.5u,0); z3=pp(1.5u,0); z4=pp(w-2.5u,h);
pd z1; pd z2; draw z1--z2;  % main diagonal
pd z3; pd z4; draw z3--z4;  % cross diagonal
endchar;

beginpunkchar("y",13,1,2);
z1=pp(1.5u,h); z2=pp(w-1.5u,h); z3=pp(.5w,.5h); z4=pp(.5w,0);
pd z1; pd z2; pd z4; draw z1--z3--z4; % stem and left diagonal
draw z2--z3;  % right diagonal
endchar;

beginpunkchar("z",11,1,2);
z1=pp(1.5u,h); z2=pp(w-2.5u,h); z3=pp(1.5u,0); z4=pp(w-1.5u,0);
pd z1; pd z4; draw z1--z2--z3--z4;  % diagonals
endchar;

beginpunkchar(230,16,1,2);  % \ae
z1=pp(1.5u,0); z2=pp(.6w,h); z3=pp(w-1.5u,h);
pd z1; pd z3; draw z1--z2--z3;  % left diagonal and upper arm
z4=pp .3[z1,z2]; z5=pp(.6w,0); z6=pp(w-2u,.3h);
pd z4; pd z6; draw z4--z6; % crossbar
z7=pp(w-u,0); pd z2; pd z7; draw z2--z5--z7; % stem and lower arm
endchar;

beginpunkchar(339,18,1,2); % \oe
z1=pp(.5w,h); z2=pp(u,.4h); z3=pp(.5w,0);
pd z1; draw z1..z2..{right}z3; % bowl
z4=pp(w-1.5u,h); z5=pp(w-2u,.4h); z6=pp(w-u,0);
pd z4; pd z6; draw z4--z1--z3--z6; % arms and stem
pd z5; draw z5--.4[z3,z1];  % crossbar
endchar;

beginpunkchar(248,14,1,1); % \o
z1=pp(.5w,h); z2=pp(u,.5h); z3=pp(.5w,0); z4=pp(w-u,.5h);
z5=pp(w-2u,1.1h); z6=pp(2u,-.1h);
pd z1; pd z6; draw z1..z2..z3..z4..z5--z6;  % bowl and diagonal
endchar;

revert_punk_lower;

beginpunkchar("_",12,.5,.5); % _
z1=pp(0,-.2h); z2=pp(w,-.2h); pd z1; pd z2; draw z1--z2;  % bar
endchar;

beginpunkchar("^",12,1,.5); %
z1=pp(.5w,h); z2=pp(1.5u,.6h); z3=pp(w-1.5u,.6h);
pd z2; pd z3; draw z2--z1--z3;
endchar;
