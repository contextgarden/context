local info = {
    version   = 1.002,
    comment   = "presets for textadept for context/metafun",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local lexer   = require("scite-context-lexer")
local context = lexer.context

if context then

    function context.synchronize()
        local buffer        = buffer
        local property      = lexer.property
        local property_int  = lexer.property_int

        buffer:set_fold_margin_colour    (true,  property_int["color.light"])
        buffer:set_fold_margin_hi_colour (true,  property_int["color.white"])
        buffer:set_sel_fore              (false, property_int["color.dark"])
        buffer:set_sel_back              (true,  property_int["color.selection"])

        local MARK_BOOKMARK                    = textadept.bookmarks.MARK_BOOKMARK
        local MARK_WARNING                     = textadept.run.MARK_WARNING
        local MARK_ERROR                       = textadept.run.MARK_ERROR

     -- buffer.marker_fore[MARK_BOOKMARK]      = property_int["color.white"]
        buffer.marker_back[MARK_BOOKMARK]      = property_int["color.blue"]
     -- buffer.marker_fore[MARK_WARNING]       = property_int["color.white"]
        buffer.marker_back[MARK_WARNING]       = property_int["color.orange"]
     -- buffer.marker_fore[MARK_ERROR]         = property_int["color.white"]
        buffer.marker_back[MARK_ERROR]         = property_int["color.red"]
        for i = 25, 31 do
            buffer.marker_fore[i]              = property_int["color.white"]
            buffer.marker_back[i]              = property_int["color.grey"]
            buffer.marker_back_selected[i]     = property_int["color.dark"]
        end

        local INDIC_BRACEMATCH                 = textadept.editing .INDIC_BRACEMATCH
        local INDIC_HIGHLIGHT                  = textadept.editing .INDIC_HIGHLIGHT
        local INDIC_PLACEHOLDER                = textadept.snippets.INDIC_PLACEHOLDER
        local INDIC_FIND                       = ui.find.INDIC_FIND

        buffer.indic_fore [INDIC_FIND]         = property_int["color.gray"]
        buffer.indic_alpha[INDIC_FIND]         = 255
        buffer.indic_fore [INDIC_BRACEMATCH]   = property_int["color.orange"]
        buffer.indic_style[INDIC_BRACEMATCH]   = buffer.INDIC_BOX -- hard to see (I need to check scite)
        buffer.indic_fore [INDIC_HIGHLIGHT]    = property_int["color.gray"]
        buffer.indic_alpha[INDIC_HIGHLIGHT]    = 255
        buffer.indic_fore [INDIC_PLACEHOLDER]  = property_int["color.gray"]

     -- buffer:brace_highlight_indicator(false,  INDIC_BRACEMATCH)

     -- buffer.call_tip_fore_hlt               = property_int["color.blue"]
        buffer.edge_colour                     = property_int["color.grey"]

        buffer.tab_width                       = 4
        buffer.use_tabs                        = false
        buffer.indent                          = 4
        buffer.tab_indents                     = true
        buffer.back_space_un_indents           = true
        buffer.indentation_guides              = not CURSES and buffer.IV_LOOKBOTH or buffer.IV_NONE
        buffer.wrap_length                     = 80 

        buffer.sel_eol_filled                  = true
     -- buffer.sel_alpha                       =
        buffer.multiple_selection              = true
        buffer.additional_selection_typing     = true
     -- buffer.multi_paste                     = buffer.MULTIPASTE_EACH
     -- buffer.virtual_space_options           = buffer.VS_RECTANGULARSELECTION + buffer.VS_USERACCESSIBLE
        buffer.rectangular_selection_modifier  = buffer.MOD_ALT
        buffer.mouse_selection_rectangular_switch = true

     -- buffer.additional_sel_alpha            =
     -- buffer.additional_sel_fore             =
     -- buffer.additional_sel_back             =

        -- how to turn of the annoying background behind the current line ...

     -- buffer.additional_caret_fore           =
     -- buffer.additional_carets_blink         = false
     -- buffer.additional_carets_visible       = false
        buffer.caret_line_visible              = false -- not CURSES and buffer ~= ui.command_entry
        buffer.caret_line_visible_always       = false
     -- buffer.caret_period                    = 0
     -- buffer.caret_style                     = buffer.CARETSTYLE_BLOCK
        buffer.caret_width                     = 10
        buffer.caret_sticky                    = buffer.CARETSTICKY_ON
        buffer.caret_fore                      = property_int["color.black"]
        buffer.caret_line_back                 = property_int["color.light"]
     -- buffer.caret_line_back_alpha           =

        buffer.view_ws                         = buffer.WS_INVISIBLE
        buffer.view_eol                        = false

        buffer.annotation_visible              = buffer.ANNOTATION_BOXED

        local NUMBER_MARGIN                    = 0
        local MARKER_MARGIN                    = 1
        local FOLD_MARGIN                      = 2  -- there are more

        buffer.margin_type_n [NUMBER_MARGIN]   = buffer.MARGIN_NUMBER
        buffer.margin_width_n[NUMBER_MARGIN]   = (CURSES and 0 or 6) + 4 * buffer:text_width(buffer.STYLE_LINENUMBER,'9') -- magic
        buffer.margin_width_n[MARKER_MARGIN]   =  CURSES and 1 or 18
        buffer.margin_width_n[FOLD_MARGIN]     =  CURSES and 1 or 18

        buffer.margin_mask_n[FOLD_MARGIN]      = buffer.MASK_FOLDERS -- does something weird: bullets

        buffer:marker_define(buffer.MARKNUM_FOLDEROPEN,    buffer.MARK_BOXMINUS)
        buffer:marker_define(buffer.MARKNUM_FOLDER,        buffer.MARK_BOXPLUS)
        buffer:marker_define(buffer.MARKNUM_FOLDERSUB,     buffer.MARK_VLINE)
        buffer:marker_define(buffer.MARKNUM_FOLDERTAIL,    buffer.MARK_LCORNER)
        buffer:marker_define(buffer.MARKNUM_FOLDEREND,     buffer.MARK_BOXPLUSCONNECTED)
        buffer:marker_define(buffer.MARKNUM_FOLDEROPENMID, buffer.MARK_BOXMINUSCONNECTED)
        buffer:marker_define(buffer.MARKNUM_FOLDERMIDTAIL, buffer.MARK_TCORNER)

     -- buffer.fold_all = buffer.FOLDACTION_CONTRACT + buffer.FOLDACTION_EXPAND + buffer.FOLDACTION_TOGGLE

        -- somehow the foldeing sumbol sin th emargin cannot be clicked on ... there seems to be some
        -- interface .. if this needs to be implemented via events i'll then probably make a copy and
        -- start doing all

     -- buffer.margin_sensitive_n[2] = true

     -- buffer.property['fold']                = "1"
     -- buffer.automatic_fold                  = buffer.AUTOMATICFOLD_SHOW + buffer.AUTOMATICFOLD_CLICK + buffer.AUTOMATICFOLD_CHANGE
     -- buffer.fold_flags                      = not CURSES and buffer.FOLDFLAG_LINEAFTER_CONTRACTED or 0
     -- buffer.fold_display_text_style         = buffer.FOLDDISPLAYTEXT_BOXED

        buffer.wrap_mode                       = buffer.WRAP_NONE

        buffer.margin_back_n[NUMBER_MARGIN]    = property_int["color.linenumber"] -- doesn't work

        buffer.property     = {
         -- ["style.linenumber"] = property["style.linenumber"], -- somehow it fails
        }

        buffer.property_int = {
            -- nothing
        }

    --     keys [OSX and 'mr' or                  'cr'  ] = textadept.run.run
    --     keys [OSX and 'mR' or (GUI and 'cR' or 'cmr')] = textadept.run.compile
    --     keys [OSX and 'mB' or (GUI and 'cB' or 'cmb')] = textadept.run.build
    --     keys [OSX and 'mX' or (GUI and 'cX' or 'cmx')] = textadept.run.stop

    end

    context.synchronize()

end
