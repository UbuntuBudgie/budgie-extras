#define _GNU_SOURCE

#include "applet.h"
#include <libnotify/notify.h>
#include <unistd.h>

struct _TrashAppletPrivate {
    BudgiePopoverManager *manager;
    GHashTable *mounts;

    GSettings *settings;

    GtkWidget *popover;
    GtkWidget *stack;
    GtkWidget *drive_box;
    GtkWidget *settings_button;
    GtkWidget *return_button;
    TrashIconButton *icon_button;

    gint uid;
    GVolumeMonitor *volume_monitor;
};

G_DEFINE_DYNAMIC_TYPE_EXTENDED(TrashApplet, trash_applet, BUDGIE_TYPE_APPLET, 0, G_ADD_PRIVATE_DYNAMIC(TrashApplet))

/**
 * Handle cleanup of the applet.
 */
static void trash_applet_finalize(GObject *object) {
    TrashAppletPrivate *priv = trash_applet_get_instance_private(TRASH_APPLET(object));

    g_hash_table_destroy(priv->mounts);
    g_object_unref(priv->volume_monitor);
    if (priv->settings) {
        g_clear_object(&priv->settings);
    }

    G_OBJECT_CLASS(trash_applet_parent_class)->finalize(object);
}

/**
 * Register our popover with the Budgie popover manager.
 */
static void trash_applet_update_popovers(BudgieApplet *base, BudgiePopoverManager *manager) {
    TrashApplet *self = TRASH_APPLET(base);
    budgie_popover_manager_register_popover(manager,
                                            GTK_WIDGET(self->priv->icon_button),
                                            BUDGIE_POPOVER(self->priv->popover));
    self->priv->manager = manager;
}

/**
 * Initialize the Trash Applet class.
 */
static void trash_applet_class_init(TrashAppletClass *klazz) {
    GObjectClass *class = G_OBJECT_CLASS(klazz);
    class->finalize = trash_applet_finalize;

    // Set our function to update popovers
    BUDGIE_APPLET_CLASS(klazz)->update_popovers = trash_applet_update_popovers;
    BUDGIE_APPLET_CLASS(klazz)->supports_settings = FALSE;
}

/**
 * Handle cleanup of the applet class.
 */
static void trash_applet_class_finalize(__budgie_unused__ TrashAppletClass *klass) {
    notify_uninit();
}

/**
 * Initialization of basic UI elements and loads our CSS
 * style stuff.
 */
static void trash_applet_init(TrashApplet *self) {
    // Create our 'private' struct
    self->priv = trash_applet_get_instance_private(self);
    self->priv->mounts = g_hash_table_new(g_str_hash, g_str_equal);
    self->priv->settings = g_settings_new(TRASH_SETTINGS_SCHEMA_ID);
    g_signal_connect_object(self->priv->settings, "changed", G_CALLBACK(trash_handle_setting_changed), self, 0);

    // Load our CSS
    GtkCssProvider *provider = gtk_css_provider_new();
    gtk_css_provider_load_from_resource(provider, "/com/github/EbonJaeger/budgie-trash-applet/style.css");
    gtk_style_context_add_provider_for_screen(gdk_screen_get_default(),
                                              GTK_STYLE_PROVIDER(provider),
                                              GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);

    // Create our panel widget
    self->priv->icon_button = trash_icon_button_new();
    g_signal_connect_object(GTK_BUTTON(self->priv->icon_button), "clicked", G_CALLBACK(trash_toggle_popover), self, 0);
    gtk_container_add(GTK_CONTAINER(self), GTK_WIDGET(self->priv->icon_button));

    // Create our popover widget
    self->priv->popover = budgie_popover_new(GTK_WIDGET(self->priv->icon_button));

    self->priv->stack = gtk_stack_new();
    gtk_stack_set_transition_type(GTK_STACK(self->priv->stack), GTK_STACK_TRANSITION_TYPE_SLIDE_LEFT_RIGHT);

    TrashSortMode sort_mode = g_settings_get_enum(self->priv->settings, TRASH_SETTINGS_KEY_SORT_MODE);
    GtkWidget *main_view = trash_create_main_view(self, sort_mode);
    gtk_widget_set_size_request(main_view, 300, -1);
    gtk_stack_add_named(GTK_STACK(self->priv->stack), main_view, "main");

    TrashSettings *settings_view = trash_settings_new();
    gtk_stack_add_named(GTK_STACK(self->priv->stack), GTK_WIDGET(settings_view), "settings");
    g_signal_connect_object(settings_view, "return-clicked", G_CALLBACK(trash_handle_return), self, 0);

    gtk_stack_set_visible_child_name(GTK_STACK(self->priv->stack), "main");
    gtk_widget_show_all(GTK_WIDGET(self->priv->stack));

    gtk_container_add(GTK_CONTAINER(self->priv->popover), self->priv->stack);
    gtk_widget_show_all(GTK_WIDGET(self));

    // Register notifications
    notify_init("com.github.EbonJaeger.budgie-trash-applet");

    // Setup our volume monitor to get trashbins for
    // removable drives
    self->priv->uid = getuid();
    self->priv->volume_monitor = g_volume_monitor_get();
    g_autoptr(GList) mounts = g_volume_monitor_get_mounts(self->priv->volume_monitor);
    g_list_foreach(mounts, (GFunc) trash_add_mount, self);

    g_signal_connect_object(self->priv->volume_monitor, "mount-added", G_CALLBACK(trash_handle_mount_added), self, G_CONNECT_AFTER);
    g_signal_connect_object(self->priv->volume_monitor, "mount-removed", G_CALLBACK(trash_handle_mount_removed), self, G_CONNECT_AFTER);

    // Setup drag and drop to trash files
    gtk_drag_dest_set(GTK_WIDGET(self),
                      GTK_DEST_DEFAULT_ALL,
                      gtk_target_entry_new("text/uri-list", 0, 0),
                      1,
                      GDK_ACTION_COPY);

    g_signal_connect_object(self, "drag-data-received", G_CALLBACK(trash_drag_data_received), self, 0);
}

void trash_applet_init_gtype(GTypeModule *module) {
    trash_applet_register_type(module);
}

BudgieApplet *trash_applet_new(void) {
    return g_object_new(TRASH_TYPE_APPLET, NULL);
}

GtkWidget *trash_create_main_view(TrashApplet *self, TrashSortMode sort_mode) {
    GtkWidget *main_view = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);

    // Create our popover header
    GtkWidget *header = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0);
    GtkStyleContext *header_style = gtk_widget_get_style_context(header);
    gtk_style_context_add_class(header_style, "trash-applet-header");
    GtkWidget *header_label = gtk_label_new("Trash");
    GtkStyleContext *header_label_style = gtk_widget_get_style_context(header_label);
    gtk_style_context_add_class(header_label_style, "title");
    gtk_box_pack_start(GTK_BOX(header), header_label, TRUE, TRUE, 0);

    // Create our scroller
    GtkWidget *scroller = gtk_scrolled_window_new(NULL, NULL);
    gtk_scrolled_window_set_min_content_height(GTK_SCROLLED_WINDOW(scroller), 300);
    gtk_scrolled_window_set_max_content_height(GTK_SCROLLED_WINDOW(scroller), 300);
    gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scroller), GTK_POLICY_NEVER, GTK_POLICY_AUTOMATIC);

    // Create the listbox that the mounted drives will go into
    self->priv->drive_box = gtk_list_box_new();
    gtk_widget_set_size_request(self->priv->drive_box, -1, 300);
    gtk_list_box_set_activate_on_single_click(GTK_LIST_BOX(self->priv->drive_box), TRUE);
    gtk_list_box_set_selection_mode(GTK_LIST_BOX(self->priv->drive_box), GTK_SELECTION_NONE);
    GtkStyleContext *drive_box_style = gtk_widget_get_style_context(self->priv->drive_box);
    gtk_style_context_add_class(drive_box_style, "trash-applet-list");
    gtk_container_add(GTK_CONTAINER(scroller), self->priv->drive_box);

    // Create the trash store widgets
    TrashStore *default_store = trash_store_new("This PC", g_icon_new_for_string("drive-harddisk-symbolic", NULL), sort_mode);
    g_autoptr(GError) err = NULL;
    trash_store_load_items(default_store, err);
    if (err) {
        g_critical("%s:%d: Error loading trash items for the default trash store: %s", __BASE_FILE__, __LINE__, err->message);
    }
    trash_store_start_monitor(default_store);

    g_hash_table_insert(self->priv->mounts, "This PC", default_store);
    gtk_list_box_insert(GTK_LIST_BOX(self->priv->drive_box), GTK_WIDGET(default_store), -1);

    // Footer
    GtkWidget *footer = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0);
    GtkStyleContext *footer_style = gtk_widget_get_style_context(footer);
    gtk_style_context_add_class(footer_style, "trash-applet-footer");

    self->priv->settings_button = gtk_button_new_from_icon_name("emblem-system-symbolic", GTK_ICON_SIZE_BUTTON);
    gtk_widget_set_tooltip_text(self->priv->settings_button, "Settings");
    GtkStyleContext *settings_button_context = gtk_widget_get_style_context(self->priv->settings_button);
    gtk_style_context_add_class(settings_button_context, "flat");
    gtk_style_context_remove_class(settings_button_context, "button");
    gtk_box_pack_start(GTK_BOX(footer), self->priv->settings_button, TRUE, FALSE, 0);
    g_signal_connect_object(GTK_BUTTON(self->priv->settings_button), "clicked", G_CALLBACK(trash_settings_clicked), self, 0);

    // Pack it all up
    gtk_box_pack_start(GTK_BOX(main_view), header, FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(main_view), scroller, TRUE, TRUE, 0);
    gtk_box_pack_end(GTK_BOX(main_view), footer, FALSE, FALSE, 0);

    // Show everything
    gtk_widget_show_all(main_view);

    return main_view;
}

void trash_toggle_popover(__budgie_unused__ GtkButton *sender, TrashApplet *self) {
    if (gtk_widget_is_visible(self->priv->popover)) {
        gtk_widget_hide(self->priv->popover);
    } else {
        budgie_popover_manager_show_popover(self->priv->manager, GTK_WIDGET(self->priv->icon_button));
    }
}

void trash_drag_data_received(__budgie_unused__ TrashApplet *self,
                              GdkDragContext *context,
                              __budgie_unused__ gint x,
                              __budgie_unused__ gint y,
                              GtkSelectionData *data,
                              guint info,
                              guint time) {
    if (info != 0) {
        return;
    }

    g_autofree gchar *d = g_strdup((gchar *) gtk_selection_data_get_data(data));
    if (g_str_has_prefix(d, "file://")) {
        g_autofree gchar *tmp = substring(d, 7, strlen(d));
        g_strstrip(tmp);
        g_autoptr(GString) path = g_string_new(tmp);
        g_string_replace(path, "%20", " ", 0);
        g_string_replace(path, "%28", "(", 0);
        g_string_replace(path, "%29", ")", 0);

        g_autoptr(GFile) file = g_file_new_for_path(path->str);
        g_autoptr(GError) err = NULL;
        if (!g_file_trash(file, NULL, &err)) {
            trash_notify_try_send("Error Trashing File", err->message, "dialog-error-symbolic");
            g_critical("%s:%d: Error moving file to trash: %s", __BASE_FILE__, __LINE__, err->message);
            return;
        }
    }

    gtk_drag_finish(context, TRUE, TRUE, time);
}

void trash_add_mount(GMount *mount, TrashApplet *self) {
    g_autoptr(GFile) location = g_mount_get_default_location(mount);
    g_autofree gchar *attributes = g_strconcat(G_FILE_ATTRIBUTE_STANDARD_NAME, ",",
                                               G_FILE_ATTRIBUTE_STANDARD_TYPE, NULL);

    // Calculate the length of the dir name we're looking for, with an extra
    // space for a NULL terminator. We use `snprintf` to count the length of
    // the UID so we can properly allocate space for it in the name string.
    gint name_length = (7 + snprintf(NULL, 0, "%i", self->priv->uid) + 1);
    g_autofree gchar *trash_dir_name = (gchar *) malloc(sizeof(gchar) * name_length);
    g_snprintf(trash_dir_name, name_length, ".Trash-%i", self->priv->uid);

    g_autoptr(GError) err = NULL;
    g_autoptr(GFileEnumerator) enumerator = g_file_enumerate_children(location,
                                                                      attributes,
                                                                      G_FILE_QUERY_INFO_NONE,
                                                                      NULL,
                                                                      &err);

    if G_UNLIKELY (!enumerator) {
        g_critical("%s:%d: Error getting file enumerator for trash files in '%s': %s", __BASE_FILE__, __LINE__, g_file_get_path(location), err->message);
        return;
    }

    // Iterate over the items in the mount's default directory.
    // If a directory matches the name of an expected trash
    // directory, create a TrashStore for it and add it to the UI.
    g_autoptr(GFileInfo) current_file = NULL;
    while ((current_file = g_file_enumerator_next_file(enumerator, NULL, &err))) {
        if (g_file_info_get_file_type(current_file) != G_FILE_TYPE_DIRECTORY ||
            strcmp(g_file_info_get_name(current_file), trash_dir_name) != 0) {
            continue;
        }

        g_autofree gchar *trash_path = g_build_path(G_DIR_SEPARATOR_S, g_file_get_path(location), g_file_info_get_name(current_file), "files", NULL);
        g_autofree gchar *trashinfo_path = g_build_path(G_DIR_SEPARATOR_S, g_file_get_path(location), g_file_info_get_name(current_file), "info", NULL);

        TrashStore *store = trash_store_new_with_extras(g_mount_get_name(mount), g_settings_get_enum(self->priv->settings, TRASH_SETTINGS_KEY_SORT_MODE), g_mount_get_symbolic_icon(mount), g_strdup(g_file_get_path(location)), g_strdup(trash_path), g_strdup(trashinfo_path));
        g_autoptr(GError) inner_err = NULL;
        trash_store_load_items(store, inner_err);
        if (inner_err) {
            g_critical("%s:%d: Error loading trash items for mount '%s': %s", __BASE_FILE__, __LINE__, g_mount_get_name(mount), err->message);
            break;
        }
        trash_store_start_monitor(store);

        gtk_list_box_insert(GTK_LIST_BOX(self->priv->drive_box), GTK_WIDGET(store), -1);
        g_hash_table_insert(self->priv->mounts, g_strdup(g_mount_get_name(mount)), store);
        break;
    }

    g_file_enumerator_close(enumerator, NULL, NULL);
}

void trash_handle_mount_added(__budgie_unused__ GVolumeMonitor *monitor, GMount *mount, TrashApplet *self) {
    trash_add_mount(mount, self);
}

void trash_handle_mount_removed(__budgie_unused__ GVolumeMonitor *monitor, GMount *mount, TrashApplet *self) {
    g_autofree gchar *mount_name = g_mount_get_name(mount);
    TrashStore *store = (TrashStore *) g_hash_table_lookup(self->priv->mounts, mount_name);
    g_return_if_fail(store != NULL);

    GtkWidget *row = gtk_widget_get_parent(GTK_WIDGET(store));
    gtk_container_remove(GTK_CONTAINER(self->priv->drive_box), row);
    g_hash_table_remove(self->priv->mounts, mount_name);
}

void trash_settings_clicked(__budgie_unused__ GtkButton *sender, TrashApplet *self) {
    gtk_stack_set_visible_child_name(GTK_STACK(self->priv->stack), "settings");
}

void trash_handle_return(__budgie_unused__ TrashSettings *sender, TrashApplet *self) {
    gtk_stack_set_visible_child_name(GTK_STACK(self->priv->stack), "main");
}

void trash_handle_setting_changed(GSettings *settings, gchar *key, TrashApplet *self) {
    if (strcmp(key, TRASH_SETTINGS_KEY_SORT_MODE) == 0) {
        // Set the sort mode everywhere
        TrashSortMode new_mode = g_settings_get_enum(settings, key);
        GHashTableIter iter;
        gpointer hash_key, value;
        g_hash_table_iter_init(&iter, self->priv->mounts);

        while (g_hash_table_iter_next(&iter, &hash_key, &value)) {
            g_object_set(value, key, new_mode, NULL);
        }
    } else {
        g_critical("%s:%d: Unknown settings key '%s'", __BASE_FILE__, __LINE__, key);
    }
}
