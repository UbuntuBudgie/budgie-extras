/*
 * BrightnessController 
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

namespace BrightnessController.Widgets
{
public class CustomMenuButton : Gtk.MenuButton
{
    private Gtk.Menu menu;
    private List<Gtk.MenuItem> itemList;

    public CustomMenuButton(string labelText) 
    {
        add(new Gtk.Label(_(labelText)));
        direction = Gtk.ArrowType.DOWN;
        get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
        
        itemList = new List<Gtk.MenuItem>();
        menu = new Gtk.Menu();
        popup = menu;
    }

    public void Add(Gtk.MenuItem item)
    {
        itemList.append(item);
        menu.append(item);
    }

    public void Select(Gtk.MenuItem item)
    {
        itemList.foreach((item)=> 
        {
            item.deselect();
        });
        item.select();
    }

    public void ShowAll()
    {
        menu.show_all();
    }
}
}