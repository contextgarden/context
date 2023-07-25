set(potrace_sources

  source/libraries/potrace/src/potracelib.c
  source/libraries/potrace/src/curve.c
  source/libraries/potrace/src/decompose.c
  source/libraries/potrace/src/trace.c

)

add_library(potrace STATIC ${potrace_sources})

target_compile_definitions(potrace PUBLIC
    VERSION="1.16"
)

target_include_directories(potrace PRIVATE
    source/libraries/mimalloc/include
    source/libraries/potrace/src
)
