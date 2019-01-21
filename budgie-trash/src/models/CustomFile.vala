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

namespace TrashApplet.Models {

public class CustomFile {

    private GLib.File file;
    private GLib.FileInfo fileInfo;

    public CustomFile(GLib.File file, GLib.FileInfo fileInfo){
        this.file = file;
        this.fileInfo = fileInfo;
    }

    public GLib.File getFile(){
        return this.file;
    }

    public GLib.FileInfo getFileInfo(){
        return this.fileInfo;
    }

}

}
