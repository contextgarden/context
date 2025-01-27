/*
    See license.txt in the root of this project.
*/

# include "luametatex.h"

/*tex 

    This a fun project of Mikael & Hans, so don't complain. The intended usage (in \CONTEXT) 
    is in columnsets. We hope to have a reasonable stable version for BT 2025 and a release at 
    CTX 2025 and will wrap up in an article as we did with parpasses in 2024.  

    Some remarks: 

    \startitemize 
    \startitem We have topskip and bottomskip. \stopitem 
    \startitem For now we rejected vertical discretionaries. \stopitem 
    \startitem We assume end notes etc. so no inserts! \stopitem 
    \startitem We considered demerits on spread for a while. \stopitem 
    \startitem There is a balance penalty equivalent for line penalty. \stopitem 
    \startitem We added balance passes akin par passes. \stopitem 
    \startitem Ther eis a trial mode too. \stopitem 
    \stopitemize 

    and 

    \startitemize 
    \startitem We will handle excepts. \stopitem 
    \startitem We might skip over excessive overfull. \stopitem 
    \startitem We will add balancing loops. \stopitem 
    \startitem We will look into adjust. \stopitem 
    \stopitemize 

    plus todo: 

    \startitemize 
    \startitem check usage of temphead (in helpers) \stopitem 
    \startitem share callback functions and use generic contexts \stopitem 
    \startitem always shape: continue or repeat, less code that way \stopitem 
    \startitem get rid of this first and second \stopitem 
    \stopitemize 

    We considered vertical discretionaries but there are several problems with this, consider for 
    instance: 

    <line> <vskip> <pre><post><replace> <vskip> <line>

    When replace is empty we don't want twice the skip. When we put skips in the elements we need 
    to handle glue inside there. It all complicates matters. Also, defining this at the tex end is 
    fuzzy. And then we need to adapt al the lua code that operates on vertical boxes. So, in the 
    end the code was removed. 

*/

typedef enum balance_states {
    balance_no_pass,
    balance_first_pass,
    balance_second_pass,
    balance_final_pass,
    balance_specification_pass,
} balance_states;

balance_state_info lmt_balance_state = {
    .just_box                 = null,
    .no_shrink_error_yet      = 1,
    .threshold                = 0,
    .quality                  = 0,
    .callback_id              = 0,
    .extra_background_stretch = 0,
    .extra_background_shrink  = 0,
    .passive                  = null,
    .printed_node             = null,
    .serial_number            = 0,
    .active_height            = { 0 },
    .background               = { 0 },
    .break_height             = { 0 },
    .minimal_demerits         = { 0 },
    .minimum_demerits         = awful_bad,
    .easy_page                = 0,
    .last_special_page        = 0,
    .target_height            = 0, 
    .first_height             = 0,
    .second_height            = 0,
    .first_topskip            = null,
    .second_topskip           = null,
    .first_bottomskip         = null,
    .second_bottomskip        = null,
    .first_options            = 0,
    .second_options           = 0,
    .emergency_amount         = 0,
    .emergency_percentage     = 0,
    .emergency_factor         = scaling_factor,
    .emergency_height_amount  = 0,
    .best_bet                 = null,
    .fewest_demerits          = 0,
    .best_page                = 0,
    .actual_looseness         = 0,
    .warned                   = 0,
    .inserts_found            = 0,
    .total_inserts_found      = 0,
    .total_inserts_checked    = 0,
    .discards_found           = 0,
    .n_of_callbacks           = 0,
    .passes                   = { 0 },
    .artificial_encountered   = 0, 
    .current_slot_number      = 0,
    .default_fitness_classes  = 0,
};

typedef enum fill_orders {
    fi_order    = 0,
    fil_order   = 1,
    fill_order  = 2,
    filll_order = 3,
} fill_orders;

static void tex_aux_pre_balance (
    const balance_properties *properties,
    int                       callback_id,
    halfword                  checks,
    int                       state /* not used here */
);

static void tex_aux_post_balance (
    const balance_properties *properties,
    int                       callback_id,
    halfword                  checks,
    int                       state /* not used here */
);

/* */

static scaled tex_aux_checked_shrink(halfword p)
{
    if (glue_shrink(p) && glue_shrink_order(p) != normal_glue_order) {
        if (lmt_balance_state.no_shrink_error_yet) {
            lmt_balance_state.no_shrink_error_yet = 0;
            tex_handle_error(
                normal_error_type,
                "Infinite glue shrinkage found in a (balance) slot",
                "The (balance) slot just ended includes some glue that has infinite shrinkability.\n"
            );
        }
        glue_shrink_order(p) = normal_glue_order;
    }
    return glue_shrink(p);
}

static void tex_aux_clean_up_the_memory(void)
{
    halfword q = node_next(active_head);
    while (q != active_head) {
        halfword p = node_next(q);
        tex_flush_node(q);
        q = p;
    }
    node_next(active_head) = null;
    q = lmt_balance_state.passive;
    while (q) {
        halfword p = node_next(q);
        tex_flush_node(q);
        q = p;
    }
    lmt_balance_state.passive = null;
}

static inline void tex_aux_set_target_to_source(scaled target[], const scaled source[])
{
    for (int i = total_advance_amount; i <= total_shrink_amount; i++) {
        target[i] = source[i];
    }
}

static inline void tex_aux_add_to_target_from_delta(scaled target[], halfword delta)
{
    target[total_advance_amount] += delta_field_total_glue(delta);
    target[total_stretch_amount] += delta_field_total_stretch(delta);
    target[total_fi_amount]      += delta_field_total_fi_amount(delta);
    target[total_fil_amount]     += delta_field_total_fil_amount(delta);
    target[total_fill_amount]    += delta_field_total_fill_amount(delta);
    target[total_filll_amount]   += delta_field_total_filll_amount(delta);
    target[total_shrink_amount]  += delta_field_total_shrink(delta);
}

static inline void tex_aux_sub_delta_from_target(scaled target[], halfword delta)
{
    target[total_advance_amount] -= delta_field_total_glue(delta);
    target[total_stretch_amount] -= delta_field_total_stretch(delta);
    target[total_fi_amount]      -= delta_field_total_fi_amount(delta);
    target[total_fil_amount]     -= delta_field_total_fil_amount(delta);
    target[total_fill_amount]    -= delta_field_total_fill_amount(delta);
    target[total_filll_amount]   -= delta_field_total_filll_amount(delta);
    target[total_shrink_amount]  -= delta_field_total_shrink(delta);
}

static inline void tex_aux_add_to_delta_from_delta(halfword target, halfword source)
{
    delta_field_total_glue(target)         += delta_field_total_glue(source);
    delta_field_total_stretch(target)      += delta_field_total_stretch(source);
    delta_field_total_fi_amount(target)    += delta_field_total_fi_amount(source);
    delta_field_total_fil_amount(target)   += delta_field_total_fil_amount(source);
    delta_field_total_fill_amount(target)  += delta_field_total_fill_amount(source);
    delta_field_total_filll_amount(target) += delta_field_total_filll_amount(source);
    delta_field_total_shrink(target)       += delta_field_total_shrink(source);
}

static inline void tex_aux_set_delta_from_difference(halfword delta, const scaled source_1[], const scaled source_2[])
{
    delta_field_total_glue(delta)         = (source_1[total_advance_amount] - source_2[total_advance_amount]);
    delta_field_total_stretch(delta)      = (source_1[total_stretch_amount] - source_2[total_stretch_amount]);
    delta_field_total_fi_amount(delta)    = (source_1[total_fi_amount]      - source_2[total_fi_amount]);
    delta_field_total_fil_amount(delta)   = (source_1[total_fil_amount]     - source_2[total_fil_amount]);
    delta_field_total_fill_amount(delta)  = (source_1[total_fill_amount]    - source_2[total_fill_amount]);
    delta_field_total_filll_amount(delta) = (source_1[total_filll_amount]   - source_2[total_filll_amount]);
    delta_field_total_shrink(delta)       = (source_1[total_shrink_amount]  - source_2[total_shrink_amount]);
}

static inline void tex_aux_add_delta_from_difference(halfword delta, const scaled source_1[], const scaled source_2[])
{
    delta_field_total_glue(delta)         += (source_1[total_advance_amount] - source_2[total_advance_amount]);
    delta_field_total_stretch(delta)      += (source_1[total_stretch_amount] - source_2[total_stretch_amount]);
    delta_field_total_fi_amount(delta)    += (source_1[total_fi_amount]      - source_2[total_fi_amount]);
    delta_field_total_fil_amount(delta)   += (source_1[total_fil_amount]     - source_2[total_fil_amount]);
    delta_field_total_fill_amount(delta)  += (source_1[total_fill_amount]    - source_2[total_fill_amount]);
    delta_field_total_filll_amount(delta) += (source_1[total_filll_amount]   - source_2[total_filll_amount]);
    delta_field_total_shrink(delta)       += (source_1[total_shrink_amount]  - source_2[total_shrink_amount]);
}

static void tex_aux_compute_break_height(int break_type, halfword s)
{
    (void) break_type;
    while (s) {
        switch (node_type(s)) {
            case glue_node:
                lmt_balance_state.break_height[total_advance_amount] -= glue_amount(s);
                lmt_balance_state.break_height[total_stretch_amount + glue_stretch_order(s)] -= glue_stretch(s);
                lmt_balance_state.break_height[total_shrink_amount] -= glue_shrink(s);
                break;
            case penalty_node:
                break;
            case kern_node:
                if (node_subtype(s) == explicit_kern_subtype) {
                    lmt_balance_state.break_height[total_advance_amount] -= kern_amount(s);
                    break;
                } else {
                    return;
                }
            default:
                return;
        };
        s = node_next(s);
    }
}

/*tex 
    we can share these with line breaks and rename the contexts.   
*/

static void tex_aux_balance_callback_initialize(int callback_id, halfword checks, int subpasses)
{
    lmt_run_callback(lmt_lua_state.lua_instance, callback_id, "ddd->",
        initialize_line_break_context,
        checks,
        subpasses
    );
}

static void tex_aux_balance_callback_start(int callback_id, halfword checks, int pass, int subpass, int classes, int decent)
{
    lmt_run_callback(lmt_lua_state.lua_instance, callback_id, "dddddd->",
        start_line_break_context,
        checks,
        pass,
        subpass,
        classes,
        decent
    );
}

static void tex_aux_balance_callback_stop(int callback_id, halfword checks)
{
    lmt_run_callback(lmt_lua_state.lua_instance, callback_id, "ddd->",
        stop_line_break_context,
        checks,
        lmt_balance_state.fewest_demerits
    );
}

static void tex_aux_balance_callback_collect(int callback_id, halfword checks)
{
    lmt_run_callback(lmt_lua_state.lua_instance, callback_id, "dd->",
        collect_line_break_context,
        checks
    );
}

static void tex_aux_balance_callback_page(int callback_id, halfword checks, int line, halfword passive)
{
    lmt_run_callback(lmt_lua_state.lua_instance, callback_id, "ddNdddddd->",
        line_line_break_context,
        checks,
        lmt_balance_state.just_box,
        lmt_packaging_state.last_badness,
        lmt_packaging_state.last_overshoot,
        lmt_packaging_state.total_shrink[normal_glue_order],
        lmt_packaging_state.total_stretch[normal_glue_order],
        line,
        passive_serial(passive)
    );
}

static void tex_aux_balance_callback_delete(int callback_id, halfword checks, halfword passive)
{
    lmt_run_callback(lmt_lua_state.lua_instance, callback_id, "dddd->",
        delete_line_break_context,
        checks,
        passive_serial(passive),
        passive_ref_count(passive)
    );
}

static void tex_aux_balance_callback_wrapup(int callback_id, halfword checks)
{
    lmt_run_callback(lmt_lua_state.lua_instance, callback_id, "dddd->",
        wrapup_line_break_context,
        checks,
        lmt_balance_state.fewest_demerits,
        lmt_balance_state.actual_looseness
    );
}

static halfword tex_aux_balance_callback_report(int callback_id, halfword checks, int pass, halfword subpass, halfword active, halfword passive)
{
    halfword demerits = active_total_demerits(active);
    lmt_run_callback(lmt_lua_state.lua_instance, callback_id, "ddddddddddddNddd->r",
        report_line_break_context,
        checks,
        pass,
        subpass,
        passive_serial(passive),
        passive_prev_break(passive) ? passive_serial(passive_prev_break(passive)) : 0,
        active_page_number(active) - 1,
        node_type(active),
        active_fitness(active) + 1,            /* we offset the class */
        passive_n_of_fitness_classes(passive), /* also in passive  */
        passive_badness(passive),
        demerits,
        passive_cur_break(passive),
        active_short(active),
        active_glue(active),
        active_page_height(active),
        &demerits  /* optionally changed */
    );
    return demerits;
}

static void tex_aux_balance_callback_list(int callback_id, halfword checks, halfword passive)
{
    lmt_run_callback(lmt_lua_state.lua_instance, callback_id, "dddd->",
        list_line_break_context,
        checks,
        passive_serial(passive),
        passive_ref_count(passive)
    );
}

/* */

static inline halfword tex_max_fitness(halfword fitnessclasses)
{
    return tex_get_specification_count(fitnessclasses);
}

static inline halfword tex_med_fitness(halfword fitnessclasses)
{
    return tex_get_specification_decent(fitnessclasses);
}

static inline halfword tex_get_demerits(const balance_properties *properties, halfword distance, halfword start, halfword stop)
{
    (void) start;
    (void) stop;
    if (distance && distance > 1) {
        return properties->adj_demerits;
    } else { 
        return 0;
    }
}

static inline halfword tex_normalized_loose_badness(halfword b, halfword fitnessclasses)
{
    halfword med = tex_get_specification_decent(fitnessclasses);
    for (halfword c = med - 1; c >= 1; c--) {
        if (b <= tex_get_specification_fitness_class(fitnessclasses, c)) {
            return c;
        }
    }
    return 0;
}

static inline halfword tex_normalized_tight_badness(halfword b, halfword fitnessclasses)
{
    halfword max = tex_get_specification_count(fitnessclasses);
    halfword med = tex_get_specification_decent(fitnessclasses);
    for (halfword c = med + 1; c <= max; c++) {
        if (b <= tex_get_specification_fitness_class(fitnessclasses, c)) {
            return c - 2;
        }
    }
    return max - 1;
}

static void tex_aux_set_quality(halfword active, halfword passive, scaled shrt, scaled glue, scaled height, halfword badness)
{
    halfword quality = 0;
    halfword deficiency = 0;
    active_short(active) = shrt;
    active_glue(active) = glue;
    active_page_height(active) = height;
    if (shrt < 0) {
        shrt = -shrt;
        if (shrt > glue) {
            quality = page_is_overfull;
            deficiency = shrt - glue;
        }
    } else if (shrt > 0) {
        if (shrt > glue) {
            quality = page_is_underfull;
            deficiency = shrt - glue;
        }
    }
    passive_quality(passive) = quality;
    passive_deficiency(passive) = deficiency;
    passive_demerits(passive) = active_total_demerits(active); /* ... */
    passive_badness(passive) = badness;
    active_quality(active) = quality;
    active_deficiency(active) = deficiency;
}

static void tex_check_skips_shortfall(const balance_properties *properties, halfword breakpoint, halfword first, halfword current, halfword page_topskip, halfword page_bottomskip, halfword *shortfall, halfword *stretch, halfword *shrink, halfword options)
{
    halfword left = active_break_node(breakpoint) ? passive_cur_break(active_break_node(breakpoint)) : first; /* nasty */
    scaled top = 0;
    scaled bottom = 0;
    *stretch = 0;
    *shrink = 0;
 // if (! tex_glue_is_zero(page_topskip)) {
    if (1) {
        /* todo: check breakable */
        halfword c = left;
        scaled h = 0;
        scaled e = 0;
        while (c) {
            switch (node_type(c)) {
                case hlist_node:
                case vlist_node:
                    h = box_height(c);
                    if ((box_options(c) & box_option_discardable) && (options & balance_step_option_top)) {
                        e = -box_total(c);
                    } else {
                        e = box_discardable(c); /* maybe also when no topskip */
                    }
                    c = null;
                    break;
                case rule_node:
                    h = rule_height(c);
                    if ((rule_options(c) & rule_option_discardable) && (options & balance_step_option_top)) {
                        e = -rule_total(c);
                    } else {
                        e = rule_discardable(c);
                    }
                    c = null;
                    break;
                default: 
                    c = node_next(c);
                    break;
            }
        }
        if (glue_amount(page_topskip) > h) {
            top = glue_amount(page_topskip) - h;
            *shortfall -= top;
            *stretch += glue_stretch(page_topskip);
            *shrink += glue_shrink(page_topskip);
        }
        *shortfall -= e;
    }
    if (1) { // ! tex_glue_is_zero(page_bottomskip)) {
        halfword c = node_prev(current);
        scaled d = 0;
        scaled e = 0;
        while (c) {
            switch (node_type(c)) {
                case hlist_node:
                case vlist_node:
                    d = box_depth(c);
                    if ((box_options(c) & box_option_discardable) && (options & balance_step_option_bottom)) {
                        e = -box_total(c);
                    }
                    c = null;
                    break;
                case rule_node:
                    d = rule_depth(c);
                    if ((rule_options(c) & rule_option_discardable) && (options & balance_step_option_bottom)) {
                        e = -rule_total(c);
                    }
                    c = null;
                    break;
                default: 
                    c = node_prev(c);
                    break;
            }
        }
        if (glue_amount(page_bottomskip) > d) {
            bottom = glue_amount(page_bottomskip) - d;
            *shortfall -= bottom;
            *stretch += glue_stretch(page_bottomskip);
            *shrink += glue_shrink(page_bottomskip);
        }
        *shortfall -= e;
    }
    if ((top || bottom) && properties->tracing_balancing > 2) {
        tex_begin_diagnostic();
        tex_print_format("[balance: correction, top %p, bottom %p]", top, bottom);
        tex_end_diagnostic();
    }
    if (lmt_balance_state.inserts_found) { 
        *shortfall -= tex_insert_distances(left, current ? node_next(current) : null, stretch, shrink);
        ++lmt_balance_state.total_inserts_checked;
    }
}

/*tex 

    We keep these three together. We can get rid of these first ones and then just use the target 
    height instead of second. After all we don't have the equivalent of hanging indentation. We 
    can even go for a default balance shape with one entry and vsize, top and bottom skip.  

*/

static void tex_aux_check_height(scaled *height)
{
    if (*height <= 0) {
        /*tex In a shape it's ok when it's not the last. */
        *height = 50*655360; /* maybe vsize_par */
        tex_normal_warning("balance", "invalid height, defaulting to 500pt");
    }
}

static void tex_aux_set_height(
    const balance_properties *properties
)
{
    if (properties->shape && specification_count(properties->shape) > 0) {
        if (specification_repeat(properties->shape)) {
            lmt_balance_state.last_special_page = max_halfword;
        } else {
            lmt_balance_state.last_special_page = specification_count(properties->shape) - 1;
        }
        lmt_balance_state.second_height = tex_get_balance_vsize(properties->shape, specification_count(properties->shape)) + tex_get_balance_extra(properties->shape, specification_count(properties->shape));
        lmt_balance_state.second_topskip = tex_get_balance_topskip(properties->shape, specification_count(properties->shape));
        lmt_balance_state.second_bottomskip = tex_get_balance_bottomskip(properties->shape, specification_count(properties->shape));
        lmt_balance_state.second_options = tex_get_balance_options(properties->shape, specification_count(properties->shape));
    } else {
        lmt_balance_state.last_special_page = 0;
        lmt_balance_state.second_height = properties->vsize;
        lmt_balance_state.second_topskip = properties->topskip;
        lmt_balance_state.second_bottomskip = properties->bottomskip;
        lmt_balance_state.second_options = 0;
    }
    /* This first is never used: */
    lmt_balance_state.first_height = properties->vsize;
    lmt_balance_state.first_topskip = properties->topskip;
    lmt_balance_state.first_bottomskip = properties->bottomskip;
    lmt_balance_state.first_options = 0;
    if(! properties->shape || specification_count(properties->shape) < 2) {
        tex_aux_check_height(&lmt_balance_state.first_height);
        tex_aux_check_height(&lmt_balance_state.second_height);
    }
}

static void tex_aux_update_height(
    const balance_properties *properties,
    int                       page, 
    scaled                   *height
)
{
    if (page > lmt_balance_state.easy_page) {
        *height = lmt_balance_state.second_height;
    } else if (page > lmt_balance_state.last_special_page) {
        *height = lmt_balance_state.second_height;
    } else if (properties->shape && specification_count(properties->shape) > 0) {
        *height = tex_get_balance_vsize(properties->shape, page) + tex_get_balance_extra(properties->shape, page);
        if (page < specification_count(properties->shape)) { 
            /*tex We permits zero height before the last specification. */
            return;
        }
    } else {
        *height = lmt_balance_state.first_height;
    }
    tex_aux_check_height(height);
}

static void tex_aux_update_height_and_skips(
    const balance_properties *properties,
    int                       page, 
    scaled                   *height, 
    scaled                   *topskip, 
    scaled                   *bottomskip,
    halfword                 *options,
    int                       final
)
{
    if (page > lmt_balance_state.easy_page) {
        *height = lmt_balance_state.second_height;
        *topskip = lmt_balance_state.second_topskip;
        *bottomskip = lmt_balance_state.second_bottomskip;
        *options = lmt_balance_state.second_options;
    } else if (page > lmt_balance_state.last_special_page) {
        *height = lmt_balance_state.second_height;
        *topskip = lmt_balance_state.second_topskip;
        *bottomskip = lmt_balance_state.second_bottomskip;
        *options = lmt_balance_state.second_options;
    } else if (properties->shape && specification_count(properties->shape) > 0) {
        *height = tex_get_balance_vsize(properties->shape, page) + (final ? 0 : tex_get_balance_extra(properties->shape, page));
        *topskip = tex_get_balance_topskip(properties->shape, page);
        *bottomskip = tex_get_balance_bottomskip(properties->shape, page);
        *options = tex_get_balance_options(properties->shape, page);
        if (page < specification_count(properties->shape)) { 
            /*tex We permits zero height before the last specification. */
            return;
        }
    } else {
        *height = lmt_balance_state.first_height;
        *topskip = lmt_balance_state.first_topskip;
        *bottomskip = lmt_balance_state.first_bottomskip;
        *options = lmt_balance_state.first_options;
    }
    tex_aux_check_height(height);
}

/* */ 

static scaled tex_aux_try_balance(
    const balance_properties *properties,
    halfword penalty,
    scaled   extra, 
    halfword break_type,
    halfword first_p,
    halfword cur_p,
    int      callback_id,
    halfword checks,
    int      pass,
    int      subpass,
    int      artificial
)
{
    halfword previous = active_head;
    halfword before_previous = null;
    scaled current_active_height[n_of_glue_amounts] = { 0 };
    halfword best_place      [max_n_of_fitness_values] = { 0 };
    halfword best_place_page [max_n_of_fitness_values] = { 0 };
    scaled   best_place_short[max_n_of_fitness_values] = { 0 };
    scaled   best_place_glue [max_n_of_fitness_values] = { 0 };
    halfword badness = 0;
    halfword prev_badness = 0;
    int demerits = 0;
    scaled glue = 0;
    scaled shortfall = 0;
    scaled stretch = 0;
    scaled shrink = 0;
    halfword old_page = 0;
    bool no_break_yet = true;
    int current_stays_active;
    halfword fit_class;
    int artificial_demerits;
    scaled page_height = 0;
    halfword page_topskip = 0;
    halfword page_bottomskip = 0;
    halfword page = 0;
    if (penalty >= infinite_penalty) {
        return shortfall;
    } else if (penalty <= -infinite_penalty) {
        penalty = eject_penalty; /* bad name here */
    }
    tex_aux_set_target_to_source(current_active_height, lmt_balance_state.active_height);
    while (1) {
        halfword current = node_next(previous);
        halfword options = 0;
        if (node_type(current) == delta_node) {
            tex_aux_add_to_target_from_delta(current_active_height, current);
            before_previous = previous;
            previous = current;
            continue;
        } else {
            /*tex We have an |unhyphenated_node|. */
        }
        lmt_balance_state.current_slot_number = page; /* we could just use this variable */
        page = active_page_number(current);
        if (page > old_page) {
            if ((lmt_balance_state.minimum_demerits < awful_bad) && ((old_page != lmt_balance_state.easy_page) || (current == active_head))) {
                tex_aux_update_height_and_skips(properties, page, &page_height, &page_topskip, &page_bottomskip, &options, 0);
                if (no_break_yet) {
                    no_break_yet = false;
                    if (lmt_balance_state.emergency_percentage) {
                        scaled stretch = tex_xn_over_d(page_height, lmt_balance_state.emergency_percentage, scaling_factor);
                        lmt_balance_state.background[total_stretch_amount] -= lmt_balance_state.emergency_amount;
                        lmt_balance_state.background[total_stretch_amount] += stretch;
                        lmt_balance_state.emergency_amount = stretch;
                    }
                    tex_aux_set_target_to_source(lmt_balance_state.break_height, lmt_balance_state.background);
                    tex_aux_compute_break_height(break_type, cur_p);
                }
                if (node_type(previous) == delta_node) {
                    tex_aux_add_delta_from_difference(previous, lmt_balance_state.break_height, current_active_height);
                } else if (previous == active_head) {
                    tex_aux_set_target_to_source(lmt_balance_state.active_height, lmt_balance_state.break_height);
                } else {
                    halfword q = tex_new_node(delta_node, default_fitness); /* class and classes zero */
                    node_next(q) = current;
                    tex_aux_set_delta_from_difference(q, lmt_balance_state.break_height, current_active_height);
                    node_next(previous) = q;
                    before_previous = previous;
                    previous = q;
                }
                if (properties->max_adj_demerits >= awful_bad - lmt_balance_state.minimum_demerits) {
                    lmt_balance_state.minimum_demerits = awful_bad - 1;
               } else {
                    lmt_balance_state.minimum_demerits += properties->max_adj_demerits;
                }
                for (halfword fit_class = default_fitness; fit_class <= tex_max_fitness(properties->fitness_classes); fit_class++) {
                    if (lmt_balance_state.minimal_demerits[fit_class] <= lmt_balance_state.minimum_demerits) {
                        halfword passive = tex_new_node(passive_node, (quarterword) fit_class);
                        halfword active = tex_new_node((quarterword) break_type, (quarterword) fit_class);
                        halfword prev_break = best_place[fit_class];
                        /*tex Initialize the passive node: */
                        active_n_of_fitness_classes(active) = tex_max_fitness(properties->fitness_classes);
                        passive_n_of_fitness_classes(passive) = tex_max_fitness(properties->fitness_classes);
                        passive_cur_break(passive) = cur_p;
                        passive_serial(passive) = ++lmt_balance_state.serial_number;
                        passive_ref_count(passive) = 1;
                        passive_prev_break(passive) = prev_break;
                        if (prev_break) {
                            passive_ref_count(prev_break) += 1;
                        }
                        /*tex Initialize the active node: */
                        active_break_node(active) = passive;
                        active_page_number(active) = best_place_page[fit_class] + 1;
                        active_total_demerits(active) = lmt_balance_state.minimal_demerits[fit_class];
                        /*tex Store additional data in the new active node. */
                        tex_aux_set_quality(active, passive, best_place_short[fit_class], best_place_glue[fit_class], page_height, prev_badness);
                        /*tex Append the passive node. */
                        node_next(passive) = lmt_balance_state.passive;
                        lmt_balance_state.passive = passive;
                        /*tex Append the active node. */
                        node_next(active) = current;
                        node_next(previous) = active;
                        previous = active;
                        /* */
                        if (callback_id) {
                            active_total_demerits(active) = tex_aux_balance_callback_report(callback_id, checks, pass, subpass, active, passive);
                        }
                        if (properties->tracing_balancing > 0) {
                            tex_begin_diagnostic();
                            tex_aux_print_break_node(active, passive, 0);
                            tex_end_diagnostic();
                        }
                    }
                    lmt_balance_state.minimal_demerits[fit_class] = awful_bad;
                }
                lmt_balance_state.minimum_demerits = awful_bad;
                if (current != active_head) {
                    halfword delta = tex_new_node(delta_node, default_fitness);
                    node_next(delta) = current;
                    tex_aux_set_delta_from_difference(delta, current_active_height, lmt_balance_state.break_height);
                    node_next(previous) = delta;
                    before_previous = previous;
                    previous = delta;
                }
            }
            if (page > lmt_balance_state.easy_page) {
                old_page = max_halfword - 1;
            } else {
                old_page = page;
            }
            /*tex Actually, page_height already has been calculated: */
            tex_aux_update_height_and_skips(properties, page, &page_height, &page_topskip, &page_bottomskip, &options, 0);
            if (current == active_head) {
                shortfall = page_height - current_active_height[total_advance_amount];
                return shortfall;
            }
        }
        artificial_demerits = 0;
        shortfall = page_height - current_active_height[total_advance_amount];
        if (properties->tracing_balancing > 2) {
            tex_begin_diagnostic();
            tex_print_format("[balance: check, page %i, height %p, total %p, extra %p, shortfall %p]", 
                page, 
                page_height,
                lmt_balance_state.active_height[total_advance_amount],
                extra, 
                shortfall
            );
            tex_end_diagnostic();
        }
        shortfall -= extra; 
        tex_check_skips_shortfall(properties, current, first_p, cur_p, page_topskip, page_bottomskip, &shortfall, &stretch, &shrink, options);
        if (shortfall > 0) {
            if (current_active_height[total_fi_amount]   || current_active_height[total_fil_amount] ||
                current_active_height[total_fill_amount] || current_active_height[total_filll_amount]) {
                badness = 0;
                /*tex Infinite stretch. */
                fit_class = tex_get_specification_decent(properties->fitness_classes) - 1;
            } else if (shortfall > large_height_excess && (current_active_height[total_stretch_amount] + stretch) < small_stretchability) {
                badness = infinite_bad;
                fit_class = default_fitness;
            } else {
                badness = tex_badness(shortfall, current_active_height[total_stretch_amount] + stretch);
                fit_class = tex_normalized_loose_badness(badness, properties->fitness_classes);
            }
        } else {
            if (-shortfall > current_active_height[total_shrink_amount]) {
                badness = infinite_bad + 1;
            } else {
                badness = tex_badness(-shortfall, current_active_height[total_shrink_amount] + shrink);
        }
            fit_class = tex_normalized_tight_badness(badness, properties->fitness_classes);
        }
        if (! cur_p) {
            shortfall = 0;
            glue = 0;
        } else if (shortfall > 0) {
            glue = current_active_height[total_stretch_amount] + stretch;
        } else if (shortfall < 0) {
            glue = current_active_height[total_shrink_amount] + shrink;
        } else {
            glue = 0;
        }
        if ((badness > infinite_bad) || (penalty == eject_penalty)) {
            if (artificial && (lmt_balance_state.minimum_demerits == awful_bad) && (node_next(current) == active_head) && (previous == active_head)) {
                /*tex Set demerits zero, this break is forced. */
                artificial_demerits = 1;
            } else if (badness > lmt_balance_state.threshold) {
                goto DEACTIVATE;
            }
            current_stays_active = 0;
        } else {
            previous = current;
            if (badness > lmt_balance_state.threshold) {
                continue;
            } else {
                current_stays_active = 1;
            }
        }
        if (artificial_demerits) {
            demerits = 0;
        } else {
            /*tex Compute the demerits, |d|, from |r| to |cur_p|. */
            int fit_current = (halfword) active_fitness(current);
            int distance = abs(fit_class - fit_current);
            demerits = badness + properties->penalty; 
            if (abs(demerits) >= infinite_bad) {
                demerits = extremely_deplorable;
            } else {
                demerits = demerits * demerits;
            }
            if (penalty) {
                if (penalty > 0) {
                    demerits += (penalty * penalty);
                } else if (penalty > eject_penalty) {
                    demerits -= (penalty * penalty);
                }
            }
            demerits += tex_get_demerits(properties, distance, fit_current, fit_class);
        }
        prev_badness = badness;
        if (properties->tracing_balancing > 0) {
            tex_aux_print_feasible_break(cur_p, current, badness, penalty, demerits, artificial_demerits, fit_class, lmt_balance_state.printed_node);
        }
        /*tex This is the minimum total demerits from the beginning to |cur_p| via |r|. */
        demerits += active_total_demerits(current);
        if (demerits <= lmt_balance_state.minimal_demerits[fit_class]) {
            lmt_balance_state.minimal_demerits[fit_class] = demerits;
            best_place[fit_class] = active_break_node(current);
            best_place_page[fit_class] = page;
            best_place_short[fit_class] = shortfall;
            best_place_glue[fit_class] = glue;
            if (demerits < lmt_balance_state.minimum_demerits) {
                lmt_balance_state.minimum_demerits = demerits;
            }
        }
        if (current_stays_active) {
            continue;
        }
      DEACTIVATE:
        {
            halfword passive = active_break_node(current);
            node_next(previous) = node_next(current);
            if (passive) {
                passive_ref_count(passive) -= 1;
                if (callback_id) {
                    /*tex Not that usefull, basically every passive is touched. */
                    switch (node_type(current)) {
                        case unhyphenated_node:
                            tex_aux_balance_callback_delete(callback_id, checks, passive);
                            break;
                    //  case hyphenated_node:
                    //      break;
                    //  case delta_node:
                    //      break;
                    }
                }
            }
            tex_flush_node(current);
        }
        if (previous == active_head) {
            current = node_next(active_head);
            if (node_type(current) == delta_node) {
                tex_aux_add_to_target_from_delta(lmt_balance_state.active_height, current);
                tex_aux_set_target_to_source(current_active_height, lmt_balance_state.active_height);
                node_next(active_head) = node_next(current);
                tex_flush_node(current);
            }
        } else if (node_type(previous) == delta_node) {
            current = node_next(previous);
            if (current == active_head) {
                tex_aux_sub_delta_from_target(current_active_height, previous);
                node_next(before_previous) = active_head;
                tex_flush_node(previous);
                previous = before_previous;
            } else if (node_type(current) == delta_node) {
                tex_aux_add_to_target_from_delta(current_active_height, current);
                tex_aux_add_to_delta_from_delta(previous, current);
                node_next(previous) = node_next(current);
                tex_flush_node(current);
            }
        } else { 
        }
    }
    return shortfall;
}

static inline int tex_aux_valid_glue_break(halfword p)
{
    halfword prv = node_prev(p);
 // return (prv && prv != temp_head && (precedes_break(prv) || precedes_kern(prv) || precedes_dir(prv)));
    return (prv && prv != temp_head && precedes_break(prv));
}

# define max_prev_graf (max_integer/2)

static inline int tex_aux_emergency(const balance_properties *properties)
{
    if (properties->emergency_stretch > 0 || properties->emergency_shrink > 0) {
        return 1;
    } else {
        return 0;
    }
}

static inline int tex_aux_emergency_skip(halfword s)
{
    return ! tex_glue_is_zero(s) && glue_stretch_order(s) == normal_glue_order && glue_shrink_order(s) == normal_glue_order;
}

static scaled tex_check_balance_quality(scaled shortfall, scaled *overfull, scaled *underfull, halfword *verdict, halfword *classified)
{
    halfword active = active_break_node(lmt_balance_state.best_bet);
    halfword passive = passive_prev_break(active);
    int result = 1;
    /* last page ... */
    switch (active_quality(active)) {
        case page_is_overfull:
            *overfull = active_deficiency(active);
            *underfull = 0;
            break;
        case page_is_underfull:
            *overfull = 0;
            *underfull = active_deficiency(active);
            break;
        default:
            *overfull = 0;
            *underfull = 0;
            break;
    }
    *verdict = active_total_demerits(active);
    *classified |= (1 << active_fitness(active));
    /* previous pages */
    if (passive) {
        while (passive) {
            switch (passive_quality(passive)) {
                case page_is_overfull:
                    if (passive_deficiency(passive) > *overfull) {
                        *overfull = passive_deficiency(passive);
                    }
                    break;
                case page_is_underfull:
                    if (passive_deficiency(passive) > *underfull) {
                        *underfull = passive_deficiency(passive);
                    }
                    break;
                default:
                    /* not in tex */
                    break;
            }
            // *classified |= classification[node_subtype(q)];
            *classified |= (1 << passive_fitness(passive));
            if (passive_demerits(passive) > *verdict) {
                *verdict = passive_demerits(passive);
            }
            passive = passive_prev_break(passive);
        }
    } else {
        if (passive_demerits(active) > *verdict) {
            *verdict = passive_demerits(active);
            result = 2;
        }
        if (-shortfall > *overfull) {
            *overfull = -shortfall;
            result = 2;
        }
    }
    if (*verdict > infinite_bad) {
        *verdict = infinite_bad;
    }
    return result;
}

static inline void tex_aux_set_initial_active(const balance_properties *properties)
{
    halfword initial = tex_new_node(unhyphenated_node, (quarterword) tex_get_specification_decent(properties->fitness_classes) - 1);
    node_next(initial) = active_head;
    active_break_node(initial) = null;
    active_page_number(initial) = 1;
    active_total_demerits(initial) = 0; // default
    active_short(initial) = 0;          // default
    active_glue(initial) = 0;           // default
    active_page_height(initial) = 0;    // default
    node_next(active_head) = initial;
}

static inline void tex_aux_set_looseness(const balance_properties *properties)
{
    lmt_balance_state.actual_looseness = 0;
    if (properties->looseness == 0) {
        lmt_balance_state.easy_page = lmt_balance_state.last_special_page;
    } else {
        lmt_balance_state.easy_page = max_halfword;
    }
}

static inline void tex_aux_set_adjacent_demerits(balance_properties *properties)
{
    properties->max_adj_demerits = properties->adj_demerits;
}

static int tex_aux_set_sub_pass_parameters(
    balance_properties *properties,
    halfword            passes,
    int                 subpass,
    halfword            first,
    int                 details,
    halfword            features,
    halfword            overfull,
    halfword            underfull,
    halfword            verdict,
    halfword            classified,
    halfword            threshold,
    halfword            demerits,
    halfword            classes
) {
    int success = 0;
    uint64_t okay = tex_get_balance_passes_okay(passes, subpass);
    /* */
    (void) first;
    (void) overfull;
    (void) underfull;
    (void) verdict;
    (void) classified;
    (void) threshold;
    (void) demerits;
    (void) classes;
    /* */
    if (okay & passes_tolerance_okay) {
        properties->tolerance = tex_get_balance_passes_tolerance(passes, subpass);
    }
    lmt_balance_state.threshold = properties->tolerance;
    if (okay & passes_basics_okay) {
        if (okay & passes_emergencyfactor_okay) {
            lmt_balance_state.emergency_factor = tex_get_balance_passes_emergencyfactor(passes, subpass);
        }
        if (okay & passes_emergencypercentage_okay) {
            lmt_balance_state.emergency_percentage = tex_get_balance_passes_emergencypercentage(passes, subpass);
        }
    }
    /* */
    if (okay & passes_adjdemerits_okay) {
        properties->adj_demerits = tex_get_balance_passes_adjdemerits(passes, subpass);
    }
    /* */
    if (okay & passes_emergencystretch_okay) {
        halfword v = tex_get_balance_passes_emergencystretch(passes, subpass);
        if (v) {
            properties->emergency_stretch = v;
            properties->original_stretch = v; /* ! */
        } else {
            properties->emergency_stretch = properties->original_stretch;
        }
    } else {
        properties->emergency_stretch = properties->original_stretch;
    }
    if (lmt_balance_state.emergency_factor) {
        properties->emergency_stretch = tex_xn_over_d(properties->original_stretch, lmt_balance_state.emergency_factor, scaling_factor);
    } else {
        properties->emergency_stretch = 0;
    }
    lmt_balance_state.background[total_stretch_amount] -= lmt_balance_state.extra_background_stretch;
    lmt_balance_state.extra_background_stretch = properties->emergency_stretch;
    lmt_balance_state.background[total_stretch_amount] += properties->emergency_stretch;
    /* */
 // if (okay & passes_emergencyshrink_okay) {
 //     halfword v = tex_get_balance_passes_emergencyshrink(passes, subpass);
 //     if (v) {
 //         properties->emergency_shrink = v;
 //         properties->original_shrink = v; /* ! */
 //     } else {
 //         properties->emergency_shrink = properties->original_shrink;
 //     }
 // } else {
 //     properties->emergency_shrink = properties->original_shrink;
 // }
 // if (lmt_balance_state.emergency_factor) {
 //     properties->emergency_shrink = tex_xn_over_d(properties->original_shrink, lmt_balance_state.emergency_factor, scaling_factor);
 // } else {
 //     properties->emergency_shrink = 0;
 // }
    if (okay & passes_additional_okay) {
        if (okay & passes_balancepenalty_okay) {
            properties->penalty = tex_get_balance_passes_pagepenalty(passes,subpass);
        }
        if (okay & passes_adjdemerits_okay) {
            properties->adj_demerits = tex_get_passes_adjdemerits(passes, subpass);
            tex_aux_set_adjacent_demerits(properties);
        }
        if (okay & passes_fitnessclasses_okay) { 
            if (tex_get_balance_passes_fitnessclasses(passes, subpass)) {
                properties->fitness_classes = tex_get_passes_fitnessclasses(passes, subpass);
            }
        }
        if (okay & passes_balancechecks_okay) {
            properties->checks = tex_get_balance_passes_pagebreakchecks(passes, subpass);
        }
    }
    lmt_balance_state.background[total_shrink_amount] -= lmt_balance_state.extra_background_shrink;
    lmt_balance_state.extra_background_shrink = properties->emergency_shrink;
    lmt_balance_state.background[total_shrink_amount] += properties->emergency_shrink;
    /* */
    if (okay & passes_looseness_okay) {
        properties->looseness = tex_get_balance_passes_looseness(passes, subpass);
        tex_aux_set_looseness(properties);
    }
    if (details) {

        # define is_okay(a) ((okay & a) == a ? ">" : " ")

        tex_begin_diagnostic();
        tex_print_format("[balance: values used in subpass %i]\n", subpass);
        tex_print_str("  --------------------------------\n");
        tex_print_format("  use criteria          %s\n", subpass >= passes_first_final(passes) ? "true" : "false");
        if (features & passes_test_set) {
            tex_print_str("  --------------------------------\n");
            if (features & passes_if_emergency_stretch) { tex_print_str("  if emergency stretch true\n"); }
            if (features & passes_if_looseness)         { tex_print_str("  if looseness         true\n"); }
        }
        tex_print_str("  --------------------------------\n");
        tex_print_format("%s threshold            %p\n", is_okay(passes_threshold_okay), tex_get_balance_passes_threshold(passes, subpass));
     // tex_print_format("%s demerits             %i\n", is_okay(passes_demerits_okay), tex_get_balance_passes_demerits(passes, subpass));
        tex_print_str("  --------------------------------\n");
        tex_print_format("%s tolerance            %i\n", is_okay(passes_tolerance_okay), properties->tolerance);
        tex_print_format("%s looseness            %i\n", is_okay(passes_looseness_okay), properties->looseness);
        tex_print_str("  --------------------------------\n");
        tex_print_format("%s adjdemerits          %i\n", is_okay(passes_adjdemerits_okay), properties->adj_demerits);
        tex_print_str("  --------------------------------\n");
        tex_print_format("%s originalstretch      %p\n", is_okay(passes_emergencystretch_okay), properties->original_stretch);
        tex_print_format("%s emergencystretch     %p\n", is_okay(passes_emergencystretch_okay), properties->emergency_stretch);
     // tex_print_format("%s originalshrink       %p\n", is_okay(passes_emergencyshrink_okay), properties->original_shrink);
     // tex_print_format("%s emergencyshrink      %p\n", is_okay(passes_emergencyshrink_okay), properties->emergency_shrink);
        tex_print_format("%s emergencyfactor      %i\n", is_okay(passes_emergencyfactor_okay), tex_get_balance_passes_emergencyfactor(passes, subpass));
        tex_print_format("%s emergencypercentage  %i\n", is_okay(passes_emergencypercentage_okay), lmt_balance_state.emergency_percentage);
        tex_print_str("  --------------------------------\n");
        tex_end_diagnostic();
    }
    return success;
}

static void tex_aux_skip_message(halfword passes, int subpass, int nofsubpasses, const char *str)
{
    tex_begin_diagnostic();
    tex_print_format("[balance: id %i, subpass %i of %i, skip %s]\n",
        passes_identifier(passes), subpass, nofsubpasses, str
    );
    tex_end_diagnostic();
}

static inline int tex_aux_next_subpass(const balance_properties *properties, halfword passes, int subpass, int nofsubpasses, int tracing)
{
    while (++subpass <= nofsubpasses) {
        halfword features = tex_get_balance_passes_features(passes, subpass);
        if (features & passes_test_set) {
            if (features & passes_if_emergency_stretch) {
                if (! ( (properties->original_stretch || tex_get_balance_passes_emergencystretch(passes, subpass)) && tex_get_balance_passes_emergencyfactor(passes, subpass) ) ) {
                    if (tracing) {
                        tex_aux_skip_message(passes, subpass, nofsubpasses, "emergency stretch");
                    }
                    continue;
                }
            }
         // if (features & passes_if_emergency_shrink) {
         //     if (! ( (properties->original_shrink || tex_get_balance_passes_emergencyshrink(passes, subpass)) && tex_get_balance_passes_emergencyfactor(passes, subpass) ) ) {
         //         if (tracing) {
         //             tex_aux_skip_message(passes, subpass, nofsubpasses, "emergency shrink");
         //         }
         //         continue;
         //     }
         // }
            if (features & passes_if_looseness) {
                if (! properties->looseness) {
                    if (tracing) {
                        tex_aux_skip_message(passes, subpass, nofsubpasses, "no looseness");
                    }
                    continue;
                }
            }
        }
        return subpass;
    }
    return nofsubpasses + 1;
}

static inline int tex_aux_check_sub_pass(balance_properties *properties, scaled shortfall, halfword passes, int subpass, int nofsubpasses, halfword first)
{
    scaled overfull = 0;
    scaled underfull = 0;
    halfword verdict = 0;
    halfword classified = 0;
    int tracing = properties->tracing_balancing > 0 || properties->tracing_passes > 0;
    int result = tex_check_balance_quality(shortfall, &overfull, &underfull, &verdict, &classified);
    if (result) {
        if (tracing && result > 1) {
            tex_begin_diagnostic();
            tex_print_format("[balance: id %i, subpass %i of %i, overfull %p, verdict %i, special case, entering subpasses]\n",
                passes_identifier(passes), subpass, nofsubpasses, overfull, verdict
            );
            tex_end_diagnostic();
        }
        while (subpass < nofsubpasses) {
            subpass = tex_aux_next_subpass(properties, passes, subpass, nofsubpasses, tracing);
            if (subpass > nofsubpasses) {
                return subpass;
            } else {
                halfword features = tex_get_balance_passes_features(passes, subpass);
                if (features & passes_quit_pass) {
                    return -1;
                } else if (features & passes_skip_pass) {
                    continue;
                } else {
                    scaled threshold = tex_get_balance_passes_threshold(passes, subpass);
                    halfword demerits = tex_get_balance_passes_demerits(passes, subpass); /* here we just use defaults */
                    halfword classes = tex_get_balance_passes_classes(passes, subpass);   /* here we just use defaults */  
                    int callback = features & passes_callback_set;
                    int success = 0;
                    int details = properties->tracing_passes > 1;
                    int retry = callback ? 1 : overfull > threshold || verdict > demerits || (classes && (classes & classified) != 0);
                    if (tracing) {
                        int id = passes_identifier(passes);
                        tex_begin_diagnostic();
                        if (callback) {
                            tex_print_format("[balance: id %i, subpass %i of %i, overfull %p, underfull %p, verdict %i, classified %x, %s]\n",
                                id, subpass, nofsubpasses, overfull, underfull, verdict, classified, "callback"
                            );
                        } else {
                            const char *action = retry ? "retry" : "skipped";
                            if (id < 0) {
                                id = -id; /* nicer for our purpose */
                            }
                            if (threshold == max_dimension) {
                                if (demerits == max_dimension) {
                                    tex_print_format("[balance: id %i, subpass %i of %i, overfull %p, underfull %p, verdict %i, classified %x, %s]\n",
                                        id, subpass, nofsubpasses, overfull, underfull, verdict, classified, action
                                    );
                                } else {
                                    tex_print_format("[balance: id %i, subpass %i of %i, overfull %p, underfull %p, verdict %i, demerits %i, classified %x, %s]\n",
                                        id, subpass, nofsubpasses, overfull, underfull, verdict, demerits, classified, action
                                    );
                                }
                            } else {
                                if (demerits == max_dimension) {
                                    tex_print_format("[balance: id %i, subpass %i of %i, overfull %p, underfull %p, verdict %i, threshold %p, classified %x, %s]\n",
                                        id, subpass, nofsubpasses, overfull, underfull, verdict, threshold, classified, action
                                    );
                                } else {
                                    tex_print_format("[balance: id %i, subpass %i of %i, overfull %p, underfull %p, verdict %i, threshold %p, demerits %i, classified %x, %s]\n",
                                        id, subpass, nofsubpasses, overfull, underfull, verdict, threshold, demerits, classified, action
                                    );
                                }
                            }
                        }
                    }
                    if (retry) {
                        success = tex_aux_set_sub_pass_parameters(
                            properties, passes, subpass, first,
                            details,
                            features, overfull, underfull, verdict, classified, threshold, demerits, classes
                        );
                    }
                    if (tracing) {
                        tex_end_diagnostic();
                    }
                    if (success) {
                        return subpass;
                    }
                }
            }
        }
    } else {
        /*tex We have a few hits in our test files. */
    }
    return 0;
}


static void tex_aux_trace_list(halfword current, int line, const char *action)
{
    tex_begin_diagnostic();
    tex_print_format("[balance: list, slot %i, line %i, height %p, depth %p, total %p, %s]", 
        lmt_balance_state.current_slot_number, 
        line,
        box_height(current), 
        box_depth(current), 
        lmt_balance_state.active_height[total_advance_amount],
        action
    );
    tex_end_diagnostic();
}

static void tex_aux_trace_rule(halfword current, int line, const char *action)
{
    tex_begin_diagnostic();
    tex_print_format("[balance: list, slot %i, line %i, height %p, depth %p, total %p, %s]", 
        lmt_balance_state.current_slot_number, 
        line,
        rule_height(current), 
        rule_depth(current), 
        lmt_balance_state.active_height[total_advance_amount],
        action
    );
    tex_end_diagnostic();
}

static void tex_aux_trace_glue(halfword current, const char *action)
{
    tex_begin_diagnostic();
    tex_print_format("[balance: glue, slot %i, amount %p, total %p, %s]", 
        lmt_balance_state.current_slot_number, 
        glue_amount(current),
        lmt_balance_state.active_height[total_advance_amount],
        action
    );
    tex_end_diagnostic();
}

static void tex_aux_trace_kern(halfword current, const char *action)
{
    tex_begin_diagnostic();
    tex_print_format("[balance: kern, slot %i, amount %p, total %p, %s]", 
        lmt_balance_state.current_slot_number, 
        kern_amount(current),
        lmt_balance_state.active_height[total_advance_amount],
        action
    );
    tex_end_diagnostic();
}

static void tex_aux_trace_penalty(halfword current, const char *action)
{
    tex_begin_diagnostic();
    tex_print_format("[balance: penalty, slot %i, amount %p, total %p, %s]", 
        lmt_balance_state.current_slot_number, 
        penalty_amount(current),
        lmt_balance_state.active_height[total_advance_amount],
        action
    );
    tex_end_diagnostic();
}

static inline halfword tex_aux_balance_list(const balance_properties *properties, halfword pass, halfword subpass, halfword current, halfword first, int artificial)
{
    halfword callback_id = lmt_balance_state.callback_id;
    halfword checks = properties->checks;
    int line = 0;
    int tracing = properties->tracing_balancing > 2; 
    while (current && (node_next(active_head) != active_head)) { /* we check the cycle */
        switch (node_type(current)) {
            case hlist_node:
            case vlist_node:
                /* what with the migration (see buildpage where we inject and restart) */
                lmt_balance_state.active_height[total_advance_amount] += box_total(current);
                if (tracing) {
                    tex_aux_trace_list(current, ++line, "contributing");
                }
                break;
            case rule_node:
                /* what with the migration (see buildpage where we inject and restart) */
                lmt_balance_state.active_height[total_advance_amount] += rule_total(current);
                if (tracing) {
                    tex_aux_trace_rule(current, ++line, "contributing");
                }
                break;
            case glue_node:
                /*tex Checks for temp_head! */
                if (tex_aux_valid_glue_break(current)) {
                    if (tracing) {
                        tex_aux_trace_glue(current, "trying");
                    }
                    tex_aux_try_balance(properties, 0, 0, unhyphenated_node, first, current, callback_id, checks, pass, subpass, artificial);
                }
                lmt_balance_state.active_height[total_advance_amount] += glue_amount(current);
                lmt_balance_state.active_height[total_stretch_amount + glue_stretch_order(current)] += glue_stretch(current);
                lmt_balance_state.active_height[total_shrink_amount] += tex_aux_checked_shrink(current);
                if (tracing) {
                    tex_aux_trace_glue(current, "contributing");
                }
                break;
            case kern_node:
                /*tex there are not many vertical kerns that can occur in vmode */
                if (node_subtype(current) == explicit_kern_subtype) { 
                    halfword nxt = node_next(current);
                    if (nxt && node_type(nxt) == glue_node) {
                        if (tracing) {
                            tex_aux_trace_kern(current, "trying");
                        }
                        tex_aux_try_balance(properties, 0, 0, unhyphenated_node, first, current, callback_id, checks, pass, subpass, artificial);
                    }
                }
                lmt_balance_state.active_height[total_advance_amount] += kern_amount(current);
                if (tracing) {
                    tex_aux_trace_kern(current, "contributing");
                }
                break;
            case penalty_node:
                if (tracing) {
                    tex_aux_trace_penalty(current, "trying");
                }
                tex_aux_try_balance(properties, penalty_amount(current), 0, unhyphenated_node, first, current, callback_id, checks, pass, subpass, artificial);
                break;
            case boundary_node:
                if (node_subtype(current) == balance_boundary) {
                    if (properties->shape && specification_count(properties->shape) > 0) { 
                        int callback = lmt_callback_defined(balance_boundary_callback);
                        if (callback) {
                            halfword penalty = 0;
                            halfword extra = 0;
                            halfword trybreak = 0;
                            lmt_run_callback(lmt_lua_state.lua_instance, callback, "dddd->drr", // r: optional 
                                boundary_data(current),
                                boundary_reserved(current),
                                balance_shape_identifier(properties->shape),
                                lmt_balance_state.current_slot_number,
                                &trybreak,
                                &penalty,
                                &extra
                            );
                            switch (trybreak) { 
                                case balance_callback_nothing:
                                    break;
                                case balance_callback_try_break:
                                    tex_aux_try_balance(properties, penalty, extra, unhyphenated_node, first, current, callback_id, checks, pass, subpass, artificial);
                                    break;
                                case balance_callback_skip_zeros:
                                    current = node_next(current);
                                    while (current) { 
                                        if (node_type(current) == boundary_node && node_subtype(current) == balance_boundary && boundary_data(current) == 0 && boundary_reserved(current) == 0) {
                                            break;
                                        } else {
                                            current = node_next(current);
                                        }
                                    } 
                                    break;
                                default:
                                    break;
                            }
                        }
                    }
                }
                break;
            case insert_node:
                if (holding_inserts_par <= 0) {
                    scaled height = tex_insert_height(current);
                    if (height > 0) {
                     // if (0) { 
                     //     tex_aux_try_balance(properties, insert_float_cost(current), 0, unhyphenated_node, first, current, callback_id, checks, pass, subpass, artificial);
                     // }
                        lmt_balance_state.active_height[total_advance_amount] += height;
                        ++lmt_balance_state.inserts_found;
                    }
                }
                break;
            case whatsit_node:
                /* keep */
                break;
            case mark_node:
                /* keep */
                break;
            default:
                break;
        }
        current = node_next(current);
    }
    return current;
}

static int tex_aux_quit_balance(const balance_properties *properties, int pass)
{
    /*tex Find an active node with fewest demerits. */
    if (properties->looseness == 0) {
        return 1;
    } else {
        halfword r = node_next(active_head);
        halfword actual_looseness = 0;
        halfword best_page = lmt_balance_state.best_page;
        int verdict = 0;
        int tracing = tracing_looseness_par;
        if (tracing) {
            tex_begin_diagnostic();
            tex_print_format("[looseness: pass %i, pages %i, looseness %i]\n", pass, best_page - 1, properties->looseness);
        }
        do {
            if (node_type(r) != delta_node) {
                halfword page_number = active_page_number(r);
                halfword page_difference = page_number - best_page;
                halfword total_demerits = active_total_demerits(r);
                if ((page_difference < actual_looseness && properties->looseness <= page_difference) || (page_difference > actual_looseness && properties->looseness >= page_difference)) {
                    lmt_balance_state.best_bet = r;
                    actual_looseness = page_difference;
                    lmt_balance_state.fewest_demerits = total_demerits;
                    if (tracing) {
                        tex_print_format("%l[looseness: pass %i, page %i, difference %i, demerits %i, %s optimal]", pass, page_number - 1, page_difference, total_demerits, "sub");
                    }
                } else if (page_difference == actual_looseness && total_demerits < lmt_balance_state.fewest_demerits) {
                    lmt_balance_state.best_bet = r;
                    lmt_balance_state.fewest_demerits = total_demerits;
                    if (tracing) {
                        tex_print_format("%l[looseness: pass %i, page %i, difference %i, demerits %i, %s optimal]", pass, page_number - 1, page_difference, total_demerits, "more");
                    }
                } else {
                    if (tracing) {
                        tex_print_format("%l[looseness: pass %i, page %i, difference %i, demerits %i, %s optimal]", pass, page_number - 1, page_difference, total_demerits, "not");
                    }
                }
            }
            r = node_next(r);
        } while (r != active_head);
        lmt_balance_state.actual_looseness = actual_looseness;
        lmt_balance_state.best_page = active_page_number(lmt_balance_state.best_bet);
        verdict = actual_looseness == properties->looseness;
        if (tracing) {
            tex_print_format("%l[looseness: pass %i, looseness %i, page %i, demerits %i, %s]\n", pass, actual_looseness, lmt_balance_state.best_page - 1, lmt_balance_state.fewest_demerits, verdict ? "success" : "failure");
            tex_end_diagnostic();
        }
        return verdict || pass >= balance_final_pass;
    }
}

static void tex_aux_find_best_bet(void)
{
    halfword r = node_next(active_head);
    lmt_balance_state.fewest_demerits = awful_bad;
    do {
        if ((node_type(r) != delta_node) && (active_total_demerits(r) < lmt_balance_state.fewest_demerits)) {
            lmt_balance_state.fewest_demerits = active_total_demerits(r);
            lmt_balance_state.best_bet = r;
        }
        r = node_next(r);
    } while (r != active_head);
    lmt_balance_state.best_page = active_page_number(lmt_balance_state.best_bet);
}

# define balance_fitness_classes lmt_balance_state.default_fitness_classes

void tex_balance_preset(balance_properties *properties)
{
    if (! balance_fitness_classes) {
        balance_fitness_classes = tex_default_fitness_classes();
    }
    properties->tracing_balancing = tracing_balancing_par;
    properties->tracing_fitness   = tracing_fitness_par;
    properties->tracing_passes    = tracing_passes_par;
    properties->tolerance         = balance_tolerance_par;
    properties->pretolerance      = -1; /* we skip when the same */
    properties->vsize             = balance_vsize_par;
    properties->topskip           = balance_top_skip_par;
    properties->bottomskip        = balance_bottom_skip_par;
    properties->emergency_stretch = balance_emergency_stretch_par;
    properties->emergency_shrink  = balance_emergency_shrink_par;
    properties->original_stretch  = 0;
    properties->original_shrink   = 0;
    properties->looseness         = balance_looseness_par;
    properties->adj_demerits      = balance_adj_demerits_par;
    properties->shape             = balance_shape_par; 
    properties->fitness_classes   = balance_fitness_classes;
    properties->passes            = balance_passes_par;   
    properties->penalty           = balance_penalty_par;
    properties->max_adj_demerits  = 0;
    properties->checks            = balance_checks_par;
    properties->packing           = packing_exactly;
    properties->trial             = 0;
}

void tex_balance_reset(balance_properties *properties)
{
    if (properties->shape           != balance_shape_par      ) { tex_flush_node(properties->shape          ); }
    if (properties->passes          != balance_passes_par     ) { tex_flush_node(properties->passes         ); }
    if (properties->topskip         != balance_top_skip_par   ) { tex_flush_node(properties->topskip        ); }
    if (properties->bottomskip      != balance_bottom_skip_par) { tex_flush_node(properties->bottomskip     ); }
    if (properties->fitness_classes != balance_fitness_classes) { tex_flush_node(properties->fitness_classes); }
}

/* Should we reset extra after setting the field? */

void tex_aux_check_extra(halfword head)
{
    halfword current = head;
    scaled extra = 0;
    while (current) {
        switch (node_type(current)) {
            case hlist_node:
            case vlist_node:
                if (extra) { 
                    box_discardable(current) = extra;
                }
                break;
            case rule_node:
                if (extra) { 
                    rule_discardable(current) = extra;
                }
                break;
            case glue_node:
                if (! glue_amount(current)) {
                    /* ignore */
                } if (tex_has_glue_option(current, glue_option_set_discardable)) {
                    /* stretch and shrink */
                    extra = glue_amount(current);
                } else if (tex_has_glue_option(current, glue_option_reset_discardable)) {
                    extra = 0;
                }
                break;
        }
        current = node_next(current);
    }
}

void tex_balance(balance_properties *properties, halfword head)
{
    halfword passes = properties->passes;
    int subpasses = passes ? tex_get_specification_count(passes) : 0;
    int subpass = -2;
    int pass = balance_no_pass;
    halfword first = node_next(temp_head);
    /*tex Some helpers use temp_head so we need to use that! */
    properties->original_stretch = properties->emergency_stretch;
    properties->original_shrink = properties->emergency_shrink;
    lmt_balance_state.just_box                 = 0;
    lmt_balance_state.no_shrink_error_yet      = 1;
    lmt_balance_state.threshold                = properties->pretolerance;
    lmt_balance_state.quality                  = 0;
    lmt_balance_state.callback_id              = properties->checks ? lmt_callback_defined(balance_callback) : 0;
    lmt_balance_state.extra_background_stretch = 0;
    lmt_balance_state.extra_background_shrink  = 0;
    lmt_balance_state.passive                  = null;
    lmt_balance_state.printed_node             = temp_head;
    lmt_balance_state.serial_number            = 0;
 /* lmt_balance_state.active_height            = { 0 }; */
 /* lmt_balance_state.background               = { 0 }; */
 /* lmt_balance_state.break_height             = { 0 }; */
 /* lmt_balance_state.fill_height              = { 0 }; */
 /* lmt_balance_state.minimal_demerits         = { 0 }; */
    lmt_balance_state.minimum_demerits         = awful_bad;
    lmt_balance_state.easy_page                = 0;
    lmt_balance_state.last_special_page        = 0;
    lmt_balance_state.target_height            = 0;
    lmt_balance_state.first_height             = 0;
    lmt_balance_state.second_height            = 0;
    lmt_balance_state.first_topskip            = null;
    lmt_balance_state.second_topskip           = null;
    lmt_balance_state.first_bottomskip         = null;
    lmt_balance_state.second_bottomskip        = null;
    lmt_balance_state.emergency_amount         = 0;
    lmt_balance_state.emergency_percentage     = 0;
    lmt_balance_state.emergency_factor         = scaling_factor;
    lmt_balance_state.emergency_height_amount  = 0;
    lmt_balance_state.best_bet                 = 0;
    lmt_balance_state.fewest_demerits          = 0;
    lmt_balance_state.best_page                = 0;
    lmt_balance_state.actual_looseness         = 0;
    lmt_balance_state.warned                   = 0;
    lmt_balance_state.inserts_found            = 0;
    lmt_balance_state.discards_found           = 0;
    lmt_balance_state.passes.n_of_break_calls += 1;
    lmt_balance_state.artificial_encountered   = 0;
    lmt_balance_state.current_slot_number      = 0;
    lmt_balance_state.last_special_page        = 0;
 /* lmt_balance_state.default_fitness_classes  = null  */ /* shared */ 
    for (int i = 0; i < n_of_glue_amounts; i++) {
        lmt_balance_state.active_height[i] = 0;
        lmt_balance_state.background[i] = 0;
        lmt_balance_state.break_height[i] = 0;
        lmt_balance_state.minimal_demerits[i] = 0;
    }
    for (int i = 0; i < max_n_of_fitness_values; i++) {
        lmt_balance_state.minimal_demerits[i] = awful_bad;
    }
    tex_insert_reset_distances();
    tex_aux_check_extra(head);
    tex_aux_pre_balance(properties, lmt_balance_state.callback_id, properties->checks, 0);
    tex_aux_set_adjacent_demerits(properties);
    tex_aux_set_height(properties);
    tex_aux_set_looseness(properties);
    if (properties->tracing_balancing > 1) {
        tex_begin_diagnostic();
        tex_print_str("[balance: original] ");
        tex_short_display(first);
        tex_end_diagnostic();
    }
    if (subpasses) {
        pass = balance_specification_pass;
        lmt_balance_state.threshold = properties->pretolerance; /* or tolerance */
        if (properties->tracing_balancing > 0 || properties->tracing_passes > 0) {
            if (specification_presets(passes)) {
                tex_begin_diagnostic();
                tex_print_str("[balance: specification presets]");
                tex_end_diagnostic();
            }
        }
        if (specification_presets(passes)) {
            subpass = 1;
        }
    } else if (properties->pretolerance >= 0) {
        pass = balance_first_pass;
        lmt_balance_state.threshold = properties->pretolerance;
    } else {
        pass = balance_second_pass;
        lmt_balance_state.threshold = properties->tolerance;
    }
    if (lmt_balance_state.callback_id) {
        tex_aux_balance_callback_initialize(lmt_balance_state.callback_id, properties->checks, subpasses);
    }
    while (1) {
        halfword current = first;
        int artificial = 0;
        switch (pass) {
            case balance_no_pass:
                goto DONE;
            case balance_first_pass:
                if (properties->tracing_balancing > 0 || properties->tracing_passes > 0) {
                    tex_begin_diagnostic();
                    tex_print_format("[balance: first pass, used tolerance %i]", lmt_balance_state.threshold);
                    // tex_end_diagnostic();
                }
                lmt_balance_state.passes.n_of_first_passes++;
                break;
            case balance_second_pass:
                if (tex_aux_emergency(properties)) {
                    lmt_balance_state.passes.n_of_second_passes++;
                    if (properties->tracing_balancing > 0 || properties->tracing_passes > 0) {
                        tex_begin_diagnostic();
                        tex_print_format("[balance: second pass, used tolerance %i]", lmt_balance_state.threshold);
                        // tex_end_diagnostic();
                    }
                    break;
                } else {
                    pass = balance_final_pass;
                    /* fall through */
                }
            case balance_final_pass:
                lmt_balance_state.passes.n_of_final_passes++;
                if (properties->tracing_balancing > 0 || properties->tracing_passes > 0) {
                    tex_begin_diagnostic();
                    tex_print_format("[balance: final pass, used tolerance %i, used emergency stretch %p]", lmt_balance_state.threshold, properties->emergency_stretch);
                    // tex_end_diagnostic();
                }
                lmt_balance_state.background[total_stretch_amount] += properties->emergency_stretch;
                break;
            case balance_specification_pass:
                if (specification_presets(passes)) {
                    if (subpass <= passes_first_final(passes)) {
                        tex_aux_set_sub_pass_parameters(
                            properties, passes, subpass,
                            first,
                            properties->tracing_passes > 1,
                            tex_get_balance_passes_features(passes,subpass),
                            0, 0, 0, 0, 0, 0, 0
                        );
                        lmt_balance_state.passes.n_of_specification_passes++;
                    }
                } else {
                    switch (subpass) {
                        case -2:
                            lmt_balance_state.threshold = properties->pretolerance;
                            subpass = -1;
                            break;
                        case -1:
                            lmt_balance_state.threshold = properties->tolerance;
                            subpass = 0;
                            break;
                        default:
                            break;
                    }
                }
                if (properties->tracing_balancing > 0 || properties->tracing_passes > 0) {
                    tex_begin_diagnostic();
                    tex_print_format("[balance: specification subpass %i]\n", subpass);
                }
                lmt_balance_state.passes.n_of_sub_passes++;
                break;
        }
        if (lmt_balance_state.threshold > infinite_bad) {
            lmt_balance_state.threshold = infinite_bad; /* we can move this check to where threshold is set */
        }
        if (lmt_balance_state.callback_id) {
            tex_aux_balance_callback_start(lmt_balance_state.callback_id, properties->checks, pass, subpass,
                tex_max_fitness(properties->fitness_classes), tex_med_fitness(properties->fitness_classes));
        }
        tex_aux_set_initial_active(properties);
        {
            halfword page = 1;
            scaled page_height;
            lmt_balance_state.current_slot_number = page; 
            tex_aux_update_height(properties, page, &page_height);
            lmt_balance_state.background[total_stretch_amount] -= lmt_balance_state.emergency_amount;
            if (lmt_balance_state.emergency_percentage) {
                scaled stretch = tex_xn_over_d(page_height, lmt_balance_state.emergency_percentage, scaling_factor);
                lmt_balance_state.background[total_stretch_amount] += stretch;
                lmt_balance_state.emergency_amount = stretch;
            } else {
                lmt_balance_state.emergency_amount = 0;
            }
            lmt_balance_state.background[total_advance_amount] -= lmt_balance_state.emergency_height_amount;
        }
        tex_aux_set_target_to_source(lmt_balance_state.active_height, lmt_balance_state.background);
        lmt_print_state.font_in_short_display = null_font;
        lmt_packaging_state.previous_char_ptr = null;
        switch (pass) {
            case balance_final_pass:
                artificial = 1;
                break;
            case balance_specification_pass:
                artificial = (subpass >= passes_first_final(passes)) || (subpass == subpasses);
                break;
            default:
                artificial = 0;
                break;
        }
        current = tex_aux_balance_list(properties, pass, subpass, current, first, artificial);
        if (! current) {
            scaled shortfall = tex_aux_try_balance(properties, eject_penalty, 0, hyphenated_node, first, current, lmt_balance_state.callback_id, properties->checks, pass, subpass, artificial);
            if (node_next(active_head) != active_head) {
                /*tex Find an active node with fewest demerits. */
                tex_aux_find_best_bet();
                if (pass == balance_specification_pass) {
                    /*tex This is where sub passes differ: we do a check. */
                    if (subpass < 0) {
                        goto HERE;
                    } else if (subpass < passes_first_final(passes)) {
                        goto DONE;
                    } else if (subpass < subpasses) {
                        int found = tex_aux_check_sub_pass(properties, shortfall, passes, subpass, subpasses, first);
                        if (found > 0) {
                            subpass = found;
                            goto HERE;
                        } else if (found < 0) {
                            goto DONE;
                        }
                    } else {
                        /* continue */
                    }
                }
                if (tex_aux_quit_balance(properties, pass)) {
                    goto DONE;
                }
            }
        }
        if (subpass <= passes_first_final(passes)) {
            ++subpass;
        }
      HERE:
        if (properties->tracing_balancing > 0 || properties->tracing_passes > 0) {
            tex_end_diagnostic(); // see above
        }
        tex_aux_clean_up_the_memory();
        switch (pass) {
            case balance_no_pass:
                /* just to be sure */
                goto DONE;
            case balance_first_pass:
                lmt_balance_state.threshold = properties->tolerance;
                pass = balance_second_pass;
                break;
            case balance_second_pass:
                pass = balance_final_pass;
                break;
            case balance_final_pass:
                pass = balance_no_pass;
                break;
            case balance_specification_pass:
                break;
        }
        if (lmt_balance_state.callback_id) {
            tex_aux_balance_callback_stop(lmt_balance_state.callback_id, properties->checks);
        }
    }
    goto INDEED;
  DONE:
    if (lmt_balance_state.callback_id) {
        tex_aux_balance_callback_stop(lmt_balance_state.callback_id, properties->checks);
    }
    if (properties->tracing_balancing > 0 || properties->tracing_passes > 0) {
        tex_end_diagnostic(); // see above
    }
  INDEED:
    if (properties->looseness && (! tracing_looseness_par) && (properties->looseness != lmt_balance_state.actual_looseness)) {
        tex_print_nlp();
        tex_print_format("%l[looseness: page %i, requested %i, actual %i]\n", lmt_balance_state.best_page - 1, properties->looseness, lmt_balance_state.actual_looseness);
    }
    lmt_balance_state.total_inserts_found += lmt_balance_state.inserts_found; 
    if (lmt_balance_state.inserts_found) { 
        tex_insert_reset_distances();
    }
    tex_aux_post_balance(properties, lmt_balance_state.callback_id, properties->checks, 0);
    tex_aux_clean_up_the_memory();
    if (lmt_balance_state.callback_id) {
        tex_aux_balance_callback_wrapup(lmt_balance_state.callback_id, properties->checks);
    }
}

# define passive_next_break passive_prev_break

static void tex_aux_pre_balance(const balance_properties *properties, int callback_id, halfword checks, int state)
{
    (void) properties;
    (void) callback_id;
    (void) checks;
    (void) state;
    /* todo */
}

/* todo: we don't need just_box at all */

static void tex_aux_post_balance(const balance_properties *properties, int callback_id, halfword checks, int state)
{
    halfword cur_p = null;
    (void) state;
    if (callback_id) {
        tex_aux_balance_callback_collect(callback_id, checks);
    }
    {
        halfword q = active_break_node(lmt_balance_state.best_bet);
        do {
            halfword r = q;
            q = passive_prev_break(q);
            passive_next_break(r) = cur_p;
            cur_p = r;
        } while (q);
    }
    if (callback_id) {
        halfword p = cur_p;
        while (p) {
            tex_aux_balance_callback_list(callback_id, checks, p);
            p = passive_next_break(p);
        }
    }
    if (properties->trial) {
        /*tex 
            We're only interested in the natural dimensions. So we create a fitting vertical empty 
            box with a height and depth matching the expected result. 
        */
        halfword page = 1;
        scaled target = 0;
        halfword topskip = null;
        halfword bottomskip = null;
        halfword first = node_next(temp_head); 
        do {
            halfword last = passive_cur_break(cur_p);
            scaled top = -1;
            scaled bottom = -1;
            halfword options = 0;
            int discardable = 0;
            scaled discard = 0;
            if (last) {
                switch (node_type(last)) {
                    case glue_node:
                        last = node_prev(last);
                        break;
                    case kern_node:
                        last = node_prev(last);
                        break;
                }
            } else {
                last = tex_tail_of_node_list(first);
            }
            tex_aux_update_height_and_skips(properties, page, &target, &topskip, &bottomskip, &options, 1);
            discardable = first && first == last && (
                (node_type(last) == rule_node  && (rule_options(last) & rule_option_discardable)) 
             || (node_type(last) == vlist_node && (box_options(last)  & box_option_discardable ))
            );  
//            if (first && ! tex_glue_is_zero(topskip)) { 
            if (first) { 
                halfword current = first;
                scaled height = 0; 
                scaled extra = 0;
                while (current) {
                    switch (node_type(current)) {
                        case hlist_node:
                        case vlist_node:
                            height = box_height(current);
                            if (box_discardable(current)) {
                                extra = box_discardable(current);
                                box_discardable(current) = 0;
                            } else if ((box_options(current) & box_option_discardable) && (options & balance_step_option_top)) {
                                discard = box_total(current);
                                extra = -discard;
                            }
                            goto ADDTOPSKIP1;
                        case rule_node:
                            height = rule_height(current); 
                            if (rule_discardable(current)) {
                                extra = rule_discardable(current);
                                rule_discardable(current) = 0;
                            } else if ((rule_options(current) & rule_option_discardable) && (options & balance_step_option_top)) {
                                discard = rule_total(current);
                                extra = -discard;
                            }
                            goto ADDTOPSKIP1;
                        default:
                            break;
                    }
                    current = node_next(current);
                }
                ADDTOPSKIP1:
                if (glue_amount(topskip) > height) {
                    top = glue_amount(topskip) - height;
                } else { 
                    top = 0;
                }
                top += extra;
            }
//           if (last && ! tex_glue_is_zero(bottomskip)) { 
            if (last) { 
                scaled depth = 0; 
                switch (node_type(last)) {
                    case hlist_node:
                    case vlist_node:
                        depth = box_depth(last); 
                        if ((box_options(last) & box_option_discardable) && (options & balance_step_option_top)) {
                            discard += box_total(last);
                        }
                        break;
                    case rule_node:
                        depth = rule_depth(last); 
                        if ((rule_options(last) & rule_option_discardable) && (options & balance_step_option_bottom)) {
                            discard += rule_total(last);
                        }
                        break;
                }
                if (glue_amount(bottomskip) > depth) {
                    bottom = glue_amount(bottomskip) - depth;
                } else { 
                    bottom = 0;
                }
            }
            { 
                scaledwhd whd = tex_natural_vsizes(first, node_next(last), 0.0, 0, 0, 1);
                whd.ht -= discard;
                lmt_balance_state.just_box = tex_vpack(null, whd.ht, packing_exactly, 0, 0, holding_none_option, NULL);
                tex_attach_attribute_list_copy(lmt_balance_state.just_box, first);
                if (top > 0) {
                    whd.ht += top; 
                }
                if (bottom > 0) {
                    whd.ht += bottom; 
                    whd.dp = 0; 
                }
                box_width(lmt_balance_state.just_box) = whd.wd;
                box_height(lmt_balance_state.just_box) = whd.ht;
                box_depth(lmt_balance_state.just_box) = whd.dp;
                node_subtype(lmt_balance_state.just_box) = balance_slot_list;
            }
            if (discardable) { 
                box_height(lmt_balance_state.just_box) = 0;
                box_depth(lmt_balance_state.just_box) = 0;
            }            
            if (callback_id) {
                tex_aux_balance_callback_page(callback_id, checks, page, cur_p);
            }
            tex_tail_append(lmt_balance_state.just_box);
            ++page;
            cur_p = passive_next_break(cur_p);
            if (cur_p) {
                first = node_next(last);
                while (first) {
                    if (first == passive_cur_break(cur_p)) {
                        break;
                    } else if (non_discardable(first)) {
                        break;
                    } else if (node_type(first) == kern_node && ! (node_subtype(first) == explicit_kern_subtype)) {
                        break;
                    } else { 
                        first = node_next(first);
                    }
                }
                if (! first) {
                    break;
                }
            }
        } while (cur_p);
    } else { 
        halfword page = 1;
        scaled target = 0;
        halfword topskip = null;
        halfword bottomskip = null;
        do {
            halfword first = node_next(temp_head); 
            halfword last  = passive_cur_break(cur_p);
            halfword options = 0;
            int discardable = 0;
            scaled discard = 0;
            if (last) {
                switch (node_type(last)) {
                    case glue_node:
                        last = node_prev(last);
                        break;
                    case kern_node:
                        kern_amount(last) = 0;
                        break;
                }
            } else {
                /* kind of weird */
                last = tex_tail_of_node_list(temp_head);
            }
            node_next(temp_head) = node_next(last);
            node_next(last) = null;
            tex_aux_update_height_and_skips(properties, page, &target, &topskip, &bottomskip, &options, 1);
            discardable = first && first == last && (
                (node_type(last) == rule_node  && (rule_options(last) & rule_option_discardable)) 
             || (node_type(last) == vlist_node && (box_options(last)  & box_option_discardable ))
            );
//            if (first && ! tex_glue_is_zero(topskip)) { 
            if (first) { 
                halfword current = first;
                scaled height = 0; 
                scaled extra = 0;
                halfword gluenode = tex_new_glue_node(topskip, top_skip_glue);
                tex_attach_attribute_list_copy(gluenode, current);
                while (current) {
                    switch (node_type(current)) {
                        case hlist_node:
                        case vlist_node:
                            height = box_height(current); 
                            if (box_discardable(current)) {
                                extra = box_discardable(current);
                                box_discardable(current) = 0;
                            } else if ((box_options(current) & box_option_discardable) && (options & balance_step_option_top)) {
                                discard = -box_total(current);
                            }
                            goto ADDTOPSKIP2;
                        case rule_node:
                            height = rule_height(current); 
                            if (rule_discardable(current)) {
                                extra = rule_discardable(current);
                                rule_discardable(current) = 0;
                            } else if ((rule_options(current) & rule_option_discardable) && (options & balance_step_option_top)) {
                                discard = -rule_total(current);
                            }
                            goto ADDTOPSKIP2;
                        default:
                            break;
                    }
                    current = node_next(current);
                }
              ADDTOPSKIP2:
                if (glue_amount(gluenode) > height) {
                    glue_amount(gluenode) -= height;
                } else {
                    glue_amount(gluenode) = 0;
                }
                tex_couple_nodes(gluenode, first);
                first = gluenode;
                glue_amount(gluenode) += extra;
                glue_amount(gluenode) += discard;
        }
//            if (last && ! tex_glue_is_zero(bottomskip)) { 
            if (last) { 
                scaled depth = 0; 
                halfword gluenode = tex_new_glue_node(bottomskip, bottom_skip_glue); 
                tex_attach_attribute_list_copy(gluenode, last);
                switch (node_type(last)) {
                    case hlist_node:
                    case vlist_node:
                        depth = box_depth(last); 
                        if ((box_options(last) & box_option_discardable) && (options & balance_step_option_bottom)) {
                            discard -= box_total(last);
                        }
                        break;
                    case rule_node:
                        depth = rule_depth(last); 
                        if ((rule_options(last) & rule_option_discardable) && (options & balance_step_option_bottom)) {
                            discard -= rule_total(last);
                        }
                        break;
                }
                if (glue_amount(gluenode) > depth) {
                    glue_amount(gluenode) -= depth;
                } else {
                    glue_amount(gluenode) = 0;
                }
                glue_amount(gluenode) += discard;
                tex_couple_nodes(last, gluenode);
                last = gluenode;
            }
            if (properties->packing == packing_additional) {
                lmt_balance_state.just_box = tex_vpack(first, 0, packing_additional, 0, 0, holding_none_option, NULL);
            } else {
                target -= discard;
                lmt_balance_state.just_box = tex_vpack(first, target, packing_exactly, 0, 0, holding_none_option, NULL);
            }
            if (discardable) { 
                box_height(lmt_balance_state.just_box) = 0;
                box_depth(lmt_balance_state.just_box) = 0;
            }
            if (discard || discardable) {
                box_balance_state(lmt_balance_state.just_box) |= balance_state_discards;
                lmt_balance_state.discards_found = 1;
            }
            node_subtype(lmt_balance_state.just_box) = balance_slot_list;
            if (callback_id) {
                tex_aux_balance_callback_page(callback_id, checks, page, cur_p);
            }
            tex_tail_append(lmt_balance_state.just_box);
            tex_attach_attribute_list_copy(lmt_balance_state.just_box, first);
            ++page;
            cur_p = passive_next_break(cur_p);
            if (cur_p) {
                /*tex 
                    This is kind of ugly code. In order to avoid loops due to an empty list we 
                    replaced |(1)| by |(r)| below. 
                */
                halfword r = temp_head;
                halfword q = null;
                while (r) {
                    q = node_next(r);
                    if (q == passive_cur_break(cur_p)) {
                        break;
                    } else if (non_discardable(q)) {
                        break;
                    } else if (node_type(q) == kern_node && node_subtype(q) != explicit_kern_subtype) {
                        break;
                    } else { 
                        r = q;
                    }
                }
                if (! r) {
                    break;
                } else if (r != temp_head) {
                    node_next(r) = null;
                    tex_flush_node_list(node_next(temp_head));
                    tex_try_couple_nodes(temp_head, q);
                }
            }
        } while (cur_p);
        if (page != lmt_balance_state.best_page) {
         // tex_confusion("balancing 1");
        } else if (node_next(temp_head)) {
         // tex_confusion("balancing 2");
        }
    }
}

// extern int tex_only_boundaries(halfword n) 
// {
//      int state = 0;
//      while (n) {
//          switch (node_type(n)) { 
//             case glue_node:
//                 if (state) { 
//                     break;
//                 } else { 
//                     return 0;
//                 } 
//             case boundary_node:
//                 if (node_subtype(balance_boundary)) {
//                     state = 1; 
//                     break;
//                 } else { 
//                     return 0;
//                 }
//             default: 
//                 return 0;
//          }
//      }
//      return 1;
// }

extern halfword tex_vbalance (
    halfword n,
    halfword mode,
    halfword trial
) 
{
    halfword box = box_register(n);
    if (! box) {
        return null;
    } else if (node_type(box) != vlist_node) {
        tex_handle_error(
            normal_error_type,
            "\\vbalance needs a \\vbox",
            "The box you are trying to split is an \\hbox. I can't split such a box, so I''ll\n"
            "leave it alone."
        );
        return null;
    } else {
        halfword head = box_list(box);
        halfword result = null;
        if (head) {
            balance_properties properties;
            tex_push_nest();
            node_next(temp_head) = head;
            tex_balance_preset(&properties);
            properties.packing = mode; 
            properties.trial = trial;
            tex_balance(&properties, head);
            tex_balance_reset(&properties);
            result = node_next(cur_list.head);
            node_next(cur_list.head) = null;
            node_next(temp_head) = null;
            tex_pop_nest();
            /* maybe filtered because that also does the uleaders */
            result = tex_vpack(result, 0, packing_exactly, max_dimension, 0, holding_none_option, NULL);
            if (lmt_balance_state.inserts_found) {
                box_balance_state(result) |= balance_state_inserts;
            }
            if (lmt_balance_state.discards_found) {
                box_balance_state(result) |= balance_state_discards;
            }
            tex_attach_attribute_list_copy(result, box);
            node_subtype(result) = balance_list;
        }
        if (! trial) {
            box_list(box) = null;
            tex_flush_node(box);
            box_register(n) = null;
        }
        return result;
    }
}

static halfword tex_aux_locate_balance_target(halfword n, halfword subtype, halfword decend)
{
    halfword box = box_register(n);
    if (! box || ! box_list(box)) {
        return -1; 
    } else if (decend) {
        while (box) {
            switch (node_type(box)) { 
                case hlist_node: 
                    box = box_list(box);
                    break;
                case vlist_node: 
                    switch (node_subtype(box)) {
                        case balance_slot_list:
                           if (subtype == balance_slot_list || subtype == unknown_list) { 
                               return box;
                           } else {
                               return null;
                           }
                        case balance_list:
                           if (subtype == balance_list) { 
                               return box;
                           } else {
                                box = box_list(box);
                                break;
                           }
                        default:
                            if (subtype == unknown_list) { 
                                return box;
                            } else { 
                                box = box_list(box);
                                break;
                            }
                    }
                    break;
                default: 
                    return null;
            }
        } 
        return null;
    } else if (box && node_type(box) == vlist_node && node_subtype(box) == subtype) { 
        return box; 
    } else {
        return null;
    }
}

halfword tex_vbalanced(
    halfword n
) 
{
    halfword box = tex_aux_locate_balance_target(n, balance_list, 0); // no descend 
    if (box < 0) {
        return null;
    } else if (box) {
        /*tex 
            We silently ignore anything other than a vbox which makes this routine less sensitive
            for being a messed up balanced container. 
        */
        halfword head = box_list(box);
        while (head && node_type(head) != vlist_node) {
            halfword next = node_next(head);
            if (next) { 
                node_prev(next) = null;
            }
            tex_flush_node(head);
            head = next; 
        }
        if (head) {
            halfword rest = node_next(head);
         // halfword list = box_list(head);
            node_prev(head) = null;
            node_next(head) = null;
            box_list(box) = rest;
            if (rest) { 
                node_prev(rest) = null;
            } else { 
                tex_flush_node(box);
                box_register(n) = null;
            }
         // for (halfword i = 0; i <= lmt_mark_state.mark_data.ptr; i++) {
         //     tex_delete_mark(i, split_first_mark_code);
         //     tex_delete_mark(i, split_bot_mark_code);
         // } 
         // while (list) {
         //     if (node_type(list) == mark_node) {
         //         tex_update_split_mark(list);
         //     }
         //     list = node_next(list);
         // }
            return head;
        } else { 
            /*tex Wipe the box, see below. */
        }
    }
    tex_handle_error(
        normal_error_type,
        "\\vbalanced needs a \\vbox result from \\vbalance",
        "The box you are trying to fetch from is not the result of \\vbalance, so to play safe I''ll\n"
        "wipe it."
    );
    tex_flush_node(box);
    box_register(n) = null;
    return null;
}

/* we always have top and bottom skips */

static void tex_aux_wipe_top_discard(halfword head, scaled amount)
{
    halfword prev = node_prev(head);
    if (prev && (node_type(prev) == glue_node) && node_subtype(prev) == top_skip_glue) {
        glue_amount(prev) += amount;
        tex_try_couple_nodes(prev, node_next(head));
        tex_flush_node(head);
    }
}

static void tex_aux_wipe_bottom_discard(halfword tail, scaled amount)
{
    halfword next = node_next(tail);
    if (next && (node_type(next) == glue_node) && node_subtype(next) == bottom_skip_glue) {
        glue_amount(next) += amount;
        tex_try_couple_nodes(node_prev(tail), next);
        tex_flush_node(tail);
    }   
}

void tex_vbalanced_discard(
    halfword n,
    halfword options
) 
{
    halfword box = tex_aux_locate_balance_target(n, balance_list, 0); // no descend 
    if (box < 0) {
        return;
    } else if (box) {
        halfword list = box_list(box);
        int remove = options & balance_discard_remove;
        while (list) { 
            if (node_type(list) == vlist_node && (box_balance_state(list) & balance_state_discards)) {
                halfword head = box_list(list);
                if (head) {
                    halfword tail = tex_tail_of_node_list(head);
                    while (head) { 
                        switch (node_type(head)) {
                            case hlist_node:
                            case vlist_node:
                                if (box_options(head) & box_option_discardable) {
                                    if (remove) { 
                                        tex_aux_wipe_top_discard(head, box_total(head));
                                    } else {
                                        tex_flush_node_list(box_list(head));
                                        box_list(head) = null;
                                    }
                                }
                                head = null;
                                break;
                            case rule_node:
                                if (rule_options(head) & rule_option_discardable) {
                                    if (remove) { 
                                        tex_aux_wipe_top_discard(head, rule_total(head));
                                    } else {
                                       node_subtype(head) = empty_rule_subtype;
                                    }
                                }
                                head = null;
                                break;
                            case glue_node: 
                                if (node_subtype(head) == top_skip_glue) {
                                    head = node_next(head);
                                } else { 
                                    head = null;
                                }
                                break;
                            default: 
                                head = null;
                                break;
                        }
                    }
                    while (tail) { 
                        switch (node_type(tail)) {
                            case hlist_node:
                            case vlist_node:
                                if (box_options(tail) & box_option_discardable) {
                                    tex_flush_node_list(box_list(tail));
                                    if (remove) { 
                                        tex_aux_wipe_bottom_discard(tail, box_total(tail));
                                    } else {
                                        box_list(tail) = null;
                                    }
                                }
                                tail = null;
                                break;
                            case rule_node:
                                if (rule_options(tail) & rule_option_discardable) {
                                    if (remove) { 
                                        tex_aux_wipe_bottom_discard(tail, rule_total(tail));
                                    } else {
                                        node_subtype(tail) = empty_rule_subtype;
                                    }
                                }
                                tail = null;
                                break;
                            case glue_node: 
                                if (node_subtype(tail) == bottom_skip_glue) {
                                    tail = node_prev(tail);
                                } else { 
                                    tail = null;
                                }
                                break;
                            default: 
                                tail = null;
                                break;
                        }
                    }
                }
            }
            list = node_next(list);
        }
    } else {
        tex_handle_error(
            normal_error_type,
            "\\vbalancediscard needs a \\vbox result from \\vbalance",
            "The box you are trying to cleanup is not the result of \\vbalance."
        );
    }
}

halfword tex_vbalanced_insert(
    halfword n, 
    halfword i,
    halfword options
)
{

    halfword box = tex_aux_locate_balance_target(n, balance_slot_list, options & balance_insert_descend);
    if (box < 0) {
        return null;
    } else if (box) {
        halfword current = box_list(box);
        halfword head = null;
        halfword tail = null;
        while (current) { 
            halfword next = node_next(current);
            if (node_type(current) == insert_node && insert_index(current) == i) {
                halfword list = insert_list(current);
                if (list) {
                    if (head) {
                        tex_couple_nodes(tail, list);
                    } else { 
                        head = list;
                    }      
                    tail = tex_tail_of_node_list(list);
                    /* maybe: remove the insert node */
                    insert_list(current) = null;
                    /* for now: safeguard */
                    insert_total_height(current) = 0;
                }
            }
            current = next;
        }
        if (head) { 
            return tex_vpack(head, 0, packing_additional, 0, 0, holding_none_option, NULL);
        }
    } else {
        tex_handle_error(
            normal_error_type,
            "\\vbalanceinsert needs a \\vbox result from \\vbalanced",
            "The box you are trying to get inserts from is not the result of \\vbalanced."
        );
    }
    return null;
}

void tex_vbalanced_deinsert(
    halfword n,
    halfword options 
)
{
    halfword box = tex_aux_locate_balance_target(n, unknown_list, options & balance_deinsert_descend);
    if (box < 0) {
        return;
    } else if (box) {
        halfword current = box_list(box);
        int forcedepth = options & balance_deinsert_linedepth;
        while (current) { 
            halfword next = node_next(current);
            if (node_type(current) == insert_node && tex_insert_height(current) > 0) {
                halfword head = insert_list(current);
                halfword prev = node_prev(current);
                if (head && prev) {
                    halfword temp = current;
                    halfword last = null;
                    insert_list(temp) = null;
                    insert_options(temp) |= insert_option_in_insert;
                    current = prev; 
                    while (head) { 
                        halfword next = node_next(head);
                        switch (node_type(head)) {
                            case hlist_node:
                            case vlist_node:
                                {
                                    halfword insert = tex_copy_node(temp);
                                    insert_list(insert) = head;
                                    insert_total_height(insert) = box_total(head);
                                    last = insert;
                                    node_next(head) = null;
                                    node_prev(head) = null;
                                    tex_couple_nodes(current, insert);
                                    current = insert; 
                                    break;
                                }
                            case rule_node:
                                {
                                    halfword insert = tex_copy_node(temp);
                                    insert_list(insert) = head;
                                    insert_total_height(insert) = rule_total(head);
                                    last = insert;
                                    node_next(head) = null;
                                    node_prev(head) = null;
                                    tex_couple_nodes(current, insert);
                                    current = insert; 
                                    break;
                                }
                            case kern_node:
                                {
                                    tex_couple_nodes(current, head);
                                    node_next(head) = null;
                                    kern_options(head) |= kern_option_in_insert;
                                    last = null;
                                    current = head;
                                    break;
                                }
                            case glue_node: 
                                { 
                                    /* todo: multiplier, so a better set height */
                                    if (last && node_subtype(head) == baseline_skip_glue) {
                                        if (forcedepth) {
                                            halfword depth = insert_line_depth(last);
                                            if (depth > 0) { 
                                                halfword list = insert_list(last);
                                                switch (node_type(list)) {
                                                    case hlist_node:
                                                    case vlist_node:
                                                        {
                                                            scaled delta = depth - box_depth(list); 
                                                            if (delta > 0) {
                                                                glue_amount(head) -= delta;
                                                                box_depth(list) += delta; 
                                                                insert_total_height(last) += delta;
                                                            }
                                                            break;
                                                        }
                                                    case rule_node:
                                                        {
                                                            scaled delta = depth - rule_depth(list); 
                                                            if (delta > 0) {
                                                                glue_amount(head) -= delta;
                                                                rule_depth(list) += delta; 
                                                                insert_total_height(last) += delta;
                                                            }
                                                            break;
                                                        }
                                                }
                                            }
                                        }
                                    }
                                    tex_couple_nodes(current, head);
                                    node_next(head) = null;
                                    glue_options(head) |= glue_option_in_insert;
                                    last = null;
                                    current = head;
                                    break;
                                }
                            case penalty_node: 
                                {
                                    tex_couple_nodes(current, head);
                                    node_next(head) = null;
                                    penalty_options(head) |= penalty_option_in_insert;
                                    current = head;
                                    break;
                                }
                            default: 
                                {
                                    halfword insert = tex_copy_node(temp);
                                    insert_list(insert) = head;
                                    insert_total_height(insert) = 0;
                                    tex_couple_nodes(current, head);
                                    node_next(head) = null;
                                    last = null;
                                    current = insert; 
                                    break;
                                }
                        } 
                        head = next;
                    }
                    tex_try_couple_nodes(current, next);
                    tex_flush_node(temp);
                }
            }
            current = next;
        }
    } else {
        tex_handle_error(
            normal_error_type,
            "\\vbalancedeinsert needs a \\vbox result from \\vbalance",
            "The box you are trying to process inserts from is not the result of \\vbalance."
        );
    }
}

void tex_vbalanced_reinsert(
    halfword n,
    halfword options 
)
{
    halfword box = tex_aux_locate_balance_target(n, balance_slot_list, options & balance_reinsert_descend);
    if (box < 0) {
        return;
    } else if (box) {
        halfword current = box_list(box);
        halfword head = null;
        halfword tail = null;
        halfword insert = null;
        halfword data = 0;
        /* saveguard, so that we have a prev ... likely topskip */
        if (current) { 
            current = node_next(current);
        }
        /* */
        while (current) { 
            halfword next = node_next(current);
            switch (node_type(current)) {
                case kern_node:
                    if (kern_options(current) & kern_option_in_insert) {
                        if (insert) { 
                            if (head) { 
                                tex_couple_nodes(tail, current);
                            } else { 
                                head = current;
                            } 
                            tail = current;
                            insert_total_height(insert) += kern_amount(current);
                        } else {
//printf("kern: to be decided\n");
                            kern_amount(current) = 0; /* todo */
                        }
                    } else { 
                        insert = null;
                    }
                    break;
                case glue_node: 
                    if (glue_options(current) & glue_option_in_insert) {
                        if (insert) { 
                            tex_try_couple_nodes(node_prev(current), next);
                            node_prev(current) = null;
                            node_next(current) = null;
                            if (head) { 
                                tex_couple_nodes(tail, current);
                            } else { 
                                head = current;
                            } 
                            tail = current;
                            insert_total_height(insert) += glue_amount(current);
                        } else { 
//printf("glue: to be decided\n");
                            glue_amount(current) = 0;  /* todo */
                            glue_stretch(current) = 0; /* todo */
                            glue_shrink(current) = 0;  /* todo */
                        }
                    } else { 
                        insert = null;
                    }
                    break;
                case penalty_node: 
                    if (penalty_options(current) & penalty_option_in_insert) {
                        if (insert) { 
                            tex_try_couple_nodes(node_prev(current), next);
                            node_prev(current) = null;
                            node_next(current) = null;
                            if (head) { 
                                tex_couple_nodes(tail, current);
                            } else { 
                                head = current;
                            } 
                            tail = current;
                        } else { 
//printf("penalty: to be decided\n");
                            penalty_amount(current) = 0;
                        }
                    } else { 
                        insert = null;
                    }
                    break;
                case insert_node: 
                    if (insert_options(current) & insert_option_in_insert) {
                        if (! insert || insert_identifier(current) != data) {
                            insert = current;
                            head = insert_list(current);
                            tail = insert_list(current);
                            data = insert_identifier(current);
                        } else { 
                            /* insert has been set */
                            tex_try_couple_nodes(node_prev(current), next);
                            node_prev(current) = null;
                            node_next(current) = null;
                            insert_total_height(insert) += insert_total_height(current);
                            tex_couple_nodes(tail, insert_list(current));
                            tail = insert_list(current);
                            insert_list(current) = null;    
                            tex_flush_node(current);
                        }
                    } else { 
                        insert = null;
                        data   = 0;
                    }
                    break;
                default: 
                    insert = null;
                    break;
            }
            current = next;
        }
    } else { 
        tex_handle_error(
            normal_error_type,
            "\\vbalancereinsert needs a \\vbox result from \\vbalanced",
            "The box you are trying to process inserts from is not the result of \\vbalanced."
        );
    }
}
