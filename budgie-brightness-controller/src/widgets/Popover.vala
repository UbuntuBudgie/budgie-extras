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

using BrightnessController.Helpers;
using BrightnessController.Widgets;
using BrightnessController.Models;

namespace BrightnessController.Widgets
{
public class Popover : Budgie.Popover
{
    private Gtk.Grid grid;
    private CustomScale dimScale;
    private CustomScale blueScale;
    private CustomScale lightScale;
    private Gtk.Label dimLabel;
    private Gtk.Label blueLabel;
    private Gtk.Label lightLabel;
    private DimHelper dimHelper;
    private LightHelper lightHelper;
    private Dim CurrentDim {get; set;}
    private Light CurrentLight {get; set;}

    public Popover(IndicatorButton indicatorButton, int witdh, int height)
    {
        Object(relative_to: indicatorButton);

        dimHelper = new DimHelper();
        lightHelper = new LightHelper();

        if(dimHelper.IsAvailable && lightHelper.IsAvailable)
        {
            set_size_request(witdh, height);
        }
        else
        {
            set_size_request(witdh / 2, height);
        }

        BuildViews();
    }

    //[START Build]
    public void BuildViews()
    {
        BuildGrid();

        if(dimHelper.IsAvailable)
        {
            BuildDim();
        }

        if(lightHelper.IsAvailable)
        {
            BuildLight();
        }

        get_child().show_all();
    }

    public void BuildGrid()
    {
        grid = new Gtk.Grid();
        grid.set_column_spacing(10);
        grid.set_row_spacing(10);
        grid.set_column_homogeneous(true);
        grid.set_margin_top(5);
        grid.set_margin_bottom(5);
        grid.set_margin_left(5);
        grid.set_margin_right(5);
        add(grid);
    }

    public void BuildDim()
    {
        var menuButton = new CustomMenuButton(_("Dim"));
        dimLabel = new Gtk.Label("");
        dimLabel.set_tooltip_text(_("Brightness"));
        blueLabel = new Gtk.Label("");
        blueLabel.set_tooltip_text(_("Temperature"));
        dimScale = new CustomScale(0, 10, 0, 1, 0.1, 0);
        blueScale = new CustomScale(0, 10, 0, 1, 0.1, 0);

        dimHelper.list.foreach((dim)=>
        {
            var item = new Gtk.MenuItem.with_label(dim.Name);
            menuButton.Add(item);
            item.activate.connect(()=>
            {
                menuButton.Select(item);
                dimHelper.SetActive(dim);
                PopulateDim(dim);
            });

            if(dim.IsActive)
            {
                item.select();
                PopulateDim(dim);
            }
        });
        menuButton.ShowAll();

        dimScale.value_changed.connect(()=>
        {
            CurrentDim.Brightness = dimScale.Value;
            dimLabel.set_text(CurrentDim.BrightnessText);
            dimHelper.SetBrightness(CurrentDim.Name, CurrentDim.Brightness, CurrentDim.Blue);
        });

        blueScale.value_changed.connect(()=>
        {
            CurrentDim.Blue = blueScale.Value;
            blueLabel.set_text(CurrentDim.BlueText);
            dimHelper.SetBrightness(CurrentDim.Name, CurrentDim.Brightness, CurrentDim.Blue);
        });

        dimHelper.SetBrightness(CurrentDim.Name, CurrentDim.Brightness, CurrentDim.Blue);

        grid.attach(menuButton, 1, 0, 2, 1);

        grid.attach(dimScale, 1, 1, 1, 1);
        grid.attach(dimLabel, 1, 2, 1, 1);

        grid.attach(blueScale, 2, 1, 1, 1);
        grid.attach(blueLabel, 2, 2, 1, 1);
    }

    public void BuildLight()
    {
        var menuButton = new CustomMenuButton(_("Light"));
        lightLabel = new Gtk.Label("");
        lightLabel.set_tooltip_text(_("Brightness"));
        lightScale = new CustomScale(0, 0, 0, 1, 1, 0);

        lightHelper.list.foreach((light) =>
        {
            var item = new Gtk.MenuItem.with_label(light.Name);
            menuButton.Add(item);
            item.activate.connect(()=>
            {
                menuButton.Select(item);
                lightHelper.SetActive(light);
                PopulateLight(light);
            });

            if(light.IsActive)
            {
                item.select();
                PopulateLight(light);
            }
        });
        menuButton.ShowAll();

        lightScale.value_changed.connect(()=>
        {
            CurrentLight.Brightness = lightScale.Value;
            lightLabel.set_text(CurrentLight.BrightnessText);
            lightHelper.SetBrightness(CurrentLight.Name, CurrentLight.Brightness);
        });
        lightHelper.SetBrightness(CurrentLight.Name, CurrentLight.Brightness);

        grid.attach(menuButton, 0, 0, 1, 1);
        grid.attach(lightScale, 0, 1, 1, 1);
        grid.attach(lightLabel, 0, 2, 1, 1);
    }
    //[END Build]

    //[START Populate]
    private void PopulateLight(Light light)
    {
        CurrentLight = light;
        lightLabel.set_text(CurrentLight.BrightnessText);
        lightScale.Update(CurrentLight.Brightness, 0, CurrentLight.MaxBrightness);
    }

    private void PopulateDim(Dim dim)
    {
        CurrentDim = dim;
        dimLabel.set_text(CurrentDim.BrightnessText);
        dimScale.Update(CurrentDim.Brightness, 10, CurrentDim.MaxBrightness);
        blueLabel.set_text(CurrentDim.BlueText);
        blueScale.Update(CurrentDim.Blue, 10, CurrentDim.MaxBrightness);
    }
    //[END Populate]

    //[START Update]
    private async void UpdateLight()
    {
        var name = CurrentLight.Name;
        string output = "";
        var subprocessLauncher = new SubprocessLauncher (SubprocessFlags.STDOUT_PIPE);

        try
        {
            if(lightHelper.haveGnomeSettingsDaemon332)
            {
                yield subprocessLauncher.spawnv(
                    {Config.PACKAGE_BINDIR + "/cat", @"/sys/class/backlight/$name/brightness"}
                ).communicate_utf8_async(null, null, out output, null);
            }
            else if(lightHelper.haveGnomeSettingsDaemonOlderThan332)
            {
                yield subprocessLauncher.spawnv(
                    {Config.PACKAGE_BINDIR + "/pkexec", Config.PACKAGE_LIBDIR + "/gnome-settings-daemon/gsd-backlight-helper", "--get-brightness"}
                ).communicate_utf8_async(null, null, out output, null);
            }

            if(output == "")
            {
                return;
            }

            if(CurrentLight.Brightness != output.to_double())
            {
                CurrentLight.Brightness = output.to_double();
                PopulateLight(CurrentLight);
                lightHelper.Save();
            }
        }
        catch (Error e)
        {
            GLib.message("Failed to run : %s", e.message);
        }
    }
    //[END Update]

    //[START On]
    public void OnShow()
    {
        if(dimHelper == null && lightHelper == null)
        {
            return;
        }

        UpdateLight.begin();

        dimHelper.SetBrightness(CurrentDim.Name, CurrentDim.Brightness, CurrentDim.Blue);
        PopulateDim(CurrentDim);
    }
    //[END On]
}
}