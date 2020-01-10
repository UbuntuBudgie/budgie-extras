#!/usr/bin/env python3

# standard includes
import sys

# dbus includes
import dbus

# project includes

# well-known name for our program
ECHO_BUS_NAME = 'org.UbuntuBudgie.ExtrasDaemon'

# interfaces implemented by some objects in our program
ECHO_INTERFACE = 'org.UbuntuBudgie.ExtrasDaemon'

# paths to some objects in our program
ECHO_OBJECT_PATH = '/org/ubuntubudgie/extrasdaemon'


def client(mes):
    bus = dbus.SessionBus()

    try:
        proxy = bus.get_object(ECHO_BUS_NAME, ECHO_OBJECT_PATH)
    except dbus.DBusException as e:
        # There are actually two exceptions thrown:
        # 1: org.freedesktop.DBus.Error.NameHasNoOwner
        #   (when the name is not registered by any running process)
        # 2: org.freedesktop.DBus.Error.ServiceUnknown
        #   (during auto-activation since there is no .service file)
        # TODO figure out how to suppress the activation attempt
        # also, there *has* to be a better way of managing exceptions
        if e._dbus_error_name != \
                'org.freedesktop.DBus.Error.ServiceUnknown':
            raise
        if e.__context__._dbus_error_name != \
                'org.freedesktop.DBus.Error.NameHasNoOwner':
            raise
        print('client: No one can hear me!!')
    else:
        iface = dbus.Interface(proxy, ECHO_INTERFACE)

        iface.ResetLayout(mes)


def main(exe, args):
    if args:
        client(' '.join(args))
    else:
        sys.exit('Usage: %s message...' % exe)


if __name__ == '__main__':
    main(sys.argv[0], sys.argv[1:])
