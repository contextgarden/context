set(filib_sources
    source/libraries/filib/j_acos.c
    source/libraries/filib/j_acot.c
    source/libraries/filib/j_acsh.c
    source/libraries/filib/j_acth.c
    source/libraries/filib/j_asin.c
    source/libraries/filib/j_asnh.c
    source/libraries/filib/j_atan.c
    source/libraries/filib/j_atnh.c
    source/libraries/filib/j_cos.c
    source/libraries/filib/j_cosh.c
    source/libraries/filib/j_cot.c
    source/libraries/filib/j_coth.c
    source/libraries/filib/j_erf.c
    source/libraries/filib/j_ex10.c
    source/libraries/filib/j_exp.c
    source/libraries/filib/j_exp2.c
    source/libraries/filib/j_expm.c
    source/libraries/filib/j_lg10.c
    source/libraries/filib/j_lg1p.c
    source/libraries/filib/j_log.c
    source/libraries/filib/j_log2.c
    source/libraries/filib/j_sin.c
    source/libraries/filib/j_sinh.c
    source/libraries/filib/j_sqr.c
    source/libraries/filib/j_sqrt.c
    source/libraries/filib/j_tan.c
    source/libraries/filib/j_tanh.c
    source/libraries/filib/q_acos.c
    source/libraries/filib/q_acot.c
    source/libraries/filib/q_acsh.c
    source/libraries/filib/q_acth.c
    source/libraries/filib/q_ari.c
    source/libraries/filib/q_asin.c
    source/libraries/filib/q_asnh.c
    source/libraries/filib/q_atan.c
    source/libraries/filib/q_atn1.c
    source/libraries/filib/q_atnh.c
    source/libraries/filib/q_comp.c
    source/libraries/filib/q_cos.c
    source/libraries/filib/q_cos1.c
    source/libraries/filib/q_cosh.c
    source/libraries/filib/q_cot.c
    source/libraries/filib/q_coth.c
    source/libraries/filib/q_cth1.c
    source/libraries/filib/q_ep1.c
    source/libraries/filib/q_epm1.c
    source/libraries/filib/q_erf.c
    source/libraries/filib/q_errm.c
    source/libraries/filib/q_ex10.c
    source/libraries/filib/q_exp.c
    source/libraries/filib/q_exp2.c
    source/libraries/filib/q_expm.c
    source/libraries/filib/q_glbl.c
    source/libraries/filib/q_lg10.c
    source/libraries/filib/q_log.c
    source/libraries/filib/q_log1.c
    source/libraries/filib/q_log2.c
    source/libraries/filib/q_pred.c
  # source/libraries/filib/q_prnt.c
    source/libraries/filib/q_rtrg.c
  # source/libraries/filib/q_scan.c
    source/libraries/filib/q_sin.c
    source/libraries/filib/q_sin1.c
    source/libraries/filib/q_sinh.c
    source/libraries/filib/q_sqr.c
    source/libraries/filib/q_sqrt.c
    source/libraries/filib/q_succ.c
    source/libraries/filib/q_tan.c
    source/libraries/filib/q_tanh.c
)

add_library(filib STATIC ${filib_sources})

target_include_directories(filib PRIVATE
    source/libraries/filib
)

target_compile_options(filib PRIVATE
)