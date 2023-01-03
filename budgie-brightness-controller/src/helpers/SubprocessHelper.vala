/*
 * BrightnessController
 * This file is part of UbuntuBudgie
 *
 * Author: Serdar ŞEN github.com/serdarsen
 *
 * Copyright © 2018 Ubuntu Budgie Developers
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 */

namespace BrightnessController.Helpers
{
public class SubprocessHelper
{
    private SubprocessLauncher subprocessLauncher;

    public SubprocessHelper()
    {
        subprocessLauncher = new SubprocessLauncher (SubprocessFlags.STDOUT_PIPE);
    }

    /**
    *  Runs given in string[] command line commands
    *  Returns string result.
    *  eg: var result = RunAndGetResult({"ls", "/sys/class/backlight"})
    */
    public string RunAndGetResult(string[] cmdLine)
    {
        string output;
        try
        {
            var proc = subprocessLauncher.spawnv(cmdLine);
            proc.communicate_utf8(null, null, out output, null);
            return output;
        }
        catch (Error e)
        {
            GLib.message("Failed to run : %s", e.message);
            return "";
        }
    }

    /**
    *  Runs given in string[] command line commands
    *  eg: Run({"ls", "/sys/class/backlight"})
    */
    public void Run(string[] cmdLine)
    {
        try
        {
            subprocessLauncher.spawnv(cmdLine);
        }
        catch (Error e)
        {
            GLib.message("Failed to run : %s", e.message);
        }
    }
}
}