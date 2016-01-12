if not modules then modules = { } end modules ['s-languages-counters'] = {
    version   = 1.001,
    comment   = "companion to s-languages-counters.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

require("util-tpl")
require("util-sql")
require("util-sql-tracers")

moduledata            = moduledata            or { }
moduledata.sql        = moduledata.sql        or { }
moduledata.sql.tables = moduledata.sql.tables or { }

local context = context

function moduledata.sql.showfields(specification) -- not that sql specific
    local data = specification.data
    if data and #data > 0 then
        local keys = specification.order or table.sortedkeys(data[1])
        local align = specification.align
        local template = "|"
        if type(align) == "table" then
            for i=1,#keys do
                template = template .. (align[keys[i]] or "c") .. "|"
            end
        else
            template = template .. string.rep((align or "c").. "|",#keys)
        end
        context.starttabulate { template }
        context.NC()
        for i=1,#keys do
            context(keys[i])
            context.NC()
        end
        context.NR()
        context.HL()
        for i=specification.first or 1,specification.last or #data do
            local d = data[i]
            context.NC()
            for i=1,#keys do
                context(d[keys[i]])
                context.NC()
            end
            context.NR()
        end
        context.stoptabulate()
    end
end

function moduledata.sql.validpresets(presets)
    local okay = true
    if presets.database == "" then
        context("No database given.")
        context.blank()
        okay = false
    end
    if presets.password == "" then
        context("No password given")
        context.blank()
        okay = false
    end
    return okay
end

function moduledata.sql.tables.showdefined(presets) -- key=value string | { presets = "name" } | { presets }

    if type(presets) == "string" then
        local specification = interfaces.checkedspecification(presets)
        if specification.presets then
            presets = table.load(specification.presets) or { }
        end
    end

    if type(presets.presets) == "string" then
        presets = table.load(presets.presets) or { }
    end

    if not moduledata.sql.validpresets(presets) then
        return
    end

    local sql_tables = utilities.sql.tracers.gettables(presets)

    context.starttitle { title = presets.database }

        for name, fields in table.sortedhash(sql_tables) do

            context.startsubject { title = name }

                context.starttabulate { format = "|l|l|l|l|l|p|" }
                context.FL()
                context.NC() context.bold("field")
                context.NC() context.bold("type")
                context.NC() context.bold("default")
                context.NC() context.bold("null")
                context.NC() context.bold("key")
                context.NC() context.bold("extra")
                context.NC() context.NR()
                context.TL()
                for i=1,#fields do
                    local field = fields[i]
                    context.NC() context(field.field)
                    context.NC() context(field.type)
                    context.NC() context(field.default)
                    context.NC() context(field.null)
                    context.NC() context(field.key)
                    context.NC() context(field.extra)
                    context.NC() context.NR()
                end
                context.LL()
                context.stoptabulate()

            context.stopsubject()
        end

    context.stoptitle()

end

function moduledata.sql.tables.showconstants(list)

    context.starttitle { title = "Constants" }

        for name, fields in table.sortedhash(list) do

            if type(fields) == "table" and #fields > 0 then

                context.startsubject { title = name }

                    context.starttabulate { format = "|l|l|" }
                    for i=0,#fields do
                        local field = fields[i]
                        if field then
                            context.NC() context(i)
                            context.NC() context(field)
                            context.NC() context.NR()
                        end
                    end
                    context.stoptabulate()

                context.stopsubject()

            end

        end

    context.stoptitle()

end
