/*
 * AdvancedBrightnessController 
 * This file is part of budgie-extras
 * 
 * Author: Serdar ŞEN github.com/serdarsen
 * 
 * Copyright © 2018-2019 Ubuntu Budgie Developers
 * 
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 */

using AdvancedBrightnessController.Models;

namespace AdvancedBrightnessController.Helpers 
{
/**
 * DimHelper is a helper to work with 
 * xrandr
 * Currently working correctly with xrandr-1.5.0
 * 
 */
public class DimHelper
{
    public bool IsAvailable {get; set;}
    private bool haveXrandr150 = false;
    public List<Dim> list;

    private SubprocessHelper subprocessHelper;
    private ConfigHelper configHelper;

    // private int noOfConnectedDev = 0;

    public DimHelper()
    {
        subprocessHelper = new SubprocessHelper();
        configHelper  = new ConfigHelper("budgie-advanced-brightness-controller", "dim");
        Load();
    }

    private void Load()
    {
        list = new List<Dim>();

        // Load Dims From Config
        var retrivedDimNames = new string[]{};
        var dimObjects = configHelper.Read();

        foreach (var obj in dimObjects) 
        {
            var properties = obj.split(" ");
            if(properties.length > 4)
            {
                var dim = new Dim();
                dim.Name = properties[0];
                retrivedDimNames += dim.Name;
                dim.MaxBrightness = properties[1].to_double();
                dim.Brightness = properties[2].to_double();
                dim.Blue = properties[3].to_double();
                dim.IsActive = properties[4].to_bool();

                //print(@"Load Dims From Config: %s, %s, %s, %s \n", dim.Name, dim.MaxBrightnessText, dim.BrightnessText, dim.IsActive.to_string());
                list.append(dim);
            }
        }

        // Load Dims From Device
        var dimsString = subprocessHelper.RunAndGetResult({"xrandr", "-q"});

        dimsString = dimsString._strip(); 
        if (dimsString == "")
        {
            return;
        }

        var lines = dimsString.split("\n");
        var connectedDeviceCount = 0;
        foreach (var line in lines)
        {
            line = line._strip();
            if(line != "")
            {
                var words = line.split(" ");
                foreach(var word in words)
                {
                    if (word == "connected"
                        && !strv_contains(retrivedDimNames, words[0]))
                    {
                        var dim = new Dim();
                        dim.Name = words[0]; 
                        dim.MaxBrightness = 100;
                        dim.Brightness = 100;
                        dim.Blue = 100;
                    
                        if(connectedDeviceCount == 0)
                        {
                            dim.IsActive = true;
                        }
                        else
                        {
                            dim.IsActive = false;
                        }
                        list.append(dim);
                        
                        //print(@"Load Dims From Device: %s, %s, %s, %s \n", dim.Name, dim.MaxBrightnessText, dim.BrightnessText, dim.IsActive.to_string());
                        connectedDeviceCount++;
                    }
                }
            }
        }   

        #if HAVE_XRANDR_1_5_0
            haveXrandr150 = true;
        #endif

        if (haveXrandr150 && list.length() > 0)
        {
            IsAvailable = true;
        }
        else
        {
            IsAvailable = false;

            var dimListLength = list.length();
            GLib.message(@"Dim is not available (Xrandr version >= 1.5.0: $haveXrandr150, Number of Dims: $dimListLength)\n");
        }
    }
    
    public void SetBrightness(string name, double brightness, double blue)
    {
        //print(@"DimHelper.SetBrightness: $name $brightness \n");
        var aOnePercentOfbrightness = brightness / 100;
        var aOnePercentOfBlue = blue / 100;
        subprocessHelper.Run({"xrandr", "--output", @"$name", "--gamma", @"1:1:$aOnePercentOfBlue", "--brightness", @"$aOnePercentOfbrightness"});
        Save();
    }

    public void SetActive(Dim dim)
    {
        list.foreach((dim)=>
        {
            dim.IsActive = false;
        });
        dim.IsActive = true;
        Save();
    }

    public void Save()
    {
        var data = new string[]{};
        list.foreach((dim)=> 
        {
            var name = dim.Name;
            var maxBrightness = dim.MaxBrightnessText;
            var brightness = dim.BrightnessText;
            var blue = dim.BlueText;
            var isActive = dim.IsActive;
            data += (@"$name $maxBrightness $brightness $blue $isActive");
        });
        configHelper.Write(data);
    }
}
}