/*
 * BrightnessController
 * This file is part of budgie-extras
 *
 * Author: Serdar ŞEN github.com/serdarsen
 *
 * Copyright © 2018-2021 Ubuntu Budgie Developers
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 */

namespace BrightnessController.Widgets
{
public class IndicatorButton : Gtk.EventBox
{
    private Gtk.Image indicatorIcon;

    public IndicatorButton()
    {
        indicatorIcon = new Gtk.Image.from_icon_name("budgie-brightness-controller-1-symbolic", Gtk.IconSize.MENU);
        add(indicatorIcon);
        show_all();
    }
}
}