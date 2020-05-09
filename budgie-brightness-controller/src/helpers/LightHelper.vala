/*
 * BrightnessController
 * This file is part of budgie-extras
 *
 * Author: Serdar ŞEN github.com/serdarsen
 *
 * Copyright © 2018-2020 Ubuntu Budgie Developers
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 */

using BrightnessController.Models;

namespace BrightnessController.Helpers
{
/**
 * LightHelper is a helper to work with
 * GNOME/gnome-settings-daemon gsd-backlight-helper
 * Currently working correctly with GNOME_SETTINGS_DAEMON_3_32_0
 *
 * https://github.com/GNOME/gnome-settings-daemon/releases
 *
 */
public class LightHelper
{
    public bool IsAvailable {get; set;}
    public bool haveGnomeSettingsDaemon332 = false;
    public bool haveGnomeSettingsDaemonOlderThan332 = false;
    public List<Light> list;

    private SubprocessHelper subprocessHelper;
    private ConfigHelper configHelper;

    public LightHelper()
    {
        subprocessHelper = new SubprocessHelper();
        configHelper  = new ConfigHelper("budgie-advanced-brightness-controller", "light");
        Load();
    }

    private void Load()
    {
        list = new List<Light>();

        //Load Lights From Config
        var retrivedLightNames = new string[]{};
        var lightObjects = configHelper.Read();

        foreach (var obj in lightObjects)
        {
            var properties = obj.split(" ");
            if(properties.length > 3)
            {
                var light = new Light();
                light.Name = properties[0];
                retrivedLightNames += light.Name;
                light.MaxBrightness = properties[1].to_double();
                light.Brightness = properties[2].to_double();
                light.IsActive = properties[3].to_bool();

                //print(@"Load Lighs From Config: %s, %s, %s, %s \n", light.Name, light.MaxBrightnessText, light.BrightnessText, light.IsActive.to_string());
                list.append(light);
            }
        }

        // Load Lights Frome Device
        var lightsString = subprocessHelper.RunAndGetResult({Config.PACKAGE_BINDIR + "/ls", "/sys/class/backlight"});

        lightsString = lightsString._strip();
        if (lightsString == "")
        {
            return;
        }

        var lightNames = lightsString.split("\n");
        var lightNamesCount = 0;
        foreach (var name in lightNames)
        {
            name = name._strip();
            if(name != ""
               && !strv_contains(retrivedLightNames, name))
            {
                var light = new Light();
                light.Name = name;
                light.MaxBrightness = GetMaxBrightness(name);
                light.Brightness = GetBrightness(name);

                if(lightNamesCount == 0)
                {
                    light.IsActive = true;
                }
                else
                {
                    light.IsActive = false;
                }
                list.append(light);

                //print(@"Load Lighs From Device: %s, %s, %s, %s \n", light.Name, light.MaxBrightnessText, light.BrightnessText, light.IsActive.to_string());
                lightNamesCount++;
            }
        }

        #if HAVE_GNOME_SETTINGS_DAEMON_3_32_0
            haveGnomeSettingsDaemon332 = true;
        #endif

        #if HAVE_GNOME_SETTINGS_DAEMON_OLDER_THAN_3_32_0
            haveGnomeSettingsDaemonOlderThan332 = true;
        #endif

        if(haveGnomeSettingsDaemon332 && list.length() > 0)
        {
            IsAvailable = true;
        }
        else if(haveGnomeSettingsDaemonOlderThan332)
        {
            IsAvailable = true;
        }
        else
        {
            print("is not available");
            IsAvailable = false;

            var lightListLength = list.length();
            GLib.message(@"Light is not available (Gnome Settings Daemon version >= 3.32.0: $haveGnomeSettingsDaemon332, Number of Lights: $lightListLength)\n");
        }
    }

    private double GetMaxBrightness(string name)
    {
        return subprocessHelper.RunAndGetResult({Config.PACKAGE_BINDIR + "/cat", @"/sys/class/backlight/$name/max_brightness"}).to_double();
    }

    public double GetBrightness(string name)
    {
        return subprocessHelper.RunAndGetResult({Config.PACKAGE_BINDIR + "/cat", @"/sys/class/backlight/$name/brightness"}).to_double();
    }

    public void SetBrightness(string name, double brightness)
    {
        var brightnessInt = (int)brightness;
        if(haveGnomeSettingsDaemon332)
        {
            subprocessHelper.Run({Config.PACKAGE_BINDIR + "/pkexec", Config.PACKAGE_LIBDIR + "/gnome-settings-daemon/gsd-backlight-helper", @"/sys/class/backlight/$name", @"$brightnessInt"});
        }
        else if(haveGnomeSettingsDaemonOlderThan332)
        {
            subprocessHelper.Run({Config.PACKAGE_BINDIR + "/pkexec", Config.PACKAGE_LIBDIR + "/gnome-settings-daemon/gsd-backlight-helper", "--set-brightness", @"$brightnessInt"});
        }

        Save();
    }

    public void SetActive(Light light)
    {
        list.foreach((light)=>
        {
            light.IsActive = false;
        });
        light.IsActive = true;
        Save();
    }

    public void Save()
    {
        var data = new string[]{};
        list.foreach((light)=>
        {
            var name = light.Name;
            var maxBrightness = light.MaxBrightnessText;
            var brightness = light.BrightnessText;
            var isActive = light.IsActive;
            data += (@"$name $maxBrightness $brightness $isActive");
        });
        configHelper.Write(data);
    }
}
}