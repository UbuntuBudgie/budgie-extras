#include "trash_info.h"

TrashInfo *trash_info_new(gchar *file_name, gchar *file_path, gboolean is_directory) {
    TrashInfo *self = g_slice_new(TrashInfo);
    self->file_name = g_strdup(file_name);
    self->file_path = g_strdup(file_path);
    self->is_directory = is_directory;

    return self;
}

void trash_info_set_from_trashinfo(TrashInfo *self, GFile *info_file, gchar *prefix) {
    g_autoptr(GError) err = NULL;
    g_autoptr(GFileInputStream) input_stream = g_file_read(info_file, NULL, &err);
    if (!input_stream) {
        g_critical("%s:%d: Unable to open .trashinfo file: %s", __BASE_FILE__, __LINE__, err->message);
        return;
    }

    // Seek to the Path line
    g_seekable_seek(G_SEEKABLE(input_stream), TRASH_INFO_PATH_OFFSET, G_SEEK_SET, NULL, NULL);

    // Read the file contents and extract the line containing the restore path
    g_autofree gchar *buffer = (gchar *) malloc(1024 * sizeof(gchar));
    gssize read;
    while ((read = g_input_stream_read(G_INPUT_STREAM(input_stream), buffer, 1024, NULL, &err))) {
        buffer[read] = '\0';
    }

    g_input_stream_close(G_INPUT_STREAM(input_stream), NULL, NULL);

    gchar **lines = g_strsplit(buffer, "\n", 2);
    gchar *restore_path = substring(lines[0], TRASH_INFO_PATH_PREFIX_OFFSET, strlen(lines[0]));
    if (prefix) {
        restore_path = g_strconcat(prefix, G_DIR_SEPARATOR_S, restore_path, NULL);
    }
    g_autofree gchar *deletion_time_str = g_strstrip(substring(lines[1], TRASH_INFO_DELETION_DATE_PREFIX_OFFSET, strlen(lines[1])));
    g_autoptr(GTimeZone) tz = g_time_zone_new_local();
    GDateTime *deletion_time = g_date_time_new_from_iso8601((const gchar *) deletion_time_str, tz);
    g_strfreev(lines);

    self->restore_path = restore_path;
    self->deleted_time = deletion_time;
}
