% Written by Taco Hoekwater
% Donated to the Public Domain. Use at your own risk.
% Preliminary version, 19-aug-1999.
% New 17/9/2003: 'eprint' and 'doi' tags

% This style produces citations in a format the ConTeXt can handle.
% It outputs a large collection of labels so that context can decide
% which one to use.
%
% Actually, there are a number of separate bst files that change in
% only two lines: the ITERATEs right before the two SORTs can
% have different values, sorting by either one of
% 
% -------------------------- cont-master.bst  author
% - the author (+year, title)  : cont-au.bst  author 
% - the title  (+author, year) : cont-ti.bst  title
% - the short key a la abbrev  : cont-ab.bst  clabel
% - nothing at all (cite order): cont-no.bst  none
%
%
% Output gives the following computed info:
% 
% - the total number of bib entries
% - the longest short label
%
% And per entry:
%
% - the key
% - the entry type
% - the yeardata for crossrefs
% - the authordata for crossrefs
% - the short key
% - the .bib appearance number

% Commands that may be written to the bbl file (not counting stuff the
% bib database defines itself):
%
% \setuppublicationlist
% \startpublication
% \stoppublication

% Field entries with a strange format/appearance:
%
% \artauthor,
% \editor,
% \author:  \xxx[junior]{firstnames}[inits]{von}{lastname}

% \etalchar: appears in short keys sometimes
% \maybeyear: appears in \pubyear sometimes
%
% And these commands for the entries have only one argument,
% precisely matching the corresponding field. Note that there 
% are more fields supported than in the standard bst files.
%
% \abstract
% \annotate
% \arttitle
% \chapter
% \city
% \comment
% \country
% \crossref
% \edition
% \isbn
% \issn
% \issue
% \journal
% \keyword
% \keywords
% \lang
% \month
% \names
% \note
% \notes
% \organization
% \pages
% \pubname
% \pubyear
% \series
% \size
% \thekey
% \title
% \bibtype
% \volume
% \eprint
% \doi
% \howpublished
% \biburl
% \lastchecked
% for ieee:

% \nationality
% \assignee
% \bibnumber
% \day
% \dayfiled
% \monthfiled
% \yearfiled
% \revision
 
ENTRY
  { abstract
	address
    annotate
	author
    booktitle
    chapter
    comment
    country
    doi
    edition
    editor
    eprint
    howpublished
    institution
    isbn
    issn
    journal
    key
    keyword
    keywords
    language
    lastchecked
	month
    names
    note
    notes
    number
    organization
    pages
    publisher
    school
    series
    size
    title
    type
    url
    volume
    year
 nationality
 assignee
 bibnumber
 day
 dayfiled
 monthfiled
 yearfiled
 revision
  }
  {}
  { label extra.label sort.label clabel sort.clabel ordinal.label}
 
 
STRINGS { s t autype}

STRINGS { last.label next.extra nlabel }
 
STRINGS { longest.label last.sort.label}

INTEGERS { longest.label.width last.extra.num ordinal.num }
 
INTEGERS { nameptr namesleft numnames }
 
INTEGERS { len }
 

FUNCTION {begin.bib}
{ #0 'ordinal.num :=
  preamble$ empty$
    'skip$
    { preamble$ write$ newline$ }
  if$
  "\setuppublicationlist[samplesize={" write$ 
	longest.label "},totalnumber=" * write$
	nlabel "]" * write$
	newline$
}

FUNCTION {end.bib}
{ newline$
}
 
 
 
FUNCTION {do.out}
{ duplicate$ empty$
    { pop$ pop$ write$}
    { "{" swap$ * "}" * * write$ pop$ newline$ }
  if$
}


FUNCTION {do.t.out}
{ duplicate$ empty$
    { pop$ pop$ write$}
    { "{" swap$ "t" change.case$ * "}" * * write$ pop$ newline$ }
  if$
}

FUNCTION {format.year}
{ year empty$
    'skip$
	{ "\pubyear{" year * write$
	   extra.label empty$
	   { "}" write$ }
	   { "\maybeyear{" extra.label * "}}" * write$ }
       if$
	  newline$
    }
  if$
}
 
FUNCTION {start.entry}
{ ordinal.num #1 + 'ordinal.num :=
  newline$
  "\startpublication[" write$
  "k=" write$
  cite$ "," * write$
  "t=" write$
  type$ "," * write$
  newline$
  label write$
  "," write$
  doi empty$
    {}
    {
     "o={" write$
     doi write$
     "}," write$
     } if$ 
  newline$
  url empty$
    {}
    {
     "u={" write$
     url write$
     "}," write$
    newline$
     } if$ 
  "n=" write$
  ordinal.label write$
  ",s=" write$
  clabel write$
  "]" write$
  newline$
  "" "\lang" language do.out
}
 
FUNCTION {stop.entry}
{   "" "\country" country do.out
    "" "\note" note do.out
	"" "\notes" notes do.out
	"" "\annotate" annotate do.out
	"" "\eprint" eprint do.out
	"" "\doi" doi do.out
	"" "\keyword" keyword do.out
	"" "\keywords" keywords do.out
	"" "\comment" comment do.out
	"" "\abstract" abstract do.out
	"" "\names" names do.out
	"" "\size" size do.out
	"" "\biburl" url do.out
	"" "\lastchecked" lastchecked do.out
	"\stoppublication" write$
  newline$
}
 
 
 
FUNCTION {not}
{   { #0 }
    { #1 }
  if$
}
 
FUNCTION {and}
{   'skip$
    { pop$ #0 }
  if$
}
 
FUNCTION {or}
{   { pop$ #1 }
    'skip$
  if$
}
 
 
FUNCTION {field.or.null}
{ duplicate$ empty$
    { pop$ "" }
    'skip$
  if$
}
 
 
FUNCTION {format.names}
{ 's := 'autype := 
  #1 'nameptr :=
  s num.names$ 'numnames :=
  numnames 'namesleft :=
    { namesleft #0 > }
    { autype write$
	  s nameptr "{jj}" format.name$ 't := 
      "[" t * "]" * write$
	  s nameptr "{ff}" format.name$ 't := 
      "{" t * "}" * write$
	  s nameptr "{f}" format.name$ add.period$ 't := 
      "[" t * "]" * write$
	  s nameptr "{vv}" format.name$ 't := 
      "{" t * "}" * write$
	  s nameptr "{ll}" format.name$ 't := 
      "{" t * "}" * write$
	  newline$
	  nameptr #1 + 'nameptr :=
      namesleft #1 - 'namesleft :=
    }
  while$
}
 

FUNCTION {format.key}
{ "" "\thekey" key do.out }


FUNCTION {format.artauthors}
{ author empty$
    { format.key }
    { "\artauthor" author format.names }
  if$
}
 
FUNCTION {format.authors}
{ author empty$
    { format.key }
    { "\author" author format.names }
  if$
}

FUNCTION {format.editors}
{ editor empty$
    { format.key }
    { "\editor" editor format.names }
  if$
}
 
 
FUNCTION {format.title}
{ "" "\title" title do.out 
  "" "\isbn" isbn do.out
}

FUNCTION {format.t.title}
{ "" "\title" title do.t.out 
  "" "\isbn" isbn do.out
}

FUNCTION {format.arttitle}
{ "" "\arttitle" title do.t.out }

FUNCTION {format.journal}
{ "" "\journal" journal do.out 
  "" "\issn" issn do.out
}
 
FUNCTION {tie.or.space.connect}
{ duplicate$ text.length$ #3 <
    { "~" }
    { " " }
  if$
  swap$ * *
}
 
FUNCTION {either.or.check}
{ empty$
    'pop$
    { "can't use both " swap$ * " fields in " * cite$ * warning$ }
  if$
}
 
FUNCTION {format.volume}
{ "" "\volume" volume do.out
}

FUNCTION {format.volume.issue}
{ "" "\volume" volume do.out
  "" "\issue" number do.out
}

FUNCTION {format.number.series}
{ "" "\series" series do.out
  volume empty$
    { "" "\volume" number do.out 
    }
    { "" "\volume" volume do.out 
	  "" "\issue" number do.out }
  if$
}
 
FUNCTION {format.edition}
{ "" "\edition" edition do.out
  "" "\month" month do.out
}
 
FUNCTION {format.pages}
{ "" "\pages" pages do.out }


FUNCTION {format.vol.num.pages}
{ format.volume.issue
  format.pages
}

FUNCTION {format.vol.num.page}
{ format.volume.issue
  format.pages
}

FUNCTION {format.type.chapter.pages}
{ chapter empty$
    'format.pages
    { "" "\bibtype" type do.out
      "" "\chapter" chapter do.out 
    }
  if$
  format.pages
}
 
FUNCTION {format.booktitle}
{"" "\title" booktitle do.out 
 "" "\isbn" isbn do.out
}

FUNCTION {format.in.ed.booktitle}
{ booktitle empty$
    'skip$
    { format.booktitle }
  if$
}
 
FUNCTION {format.in.booktitle.or.series}
{ "" "\series" series do.out 
  booktitle empty$
    'skip$
	{ editor empty$
        { format.booktitle }
        { format.editors format.booktitle }
      if$ 
    }
  if$
}
 
 
FUNCTION {format.tr.number}
{"" "\bibtype" type do.out
 "" "\volume" number do.out
}
 
FUNCTION {format.crossref}
{ "" "\crossref" crossref do.out 
}
 
FUNCTION {format.book.crossref}
{ 
  "" "\volume" volume do.out 
  format.crossref
}
 
FUNCTION {format.incoll.inproc.crossref}
{ format.crossref
}
 
FUNCTION {article}
{ start.entry
  format.artauthors
  format.year
  format.arttitle
  crossref missing$
    { format.journal
      format.vol.num.pages
    }
    { format.crossref
      format.pages
    }
  if$ 
  "" "\month" month do.out
  stop.entry
}
 
FUNCTION {book}
{ start.entry
  author empty$
    { format.editors
    }
    { format.authors
    }
  if$
  format.year
  format.title
  crossref missing$
    { format.number.series
	  "" "\city" address do.out
      "" "\pubname" publisher do.out
    }
    { 
      format.book.crossref
    }
  if$
  format.edition
  stop.entry
}
 
FUNCTION {booklet}
{ start.entry
  format.authors
  format.year
  format.t.title
  format.key
  "" "\pubname" publisher do.out
  "" "\howpublished" howpublished do.out
  "" "\city" address do.out
  stop.entry
}
 
FUNCTION {inbook}
{ start.entry
  author empty$
    { format.editors
    }
    { format.authors
    }
  if$
  format.year
  format.title
  crossref missing$
    { format.type.chapter.pages
      format.number.series
      "" "\city" address do.out
  	  "" "\pubname" publisher do.out
    }
    { format.type.chapter.pages
      format.book.crossref
    }
  if$
  format.edition
  stop.entry
}
 
FUNCTION {incollection}
{ start.entry
  format.artauthors
  format.year
  format.arttitle
  format.editors
  crossref missing$
    { format.in.ed.booktitle
      format.number.series
      "" "\city" address do.out
      format.edition
      format.type.chapter.pages
    }
    { format.incoll.inproc.crossref
      format.type.chapter.pages
    }
  if$
  "" "\pubname" publisher do.out
  stop.entry
}
 
FUNCTION {inproceedings}
{ start.entry
  format.authors
  format.year
  format.arttitle
  crossref missing$
    { format.in.booktitle.or.series
      format.number.series
      "" "\city" address do.out
      format.pages
    }
    { format.incoll.inproc.crossref
      format.pages
    }
  if$
  "" "\pubname" publisher do.out
  "" "\organization" organization do.out
  stop.entry
}
 
FUNCTION {conference} { inproceedings }
 
FUNCTION {manual}
{ start.entry
  format.authors
  format.year
  format.title
  "" "\organization" organization do.out
  "" "\city" address do.out
  "" "\edition" edition do.out
  stop.entry
}
 
FUNCTION {mastersthesis}
{ start.entry
  format.authors
  format.year
  format.t.title
  "" "\bibtype" type do.out
  "" "\pubname" school do.out
  "" "\month" month do.out
  "" "\city" address do.out
  stop.entry
}
 
FUNCTION {misc}
{ start.entry
  format.authors
  format.year
  format.t.title
  format.key
  "" "\city" address do.out
  "" "\day" day do.out
  "" "\month" month do.out
  "" "\pubname" publisher do.out
  "" "\howpublished" howpublished do.out
  stop.entry
}
 
FUNCTION {phdthesis}
{ start.entry
  format.authors
  format.title
  format.year
  "" "\bibtype" type do.out
  "" "\month" month do.out
  "" "\pubname" school do.out
  "" "\city" address do.out
  stop.entry
}
 
FUNCTION {proceedings}
{ start.entry
  format.editors
  format.year
  format.title
  format.number.series
  "" "\city" address do.out
  "" "\pubname" publisher do.out
  "" "\organization" organization do.out
  stop.entry
}
 
FUNCTION {techreport}
{ start.entry
  format.authors
  format.year
  format.t.title
  format.tr.number
  "" "\city" address do.out
  "" "\pubname" institution do.out
  stop.entry
}
 
FUNCTION {unpublished}
{ start.entry
  format.authors
  format.year
  format.t.title
  "" "\month" month do.out
  stop.entry
}

% 4 additions from IEEEtran

FUNCTION {electronic}
{ start.entry
  format.authors
  format.year
  format.t.title
  "" "\month" month do.out
  "" "\city" address do.out
  "" "\organization" organization do.out
  "" "\howpublished" howpublished do.out
  stop.entry
}
FUNCTION {patent}
{ start.entry
  format.authors
  format.year
  format.t.title
  "" "\bibnumber" number do.out
  "" "\city" address do.out
  "" "\nationality" nationality do.out
  "" "\assignee" assignee do.out
  "" "\bibtype" type do.out
  "" "\month" month do.out
  "" "\monthfiled" monthfiled do.out
  "" "\yearfiled" yearfiled do.out
  "" "\day" day do.out
  "" "\dayfiled" dayfiled do.out
  stop.entry
}
FUNCTION {periodical}
{ start.entry
  format.editors
  format.year
  format.title
  format.number.series
  "" "\bibnumber" number do.out
  "" "\month" month do.out
  "" "\organization" organization do.out
  stop.entry
}
FUNCTION {standard}
{ start.entry
  format.authors
  format.year
  format.title
  "" "\bibtype" type do.out
  "" "\organization" organization do.out
  "" "\city" address do.out
  "" "\revision" revision do.out
  "" "\pubname" institution do.out
  "" "\howpublished" howpublished do.out
  "" "\bibnumber" number do.out
  "" "\month" month do.out
  stop.entry
}

FUNCTION {IEEEtranBSTCTL} { }

 
FUNCTION {default.type} { misc }

MACRO {jan} {"1"}
MACRO {feb} {"2"}
MACRO {mar} {"3"}
MACRO {apr} {"4"}
MACRO {may} {"5"}
MACRO {jun} {"6"}
MACRO {jul} {"7"}
MACRO {aug} {"8"}
MACRO {sep} {"9"}
MACRO {oct} {"10"}
MACRO {nov} {"11"}
MACRO {dec} {"12"}

READ

FUNCTION {initialize.ordinal.label}
{ #0 'ordinal.num := }

FUNCTION {set.ordinal.label} {
 #1 ordinal.num + 'ordinal.num :=
 ordinal.num int.to.str$ 'ordinal.label :=
}

EXECUTE {initialize.ordinal.label}

ITERATE {set.ordinal.label}
 
FUNCTION {sortify}
{ purify$
  "l" change.case$
}
 
FUNCTION {chop.word}
{ 's :=
  'len :=
  s #1 len substring$ =
    { s len #1 + global.max$ substring$ }
    's
  if$
}
 
FUNCTION {format.lab.names}
{ 's :=
  s #1 "{vv~}{ll}" format.name$
  "{" swap$ * "}" *
  s num.names$ duplicate$
  #1 > 
    { pop$ "," * }
    { pop$ }
  if$
  s num.names$ duplicate$
  #2 >
    { pop$ "{}" * }
    { #2 <
        'skip$
        { s #2 "{ff }{vv }{ll}{ jj}" format.name$ "others" =
            { "{}" * }
            { s #2 "{vv~}{ll}" format.name$ "{" swap$ * "}" * * }
          if$
        }
      if$
    }
  if$
  "{" swap$ * "}," *
}
 
FUNCTION {author.key.label}
{ author empty$
    { key empty$
        { "{" cite$ * "}," *}
        { "{" key * "}," * }
      if$
    }
    { author format.lab.names }
  if$
}
 
FUNCTION {author.editor.key.label}
{ author empty$
    { editor empty$
        { key empty$
           { "{" cite$ * "}," *}
           { "{" key * "}," * }
          if$
        }
        { editor format.lab.names }
      if$
    }
    { author format.lab.names }
  if$
}
 
FUNCTION {editor.key.label}
{ editor empty$
    { key empty$
        { "{" cite$ * "}," *}
        { "{" key * "}," * }
      if$
    }
    { editor format.lab.names }
  if$
}
 
FUNCTION {calc.label}
{ type$ "book" =
  type$ "inbook" =
  or
    'author.editor.key.label
    { type$ "proceedings" =
        'editor.key.label
        'author.key.label
      if$
    }
  if$
  "a=" swap$ * "y=" *
  year field.or.null purify$ #-1 #4 substring$
  *
  'label :=
}

INTEGERS { et.al.char.used }

FUNCTION {initialize.et.al.char.used}
{ #0 'et.al.char.used :=
}

EXECUTE {initialize.et.al.char.used}

FUNCTION {format.clab.names}
{ 's :=
  s num.names$ 'numnames :=
  numnames #1 >
    { numnames #4 >
	{ #3 'namesleft := }
	{ numnames 'namesleft := }
      if$
      #1 'nameptr :=
      ""
	{ namesleft #0 > }
	{ nameptr numnames =
	    { s nameptr "{ff }{vv }{ll}{ jj}" format.name$ "others" =
		{ "{\etalchar{+}}" *
		  #1 'et.al.char.used :=
		}
		{ s nameptr "{v{}}{l{}}" format.name$ * }
	      if$
	    }
	    { s nameptr "{v{}}{l{}}" format.name$ * }
	  if$
	  nameptr #1 + 'nameptr :=
	  namesleft #1 - 'namesleft :=
	}
      while$
      numnames #4 >
	{ "{\etalchar{+}}" *
	  #1 'et.al.char.used :=
	}
	'skip$
      if$
    }
    { s #1 "{v{}}{l{}}" format.name$
      duplicate$ text.length$ #2 <
	{ pop$ s #1 "{ll}" format.name$ #3 text.prefix$ }
	'skip$
      if$
    }
  if$
}

FUNCTION {author.key.clabel}
{ author empty$
    { key empty$
	{ cite$ #1 #3 substring$ }
	{ key #3 text.prefix$ }
      if$
    }
    { author format.clab.names }
  if$
}

FUNCTION {author.editor.key.clabel}
{ author empty$
    { editor empty$
	{ key empty$
	    { cite$ #1 #3 substring$ }
	    { key #3 text.prefix$ }
	  if$
	}
	{ editor format.clab.names }
      if$
    }
    { author format.clab.names }
  if$
}

FUNCTION {author.key.organization.clabel}
{ author empty$
    { key empty$
	{ organization empty$
	    { cite$ #1 #3 substring$ }
	    { "The " #4 organization chop.word #3 text.prefix$ }
	  if$
	}
	{ key #3 text.prefix$ }
      if$
    }
    { author format.clab.names }
  if$
}

FUNCTION {editor.key.organization.clabel}
{ editor empty$
    { key empty$
	{ organization empty$
	    { cite$ #1 #3 substring$ }
	    { "The " #4 organization chop.word #3 text.prefix$ }
	  if$
	}
	{ key #3 text.prefix$ }
      if$
    }
    { editor format.clab.names }
  if$
}

FUNCTION {calc.clabel}
{ type$ "book" =
  type$ "inbook" =
  or
    'author.editor.key.clabel
    { type$ "proceedings" =
	'editor.key.organization.clabel
	{ type$ "manual" =
	    'author.key.organization.clabel
	    'author.key.clabel
	  if$
	}
      if$
    }
  if$
  duplicate$
  year field.or.null purify$ #-1 #2 substring$
  *
  'clabel :=
  year field.or.null purify$ #-1 #4 substring$
  *
  sortify 'sort.clabel :=
}
 
FUNCTION {sort.format.names}
{ 's :=
  #1 'nameptr :=
  ""
  s num.names$ 'numnames :=
  numnames 'namesleft :=
    { namesleft #0 > }
    { nameptr #1 >
        { "   " * }
        'skip$
      if$
      s nameptr "{vv{ } }{ll{ }}{  f{ }}{  jj{ }}" format.name$ 't :=
      nameptr numnames = t "others" = and
        { "et al" * }
        { t sortify * }
      if$
      nameptr #1 + 'nameptr :=
      namesleft #1 - 'namesleft :=
    }
  while$
}
 
FUNCTION {sort.format.title}
{ 't :=
  "A " #2
    "An " #3
      "The " #4 t chop.word
    chop.word
  chop.word
  sortify
  #1 global.max$ substring$
}
 
FUNCTION {author.sort}
{ author empty$
    { key empty$
        { "to sort, need author or key in " cite$ * warning$
        }
        { key sortify }
      if$
    }
    { author sort.format.names }
  if$
}
 
FUNCTION {author.editor.sort}
{ author empty$
    { editor empty$
        { key empty$
            { "to sort, need author, editor, or key in " cite$ * warning$
            }
            { key sortify }
          if$
        }
        { editor sort.format.names }
      if$
    }
    { author sort.format.names }
  if$
}
 
FUNCTION {editor.sort}
{ editor empty$
    { key empty$
        { "to sort, need editor or key in " cite$ * warning$
        }
        { key sortify }
      if$
    }
    { editor sort.format.names }
  if$
}
 
FUNCTION {presort.title}
{ calc.label
  calc.clabel
  title field.or.null
  sort.format.title
  "    "
  *
  #1 entry.max$ substring$
  'sort.label :=
  sort.label
  'sort.key$ :=
}

FUNCTION {presort.author}
{ calc.clabel
  calc.label
  type$ "book" =
  type$ "inbook" =
  or
    'author.editor.sort
    { type$ "proceedings" =
        'editor.sort
        'author.sort
      if$
    }
  if$
  #1 entry.max$ substring$
  'sort.label :=
  sort.label
  'sort.key$ :=
}

FUNCTION {presort.clabel}
{ calc.label
  calc.clabel
  clabel sortify
  duplicate$ 'sort.label :=
  #1 entry.max$ substring$
  #1 entry.max$ substring$
  'sort.key$ :=
}

FUNCTION {presort.none}
{ calc.label
  calc.clabel
  "" 'sort.label :=
  "" 'sort.key$ :=
}
 
ITERATE {presort.title}
 
SORT
 
FUNCTION {initialize.extra.label.stuff}
{ #0 int.to.chr$ 'last.label :=
  "" 'next.extra :=
  #0 'last.extra.num :=
  #0 'ordinal.num :=
}
 
FUNCTION {forward.pass}
{ ordinal.num #1 + 'ordinal.num :=
  ordinal.num int.to.str$ 'nlabel :=
  last.label label =
    { last.extra.num #1 + 'last.extra.num :=
      last.extra.num int.to.chr$ 'extra.label :=
    }
    { "a" chr.to.int$ 'last.extra.num :=
      "" 'extra.label :=
      label 'last.label :=
    }
  if$
}
 
FUNCTION {reverse.pass}
{ next.extra "b" =
    { "a" 'extra.label := }
    'skip$
  if$
  label extra.label * 'label :=
  clabel extra.label * 'clabel :=
  extra.label 'next.extra :=
  clabel width$ longest.label.width >
    { clabel 'longest.label :=
      clabel width$ 'longest.label.width :=
    }
    'skip$
  if$
}
 
EXECUTE {initialize.extra.label.stuff}

FUNCTION {initialize.longest.label}
{ "" 'longest.label :=
  #0 int.to.chr$ 'last.sort.label :=
  "" 'next.extra :=
  #0 'longest.label.width :=
  #0 'last.extra.num :=
}

EXECUTE {initialize.longest.label}
 
ITERATE {forward.pass}
 
REVERSE {reverse.pass}
 
FUNCTION {bib.sort.order.author}
{ sort.label
  "    "
  *
  year field.or.null sortify
  *
  "    "
  *
  title field.or.null
  sort.format.title
  *
  #1 entry.max$ substring$
  'sort.key$ :=
}

FUNCTION {bib.sort.order.title}
{ sort.label
  "    "
  *
  type$ "book" =
  type$ "inbook" =
  or
    'author.editor.sort
    { type$ "proceedings" =
        'editor.sort
        'author.sort
      if$
    }
  if$
  *
  "    "
  *
  year field.or.null sortify
  *
  #1 entry.max$ substring$
  'sort.key$ :=
}

FUNCTION {bib.sort.order.clabel}
{ sort.label
  "    "
  *
  title field.or.null
  sort.format.title
  *
  #1 entry.max$ substring$
  'sort.key$ :=
}
 
FUNCTION {bib.sort.order.none}
{ sort.label 'sort.key$ :=
}

ITERATE {bib.sort.order.title}
 
SORT
 
EXECUTE {begin.bib}
 
ITERATE {call.type$}
 
 
EXECUTE {end.bib}
