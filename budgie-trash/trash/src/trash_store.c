#include "trash_store.h"

enum {
    PROP_EXP_0,
    PROP_SORT_MODE,
    N_EXP_PROPERTIES
};

static GParamSpec *store_props[N_EXP_PROPERTIES] = {NULL};

struct _TrashStore {
    GtkBox parent_instance;
    GFileMonitor *file_monitor;
    GSList *trashed_files;

    gchar *path_prefix;
    gchar *trash_path;
    gchar *trashinfo_path;
    TrashSortMode sort_mode;

    gboolean restoring;
    gint file_count;

    GtkWidget *header;
    GtkWidget *header_icon;
    GtkWidget *header_label;
    GtkWidget *reveal_icon;
    GtkWidget *delete_btn;
    GtkWidget *restore_btn;

    GtkWidget *file_revealer;
    GtkWidget *file_box;

    TrashRevealer *revealer;
};

struct _TrashStoreClass {
    GtkBoxClass parent_class;
};

static void trash_store_finalize(GObject *obj);
static void trash_store_get_property(GObject *obj, guint prop_id, GValue *val, GParamSpec *spec);
static void trash_store_set_property(GObject *obj, guint prop_id, const GValue *val, GParamSpec *spec);

G_DEFINE_TYPE(TrashStore, trash_store, GTK_TYPE_BOX);

static void trash_store_class_init(TrashStoreClass *klazz) {
    GObjectClass *class = G_OBJECT_CLASS(klazz);
    class->finalize = trash_store_finalize;
    class->get_property = trash_store_get_property;
    class->set_property = trash_store_set_property;

    store_props[PROP_SORT_MODE] = g_param_spec_enum(
        "sort-mode",
        "Sort mode",
        "Set how trashed files should be sorted",
        TRASH_TYPE_SORT_MODE,
        TRASH_SORT_TYPE,
        G_PARAM_CONSTRUCT | G_PARAM_EXPLICIT_NOTIFY | G_PARAM_READWRITE);

    g_object_class_install_properties(class, N_EXP_PROPERTIES, store_props);
}

static void trash_store_get_property(GObject *obj, guint prop_id, GValue *val, GParamSpec *spec) {
    TrashStore *self = TRASH_STORE(obj);

    switch (prop_id) {
        case PROP_SORT_MODE:
            g_value_set_enum(val, self->sort_mode);
            break;
        default:
            G_OBJECT_WARN_INVALID_PROPERTY_ID(obj, prop_id, spec);
            break;
    }
}

static void trash_store_set_property(GObject *obj, guint prop_id, const GValue *val, GParamSpec *spec) {
    TrashStore *self = TRASH_STORE(obj);

    switch (prop_id) {
        case PROP_SORT_MODE:
            self->sort_mode = g_value_get_enum(val);
            gtk_list_box_invalidate_sort(GTK_LIST_BOX(self->file_box));
            g_object_notify_by_pspec(obj, store_props[PROP_SORT_MODE]);
            break;
        default:
            G_OBJECT_WARN_INVALID_PROPERTY_ID(obj, prop_id, spec);
            break;
    }
}

static void trash_store_init(TrashStore *self) {
    self->restoring = FALSE;
    self->file_count = 0;
    self->trashed_files = NULL;

    GtkStyleContext *style = gtk_widget_get_style_context(GTK_WIDGET(self));
    gtk_style_context_add_class(style, "trash-store-widget");
    gtk_widget_set_vexpand(GTK_WIDGET(self), TRUE);

    // Create our header box
    GtkWidget *header_event_box = gtk_event_box_new();
    GtkStyleContext *header_style = gtk_widget_get_style_context(header_event_box);
    gtk_style_context_add_class(header_style, "trash-store-header");
    g_signal_connect_object(header_event_box, "button-press-event", G_CALLBACK(trash_store_handle_header_clicked), self, 0);

    self->header = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0);
    gtk_widget_set_size_request(self->header, -1, 48);

    self->delete_btn = gtk_button_new_from_icon_name("list-remove-all-symbolic", GTK_ICON_SIZE_SMALL_TOOLBAR);
    gtk_widget_set_tooltip_text(self->delete_btn, "Clear All");
    g_signal_connect_object(GTK_BUTTON(self->delete_btn), "clicked", G_CALLBACK(trash_store_handle_header_btn_clicked), self, 0);
    self->restore_btn = gtk_button_new_from_icon_name("edit-undo-symbolic", GTK_ICON_SIZE_SMALL_TOOLBAR);
    gtk_widget_set_tooltip_text(self->restore_btn, "Restore All");
    g_signal_connect_object(GTK_BUTTON(self->restore_btn), "clicked", G_CALLBACK(trash_store_handle_header_btn_clicked), self, 0);
    gtk_box_pack_end(GTK_BOX(self->header), self->delete_btn, FALSE, FALSE, 0);
    gtk_box_pack_end(GTK_BOX(self->header), self->restore_btn, FALSE, FALSE, 0);

    // Create our revealer object
    self->revealer = trash_revealer_new();
    gtk_revealer_set_transition_type(GTK_REVEALER(self->revealer), GTK_REVEALER_TRANSITION_TYPE_SLIDE_DOWN);
    gtk_revealer_set_reveal_child(GTK_REVEALER(self->revealer), FALSE);

    g_signal_connect_object(GTK_BUTTON(self->revealer->cancel_button), "clicked", G_CALLBACK(trash_store_handle_cancel_clicked), self, 0);
    g_signal_connect_object(GTK_BUTTON(self->revealer->confirm_button), "clicked", G_CALLBACK(trash_store_handle_confirm_clicked), self, 0);

    self->file_revealer = gtk_revealer_new();
    gtk_revealer_set_transition_type(GTK_REVEALER(self->file_revealer), GTK_REVEALER_TRANSITION_TYPE_SLIDE_DOWN);
    gtk_revealer_set_reveal_child(GTK_REVEALER(self->file_revealer), TRUE);

    // Create our file list
    self->file_box = gtk_list_box_new();
    GtkStyleContext *file_box_style = gtk_widget_get_style_context(self->file_box);
    gtk_style_context_add_class(file_box_style, "trash-file-box");
    gtk_style_context_add_class(file_box_style, "empty");
    gtk_list_box_set_activate_on_single_click(GTK_LIST_BOX(self->file_box), TRUE);
    gtk_list_box_set_selection_mode(GTK_LIST_BOX(self->file_box), GTK_SELECTION_NONE);
    gtk_list_box_set_sort_func(GTK_LIST_BOX(self->file_box), (GtkListBoxSortFunc) trash_store_sort, self, NULL);

    g_signal_connect_object(self->file_box, "row-activated", G_CALLBACK(trash_store_handle_row_activated), self, 0);

    gtk_container_add(GTK_CONTAINER(self->file_revealer), self->file_box);

    // Pack ourselves up
    trash_store_apply_button_styles(self);

    gtk_container_add(GTK_CONTAINER(header_event_box), self->header);

    gtk_box_pack_start(GTK_BOX(self), header_event_box, TRUE, TRUE, 0);
    gtk_box_pack_start(GTK_BOX(self), GTK_WIDGET(self->revealer), FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(self), self->file_revealer, TRUE, TRUE, 0);
}

static void trash_store_finalize(GObject *obj) {
    TrashStore *self = TRASH_STORE(obj);

    if (self->trashed_files) {
        // Not trying to free the widgets stored in the list because
        // I'm suspecting that they're already free'd by the time we
        // get here due to the container being destroyed by this point.
        g_slist_free(self->trashed_files);
    }

    g_free(self->path_prefix);
    g_free(self->trash_path);
    g_free(self->trashinfo_path);

    G_OBJECT_CLASS(trash_store_parent_class)->finalize(obj);
}

TrashStore *trash_store_new(gchar *drive_name, GIcon *icon, TrashSortMode mode) {
    TrashStore *self = g_object_new(TRASH_TYPE_STORE, "orientation", GTK_ORIENTATION_VERTICAL, "sort-mode", mode, NULL);
    self->trash_path = g_build_path(G_DIR_SEPARATOR_S, g_get_user_data_dir(), "Trash", "files", NULL);
    self->trashinfo_path = g_build_path(G_DIR_SEPARATOR_S, g_get_user_data_dir(), "Trash", "info", NULL);
    self->path_prefix = NULL;

    self->header_icon = gtk_image_new_from_gicon(icon, GTK_ICON_SIZE_SMALL_TOOLBAR);
    gtk_box_pack_start(GTK_BOX(self->header), self->header_icon, FALSE, FALSE, 0);

    self->header_label = gtk_label_new(g_strdup(drive_name));
    gtk_label_set_max_width_chars(GTK_LABEL(self->header_label), 30);
    gtk_label_set_ellipsize(GTK_LABEL(self->header_label), PANGO_ELLIPSIZE_END);
    gtk_widget_set_halign(self->header_label, GTK_ALIGN_START);
    gtk_label_set_justify(GTK_LABEL(self->header_label), GTK_JUSTIFY_LEFT);
    gtk_box_pack_start(GTK_BOX(self->header), self->header_label, TRUE, TRUE, 0);

    gtk_widget_set_tooltip_text(self->header, g_strdup(drive_name));

    self->reveal_icon = gtk_image_new_from_icon_name("pan-down-symbolic", GTK_ICON_SIZE_SMALL_TOOLBAR);
    gtk_box_pack_start(GTK_BOX(self->header), self->reveal_icon, FALSE, FALSE, 0);

    gtk_widget_show_all(GTK_WIDGET(self));

    return self;
}

TrashStore *trash_store_new_with_extras(gchar *drive_name,
                                        TrashSortMode mode,
                                        GIcon *icon,
                                        gchar *path_prefix,
                                        gchar *trash_path,
                                        gchar *trashinfo_path) {
    TrashStore *self = trash_store_new(drive_name, icon, mode);
    self->path_prefix = g_strdup(path_prefix);

    if (self->trash_path) {
        g_free(self->trash_path);
    }
    if (self->trashinfo_path) {
        g_free(self->trashinfo_path);
    }

    self->trash_path = g_strdup(trash_path);
    self->trashinfo_path = g_strdup(trashinfo_path);

    return self;
}

void trash_store_apply_button_styles(TrashStore *self) {
    GtkStyleContext *delete_style = gtk_widget_get_style_context(self->delete_btn);
    gtk_style_context_add_class(delete_style, "flat");
    gtk_style_context_remove_class(delete_style, "button");
    GtkStyleContext *restore_style = gtk_widget_get_style_context(self->restore_btn);
    gtk_style_context_add_class(restore_style, "flat");
    gtk_style_context_remove_class(restore_style, "button");
}

void trash_store_set_btns_sensitive(TrashStore *self, gboolean sensitive) {
    gtk_widget_set_sensitive(self->delete_btn, sensitive);
    gtk_widget_set_sensitive(self->restore_btn, sensitive);
}

void trash_store_check_empty(TrashStore *self) {
    GtkStyleContext *file_box_style = gtk_widget_get_style_context(self->file_box);

    if (self->file_count > 0) {
        gtk_style_context_remove_class(file_box_style, "empty");
        trash_store_set_btns_sensitive(self, TRUE);
    } else {
        if (!gtk_style_context_has_class(file_box_style, "empty")) {
            gtk_style_context_add_class(file_box_style, "empty");
        }

        trash_store_set_btns_sensitive(self, FALSE);
    }
}

void trash_store_start_monitor(TrashStore *self) {
    GFile *dir = g_file_new_for_path(self->trash_path);
    g_autoptr(GError) err = NULL;
    self->file_monitor = g_file_monitor_directory(dir, G_FILE_MONITOR_WATCH_MOVES, NULL, &err);
    g_signal_connect_object(self->file_monitor, "changed", G_CALLBACK(trash_store_handle_monitor_event), self, 0);
}

gboolean trash_store_handle_header_clicked(__attribute__((unused)) GtkWidget *sender, GdkEventButton *event, TrashStore *self) {
    switch (event->type) {
        case GDK_BUTTON_PRESS:
            if (gtk_revealer_get_child_revealed(GTK_REVEALER(self->file_revealer))) {
                gtk_revealer_set_reveal_child(GTK_REVEALER(self->file_revealer), FALSE);
                gtk_image_set_from_icon_name(GTK_IMAGE(self->reveal_icon), "pan-start-symbolic", GTK_ICON_SIZE_SMALL_TOOLBAR);
            } else {
                gtk_revealer_set_reveal_child(GTK_REVEALER(self->file_revealer), TRUE);
                gtk_image_set_from_icon_name(GTK_IMAGE(self->reveal_icon), "pan-down-symbolic", GTK_ICON_SIZE_SMALL_TOOLBAR);
            }

            return TRUE;
        default:
            return FALSE;
    }

    return FALSE;
}

void trash_store_handle_header_btn_clicked(GtkButton *sender, TrashStore *self) {
    if (sender == GTK_BUTTON(self->delete_btn)) {
        self->restoring = FALSE;
        trash_revealer_set_text(self->revealer, "<b>Permanently delete all items in the trash bin?</b>", TRUE);
    } else {
        self->restoring = TRUE;
        trash_revealer_set_text(self->revealer, "<b>Restore all items from the trash bin?</b>", FALSE);
    }

    trash_store_set_btns_sensitive(self, FALSE);
    gtk_revealer_set_reveal_child(GTK_REVEALER(self->revealer), TRUE);
}

void trash_store_handle_cancel_clicked(__attribute__((unused)) GtkButton *sender, TrashStore *self) {
    trash_store_set_btns_sensitive(self, TRUE);
    gtk_revealer_set_reveal_child(GTK_REVEALER(self->revealer), FALSE);
}

void trash_store_handle_confirm_clicked(__attribute__((unused)) GtkButton *sender, TrashStore *self) {
    g_autoptr(GError) err = NULL;
    g_slist_foreach(self->trashed_files, self->restoring ? (GFunc) trash_item_restore : (GFunc) trash_item_delete, &err);
    if (err) {
        trash_notify_try_send("Trash Bin Error", err->message, "dialog-error-symbolic");
    }

    if (self->restoring) {
        trash_notify_try_send("Trash Restored", "All trashed files have been restored", NULL);
    } else {
        trash_notify_try_send("Trash Cleared", "All files cleared from the trash", NULL);
    }

    trash_store_set_btns_sensitive(self, TRUE);
    gtk_revealer_set_reveal_child(GTK_REVEALER(self->revealer), FALSE);
}

void trash_store_handle_row_activated(__attribute__((unused)) GtkListBox *sender, GtkListBoxRow *row, __attribute__((unused)) TrashStore *self) {
    GtkWidget *child = gtk_bin_get_child(GTK_BIN(row));
    trash_item_toggle_info_revealer(TRASH_ITEM(child));
}

void trash_store_handle_monitor_event(__attribute__((unused)) GFileMonitor *monitor,
                                      GFile *file,
                                      __attribute__((unused)) GFile *other_file,
                                      GFileMonitorEvent event_type,
                                      TrashStore *self) {
    switch (event_type) {
        case G_FILE_MONITOR_EVENT_MOVED_IN: {
            TrashItem *trash_item = trash_store_create_trash_item(self, g_file_get_path(file));

            gtk_list_box_insert(GTK_LIST_BOX(self->file_box), GTK_WIDGET(trash_item), -1);
            self->trashed_files = g_slist_append(self->trashed_files, trash_item);
            self->file_count++;

            trash_store_check_empty(self);
            break;
        }
        case G_FILE_MONITOR_EVENT_MOVED_OUT:
        case G_FILE_MONITOR_EVENT_DELETED: {
            g_autofree gchar *file_name = g_file_get_basename(file);

            // Delete the .trashinfo file
            g_autofree gchar *info_file_name = g_build_path(G_DIR_SEPARATOR_S, self->trashinfo_path, g_strconcat(file_name, ".trashinfo", NULL), NULL);
            g_autoptr(GFile) info_file = g_file_new_for_path(info_file_name);
            g_file_delete(info_file, NULL, NULL);

            GSList *elem = g_slist_find_custom(self->trashed_files, file_name, (GCompareFunc) trash_item_has_name);
            TrashItem *trash_item = (TrashItem *) g_slist_nth_data(self->trashed_files,
                                                                   g_slist_position(self->trashed_files, elem));
            g_return_if_fail(trash_item != NULL);

            GtkWidget *row = gtk_widget_get_parent(GTK_WIDGET(trash_item));
            gtk_container_remove(GTK_CONTAINER(self->file_box), row);
            self->file_count--;
            trash_store_check_empty(self);
            self->trashed_files = g_slist_remove(self->trashed_files, trash_item);
            break;
        }
        default:
            break;
    }
}

void trash_store_load_items(TrashStore *self, GError *err) {
    // Open our trash directory
    g_autoptr(GFile) trash_dir = g_file_new_for_path(self->trash_path);
    g_autoptr(GFileEnumerator) enumerator = g_file_enumerate_children(trash_dir,
                                                                      G_FILE_ATTRIBUTE_STANDARD_NAME,
                                                                      G_FILE_QUERY_INFO_NONE,
                                                                      NULL,
                                                                      &err);
    if G_UNLIKELY (!enumerator) {
        g_critical("%s:%d: Error getting file enumerator for trash files in '%s': %s", __BASE_FILE__, __LINE__, self->trash_path, err->message);
        return;
    }

    // Iterate over the directory's children and append each file name to a list
    g_autoptr(GFileInfo) current_file = NULL;
    while ((current_file = g_file_enumerator_next_file(enumerator, NULL, &err))) {
        gchar *path = g_build_path(G_DIR_SEPARATOR_S, self->trash_path, g_file_info_get_name(current_file), NULL);
        TrashItem *trash_item = trash_store_create_trash_item(self, path);

        gtk_list_box_insert(GTK_LIST_BOX(self->file_box), GTK_WIDGET(trash_item), -1);
        self->trashed_files = g_slist_append(self->trashed_files, trash_item);
        self->file_count++;
    }

    trash_store_check_empty(self);
    g_file_enumerator_close(enumerator, NULL, NULL);
}

TrashItem *trash_store_create_trash_item(TrashStore *self, gchar *path) {
    g_autoptr(GFile) file = g_file_new_for_path(path);
    g_autofree gchar *attributes = g_strconcat(G_FILE_ATTRIBUTE_STANDARD_NAME, ",",
                                               G_FILE_ATTRIBUTE_STANDARD_ICON, ",",
                                               G_FILE_ATTRIBUTE_STANDARD_TYPE,
                                               NULL);
    g_autoptr(GFileInfo) file_info = g_file_query_info(file, attributes, G_FILE_QUERY_INFO_NONE, NULL, NULL);

    gchar *file_name = (gchar *) g_file_info_get_name(file_info);
    g_autofree gchar *info_file_path = g_build_path(G_DIR_SEPARATOR_S, self->trashinfo_path, g_strconcat(file_name, ".trashinfo", NULL), NULL);
    g_autoptr(GFile) info_file = g_file_new_for_path(info_file_path);
    TrashInfo *trash_info = NULL;

    trash_info = trash_info_new(file_name,
                                g_build_path(G_DIR_SEPARATOR_S, self->trash_path, file_name, NULL),
                                (g_file_info_get_file_type(file_info) == G_FILE_TYPE_DIRECTORY));
    trash_info_set_from_trashinfo(trash_info, info_file, self->path_prefix);

    TrashItem *trash_item = trash_item_new(g_file_info_get_icon(file_info), trash_info);
    gtk_widget_show_all(GTK_WIDGET(trash_item));

    return trash_item;
}

gchar *trash_store_read_trash_info(gchar *trashinfo_path, GError **err) {
    // Open the file
    g_autoptr(GFile) info_file = g_file_new_for_path(trashinfo_path);
    g_autoptr(GFileInputStream) input_stream = g_file_read(info_file, NULL, err);
    if (!input_stream) {
        return NULL;
    }

    // Seek to the Path line
    g_seekable_seek(G_SEEKABLE(input_stream), TRASH_INFO_PATH_OFFSET, G_SEEK_SET, NULL, err);

    // Read the file contents and extract the line containing the restore path
    gchar *buffer = (gchar *) malloc(1024 * sizeof(gchar));
    gssize read;
    while ((read = g_input_stream_read(G_INPUT_STREAM(input_stream), buffer, 1024, NULL, err))) {
        buffer[read] = '\0';
    }

    g_input_stream_close(G_INPUT_STREAM(input_stream), NULL, NULL);

    return buffer;
}

gint trash_store_sort(GtkListBoxRow *row1, GtkListBoxRow *row2, TrashStore *self) {
    TrashItem *item1 = TRASH_ITEM(gtk_bin_get_child(GTK_BIN(row1)));
    TrashItem *item2 = TRASH_ITEM(gtk_bin_get_child(GTK_BIN(row2)));

    switch (self->sort_mode) {
        case TRASH_SORT_A_Z:
            return trash_item_collate_by_name(item1, item2);
        case TRASH_SORT_Z_A:
            return trash_item_collate_by_name(item2, item1);
        case TRASH_SORT_DATE_ASCENDING:
            return trash_item_collate_by_date(item2, item1);
        case TRASH_SORT_DATE_DESCENDING:
            return trash_item_collate_by_date(item1, item2);
        case TRASH_SORT_TYPE:
            return trash_item_collate_by_type(item1, item2);
        default:
            g_critical("%s:%d: Unknown sort mode '%d', defaulting to by type", __BASE_FILE__, __LINE__, self->sort_mode);
            return trash_item_collate_by_type(item1, item2);
    }
}
