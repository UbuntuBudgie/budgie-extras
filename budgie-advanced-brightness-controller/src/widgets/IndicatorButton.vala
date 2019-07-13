/*
 * AdvancedBrightnessController 
 * This file is part of UbuntuBudgie
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

namespace AdvancedBrightnessController.Widgets
{
public class IndicatorButton : Gtk.EventBox 
{
    private Gtk.Image indicatorIcon;

    public IndicatorButton() 
    {
        indicatorIcon = new Gtk.Image.from_icon_name("budgie-advanced-brightness-controller-1-symbolic", Gtk.IconSize.MENU);
        add(indicatorIcon);
        show_all();
    }
}
}