#pragma once

#include <gtk/gtk.h>

G_BEGIN_DECLS

#define TRASH_TYPE_ICON_BUTTON (trash_icon_button_get_type())

G_DECLARE_FINAL_TYPE(TrashIconButton, trash_icon_button, TRASH, ICON_BUTTON, GtkButton)

TrashIconButton *trash_icon_button_new(void);
void trash_icon_button_set_filled(TrashIconButton *self);
void trash_icon_button_set_empty(TrashIconButton *self);

G_END_DECLS
