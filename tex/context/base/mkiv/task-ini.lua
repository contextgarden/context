if not modules then modules = { } end modules ['task-ini'] = {
    version   = 1.001,
    comment   = "companion to task-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- this is a temporary solution, we need to isolate some modules and then
-- the load order can determine the trickery to be applied to node lists
--
-- we can disable more handlers and enable then when really used (*)
--
-- todo: two finalizers: real shipout (can be imposed page) and page shipout (individual page)
--
-- todo: consider moving the kernel kerning/ligaturing functions in the main font loop because
-- there we know if they are needed; doesn't save time but; if we overload unh* commands to
-- not apply the font handler, we can remove all checks for subtypes 255

local tasks           = nodes.tasks
local appendaction    = tasks.appendaction
local disableaction   = tasks.disableaction
local enableaction    = tasks.enableaction
local freezegroup     = tasks.freezegroup
local freezecallbacks = callbacks.freeze

------------("processors",   "before",      "nodes.properties.attach",                          nil, "nut",    "enabled"   )

appendaction("processors",   "normalizers", "typesetters.periodkerns.handler",                  nil, "nut",    "disabled"  )
appendaction("processors",   "normalizers", "languages.replacements.handler",                   nil, "nut",    "disabled"  )
appendaction("processors",   "normalizers", "typesetters.wrappers.handler",                     nil, "nut",    "disabled"  )
appendaction("processors",   "normalizers", "typesetters.characters.handler",                   nil, "nut",    "enabled"   )
appendaction("processors",   "normalizers", "fonts.collections.process",                        nil, "nut",    "disabled"  )
appendaction("processors",   "normalizers", "fonts.checkers.missing",                           nil, "nut",    "disabled"  )

appendaction("processors",   "characters",  "scripts.autofontfeature.handler",                  nil, "nut",    "disabled"  )
appendaction("processors",   "characters",  "scripts.splitters.handler",                        nil, "nut",    "disabled"  )
appendaction("processors",   "characters",  "typesetters.cleaners.handler",                     nil, "nut",    "disabled"  )
appendaction("processors",   "characters",  "typesetters.directions.handler",                   nil, "nut",    "disabled"  )
appendaction("processors",   "characters",  "typesetters.cases.handler",                        nil, "nut",    "disabled"  )
appendaction("processors",   "characters",  "typesetters.breakpoints.handler",                  nil, "nut",    "disabled"  )
appendaction("processors",   "characters",  "scripts.injectors.handler",                        nil, "nut",    "disabled"  )

appendaction("processors",   "words",       "languages.words.check",                            nil, "nut",    "disabled"  )
appendaction("processors",   "words",       "languages.hyphenators.handler",                    nil, "nut",    "enabled"   )
appendaction("processors",   "words",       "typesetters.initials.handler",                     nil, "nut",    "disabled"  )
appendaction("processors",   "words",       "typesetters.firstlines.handler",                   nil, "nut",    "disabled"  )

appendaction("processors",   "fonts",       "builders.paragraphs.solutions.splitters.split",    nil, "nut",    "disabled"  )
appendaction("processors",   "fonts",       "nodes.handlers.characters",                        nil, "nut",    "enabled"   )
appendaction("processors",   "fonts",       "nodes.injections.handler",                         nil, "nut",    "enabled"   )
appendaction("processors",   "fonts",       "typesetters.fontkerns.handler",                    nil, "nut",    "disabled"  )
appendaction("processors",   "fonts",       "nodes.handlers.protectglyphs",                     nil, "nonut",  "enabled"   )
appendaction("processors",   "fonts",       "builders.kernel.ligaturing",                       nil, "nut",    "disabled"  )
appendaction("processors",   "fonts",       "builders.kernel.kerning",                          nil, "nut",    "disabled"  )
appendaction("processors",   "fonts",       "builders.kernel.cleanup",                          nil, "nut",    "enabled"   )
appendaction("processors",   "fonts",       "nodes.handlers.stripping",                         nil, "nut",    "disabled"  )
appendaction("processors",   "fonts",       "nodes.handlers.flatten",                           nil, "nut",    "disabled"  )
appendaction("processors",   "fonts",       "fonts.goodies.colorschemes.coloring",              nil, "nut",    "disabled"  )

appendaction("processors",   "lists",       "typesetters.rubies.check",                         nil, "nut",    "disabled"  )
appendaction("processors",   "lists",       "typesetters.characteralign.handler",               nil, "nut",    "disabled"  )
appendaction("processors",   "lists",       "typesetters.spacings.handler",                     nil, "nut",    "disabled"  )
appendaction("processors",   "lists",       "typesetters.kerns.handler",                        nil, "nut",    "disabled"  )
appendaction("processors",   "lists",       "typesetters.digits.handler",                       nil, "nut",    "disabled"  )
appendaction("processors",   "lists",       "typesetters.italics.handler",                      nil, "nut",    "disabled"  )
appendaction("processors",   "lists",       "languages.visualizediscretionaries",               nil, "nut",    "disabled"  )

appendaction("processors",   "after",       "typesetters.marksuspects",                         nil, "nut",    "disabled"  )

appendaction("shipouts",     "normalizers", "typesetters.showsuspects",                         nil, "nut",    "disabled"  )
appendaction("shipouts",     "normalizers", "typesetters.margins.finalhandler",                 nil, "nut",    "disabled"  )
------------("shipouts",     "normalizers", "nodes.handlers.cleanuppage",                       nil, "nut",    "disabled"  )
appendaction("shipouts",     "normalizers", "builders.paragraphs.expansion.trace",              nil, "nut",    "disabled"  )
appendaction("shipouts",     "normalizers", "typesetters.alignments.handler",                   nil, "nut",    "disabled"  )
appendaction("shipouts",     "normalizers", "nodes.references.handler",                         nil, "nut",    "production")
appendaction("shipouts",     "normalizers", "nodes.destinations.handler",                       nil, "nut",    "production")
appendaction("shipouts",     "normalizers", "nodes.rules.handler",                              nil, "nut",    "disabled"  )
appendaction("shipouts",     "normalizers", "nodes.shifts.handler",                             nil, "nut",    "disabled"  )
appendaction("shipouts",     "normalizers", "structures.tags.handler",                          nil, "nut",    "disabled"  )
appendaction("shipouts",     "normalizers", "nodes.handlers.accessibility",                     nil, "nut",    "disabled"  )
appendaction("shipouts",     "normalizers", "nodes.handlers.backgrounds",                       nil, "nut",    "disabled"  )
appendaction("shipouts",     "normalizers", "typesetters.rubies.attach",                        nil, "nut",    "disabled"  )
------------("shipouts",     "normalizers", "nodes.properties.delayed",                         nil, "nut",    "production")

appendaction("shipouts",     "finishers",   "nodes.visualizers.handler",                        nil, "nut",    "disabled"  )
appendaction("shipouts",     "finishers",   "attributes.colors.handler",                        nil, "nut",    "disabled"  )
appendaction("shipouts",     "finishers",   "attributes.transparencies.handler",                nil, "nut",    "disabled"  )
appendaction("shipouts",     "finishers",   "attributes.colorintents.handler",                  nil, "nut",    "disabled"  )
appendaction("shipouts",     "finishers",   "attributes.negatives.handler",                     nil, "nut",    "disabled"  )
appendaction("shipouts",     "finishers",   "attributes.effects.handler",                       nil, "nut",    "disabled"  )
appendaction("shipouts",     "finishers",   "attributes.viewerlayers.handler",                  nil, "nut",    "disabled"  )

appendaction("shipouts",     "wrapup",      "nodes.handlers.export",                            nil, "nut",    "disabled"  )  -- always last
appendaction("shipouts",     "wrapup",      "luatex.synctex.collect",                           nil, "nut",    "disabled"  )

appendaction("math",         "normalizers", "noads.handlers.showtree",                          nil, "nonut",  "disabled"  )
appendaction("math",         "normalizers", "noads.handlers.unscript",                          nil, "nonut",  "enabled"   )
appendaction("math",         "normalizers", "noads.handlers.unstack",                           nil, "nonut",  "disabled"  )
appendaction("math",         "normalizers", "noads.handlers.variants",                          nil, "nonut",  "enabled"   )
appendaction("math",         "normalizers", "noads.handlers.relocate",                          nil, "nonut",  "enabled"   )
appendaction("math",         "normalizers", "noads.handlers.families",                          nil, "nonut",  "enabled"   )
appendaction("math",         "normalizers", "noads.handlers.render",                            nil, "nonut",  "enabled"   )
appendaction("math",         "normalizers", "noads.handlers.collapse",                          nil, "nonut",  "disabled"  )
appendaction("math",         "normalizers", "noads.handlers.fixscripts",                        nil, "nonut",  "enabled"   )
appendaction("math",         "normalizers", "noads.handlers.domains",                           nil, "nonut",  "disabled"  )
appendaction("math",         "normalizers", "noads.handlers.autofences",                        nil, "nonut",  "disabled"  )
appendaction("math",         "normalizers", "noads.handlers.resize",                            nil, "nonut",  "enabled"   )
------------("math",         "normalizers", "noads.handlers.respace",                           nil, "nonut",  "enabled"   )
appendaction("math",         "normalizers", "noads.handlers.alternates",                        nil, "nonut",  "enabled"   )
appendaction("math",         "normalizers", "noads.handlers.tags",                              nil, "nonut",  "disabled"  )
appendaction("math",         "normalizers", "noads.handlers.italics",                           nil, "nonut",  "disabled"  )
appendaction("math",         "normalizers", "noads.handlers.kernpairs",                         nil, "nonut",  "disabled"  )
appendaction("math",         "normalizers", "noads.handlers.classes",                           nil, "nonut",  "disabled"  )

appendaction("math",         "builders",    "builders.kernel.mlist_to_hlist",                   nil, "nut",    "enabled"   )  -- mandate
appendaction("math",         "builders",    "typesetters.directions.processmath",               nil, "nut",    "disabled"  )
appendaction("math",         "builders",    "noads.handlers.makeup",                            nil, "nonut",  "disabled"  )
appendaction("math",         "builders",    "noads.handlers.align",                             nil, "nonut",  "enabled"   )

appendaction("finalizers",   "lists",       "typesetters.paragraphs.normalize",                 nil, "nut",    "enabled"   ) -- "disabled"
appendaction("finalizers",   "lists",       "typesetters.margins.localhandler",                 nil, "nut",    "disabled"  )
appendaction("finalizers",   "lists",       "builders.paragraphs.keeptogether",                 nil, "nut",    "disabled"  )
appendaction("finalizers",   "fonts",       "builders.paragraphs.solutions.splitters.optimize", nil, "nonut",  "disabled"  )
appendaction("finalizers",   "lists",       "builders.paragraphs.tag",                          nil, "nut",    "disabled"  )
appendaction("finalizers",   "lists",       "nodes.linefillers.handler",                        nil, "nut",    "disabled"  )

appendaction("contributers", "normalizers", "nodes.handlers.flattenline",                       nil, "nut",    "disabled"  )
appendaction("contributers", "normalizers", "nodes.handlers.textbackgrounds",                   nil, "nut",    "disabled"  )

appendaction("vboxbuilders", "normalizers", "nodes.handlers.backgroundsvbox",                   nil, "nut",    "disabled"  )
------------("vboxbuilders", "normalizers", "typesetters.margins.localhandler",                 nil, "nut",    "disabled"  )
appendaction("vboxbuilders", "normalizers", "builders.vspacing.vboxhandler",                    nil, "nut",    "enabled"   )
appendaction("vboxbuilders", "normalizers", "builders.profiling.vboxhandler",                   nil, "nut",    "disabled"  )
appendaction("vboxbuilders", "normalizers", "typesetters.checkers.handler",                     nil, "nut",    "disabled"  )

appendaction("mvlbuilders",  "normalizers", "nodes.handlers.backgroundspage",                   nil, "nut",    "disabled"  )
appendaction("mvlbuilders",  "normalizers", "typesetters.margins.globalhandler",                nil, "nut",    "disabled"  )
appendaction("mvlbuilders",  "normalizers", "nodes.handlers.migrate",                           nil, "nut",    "disabled"  )
appendaction("mvlbuilders",  "normalizers", "builders.vspacing.pagehandler",                    nil, "nut",    "enabled"   )
appendaction("mvlbuilders",  "normalizers", "builders.profiling.pagehandler",                   nil, "nut",    "disabled"  )
appendaction("mvlbuilders",  "normalizers", "typesetters.checkers.handler",                     nil, "nut",    "disabled"  )

appendaction("everypar",     "normalizers", "nodes.handlers.checkparcounter",                   nil, "nut",    "disabled"  )

-- some protection

freezecallbacks("find_.*_file", "find file using resolver")
freezecallbacks("read_.*_file", "read file at once")
freezecallbacks("open_.*_file", "open file for reading")

-- experimental:

freezegroup("processors",   "normalizers")
freezegroup("processors",   "characters")
freezegroup("processors",   "words")
freezegroup("processors",   "fonts")
freezegroup("processors",   "lists")

freezegroup("finalizers",   "normalizers")
freezegroup("finalizers",   "fonts")
freezegroup("finalizers",   "lists")

freezegroup("math",         "normalizers")
freezegroup("math",         "builders")

freezegroup("shipouts",     "normalizers")
freezegroup("shipouts",     "finishers")
freezegroup("shipouts",     "wrapup")

freezegroup("mvlbuilders",  "normalizers")
freezegroup("vboxbuilders", "normalizers")

-----------("parbuilders",  "lists")
-----------("pagebuilders", "lists")

freezegroup("math",         "normalizers")
freezegroup("math",         "builders")

freezegroup("everypar",     "normalizers")

-- new: disabled here

directives.register("nodes.basepass", function(v)
    if v then
         enableaction("processors",  "builders.kernel.ligaturing")
         enableaction("processors",  "builders.kernel.kerning")
    else
         disableaction("processors", "builders.kernel.ligaturing")
         disableaction("processors", "builders.kernel.kerning")
    end
end)
