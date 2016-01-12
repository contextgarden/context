dofile("bibl-bib.lua")

local session = bibtex.new()

bibtex.load(session,"gut.bib")
bibtex.load(session,"komoedie.bib")
bibtex.load(session,"texbook1.bib")
bibtex.load(session,"texbook2.bib")
bibtex.load(session,"texbook3.bib")
bibtex.load(session,"texgraph.bib")
bibtex.load(session,"texjourn.bib")
bibtex.load(session,"texnique.bib")
bibtex.load(session,"tugboat.bib")
print(bibtex.size,statistics.elapsedtime(bibtex))
bibtex.toxml(session)
print(bibtex.size,statistics.elapsedtime(bibtex))

--~ print(table.serialize(session.data))
--~ print(table.serialize(session.shortcuts))
--~ print(xml.serialize(session.xml))

