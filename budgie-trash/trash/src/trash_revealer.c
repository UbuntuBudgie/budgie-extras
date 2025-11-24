#include "trash_revealer.h"

G_DEFINE_TYPE(TrashRevealer, trash_revealer, GTK_TYPE_REVEALER);

static void trash_revealer_class_init(__attribute__((unused)) TrashRevealerClass *klazz) {}

static void trash_revealer_init(TrashRevealer *self) {
    gtk_revealer_set_transition_type(GTK_REVEALER(self), GTK_REVEALER_TRANSITION_TYPE_SLIDE_DOWN);
    gtk_revealer_set_reveal_child(GTK_REVEALER(self), FALSE);

    self->container = gtk_box_new(GTK_ORIENTATION_VERTICAL, 5);
    self->label = gtk_label_new("");
    gtk_widget_set_size_request(self->label, 290, 20);
    gtk_label_set_line_wrap(GTK_LABEL(self->label), TRUE);
    gtk_box_pack_start(GTK_BOX(self->container), self->label, TRUE, TRUE, 0);

    GtkWidget *revealer_btns = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0);
    self->cancel_button = gtk_button_new_with_label("No");
    self->confirm_button = gtk_button_new_with_label("Yes");

    GtkStyleContext *cancel_style = gtk_widget_get_style_context(self->cancel_button);
    gtk_style_context_add_class(cancel_style, "flat");
    gtk_style_context_remove_class(cancel_style, "button");
    GtkStyleContext *confirm_style = gtk_widget_get_style_context(self->confirm_button);
    gtk_style_context_add_class(confirm_style, "flat");
    gtk_style_context_remove_class(confirm_style, "button");

    gtk_box_pack_start(GTK_BOX(revealer_btns), self->cancel_button, TRUE, TRUE, 0);
    gtk_box_pack_end(GTK_BOX(revealer_btns), self->confirm_button, TRUE, TRUE, 0);
    gtk_box_pack_end(GTK_BOX(self->container), revealer_btns, TRUE, TRUE, 0);

    // Pack ourselves up
    gtk_container_add(GTK_CONTAINER(self), self->container);
}

TrashRevealer *trash_revealer_new() {
    return g_object_new(TRASH_TYPE_REVEALER, NULL);
}

void trash_revealer_set_text(TrashRevealer *self, gchar *text, gboolean destructive) {
    gchar *text_clone = g_strdup(text);

    if (text_clone == NULL || strcmp(text_clone, "") == 0) {
        return;
    }

    // Set the label text
    gtk_label_set_markup(GTK_LABEL(self->label), text_clone);

    GtkStyleContext *confirm_style = gtk_widget_get_style_context(self->confirm_button);
    if (destructive) {
        gtk_style_context_remove_class(confirm_style, "suggested-action");
        gtk_style_context_add_class(confirm_style, "destructive-action");
    } else {
        gtk_style_context_remove_class(confirm_style, "destructive-action");
        gtk_style_context_add_class(confirm_style, "suggested-action");
    }
}
