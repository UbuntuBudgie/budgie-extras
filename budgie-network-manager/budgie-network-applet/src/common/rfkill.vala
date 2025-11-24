/*
 * Copyright (C) 2012 Canonical Ltd.
 * Author: Robert Ancell <robert.ancell@canonical.com>
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later
 * version. See http://www.gnu.org/copyleft/gpl.html the full text of the
 * license.
 */

public enum RFKillDeviceType {
    ALL = 0,
    WLAN,
    BLUETOOTH,
    UWB,
    WIMAX,
    WMAN
}

public class RFKillDevice {
    public signal void changed ();

    public bool software_lock {
        get { return _software_lock; }
        set {
            var event = RFKillEvent ();
            event.idx = idx;
            event.op = RFKillOperation.CHANGE;
            event.soft = value ? 1 : 0;
            if (Posix.write (manager.fd, &event, 8) != 8)
                return;
        }
    }

    public bool hardware_lock { get { return _hardware_lock; } }

    public RFKillDeviceType device_type { get { return _device_type; } }

    internal RFKillManager manager;
    internal uint32 idx;
    internal RFKillDeviceType _device_type;
    internal bool _software_lock;
    internal bool _hardware_lock;

    internal RFKillDevice (RFKillManager manager, uint32 idx, RFKillDeviceType device_type, bool software_lock, bool hardware_lock) {
        this.manager = manager;
        this.idx = idx;
        _device_type = device_type;
        _software_lock = software_lock;
        _hardware_lock = hardware_lock;
    }
}

public class RFKillManager : Object {
    public signal void device_added (RFKillDevice device);
    public signal void device_changed (RFKillDevice device);
    public signal void device_deleted (RFKillDevice device);

    public RFKillManager () {
        _devices = new List<RFKillDevice> ();
    }

    public void open () {
        fd = Posix.open ("/dev/rfkill", Posix.O_RDWR);
        Posix.fcntl (fd, Posix.F_SETFL, Posix.O_NONBLOCK);

        /* Read initial state */
        while (read_event ());

        /* Monitor for events */
        var channel = new IOChannel.unix_new (fd);
        channel.add_watch (IOCondition.IN | IOCondition.HUP | IOCondition.ERR, () => { return read_event (); });
    }

    public List<RFKillDevice> get_devices () {
        var devices = new List<RFKillDevice> ();
        foreach (var device in _devices)
            devices.append (device);
        return devices;
    }

    public void set_software_lock (RFKillDeviceType type, bool lock_enabled) {
        var event = RFKillEvent ();
        event.type = type;
        event.op = RFKillOperation.CHANGE_ALL;
        event.soft = lock_enabled ? 1 : 0;
        if (Posix.write (fd, &event, 8) != 8)
            return;
    }

    internal int fd = -1;
    private List<RFKillDevice> _devices;

    private bool read_event () {
        var event = RFKillEvent ();
        if (Posix.read (fd, &event, 8) != 8)
            return false;

        switch (event.op) {
        case RFKillOperation.ADD:
            var device = new RFKillDevice (this, event.idx, (RFKillDeviceType) event.type, event.soft != 0, event.hard != 0);
            _devices.append (device);
            device_added (device);
            break;
        case RFKillOperation.DELETE:
            var device = get_device (event.idx);
            if (device != null) {
                _devices.remove (device);
                device_deleted (device);
            }
            break;
        case RFKillOperation.CHANGE:
            var device = get_device (event.idx);
            if (device != null) {
                device._software_lock = event.soft != 0;
                device._hardware_lock = event.hard != 0;
                device.changed ();
                device_changed (device);
            }
            break;
        }
        return true;
    }

    private RFKillDevice? get_device (uint32 idx) {
        foreach (var device in _devices) {
            if (device.idx == idx)
                return device;
        }

        return null;
    }
}

private struct RFKillEvent {
    uint32 idx;
    uint8 type;
    uint8 op;
    uint8 soft;
    uint8 hard;
}

private enum RFKillOperation {
    ADD = 0,
    DELETE,
    CHANGE,
    CHANGE_ALL
}
