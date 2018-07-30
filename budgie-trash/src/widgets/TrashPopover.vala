/*
 * This file is part of UbuntuBudgie
 *
 * Copyright © 2015-2017 Budgie Desktop Developers
 * Copyright © 2018-2019 Ubuntu Budgie Developers
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 */

using TrashApplet.Widgets;
using TrashApplet.Helpers;
using TrashApplet.Models;

namespace TrashApplet.Widgets { 
 
public class TrashPopover : Budgie.Popover {

    private const string PAGE_1 = "page1";
    private const string PAGE_2 = "page2";
    private string state = TrashHelper.TRASH_EMPTY;

    private Gtk.Stack stack;
    private MessageRevealer messageBar;
    private Gtk.Button openButton;
    private Gtk.Button emptyButton;
    private Gtk.Button noButton;
    private Gtk.Button yesButton;
    private Gtk.Spinner spinner;
    private Gtk.EventBox indicatorBox;
    private Gtk.Image indicatorIcon;
    private Gtk.ScrolledWindow scrollWindow;
    private Gtk.Box trashFileContaner;
    private GLib.FileMonitor monitor;

    private TrashHelper trashHelper;
    private int popoverWidth = 300;
    private int popoverHeight = 400;


    public TrashPopover(Gtk.EventBox indicatorBox) {
        Object(relative_to: indicatorBox);
    
        set_default_size(popoverWidth, popoverHeight); // popover size
        set_resizable(false);
        initTrashHelper();
        buildIndicatorBox(indicatorBox);
        initTrashFileMonitor();
        buildStack();
        bindTrashFileContainer();
        update();
    }

    //[build START]
    public void buildIndicatorBox(Gtk.EventBox indicatorBox){
        this.indicatorBox = indicatorBox;
        indicatorIcon = new Gtk.Image.from_icon_name("budgie-trash-full-symbolic", Gtk.IconSize.MENU);
        this.indicatorBox.add(indicatorIcon);
    }

    public void buildStack(){
        //Stack
        stack = new Gtk.Stack();
        add(stack);
        stack.set_homogeneous(true);
        stack.set_transition_type(Gtk.StackTransitionType.SLIDE_LEFT_RIGHT);

        //Page1
        Gtk.Box page1 = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        page1.border_width = 0;
        stack.add_named(page1, PAGE_1);

        //Page1 Content

        Gtk.Box page1ToolBar = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        page1.pack_start(page1ToolBar, false, false, 0);
        page1ToolBar.set_homogeneous(true);
        openButton = new Gtk.Button.with_label(_("Open"));
        page1ToolBar.pack_start(openButton, true, true, 0);
        //openButton.get_child().halign = Gtk.Align.START;
        setMargins(page1ToolBar, 5, 1, 1, 1);
        openButton.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);
        openButton.set_size_request(0, 36);
        openButton.clicked.connect(openButtonOnClick);

        emptyButton = new Gtk.Button.with_label(_("Empty"));
        page1ToolBar.pack_end(emptyButton, true, true, 0);
        //emptyButton.get_child().halign = Gtk.Align.START;
        emptyButton.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);
        emptyButton.set_size_request(0, 36);
        emptyButton.clicked.connect(emptyButtonOnClick);

        messageBar = new MessageRevealer();
        messageBar.set_no_show_all(true);
        page1.pack_start(messageBar, false, true, 0);

        scrollWindow = new Gtk.ScrolledWindow(null, null);
        page1.pack_start(scrollWindow, true, true, 0);
        scrollWindow.set_overlay_scrolling(true);
        scrollWindow.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        trashFileContaner = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        scrollWindow.add(trashFileContaner);
        setMargins(trashFileContaner, 5, 1, 1, 1);

        //Page2
        Gtk.Box page2 = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        page2.border_width = 0;
        stack.add_named(page2, PAGE_2);
        // setMargins(page2, 10, 1, 3, 3);

        //Page1 Content
        Gtk.Box titlesContainer =new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        page2.set_center_widget(titlesContainer);
        
        Gtk.Label dialogTitleLabel = new Gtk.Label("");
        dialogTitleLabel.set_markup(_("Empty all items from the Trash?"));
        // dialogTitleLabel.set_halign(Gtk.Align.CENTER);
        dialogTitleLabel.set_justify(Gtk.Justification.CENTER);
        dialogTitleLabel.set_line_wrap_mode(Pango.WrapMode.WORD_CHAR);
        dialogTitleLabel.set_line_wrap(true);
        dialogTitleLabel.set_max_width_chars(30);
        titlesContainer.pack_start(dialogTitleLabel, false, false, 0);
        dialogTitleLabel.set_margin_bottom(15);

        Gtk.Label dialogSubTitleLabel = new Gtk.Label(_("All items in the Trash will be permanently deleted."));
        //dialogSubTitleLabel.set_halign(Gtk.Align.CENTER);
        dialogSubTitleLabel.set_justify(Gtk.Justification.CENTER);
        dialogSubTitleLabel.set_line_wrap_mode(Pango.WrapMode.WORD_CHAR);
        dialogSubTitleLabel.set_line_wrap(true);
        dialogSubTitleLabel.set_max_width_chars(30);
        dialogSubTitleLabel.get_style_context().add_class("dim-label");
        titlesContainer.pack_start(dialogSubTitleLabel, false, false, 0);
        dialogTitleLabel.set_margin_bottom(15);

        Gtk.Box yesNoButtonContainer = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        page2.pack_end(yesNoButtonContainer, false, false, 0);
        yesNoButtonContainer.set_homogeneous(true);

        noButton = new Gtk.Button.with_label(_("Cancel"));
        yesNoButtonContainer.pack_start(noButton, true, true, 0);
        //openButton.get_child().halign = Gtk.Align.START;
        noButton.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);
        noButton.set_size_request(0, 36);
        noButton.clicked.connect(noButtonOnClick);

        yesButton = new Gtk.Button.with_label(_("Empty Trash"));
        yesNoButtonContainer.pack_end(yesButton, true, true, 0);
        //emptyButton.get_child().halign = Gtk.Align.START;
        yesButton.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);
        yesButton.get_style_context().add_class("destructive-action");
        yesButton.set_size_request(0, 36);
        yesButton.clicked.connect(yesButtonOnClick);
    }
    //[build END]

    //[init START]
    public void initTrashHelper(){
        trashHelper = new TrashHelper();
        trashHelper.fileRestored.connect(onFileRestore);
        trashHelper.sameNameFileFound.connect(onSameNameFileFind);
        trashHelper.trashInfoFileNotFound.connect(onTrashInfoFileNotFind);
        trashHelper.hidePopover.connect(onHidePopover);
        trashHelper.indicatorIconUpdated.connect(onIndicatorIconUpdate);
    }

    public void initTrashFileMonitor(){
        try {
            monitor = trashHelper.getTrashFile().monitor_directory(FileMonitorFlags.NONE, null);
            monitor.changed.connect ((src, dest, event) => {
                update();
            });
        } catch (Error err) {
            print ("Error: %s\n", err.message);
        }
    }
    //[init END]

    //[open START]
    public void openStackPage1(){
        stack.set_visible_child_name(PAGE_1);
    }

    public void openStackPage2(){
        stack.set_visible_child_name(PAGE_2);
    }
    //[open END]

    //[signal callbacks START]
    public void openButtonOnClick(){
        hide();
        trashHelper.openTrashFile();
    }

    public void emptyButtonOnClick(){
        openStackPage2();
    }

    public void noButtonOnClick(){
        openStackPage1();
    }

    public void yesButtonOnClick(){
        trashHelper.emptyTrash();
        hide();
        scrollTop();
        openStackPage1();
    }

    public void onFileRestore(){
        showMessage(trashHelper.getMessage());
        update();
    }

    public void onSameNameFileFind(){
        showMessage(trashHelper.getMessage());
    }

    public void onTrashInfoFileNotFind(){
        showMessage(trashHelper.getMessage());
    }

    public void onHidePopover(){
        hide();
    }

    public void onIndicatorIconUpdate(){
       updateIndicatorIcon(trashHelper.getState());
    }
    //[signal callbacks END]

    //[update START]
    public void update(){ 
        openStackPage1();  
        if(trashHelper.isTrashEmpty()){
            emptyButton.set_sensitive(false);
            updateIndicatorIcon(TrashHelper.TRASH_EMPTY);
        }else{
            emptyButton.set_sensitive(true);
            updateIndicatorIcon(TrashHelper.TRASH_FULL);
        }
        bindTrashFileContainer();
        set_size_request(popoverWidth, popoverHeight);
    }

    public void updateIndicatorIcon(string state){
        if(indicatorBox != null){
            foreach(var widget in indicatorBox.get_children()){
                widget.destroy();
            }
            this.state = state;
            if(state == TrashHelper.TRASH_EMPTY){
                indicatorIcon = new Gtk.Image.from_icon_name("budgie-trash-empty-symbolic", Gtk.IconSize.MENU);
                indicatorBox.add(indicatorIcon);
            }else if(state == TrashHelper.TRASH_FULL){
                indicatorIcon = new Gtk.Image.from_icon_name("budgie-trash-full-symbolic", Gtk.IconSize.MENU);
                indicatorBox.add(indicatorIcon);
            }else if(state == TrashHelper.TRASH_DELETING){
                spinner = new Gtk.Spinner();
                indicatorBox.add(spinner);
                spinner.start();
            }
            indicatorBox.show_all();
        }
    }
    //[update END]

    //[other START]
    public void bindTrashFileContainer(){

        //cleanTrashFileContainer
        if(trashFileContaner != null){
            foreach(var widget in trashFileContaner.get_children()){
                widget.destroy();
            }
        }

        //bind
        List<CustomFile> customFiles = trashHelper.getCustomFiles();
        if(trashFileContaner != null && customFiles != null){
            foreach(CustomFile customFile in customFiles){
                MenuRow menuRow = new MenuRow(customFile, trashHelper);
                trashFileContaner.add(menuRow);
                trashFileContaner.show_all();
            }
        }

    }

    public void scrollTop(){
        if(scrollWindow != null){
            scrollWindow.get_vadjustment().set_value(0);
        }
    }

    public void setMargins(Gtk.Widget widget, int top, int bottom, int left, int right){
        widget.set_margin_top(top);
        widget.set_margin_bottom(bottom);
        widget.set_margin_left(left);
        widget.set_margin_right(right);
    }

    private void showMessage(string message) {
        messageBar.set_content(message);
    }

    public override void closed()
    {
        messageBar.hide_it();
    }
    //[other END]

}

}