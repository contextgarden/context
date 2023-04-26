set(softposit_sources

# source/libraries/softposit/source/s_addMagsP8.c
# source/libraries/softposit/source/s_subMagsP8.c
# source/libraries/softposit/source/s_mulAddP8.c
# source/libraries/softposit/source/p8_add.c
# source/libraries/softposit/source/p8_sub.c
# source/libraries/softposit/source/p8_mul.c
# source/libraries/softposit/source/p8_div.c
# source/libraries/softposit/source/p8_sqrt.c
# source/libraries/softposit/source/p8_to_p16.c
# source/libraries/softposit/source/p8_to_p32.c
# source/libraries/softposit/source/p8_to_pX2.c
# source/libraries/softposit/source/p8_to_i32.c
# source/libraries/softposit/source/p8_to_i64.c
# source/libraries/softposit/source/p8_to_ui32.c
# source/libraries/softposit/source/p8_to_ui64.c
# source/libraries/softposit/source/p8_roundToInt.c
# source/libraries/softposit/source/p8_mulAdd.c
# source/libraries/softposit/source/p8_eq.c
# source/libraries/softposit/source/p8_le.c
# source/libraries/softposit/source/p8_lt.c
# source/libraries/softposit/source/quire8_fdp_add.c
# source/libraries/softposit/source/quire8_fdp_sub.c
# source/libraries/softposit/source/ui32_to_p8.c
# source/libraries/softposit/source/ui64_to_p8.c
# source/libraries/softposit/source/i32_to_p8.c
# source/libraries/softposit/source/i64_to_p8.c

# source/libraries/softposit/source/s_addMagsP16.c
# source/libraries/softposit/source/s_subMagsP16.c
# source/libraries/softposit/source/s_mulAddP16.c
# source/libraries/softposit/source/p16_to_ui32.c
# source/libraries/softposit/source/p16_to_ui64.c
# source/libraries/softposit/source/p16_to_i32.c
# source/libraries/softposit/source/p16_to_i64.c
# source/libraries/softposit/source/p16_to_p8.c
# source/libraries/softposit/source/p16_to_p32.c
# source/libraries/softposit/source/p16_to_pX2.c
# source/libraries/softposit/source/p16_roundToInt.c
# source/libraries/softposit/source/p16_add.c
# source/libraries/softposit/source/p16_sub.c
# source/libraries/softposit/source/p16_mul.c
# source/libraries/softposit/source/p16_mulAdd.c
# source/libraries/softposit/source/p16_div.c
# source/libraries/softposit/source/p16_eq.c
# source/libraries/softposit/source/p16_le.c
# source/libraries/softposit/source/p16_lt.c
# source/libraries/softposit/source/p16_sqrt.c
# source/libraries/softposit/source/quire16_fdp_add.c
# source/libraries/softposit/source/quire16_fdp_sub.c
# source/libraries/softposit/source/quire_helper.c
# source/libraries/softposit/source/ui32_to_p16.c
# source/libraries/softposit/source/ui64_to_p16.c
# source/libraries/softposit/source/i32_to_p16.c
# source/libraries/softposit/source/i64_to_p16.c

  source/libraries/softposit/source/s_addMagsP32.c
  source/libraries/softposit/source/s_subMagsP32.c
  source/libraries/softposit/source/s_mulAddP32.c
  source/libraries/softposit/source/p32_to_ui32.c
  source/libraries/softposit/source/p32_to_ui64.c
  source/libraries/softposit/source/p32_to_i32.c
  source/libraries/softposit/source/p32_to_i64.c
# source/libraries/softposit/source/p32_to_p8.c
# source/libraries/softposit/source/p32_to_p16.c
##source/libraries/softposit/source/p32_to_pX2.c
  source/libraries/softposit/source/p32_roundToInt.c
  source/libraries/softposit/source/p32_add.c
  source/libraries/softposit/source/p32_sub.c
  source/libraries/softposit/source/p32_mul.c
  source/libraries/softposit/source/p32_mulAdd.c
  source/libraries/softposit/source/p32_div.c
  source/libraries/softposit/source/p32_eq.c
  source/libraries/softposit/source/p32_le.c
  source/libraries/softposit/source/p32_lt.c
  source/libraries/softposit/source/p32_sqrt.c
##source/libraries/softposit/source/quire32_fdp_add.c
##source/libraries/softposit/source/quire32_fdp_sub.c
  source/libraries/softposit/source/ui32_to_p32.c
  source/libraries/softposit/source/ui64_to_p32.c
  source/libraries/softposit/source/i32_to_p32.c
  source/libraries/softposit/source/i64_to_p32.c
  source/libraries/softposit/source/s_approxRecipSqrt_1Ks.c
# source/libraries/softposit/source/c_convertDecToPosit8.c
# source/libraries/softposit/source/c_convertPosit8ToDec.c
# source/libraries/softposit/source/c_convertDecToPosit16.c
# source/libraries/softposit/source/c_convertPosit16ToDec.c
# source/libraries/softposit/source/c_convertQuire8ToPosit8.c
# source/libraries/softposit/source/c_convertQuire16ToPosit16.c
##source/libraries/softposit/source/c_convertQuire32ToPosit32.c
  source/libraries/softposit/source/c_convertDecToPosit32.c
  source/libraries/softposit/source/c_convertPosit32ToDec.c
  source/libraries/softposit/source/c_int.c
##source/libraries/softposit/source/s_addMagsPX2.c
##source/libraries/softposit/source/s_subMagsPX2.c
##source/libraries/softposit/source/s_mulAddPX2.c
##source/libraries/softposit/source/pX2_add.c
##source/libraries/softposit/source/pX2_sub.c
##source/libraries/softposit/source/pX2_mul.c
##source/libraries/softposit/source/pX2_div.c
##source/libraries/softposit/source/pX2_mulAdd.c
##source/libraries/softposit/source/pX2_roundToInt.c
##source/libraries/softposit/source/pX2_sqrt.c
##source/libraries/softposit/source/pX2_eq.c
##source/libraries/softposit/source/pX2_le.c
##source/libraries/softposit/source/pX2_lt.c
##source/libraries/softposit/source/ui32_to_pX2.c
# source/libraries/softposit/source/ui64_to_pX2.c
##source/libraries/softposit/source/i32_to_pX2.c
# source/libraries/softposit/source/i64_to_pX2.c
##source/libraries/softposit/source/c_convertQuireX2ToPositX2.c

)

add_library(softposit STATIC ${softposit_sources})

target_include_directories(softposit PRIVATE
    source/libraries/softposit/source
    source/libraries/softposit/source/include
    source/libraries/softposit/build/Linux-x86_64-GCC
)

target_compile_options(softposit PRIVATE
    -DSOFTPOSIT_FAST_INT64
)