#pragma once

#include <libnotify/notification.h>

G_BEGIN_DECLS

typedef struct _TrashNotifyData TrashNotifyData;

/**
 * Create a new [NotifyNotification] object for use
 * inside a thread to show a notification.
 */
TrashNotifyData *trash_notify_data_new(NotifyNotification *notification);

/**
 * Tries to send a notification to the user.
 *
 * If no `icon_name` is passed to the function, a default icon
 * will be used.
 *
 * A thread will be spawned so that the notification will actually
 * be shown by Budgie without timing out (and locking up the system)
 * until it times out.
 */
void trash_notify_try_send(gchar *summary, gchar *body, gchar *icon_name);

/**
 * Internal callback function to show the notification.
 */
gpointer _trash_notify_send(TrashNotifyData *data);

G_END_DECLS
