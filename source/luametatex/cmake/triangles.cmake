set(triangles_sources
  source/libraries/triangles/triangles.c
)

add_library(triangles STATIC ${triangles_sources})

# add_compile_options(
#     -fno-signed-zeros
#     -fno-trapping-math    
#     -fno-math-errno
# )

target_include_directories(triangles PRIVATE
    source/libraries/triangles
)