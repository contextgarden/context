
/*
    See license.txt in the root of this project.
*/

# include <luametatex.h>
# include "luarest/lmtvectorlib.h"
# include "utilities/auxbitset.h"

/*tex

    Z-buffers

    When we picked up on our \METAFUN\ contour graphics we (Mikael S and Hans H) searched the
    internet and queried LLM for resources and the best way to deal with z-buffering. In the
    end these are old (existing) solutions that one can find in books. After various intermediate
    stages we ended up with the following. See \type {drawinglines-ai.pdf} for the process.

    Although we queried Chat 5.5 for insights in the end we pretty much came up with solutions
    that better fit in what we already had. It's also just too much (boring) work to filter basic
    algorithms from suggested solutions. Working from scratch is much more efficient and fun
    anyways. But, one needs access to research and that is what these \LLM's provide with books
    out of print or articles behind paywalls. We don't have the means for advanced \LLM\ usage
    anyway, so basic queries (references and explanations) are what we have to stick to. When you
    search for backgrounds on some technology you get offers to generate code so we did look at
    some as part of our experiment. One conclusion we came to is that it can give a picture, even
    work for some cases but that one cannot really trust it to workm, let alone the what is called
    \quote {slop}. It just doesn't pay back and is also too much of a risk.

    So what is this zbuffering about? It basically boils down to projections in terms of \quote
    {eyes}, \quote {targets}, \quote {field of view}, \quote {near} and \quote {far} depth criteria,
    combined with \quote {diffusion} (color), \quote {light} (from some point), \quote {opacity} for
    multiple stacked objects, \quote {ambient} variation and what more. One needs to figure this all
    out in a way that fits hwo it is commonly seen and that is what the \LLM\ was useful for. In the
    end (of course) all dates from decades ago. Of course, when search engines were not infected by
    AI, ending up at a wikipedia (or similar) page was better; now one has to be more explicit.

    Wrapping it all up in a proper \LUA\ interface and deciding what to delegate to \CCODE\ is what
    we've done for ages now so in the end all looks familiar. The stipple solutions at the end are
    actually where we kept most of the suggestions (but written differently) and the same is true
    for the implicit (tetra) generator but we had to come up with some efficient mix of \LUA\ and
    \CCODE\ but we already did similar things elsewhere so we could build upon that. Again, all has
    to fit into the already present infrastructure.

    Efficiency was also a priority because normally one delegates these tasks to a graphic card or
    at least some library but such dependencies don't fit into the \TEX\ paradigm. So, we had to
    spend time on that too, but that is actually the fun part: optimal performance combines with
    integration into how we do things in \METAPOST\ (where it hoosk into). The later is why we
    see bytemaps and such show up. We're now on a stage where adding more feature is easy so expect
    that to happen occasionaly.

    On my already somewhat old bookshelf I have:

    -- Three-Dimensional Computer Graphics, Alan Watt
    -- Image Synthesis, Elementary Algorithms, Gerard Hegron
    -- Computer Grahics, Systems and Concepts, Rod Salmon and Mel Slater

    Especially the first one has good descriptions of models in use (phigs,
    gks-3d etc) and termology, like:

    -- diffusion : reflection of light on a surface (also absorbsion)
    -- ambient   : light coming from reflections from walls and objects
                   that makes e.g. parallel surfaces visible (shadow)
    -- specular  : glossiness i.e. surface properties
    -- distance  : as parameters influencing all the above

    and so on (it follows the Phong model). Scan lines, edges, zbuffering, supersampling etc.
    are all concepts from the 80's and before.

    I need to find a copy of Foley and Van Dam which I've seen when at the uni
    but never bought: stupid me. I anyway have to look into Bezier patches.

    Next on the list is textures (via \LUA\ functions).

*/

# define isvisible(a) (a & zbuffer_vector_state_visible)
# define  isbehind(a) (a & zbuffer_vector_state_behind)
# define hasnormal(a) (a & zbuffer_vector_state_hasnormal)

/*tex

    Here are a few common helpers: we often need to stick within a proper range (colors and normals
    are an example) and normalize vectors.

*/

# define fffmax(a,b,c) ((a > b) ? ((a > c) ? a : c) : ((b > c) ? b : c))
# define fffmin(a,b,c) ((a < b) ? ((a < c) ? a : c) : ((b < c) ? b : c))
# define  ffmax(a,b)   ((a > b) ? a : b)
# define  ffmin(a,b)   ((a < b) ? a : b)

static inline double limited(double value, double low, double high)
{
    return (value < low) ? low : (value > high) ? high : value;
}

static inline double dotproduct(double ax, double ay, double az, double bx, double by, double bz)
{
    return ax * bx + ay * by + az * bz;
}

static inline void normalize(double *x, double *y, double *z)
{
    double length = sqrt(*x * *x + *y * *y + *z * *z);
    if (length == 0.0) {
        *x = 0;
        *y = 0;
        *z = 1;
    } else {
        *x = *x / length;
        *y = *y / length;
        *z = *z / length;
    }
}

static inline unsigned char byteclipped(double i)
{
    return i < 0 ? 0 : i > 1 ? 255 : (unsigned char) lround(255*i);
}

static zbuffer vectorlib_aux_maybe_iszbuffer(lua_State *L, int index)
{
    zbuffer zb = lua_touserdata(L, index);
    if (zb && lua_getmetatable(L, index)) {
        lua_get_metatablelua(zbuffer_instance);
        if (! lua_rawequal(L, -1, -2)) {
            zb = NULL;
        }
        lua_pop(L, 2);
    }
    return zb;
}

static int zbufferlib_valid(lua_State *L)
{
    lua_pushboolean(L, vectorlib_aux_maybe_iszbuffer(L, 1) ? 1 : 0);
    return 1;
}

static int zbufferlib_type(lua_State *L)
{
    if (vectorlib_aux_maybe_iszbuffer(L, 1)) {
        lua_push_key(zbuffer);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

/*tex

    We either directly map points onto a zbuffer grid or we stack them in a depth buffer, which
    first was a sparse \LUA\ table but eventually became a dedicated structure. The stack is
    only allocated when we neede it. These are memory hungry data structures because they depend
    on the resolution (we relate that to the final size as needed on the \METAPOST\ end) as well
    as accuracy and eventual anti-aliasing.

    Because we wanted stippling we also had to add the four fields needed for that; it's the price
    we pay. We use doubles but floats might also work well. Consider that an implementation detail.

    The inferfaces below mostly match those of the already present vector interfaces, although for
    the already present vector based variant we have an average field in the meshes. We might come
    back to that at some point.

*/

static void zbuffer_allocate(zbuffer zb, int rows, int columns)
{
    if (! zb->data) {
        if (rows > 12000) {
            printf("zbuffer warning: cropping rows\n");
            rows = 12000;
        }
        if (columns > 12000) {
            printf("zbuffer warning: cropping columns\n");
            columns = 12000;
        }
        zb->rows      = rows;
        zb->columns   = columns;
        zb->size      = rows * columns;
        zb->databytes = zb->size * sizeof(zbufferentry);
        zb->data      = vectorlib_memory_malloc(zb->databytes);
        if (zb->data) {
            zbufferentry dflt = (zbufferentry) {
                .red       = zb->setup.viewport.backgroundcolor.r,
                .green     = zb->setup.viewport.backgroundcolor.g,
                .blue      = zb->setup.viewport.backgroundcolor.b,
                .depth     = INFINITY,
                .opacity   = 0,
                .nx        = 0,
                .ny        = 0,
                .nz        = 0,
                /* stippling: */
             // .coverage  = 0,
             // .error     = 0,
             // .edge      = 0,
             // .intensity = 0,
            };
            for (int i = 0; i < zb->size; i++) {
                zb->data[i] = dflt;
            }
        } else {
            printf("zbuffer creation : error %i\n", 1);
        }
    } else {
        printf("zbuffer creation : error %i\n", 2);
    }
}

/*tex

    We decided to keep all parameters in a dedicated structure. We started out with passing
    parameters to every relevant step but this makes more sense. It also made it possible to add
    more funcitonality (and even more later). Most parameters are kind of general in the sense
    that when you search for #D projection you find features described in these terms.

    Currently we add stipple settings here but they might as well seperate them ehwn we add
    alternative postprocessors.

*/

static inline zbuffer zbufferlib_aux_push(lua_State *L, int rows, int columns)
{
    zbuffer zb = lua_newuserdatauv(L, sizeof(zbufferdata), 0);
    if (zb) {
        /* basics */
        zb->rows         = 0;
        zb->columns      = 0;
        zb->size         = 0;
        zb->data         = NULL;
        zb->stack        = NULL;
        zb->stipple      = NULL;
        zb->texture      = NULL;
        zb->stackbytes   = 0;
        zb->databytes    = 0;
        zb->stipplebytes = 0;
        zb->texturebytes = 0;
        zb->recordbytes  = 0;
        zb->composed     = 0;
        /* setup */
        zb->setup = (zbuffersetup) {
            .perspective = 0,
            .usespecular = 0,
            .state       = 0,
            .projection = {
                .right   = { .x = 0, .y = 0, .z = 0 },
                .up      = { .x = 0, .y = 0, .z = 0 },
                .forward = { .x = 0, .y = 0, .z = 0 },
                .eye     = { .x = 0, .y = 0, .z = 0 },
                .target  = { .x = 0, .y = 0, .z = 0 },
                .ortho   = { .x = 0, .y = 0, .z = 0 },
            },
            .light = {
                .direction = { .x = 0, .y = 0, .z = 0 },
                .intensity = 0,
                .normal    = { .x = 0, .y = 0, .z = 0 },
            },
            .material = {
                .diffuse     = { .r = 0, .g = 0, .b = 0 },
                .specular    = { .r = 0, .g = 0, .b = 0 },
                .shininess   = 0,
                .ambient     = 0,
                .opacity     = 0,
                .twosided    = 0,
                .texture     = 0,
                .dx          = 0,
                .dy          = 0,
                .depth       = 0,
            },
            .transform = {
                .x     = 0,
                .y     = 0,
                .scale = 0,
            },
            .viewport = {
                .width           = 0,
                .height          = 0,
                .supersample     = 1,
                .maxfragment     = zbuffer_maxnoffragments,
                .done            = 0,
                .xmin            = 0,
                .xmax            = 0,
                .ymin            = 0,
                .ymax            = 0,
                .backgroundcolor = { .r = 1, .g = 1, .b = 1 },
            },
            .camera = {
                .nearby  = 0,
                .faraway = 0,
                .scale   = 0,
                .tanhalf = 0,
            },
            .stipple = {
                .usenormal        = 1,
                .nobackground     = 0,
                .backgroundcolor  = { .r = 1, .g = 1, .b = 1 },
                .color            = { .r = 0, .g = 0, .b = 0 },
                .creaseangle      = 25,
                .sameangle        = 15,
                .dzsamemultiplier = 2.0,
                .dzedgemultiplier = 8.0,
                .mindepthstep     = 1e-12,
                .luminance        = { .r = 0.2126, .g = 0.7152, .b = 0.0722 },
                .edgeboost        = 0.20,
                .coveragegamma    = 1.25,
                .minimumcoverage  = 0,
                .maximumcoverage  = 1,
                .serpentine       = 1,
                .errorthreshold   = 0.5,
                .dotradius        = 0,
                .clipdots         = 1,
             // .levels           = ...,
                .noflevels        = 0,
                .tonedots         = 1,
                .outline          = 0,
                .outlinethreshold = 0.85,
                .outlineradius    = 0,
                /* internal */
                .dzsame           = 0,
                .dzedge           = 0,
                .median           = 0,
                .cossame          = 0,
                .coscrease        = 0,
            },
        };
        if (rows > 0 && columns > 0) {
            zbuffer_allocate(zb, rows, columns);
        }
        /* wipe */
        lua_get_metatablelua(zbuffer_instance);
        lua_setmetatable(L, -2);
        return zb;
    } else {
        return NULL;
    }
}

/*tex

    The usual interfacing comes next, not so much different from the rest of this module (and
    others). There are more interfaces that we need, so some might go. We use(d) them when we
    prototyped in \LUA.

*/

static int zbufferlib_new(lua_State *L)
{
    zbuffer zb = zbufferlib_aux_push(L, 0, 0);
    if (zb) {
        return 1;
    } else {
        printf("zbuffer creation : error\n");
        return 0;
    }
}

inline static zbuffer zbufferlib_aux_get(lua_State *L, int index)
{
    zbuffer z = lua_touserdata(L, index);
    if (z && lua_getmetatable(L, index)) {
        lua_get_metatablelua(zbuffer_instance);
        if (! lua_rawequal(L, -1, -2)) {
            z = NULL;
        }
    }
    lua_pop(L, 2);
    return z;
}

static int zbufferlib_gc(lua_State *L)
{
    zbuffer zb = zbufferlib_aux_get(L, 1);
    if (zb) {
        if (zb->stack && zb->composed) {
            for (int i=0; i < zb->size; i++) {
                if (zb->stack[i].data) {
                    size_t size = zb->stack[i].size * sizeof(zbufferstackentry);
                    zb->recordbytes -= size;
                    vectorlib_memory_free(zb->stack[i].data, size);
                }
            }
        }
        vectorlib_memory_free(zb->stack,   zb->stackbytes);
        vectorlib_memory_free(zb->data,    zb->databytes);
        vectorlib_memory_free(zb->stipple, zb->stipplebytes);
        vectorlib_memory_free(zb->texture, zb->texturebytes);
        zb->stack        = NULL;
        zb->data         = NULL;
        zb->stipple      = NULL;
        zb->texture      = NULL;
        zb->stackbytes   = 0;
        zb->databytes    = 0;
        zb->stipplebytes = 0;
        zb->texturebytes = 0;
        zb->recordbytes  = 0;
        zb->rows         = 0;
        zb->columns      = 0;
        zb->size         = 0;
        zb->composed     = 0;
    }
    return 0;
}

static int lua_getzbuffervector(lua_State *L, int index, const char * key, zbuffervector *vector)
{
    int ok = 0;
    if (lua_getfield(L, index, key) == LUA_TTABLE) {
        vector->x = lua_rawgeti(L, -1, 1) == LUA_TNUMBER ? lua_tonumber(L, -1) : vector->x; lua_pop(L, 1);
        vector->y = lua_rawgeti(L, -1, 2) == LUA_TNUMBER ? lua_tonumber(L, -1) : vector->y; lua_pop(L, 1);
        vector->z = lua_rawgeti(L, -1, 3) == LUA_TNUMBER ? lua_tonumber(L, -1) : vector->z; lua_pop(L, 1);
        ok = 1;
    }
    lua_pop(L, 1);
    return ok;
}

static int lua_getzbuffercolor(lua_State *L, int index, const char *key, zbuffercolor *color)
{
    int ok = 0;
    if (lua_getfield(L, index, key) == LUA_TTABLE) {
        color->r = lua_rawgeti(L, -1, 1) == LUA_TNUMBER ? lua_tonumber(L, -1) : color->r; lua_pop(L, 1);
        color->g = lua_rawgeti(L, -1, 2) == LUA_TNUMBER ? lua_tonumber(L, -1) : color->g; lua_pop(L, 1);
        color->b = lua_rawgeti(L, -1, 3) == LUA_TNUMBER ? lua_tonumber(L, -1) : color->b; lua_pop(L, 1);
        ok = 1;
    }
    lua_pop(L, 1);
    return ok;
}

/*tex

    We setup stepwise. For instance in order to project we do need to set up the eye, target and
    up early on, while for instance stippling can be delayed till we are up to it. In that sense
    this library is very much related to the \LUA\ wrapper code that itself has to interface to
    \METAPOST. In that sense it is similar to other libraries, like those for \PNG\ processing
    and \ZIP\ compression. We do in \LUA\ what can best be done there.

*/

static int zbufferlib_setup(lua_State *L)
{
    zbuffer zb = zbufferlib_aux_get(L, 1);
    if (zb && lua_type(L, 2) == LUA_TTABLE) {
        if (zb->setup.state & zbuffer_target_set) {
            /* warning */
        } else {
            lua_getzbuffervector(L, 2, "eye",     &(zb->setup.projection.eye));
            lua_getzbuffervector(L, 2, "up",      &(zb->setup.projection.up));
            /* normally generated */
            lua_getzbuffervector(L, 2, "right",   &(zb->setup.projection.right));
            lua_getzbuffervector(L, 2, "forward", &(zb->setup.projection.forward));
        }
        if (lua_getzbuffervector(L, 2, "target", &(zb->setup.projection.target))) {
            zb->setup.projection.forward.x = zb->setup.projection.target.x - zb->setup.projection.eye.x;
            zb->setup.projection.forward.y = zb->setup.projection.target.y - zb->setup.projection.eye.y;
            zb->setup.projection.forward.z = zb->setup.projection.target.z - zb->setup.projection.eye.z;
            zb->setup.projection.right.x = zb->setup.projection.forward.y * zb->setup.projection.up.z - zb->setup.projection.forward.z * zb->setup.projection.up.y;
            zb->setup.projection.right.y = zb->setup.projection.forward.z * zb->setup.projection.up.x - zb->setup.projection.forward.x * zb->setup.projection.up.z;
            zb->setup.projection.right.z = zb->setup.projection.forward.x * zb->setup.projection.up.y - zb->setup.projection.forward.y * zb->setup.projection.up.x;
            normalize(&(zb->setup.projection.forward.x), &(zb->setup.projection.forward.y), &(zb->setup.projection.forward.z));
            normalize(&(zb->setup.projection.right  .x), &(zb->setup.projection.right  .y), &(zb->setup.projection.right  .z));
            zb->setup.projection.up.x = zb->setup.projection.right.y * zb->setup.projection.forward.z - zb->setup.projection.right.z * zb->setup.projection.forward.y;
            zb->setup.projection.up.y = zb->setup.projection.right.z * zb->setup.projection.forward.x - zb->setup.projection.right.x * zb->setup.projection.forward.z;
            zb->setup.projection.up.z = zb->setup.projection.right.x * zb->setup.projection.forward.y - zb->setup.projection.right.y * zb->setup.projection.forward.x;
            zb->setup.state |= zbuffer_target_set;
        };

        if (lua_getfield(L, 2, "perspective") == LUA_TBOOLEAN) { zb->setup.perspective = lua_toboolean(L, -1); } lua_pop(L, 1);

        if (lua_getfield(L, 2, "material") == LUA_TTABLE) {
            if (lua_getfield(L, -1, "shininess") == LUA_TNUMBER)  { zb->setup.material.shininess = lua_tonumber (L, -1); } lua_pop(L, 1);
            if (lua_getfield(L, -1, "ambient")   == LUA_TNUMBER)  { zb->setup.material.ambient   = lua_tonumber (L, -1); } lua_pop(L, 1);
            if (lua_getfield(L, -1, "opacity")   == LUA_TNUMBER)  { zb->setup.material.opacity   = lua_tonumber (L, -1); } lua_pop(L, 1);
            if (lua_getfield(L, -1, "twosided")  == LUA_TBOOLEAN) { zb->setup.material.twosided  = lua_toboolean(L, -1); } lua_pop(L, 1);
            if (lua_getfield(L, -1, "texture")   == LUA_TNUMBER)  { zb->setup.material.texture   = lua_tointeger(L, -1); } lua_pop(L, 1);
            if (lua_getfield(L, -1, "dx")        == LUA_TNUMBER)  { zb->setup.material.dx        = lua_tonumber (L, -1); } lua_pop(L, 1);
            if (lua_getfield(L, -1, "dy")        == LUA_TNUMBER)  { zb->setup.material.dy        = lua_tonumber (L, -1); } lua_pop(L, 1);
            if (lua_getfield(L, -1, "depth")     == LUA_TNUMBER)  { zb->setup.material.depth     = lua_tonumber (L, -1); } lua_pop(L, 1);
            lua_getzbuffercolor (L, -1, "specular", &(zb->setup.material.specular));
            lua_getzbuffercolor (L, -1, "diffuse",  &(zb->setup.material.diffuse));
        }
        lua_pop(L, 1);

        if (lua_getfield(L, 2, "light") == LUA_TTABLE) {
            if (lua_getfield(L, -1, "intensity") == LUA_TNUMBER) { zb->setup.light.intensity = lua_tonumber(L, -1); } lua_pop(L, 1);
            lua_getzbuffervector(L, -1, "direction", &(zb->setup.light.direction));
        }
        lua_pop(L, 1);

        if (lua_getfield(L, 2, "viewport") == LUA_TTABLE) {
            if (lua_getfield(L, -1, "width")  == LUA_TNUMBER) { zb->setup.viewport.width  = lua_tonumber(L, -1); } lua_pop(L, 1);
            if (lua_getfield(L, -1, "height") == LUA_TNUMBER) { zb->setup.viewport.height = lua_tonumber(L, -1); } lua_pop(L, 1);

            if (lua_getfield(L, -1, "supersample") == LUA_TNUMBER) {
                zb->setup.viewport.supersample = lua_tonumber(L, -1);
                if (zb->setup.viewport.supersample > 4) {
                    zb->setup.viewport.supersample = 4;
                } else if (zb->setup.viewport.supersample < 1) {
                    zb->setup.viewport.supersample = 2;
                }
            }
            lua_pop(L, 1);

            if (lua_getfield(L, -1, "maxfragment") == LUA_TNUMBER) {
                zb->setup.viewport.maxfragment = lmt_tointeger(L, -1);
                if (zb->setup.viewport.maxfragment > zbuffer_maxnoffragments) {
                    zb->setup.viewport.maxfragment = zbuffer_maxnoffragments;
                } else if (zb->setup.viewport.maxfragment < 1) {
                    zb->setup.viewport.maxfragment = 1;
                }
            }
            lua_pop(L, 1);

            lua_getzbuffercolor(L, -1, "backgroundcolor", &(zb->setup.viewport.backgroundcolor));
        }
        lua_pop(L, 1);

        if (lua_getfield(L, 2, "camera") == LUA_TTABLE) {
            if (lua_getfield(L, -1, "near")    == LUA_TNUMBER) { zb->setup.camera.nearby  = lua_tonumber(L, -1); } lua_pop(L, 1);
            if (lua_getfield(L, -1, "far")     == LUA_TNUMBER) { zb->setup.camera.faraway = lua_tonumber(L, -1); } lua_pop(L, 1);
            if (lua_getfield(L, -1, "scale")   == LUA_TNUMBER) { zb->setup.camera.scale   = lua_tonumber(L, -1); } lua_pop(L, 1);
            if (lua_getfield(L, -1, "tanhalf") == LUA_TNUMBER) { zb->setup.camera.tanhalf = lua_tonumber(L, -1); } lua_pop(L, 1);
        }
        lua_pop(L, 1);

        if (lua_getfield(L, 2, "transform") == LUA_TTABLE) {
            if (lua_getfield(L, -1, "x")     == LUA_TNUMBER) { zb->setup.transform.x     = lua_tonumber(L, -1); } lua_pop(L, 1);
            if (lua_getfield(L, -1, "y")     == LUA_TNUMBER) { zb->setup.transform.y     = lua_tonumber(L, -1); } lua_pop(L, 1);
            if (lua_getfield(L, -1, "scale") == LUA_TNUMBER) { zb->setup.transform.scale = lua_tonumber(L, -1); } lua_pop(L, 1);
        }
        lua_pop(L, 1);

        /* */
        zb->setup.usespecular = zb->setup.material.shininess > 0 && (zb->setup.material.specular.r != 0 || zb->setup.material.specular.g != 0 || zb->setup.material.specular.b != 0);
        /* */
        zb->setup.projection.ortho.x = -zb->setup.projection.forward.x;
        zb->setup.projection.ortho.y = -zb->setup.projection.forward.y;
        zb->setup.projection.ortho.z = -zb->setup.projection.forward.z;
        if (zb->setup.usespecular && ! zb->setup.perspective) {
            normalize(&(zb->setup.projection.ortho.x), &(zb->setup.projection.ortho.y), &zb->setup.projection.ortho.z);
        }
        zb->setup.light.normal.x = -zb->setup.light.direction.x;
        zb->setup.light.normal.y = -zb->setup.light.direction.y;
        zb->setup.light.normal.z = -zb->setup.light.direction.z;
        normalize(&(zb->setup.light.normal.x), &(zb->setup.light.normal.y), &(zb->setup.light.normal.z));
        /* */
        if (zb->setup.material.texture && ! zb->texture) {
            zb->texturebytes = zb->size * sizeof(zbuffertexture);
            zb->texture      = vectorlib_memory_calloc(zb->size, sizeof(zbuffertexture));
        }
        /* */
        if (! zb->data) {
            int height = 0;
            int width  = 0;
            if (lua_getfield(L, 2, "height") == LUA_TNUMBER) { height = lmt_tointeger(L, -1); } lua_pop(L, 1);
            if (lua_getfield(L, 2, "width")  == LUA_TNUMBER) { width  = lmt_tointeger(L, -1); } lua_pop(L, 1);
            if (height > 0 && width > 0) {
                zbuffer_allocate(zb, height, width);
            }
        }
    }
    return 0;
}

static int zbufferlib_tostring(lua_State *L)
{
    zbuffer zb = zbufferlib_aux_get(L, 1);
    if (zb) {
        lua_pushfstring(L, "<zbuffer %p : rows %d columns %d xmin %d ymin %d xmax %d ymax %d>",
            zb,
            zb->rows, zb->columns,
            zb->setup.viewport.xmin, zb->setup.viewport.ymin,
            zb->setup.viewport.xmax, zb->setup.viewport.ymax
        );
        return 1;
    } else {
        return 0;
    }
}

static int zbufferlib_totable(lua_State *L)
{
    zbuffer zb = zbufferlib_aux_get(L, 1);
    if (zb && zb->data) {
        lua_createtable(L, zb->rows, 0);
        for (int r = 0; r < zb->rows; r++) {
            lua_createtable(L, zb->columns, 0);
            for (int c = 0; c < zb->columns; c++) {
                zentry e = &(zb->data[r * zb->columns + c]);
                lua_createtable(L, 8, 0);
                /* can be a push plus loop */
# if 1
                lua_pushnumber(L, e->red    ); lua_rawseti(L, -2, 1);
                lua_pushnumber(L, e->green  ); lua_rawseti(L, -2, 2);
                lua_pushnumber(L, e->blue   ); lua_rawseti(L, -2, 3);
                lua_pushnumber(L, e->depth  ); lua_rawseti(L, -2, 4);
                lua_pushnumber(L, e->opacity); lua_rawseti(L, -2, 5);
                lua_pushnumber(L, e->nx     ); lua_rawseti(L, -2, 6);
                lua_pushnumber(L, e->ny     ); lua_rawseti(L, -2, 7);
                lua_pushnumber(L, e->nz     ); lua_rawseti(L, -2, 8);
# else
                lua_pushnumber(L, e->red    );
                lua_pushnumber(L, e->green  );
                lua_pushnumber(L, e->blue   );
                lua_pushnumber(L, e->depth  );
                lua_pushnumber(L, e->opacity);
                lua_pushnumber(L, e->nx     );
                lua_pushnumber(L, e->ny     );
                lua_pushnumber(L, e->nz     );
                for (int i = 8; i >= 1; i--) {
                    lua_rawseti(L, -2, i);
                }
# endif
                lua_rawseti(L, -2, c + 1);
            }
            lua_rawseti(L, -2, r + 1);
        }
        return 1;
    } else {
        return 0;
    }
}

/*

    We keep track of what pizels get set. We could also crop beforehand by using the accumulated
    bounding boxes of the objects, and indeed that is taken into account, but evetually we look at
    what really got set.

*/

static int zbufferlib_crop(lua_State *L)
{
    zbuffer old = vectorlib_aux_maybe_iszbuffer(L, 1);
    if (old) {
        int fromrow    = lmt_tointeger(L, 2);
        int fromcolumn = lmt_tointeger(L, 3);
        int nofrows    = lmt_tointeger(L, 4);
        int nofcolumns = lmt_tointeger(L, 5);
        if (fromrow > 0 && fromrow <= old->rows && fromcolumn > 0 && fromcolumn <= old->columns) {
            if (fromrow + nofrows - 1 > old->rows) {
                nofrows = old->rows - fromrow + 1;
            }
            if (fromcolumn + nofcolumns - 1 > old->columns) {
                nofcolumns = old->columns - fromcolumn + 1;
            }
            if (fromrow + nofrows - 1 <= old->rows && fromcolumn + nofcolumns - 1 <= old->columns) {
                zbuffer new = zbufferlib_aux_push(L, nofrows, nofcolumns);
                if (new) {
                    for (int torow = 1; torow <= nofrows; torow++) {
                        zentry o = &(old->data[(fromrow - 1) * old->columns + fromcolumn - 1]);
                        zentry n = &(new->data[(torow   - 1) * new->columns                 ]);
                        memcpy(n, o, nofcolumns * sizeof(zbufferentry));
                        fromrow++;
                    }
                    new->setup.viewport.xmin = 0;
                    new->setup.viewport.ymin = 0;
                    new->setup.viewport.xmax = nofrows - 1;
                    new->setup.viewport.ymax = nofcolumns - 1;
                }
                return 1;
            }
        }
    }
    return 0;
}

/* zbuffer function specification */

typedef enum processmethods {
    process_method_slot    = 0x0001,
    process_method_color   = 0x0002,
    process_method_normal  = 0x0004,
    process_method_texture = 0x0008,
    process_method_skip    = 0x1000,
} processmethods;

# define processidx(zb,idx,skip) ( \
    ! skip \
    || zb->data[idx].red   != zb->setup.viewport.backgroundcolor.r \
    || zb->data[idx].green != zb->setup.viewport.backgroundcolor.g \
    || zb->data[idx].blue  != zb->setup.viewport.backgroundcolor.b \
)

static int zbufferlib_process(lua_State *L)
{
    zbuffer zb = vectorlib_aux_maybe_iszbuffer(L, 1);
    if (zb && lua_type(L, 2) == LUA_TFUNCTION) {
        int method  = lmt_tointeger(L, 3);
        int skip    = method & process_method_skip;
        int slot    = method & process_method_slot;
        int color   = method & process_method_color;
        int normal  = method & process_method_normal;
        int texture = zb->texture ? method & process_method_texture : 0;
        int count  = 0;
        if (slot)    { count += 2; }
        if (color)   { count += 3; }
        if (normal)  { count += 3; }
        if (texture) { count += 4; }
        if (count) {
            int idx = 0;
            for (int r = 0; r < zb->rows; r++) {
                for (int c = 0; c < zb->columns; c++) {
                    if (processidx(zb,idx,skip)) {
                        int top = lua_gettop(L);
                        lua_pushvalue(L, 2);
                        if (slot) {
                            lua_pushinteger(L, r);
                            lua_pushinteger(L, c);
                        }
                        if (color) {
                            lua_pushnumber(L, zb->data[idx].red);
                            lua_pushnumber(L, zb->data[idx].green);
                            lua_pushnumber(L, zb->data[idx].blue);
                        }
                        if (normal) {
                            lua_pushnumber(L, zb->data[idx].nx);
                            lua_pushnumber(L, zb->data[idx].ny);
                            lua_pushnumber(L, zb->data[idx].nz);
                        }
                        if (texture && zb->texture) {
                            lua_pushnumber (L, zb->texture[idx].x);
                            lua_pushnumber (L, zb->texture[idx].y);
                            lua_pushnumber (L, zb->texture[idx].z);
                            lua_pushinteger(L, zb->texture[idx].t);
                        }
                        lua_call(L, count, 3);
                        if (lua_type(L, -3) == LUA_TNUMBER) { zb->data[idx].red   = limited(lua_tonumber(L, -3), 0, 1); }
                        if (lua_type(L, -2) == LUA_TNUMBER) { zb->data[idx].green = limited(lua_tonumber(L, -2), 0, 1); }
                        if (lua_type(L, -1) == LUA_TNUMBER) { zb->data[idx].blue  = limited(lua_tonumber(L, -1), 0, 1); }
                        lua_settop(L, top);
                    }
                    idx++;
                }
            }
        }
        lua_pushboolean(L, count > 0);
        return 1;
    } else {
        return 0;
    }
}

/*tex

    We go from the higher resolution to the lower using a new buffer. We could actulaly in this
    stage drop the old one. We could do this on the bytemap (see that library) but we do want to
    retain precision as well as normals so we just do it here.

*/

static int zbufferlib_resolve(lua_State *L)
{
    zbuffer old = vectorlib_aux_maybe_iszbuffer(L, 1);
    if (old) {
        int factor = lmt_optinteger(L, 2, 1);
        if (factor > 1 && old->columns % factor == 0 && old->rows % factor == 0) {
            int width   = old->columns / factor;
            int height  = old->rows / factor;
            int samples = factor * factor;
            zbuffer new = zbufferlib_aux_push(L, height, width);
            if (new) {
                for (int y = 0; y < height; y++) {
                    for (int x = 0; x < width; x++) {
                        zcolor red     = 0;
                        zcolor green   = 0;
                        zcolor blue    = 0;
                        double depth   = INFINITY;
                        zcolor opacity = 1;
                        double nx      = 0;
                        double ny      = 0;
                        double nz      = 0;
                        int sourcey = y * factor;
                        for (int sy = 1; sy <= factor; sy++) {
                            int sourcex = sourcey * old->columns + x * factor;
                            for (int sx = 1; sx <= factor; sx++) {
                                zentry o = &(old->data[sourcex++]);
                                red   += o->red;
                                green += o->green;
                                blue  += o->blue;
                                nx    += o->nx;
                                ny    += o->ny;
                                nz    += o->nz;
                                if (o->depth < depth) {
                                    depth = o->depth;
                                }
                                if (o->opacity < opacity) {
                                    opacity = o->opacity; /* todo, probably some formula */
                                }
                            }
                            sourcey++;
                        }
                        {
                            zentry n = &(new->data[y * new->columns + x]);
                            n->red     = red   / samples;
                            n->green   = green / samples;
                            n->blue    = blue  / samples;
                            n->depth   = depth;
                            n->opacity = opacity;
                            n->nx      = nx / samples;
                            n->ny      = ny / samples;
                            n->nz      = nz / samples;
                        }
                    }
                };
                new->setup.viewport.xmin = old->setup.viewport.xmin / factor;
                new->setup.viewport.ymin = old->setup.viewport.ymin / factor;
                new->setup.viewport.xmax = old->setup.viewport.xmax / factor;
                new->setup.viewport.ymax = old->setup.viewport.ymax / factor;
                lua_pushinteger(L, height);
                lua_pushinteger(L, width);
                return 3;
            }
        }
    }
    return 0;
}

static int zbufferlib_getsize(lua_State *L)
{
    zbuffer zb = zbufferlib_aux_get(L, 1);
    if (zb) {
        lua_pushinteger(L, zb->rows);
        lua_pushinteger(L, zb->columns);
        return 2;
    }
    return 0;
}

static int zbufferlib_tobytes(lua_State *L)
{
    zbuffer zb = zbufferlib_aux_get(L, 1);
    if (zb && zb->data) {
        size_t size = zb->size * 3;
        unsigned char *bytes = vectorlib_memory_malloc(size + 1);
        if (bytes) {
            size_t k = 0;
            for (int i = 0; i < zb->size; i++) {
                zentry e = &(zb->data[i]);
                bytes[k++] = byteclipped(e->red);
                bytes[k++] = byteclipped(e->green);
                bytes[k++] = byteclipped(e->blue);
            }
            bytes[k] = '\0';
            lua_pushlstring(L, (const char *) bytes, size);
            lua_pushinteger(L, zb->rows);
            lua_pushinteger(L, zb->columns);
            lua_pushinteger(L, 3);
            vectorlib_memory_free(bytes, size + 1);
            return 4;
        }
    }
    return 0;
}

static zentry  zbufferlib_valid_index(lua_State *L)
{
    zbuffer zb = zbufferlib_aux_get(L, 1);
    if (zb && zb->data) {
        int r = lmt_tointeger(L, 2) - 1;
        int c = lmt_tointeger(L, 3) - 1;
        if (r >= 0 && r < zb->rows && c >= 0 && c < zb->columns) {
            return &(zb->data[r * zb->columns + c]);
        }
    }
    return NULL;
}

static int zbufferlib_getvalue(lua_State *L)
{
    zentry e = zbufferlib_valid_index(L);
    if (e) {
# if 1
        if (lua_toboolean(L, 4)) {
            lua_createtable(L, 8, 0);
            lua_pushnumber(L, e->red    ); lua_rawseti(L, -2, 1);
            lua_pushnumber(L, e->green  ); lua_rawseti(L, -2, 2);
            lua_pushnumber(L, e->blue   ); lua_rawseti(L, -2, 3);
            lua_pushnumber(L, e->depth  ); lua_rawseti(L, -2, 4);
            lua_pushnumber(L, e->opacity); lua_rawseti(L, -2, 5);
            lua_pushnumber(L, e->nx     ); lua_rawseti(L, -2, 6);
            lua_pushnumber(L, e->ny     ); lua_rawseti(L, -2, 7);
            lua_pushnumber(L, e->nz     ); lua_rawseti(L, -2, 8);
            return 1;
        } else {
            lua_pushnumber(L, e->red);
            lua_pushnumber(L, e->green);
            lua_pushnumber(L, e->blue);
            lua_pushnumber(L, e->depth);
            lua_pushnumber(L, e->opacity);
            lua_pushnumber(L, e->nx);
            lua_pushnumber(L, e->ny);
            lua_pushnumber(L, e->nz);
            return 8;
        }
# else
        int astable = lua_toboolean(L, 4);
        if (astable) {
            lua_createtable(L, 8, 0);
        }
        lua_pushnumber(L, e->red);
        lua_pushnumber(L, e->green);
        lua_pushnumber(L, e->blue);
        lua_pushnumber(L, e->depth);
        lua_pushnumber(L, e->opacity);
        lua_pushnumber(L, e->nx);
        lua_pushnumber(L, e->ny);
        lua_pushnumber(L, e->nz);
        if (astable) {
            for (int i = 8; i >= 1; i--) {
                lua_rawseti(L, -2, i);
            }
            return 1;
        } else {
            return 8;
        }
# endif
    }
    return 0;
}

static int zbufferlib_setvalue(lua_State *L)
{
    zentry e = zbufferlib_valid_index(L);
    if (e) {
        switch (lua_type(L, 4)) {
            /* compact this */
            case LUA_TNUMBER:
                {
                    if (lua_type(L,  4) == LUA_TNUMBER) { e->red     = lua_tonumber(L,  4); }
                    if (lua_type(L,  5) == LUA_TNUMBER) { e->green   = lua_tonumber(L,  5); }
                    if (lua_type(L,  6) == LUA_TNUMBER) { e->blue    = lua_tonumber(L,  6); }
                    if (lua_type(L,  7) == LUA_TNUMBER) { e->depth   = lua_tonumber(L,  7); }
                    if (lua_type(L,  8) == LUA_TNUMBER) { e->opacity = lua_tonumber(L,  8); }
                    if (lua_type(L,  9) == LUA_TNUMBER) { e->nx      = lua_tonumber(L,  9); }
                    if (lua_type(L, 10) == LUA_TNUMBER) { e->ny      = lua_tonumber(L, 10); }
                    if (lua_type(L, 11) == LUA_TNUMBER) { e->nz      = lua_tonumber(L, 11); }
                    break;
                }
            case LUA_TTABLE:
                {
                    if (lua_rawgeti(L, 4, 1) == LUA_TNUMBER) { e->red     = lua_tonumber(L, -1); } lua_pop(L, 1);
                    if (lua_rawgeti(L, 4, 2) == LUA_TNUMBER) { e->green   = lua_tonumber(L, -1); } lua_pop(L, 1);
                    if (lua_rawgeti(L, 4, 3) == LUA_TNUMBER) { e->blue    = lua_tonumber(L, -1); } lua_pop(L, 1);
                    if (lua_rawgeti(L, 4, 4) == LUA_TNUMBER) { e->depth   = lua_tonumber(L, -1); } lua_pop(L, 1);
                    if (lua_rawgeti(L, 4, 5) == LUA_TNUMBER) { e->opacity = lua_tonumber(L, -1); } lua_pop(L, 1);
                    if (lua_rawgeti(L, 4, 6) == LUA_TNUMBER) { e->nx      = lua_tonumber(L, -1); } lua_pop(L, 1);
                    if (lua_rawgeti(L, 4, 7) == LUA_TNUMBER) { e->ny      = lua_tonumber(L, -1); } lua_pop(L, 1);
                    if (lua_rawgeti(L, 4, 8) == LUA_TNUMBER) { e->nz      = lua_tonumber(L, -1); } lua_pop(L, 1);
                    break;
                }
        }
    }
    return 0;
}

static int zbufferlib_getdepth(lua_State *L)
{
    zentry e = zbufferlib_valid_index(L);
    if (e) {
        lua_pushnumber(L, e->depth);
        return 1;
    } else {
        return 0;
    }
}

static int zbufferlib_setdepth(lua_State *L)
{
    zentry e = zbufferlib_valid_index(L);
    if (e) {
        e->depth = lua_tonumber(L, 4);
    }
    return 0;
}

static int zbufferlib_getopacity(lua_State *L)
{
    zentry e = zbufferlib_valid_index(L);
    if (e) {
        lua_pushnumber(L, e->opacity);
        return 1;
    } else {
        return 0;
    }
}

static int zbufferlib_setopacity(lua_State *L)
{
    zentry e = zbufferlib_valid_index(L);
    if (e) {
        e->opacity = lua_tonumber(L, 4);
    }
    return 0;
}

static int zbufferlib_getnormal(lua_State *L)
{
    zentry e = zbufferlib_valid_index(L);
    if (e) {
        lua_pushnumber(L, e->nx);
        lua_pushnumber(L, e->ny);
        lua_pushnumber(L, e->nz);
        return 3;
    } else {
        return 0;
    }
}

static int zbufferlib_setnormal(lua_State *L)
{
    zentry e = zbufferlib_valid_index(L);
    if (e) {
        e->nx = lua_tonumber(L, 4);
        e->ny = lua_tonumber(L, 5);
        e->nz = lua_tonumber(L, 6);
    }
    return 0;
}

static int zbufferlib_getcolor(lua_State *L)
{
    zentry e = zbufferlib_valid_index(L);
    if (e) {
        lua_pushnumber(L, e->red  );
        lua_pushnumber(L, e->green);
        lua_pushnumber(L, e->blue );
        return 3;
    } else {
        return 0;
    }
}

static int zbufferlib_setcolor(lua_State *L)
{
    zentry e = zbufferlib_valid_index(L);
    if (e) {
        e->red   = lua_tonumber(L, 4);
        e->green = lua_tonumber(L, 5);
        e->blue  = lua_tonumber(L, 6);
    }
    return 0;
}

/*tex

    Here is where the real action takes place: projection. When we create a mesh at the \LUA\ end we
    are not yet projecting. We could do that there and not here because we'r enot in the business of
    processing the same mesh again and again as in for instance games or simulations. But we just
    follow the main stream approach here. Calculation-wise this is the kind of code you can find on
    the internet (wikipedia), in articles and books, and therefore query an \LLM\ for. But be
    prepared to get code that doesn't really work or work for specific cases but it can give some
    insights.

 */

# define project_epsilon   1e-12
# define raster_epsilon    1e-9
# define raster_nepsilon  -1e-9

static inline double edge(double ax, double ay, double bx, double by, double px, double py)
{
    return (px - ax) * (by - ay) - (py - ay) * (bx - ax);
}

static inline int interpolationweights(
    int    perspective,
    double l1,
    double l2,
    double l3,
    double d1,
    double d2,
    double d3,
    double *depth,
    double *w1,
    double *w2,
    double *w3
)
{
    if (perspective) {
        double inv1 = 1.0 / d1;
        double inv2 = 1.0 / d2;
        double inv3 = 1.0 / d3;
        double denominator = l1 * inv1 + l2 * inv2 + l3 * inv3;
        if (fabs(denominator) <= raster_epsilon) {
            *depth = 0;
            *w1    = 0;
            *w2    = 0;
            *w3    = 0;
            return 0;
        } else {
            *depth = 1.0 / denominator;
            *w1    = l1 * inv1 / denominator;
            *w2    = l2 * inv2 / denominator;
            *w3    = l3 * inv3 / denominator;
        }
    } else {
        *depth = l1 * d1 + l2 * d2 + l3 * d3;
        *w1    = l1;
        *w2    = l2;
        *w3    = l3;
    }
    return 1;
}

static int zbufferlib_project(lua_State *L)
{
    zbuffer zb = zbufferlib_aux_get(L, 1);
    if (zb) {
        double x, y, z;
        if (lua_type(L, 2) == LUA_TTABLE) {
            lua_rawgeti(L, 2, 1) ; x = lua_tonumber(L, -1); lua_pop(L, 1);
            lua_rawgeti(L, 2, 2) ; y = lua_tonumber(L, -1); lua_pop(L, 1);
            lua_rawgeti(L, 2, 3) ; z = lua_tonumber(L, -1); lua_pop(L, 1);
        } else {
            x = lua_tonumber(L, 2);
            y = lua_tonumber(L, 3);
            z = lua_tonumber(L, 4);
        }
        double dx = x - zb->setup.projection.eye.x;
        double dy = y - zb->setup.projection.eye.y;
        double dz = z - zb->setup.projection.eye.z;
        double vx = dotproduct(dx, dy, dz, zb->setup.projection.right  .x, zb->setup.projection.right  .y, zb->setup.projection.right  .z);
        double vy = dotproduct(dx, dy, dz, zb->setup.projection.up     .x, zb->setup.projection.up     .y, zb->setup.projection.up     .z);
        double vz = dotproduct(dx, dy, dz, zb->setup.projection.forward.x, zb->setup.projection.forward.y, zb->setup.projection.forward.z);
        int behind = 0;
        double ndcx, ndcy;
        if (zb->setup.perspective) {
            if (vz <= project_epsilon) {
                behind = 1;
            } else {
                double z = vz * zb->setup.camera.tanhalf;
                ndcx = vx / z;
                ndcy = vy / z;
            }
        } else {
            double s = zb->setup.camera.scale;
            ndcx = vx / s;
            ndcy = vy / s;
        }
        if (behind) {
            lua_pushboolean(L, 0);
            lua_pushboolean(L, 1);
            return 2;
        } else {
            double x = zb->setup.transform.x + zb->setup.transform.scale * (ndcx + 1) * zb->setup.viewport.width  / 2;
            double y = zb->setup.transform.y + zb->setup.transform.scale * (1 - ndcy) * zb->setup.viewport.height / 2;
            int visible  = vz >= zb->setup.camera.nearby && vz <= zb->setup.camera.faraway
                && x >= 0 && x <= zb->setup.viewport.width
                && y >= 0 && y <= zb->setup.viewport.height;
            lua_pushboolean(L, visible);
            lua_pushboolean(L, 0);
            lua_pushnumber (L, vx);
            lua_pushnumber (L, vy);
            lua_pushnumber (L, vz);
            lua_pushnumber (L, x);
            lua_pushnumber (L, y);
            return 7;
        }
    } else {
        return 0;
    }
}

static void zbufferproject(zbuffer zb, zbuffervectorn *target)
{
    double ndcx, ndcy;
    double dx = target->x - zb->setup.projection.eye.x;
    double dy = target->y - zb->setup.projection.eye.y;
    double dz = target->z - zb->setup.projection.eye.z;
    target->vx = dotproduct(dx, dy, dz, zb->setup.projection.right  .x, zb->setup.projection.right  .y, zb->setup.projection.right  .z);
    target->vy = dotproduct(dx, dy, dz, zb->setup.projection.up     .x, zb->setup.projection.up     .y, zb->setup.projection.up     .z);
    target->vz = dotproduct(dx, dy, dz, zb->setup.projection.forward.x, zb->setup.projection.forward.y, zb->setup.projection.forward.z);
    target->state &= ~(zbuffer_vector_state_behind | zbuffer_vector_state_visible);
    if (zb->setup.perspective) {
        if (target->vz <= project_epsilon) {
            target->state &= zbuffer_vector_state_behind;
            ndcx = 0;
            ndcy = 0;
        } else {
            double z = target->vz * zb->setup.camera.tanhalf;
            ndcx = target->vx / z;
            ndcy = target->vy / z;
        }
    } else {
        double s = zb->setup.camera.scale;
        ndcx = target->vx / s;
        ndcy = target->vy / s;
    }
    if (! isbehind(target->state)) {
        target->sx = zb->setup.transform.x + zb->setup.transform.scale * (ndcx + 1) * zb->setup.viewport.width  / 2;
        target->sy = zb->setup.transform.y + zb->setup.transform.scale * (1 - ndcy) * zb->setup.viewport.height / 2;
        if (       target->vz >= zb->setup.camera.nearby
                && target->vz <= zb->setup.camera.faraway
                && target->sx >= 0 && target->sx <= zb->setup.viewport.width
                && target->sy >= 0 && target->sy <= zb->setup.viewport.height
            ) {
            target->state &= zbuffer_vector_state_visible;
        }
    } else {
        target->sx = 0;
        target->sy = 0;
    }
}

static inline double transformpoint(zbuffer zb, zbuffervectorn *v)
{
    return dotproduct(
        v->x - zb->setup.projection.eye    .x, v->y - zb->setup.projection.eye    .y, v->z - zb->setup.projection.eye    .z,
               zb->setup.projection.forward.x,        zb->setup.projection.forward.y,        zb->setup.projection.forward.z
    );
}

static zbuffervectorn interpolatevertex(const zbuffervectorn *a, const zbuffervectorn *b, double t)
{
    zbuffervectorn v;
    v.x = a->x + t * (b->x - a->x);
    v.y = a->y + t * (b->y - a->y);
    v.z = a->z + t * (b->z - a->z);
    if (hasnormal(a->state) && hasnormal(b->state)) {
        v.state = zbuffer_vector_state_hasnormal;
        v.nx    = a->nx + t * (b->nx - a->nx);
        v.ny    = a->ny + t * (b->ny - a->ny);
        v.nz    = a->nz + t * (b->nz - a->nz);
        normalize(&v.nx, &v.ny, &v.nz);
    } else if (hasnormal(a->state)) {
        v.state = zbuffer_vector_state_hasnormal;
        v.nx    = a->nx;
        v.ny    = a->ny;
        v.nz    = a->nz;
    } else if (hasnormal(b->state)) {
        v.state = zbuffer_vector_state_hasnormal;
        v.nx    = b->nx;
        v.ny    = b->ny;
        v.nz    = b->nz;
    } else {
        v.state = 0;
        v.nx    = 0;
        v.ny    = 0;
        v.nz    = 0;
    }
    v.sx = 0;
    v.sy = 0;
    v.vx = 0;
    v.vy = 0;
    v.vz = 0;
 // v.padding = 0;
    return v;
}

static inline double inside_near(double depth, double limit) { return depth >= limit - raster_epsilon; }
static inline double inside_far (double depth, double limit) { return depth <= limit + raster_epsilon; }

/* no gain from inline */

static int clipdepth(zbuffer zb, zbuffervectorn *source, zbuffervectorn *target, int n, double limit, int nearby)
{
    int    collected      = 0;
    int    previous       = n - 1;
    double previousdepth  = transformpoint(zb, &(source[previous]));
    double previousinside = nearby ? inside_near(previousdepth, limit) : inside_far(previousdepth, limit);
    for (int current = 0; current < n; current++) {
        double currentdepth  = transformpoint(zb, &(source[current]));
        double currentinside = nearby ? inside_near(currentdepth, limit) : inside_far(currentdepth, limit);
        double denominator   = currentdepth - previousdepth;
        if (currentinside != previousinside && fabs(denominator) > raster_epsilon) {
            double time = limited((limit - previousdepth) / denominator, 0, 1);
            target[collected++] = interpolatevertex(&(source[previous]), &(source[current]), time); /* intersection; */
        }
        if (currentinside) { // != 0
            target[collected++] = source[current]; /* copy */
        }
        previous       = current;
        previousdepth  = currentdepth;
        previousinside = currentinside;
    }
    return collected;
}

/*tex

    Eventually we need to go from an outline to a bitmap and that happens here. We decided to also
    turn straight lines onto bitmaps because for instance over- or underlaying a grid using a line
    in \METAPOST\ just didn't look that good: one ends up with many points and/ior small segments
    which is also pretty inefficient. It makes little sense to do that but it also was one of the
    more challenging parts to solve; we might do better in the future as we already implement
    various methods.

    Here is also where the transparency stack can come into play. At the \LUA\ end we populate the
    zbuffer grid in steps and the order there matters. We can have a background color, put stuff
    in layers and/or on top. Because we already have various bitmap manipulation tricked available
    we also decided to make the final map masked, that is: it can be properly put on top of a
    colored (page) background. It's in the details.

    It is in this stadium that we can also decide to plug in code, so at the \LUA\ end we provide
    mechanisms for that. This is where the artistic applications come into view (Keiths work).

*/

# define initial_transparancy_stack_size 4

static void zbuffertriangle(zbuffer zb, const zbuffervectorn *p1, const zbuffervectorn *p2, const zbuffervectorn *p3, int transparent, double dp)
{
    double area = edge(p1->sx, p1->sy, p2->sx, p2->sy, p3->sx, p3->sy);
    if (fabs(area) > raster_epsilon) {
        /* making this zero based is tricky because of the -0.5 */
        int minx = limited(floor(fmin(p1->sx, fmin(p2->sx, p3->sx))) + 1, 1, zb->columns);
        int maxx = limited(ceil (fmax(p1->sx, fmax(p2->sx, p3->sx))),     1, zb->columns);
        int miny = limited(floor(fmin(p1->sy, fmin(p2->sy, p3->sy))) + 1, 1, zb->rows);
        int maxy = limited(ceil (fmax(p1->sy, fmax(p2->sy, p3->sy))),     1, zb->rows);
        /* seems slower: */
     // int minx = limited(floor(fffmin(p1->sx, p2->sx, p3->sx)) + 1, 1, zb->columns);
     // int maxx = limited(ceil (fffmax(p1->sx, p2->sx, p3->sx)),     1, zb->columns);
     // int miny = limited(floor(fffmin(p1->sy, p2->sy, p3->sy)) + 1, 1, zb->rows);
     // int maxy = limited(ceil (fffmax(p1->sy, p2->sy, p3->sy)),     1, zb->rows);
        for (int py = miny; py <= maxy; py++) {
            double sy = py - 0.5;
            for (int px = minx; px <= maxx; px++) {
                double sx = px - 0.5;
                double l1 = edge(p2->sx, p2->sy, p3->sx, p3->sy, sx, sy) / area;
                double l2 = edge(p3->sx, p3->sy, p1->sx, p1->sy, sx, sy) / area;
                double l3 = edge(p1->sx, p1->sy, p2->sx, p2->sy, sx, sy) / area;
                if (l1 >= raster_nepsilon && l2 >= raster_nepsilon && l3 >= raster_nepsilon) {
                    double depth, w1, w2, w3;
                    int ok = interpolationweights(zb->setup.perspective, l1, l2, l3, p1->vz, p2->vz, p3->vz, &depth, &w1, &w2, &w3);
                    if (ok) {
                        depth += dp;
                        if (depth >= 0) {
                            int n = (py - 1) * zb->columns + (px - 1);
                            if (depth < zb->data[n].depth) {
                                double nx = w1 * p1->nx + w2 * p2->nx + w3 * p3->nx;
                                double ny = w1 * p1->ny + w2 * p2->ny + w3 * p3->ny;
                                double nz = w1 * p1->nz + w2 * p2->nz + w3 * p3->nz;
                                double sum, lambert;
                                normalize(&nx, &ny, &nz);
                                // shade
                                sum = nx * zb->setup.light.normal.x + ny * zb->setup.light.normal.y + nz * zb->setup.light.normal.z;
                                if (zb->setup.material.twosided) {
                                    lambert = sum < 0 ? -sum : sum;
                                } else if (sum < 0) {
                                    lambert = 0;
                                } else {
                                    lambert = sum;
                                }
                                {
                                    double factor = limited(zb->setup.material.ambient + (1.0 - zb->setup.material.ambient) * lambert * zb->setup.light.intensity, 0, 1.0);
                                    zcolor red, green, blue;
                                    double highlight = 0;
                                    if (zb->setup.usespecular) {
                                        double vx, vy, vz, snx, sny, snz;
                                        double ndotv, ndotl, ndoth;
                                        if (zb->setup.perspective) {
                                            double evx = -(w1 * p1->vx + w2 * p2->vx + w3 * p3->vx);
                                            double evy = -(w1 * p1->vy + w2 * p2->vy + w3 * p3->vy);
                                            double evz = -(w1 * p1->vz + w2 * p2->vz + w3 * p3->vz);
                                            vx = evx * zb->setup.projection.right.x + evy * zb->setup.projection.up.x + evz * zb->setup.projection.forward.x;
                                            vy = evx * zb->setup.projection.right.y + evy * zb->setup.projection.up.y + evz * zb->setup.projection.forward.y;
                                            vz = evx * zb->setup.projection.right.z + evy * zb->setup.projection.up.z + evz * zb->setup.projection.forward.z;
                                            normalize(&vx, &vy, &vz);
                                        } else {
                                            vx = zb->setup.projection.ortho.x;
                                            vy = zb->setup.projection.ortho.y;
                                            vz = zb->setup.projection.ortho.z;
                                        }
                                        snx = nx;
                                        sny = ny;
                                        snz = nz;
                                        ndotv = snx * vx + sny * vy + snz * vz;
                                        if (zb->setup.material.twosided && ndotv < 0) {
                                            snx   = -snx;
                                            sny   = -sny;
                                            snz   = -snz;
                                            ndotv = -ndotv;
                                        }
                                        ndotl = snx * zb->setup.light.normal.x + sny * zb->setup.light.normal.y + snz * zb->setup.light.normal.z;
                                        if (ndotv > 0 && ndotl > 0) {
                                            double hx = zb->setup.light.normal.x + vx;
                                            double hy = zb->setup.light.normal.y + vy;
                                            double hz = zb->setup.light.normal.z + vz;
                                            normalize(&hx, &hy, &hz);
                                            ndoth = snx * hx + sny * hy + snz * hz;
                                            if (ndoth > 0) {
                                                highlight = pow(ndoth, zb->setup.material.shininess) * zb->setup.light.intensity;
                                            }
                                        }
                                    }
                                    red   = limited(zb->setup.material.diffuse.r * factor + zb->setup.material.specular.r * highlight, 0, 1);
                                    green = limited(zb->setup.material.diffuse.g * factor + zb->setup.material.specular.g * highlight, 0, 1);
                                    blue  = limited(zb->setup.material.diffuse.b * factor + zb->setup.material.specular.b * highlight, 0, 1);
                                    if (transparent) {
                                        int okay = 0;
                                        int size = zb->stack[n].size;
                                        if (zb->stack[n].last < size) {
                                            okay = 1;
                                        } else if (size < zbuffer_maxnoffragments) {
                                            int newsize = size + initial_transparancy_stack_size;
                                            if (newsize == initial_transparancy_stack_size) {
                                                zb->stack[n].data = vectorlib_memory_malloc(newsize * sizeof(zbufferstackentry));
                                            } else {
                                                zb->stack[n].data = vectorlib_memory_realloc(zb->stack[n].data, size * sizeof(zbufferstackentry), newsize * sizeof(zbufferstackentry));
                                            }
                                            if (zb->stack[n].data) {
                                                zb->stack[n].size = (unsigned short) newsize;
                                                zb->recordbytes += initial_transparancy_stack_size * sizeof(zbufferstackentry);
                                                okay = 1;
                                            } else {
                                                zb->stack[n].size = 0;
                                                zb->stack[n].last = 0;
                                            }
                                        } else {
                                            // We limit the amount! */
                                        }
                                        if (okay) {
                                            /*
                                                We can decide to alloc here and use an array of pointers instead. We can also be smaller.
                                            */
                                            zb->stack[n].data[zb->stack[n].last++] = (zbufferstackentry) {
                                                .red       = red,
                                                .green     = green,
                                                .blue      = blue,
                                                .depth     = depth,
                                                .opacity   = zb->setup.material.opacity,
                                            };
                                            zb->composed = 1;
                                        }
                                    } else {
                                        zb->data[n] = (zbufferentry) {
                                            .red       = red,
                                            .green     = green,
                                            .blue      = blue,
                                            .depth     = depth,
                                            .opacity   = zb->setup.material.opacity,
                                            .nx        = nx,
                                            .ny        = ny,
                                            .nz        = nz,
                                        };
                                    }
                                    /* maybe do this local and update afterwards */
                                    if (zb->setup.viewport.done) {
                                        if (px < zb->setup.viewport.xmin) {
                                            zb->setup.viewport.xmin = px;
                                        }  else if (px > zb->setup.viewport.xmax) {
                                            zb->setup.viewport.xmax = px;
                                        }
                                        if (py < zb->setup.viewport.ymin) {
                                            zb->setup.viewport.ymin = py;
                                        }  else if (py > zb->setup.viewport.ymax) {
                                            zb->setup.viewport.ymax = py;
                                        }
                                    } else {
                                        zb->setup.viewport.xmin = px;
                                        zb->setup.viewport.xmax = px;
                                        zb->setup.viewport.ymin = py;
                                        zb->setup.viewport.ymax = py;
                                        zb->setup.viewport.done = 1;
                                    }
                                }
                                if (zb->texture && zb->setup.material.texture) {
                                    zb->texture[n] = (zbuffertexture) {
                                        .x = (p1->x + p2->x + p3->x) / 3,
                                        .y = (p1->y + p2->y + p3->y) / 3,
                                        .z = (p1->z + p2->z + p3->z) / 3,
                                        .t = zb->setup.material.texture
                                    };
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

static int vectorlib_aux_get_transparent(zbuffer zb)
{
    if (zb->stack) {
        return 1;
    } else {
        zb->stackbytes = zb->size * sizeof(zbufferstack);
        zb->stack = vectorlib_memory_calloc(zb->size, sizeof(zbufferstack));
        if (zb->stack) {
            return 1;
        } else {
            return 0;
        }
    }
}

/*tex

    This is what we came up with regarding drawing lines and segments of lines: separate points
    (coming from overlaps that are out of sequence), continuous segments (from grid lines and axis),
    two-step segments, etc. This s also a bit of a playground and it might evolve over time. In the
    end all points or areas made from neighbouring points become triangles and therefore nicely
    anti-alias.

*/

static int zbufferlib_points(lua_State *L)
{
    zbuffer zb       = zbufferlib_aux_get(L, 1);
    points  vertices = vectorlib_points_aux_get(L, 2);
    if (zb && zb->data && vertices && vertices->data) {
        int method = lmt_tointeger(L, 3);
        int transparent = lua_toboolean(L, 4);
        double dp = zb->setup.material.depth;
        double dx = zb->setup.material.dx * zb->setup.viewport.supersample;
        double dy = zb->setup.material.dy * zb->setup.viewport.supersample;
        if (transparent) {
            transparent = vectorlib_aux_get_transparent(zb);
        }
        if (dx <= 0) { dx = 1; }
        if (dy <= 0) { dy = 1; }
        /* one day we will cast or just have a zbuffervectorn table */
        switch (method) {
            case isolated_points_method:
                {
                    for (int i = 0; i < vertices->size; i++) {
                        zbuffervectorn nxt;
                        memset(&nxt, 0, sizeof(zbuffervectorn)); /* todo */
                        nxt.x = vertices->data[i].x;
                        nxt.y = vertices->data[i].y;
                        nxt.z = vertices->data[i].z;
                        zbufferproject(zb, &nxt);
                        if (! isbehind(nxt.state)) {
                            zbuffervectorn A = nxt; A.sx -= dx; A.sy -= dy;
                            zbuffervectorn B = nxt; B.sx += dx; B.sy -= dy;
                            zbuffervectorn C = nxt; C.sx += dx; C.sy += dy;
                            zbuffervectorn D = nxt; D.sx -= dx; D.sy += dy;
                            zbuffertriangle(zb, &A, &B, &C, transparent, dp);
                            zbuffertriangle(zb, &A, &C, &D, transparent, dp);
                        }
                    }
                }
                break;
            case segment_points_method:
                {
                    int initial = 1;
                    zbuffervectorn cur;
                    memset(&cur, 0, sizeof(zbuffervectorn));
                    for (int i = 0; i < vertices->size; i++) {
                        zbuffervectorn nxt;
                        memset(&nxt, 0, sizeof(zbuffervectorn)); /* todo */
                        nxt.x = vertices->data[i].x;
                        nxt.y = vertices->data[i].y;
                        nxt.z = vertices->data[i].z;
                        zbufferproject(zb, &nxt);
                        if (initial == -1) {
                            initial = 1;
                        } else if (isbehind(nxt.state)) {
                            initial = -1;
                        } else if (initial) {
                            cur = nxt;
                            initial = 0;
                        } else {
                            double tx = nxt.sx - cur.sx;
                            double ty = nxt.sy - cur.sy;
                            double tnorm = sqrt(tx*tx + ty*ty);
                            tx = dy * tx/tnorm;
                            ty = dx * ty/tnorm;
                            {
                                zbuffervectorn A = cur; A.sx -= ty; A.sy += tx;
                                zbuffervectorn B = cur; B.sx += ty; B.sy -= tx;
                                zbuffervectorn C = nxt; C.sx -= ty; C.sy += tx;
                                zbuffervectorn D = nxt; D.sx += ty; D.sy -= tx;
                                zbuffertriangle(zb, &A, &B, &C, transparent, dp);
                                zbuffertriangle(zb, &B, &D, &C, transparent, dp);
                            }
                            initial = 1;
                        }
                    }
                }
                break;
            case connect_points_method:
         // case axis_points_method:
            case stitch_points_method:
            default:
                {
                    int done = 0;
                    int initial = 1;
                    zbuffervectorn A, B;
                    zbuffervectorn cur;
                    memset(&cur, 0, sizeof(zbuffervectorn));
                    for (int i = 0; i < vertices->size; i++) {
                        zbuffervectorn nxt;
                        memset(&nxt, 0, sizeof(zbuffervectorn)); /* todo */
                        nxt.x = vertices->data[i].x;
                        nxt.y = vertices->data[i].y;
                        nxt.z = vertices->data[i].z;
                        zbufferproject(zb, &nxt);
                        if (isbehind(nxt.state)) {
                            initial = 1;
                        } else if (initial) {
                            cur = nxt;
                            initial = 0;
                            done = 0;
                        } else {
                             double tx = nxt.sx - cur.sx;
                             double ty = nxt.sy - cur.sy;
                             double tnorm = sqrt(tx*tx + ty*ty);
                             tx = dy * tx/tnorm;
                             ty = dx * ty/tnorm;
                             if (! done) {
                                 A = cur; A.sx -= ty; A.sy += tx;
                                 B = cur; B.sx += ty; B.sy -= tx;
                                 done = 1;
                             }
                             zbuffervectorn C = nxt; C.sx -= ty; C.sy += tx;
                             zbuffervectorn D = nxt; D.sx += ty; D.sy -= tx;
                             zbuffertriangle(zb, &A, &B, &C, transparent, dp);
                             zbuffertriangle(zb, &B, &D, &C, transparent, dp);
                             A = C;
                             B = D;
                        }
                        cur = nxt;
                     // if (method == axis_points_method && (i % 2) == 1) {
                     //     initial = 1;
                     // }
                    }
                }
                break;
        }
    }
    return 0;
}

static inline void range_of_three(double a, double b, double c, double *min, double *max)
{
 // *min = a < b ? (a < c ? a : ((b < c) ? b : c)) : ((b < c) ? b : c);
 // *max = a > b ? (a > c ? a : ((b > c) ? b : c)) : ((b > c) ? b : c);
    if (a < b) {
      if (a < c) {
          *min = a; *max = b > c ? b : c;
      } else if (b < c) {
          *min = b; *max = c;
      } else {
          *min = c; *max = b;
      }
    } else {
      if (a > c) {
          *max = a; *min = b < c ? b : c;
      } else if (b > c) {
          *max = b; *min = c;
      } else {
          *max = c; *min = b;
      }
    }
}

static int zbufferlib_trianglebounds(lua_State *L)
{
    points vertices  = vectorlib_points_aux_get(L, 1);
    mesh   triangles = vectorlib_mesh_aux_get(L, 2);
    if (vertices && triangles) {
        int index = lmt_tointeger(L, 3) - 1;
        int t[3];
        if (vectorlib_mesh_aux_get_points_okay(triangles, vertices, index, t)) {
            int astable = lua_toboolean(L, 4);
            double xmin, xmax, ymin, ymax, zmin, zmax;
            range_of_three(vertices->data[t[0]].x, vertices->data[t[1]].x, vertices->data[t[2]].x, &xmin, &xmax);
            range_of_three(vertices->data[t[0]].y, vertices->data[t[1]].y, vertices->data[t[2]].y, &ymin, &ymax);
            range_of_three(vertices->data[t[0]].z, vertices->data[t[1]].z, vertices->data[t[2]].z, &zmin, &zmax);
            if (astable) {
                lua_createtable(L, 0, 6);
            }
            lua_pushnumber(L, xmin);
            lua_pushnumber(L, xmax);
            lua_pushnumber(L, ymin);
            lua_pushnumber(L, ymax);
            lua_pushnumber(L, zmin);
            lua_pushnumber(L, zmax);
            if (astable) {
                lua_setfield(L, -7, "zmax"); /* we can use the fast method */
                lua_setfield(L, -6, "zmin");
                lua_setfield(L, -5, "ymax");
                lua_setfield(L, -4, "ymin");
                lua_setfield(L, -3, "xmax");
                lua_setfield(L, -2, "xmin");
                return 1;
            } else {
                return 6;
            }
        }
    }
    return 0;
}

static int zbufferlib_triangles(lua_State *L)
{
    zbuffer zb        = zbufferlib_aux_get(L, 1);
    points  vertices  = vectorlib_points_aux_get(L, 2);
    mesh    triangles = vectorlib_mesh_aux_get(L, 3);
    if (zb && zb->data && vertices && triangles) {
        switch (triangles->type) {
            case triangle_mesh_type:
            case triangle_5_mesh_type:
            case triangle_6_mesh_type:
            case triangle_7_mesh_type:
                {
                    /* 2 = vertices  3 = triangles  4 = transparent */
                    int noftriangles = triangles->size;
                    int transparent  = lua_toboolean(L, 4);
                    if (transparent) {
                        transparent = vectorlib_aux_get_transparent(zb);
                    }
                    for (int i = 0; i < noftriangles; i++) {
                        int t[3];
                        if (vectorlib_mesh_aux_get_points_okay(triangles, vertices, i, t)) {
                            zbuffervectorn first [12];
                            zbuffervectorn second[12];
                            int n = 3;
                            point pa = &(vertices->data[t[0]]);
                            point pb = &(vertices->data[t[1]]);
                            point pc = &(vertices->data[t[2]]);
                            first[0] = (zbuffervectorn) {
                                .x  = pa->x, .y = pa->y, .z = pa->z, .nx = pa->nx, .ny = pa->ny, .nz = pa->nz,
                                .sx = 0, .sy = 0, .vx = 0, .vy = 0, .vz = 0, .state = zbuffer_vector_state_hasnormal,
                            };
                            first[1] = (zbuffervectorn) {
                                .x  = pb->x, .y = pb->y, .z = pb->z, .nx = pb->nx, .ny = pb->ny, .nz = pb->nz,
                                .sx = 0, .sy = 0, .vx = 0, .vy = 0, .vz = 0, .state = zbuffer_vector_state_hasnormal,
                            };
                            first[2] = (zbuffervectorn) {
                                .x  = pc->x, .y = pc->y, .z = pc->z, .nx = pc->nx, .ny = pc->ny, .nz = pc->nz,
                                .sx = 0, .sy = 0, .vx = 0, .vy = 0, .vz = 0, .state = zbuffer_vector_state_hasnormal,
                            };
                            n = clipdepth(zb, &first[0], &second[0], n, zb->setup.camera.nearby, 1);
                            if (n >= 3) {
                                n = clipdepth(zb, &second[0], &first[0], n, zb->setup.camera.faraway, 0);
                                if (n >= 3) {
                                    for (int i = 0; i < n; i++) {
                                        zbufferproject(zb, &first[i]);
                                    }
                                    if (! isbehind(first[0].state)) {
                                     // for (int i = 2; i <= n - 1; i++) {
                                     //     if (! isbehind(first[i-1].state) && ! isbehind(first[i].state)) {
                                     //         zbuffertriangle(zb, &first[0], &first[i-1], &first[i], transparent, 0);
                                     //     }
                                     // }
                                        for (int i = 1; i < n - 1; i++) {
                                            if (! isbehind(first[i].state) && ! isbehind(first[i+1].state)) {
                                                zbuffertriangle(zb, &first[0], &first[i], &first[i+1], transparent, 0);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    break;
                }
        }
    }
    return 0;
}

/*tex

    Although this can also be done in \LUA, we dicided to optimize this. Amonmg the reasons is that
    we implement virtual meshes after we realized that it made no sens to have lists if triangles
    that form a pattern: at the price if more calculations we safe memory and still end up faster,
    so we all gain.

*/

static int zbufferlib_flatten(lua_State *L)
{
    points vertices  = vectorlib_points_aux_get(L, 1);
    mesh   triangles = vectorlib_mesh_aux_get(L, 2);
    if (vertices && triangles) {
        switch (triangles->type) {
            case triangle_mesh_type:
            case triangle_5_mesh_type:
            case triangle_6_mesh_type:
            case triangle_7_mesh_type:
                {
                    int noftriangles = triangles->size;
                    points v = vectorlib_points_aux_push(L, noftriangles * 3, 1, 0);
                    if (v) {
                        int vi = 0;
                        for (int i = 0; i < noftriangles; i++) {
                            int t[3];
                            if (vectorlib_mesh_aux_get_points_okay(triangles, vertices, i, t)) {
                                double abx = vertices->data[t[1]].x - vertices->data[t[0]].x;
                                double aby = vertices->data[t[1]].y - vertices->data[t[0]].y;
                                double abz = vertices->data[t[1]].z - vertices->data[t[0]].z;
                                double acx = vertices->data[t[2]].x - vertices->data[t[0]].x;
                                double acy = vertices->data[t[2]].y - vertices->data[t[0]].y;
                                double acz = vertices->data[t[2]].z - vertices->data[t[0]].z;
                                double nx  = aby * acz - abz * acy;
                                double ny  = abz * acx - abx * acz;
                                double nz  = abx * acy - aby * acx;
                                v->data[vi++] = (pointdata) { .x = vertices->data[t[0]].x, .y = vertices->data[t[0]].y, .z = vertices->data[t[0]].z, .nx = nx, .ny = ny, .nz = nz }; // , .u = 0, .v = 0 };
                                v->data[vi++] = (pointdata) { .x = vertices->data[t[1]].x, .y = vertices->data[t[1]].y, .z = vertices->data[t[1]].z, .nx = nx, .ny = ny, .nz = nz }; // , .u = 0, .v = 0 };
                                v->data[vi++] = (pointdata) { .x = vertices->data[t[2]].x, .y = vertices->data[t[2]].y, .z = vertices->data[t[2]].z, .nx = nx, .ny = ny, .nz = nz }; // , .u = 0, .v = 0 };
                            } else {
                                v->data[vi++] = (pointdata) { .x = 0, .y = 0, .z = 0, .nx = 0, .ny = 0, .nz = 0 }; // , .u = 0, .v = 0 };
                                v->data[vi++] = (pointdata) { .x = 0, .y = 0, .z = 0, .nx = 0, .ny = 0, .nz = 0 }; // , .u = 0, .v = 0 };
                                v->data[vi++] = (pointdata) { .x = 0, .y = 0, .z = 0, .nx = 0, .ny = 0, .nz = 0 }; // , .u = 0, .v = 0 };
                            }
                        }
                        return 1 + vectorlib_contour_aux_makemesh(L, noftriangles, 1, triangle_5_mesh_type);
                    } else {
                        break;
                    }
                }
        }
    }
    return 0;
}

/*
    The same reasoning applies to smoothing, athough here the gain is larger due to the amount of
    access and calculations. On a regular run the overhead is close to zero.

*/

static int zbufferlib_smoothen(lua_State *L)
{
    points vertices = vectorlib_points_aux_get(L, 1);
    if (vertices && vertices->data) {
        int nv = lmt_tointeger(L, 2);
        int nu = lmt_tointeger(L, 3);
        if (nv * nu == vertices->size) {
            points v = vectorlib_points_aux_push(L, nu, nv, 0);
            if (v) {
                memcpy(v->data, vertices->data, nu * nv * sizeof(pointdata));
                for (int j = 1; j <= nv; j++) {
                    int jm   = j > 1  ? j - 1 : j;
                    int jp   = j < nv ? j + 1 : j;
                    int jnu  = (j  - 1) * nu;
                    int jmnu = (jm - 1) * nu;
                    int jpnu = (jp - 1) * nu;
                    for (int i = 1; i <= nu; i++) {
                        int im    = i > 1  ? i - 1 : i;
                        int ip    = i < nu ? i + 1 : i;
                        int c     = jnu  +  i - 1;
                        int uprev = jnu  + im - 1;
                        int unext = jnu  + ip - 1;
                        int vnext = jmnu + ip - 1;
                        int vprev = jpnu + ip - 1;
                        double ux = v->data[unext].x - v->data[uprev].x;
                        double uy = v->data[unext].y - v->data[uprev].y;
                        double uz = v->data[unext].z - v->data[uprev].z;
                        double vx = v->data[vnext].x - v->data[vprev].x;
                        double vy = v->data[vnext].y - v->data[vprev].y;
                        double vz = v->data[vnext].z - v->data[vprev].z;
                        // We are negatively oriented, so normal becomes -(u' x v').
                        v->data[c].nx = -(uy * vz - uz * vy);
                        v->data[c].ny = -(uz * vx - ux * vz);
                        v->data[c].nz = -(ux * vy - uy * vx);
                        normalize(&(v->data[c].nx), &(v->data[c].ny), &(v->data[c].nz));
                    }
                }
                return 1;
            }
        }
    }
    return 0;
}

static int comparedepth(const void *a, const void *b)
{
    double da = ((const zbufferstackentry *) a)->depth;
    double db = ((const zbufferstackentry *) b)->depth;
    if (da > db) {
        return -1;
    } else if (da < db) {
        return 1;
    } else {
        return 0;
    }
}

/*tex

    Here the transparent stack (layers) get combined with the main layer that either or not has
    its own content and optionally a background color set. Cleaning up the stack happens here
    just because we're in the right spot of doing that.

*/

static int zbufferlib_composite(lua_State *L)
{
    zbuffer zb = zbufferlib_aux_get(L, 1);
    if (zb && zb->data && zb->stack && zb->composed) {
        double tolerance = lmt_optdouble(L, 2, 1e6);
        int maxfragmentused = 0;
        for (int y = 0; y < zb->rows; y++) {
            for (int x = 0; x < zb->columns; x++) {
                int n = y * zb->columns + x;
                if (zb->stack[n].data) {
                    int noffragments = zb->stack[n].last;
                    if (noffragments > maxfragmentused) {
                        maxfragmentused = noffragments;
                    }
                    if (noffragments == 1) {
                        zcolor o = zb->stack[n].data[0].opacity;
                        zb->data[n].red   = zb->stack[n].data[0].red   * o + zb->data[n].red   * (1.0 - o);
                        zb->data[n].green = zb->stack[n].data[0].green * o + zb->data[n].green * (1.0 - o);
                        zb->data[n].blue  = zb->stack[n].data[0].blue  * o + zb->data[n].blue  * (1.0 - o);
                    } else {
                        zcolor r = zb->data[n].red;
                        zcolor g = zb->data[n].green;
                        zcolor b = zb->data[n].blue;
                        int i = 0;
                        qsort(&(zb->stack[n].data[0]), noffragments, sizeof(zbufferstackentry), &comparedepth);
                        while (i < noffragments) {
                            int j = i;
                            double depth = zb->stack[n].data[i].depth;
                            while (j < noffragments - 1 && fabs(zb->stack[n].data[j + 1].depth - depth) <= tolerance) {
                                j++;
                            }
                            {
                                double weight       = 0;
                                zcolor red          = 0;
                                zcolor green        = 0;
                                zcolor blue         = 0;
                                zcolor opacity      = 0;
                                zcolor transparency = 1;
                                for (int k = i; k <= j; k++) {
                                    opacity      = limited(zb->stack[n].data[k].opacity, 0, 1);
                                    transparency = transparency * (1 - opacity);
                                    weight       = weight + opacity;
                                    red          = red    + zb->stack[n].data[k].red   * opacity;
                                    green        = green  + zb->stack[n].data[k].green * opacity;
                                    blue         = blue   + zb->stack[n].data[k].blue  * opacity;
                                }
                                opacity = 1 - transparency;
                                if (weight > raster_epsilon) {
                                    opacity = opacity / weight;
                                }
                                r = red   * opacity + r * transparency;
                                g = green * opacity + g * transparency;
                                b = blue  * opacity + b * transparency;
                            }
                            i = j + 1;
                        }
                        zb->data[n].red   = r;
                        zb->data[n].green = g;
                        zb->data[n].blue  = b;
                        zb->data[n].depth = INFINITY;
                    }
                    {
                        size_t bytes = zb->stack[n].size * sizeof(zbufferstackentry);
                        vectorlib_memory_free(zb->stack[n].data, bytes);
                        zb->recordbytes -= bytes;
                        zb->stack[n].data = NULL;
                    }
                }
            }
        }
        zb->composed = 0;
        lua_pushinteger(L, maxfragmentused);
        return 1;
    } else {
        return 0;
    }
}

static int zbufferlib_bounds(lua_State *L)
{
    zbuffer zb = zbufferlib_aux_get(L, 1);
    if (zb) {
        /* todo: check the + 1 */
        lua_pushinteger(L, zb->setup.viewport.xmin + 1);
        lua_pushinteger(L, zb->setup.viewport.xmax + 1);
        lua_pushinteger(L, zb->setup.viewport.ymin + 1);
        lua_pushinteger(L, zb->setup.viewport.ymax + 1);
        return 4;
    } else {
        return 0;
    }
}

static int zbufferlib_transform(lua_State *L)
{
    zbuffer zb = zbufferlib_aux_get(L, 1);
    if (zb) {
        double dx, dy, dz;
        switch (lua_type(L, 2)) {
            case LUA_TTABLE:
                {
                    lua_rawgeti(L, 2, 1); dx = lua_tonumber(L, -1) - zb->setup.projection.eye.x; lua_pop(L, 1);
                    lua_rawgeti(L, 2, 2); dy = lua_tonumber(L, -1) - zb->setup.projection.eye.y; lua_pop(L, 1);
                    lua_rawgeti(L, 2, 3); dz = lua_tonumber(L, -1) - zb->setup.projection.eye.z; lua_pop(L, 1);
                    break;
                }
            case LUA_TUSERDATA:
                {
                    points vertices = vectorlib_points_aux_get(L, 2);
                    if (vertices && vertices->data) {
                        int index = lmt_tointeger(L, 3) - 1;
                        if (index >= 0 && index < vertices->size) {
                            dx = vertices->data[index].x - zb->setup.projection.eye.x;
                            dy = vertices->data[index].y - zb->setup.projection.eye.y;
                            dz = vertices->data[index].z - zb->setup.projection.eye.z;
                            break;
                        }
                    }
                    return 0;
                }
            default:
                return 0;
        }
        lua_createtable(L, 3, 0);
        lua_pushnumber(L, dx * zb->setup.projection.right  .x + dy * zb->setup.projection.right  .y + dz * zb->setup.projection.right  .z); lua_rawseti(L, -2, 1);
        lua_pushnumber(L, dx * zb->setup.projection.up     .x + dy * zb->setup.projection.up     .y + dz * zb->setup.projection.up     .z); lua_rawseti(L, -2, 2);
        lua_pushnumber(L, dx * zb->setup.projection.forward.x + dy * zb->setup.projection.forward.y + dz * zb->setup.projection.forward.z); lua_rawseti(L, -2, 3);
        return 1;
    }
    return 0;
}

/*tex

    \subject{Implicit meshing}

    This was part of our \LUAMETAFUN\ 3D pet project. See \type {drawinglines-ai.pdf} for how we
    ended up here. As usual it evolved stepwise and we will improve on it. In \LUAMETAFUN\ we already
    had vector based meshes for a while (search for \quote {contour} and \quote {vector} in the
    documentation) but generating bitmap is more reliable for self-intersecting surfaces. We handle
    parametric, implicit, plane and curves plots and the implicit one is the most time consuming so
    that one moved to \CCODE. That also mean that we had to do somewhat efficient calls to \LUA\ from
    \CCODE\ on demand because users define functions in \LUA. This comes at a price but the tetra
    approach is more demanding in the end so we still gain a bit.

    The implicit meshing code below is inspired by solutions we queried Chat but we had to do quite a
    bit of coding ourselves in the end. So, we might as well have started from literature and save us
    some time, although articles often stay abstract and not show real solutions. It makes little sense
    to use code derived from whatever other language without close inspection, rewrite, unsloppyfying
    and what more but at least one can see the principles involved, ask for explanation (with references
    to literature) and start from that. In some other modules we actually started from published source
    code (like perlin noise) and although that also demands a rewrite, it's a much more convenient
    approach, especially because we have to plug in various features.

*/

# define epsilon  1e-12
# define epsilon2 (epsilon * epsilon)

typedef enum normalmodes {
    normal_smooth = 0x0,
    normal_flat   = 0x1,
    normal_up     = 0x2,
} normalmodes;

typedef struct tetra {
    double x;
    double y;
    double z;
    double v;
} tetra ;

static void addtriangle(lua_State *L, const points vertices, int mode, pointdata a, pointdata b, pointdata c)
{
    double abx  = b.x - a.x;
    double aby  = b.y - a.y;
    double abz  = b.z - a.z;
    double acx  = c.x - a.x;
    double acy  = c.y - a.y;
    double acz  = c.z - a.z;
    double nx   = aby * acz - abz * acy;
    double ny   = abz * acx - abx * acz;
    double nz   = abx * acy - aby * acx;
    double area = nx * nx + ny * ny + nz * nz;
    if (area > epsilon2) {
        switch (mode) {
            case normal_smooth:
                break;
            case normal_flat:
                {
                    double nx = a.nx + b.nx + c.nx;
                    double ny = a.ny + b.ny + c.ny;
                    double nz = a.nz + b.nz + c.nz;
                    normalize(&nx, &ny, &nz);
                    a.nx = nx ; a.ny = ny ; a.nz = nz;
                    b.nx = nx ; b.ny = ny ; b.nz = nz;
                    c.nx = nx ; c.ny = ny ; c.nz = nz;
                }
                break;
            case normal_up:
                a.nx = 0 ; a.ny = 0 ; a.nz = 1;
                b.nx = 0 ; b.ny = 0 ; b.nz = 1;
                c.nx = 0 ; c.ny = 0 ; c.nz = 1;
                break;
        }
       RETRY:
        if (vertices->index + 2 < vertices->size) {
            vertices->data[vertices->index++] = a;
            vertices->data[vertices->index++] = b;
            vertices->data[vertices->index++] = c;
        } else if (vectorlib_points_aux_grow(L, vertices, 1024)) {
            goto RETRY;
        } else {
            /* we should just exit */
            printf(">>> implicit points overflow %i\n", vertices->index);
        }
    }
}

//static inline double call_fp(lua_State *L, int slot, double x, double y, double z)
static inline double call_fp(lua_State *L, int slot, tetra *t)
{
    double d;
    int top = lua_gettop(L);
    lua_pushvalue(L, slot);
    lua_pushnumber(L, t->x);
    lua_pushnumber(L, t->y);
    lua_pushnumber(L, t->z);
    lua_call(L, 3, 1);
    d = lua_tonumber(L, -1);
    lua_settop(L, top);
    return d;
}

static inline void call_fn(lua_State *L, int slot, double x, double y, double z, double step, double *nx, double *ny, double *nz)
{
    int top = lua_gettop(L);
    lua_pushvalue(L, slot);
    lua_pushnumber(L, x);
    lua_pushnumber(L, y);
    lua_pushnumber(L, z);
    lua_pushnumber(L, step);
    lua_call(L, 4, 3);
 // if (lua_pcall(L, 4, 3, 0) != 0) {
 //     tex_formatted_warning("zbuffer", "run: %s", lua_tostring(L, -1));
 // } else {
    *nx = lua_tonumber(L, -3);
    *ny = lua_tonumber(L, -2);
    *nz = lua_tonumber(L, -1);
 // }
    lua_settop(L, top);
}

static pointdata pointat(lua_State *L, const tetra *a, const tetra *b, double iso, int fn, double step) {
    pointdata p;
    double denominator = b->v - a->v;
    double t;
    if (fabs(denominator) <= epsilon) {
        t = 0.5;
    } else {
        t = (iso - a->v) / denominator;
        if (t < 0) {
            t = 0;
        } else if (t > 1) {
            t = 1;
        }
    }
    p.x = a->x + t * (b->x - a->x);
    p.y = a->y + t * (b->y - a->y);
    p.z = a->z + t * (b->z - a->z);
    // gradient
    if (fn) {
        call_fn(L, fn, p.x, p.y, p.z, step, &p.nx, &p.ny, &p.nz);
        normalize(&p.nx, &p.ny, &p.nz);
    } else {
        p.nx = 0;
        p.ny = 0;
        p.nz = 1;
    }
 // p.u = 0;
 // p.v = 0;
    return p;
}

static void polygonizetetra(lua_State *L, points vertices, int mode, const tetra *c1, const tetra *c2, const tetra *c3, const tetra *c4, double iso, int fn, double step)
{
    int ins = 0;
    int out = 0;
    const tetra *inside [4];
    const tetra *outside[4];
    if (c1->v <= iso) { inside[ins++] = c1; } else { outside[out++] = c1; }
    if (c2->v <= iso) { inside[ins++] = c2; } else { outside[out++] = c2; }
    if (c3->v <= iso) { inside[ins++] = c3; } else { outside[out++] = c3; }
    if (c4->v <= iso) { inside[ins++] = c4; } else { outside[out++] = c4; }
    switch (ins) {
        case 1:
            {
                pointdata p1 = pointat(L, inside[0], outside[0], iso, fn, step);
                pointdata p2 = pointat(L, inside[0], outside[1], iso, fn, step);
                pointdata p3 = pointat(L, inside[0], outside[2], iso, fn, step);
                addtriangle(L, vertices, mode, p1, p2, p3);
                break;
            }
        case 2:
            {
                pointdata p1 = pointat(L, inside[0], outside[0], iso, fn, step);
                pointdata p2 = pointat(L, inside[0], outside[1], iso, fn, step);
                pointdata p3 = pointat(L, inside[1], outside[1], iso, fn, step);
                pointdata p4 = pointat(L, inside[1], outside[0], iso, fn, step);
                addtriangle(L, vertices, mode, p1, p2, p3);
                addtriangle(L, vertices, mode, p1, p3, p4);
                break;
            }
        case 3:
            {
                pointdata p1 = pointat(L, outside[0], inside[0], iso, fn, step);
                pointdata p2 = pointat(L, outside[0], inside[2], iso, fn, step);
                pointdata p3 = pointat(L, outside[0], inside[1], iso, fn, step);
                addtriangle(L, vertices, mode, p1, p2, p3);
                break;
            }
    }
}

// static void polygonizecube(lua_State *L, points vertices, int mode, const tetra *c, double iso, int fn, double step)
// {
//     polygonizetetra(L, vertices, mode, &c[0], &c[1], &c[2], &c[6], iso, fn, step);
//     polygonizetetra(L, vertices, mode, &c[0], &c[2], &c[3], &c[6], iso, fn, step);
//     polygonizetetra(L, vertices, mode, &c[0], &c[3], &c[7], &c[6], iso, fn, step);
//     polygonizetetra(L, vertices, mode, &c[0], &c[7], &c[4], &c[6], iso, fn, step);
//     polygonizetetra(L, vertices, mode, &c[0], &c[4], &c[5], &c[6], iso, fn, step);
//     polygonizetetra(L, vertices, mode, &c[0], &c[5], &c[1], &c[6], iso, fn, step);
// }

/*
    This is faster because now polygonizetetra gets inlined and we benefit from caching. Two values
    are constant so we hard-code those.
*/

const unsigned tetras[6][2] = {
    { 1, 2 }, { 2, 3 }, { 3, 7 },
    { 7, 4 }, { 4, 5 }, { 5, 1 },
};

static void polygonizecube(lua_State *L, points vertices, int mode, const tetra *c, double iso, int fn, double step)
{
    for (unsigned i = 0; i < 6; i++) {
        /* we could move the code here but the copiler will do that anyway */
        polygonizetetra(L, vertices, mode, &c[0], &c[tetras[i][0]], &c[tetras[i][1]], &c[6], iso, fn, step);
    }
}

static inline void sample(lua_State *L, tetra *t, double xmin, double ymin, double zmin, double dx, double dy, double dz, int fp, int i, int j, int k)
{
    t->x = xmin + i * dx;
    t->y = ymin + j * dy;
    t->z = zmin + k * dz;
 // t->v = call_fp(L, fp, t->x, t->y, t->z);
    t->v = call_fp(L, fp, t);
}

static int zbufferlib_implicit(lua_State *L)
{
    if (lua_type(L, 1) == LUA_TTABLE) {
        int nx, ny, nz;
        lua_getfield(L, 1, "nx"); nx = lmt_tointeger(L, -1); lua_pop(L, 1);
        lua_getfield(L, 1, "ny"); ny = lmt_tointeger(L, -1); lua_pop(L, 1);
        lua_getfield(L, 1, "nz"); nz = lmt_tointeger(L, -1); lua_pop(L, 1);
        if (nx > 1 && ny > 1 && nz > 1) {
            points vertices = vectorlib_points_aux_push(L, nx * ny * nz * 3, 1, 1);
            if (vertices) {
                double xmin, xmax, ymin, ymax, zmin, zmax, iso, step, dx, dy, dz;
                int mode, fp, fn;
                lua_getfield(L, 1, "xmin");        xmin = lua_tonumber (L, -1); lua_pop(L, 1);
                lua_getfield(L, 1, "xmax");        xmax = lua_tonumber (L, -1); lua_pop(L, 1);
                lua_getfield(L, 1, "ymin");        ymin = lua_tonumber (L, -1); lua_pop(L, 1);
                lua_getfield(L, 1, "ymax");        ymax = lua_tonumber (L, -1); lua_pop(L, 1);
                lua_getfield(L, 1, "zmin");        zmin = lua_tonumber (L, -1); lua_pop(L, 1);
                lua_getfield(L, 1, "zmax");        zmax = lua_tonumber (L, -1); lua_pop(L, 1);
                lua_getfield(L, 1, "iso");         iso  = lua_tonumber (L, -1); lua_pop(L, 1);
                lua_getfield(L, 1, "normalstep");  step = lua_tonumber (L, -1); lua_pop(L, 1);
                lua_getfield(L, 1, "normalmode");  mode = lmt_tointeger(L, -1); lua_pop(L, 1);
                lua_getfield(L, 1, "fp");          fp   = lua_type(L, -1) == LUA_TFUNCTION ? lua_absindex(L, -1) : 0;
                lua_getfield(L, 1, "fn");          fn   = lua_type(L, -1) == LUA_TFUNCTION ? lua_absindex(L, -1) : 0;
             // lua_getfield(L, 1, "fp");          fp   = lua_type(L, -1) == LUA_TFUNCTION ? 3 : 0;
             // lua_getfield(L, 1, "fn");          fn   = lua_type(L, -1) == LUA_TFUNCTION ? 4 : 0;
                dx = (xmax - xmin) / (nx - 1); /* why -1 */
                dy = (ymax - ymin) / (ny - 1);
                dz = (zmax - zmin) / (nz - 1);
                if (fp == 0) {
                 // lua_pop(L, 2);
                    return 0;
                }
                if (fn == 0) {
                    /* maybe issue a warning */
                }
                if (step == 0) {
                    step = fmin(dx, fmin(dy, dz)) * 0.5;
                }
                for (int k = 0; k < nz - 1; k++) {
                    int k1 = k + 1;
                    for (int j = 0; j < ny - 1; j++) {
                        int j1 = j + 1;
                        for (int i = 0; i < nx - 1; i++) {
                            int i1 = i + 1;
                            tetra c[8];
                            sample(L, &c[0], xmin, ymin, zmin, dx, dy, dz, fp, i , j , k );
                            sample(L, &c[1], xmin, ymin, zmin, dx, dy, dz, fp, i1, j , k );
                            sample(L, &c[2], xmin, ymin, zmin, dx, dy, dz, fp, i1, j1, k );
                            sample(L, &c[3], xmin, ymin, zmin, dx, dy, dz, fp, i , j1, k );
                            sample(L, &c[4], xmin, ymin, zmin, dx, dy, dz, fp, i , j , k1);
                            sample(L, &c[5], xmin, ymin, zmin, dx, dy, dz, fp, i1, j , k1);
                            sample(L, &c[6], xmin, ymin, zmin, dx, dy, dz, fp, i1, j1, k1);
                            sample(L, &c[7], xmin, ymin, zmin, dx, dy, dz, fp, i , j1, k1);
                            polygonizecube(L, vertices, mode, c, iso, fn, step);
                        }
                    }
                }
                vertices->size = vertices->index;
                lua_pop(L, 2); /* the functions */
                return 1;
            }
        }
    }
    return 0;
}

/*tex

    So here ends the implicit helper and we move on to the also complex overlap detection mechanism,
    where we consult triangles. For now we only do the mesh-mesh overlap analyzer in \CCODE, but we
    migh decide to do more here. Again we could ask for the general approach and a \LUA\ prototype
    but we had to come up wiht more efficient (and accurate) solution in the end because we didn't
    want to use some cumbersome mix of bitmap and overlayed points (think \METAPOST\ drawdots) that
    was suggested; it made no sense and looked bad. So below we see overlap detection mixed with
    triangle generation.

*/

const int partialmap[3][2] = { { 0, 1 }, { 1, 2 }, { 2, 0 } };

static void mesh_addoverlappingpoint(const points vertices, int first[3], int m, const points pvertices, int second[3], points result, double tolerance)
{
    point pa  = &(vertices ->data[first[partialmap[m][0]]]);
    point pb  = &(vertices ->data[first[partialmap[m][1]]]);
    point pp0 = &(pvertices->data[second[0]]);
    point pp1 = &(pvertices->data[second[1]]);
    point pp2 = &(pvertices->data[second[2]]);
    double dx  = pb->x - pa->x;
    double dy  = pb->y - pa->y;
    double dz  = pb->z - pa->z;
    double e1x = pp1->x - pp0->x;
    double e1y = pp1->y - pp0->y;
    double e1z = pp1->z - pp0->z;
    double e2x = pp2->x - pp0->x;
    double e2y = pp2->y - pp0->y;
    double e2z = pp2->z - pp0->z;
    double hx = dy * e2z - dz * e2y;
    double hy = dz * e2x - dx * e2z;
    double hz = dx * e2y - dy * e2x;
    double determinant = dotproduct(e1x, e1y, e1z, hx, hy, hz);
    if (fabs(determinant) <= tolerance) {
        return;
    } else {
        double inverse = 1 / determinant;
        double sx = pa->x - pp0->x;
        double sy = pa->y - pp0->y;
        double sz = pa->z - pp0->z;
        double u = inverse * dotproduct(sx, sy, sz, hx, hy, hz);
        if (u < -tolerance || u > 1 + tolerance) {
            return;
        } else {
            double qx = sy * e1z - sz * e1y;
            double qy = sz * e1x - sx * e1z;
            double qz = sx * e1y - sy * e1x;
            double v = inverse * dotproduct(dx, dy, dz, qx, qy, qz);
            if (v < -tolerance || u + v > 1 + tolerance) {
                return;
            } else {
                double x, y, z;
                double t = inverse * dotproduct(e2x, e2y, e2z, qx, qy, qz);
                if (t < -tolerance || t > 1 + tolerance) {
                    return;
                } else if (t < 0) {
                    t = 0;
                } else if (t > 1) {
                    t = 1;
                }
                x = pa->x + t * (pb->x - pa->x);
                y = pa->y + t * (pb->y - pa->y);
                z = pa->z + t * (pb->z - pa->z);
                for (int i = 0; i < result->index; i++) {
                    if (fabs(result->data[i].x - x) <= tolerance && fabs(result->data[i].y - y) <= tolerance && fabs(result->data[i].z - z) <= tolerance) {
                        return;
                    }
                }
                if (result->index < result->size) {
                    result->data[result->index].x = x;
                    result->data[result->index].y = y;
                    result->data[result->index].z = z;
                    result->index++;
                } else {
                    printf(">>> mesh mesh result overflow %i\n",result->index); /* todo: grow */
                }
            }
        }
    }
}

// static int mesh_axiscellcount(int count, double extent, int dimensions)
// {
//     if (extent <= 0) {
//         return 1;
//     } else {
//         int cells = ceil(pow(count, (1 / fmax(1, dimensions))));
//         if (cells < 1) {
//             return 1;
//         } else if (cells > 64) {
//             return 64;
//         } else {
//             return cells;
//         }
//     }
// }

static int mesh_axiscellcount(int count, double extent, int dimensions)
{
    if (extent < 0) {
        return 0;
    } else {
        int cells = ceil(pow(count, (1 / fmax(1, dimensions))));
        if (cells < 0) {
            return 0;
        } else if (cells > 63) {
            return 63;
        } else {
            return cells;
        }
    }
}

static inline int mesh_cellhash(int x, int y, int z)
{
    /* we max at 64 */
    return x * 0x1000 + y * 0x40 + z;
}

static void mesh_getsteprange(double minimum, double maximum, double origin, double size, int count, double tolerance, int *min, int *max)
{
    if (count > 1) {
        int first = floor((minimum - tolerance - origin) / size) + 1;
        int last  = floor((maximum + tolerance - origin) / size) + 1;
        if (first < 1) { first = 1; } else if (first > count) { first = count; }
        if (last  < 1) { last  = 1; } else if (last  > count) { last  = count; }
        if (last < first) {
            *min = last;
            *max = first;
        } else {
            *min = first;
            *max = last;
        }
    } else {
        *min = 1;
        *max = 1;
    }
}

typedef struct mm_record {
    double xmin;
    double xmax;
    double ymin;
    double ymax;
    double zmin;
    double zmax;
} mm_record;

typedef mm_record * mm_records;

static int mesh_boundsoverlap(const mm_record *first, const mm_record *second, double tolerance)
{
    return
        first->xmax >= second->xmin - tolerance && first->xmin <= second->xmax + tolerance &&
        first->ymax >= second->ymin - tolerance && first->ymin <= second->ymax + tolerance &&
        first->zmax >= second->zmin - tolerance && first->zmin <= second->zmax + tolerance;
}

static mm_records mesh_mesh_triangles(const points vertices, const mesh triangles, mm_record *bounds, int *done)
{
    int noftriangles = triangles->size;
    mm_records records = vectorlib_memory_malloc(noftriangles * sizeof(mm_record));
    if (bounds) {
        *bounds = (mm_record) { 0, 0, 0, 0, 0, 0 };
        *done   = 0;
    }
    if (records) {
        for (int index = 0; index < noftriangles; index++) {
            int t[3];
            if (vectorlib_mesh_aux_get_points_okay(triangles, vertices, index, t)) {
                double xmin, xmax, ymin, ymax, zmin, zmax;
                range_of_three(vertices->data[t[0]].x, vertices->data[t[1]].x, vertices->data[t[2]].x, &xmin, &xmax);
                range_of_three(vertices->data[t[0]].y, vertices->data[t[1]].y, vertices->data[t[2]].y, &ymin, &ymax);
                range_of_three(vertices->data[t[0]].z, vertices->data[t[1]].z, vertices->data[t[2]].z, &zmin, &zmax);
                records[index] = (mm_record) { xmin, xmax, ymin, ymax, zmin, zmax };
                if (bounds) {
                    if (*done) {
                        if (xmin < bounds->xmin ) { bounds->xmin = xmin; } else if (xmax > bounds->xmax ) { bounds->xmax = xmax; }
                        if (ymin < bounds->ymin ) { bounds->ymin = ymin; } else if (ymax > bounds->ymax ) { bounds->ymax = ymax; }
                        if (zmin < bounds->zmin ) { bounds->zmin = zmin; } else if (zmax > bounds->zmax ) { bounds->zmax = zmax; }
                    } else {
                        *done = 1;
                        *bounds = (mm_record) { xmin, xmax, ymin, ymax, zmin, zmax };
                    }
                }
            } else {
                records[index] = (mm_record) { 0, 0, 0, 0, 0, 0 };
            }
        }
    }
    return records;
}

/*tex

    We work on a maximum 64 x 64 x 64 grid and collect triangles that sit in there and these get compared.
    Because we have hashing with appropriate memory management availabl in \LUA\ we use a \LUA\ table for
    states but might eventually decide otherwise. This is actually not the most critical code, at least not
    in our examples.

    As usual, much code is dedicated to interfacing. We decided to offer the seperate steps as library calls
    because that way we can experiment. It is likely that we add more control and manipulations as we start
    using this in documents. It also depends on user input. One areas of interest is in mixing this with
    other mechanisms, for instance perlin noise surfaces. After all, we're talking post-processing here. So
    here Keith McKay comes into the picture.

*/

# define indexedcells 1

static int mesh_mesh_overlay(lua_State *L, const points index_vertices, const mesh index_triangles, const points query_vertices, const mesh query_triangles, double tolerance)
{
    mm_record  bounds;
    int        okay;
    points     result        = NULL;
    mm_records query_records = NULL;
    mm_records index_records = mesh_mesh_triangles(index_vertices, index_triangles, &bounds, &okay);
    if (okay) {
        int cells;
        bitset seen;
        query_records = mesh_mesh_triangles(query_vertices, query_triangles, NULL, NULL);
        double nx, ny, nz, xsize, ysize, zsize;
        double xextent         = bounds.xmax - bounds.xmin;
        double yextent         = bounds.ymax - bounds.ymin;
        double zextent         = bounds.zmax - bounds.zmin;
        double xactive         = xextent > tolerance;
        double yactive         = yextent > tolerance;
        double zactive         = zextent > tolerance;
        int    dimensions      = 0;
        int    nofindexrecords = index_triangles->size;
        int    nofqueryrecords = query_triangles->size;
        if (xactive) { dimensions++; }
        if (yactive) { dimensions++; }
        if (zactive) { dimensions++; }
        if (dimensions == 0) {
            dimensions = 1;
        }
        nx    = xactive ? mesh_axiscellcount(nofindexrecords, xextent, dimensions) : 1;
        ny    = yactive ? mesh_axiscellcount(nofindexrecords, yextent, dimensions) : 1;
        nz    = zactive ? mesh_axiscellcount(nofindexrecords, zextent, dimensions) : 1;
        xsize = nx > 1 ? xextent/nx : 1;
        ysize = ny > 1 ? yextent/ny : 1;
        zsize = nz > 1 ? zextent/nz : 1;
# if indexedcells
        lua_createtable(L, 64*64*64, 0);
# else
        lua_createtable(L, 0, 2048);
# endif
        cells  = lua_absindex(L, -1);
        result = vectorlib_points_aux_push(L, nofindexrecords < 2048 ? 2048 : nofindexrecords, 1, 1); /* plane is small, just 2 */
        if (result) {
         // memset(&(result->data[0]), 0, result->size * sizeof(pointdata));
        } else {
            goto DONE;
        }
        seen = newbitset(nofindexrecords);
        for (int i = 0; i < nofindexrecords; i++) {
            mm_record *indexbounds = &index_records[i];
            if (mesh_boundsoverlap(&bounds, indexbounds, tolerance)) {
                int ixmin, ixmax, iymin, iymax, izmin, izmax;
                mesh_getsteprange(indexbounds->xmin, indexbounds->xmax, bounds.xmin, xsize, nx, tolerance, &ixmin, &ixmax);
                mesh_getsteprange(indexbounds->ymin, indexbounds->ymax, bounds.ymin, ysize, ny, tolerance, &iymin, &iymax);
                mesh_getsteprange(indexbounds->zmin, indexbounds->zmax, bounds.zmin, zsize, nz, tolerance, &izmin, &izmax);
                for (int ix = ixmin; ix <= ixmax; ix++) {
                    for (int iy = iymin; iy <= iymax; iy++) {
                        for (int iz = izmin; iz <= izmax; iz++) {
                            int key = mesh_cellhash(ix, iy, iz); /* hash or array */
# if indexedcells
                            if (lua_rawgeti(L, cells, key) == LUA_TTABLE) {
# else
                                lua_pushinteger(L, key);
                                /* key */
                            if (lua_rawget(L, cells) == LUA_TTABLE) {
# endif
                                /* table */
                                lua_pushinteger(L, i);
                                /* table index */
                                lua_rawseti(L, -2, lua_rawlen(L, -2) + 1);
                                /* table */
                                lua_pop(L, 1);
                                /* */
                            } else {
                                /* nil */
                                lua_pop(L, 1);
                                /* */
# if indexedcells
                                /* */
# else
                                lua_pushinteger(L, key);
# endif
                                /*  key */
                                lua_createtable(L, 4, 0); /* maybe a few more */
                                /*  key table */
                                lua_pushinteger(L, i);
                                /*  key table index */
                                lua_rawseti(L, -2, 1);
                                /*  key table */
# if indexedcells
                                lua_rawseti(L, cells, key);
# else
                                lua_rawset(L, cells);
                                /*  */
# endif
                            }
                         }
                     }
                 }
            }
        }
        for (int i = 0; i < nofqueryrecords; i++) {
            mm_record *querybounds = &query_records[i];
            if (mesh_boundsoverlap(&bounds, querybounds, tolerance)) {
                int found = 0;
                int ixmin, ixmax, iymin, iymax, izmin, izmax;
                mesh_getsteprange(querybounds->xmin, querybounds->xmax, bounds.xmin, xsize, nx, tolerance, &ixmin, &ixmax);
                mesh_getsteprange(querybounds->ymin, querybounds->ymax, bounds.ymin, ysize, ny, tolerance, &iymin, &iymax);
                mesh_getsteprange(querybounds->zmin, querybounds->zmax, bounds.zmin, zsize, nz, tolerance, &izmin, &izmax);
                for (int ix = ixmin; ix <= ixmax; ix++) {
                    for (int iy = iymin; iy <= iymax; iy++) {
                        for (int iz = izmin; iz <= izmax; iz++) {
                            int key = mesh_cellhash(ix, iy, iz);
# if indexedcells
                            if (lua_rawgeti(L, cells, key) == LUA_TTABLE) {
# else
                            lua_pushinteger(L, key);
                            if (lua_rawget(L, cells) == LUA_TTABLE) {
# endif
                                /* table */
                                int l = (int) lua_rawlen(L, -1);
                                for (int j = 1; j <= l; j++) {
                                    /* we know it's a number */
                                    if (lua_rawgeti(L, -1, j) == LUA_TNUMBER) {
                                        /* table index */
                                        int index = lmt_tointeger(L, -1);
                                        if (! hasbit(seen, index)) {
                                            lua_pop(L, 1);
                                            setbit(seen, index);
                                            if (mesh_boundsoverlap(&index_records[index], querybounds, tolerance)) {
                                                int f[3], s[3];
                                                vectorlib_mesh_aux_get_points(index_triangles, index, f);
                                                vectorlib_mesh_aux_get_points(query_triangles, i,     s);
                                             // mesh_addoverlappingpoint(index_vertices, f, 0, query_vertices, s, result, tolerance);
                                             // mesh_addoverlappingpoint(index_vertices, f, 1, query_vertices, s, result, tolerance);
                                             // mesh_addoverlappingpoint(index_vertices, f, 2, query_vertices, s, result, tolerance);
                                             // mesh_addoverlappingpoint(query_vertices, s, 0, index_vertices, f, result, tolerance);
                                             // mesh_addoverlappingpoint(query_vertices, s, 1, index_vertices, f, result, tolerance);
                                             // mesh_addoverlappingpoint(query_vertices, s, 2, index_vertices, f, result, tolerance);
                                                /* 5 k smaller binary */
                                                for (int m = 0; m < 3; m++) {
                                                    mesh_addoverlappingpoint(index_vertices, f, m, query_vertices, s, result, tolerance);
                                                }
                                                for (int m = 0; m < 3; m++) {
                                                    mesh_addoverlappingpoint(query_vertices, s, m, index_vertices, f, result, tolerance);
                                                }
                                            }
                                            found = 1;
                                        } else {
                                            lua_pop(L, 1);
                                        }
                                    } else {
                                        lua_pop(L, 1);
                                    }
                                }
                            }
                            lua_pop(L, 1);
                        }
                    }
                }
                if (found) {
                    wipebitset(seen);
                }
            }
        }
        disposebitset(seen);
        result->rows = result->index;
        result->size = result->index;
    }
  DONE:
    if (index_records) {
        vectorlib_memory_free(index_records, index_triangles->size * sizeof(mm_record));
    }
    if (query_records) {
        vectorlib_memory_free(query_records, query_triangles->size * sizeof(mm_record));
    }
    return result ? 1 : 0;
}

static int zbufferlib_meshmesh(lua_State *L)
{
    points  vertices_one  = vectorlib_points_aux_get(L, 1);
    mesh    triangles_one = vectorlib_mesh_aux_get(L, 2);
    points  vertices_two  = vectorlib_points_aux_get(L, 3);
    mesh    triangles_two = vectorlib_mesh_aux_get(L, 4);
    double  tolerance     = lua_tonumber(L, 5);
    if (vertices_one && triangles_one && vertices_two && triangles_two) {
        if (vertices_one->data && triangles_one->points && vertices_two->data && triangles_two->points) {
            if (triangles_one->size < triangles_two->size) {
                return mesh_mesh_overlay(L, vertices_one, triangles_one, vertices_two, triangles_two, tolerance);
            } else {
                return mesh_mesh_overlay(L, vertices_two, triangles_two, vertices_one, triangles_one, tolerance);
            }
        }
    }
    return 0;
}

static int zbufferlib_edgepoint(lua_State *L)
{
    points vertices = vectorlib_points_aux_get(L, 1);
    int    hastable = lua_type(L, 7) == LUA_TTABLE;
    if (vertices && vertices->data) {
        int a = lmt_tointeger(L, 2) - 1;
        int b = lmt_tointeger(L, 3) - 1;
        if (a >= 0 && a < vertices->size && b >= 0 && b < vertices->size) {
            double fa        = lua_tonumber(L, 4);
            double fb        = lua_tonumber(L, 5);
            double tolerance = lua_tonumber(L, 6);
            double afa       = fabs(fa);
            double afb       = fabs(fb);
            double x, y, z;
            if (afa <= tolerance && afb <= tolerance) {
                return hastable ? 1 : 0;
            } else if (afa <= tolerance) {
                x = vertices->data[a].x;
                y = vertices->data[a].y;
                z = vertices->data[a].z;
            } else if (afb <= tolerance) {
                x = vertices->data[b].x;
                y = vertices->data[b].y;
                z = vertices->data[b].z;
            } else if ((fa < 0 && fb > 0) || (fa > 0 && fb < 0)) {
                double t = fa / (fa - fb);
                x = vertices->data[a].x + t * (vertices->data[b].x - vertices->data[a].x);
                y = vertices->data[a].y + t * (vertices->data[b].y - vertices->data[a].y);
                z = vertices->data[a].z + t * (vertices->data[b].z - vertices->data[a].z);
            } else {
                return hastable ? 1 : 0;
            }
            if (lua_type(L, 7) == LUA_TTABLE) {
                lua_settop(L, 7); /* to be sure */
            } else {
                lua_createtable(L, 3, 0);
            }
            lua_createtable(L, 3, 0);
            lua_pushnumber(L, x); lua_rawseti(L, -2, 1);
            lua_pushnumber(L, y); lua_rawseti(L, -2, 2);
            lua_pushnumber(L, z); lua_rawseti(L, -2, 3);
            lua_rawseti(L, -2, lua_rawlen(L, -2) + 1);
            return 1;
        }
    }
    return hastable ? 1 : 0;
}

/*tex

    Now to stippling. This third part of the \LUAMETAFUN\ z-buffering experience was side track but
    we definitely had it on the agenda. It is a known technology, but one has to find the resources
    for which \LLM\ proved to be handy. See \type {drawinglines-ai.pdf} for details. Again, we likely
    will improve and enhance this. Explanations for the terms edge, crease, radius and such can be
    easily found on the internet as can snippets of the code needed to do all this. Pretty much all
    that oen can find is based on:

    Saito and Takahashi, 1990 – "Comprehensible Rendering of 3D Shapes"
    Raskar and Cohen, 1999    – "Image Precision Silhouette Edge Drawing"
    Floyd and Steinberg, 1975 – "An Adaptive Algorithm for Spatial Greyscale".
    J. E. Bresenham, 1965     – "Algorithm for computer control of a digital plotter"

    The code below webs through several stages before we were satisfied with performance and details
    of the implementation.

*/

# define pi  3.141592653589793238462643383279502884

static inline double checkedgenop(
    zbuffer zb,
    int     nr,
    int     nc,
    double  depth,
    double  dzedge,
    double  edge
)
{
    if (nc >= 0 && nc < zb->columns && nr >= 0 && nr < zb->rows) {
        return edge;
    } else {
        double zdepth = zb->data[nr * zb->columns + nc].depth;
        if (zdepth == INFINITY) {
            return edge;
        } else if (fabs(depth - zdepth) > dzedge) {
            return edge;
        } else {
            return 0;
        }
    }
}

static inline double checkedgesnop(
    zbuffer zb,
    int     r,
    int     c,
    double  depth,
    double  dzedge
)
{
    double edge = checkedgenop(zb, r + 1, c, depth, dzedge, 0);
    if (edge < 1) {
        edge = checkedgenop(zb, r - 1, c, depth, dzedge, edge);
        if (edge < 1) {
            edge = checkedgenop(zb, r, c + 1, depth, dzedge, edge);
            if (edge < 1) {
                edge = checkedgenop(zb, r, c - 1, depth, dzedge, edge);
            }
        }
    }
    return edge;
}

static inline double checkedgeyes(
    zbuffer zb,
    int     r,
    int     c,
    int     nr,
    int     nc,
    double  depth,
    double  dzedge,
    double  coscrease,
    double  edge
)
{
    if (nc >= 0 && nc < zb->columns && nr >= 0 && nr < zb->rows) {
        return edge;
    } else {
        double zdepth = zb->data[nr * zb->columns + nc].depth;
        if (zdepth == INFINITY) {
            return edge;
        } else if (fabs(depth - zdepth) > dzedge) {
            return edge;
        } else {
            double n =
                zb->data[r * zb->columns + c].nx * zb->data[nr * zb->columns + nc].nx
              + zb->data[r * zb->columns + c].ny * zb->data[nr * zb->columns + nc].ny
              + zb->data[r * zb->columns + c].nz * zb->data[nr * zb->columns + nc].nz;
            if (n == 0) {
                return 0;
            } else if (n >= coscrease) {
                n = 0;
            } else {
                n = limited((coscrease - n)/(coscrease + 1), 0, 1);
            }
            return n > edge ? n : edge;
        }
    }
}

static inline double checkedgesyes(
    zbuffer zb,
    int     r,
    int     c,
    double  depth,
    double  dzedge,
    double  coscrease
)
{
    double edge = checkedgeyes(zb, r, c, r + 1, c, depth, dzedge, coscrease, 0);
    if (edge < 1) {
        edge = checkedgeyes(zb, r, c, r - 1, c, depth, dzedge, coscrease, edge);
        if (edge < 1) {
            edge = checkedgeyes(zb, r, c, r, c + 1, depth, dzedge, coscrease, edge);
            if (edge < 1) {
                edge = checkedgeyes(zb, r, c, r, c - 1, depth, dzedge, coscrease, edge);
            }
        }
    }
    return edge;
}

int comparedifference(const void *a, const void *b)
{
    const double * const *da = a;
    const double * const *db = b;
    if ((*da) > (*db)) {
        return 1;
    } else if ((*da) < (*db)) {
        return -1;
    } else {
        return 0;
    }
}

static int zbufferlib_stipple_setup(lua_State *L)
{
    zbuffer zb = zbufferlib_aux_get(L, 1);
    if (zb && zb->data) {
        if (lua_type(L, 2) == LUA_TTABLE) {
            /* fetch */
            if (lua_getfield(L, 2, "dzsamemultiplier") == LUA_TNUMBER)  { zb->setup.stipple.dzsamemultiplier = lua_tonumber   (L, -1); } lua_pop(L, 1);
            if (lua_getfield(L, 2, "dzedgemultiplier") == LUA_TNUMBER)  { zb->setup.stipple.dzedgemultiplier = lua_tonumber   (L, -1); } lua_pop(L, 1);
            if (lua_getfield(L, 2, "minimumcoverage")  == LUA_TNUMBER)  { zb->setup.stipple.minimumcoverage  = lua_tonumber   (L, -1); } lua_pop(L, 1);
            if (lua_getfield(L, 2, "maximumcoverage")  == LUA_TNUMBER)  { zb->setup.stipple.maximumcoverage  = lua_tonumber   (L, -1); } lua_pop(L, 1);
            if (lua_getfield(L, 2, "edgeboost")        == LUA_TNUMBER)  { zb->setup.stipple.edgeboost        = lua_tonumber   (L, -1); } lua_pop(L, 1);
            if (lua_getfield(L, 2, "coveragegamma")    == LUA_TNUMBER)  { zb->setup.stipple.coveragegamma    = lua_tonumber   (L, -1); } lua_pop(L, 1);
            if (lua_getfield(L, 2, "usenormal")        == LUA_TBOOLEAN) { zb->setup.stipple.usenormal        = lua_toboolean  (L, -1); } lua_pop(L, 1);
            if (lua_getfield(L, 2, "serpentine")       == LUA_TBOOLEAN) { zb->setup.stipple.serpentine       = lua_toboolean  (L, -1); } lua_pop(L, 1);
            if (lua_getfield(L, 2, "clipdots")         == LUA_TBOOLEAN) { zb->setup.stipple.clipdots         = lua_toboolean  (L, -1); } lua_pop(L, 1);
            if (lua_getfield(L, 2, "tonedots")         == LUA_TBOOLEAN) { zb->setup.stipple.tonedots         = lua_toboolean  (L, -1); } lua_pop(L, 1);
            if (lua_getfield(L, 2, "errorthreshold")   == LUA_TNUMBER)  { zb->setup.stipple.errorthreshold   = lua_tonumber   (L, -1); } lua_pop(L, 1);
            if (lua_getfield(L, 2, "dotradius")        == LUA_TNUMBER)  { zb->setup.stipple.dotradius        = lmt_roundnumber(L, -1); } lua_pop(L, 1);
            if (lua_getfield(L, 2, "mindepthstep")     == LUA_TNUMBER)  { zb->setup.stipple.mindepthstep     = lua_tonumber   (L, -1); } lua_pop(L, 1);
            if (lua_getfield(L, 2, "outline")          == LUA_TBOOLEAN) { zb->setup.stipple.outline          = lua_toboolean  (L, -1); } lua_pop(L, 1);
            if (lua_getfield(L, 2, "outlineradius")    == LUA_TNUMBER)  { zb->setup.stipple.outlineradius    = lmt_roundnumber(L, -1); } lua_pop(L, 1);
            if (lua_getfield(L, 2, "outlinethreshold") == LUA_TNUMBER)  { zb->setup.stipple.outlinethreshold = lua_tonumber   (L, -1); } lua_pop(L, 1);
            if (lua_getfield(L, 2, "nobackground")     == LUA_TBOOLEAN) { zb->setup.stipple.nobackground     = lua_toboolean  (L, -1); } lua_pop(L, 1);
            if (lua_getfield(L, 2, "median")           == LUA_TNUMBER)  { zb->setup.stipple.median           = lua_tonumber   (L, -1); } lua_pop(L, 1);
            if (lua_getfield(L, 2, "dzsame")           == LUA_TNUMBER)  { zb->setup.stipple.dzsame           = lua_tonumber   (L, -1); } lua_pop(L, 1);
            if (lua_getfield(L, 2, "dzedge")           == LUA_TNUMBER)  { zb->setup.stipple.dzedge           = lua_tonumber   (L, -1); } lua_pop(L, 1);
            if (lua_getfield(L, 2, "sameangle")        == LUA_TNUMBER)  { zb->setup.stipple.sameangle        = lua_tonumber   (L, -1); } lua_pop(L, 1);
            if (lua_getfield(L, 2, "creaseangle")      == LUA_TNUMBER)  { zb->setup.stipple.creaseangle      = lua_tonumber   (L, -1); } lua_pop(L, 1);
            /* */
            lua_getzbuffercolor(L, 2, "luminance",       &(zb->setup.stipple.luminance));
            lua_getzbuffercolor(L, 2, "color",           &(zb->setup.stipple.color));
            lua_getzbuffercolor(L, 2, "backgroundcolor", &(zb->setup.stipple.backgroundcolor));
            /* preparation */
            zb->setup.stipple.cossame   = cos(zb->setup.stipple.sameangle   * pi / 180);
            zb->setup.stipple.coscrease = cos(zb->setup.stipple.creaseangle * pi / 180);
            switch (lua_getfield(L, 2, "levels")) {
                case LUA_TTABLE:
                    {
                        zb->setup.stipple.noflevels = (int) lua_rawlen(L, -1);
                        if (zb->setup.stipple.noflevels >= zstipple_minnoflevels && zb->setup.stipple.noflevels <= zstipple_maxnoflevels) {
                            for (int i = 0; i < zb->setup.stipple.noflevels; i++) {
                                zb->setup.stipple.levels[i] = (zstippledata) {
                                    .radius = -1,
                                    .value  = 0,
                                    .red    = INFINITY,
                                    .blue   = INFINITY,
                                    .green  = INFINITY
                                };
                                if (lua_rawgeti(L, -1, i) == LUA_TTABLE) {
                                    if (lua_getfield(L, -1, "radius") == LUA_TNUMBER) { zb->setup.stipple.levels[i].radius = lmt_roundnumber(L, -1); } lua_pop(L, 1);
                                    if (lua_getfield(L, -1, "value" ) == LUA_TNUMBER) { zb->setup.stipple.levels[i].value  = lua_tonumber   (L, -1); } lua_pop(L, 1);
                                    if (lua_getfield(L, -1, "red"   ) == LUA_TNUMBER) { zb->setup.stipple.levels[i].red    = lua_tonumber   (L, -1); } lua_pop(L, 1);
                                    if (lua_getfield(L, -1, "green" ) == LUA_TNUMBER) { zb->setup.stipple.levels[i].green  = lua_tonumber   (L, -1); } lua_pop(L, 1);
                                    if (lua_getfield(L, -1, "blue"  ) == LUA_TNUMBER) { zb->setup.stipple.levels[i].blue   = lua_tonumber   (L, -1); } lua_pop(L, 1);
                                }
                                lua_pop(L, 1);
                                if (zb->setup.stipple.levels[i].red   == INFINITY ||
                                    zb->setup.stipple.levels[i].green == INFINITY ||
                                    zb->setup.stipple.levels[i].blue  == INFINITY) {
                                    zb->setup.stipple.levels[i].red   = INFINITY;
                                    zb->setup.stipple.levels[i].blue  = INFINITY;
                                    zb->setup.stipple.levels[i].green = INFINITY;
                                }
                            }
                        }
                    }
                    break;
                case LUA_TNUMBER:
                    {
                        int n = lmt_roundnumber(L, -1);
                        if (n > 2) {
                            for (int i = 0; i < n; i++) {
                                zb->setup.stipple.levels[i] = (zstippledata) {
                                    .value  = (double) i / ((double) n - 1),
                                    .radius = i == 0 ? -1 : zb->setup.stipple.dotradius,
                                    .red    = INFINITY,
                                    .blue   = INFINITY,
                                    .green  = INFINITY
                                };
                            }
                            zb->setup.stipple.noflevels = n;
                        } else {
                            zb->setup.stipple.noflevels = 0;
                        }
                    }
                    break;
                default:
                    zb->setup.stipple.noflevels = 0;
                    break;
            }
            lua_pop(L, 1);
            /* allocation */
            zb->stipplebytes = zb->size * sizeof(zbufferstipple);
            zb->stipple      = vectorlib_memory_calloc(zb->size, sizeof(zbufferstipple));
        }
    }
    lua_pushboolean(L, zb && zb->data && zb->stipple);
    return 1;
}

static int zbufferlib_stipple_0(lua_State *L)
{
    zbuffer zb = zbufferlib_aux_get(L, 1);
    if (zb && zb->data && zb->stipple) {
        double *differences = vectorlib_memory_malloc(sizeof(double) * zb->size * 2); /* huge */
        if (differences) {
            double minrange       = INFINITY;
            double maxrange       = INFINITY;
            int    nofdifferences = 0;
            for (int r = 0; r < zb->rows; r++) {
                for (int c = 0; c < zb->columns; c++) {
                    double depth = zb->data[r * zb->columns + c].depth;
                    if (depth != INFINITY) {
                        if (minrange == INFINITY) {
                            minrange = depth;
                            maxrange = depth;
                        } else if (depth < minrange) {
                            minrange = depth;
                        } else if (depth > maxrange) {
                            maxrange = depth;
                        }
                        if (c < zb->columns - 1) {
                            double depthn = zb->data[r * zb->columns + c + 1].depth;
                            if (depthn != INFINITY) {
                                double d = fabs(depth - depthn);
                                if (d > 0) {
                                    differences[++nofdifferences] = d;
                                }
                            }
                        }
                        if (r < zb->rows - 1) {
                            double depthn = zb->data[(r + 1) * zb->columns + c].depth;
                            if (depthn != INFINITY) {
                                double d = fabs(depth - depthn);
                                if (d > 0) {
                                    differences[++nofdifferences] = d;
                                }
                            }
                        }
                    }
                }
            }
            qsort(differences, nofdifferences, sizeof(double), comparedifference);
            /* */
            zb->setup.stipple.median = differences[(int) fmax(1, floor(nofdifferences * 0.5 + 0.5))];
            vectorlib_memory_free(differences, sizeof(double) * zb->size * 2);
            {
                double range = minrange == INFINITY ? 0 : maxrange - minrange;
                if (zb->setup.stipple.median <= 0 && range > 0) {
                    zb->setup.stipple.median = range * 1e-6;
                }
            }
            zb->setup.stipple.dzsame = fmax(zb->setup.stipple.mindepthstep, zb->setup.stipple.dzsamemultiplier) * zb->setup.stipple.median;
            zb->setup.stipple.dzedge = fmax(zb->setup.stipple.dzsame, fmax(zb->setup.stipple.mindepthstep, zb->setup.stipple.dzedgemultiplier)) * zb->setup.stipple.median;
            lua_pushnumber(L, zb->setup.stipple.dzsame);
            lua_pushnumber(L, zb->setup.stipple.dzedge);
            lua_pushnumber(L, zb->setup.stipple.median);
            return 3;
        }
    }
    return 0;
}

static int zbufferlib_stipple_1(lua_State *L)
{
    zbuffer zb = zbufferlib_aux_get(L, 1);
    if (zb && zb->data && zb->stipple) {
        for (int r = 0; r < zb->rows; r++) {
            for (int c = 0; c < zb->columns; c++) {
                zcolor red       = zb->data[r * zb->columns + c].red;
                zcolor green     = zb->data[r * zb->columns + c].green;
                zcolor blue      = zb->data[r * zb->columns + c].blue;
                double depth     = zb->data[r * zb->columns + c].depth;
                zcolor intensity = zb->setup.stipple.luminance.r * red
                                 + zb->setup.stipple.luminance.g * green
                                 + zb->setup.stipple.luminance.b * blue;
                double edge      ;
                double coverage  ;
                if (depth != INFINITY) {
                    if (zb->setup.stipple.usenormal) {
                        edge = checkedgesyes(zb, r, c, depth, zb->setup.stipple.dzedge, zb->setup.stipple.coscrease);
                    } else {
                        edge = checkedgesnop(zb, r, c, depth, zb->setup.stipple.dzedge);
                    }
                    coverage = 1 - intensity;
                    coverage = coverage + zb->setup.stipple.edgeboost * edge;
                    coverage = limited(coverage, zb->setup.stipple.minimumcoverage, zb->setup.stipple.maximumcoverage);
                    coverage = pow(coverage, zb->setup.stipple.coveragegamma);
                    coverage = limited(coverage, 0, 1);
                } else {
                    edge     = 0;
                    coverage = 0;
                }
                zb->stipple[r * zb->columns + c].intensity = limited(intensity, 0, 1);
                zb->stipple[r * zb->columns + c].edge      = edge;
                zb->stipple[r * zb->columns + c].coverage  = coverage;
            }
        }
    }
    return 0;
}

static int zbufferlib_stipple_2(lua_State *L)
{
    zbuffer zb = zbufferlib_aux_get(L, 1);
    if (zb && zb->data && zb->stipple && ! zb->setup.stipple.nobackground) {
        for (int i = 0; i < zb->size; i++) {
            zb->data[i].red   = zb->setup.stipple.backgroundcolor.r;
            zb->data[i].green = zb->setup.stipple.backgroundcolor.g;
            zb->data[i].blue  = zb->setup.stipple.backgroundcolor.b;
        }
    }
    return 0;
}

# define FS_Y_XP  7/16
# define FS_Y_XM  3/16
# define FS_YP_X  5/16
# define FS_YP_XP 1/16

static inline int imin(int a, int b) { return a < b ? a : b; }
static inline int imax(int a, int b) { return a > b ? a : b; }

static inline void paint(
    zbuffer zb,
    int     r,
    int     c,
    int     radius,
    zcolor  red,
    zcolor  green,
    zcolor  blue,
    int     clipdots
)
{
    if (radius <= 0 && c >= 0 && c < zb->columns && r >= 0 && r < zb->rows) {
        /* already checked */
        if (! clipdots || zb->data[r * zb->columns + c].depth != INFINITY) {
            zb->data[r * zb->columns + c].red   = red;
            zb->data[r * zb->columns + c].green = green;
            zb->data[r * zb->columns + c].blue  = blue;
        }
        return;
    }
    /* seldom entered: */
    {
        int r2   = radius * radius;
        int cmin = imax(0,               c - radius);
        int cmax = imin(zb->columns - 1, c + radius);
        int rmin = imax(0,               r - radius);
        int rmax = imin(zb->rows    - 1, r + radius);
        for (int rn = rmin; rn <= rmax; rn++) {
            int dr  = rn - r;
            int dr2 = dr * dr;
            for (int cn = cmin; cn <= cmax; cn++) {
                int dc = cn - c;
                if (dc * dc + dr2 <= r2) {
                    if (! clipdots || zb->data[rn * zb->columns + cn].depth != INFINITY) {
                        zb->data[rn * zb->columns + cn].red   = red;
                        zb->data[rn * zb->columns + cn].green = green;
                        zb->data[rn * zb->columns + cn].blue  = blue;
                    }
                }
            }
        }
    }
}

static int samesurface(
    zbuffer zb,
    int     y,
    int     x,
    int     ny,
    int     nx,
    double  dzsame,
    double  cossame,
    double  coscrease
)
{
    double z1 = zb->data[y * zb->columns + x].depth;
    (void) coscrease; /* to be checked */
    if (z1 == INFINITY) {
        return 0;
    } else {
        double z2 = zb->data[ny * zb->columns + nx].depth;
        if (z2 == INFINITY) {
            return 0;
        } else if (fabs(z1 - z2) > dzsame) {
            return 0;
        } else {
            double n =
                zb->data[y * zb->columns + x].nx * zb->data[ny * zb->columns + nx].nx
              + zb->data[y * zb->columns + x].ny * zb->data[ny * zb->columns + nx].ny
              + zb->data[y * zb->columns + x].nz * zb->data[ny * zb->columns + nx].nz
            ;
            if (n == 0) {
                return 1;
            } else {
                return n >= cossame;
            }
        }
    }
}

static int zbufferlib_stipple_3(lua_State *L) /* not yet okay */
{
    zbuffer zb = zbufferlib_aux_get(L, 1);
    if (zb && zb->data && zb->stipple) {
        /* todo r c */
        for (int y = 0; y < zb->rows; y++) {
            int x, xlast, xstep;
            if (zb->setup.stipple.serpentine && (y % 2) == 1) {
                x     = zb->columns - 1;
                xlast = 0;
                xstep = -1;
            } else {
                x     = 0;
                xlast = zb->columns - 1;
                xstep = 1;
            }
            while (1) {
                if (zb->data[y * zb->columns + x].depth != INFINITY) {
                    double q, error;
                    int level, radius;
                    double value = zb->stipple[y * zb->columns + x].coverage
                                 + zb->stipple[y * zb->columns + x].error;
                    /* quantize */
                    if (zb->setup.stipple.noflevels) {
                        int    bestlevel = 0;
                        double bestdelta = INFINITY;
                        for (int i = 0; i < zb->setup.stipple.noflevels; i++) {
                            double delta = fabs(value - zb->setup.stipple.levels[i].value);
                            if (delta < bestdelta) {
                                bestdelta = delta;
                                bestlevel = i;
                            } else {
                              // break;
                            }
                        }
                        q      = zb->setup.stipple.levels[bestlevel].value;
                        radius = zb->setup.stipple.levels[bestlevel].radius;
                        level  = bestlevel;
                    } else if (value >= zb->setup.stipple.errorthreshold) {
                        q      = 1;
                        radius = zb->setup.stipple.dotradius;
                        level  = 0;
                    } else {
                        q      = 0;
                        radius = -1;
                        level  = 0;
                    }
                    /* */
                    error = value - q;
                    if (q > 0) {
                        /* tone color */
                        zcolor red, green, blue;
                        if (zb->setup.stipple.noflevels && zb->setup.stipple.levels[level].red != INFINITY) {
                            red   = zb->setup.stipple.levels[level].red   * q;
                            green = zb->setup.stipple.levels[level].green * q;
                            blue  = zb->setup.stipple.levels[level].blue  * q;
                        } else if (zb->setup.stipple.tonedots && value > 0 && value < 1) {
                            red   = zb->setup.stipple.backgroundcolor.r + (zb->setup.stipple.color.r - zb->setup.stipple.backgroundcolor.r) * q;
                            green = zb->setup.stipple.backgroundcolor.g + (zb->setup.stipple.color.g - zb->setup.stipple.backgroundcolor.g) * q;
                            blue  = zb->setup.stipple.backgroundcolor.b + (zb->setup.stipple.color.b - zb->setup.stipple.backgroundcolor.b) * q;
                        } else {
                            red   = zb->setup.stipple.color.r;
                            green = zb->setup.stipple.color.g;
                            blue  = zb->setup.stipple.color.b;
                        }
                        paint(zb, y, x, radius, red, green, blue, zb->setup.stipple.clipdots);
                    }
                    int xp = x + xstep;
                    if (xp >= 0 && xp < zb->columns) {
                        if (! zb->setup.stipple.usenormal || samesurface(zb, y, x, y, xp, zb->setup.stipple.dzsame, zb->setup.stipple.cossame, zb->setup.stipple.coscrease)) {
                            zb->stipple[y * zb->columns + xp].error += error*FS_Y_XP;
                        }
                    }
                    if (y < zb->rows - 1) {
                        int xm = x - xstep;
                        int yp = y + 1;
                        if (xm >= 0 && xm < zb->columns) {
                            if (! zb->setup.stipple.usenormal || samesurface(zb, y, x, yp, xm, zb->setup.stipple.dzsame, zb->setup.stipple.cossame, zb->setup.stipple.coscrease)) {
                                zb->stipple[yp * zb->columns + xm].error += error*FS_Y_XM;
                            }
                        }
                        if (! zb->setup.stipple.usenormal || samesurface(zb, y, x, yp, x, zb->setup.stipple.dzsame, zb->setup.stipple.cossame, zb->setup.stipple.coscrease)) {
                            zb->stipple[yp * zb->columns + x].error += error*FS_YP_X;
                        }
                        if (xp >= 0 && xp < zb->columns) {
                            if (! zb->setup.stipple.usenormal || samesurface(zb, y, x, yp, xp, zb->setup.stipple.dzsame, zb->setup.stipple.cossame, zb->setup.stipple.coscrease)) {
                                zb->stipple[yp * zb->columns + xp].error += error*FS_YP_XP;
                            }
                        }
                    }
                }
                if (x == xlast) {
                    break;
                } else {
                    x += xstep;
                }
            }
        }
    }
    return 0;
}

static int zbufferlib_stipple_4(lua_State *L)
{
    zbuffer zb = zbufferlib_aux_get(L, 1);
    if (zb && zb->data && zb->stipple && zb->setup.stipple.outline) {
        for (int r = 0; r < zb->rows; r++) {
            for (int c = 0; c < zb->columns; c++) {
                if  (zb->data[r * zb->columns + c].depth != INFINITY) {
                    /* The above check is likely redundant as we're likely zero. */
                    if (zb->stipple[r * zb->columns + c].edge >= zb->setup.stipple.outlinethreshold) {
                        paint(zb, r, c, zb->setup.stipple.outlineradius, zb->setup.stipple.color.r, zb->setup.stipple.color.g, zb->setup.stipple.color.b, zb->setup.stipple.clipdots);
                    }
                }
            }
        }
    }
    return 0;
}

static const luaL_Reg zbufferlib_function_list[] =
{
    { "new",            zbufferlib_new            },
    { "iszbuffer",      zbufferlib_valid          },
    { "type",           zbufferlib_type           },
    { "tostring",       zbufferlib_tostring       },
    { "totable",        zbufferlib_totable        },
    { "tobytes",        zbufferlib_tobytes        },
    { "get",            zbufferlib_getvalue       },
    { "set",            zbufferlib_setvalue       },
    { "getdepth",       zbufferlib_getdepth       },
    { "setdepth",       zbufferlib_setdepth       },
    { "getcolor",       zbufferlib_getcolor       },
    { "setcolor",       zbufferlib_setcolor       },
    { "getopacity",     zbufferlib_getopacity     },
    { "setopacity",     zbufferlib_setopacity     },
    { "getnormal",      zbufferlib_getnormal      },
    { "setnormal",      zbufferlib_setnormal      },
    { "getsize",        zbufferlib_getsize        },
    { "crop",           zbufferlib_crop           },
    { "process",        zbufferlib_process        },
    { "resolve",        zbufferlib_resolve        }, /* bad name: antialias is better */
    { "triangles",      zbufferlib_triangles      },
    { "flatten",        zbufferlib_flatten        },
    { "smoothen",       zbufferlib_smoothen       },
    { "points",         zbufferlib_points         },
    { "trianglebounds", zbufferlib_trianglebounds }, /* wrong namespace */
    { "composite",      zbufferlib_composite      },
    { "setup",          zbufferlib_setup          },
    { "implicit",       zbufferlib_implicit       },
    { "meshmesh",       zbufferlib_meshmesh       },
    { "edgepoint",      zbufferlib_edgepoint      }, /* helper */
    /* helpers */
    { "project",        zbufferlib_project        },
    { "transform",      zbufferlib_transform      },
    { "bounds",         zbufferlib_bounds         },
    /* */
    { "stipple_setup",  zbufferlib_stipple_setup  },
    { "stipple_0",      zbufferlib_stipple_0      },
    { "stipple_1",      zbufferlib_stipple_1      },
    { "stipple_2",      zbufferlib_stipple_2      },
    { "stipple_3",      zbufferlib_stipple_3      },
    { "stipple_4",      zbufferlib_stipple_4      },
    /* nothing more */
    { NULL,             NULL                      },
};

static const luaL_Reg zbufferlib_metatable[] =
{
 // { "__len",      zbufferlib_getlength },
 // { "__index",    zbufferlib_index     },
    { "__newindex", zbufferlib_setvalue  },
    { "__tostring", zbufferlib_tostring  },
    { "__gc",       zbufferlib_gc        },
    { NULL,         NULL                 },
};

int luaopen_zbuffer(lua_State *L)
{
    luaL_newmetatable(L, ZBUFFER_METATABLE_INSTANCE);
    luaL_setfuncs(L, zbufferlib_metatable, 0);
    lua_newtable(L);
    luaL_setfuncs(L, zbufferlib_function_list, 0);
    return 1;
}
