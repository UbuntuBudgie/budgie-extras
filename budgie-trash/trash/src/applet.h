#pragma once

#include "notify.h"
#include "trash_icon_button.h"
#include "trash_settings.h"
#include "trash_store.h"
#include "utils.h"
#include <budgie-desktop/applet.h>
#include <gtk/gtk.h>

#define __budgie_unused__ __attribute__((unused))

G_BEGIN_DECLS

typedef struct _TrashAppletPrivate TrashAppletPrivate;
typedef struct _TrashApplet TrashApplet;
typedef struct _TrashAppletClass TrashAppletClass;

#define TRASH_TYPE_APPLET trash_applet_get_type()
#define TRASH_APPLET(o) (G_TYPE_CHECK_INSTANCE_CAST((o), TRASH_TYPE_APPLET, TrashApplet))
#define TRASH_IS_APPLET(o) (G_TYPE_CHECK_INSTANCE_TYPE((o), TRASH_TYPE_APPLET))
#define TRASH_APPLET_CLASS(o) (G_TYPE_CHECK_CLASS_CAST((o), TRASH_TYPE_APPLET, TrashAppletClass))
#define TRASH_IS_APPLET_CLASS(o) (G_TYPE_CHECK_CLASS_TYPE((o), TRASH_TYPE_APPLET))
#define TRASH_APPLET_GET_CLASS(o) (G_TYPE_INSTANCE_GET_CLASS((o), TRASH_TYPE_APPLET, TrashAppletClass))

struct _TrashAppletClass {
    BudgieAppletClass parent_class;
};

struct _TrashApplet {
    BudgieApplet parent;
    TrashAppletPrivate *priv;
};

GType trash_applet_get_type(void);

/**
 * Public for the plugin to allow registration of types.
 */
void trash_applet_init_gtype(GTypeModule *module);

/**
 * Constructs a new  Trash Applet instance.
 */
BudgieApplet *trash_applet_new(void);

/**
 * Create our widgets to show in our popover.
 */
GtkWidget *trash_create_main_view(TrashApplet *self, TrashSortMode sort_mode);

/**
 * Shows our popover widget if it isn't currently visible, or hide
 * it if it is.
 */
void trash_toggle_popover(GtkButton *sender, TrashApplet *self);

void trash_drag_data_received(TrashApplet *self,
                              GdkDragContext *context,
                              gint x,
                              gint y,
                              GtkSelectionData *data,
                              guint info,
                              guint time);

void trash_add_mount(GMount *mount, TrashApplet *self);
void trash_handle_mount_added(GVolumeMonitor *monitor, GMount *mount, TrashApplet *self);
void trash_handle_mount_removed(GVolumeMonitor *monitor, GMount *mount, TrashApplet *self);

void trash_settings_clicked(GtkButton *sender, TrashApplet *self);
void trash_handle_return(TrashSettings *sender, TrashApplet *self);

void trash_handle_setting_changed(GSettings *settings, gchar *key, TrashApplet *self);

G_END_DECLS
