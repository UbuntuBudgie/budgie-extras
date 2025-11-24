#include "utils.h"

struct _FileDeleteData {
    int _ref_count;

    const gchar *file_path;
    gboolean is_directory;
};

FileDeleteData *file_delete_data_ref(FileDeleteData *data) {
    g_atomic_int_inc(&data->_ref_count);
    return data;
}

void file_delete_data_unref(gpointer user_data) {
    FileDeleteData *data = (FileDeleteData *) user_data;
    if (g_atomic_int_dec_and_test(&data->_ref_count)) {
        g_free((gchar *) data->file_path);
        g_slice_free(FileDeleteData, data);
    }
}

FileDeleteData *file_delete_data_new(const char *file_path, gboolean is_directory) {
    FileDeleteData *data = g_slice_new0(FileDeleteData);
    data->_ref_count = 1;
    data->file_path = file_path;
    data->is_directory = is_directory;

    return data;
}

gpointer trash_delete_file(FileDeleteData *data) {
    g_autoptr(GFile) file = g_file_new_for_path(data->file_path);
    g_autoptr(GError) err = NULL;
    gboolean success = TRUE;

    if (data->is_directory) {
        success = trash_delete_directory_recursive(data->file_path, &err);
    } else {
        success = g_file_delete(file, NULL, &err);
    }

    if (!success) {
        trash_notify_try_send("Trash Bin Error", err->message, "dialog-error-symbolic");
        g_critical("%s:%d: Error deleting item: %s", __BASE_FILE__, __LINE__, err->message);
    }

    return NULL;
}

gboolean trash_delete_directory_recursive(const gchar *path, GError **err) {
    GFileInfo *file_info;
    g_autoptr(GFile) file = g_file_new_for_path(path);
    g_autoptr(GFileEnumerator) enumerator = g_file_enumerate_children(file,
                                                                      FILE_ATTRIBUTES_STANDARD_NAME_AND_TYPE,
                                                                      G_FILE_QUERY_INFO_NONE,
                                                                      NULL,
                                                                      NULL);

    gboolean success = TRUE;

    // Iterate over all of the children and delete them
    while ((file_info = g_file_enumerator_next_file(enumerator, NULL, NULL))) {
        g_autofree gchar *child_path = g_build_path(G_DIR_SEPARATOR_S, path, g_file_info_get_name(file_info), NULL);

        if (g_file_info_get_file_type(file_info) == G_FILE_TYPE_DIRECTORY) {
            // Directories must be empty to be deleted, so recursively delete all children first
            success = trash_delete_directory_recursive(child_path, err);
        } else {
            // Not a directory, just delete the file
            g_autoptr(GFile) child_file = g_file_new_for_path(child_path);
            success = g_file_delete(child_file, NULL, err);
        }

        g_object_unref(file_info);

        if (!success) {
            return success;
        }
    }

    g_file_enumerator_close(enumerator, NULL, NULL);

    // Delete the current file
    return g_file_delete(file, NULL, err);
}

gchar *substring(gchar *source, gint offset, size_t length) {
    if ((offset + length > strlen(source)) && length != strlen(source)) {
        return NULL;
    }

    if (length == strlen(source)) {
        length = length - offset;
    }

    gchar *dest = malloc(sizeof(gchar) * length + 1);

    strncpy(dest, source + offset, length);
    dest[length] = '\0';
    return dest;
}
