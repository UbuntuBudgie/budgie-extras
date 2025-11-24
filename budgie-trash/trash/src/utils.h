#pragma once

#include "notify.h"
#include <gio/gio.h>
#include <string.h>

#define FILE_ATTRIBUTES_STANDARD_NAME_AND_TYPE "standard::name,standard::type"

typedef struct _FileDeleteData FileDeleteData;

FileDeleteData *file_delete_data_new(const char *path, gboolean is_directory);
FileDeleteData *file_delete_data_ref(FileDeleteData *data);
void file_delete_data_unref(gpointer user_data);

/**
 * Attempt to delete a file from the disk.
 *
 * If the file is a directory, this function will recursively delete
 * the entire file tree inside the directory because directories
 * must be empty in order to be deleted.
 */
gpointer trash_delete_file(FileDeleteData *data);

/**
 * Recursively attempt to delete an entire directory tree from the
 * disk.
 *
 * On error, FALSE is returned and err is set.
 */
gboolean trash_delete_directory_recursive(const gchar *path, GError **err);

/**
 * Returns a new string consisting of the substring of the full string
 * starting at `offset` and going until `length`.
 *
 * The returned string should be freed with `g_free()`.
 */
gchar *substring(gchar *source, gint offset, size_t length);
