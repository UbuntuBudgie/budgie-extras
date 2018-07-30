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

using TrashApplet.Models;

namespace TrashApplet.Helpers { 
     

public class TrashHelper {

    public signal void fileRestored();
    public signal void sameNameFileFound();
    public signal void trashInfoFileNotFound();
    public signal void hidePopover();
    public signal void indicatorIconUpdated();
    public static string TRASH_EMPTY = "trash_empty";
    public static string TRASH_FULL = "trash_full";
    public static string TRASH_DELETING = "trash_deleting";

    private string state = TRASH_FULL;
    private string message;
    private const string trashFileUri = "trash:///";
    private string trashInfoPath;
    private string trashFilesPath;
    private const string trashInfoShortPath = "/.local/share/Trash/info/";
    private const string trashFilesShortPath = "/.local/share/Trash/files/";
    private GLib.File trashFile;
    private GLib.File trashInfoFile;
    private string homePath;

    public TrashHelper(){
        homePath = Environment.get_home_dir();
        trashInfoPath = homePath + trashInfoShortPath;
        trashFilesPath = homePath + trashFilesShortPath;
        trashFile = GLib.File.new_for_uri(trashFileUri);
        trashInfoFile = GLib.File.new_for_path(trashInfoPath);
    }

    //[open START]
    public void openTrashFile(){
        try {
            GLib.AppInfo.launch_default_for_uri(trashFileUri, null);
        } catch (GLib.Error e) {
            print ("Error: \"%s\"\n", e.message);
        }
    }

    public void openFile(GLib.File file){
        try {
            GLib.AppInfo.launch_default_for_uri(file.get_uri(), null);
        } catch (GLib.Error e) {
            print ("Error: \"%s\"\n", e.message);
        }
        hidePopover();
    }
    //[open END]

    //[restore START]
    public void restore(GLib.FileInfo fileInfo){

        // src, dest, infoFile
        string fileName = fileInfo.get_name();
        string fileDisplayName = fileInfo.get_display_name();
        string infoPath = trashInfoPath + fileName + ".trashinfo";
        string srcPath = trashFilesPath + fileName;
        GLib.File infoFile = GLib.File.new_for_path(infoPath);

        // Reading original Path and DeletionDate data
        // Restoring file
        if(infoFile.query_exists()){

            infoFile.read_async.begin(Priority.DEFAULT, null, (obj, res) => {
                try{
                    FileInputStream @is = infoFile.read_async.end(res);
                    DataInputStream dis = new DataInputStream(@is);
                    string line;
                    while((line = dis.read_line()) != null){
                        if(line.has_prefix("Path")){
                            string destPath = line.substring(5, -1);
                            int fileNameStartIndex = destPath.last_index_of("/");

                            string destParentPath = destPath.substring(0, fileNameStartIndex);

                            destPath = destParentPath + "/" + fileDisplayName;
              
                            restoreFile(infoFile, srcPath, destPath, destParentPath);
                        }
                        //if(line.has_prefix("DeletionDate")){
                        //    string deletionDate = line.slice(13, -1);
                        //    print ("%s\n\n", deletionDate);
                        //}
                    }
                }catch(Error e){
                    print("Error: %s\n", e.message);
                }
            });

        }else{
            showTrashInfoFileNotFoundMessage("Could not determine original location of " + fileDisplayName);
        }

    }

    public void restoreFile(GLib.File infoFile, string srcPath, string destPath, string destParentPath){

        GLib.File dest = GLib.File.new_for_path(destPath);
        GLib.File destParent = GLib.File.new_for_path(destParentPath);
        GLib.File src = GLib.File.new_for_path(srcPath);

        if (!destParent.query_exists()) {
            try {
                destParent.make_directory(null);
            } catch (Error e) {
                print ("Error: %s\n", e.message);
            }
        }

        if(src.query_exists() && !dest.query_exists()){
            try {
                src.move(dest, FileCopyFlags.NONE, null);
                infoFile.delete();
                showFileRestoredMessage(destPath + "\n " + _("restored."));
            } catch (Error e) {
                print ("Error: %s\n", e.message);
            }
        }else if(dest.query_exists()){

            showSameNameFileFoundMessage(destPath + "\n " + _("already exist."));
        }

    }
    //[restore END]

    //[get START]
    public string getMessage(){
        return this.message;
    }

    public string getState(){
        return this.state;
    }

    public GLib.File getTrashFile(){
        return trashFile;
    }

    public List<CustomFile> getCustomFiles(){
        List<CustomFile> fileInfos = new List<CustomFile>();
        if(trashFile.query_exists()){
            try{
                FileEnumerator enumerator = trashFile.enumerate_children("standard::*", FileQueryInfoFlags.NOFOLLOW_SYMLINKS, null);
                while(true){
                    FileInfo fileInfo = enumerator.next_file(null);
                    if(fileInfo != null){
                        GLib.File childFile = trashFile.get_child(fileInfo.get_name());

                        CustomFile customFile = new CustomFile(childFile, fileInfo);

                        fileInfos.append(customFile);
                    }else{
                        break;
                    }
                }
                enumerator.close(null);
            }catch(GLib.Error e){
                print ("Error: %s\n", e.message);
            }
        }
        return fileInfos;
    }
    //[get END]

    //[signal helpers START]
    public void showSameNameFileFoundMessage(string message){
        this.message = message;
        sameNameFileFound();
    }

    public void showFileRestoredMessage(string message){
        this.message = message;
        fileRestored();
    }

    public void showTrashInfoFileNotFoundMessage(string message){
        this.message = message;
        trashInfoFileNotFound();
    }

    public void updateIndicatorIcon(string state){
        this.state = state;
        indicatorIconUpdated();
    }
    //[signal helpers END]

    //[empty START]
    public void emptyTrash(){
        updateIndicatorIcon(TRASH_DELETING);
        emptyTrashInfoFile();
        emptyTrashFilesFile();
    }
    
    public void emptyTrashInfoFile(){
        if(trashInfoFile.query_exists()){
            try{
                FileEnumerator enumerator = trashInfoFile.enumerate_children("standard::*", FileQueryInfoFlags.NOFOLLOW_SYMLINKS, null);
                while(true){
                    FileInfo fileInfo = enumerator.next_file(null);
                    if(fileInfo != null){
                        GLib.File childFile = trashInfoFile.get_child(fileInfo.get_name());
                        childFile.delete();
                    }else{
                        break;
                    }
                }
            }catch(GLib.Error e){
                print ("Error: %s\n", e.message);
            }
        }
    }

    public void emptyTrashFilesFile(){
        if(trashFile.query_exists()){
            try{
                FileEnumerator enumerator = trashFile.enumerate_children("standard::*", FileQueryInfoFlags.NOFOLLOW_SYMLINKS, null);

                while(true){
                    FileInfo fileInfo = enumerator.next_file(null);

                    if(fileInfo != null){
                       
                        GLib.File childFile = trashFile.get_child(fileInfo.get_name());
                        moveFileToCacheThenDelete(childFile, fileInfo.get_name());

                    }else{
                        updateIndicatorIcon(TRASH_EMPTY);
                        break;
                    }
                }

            }catch(GLib.Error e){
                print ("Error: %s\n", e.message);
            }
        }
    }

    public void deleteFile(GLib.File file, bool deleteDirectory){
        try{
            updateIndicatorIcon(TRASH_DELETING);
            GLib.FileType fileType = file.query_file_type (GLib.FileQueryInfoFlags.NONE, null);
            if(fileType == GLib.FileType.DIRECTORY) {
                deleteDirectoryContent(file, deleteDirectory);
            }else{
                file.delete();
                updateIndicatorIcon(TRASH_EMPTY);
            }
        }catch(GLib.Error e){
            print ("Error: %s\n", e.message);
        }
    }

    public void deleteDirectoryContent(GLib.File file, bool deleteDirectory){
        try{
            FileEnumerator enumerator = file.enumerate_children("standard::*", FileQueryInfoFlags.NOFOLLOW_SYMLINKS, null);
            while(true){
                FileInfo fileInfo = enumerator.next_file(null);
                if(fileInfo != null){
                    GLib.File childFile = file.get_child(fileInfo.get_name());
                    deleteFile(childFile, true);
                }else{
                    if(deleteDirectory){
                        file.delete(null);
                    }
                    updateIndicatorIcon(TRASH_EMPTY);
                    break;
                }
            }
        }catch(GLib.Error e){
            print ("Error: %s\n", e.message);
        }
        
    }

    public bool isTrashEmpty(){
        if(trashFile.query_exists()){
            try{
                FileEnumerator enumerator = trashFile.enumerate_children("standard::*", FileQueryInfoFlags.NOFOLLOW_SYMLINKS, null);
                FileInfo fileInfo = enumerator.next_file(null);
                if(fileInfo != null){
                    return false;
                }else{
                    return true;
                }
            }catch(GLib.Error e){
                print ("Error: %s\n", e.message);
                return true;
            }
        }else{
            return false;
        }
    }

    public void moveFileToCacheThenDelete(GLib.File src, string fileName){
        if(src.query_exists()){
            try{

                string homePath = Environment.get_home_dir();
                string destPath = homePath + "/.cache/budgie-trash/" + fileName;
                string destParentPath = homePath + "/.cache/budgie-trash/";

                GLib.File destParent = GLib.File.new_for_path(destParentPath);
                GLib.File dest = GLib.File.new_for_path(destPath);

                if(!destParent.query_exists()){
                    destParent.make_directory();
                }

                src.move(dest, FileCopyFlags.NONE, null);
                deleteFile(dest, true);
            } catch (Error e) {
                print ("Error: %s\n", e.message);
            }
        }
    }
    //[empty END]

    //[other START]
    public void bindMenuRow(GLib.FileInfo fileInfo, Gtk.Button restoreButton, Gtk.Label timeLabel){

        // src, dest, infoFile
        string fileName = fileInfo.get_name();
        string infoPath = trashInfoPath + fileName + ".trashinfo";
        //// string srcPath = trashFilesPath + fileName;
        GLib.File infoFile = GLib.File.new_for_path(infoPath);

        // Reading original Path and DeletionDate data
        // Restoring file
        if(infoFile.query_exists()){
            infoFile.read_async.begin(Priority.DEFAULT, null, (obj, res) => {
                try{
                    FileInputStream @is = infoFile.read_async.end(res);
                    DataInputStream dis = new DataInputStream(@is);
                    string line;
                    while((line = dis.read_line()) != null){
                        if(line.has_prefix("Path")){
                            string destPath = line.substring(5, -1);
                            int fileNameStartIndex = destPath.last_index_of("/");
                            string destParentPath = destPath.substring(0, fileNameStartIndex);
                            destPath = destParentPath + "/" + fileName;
                            //fileButton.set_tooltip_text(destParentPath);
                            restoreButton.set_tooltip_text(_("Restore") + " " + destPath);
                            
                        }
                        if(line.has_prefix("DeletionDate")){
                           string deletionDate = line.slice(13, -1);
                           //print ("%s\n\n", deletionDate);
                           string time = deletionDate.slice(11, 16);
                           timeLabel.set_text(time);
                        }
                    }
                }catch(Error e){
                    print("Error: %s\n", e.message);
                }
            });

        }

    }
    //[other END]

}

}