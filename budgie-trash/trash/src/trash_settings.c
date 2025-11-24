#include "trash_settings.h"

enum {
    SIGNAL_RETURN_CLICKED,
    N_SIGNALS
};

static guint settings_signals[N_SIGNALS] = {0};

enum {
    PROP_EXP_0,
    PROP_SORT_MODE,
    N_EXP_PROPERTIES
};

static GParamSpec *settings_props[N_EXP_PROPERTIES] = {
    NULL,
};

struct _TrashSettings {
    GtkBox parent_instance;

    GSettings *settings;
    gint sort_mode;

    GtkWidget *sort_mode_type;
    GtkWidget *sort_mode_alphabetical;
    GtkWidget *sort_mode_alphabetical_reverse;
    GtkWidget *sort_mode_date;
    GtkWidget *sort_mode_date_reverse;
    GtkWidget *return_button;
};

struct _TrashSettingsClass {
    GtkBoxClass parent_class;

    void (*return_clicked)(TrashSettings *);
};

G_DEFINE_TYPE(TrashSettings, trash_settings, GTK_TYPE_BOX)

static void trash_settings_dispose(GObject *obj);
static void trash_settings_get_property(GObject *obj, guint prop_id, GValue *val, GParamSpec *spec);
static void trash_settings_set_property(GObject *obj, guint prop_id, const GValue *val, GParamSpec *spec);

static void trash_settings_class_init(TrashSettingsClass *klazz) {
    GObjectClass *class = G_OBJECT_CLASS(klazz);
    class->dispose = trash_settings_dispose;
    class->get_property = trash_settings_get_property;
    class->set_property = trash_settings_set_property;

    // Signals
    settings_signals[SIGNAL_RETURN_CLICKED] = g_signal_new(
        "return-clicked",
        G_TYPE_FROM_CLASS(class),
        G_SIGNAL_RUN_FIRST | G_SIGNAL_ACTION,
        G_STRUCT_OFFSET(TrashSettingsClass, return_clicked),
        NULL,
        NULL,
        NULL,
        G_TYPE_NONE,
        0,
        NULL);

    // Properties
    settings_props[PROP_SORT_MODE] = g_param_spec_enum(
        "sort-mode",
        "Sort mode",
        "Set how trashed files should be sorted",
        TRASH_TYPE_SORT_MODE,
        TRASH_SORT_TYPE,
        G_PARAM_CONSTRUCT | G_PARAM_EXPLICIT_NOTIFY | G_PARAM_READWRITE);

    g_object_class_install_properties(class, N_EXP_PROPERTIES, settings_props);
}

static void trash_settings_dispose(GObject *obj) {
    TrashSettings *self = TRASH_SETTINGS(obj);

    g_settings_unbind(self->settings, TRASH_SETTINGS_KEY_SORT_MODE);

    G_OBJECT_CLASS(trash_settings_parent_class)->dispose(obj);
}

static void trash_settings_get_property(GObject *obj, guint prop_id, GValue *val, GParamSpec *spec) {
    TrashSettings *self = TRASH_SETTINGS(obj);

    switch (prop_id) {
        case PROP_SORT_MODE:
            g_value_set_enum(val, self->sort_mode);
            break;
        default:
            G_OBJECT_WARN_INVALID_PROPERTY_ID(obj, prop_id, spec);
            break;
    }
}

static void trash_settings_set_property(GObject *obj, guint prop_id, const GValue *val, GParamSpec *spec) {
    TrashSettings *self = TRASH_SETTINGS(obj);

    switch (prop_id) {
        case PROP_SORT_MODE:
            self->sort_mode = g_value_get_enum(val);
            break;
        default:
            G_OBJECT_WARN_INVALID_PROPERTY_ID(obj, prop_id, spec);
            break;
    }
}

static void trash_settings_init(TrashSettings *self) {
    self->settings = g_settings_new(TRASH_SETTINGS_SCHEMA_ID);
    g_settings_bind(self->settings,
                    TRASH_SETTINGS_KEY_SORT_MODE,
                    self,
                    "sort-mode",
                    G_SETTINGS_BIND_DEFAULT);

    GtkWidget *header = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0);
    GtkStyleContext *header_style = gtk_widget_get_style_context(header);
    gtk_style_context_add_class(header_style, "trash-applet-header");
    GtkWidget *header_label = gtk_label_new("Settings");
    GtkStyleContext *header_label_style = gtk_widget_get_style_context(header_label);
    gtk_style_context_add_class(header_label_style, "title");
    gtk_box_pack_start(GTK_BOX(header), header_label, TRUE, TRUE, 0);

    gtk_box_pack_start(GTK_BOX(self), header, FALSE, FALSE, 0);

    // Create our scroller
    GtkWidget *scroller = gtk_scrolled_window_new(NULL, NULL);
    gtk_scrolled_window_set_min_content_height(GTK_SCROLLED_WINDOW(scroller), 300);
    gtk_scrolled_window_set_max_content_height(GTK_SCROLLED_WINDOW(scroller), 300);
    gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scroller), GTK_POLICY_NEVER, GTK_POLICY_AUTOMATIC);

    gtk_box_pack_start(GTK_BOX(self), scroller, TRUE, TRUE, 0);

    // Create a settings container to put in the scroller
    GtkWidget *settings_box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
    GtkStyleContext *box_context = gtk_widget_get_style_context(settings_box);
    gtk_style_context_add_class(box_context, "trash-settings-box");
    gtk_container_add(GTK_CONTAINER(scroller), settings_box);

    // Create the sorting settings section
    GtkWidget *sort_section = gtk_box_new(GTK_ORIENTATION_VERTICAL, 5);
    GtkWidget *sort_label = gtk_label_new("Sort mode");
    GtkStyleContext *sort_label_style = gtk_widget_get_style_context(sort_label);
    gtk_style_context_add_class(sort_label_style, GTK_STYLE_CLASS_DIM_LABEL);
    gtk_widget_set_tooltip_text(sort_label, "Set the sorting mode for trashed files");
    gtk_widget_set_halign(sort_label, GTK_ALIGN_START);
    gtk_label_set_justify(GTK_LABEL(sort_label), GTK_JUSTIFY_LEFT);

    gtk_box_pack_start(GTK_BOX(sort_section), sort_label, FALSE, FALSE, 0);

    GtkWidget *type_container = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0);
    GtkWidget *type_label = gtk_label_new("Type");
    gtk_widget_set_halign(type_label, GTK_ALIGN_START);
    gtk_label_set_justify(GTK_LABEL(type_label), GTK_JUSTIFY_LEFT);
    self->sort_mode_type = gtk_radio_button_new(NULL);

    gtk_box_pack_start(GTK_BOX(type_container), type_label, TRUE, TRUE, 0);
    gtk_box_pack_end(GTK_BOX(type_container), self->sort_mode_type, FALSE, FALSE, 0);

    GtkWidget *alphabetical_container = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0);
    GtkWidget *alphabetical_label = gtk_label_new("A-Z");
    gtk_widget_set_halign(alphabetical_label, GTK_ALIGN_START);
    gtk_label_set_justify(GTK_LABEL(alphabetical_label), GTK_JUSTIFY_LEFT);
    self->sort_mode_alphabetical = gtk_radio_button_new_from_widget(GTK_RADIO_BUTTON(self->sort_mode_type));

    gtk_box_pack_start(GTK_BOX(alphabetical_container), alphabetical_label, TRUE, TRUE, 0);
    gtk_box_pack_end(GTK_BOX(alphabetical_container), self->sort_mode_alphabetical, FALSE, FALSE, 0);

    GtkWidget *alphabetical_reverse_container = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0);
    GtkWidget *alphabetical_reverse_label = gtk_label_new("Z-A");
    gtk_widget_set_halign(alphabetical_reverse_label, GTK_ALIGN_START);
    gtk_label_set_justify(GTK_LABEL(alphabetical_reverse_label), GTK_JUSTIFY_LEFT);
    self->sort_mode_alphabetical_reverse = gtk_radio_button_new_from_widget(GTK_RADIO_BUTTON(self->sort_mode_type));

    gtk_box_pack_start(GTK_BOX(alphabetical_reverse_container), alphabetical_reverse_label, TRUE, TRUE, 0);
    gtk_box_pack_end(GTK_BOX(alphabetical_reverse_container), self->sort_mode_alphabetical_reverse, FALSE, FALSE, 0);

    GtkWidget *date_container = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0);
    GtkWidget *date_label = gtk_label_new("Date Ascending");
    gtk_widget_set_halign(date_label, GTK_ALIGN_START);
    gtk_label_set_justify(GTK_LABEL(date_label), GTK_JUSTIFY_LEFT);
    self->sort_mode_date = gtk_radio_button_new_from_widget(GTK_RADIO_BUTTON(self->sort_mode_type));

    gtk_box_pack_start(GTK_BOX(date_container), date_label, TRUE, TRUE, 0);
    gtk_box_pack_end(GTK_BOX(date_container), self->sort_mode_date, FALSE, FALSE, 0);

    GtkWidget *date_reverse_container = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0);
    GtkWidget *date_reverse_label = gtk_label_new("Date Descending");
    gtk_widget_set_halign(date_reverse_label, GTK_ALIGN_START);
    gtk_label_set_justify(GTK_LABEL(date_reverse_label), GTK_JUSTIFY_LEFT);
    self->sort_mode_date_reverse = gtk_radio_button_new_from_widget(GTK_RADIO_BUTTON(self->sort_mode_type));

    gtk_box_pack_start(GTK_BOX(date_reverse_container), date_reverse_label, TRUE, TRUE, 0);
    gtk_box_pack_end(GTK_BOX(date_reverse_container), self->sort_mode_date_reverse, FALSE, FALSE, 0);

    // Signals
    g_signal_connect_object(self->sort_mode_type, "clicked", G_CALLBACK(trash_settings_sort_changed), self, 0);
    g_signal_connect_object(self->sort_mode_alphabetical, "clicked", G_CALLBACK(trash_settings_sort_changed), self, 0);
    g_signal_connect_object(self->sort_mode_alphabetical_reverse, "clicked", G_CALLBACK(trash_settings_sort_changed), self, 0);
    g_signal_connect_object(self->sort_mode_date, "clicked", G_CALLBACK(trash_settings_sort_changed), self, 0);
    g_signal_connect_object(self->sort_mode_date_reverse, "clicked", G_CALLBACK(trash_settings_sort_changed), self, 0);

    gtk_box_pack_start(GTK_BOX(sort_section), type_container, FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(sort_section), alphabetical_container, FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(sort_section), alphabetical_reverse_container, FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(sort_section), date_container, FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(sort_section), date_reverse_container, FALSE, FALSE, 0);

    gtk_box_pack_start(GTK_BOX(settings_box), sort_section, FALSE, FALSE, 0);

    // Create the footer
    GtkWidget *footer = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0);
    GtkStyleContext *footer_style = gtk_widget_get_style_context(footer);
    gtk_style_context_add_class(footer_style, "trash-applet-footer");

    self->return_button = gtk_button_new_from_icon_name("edit-undo-symbolic", GTK_ICON_SIZE_BUTTON);
    gtk_widget_set_tooltip_text(self->return_button, "Return");
    GtkStyleContext *settings_button_context = gtk_widget_get_style_context(self->return_button);
    gtk_style_context_add_class(settings_button_context, "flat");
    gtk_style_context_remove_class(settings_button_context, "button");
    gtk_box_pack_start(GTK_BOX(footer), self->return_button, TRUE, FALSE, 0);
    g_signal_connect_object(GTK_BUTTON(self->return_button), "clicked", G_CALLBACK(trash_return_clicked), self, 0);

    switch (self->sort_mode) {
        case TRASH_SORT_A_Z:
            gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON(self->sort_mode_alphabetical), TRUE);
            break;
        case TRASH_SORT_Z_A:
            gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON(self->sort_mode_alphabetical_reverse), TRUE);
            break;
        case TRASH_SORT_DATE_ASCENDING:
            gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON(self->sort_mode_date), TRUE);
            break;
        case TRASH_SORT_DATE_DESCENDING:
            gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON(self->sort_mode_date_reverse), TRUE);
            break;
        case TRASH_SORT_TYPE:
            gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON(self->sort_mode_type), TRUE);
            break;
        default:
            g_critical("%s:%d: Unknown trash sort mode '%d'", __BASE_FILE__, __LINE__, (gint) self->sort_mode);
            break;
    }

    gtk_box_pack_end(GTK_BOX(self), footer, FALSE, FALSE, 0);

    gtk_widget_show_all(GTK_WIDGET(self));
}

TrashSettings *trash_settings_new() {
    return g_object_new(TRASH_TYPE_SETTINGS,
                        "orientation", GTK_ORIENTATION_VERTICAL,
                        "spacing", 0,
                        NULL);
}

void trash_settings_sort_changed(GtkWidget *button, TrashSettings *self) {
    if (button == self->sort_mode_alphabetical) {
        self->sort_mode = TRASH_SORT_A_Z;
    } else if (button == self->sort_mode_alphabetical_reverse) {
        self->sort_mode = TRASH_SORT_Z_A;
    } else if (button == self->sort_mode_date) {
        self->sort_mode = TRASH_SORT_DATE_ASCENDING;
    } else if (button == self->sort_mode_date_reverse) {
        self->sort_mode = TRASH_SORT_DATE_DESCENDING;
    } else {
        self->sort_mode = TRASH_SORT_TYPE;
    }

    g_settings_set_enum(self->settings, "sort-mode", self->sort_mode);
}

void trash_return_clicked(__attribute__((unused)) GtkButton *sender, TrashSettings *self) {
    g_signal_emit(self, settings_signals[SIGNAL_RETURN_CLICKED], 0, NULL);
}
