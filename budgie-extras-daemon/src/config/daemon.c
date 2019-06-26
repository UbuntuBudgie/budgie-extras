#ifndef CONFIG_H_INCLUDED
#include "config.h"

/**
 * All this is to keep Vala happy & configured..
 */
const char *BUDGIE_EXTRAS_DATADIR = DATADIR;
const char *BUDGIE_EXTRAS_SYSCONFDIR = SYSCONFDIR;

#else
#error config.h missing!
#endif

