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

namespace BrightnessController.Widgets
{
public class CustomScale : Gtk.Scale
{
    public double Value
    {
        get{return adjustment.value;}
        set{adjustment.value = value;}
    }

    public CustomScale(double currentValue, double lower, double upper,
                       double stepIncrement, double pageIncrement, double pageSize)
    {
        adjustment.value = currentValue;
        adjustment.lower = lower;

        adjustment.step_increment = stepIncrement;
        adjustment.page_increment = pageIncrement;
        adjustment.page_size = pageSize;

        orientation = Gtk.Orientation.VERTICAL;

        set_value_pos(Gtk.PositionType.BOTTOM);
        set_draw_value (false);
        set_vexpand(true);
        set_hexpand(true);
        set_inverted(true);

        set_value(currentValue);
    }

    public void Update(double currentValue, double lower, double upper)
    {
        adjustment.value = currentValue;
        adjustment.upper = upper;

        if(upper >= 100)
        {
            adjustment.lower = 10;
        }
        else
        {
            adjustment.lower = lower;
        }

        set_value(currentValue);
    }
}
}