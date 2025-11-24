#pragma once

#include "trash_enum_types.h"
#include <gtk/gtk.h>

G_BEGIN_DECLS

typedef enum {
    TRASH_SORT_TYPE = 1,
    TRASH_SORT_A_Z = 2,
    TRASH_SORT_Z_A = 3,
    TRASH_SORT_DATE_ASCENDING = 4,
    TRASH_SORT_DATE_DESCENDING = 5
} TrashSortMode;

/**
 * Constant ID for our settings gschema
 */
#define TRASH_SETTINGS_SCHEMA_ID "com.github.ebonjaeger.budgie-trash-applet"

#define TRASH_SETTINGS_KEY_SORT_MODE "sort-mode"

#define TRASH_TYPE_SETTINGS (trash_settings_get_type())
#define TRASH_SETTINGS(obj) (G_TYPE_CHECK_INSTANCE_CAST((obj), TRASH_TYPE_SETTINGS, TrashSettings))
#define TRASH_IS_SETTINGS(obj) (G_TYPE_CHECK_INSTANCE_TYPE((obj), TRASH_TYPE_SETTINGS))

typedef struct _TrashSettings TrashSettings;
typedef struct _TrashSettingsClass TrashSettingsClass;

TrashSettings *trash_settings_new();

void trash_settings_sort_changed(GtkWidget *button, TrashSettings *self);

void trash_return_clicked(GtkButton *sender, TrashSettings *self);

G_END_DECLS
