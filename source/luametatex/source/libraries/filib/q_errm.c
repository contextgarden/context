/* fi_lib: interval library version 1.2, for copyright see fi_lib.h */

# include "fi_lib.h"

/*
    This module has been adapted so that we can plug-in a error handler which is nicer when
    we use the library from LUA. The abstraction is also less error prone. (HH)
*/

# include <stdlib.h> /* for exit */

const char *fi_lib_function_names[] = {
    "acos",
    "acot",
    "acsh",
    "acth",
    "asin",
    "asnh",
    "atan",
    "atnh",
    "cmps",
    "comp",
    "cos",
    "cos1",
    "cosh",
    "cot",
    "coth",
    "ep1",
    "epm1",
    "erf",
    "erfc",
    "ex10",
    "exp",
    "exp2",
    "expm",
    "l1p1",
    "lg10",
    "lg1p",
    "log",
    "log1",
    "log2",
    "sin",
    "sin1",
    "sinh",
    "sqr",
    "sqrt",
    "tan",
    "tanh",
    "div_id",
};

/* ----------- error handling for argument == NaN ---------------*/

int (* fi_lib_error_handler) (int kind, const char *name, double one, double two) = NULL;

double q_abortnan(int n, double *x, int fctn)
{
    if (fctn >= 0 && fctn < fi_lib_last) {
        if (fi_lib_error_handler) {
            int code = fi_lib_error_handler(
                fi_lib_error_nan,
                fi_lib_function_names[fctn], 0, 0
            );
            if (code) {
                exit(code);
            }
        } else {
            printf(
                "\nfi_lib error: %s in function '%s'\n",
                "nan",
                fi_lib_function_names[fctn]
            );
            exit(n);
        }
    }
    return *x;
}

/* ------------ error handling for point arguments ---------------*/

double q_abortr1(int n, double *x, int fctn)
{
    if (fctn >= 0 && fctn < fi_lib_last) {
        if (fi_lib_error_handler) {
            int code = fi_lib_error_handler(
                n == FI_LIB_INV_ARG ? fi_lib_error_invalid_double : fi_lib_error_overflow_double,
                fi_lib_function_names[fctn], *x, 0
            );
            if (code) {
                exit(code);
            }
        } else {
            printf(
                "\nfi_lib error: %s in function '%s' %24.15e\n",
                n == FI_LIB_INV_ARG ? "invalid number" : "overflow",
                fi_lib_function_names[fctn], *x
            );
            exit(n);
        }
    }
    return *x;
}

/* ------------- error handling for interval arguments -------------*/

interval q_abortr2(int n, double *x1, double *x2, int fctn)
{
    interval res;
    if (fctn >= 0 && fctn < fi_lib_last) {
        if (fi_lib_error_handler) {
            int code = fi_lib_error_handler(
                n == FI_LIB_INV_ARG ? fi_lib_error_invalid_interval : fi_lib_error_overflow_interval,
                fi_lib_function_names[fctn], *x1, *x2
            );
            if (code) {
                exit(code);
            }
        } else {
            printf(
                "\nfi_lib error: %s in function '%s' [%24.15e .. %24.15e]\n",
                n == FI_LIB_INV_ARG ? "invalid number" : "overflow",
                fi_lib_function_names[fctn], *x1, *x2
            );
            exit(n);
        }
    }
    res.INF = *x1;
    res.SUP = *x2;
    return res;
}

/* ------------ error handling for point arguments ---------------*/

double q_abortdivd(int n, double *x)
{
    if (fi_lib_error_handler) {
        int code = fi_lib_error_handler(
            fi_lib_error_zero_division_double,
            fi_lib_function_names[fi_lib_div_id], *x, 0
        );
        if (code) {
            exit(code);
        }
    } else {
        printf(
            "\nfi_lib error: %s in function '%s' %24.15e\n",
            "division by zero",
            fi_lib_function_names[fi_lib_div_id], *x
        );
        exit(n);
    }
    return *x;
}

/* ------------- error handling for interval arguments -------------*/

interval q_abortdivi(int n, double *x1, double *x2)
{
    interval res;
    if (fi_lib_error_handler) {
        int code = fi_lib_error_handler(
            fi_lib_error_zero_division_interval,
            fi_lib_function_names[fi_lib_div_id], *x1, *x2
        );
        if (code) {
            exit(code);
        }
    } else {
        printf(
            "\nfi_lib error: %s in function '%s' [%24.15e .. %24.15e]\n",
            "division by zero",
            fi_lib_function_names[fi_lib_div_id], *x1, *x2
        );
        exit(n);
    }
    res.INF = *x1;
    res.SUP = *x2;
    return res;
}

/* ------------- just a chedker ------------------------------------*/

int q_usedendian(void) /* returns 1 for little endian */
{
    return FI_LIB_USEDENDIAN;
}

/* ------------- we can plug in an error handler -------------------*/

void q_usehandler(void *f)
{
    fi_lib_error_handler = f;
}