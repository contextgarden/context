/* lmtvectorlib.c

    -- mlib-thr.lmt

    local keys = {
        "code", "dfdx", "dfdy", "dfdz", "normal",
        "xmin", "xmax", "ymin", "ymax", "zmin", "zmax",
        "nx", "ny", "nz", "iso", "normalstep",
        "adaptive", "maxrefine", "flatness", "nearsurface",
    }

    -- mp-thrd.mkxl

    adaptive    = false,
    maxrefine   = 0,
    flatness    = .25,
    nearsurface = 1,

*/

static inline void samplepoint(lua_State *L, tetra *t, double x, double y, double z, int fp)
{
    t->x = x;
    t->y = y;
    t->z = z;
    t->v = call_fp(L, fp, x, y, z);
}

static void samplecube(lua_State *L, tetra *c, double x0, double y0, double z0, double dx, double dy, double dz, int fp)
{
    double x1 = x0 + dx;
    double y1 = y0 + dy;
    double z1 = z0 + dz;
    samplepoint(L, &c[0], x0, y0, z0, fp);
    samplepoint(L, &c[1], x1, y0, z0, fp);
    samplepoint(L, &c[2], x1, y1, z0, fp);
    samplepoint(L, &c[3], x0, y1, z0, fp);
    samplepoint(L, &c[4], x0, y0, z1, fp);
    samplepoint(L, &c[5], x1, y0, z1, fp);
    samplepoint(L, &c[6], x1, y1, z1, fp);
    samplepoint(L, &c[7], x0, y1, z1, fp);
}

static inline int implicitindex(int i, int j, int k, int nx, int ny)
{
    return (k * ny + j) * nx + i;
}

static int implicitcelllevel(lua_State *L, double x0, double y0, double z0, double dx, double dy, double dz, int fp, double iso, double flatness, double nearsurface, int level, int maxlevel)
{
    tetra c[8];
    tetra center;
    double minv, maxv, sum, average, range, deviation, scale, distance, limit;
    int crossing, centercrossing, curvednear;
    samplecube(L, c, x0, y0, z0, dx, dy, dz, fp);
    minv = maxv = sum = c[0].v;
    distance = fabs(c[0].v - iso);
    for (int n = 1; n < 8; n++) {
        double value = c[n].v;
        double delta = fabs(value - iso);
        if (value < minv) {
            minv = value;
        } else if (value > maxv) {
            maxv = value;
        }
        if (delta < distance) {
            distance = delta;
        }
        sum += value;
    }
    samplepoint(L, &center, x0 + 0.5 * dx, y0 + 0.5 * dy, z0 + 0.5 * dz, fp);
    if (fabs(center.v - iso) < distance) {
        distance = fabs(center.v - iso);
    }
    average        = 0.125 * sum; /* sum / 8 */
    range          = maxv - minv;
    scale          = fmax(range, epsilon);
    deviation      = fabs(center.v - average);
    crossing       = minv <= iso && maxv >= iso;
    centercrossing = ! crossing && fmin(minv, center.v) <= iso && fmax(maxv, center.v) >= iso;
    limit          = nearsurface * fmax(range + deviation, epsilon);
    curvednear     = deviation > flatness * scale && distance <= limit;
    if (! crossing && ! centercrossing && ! curvednear) {
        return -1;
    } else if (level >= maxlevel) {
        return level;
    } else if (! centercrossing && ! curvednear) {
        return level;
    } else {
        int best = level;
        double hx = 0.5 * dx;
        double hy = 0.5 * dy;
        double hz = 0.5 * dz;
        for (int kk = 0; kk < 2; kk++) {
            for (int jj = 0; jj < 2; jj++) {
                for (int ii = 0; ii < 2; ii++) {
                    int child = implicitcelllevel(L, x0 + ii * hx, y0 + jj * hy, z0 + kk * hz, hx, hy, hz, fp, iso, flatness, nearsurface, level + 1, maxlevel);
                    if (child > best) {
                        best = child;
                    }
                }
            }
        }
        return best;
    }
}

static void implicitbalancelevels(int *levels, int nx, int ny, int nz)
{
    int changed = 1;
    while (changed) {
        changed = 0;
        for (int k = 0; k < nz; k++) {
            for (int j = 0; j < ny; j++) {
                for (int i = 0; i < nx; i++) {
                    int index = implicitindex(i, j, k, nx, ny);
                    int level = levels[index];
                    if (level >= 0) {
                        if (i + 1 < nx) {
                            int otherindex = implicitindex(i + 1, j, k, nx, ny);
                            int other = levels[otherindex];
                            if (other >= 0 && other != level) {
                                int raised = level > other ? level : other;
                                if (levels[index] != raised) {
                                    levels[index] = raised;
                                    changed = 1;
                                }
                                if (levels[otherindex] != raised) {
                                    levels[otherindex] = raised;
                                    changed = 1;
                                }
                            }
                        }
                        if (j + 1 < ny) {
                            int otherindex = implicitindex(i, j + 1, k, nx, ny);
                            int other = levels[otherindex];
                            if (other >= 0 && other != level) {
                                int raised = level > other ? level : other;
                                if (levels[index] != raised) {
                                    levels[index] = raised;
                                    changed = 1;
                                }
                                if (levels[otherindex] != raised) {
                                    levels[otherindex] = raised;
                                    changed = 1;
                                }
                            }
                        }
                        if (k + 1 < nz) {
                            int otherindex = implicitindex(i, j, k + 1, nx, ny);
                            int other = levels[otherindex];
                            if (other >= 0 && other != level) {
                                int raised = level > other ? level : other;
                                if (levels[index] != raised) {
                                    levels[index] = raised;
                                    changed = 1;
                                }
                                if (levels[otherindex] != raised) {
                                    levels[otherindex] = raised;
                                    changed = 1;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

static void implicitadaptive(lua_State *L, points vertices, int mode, int nx, int ny, int nz, double xmin, double ymin, double zmin, double dx, double dy, double dz, double iso, int fp, int fn, double step, int maxrefine, double flatness, double nearsurface)
{
    int cnx = nx - 1;
    int cny = ny - 1;
    int cnz = nz - 1;
    int nofcells = cnx * cny * cnz;
    int *levels = nofcells > 0 ? lmt_memory_malloc(nofcells * sizeof(int)) : NULL;
    if (levels) {
        for (int i = 0; i < nofcells; i++) {
            levels[i] = -1;
        }
        for (int k = 0; k < cnz; k++) {
            for (int j = 0; j < cny; j++) {
                for (int i = 0; i < cnx; i++) {
                    double x0 = xmin + i * dx;
                    double y0 = ymin + j * dy;
                    double z0 = zmin + k * dz;
                    levels[implicitindex(i, j, k, cnx, cny)] = implicitcelllevel(L, x0, y0, z0, dx, dy, dz, fp, iso, flatness, nearsurface, 0, maxrefine);
                }
            }
        }
        implicitbalancelevels(levels, cnx, cny, cnz);
        for (int k = 0; k < cnz; k++) {
            for (int j = 0; j < cny; j++) {
                for (int i = 0; i < cnx; i++) {
                    int level = levels[implicitindex(i, j, k, cnx, cny)];
                    if (level >= 0) {
                        int refine = 1 << level;
                        double sdx = dx / refine;
                        double sdy = dy / refine;
                        double sdz = dz / refine;
                        double xbase = xmin + i * dx;
                        double ybase = ymin + j * dy;
                        double zbase = zmin + k * dz;
                        for (int kk = 0; kk < refine; kk++) {
                            for (int jj = 0; jj < refine; jj++) {
                                for (int ii = 0; ii < refine; ii++) {
                                    tetra c[8];
                                    samplecube(L, c, xbase + ii * sdx, ybase + jj * sdy, zbase + kk * sdz, sdx, sdy, sdz, fp);
                                    polygonizecube(L, vertices, mode, c, iso, fn, step);
                                }
                            }
                        }
                    }
                }
            }
        }
        lmt_memory_free(levels);
    } else {
        implicitregular(L, vertices, mode, nx, ny, nz, xmin, ymin, zmin, dx, dy, dz, iso, fp, fn, step);
    }
}

static void implicitregular(lua_State *L, points vertices, int mode, int nx, int ny, int nz, double xmin, double ymin, double zmin, double dx, double dy, double dz, double iso, int fp, int fn, double step)
{
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
}

static int vectorlib_zbuffer_implicit(lua_State *L)
{
    if (lua_type(L, 1) == LUA_TTABLE) {
        int nx, ny, nz;
        lua_getfield(L, 1, "nx"); nx = lmt_tointeger(L, -1); lua_pop(L, 1);
        lua_getfield(L, 1, "ny"); ny = lmt_tointeger(L, -1); lua_pop(L, 1);
        lua_getfield(L, 1, "nz"); nz = lmt_tointeger(L, -1); lua_pop(L, 1);
        if (nx > 1 && ny > 1 && nz > 1) {
            points vertices = vectorlib_aux_points_push(L, nx * ny * nz * 3, 1, 1);
            if (vertices) {
                double xmin, xmax, ymin, ymax, zmin, zmax, iso, step, dx, dy, dz;
                double flatness, nearsurface;
                int mode, fp, fn, adaptive, maxrefine;
                lua_getfield(L, 1, "xmin");        xmin        = lua_tonumber (L, -1); lua_pop(L, 1);
                lua_getfield(L, 1, "xmax");        xmax        = lua_tonumber (L, -1); lua_pop(L, 1);
                lua_getfield(L, 1, "ymin");        ymin        = lua_tonumber (L, -1); lua_pop(L, 1);
                lua_getfield(L, 1, "ymax");        ymax        = lua_tonumber (L, -1); lua_pop(L, 1);
                lua_getfield(L, 1, "zmin");        zmin        = lua_tonumber (L, -1); lua_pop(L, 1);
                lua_getfield(L, 1, "zmax");        zmax        = lua_tonumber (L, -1); lua_pop(L, 1);
                lua_getfield(L, 1, "iso");         iso         = lua_tonumber (L, -1); lua_pop(L, 1);
                lua_getfield(L, 1, "normalstep");  step        = lua_tonumber (L, -1); lua_pop(L, 1);
                lua_getfield(L, 1, "normalmode");  mode        = lmt_tointeger(L, -1); lua_pop(L, 1);
                lua_getfield(L, 1, "adaptive");    adaptive    = lua_toboolean(L, -1); lua_pop(L, 1);
                lua_getfield(L, 1, "maxrefine");   maxrefine   = lmt_tointeger(L, -1); lua_pop(L, 1);
                lua_getfield(L, 1, "flatness");    flatness    = lua_tonumber (L, -1); lua_pop(L, 1);
                lua_getfield(L, 1, "nearsurface"); nearsurface = lua_tonumber (L, -1); lua_pop(L, 1);
                lua_getfield(L, 1, "fp");          fp          = lua_type(L, -1) == LUA_TFUNCTION ? lua_absindex(L, -1) : 0;
                lua_getfield(L, 1, "fn");          fn          = lua_type(L, -1) == LUA_TFUNCTION ? lua_absindex(L, -1) : 0;
             // lua_getfield(L, 1, "fp");          fp          = lua_type(L, -1) == LUA_TFUNCTION ? 3 : 0;
             // lua_getfield(L, 1, "fn");          fn          = lua_type(L, -1) == LUA_TFUNCTION ? 4 : 0;
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
                if (maxrefine < 0) {
                    maxrefine = 0;
                } else if (maxrefine > 6) {
                    maxrefine = 6;
                }
                if (flatness <= 0) {
                    flatness = 0.25;
                }
                if (nearsurface <= 0) {
                    nearsurface = 1.0;
                }
                if (adaptive && maxrefine > 0) {
                    implicitadaptive(L, vertices, mode, nx, ny, nz, xmin, ymin, zmin, dx, dy, dz, iso, fp, fn, step, maxrefine, flatness, nearsurface);
                } else {
                    implicitregular(L, vertices, mode, nx, ny, nz, xmin, ymin, zmin, dx, dy, dz, iso, fp, fn, step);
                }
                vertices->size = vertices->index;
                lua_pop(L, 2); /* the functions */
                return 1;
            }
        }
    }
    return 0;
}

/* */