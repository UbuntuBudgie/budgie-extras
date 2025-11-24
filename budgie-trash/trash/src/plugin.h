#pragma once

#include "applet.h"
#include <gtk/gtk.h>

G_BEGIN_DECLS

typedef struct _TrashPlugin TrashPlugin;
typedef struct _TrashPluginClass TrashPluginClass;

#define TRASH_TYPE_PLUGIN trash_plugin_get_type()
#define TRASH_PLUGIN(o) (G_TYPE_CHECK_INSTANCE_CAST((o), TRASH_TYPE_PLUGIN, TrashPlugin))
#define TRASH_IS_PLUGIN(o) (G_TYPE_CHECK_INSTANCE_TYPE((o), TRASH_TYPE_PLUGIN))
#define TRASH_PLUGIN_CLASS(o) (G_TYPE_CHECK_CLASS_CAST((o), TRASH_TYPE_PLUGIN, TrashPluginClass))
#define TRASH_IS_PLUGIN_CLASS(o) (G_TYPE_CHECK_CLASS_TYPE((o), TRASH_TYPE_PLUGIN))
#define TRASH_PLUGIN_GET_CLASS(o) (G_TYPE_INSTANCE_GET_CLASS((o), TRASH_TYPE_PLUGIN, TrashPluginClass))

struct _TrashPluginClass {
    GObjectClass parent_class;
};

struct _TrashPlugin {
    GObject parent;
};

GType trash_plugin_get_type(void);

G_END_DECLS
