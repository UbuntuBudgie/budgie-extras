/*
 * BrightnessController
 * This file is part of budgie-extras
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

using BrightnessController.Models;

namespace BrightnessController.Helpers
{

    /**
    * LightHelper is a helper to work with
    * budgie-brightness-helper
    *
    */
    public class LightHelper
    {
        public bool IsAvailable {get; set;}
        public List<Light> list;

        private SubprocessHelper subprocessHelper;
        private ConfigHelper configHelper;

        public LightHelper()
        {
            subprocessHelper = new SubprocessHelper();
            configHelper  = new ConfigHelper("budgie-advanced-brightness-controller", "light");
            Load();
        }

        public double GetBrightness(string name)
        {
            return subprocessHelper.RunAndGetResult({"cat", @"/sys/class/backlight/$name/brightness"}).to_double();
        }

        private void Load()
        {
            list = new List<Light>();

            // Check budgie-brightness-helper is available by running it with --help
            // (a non-empty result means it's present and working)
            var helperCheck = subprocessHelper.RunAndGetResult({Config.PACKAGE_BINDIR + "/budgie-brightness-helper", "--help"});

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
                    light.Brightness = GetBrightness(light.Name);  // always read live, ignore cached value
                    light.IsActive = properties[3].to_bool();

                    GLib.debug("LightHelper.Load config: name=%s MaxBrightness=%.1f LiveBrightness=%.1f",
                    light.Name, light.MaxBrightness, light.Brightness);
                    list.append(light);
                }
            }

            // Load Lights From Device
            var lightsString = subprocessHelper.RunAndGetResult({"ls", "/sys/class/backlight"});

            lightsString = lightsString._strip();
            if (lightsString == "")
            {
                // No backlight devices found; availability depends solely on helper
                if (helperCheck != "")
                {
                    // Helper exists but no sysfs backlight entries — still mark available
                    // so the single virtual "backlight" entry can be used
                    if (list.length() == 0)
                    {
                        var light = new Light();
                        light.Name = "backlight";
                        light.MaxBrightness = 100;
                        light.Brightness = GetCurrentBrightnessPercent();
                        light.IsActive = true;
                        list.append(light);
                    }
                    IsAvailable = true;
                }
                else
                {
                    IsAvailable = false;
                }
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
                    light.MaxBrightness = 100;  // We now work in percent (0-100)
                    light.Brightness = GetCurrentBrightnessPercent();

                    if(lightNamesCount == 0)
                    {
                        light.IsActive = true;
                    }
                    else
                    {
                        light.IsActive = false;
                    }
                    list.append(light);

                    print(@"Load Lights From Device: %s, %s, %s \n", light.Name, light.MaxBrightnessText, light.IsActive.to_string());
                    lightNamesCount++;
                }
            }

            if (list.length() > 0)
            {
                IsAvailable = true;
            }
            else
            {
                print("is not available");
                IsAvailable = false;

                var lightListLength = list.length();
                GLib.debug(@"Light is not available (Number of Lights: $lightListLength)\n");
            }
        }

        /**
        * Read the current brightness percentage by inspecting sysfs directly.
        * Falls back to 100 if unavailable.
        */
        private double GetCurrentBrightnessPercent()
        {
            // Try each backlight device under /sys/class/backlight
            var lightsString = subprocessHelper.RunAndGetResult({"ls", "/sys/class/backlight"})._strip();
            if (lightsString != "")
            {
                var names = lightsString.split("\n");
                if (names.length > 0)
                {
                    var name = names[0]._strip();
                    if (name != "")
                    {
                        var maxStr = subprocessHelper.RunAndGetResult({"cat", @"/sys/class/backlight/$name/max_brightness"})._strip();
                        var curStr = subprocessHelper.RunAndGetResult({"cat", @"/sys/class/backlight/$name/brightness"})._strip();
                        double maxVal = maxStr.to_double();
                        double curVal = curStr.to_double();
                        if (maxVal > 0)
                        {
                            return (curVal / maxVal) * 100.0;
                        }
                    }
                }
            }
            return 100.0;
        }

        /**
        * Set brightness using budgie-brightness-helper --set=PERCENT (0-100).
        * brightness_percentage is already in the 0-100 range.
        */
        public void SetBrightness(int brightness_percentage)
        {
            // Clamp to valid range
            int clamped = brightness_percentage.clamp(0, 100);
            string setArg = "--set=" + clamped.to_string();
            GLib.debug("LightHelper.SetBrightness: brightness_percentage=%d setArg=%s", brightness_percentage, setArg);
            subprocessHelper.Run({Config.PACKAGE_BINDIR + "/budgie-brightness-helper", setArg});

            // Update the active light's stored brightness so Save() persists it
            list.foreach((light) =>
            {
                if (light.IsActive)
                {
                    light.Brightness = (double)clamped;
                }
            });

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
