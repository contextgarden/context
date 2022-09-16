Commented line in lptypes.h:

  # include <assert.h>

Added line in lptypes.h:

  # define assert(condition) ((void)0)

Maybe some day lua_assert will be used in lpeg.