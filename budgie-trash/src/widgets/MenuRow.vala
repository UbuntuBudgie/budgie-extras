/*
 * This file is part of UbuntuBudgie
 *
 * Copyright © 2018-2019 Ubuntu Budgie Developers
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 */

using TrashApplet.Helpers;
using TrashApplet.Models;

 namespace TrashApplet.Widgets {


 public class MenuRow : Gtk.Box {

    private GLib.FileInfo fileInfo;
    private GLib.File file;
    private Gtk.Button fileButton;
    private Gtk.Button restoreButton;
    private int restoreIconSize = 18;

    public const string trashUri = "trash:///";
    public string homePath;
    public string infoPath;
    public string srcPath;
    public string fileName;
    private TrashHelper trashHelper;

    public MenuRow(CustomFile customFile, TrashHelper trashHelper){

        this.trashHelper = trashHelper;
        this.fileInfo = customFile.getFileInfo();
        this.file = customFile.getFile();

        set_orientation(Gtk.Orientation.HORIZONTAL);
        set_spacing(0);

        fileButton = new Gtk.Button();
        pack_start(fileButton, true, true, 0);

        Gtk.Box content = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        fileButton.add(content);

        fileButton.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);
        fileButton.set_size_request(0, 36);
        fileButton.clicked.connect(fileButtonOnClick);

        fileButton.set_tooltip_text(_("Open") + " " + fileInfo.get_display_name());

        Gtk.Image icon = new Gtk.Image.from_gicon(fileInfo.get_icon(), Gtk.IconSize.INVALID);
        icon.set_pixel_size(24);
        content.pack_start(icon, false, false, 0);


        Gtk.Label fileNameLabel = new Gtk.Label(fileInfo.get_display_name());
        content.pack_start(fileNameLabel, false, false, 0);
        setMargins(fileNameLabel, 0, 0, 7, 0);
        fileNameLabel.set_halign(Gtk.Align.START);
        fileNameLabel.set_line_wrap_mode(Pango.WrapMode.CHAR);
        fileNameLabel.set_line_wrap(true);
        fileNameLabel.set_max_width_chars(30);
        fileNameLabel.set_ellipsize(Pango.EllipsizeMode.END);

        Gtk.Label timeLabel = new Gtk.Label("");
        content.pack_end(timeLabel, false, false, 0);
        setMargins(timeLabel, 0, 0, 7, 0);


        restoreButton = new Gtk.Button();
        pack_end(restoreButton, false, false, 0);
        restoreButton.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);
        Gtk.Image restoreIcon = new Gtk.Image.from_icon_name("budgie-trash-restore-symbolic", Gtk.IconSize.INVALID);
        restoreIcon.set_pixel_size(restoreIconSize);
        restoreButton.add(restoreIcon);
        restoreButton.clicked.connect(restoreButtonOnClick);
        trashHelper.bindMenuRow(this.fileInfo, restoreButton, timeLabel);

    }

    public void setMargins(Gtk.Widget widget, int top, int bottom, int left, int right){
        widget.set_margin_top(top);
        widget.set_margin_bottom(bottom);
        widget.set_margin_left(left);
        widget.set_margin_right(right);
    }

    public void fileButtonOnClick(){
        trashHelper.openFile(this.file);
    }

    public void restoreButtonOnClick(){
        trashHelper.restore(fileInfo);
    }

 }

}
