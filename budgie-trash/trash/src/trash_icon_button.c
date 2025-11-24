#include "trash_icon_button.h"

struct _TrashIconButton {
    GtkButton parent_instance;

    GtkWidget *icon_empty;
    GtkWidget *icon_full;
};

struct _TrashIconButtonClass {
    GtkButtonClass parent_class;
};

G_DEFINE_TYPE(TrashIconButton, trash_icon_button, GTK_TYPE_BUTTON);

static void trash_icon_button_class_init(__attribute__((unused)) TrashIconButtonClass *klazz) {
}

static void trash_icon_button_init(TrashIconButton *self) {
    GtkStyleContext *style = gtk_widget_get_style_context(GTK_WIDGET(self));
    gtk_style_context_add_class(style, "flat");
    gtk_style_context_remove_class(style, "button");

    self->icon_empty = gtk_image_new_from_icon_name("user-trash-symbolic", GTK_ICON_SIZE_MENU);
    self->icon_full = gtk_image_new_from_icon_name("user-trash-full-symbolic", GTK_ICON_SIZE_MENU);

    gtk_button_set_image(GTK_BUTTON(self), GTK_WIDGET(self->icon_empty));
    gtk_widget_set_tooltip_text(GTK_WIDGET(self), "Trash");

    gtk_widget_show_all(GTK_WIDGET(self));
}

TrashIconButton *trash_icon_button_new(void) {
    return g_object_new(TRASH_TYPE_ICON_BUTTON, NULL);
}

void trash_icon_button_set_filled(TrashIconButton *self) {
    gtk_button_set_image(GTK_BUTTON(self), GTK_WIDGET(self->icon_full));
}

void trash_icon_button_set_empty(TrashIconButton *self) {
    gtk_button_set_image(GTK_BUTTON(self), GTK_WIDGET(self->icon_empty));
}
