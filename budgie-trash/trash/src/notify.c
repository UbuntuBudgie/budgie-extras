#include "notify.h"

struct _TrashNotifyData {
    int _ref_count;
    NotifyNotification *notification;
};

static TrashNotifyData *trash_notify_data_ref(TrashNotifyData *data);
static void trash_notify_data_unref(gpointer user_data);

static TrashNotifyData *trash_notify_data_ref(TrashNotifyData *data) {
    g_atomic_int_inc(&data->_ref_count);
    return data;
}

static void trash_notify_data_unref(gpointer user_data) {
    TrashNotifyData *data = (TrashNotifyData *) user_data;
    if (g_atomic_int_dec_and_test(&data->_ref_count)) {
        g_object_unref(data->notification);
        g_slice_free(TrashNotifyData, data);
    }
}

TrashNotifyData *trash_notify_data_new(NotifyNotification *notification) {
    TrashNotifyData *data = g_slice_new0(TrashNotifyData);
    data->_ref_count = 1;
    data->notification = notification;
    return data;
}

void trash_notify_try_send(gchar *summary, gchar *body, gchar *icon_name) {
    NotifyNotification *notification = notify_notification_new(summary, body, icon_name ? icon_name : "user-trash-symbolic");
    notify_notification_set_app_name(notification, "Budgie Trash Applet");
    notify_notification_set_urgency(notification, NOTIFY_URGENCY_NORMAL);
    notify_notification_set_timeout(notification, 5000);
    TrashNotifyData *data = trash_notify_data_new(notification);

    g_autoptr(GError) err = NULL;
    GThread *thread = g_thread_try_new("trash-notify-thread", (GThreadFunc) _trash_notify_send, trash_notify_data_ref(data), &err);
    if (!thread) {
        g_critical("%s:%d: Failed to spawn thread for sending a notification: %s", __BASE_FILE__, __LINE__, err->message);
        trash_notify_data_unref(data);
        return;
    }

    g_thread_unref(thread);
    trash_notify_data_unref(data);
}

gpointer _trash_notify_send(TrashNotifyData *data) {
    g_autoptr(GError) err = NULL;
    if (!notify_notification_show(data->notification, &err)) {
        g_critical("%s:%d: Error sending notification: %s", __BASE_FILE__, __LINE__, err->message);
    }
    trash_notify_data_unref(data);

    return NULL;
}
