#pragma once

#include "utils.h"
#include <gio/gio.h>

/**
 * The offset to the beginning of the line containing the
 * restore path.
 */
#define TRASH_INFO_PATH_OFFSET 13

/**
 * The offset from the beginning of a line to the start of
 * the restore path in a trash info file.
 */
#define TRASH_INFO_PATH_PREFIX_OFFSET 5

/**
 * The offset to the beginning of the date from the start
 * of a line.
 */
#define TRASH_INFO_DELETION_DATE_PREFIX_OFFSET 13

typedef struct {
    GObject parent_instance;

    gchar *file_name;
    gchar *file_path;

    gboolean is_directory;

    gchar *restore_path;
    GDateTime *deleted_time;
} TrashInfo;

typedef struct {
    GObjectClass parent_class;
} TrashInfoClass;

/**
 * Create a new TrashInfo struct.
 */
TrashInfo *trash_info_new(gchar *file_name, gchar *file_path, gboolean is_directory);

/**
 * Set fields of the TrashInfo struct that have to be read
 * from the .trashinfo file.
 */
void trash_info_set_from_trashinfo(TrashInfo *self, GFile *info_file, gchar *prefix);
