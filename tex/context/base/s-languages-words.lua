if not modules then modules = { } end modules ['s-languages-words'] = {
    version   = 1.001,
    comment   = "companion to s-languages-words.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

moduledata.languages       = moduledata.languages       or { }
moduledata.languages.words = moduledata.languages.words or { }

function moduledata.languages.words.showwords(specification)
    local filename = specification.filename or file.addsuffix(tex.jobname,"words")
    if lfs.isfile(filename) then
        local w = dofile(filename)
        if w then
         -- table.print(w)
            for cname, category in table.sortedpairs(w.categories) do
                for lname, language in table.sortedpairs(category.languages) do
                    context.bold(string.format("category: %s, language: %s, total: %s, unique: %s:",
                        cname, lname, language.total or 0, language.unique or 0)
                    )
                    for word, n in table.sortedpairs(language.list) do
                        context(" %s (%s)",word,n)
                    end
                    context.par()
                end
            end
        end
    end
end

