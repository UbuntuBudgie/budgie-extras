#!/usr/bin/env python3

# This file is part of App Launcher

# Copyright © 2018-2019 Ubuntu Budgie Developers

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.


import gi.repository

gi.require_version('Gtk', '3.0')
gi.require_version('GMenu', '3.0')
gi.require_version('Budgie', '1.0')
from gi.repository import Budgie
from gi.repository import GMenu
from gi.repository import Gtk
from gi.repository import Gdk
from AppButton import AppButton
from PanelButton import PanelButton
from ArrowButton import ArrowButton
from EditButton import EditButton
from MenuButton import MenuButton
from DirectionalButton import DirectionalButton
from App import App
from SortHelper import SortHelper
from FilterHelper import FilterHelper
from LocaleHelper import LocaleHelper
from Log import Log
from Error import Error
from SelectButton import SelectButton


class AppLauncherApplet(Budgie.Applet):
    # Budgie.Applet is in fact a Gtk.Bin

    def __init__(self, uuid):
        self.TAG = "budgie-app-launcher.AppLauncher"
        self.APPINDICATOR_ID = "io_serdarsen_github_budgie_app_launcher"
        self.APPS_ID = "gnome-applications.menu"
        self.log = Log("budgie-app-launcher")
        self.sortHelper = SortHelper()
        self.filterHelper = FilterHelper()
        self.localHelper = LocaleHelper()
        self.iconSize = 24
        self.showOnPanel = 0
        self.tree = None  # GMenu.Tree
        self.appButtonsContainer = None  # Gtk.ListBox
        self.contentScroll = None  # Gtk.ScrolledWindow
        self.allAppsContentScroll = None
        self.currentMenuButton = None
        self.menuButtons = []
        self.allApps = []
        self.filteredActiveApps = []
        self.activeApps = []
        self.inactiveApps = []
        self.appLimitOnPanel = 10
        self.manager = None
        self.popover = None
        self.popoverHeight = 0
        self.popoverWidth = 300
        self.popoverHeight = 510
        Budgie.Applet.__init__(self)
        self.iconSize = self.localHelper.retriveIconSize()
        self.showOnPanel = self.localHelper.retriveShowOnPanel()
        self.buildIndicator()
        self.buildPopover()
        self.buildStack()
        self.loadAllApps()
        self.loadAppButtons()
        self.loadPanelButtons()
        self.vertical = False

    def do_panel_position_changed(self, position):
        # wait for signal, change orientation if it occurs
        check_or = any([
            position == Budgie.PanelPosition(pos) for pos in [8, 16]
        ])
        self.vertical = True if check_or else False
        self.reload_elements()

    def reload_elements(self):
        # on orientation change of the panel, set applet accordingly
        self.panelButtonsContainer.destroy()
        self.panelButtonsContainer = Gtk.VBox() if self.vertical \
            else Gtk.HBox()
        self.indicatorBox.add(self.panelButtonsContainer)
        self.update()

    ####################################
    # build START
    ####################################

    def buildIndicator(self):
        self.indicatorBox = Gtk.EventBox()
        self.panelButtonsContainer = Gtk.VBox()
        self.indicatorBox.add(self.panelButtonsContainer)
        self.add(self.indicatorBox)

    def buildPopover(self):
        self.popover = Budgie.Popover.new(self.indicatorBox)
        self.popover.set_default_size(self.popoverWidth, self.popoverHeight)
        self.popover.get_child().show_all()
        self.show_all()

    def buildStack(self):
        self.stack = Gtk.Stack()
        self.stack.set_homogeneous(False)
        self.stack.set_transition_type(
            Gtk.StackTransitionType.SLIDE_LEFT_RIGHT)
        self.popover.add(self.stack)
        self.buildStackPage1()
        self.buildStackPage2()

    def buildStackPage1(self):
        # page 1
        page1 = Gtk.Box(Gtk.Orientation.VERTICAL, 0)
        page1.border_width = 0
        self.stack.add_named(page1, "page1")
        page1.get_style_context().add_class("budgie-menu")
        # page 1 content
        page1InnerBox = Gtk.VBox()
        page1.pack_start(page1InnerBox, True, True, 0)
        titleBox = Gtk.HBox()
        page1InnerBox.pack_start(titleBox, False, False, 0)
        self.setMargins(titleBox, 3, 3, 3, 0)

        self.searchEntry = Gtk.SearchEntry()
        titleBox.pack_start(self.searchEntry, True, True, 0)
        self.searchEntry.connect("search-changed", self.searchEntryOnChange)
        self.searchEntry.connect("activate", self.searchEntryOnActivate)
        editButton = EditButton("Edit")
        editButton.connect("clicked", self.editButtonOnClick)
        titleBox.pack_end(editButton, False, False, 0)
        self.contentScroll = Gtk.ScrolledWindow(None, None)
        page1InnerBox.pack_start(self.contentScroll, True, True, 0)
        self.contentScroll.set_overlay_scrolling(True)
        self.contentScroll.set_policy(Gtk.PolicyType.NEVER,
                                      Gtk.PolicyType.AUTOMATIC)
        self.appButtonsContainer = Gtk.ListBox()
        self.contentScroll.add(self.appButtonsContainer)
        # self.content.row_activated.connect(on_row_activate)
        self.appButtonsContainer.set_selection_mode(Gtk.SelectionMode.NONE)
        # placeholder in case of no results
        placeholder = Gtk.Label("App Launcher")
        placeholder.use_markup = True
        placeholder.get_style_context().add_class("dim-label")
        placeholder.show()
        placeholder.margin = 6
        self.appButtonsContainer.valign = Gtk.Align.START
        self.appButtonsContainer.set_placeholder(placeholder)

    def buildStackPage2(self):
        # page 2
        page2 = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        page2.border_width = 0
        self.setMargins(page2, 10, 3, 3, 3)
        self.stack.add_named(page2, "page2")

        # page 2 toolbar
        page2Toolbar = Gtk.HBox()
        page2.pack_start(page2Toolbar, False, False, 0)
        # page 2 toolbar content
        # cancel
        backButton = DirectionalButton("Back", Gtk.PositionType.LEFT)
        page2Toolbar.pack_start(backButton, True, True, 0)
        backButton.connect("clicked", self.backButtonOnClick)
        # up
        self.upButton = ArrowButton(Gtk.PositionType.TOP)
        page2Toolbar.pack_start(self.upButton, True, True, 0)
        self.upButton.connect("clicked", self.upButtonOnClick)
        self.upButton.set_sensitive(False)
        # down
        self.downButton = ArrowButton(Gtk.PositionType.BOTTOM)
        page2Toolbar.pack_start(self.downButton, True, True, 0)
        self.setMargins(page2Toolbar, 0, 3, 0, 0)
        self.downButton.connect("clicked", self.downButtonOnClick)
        self.downButton.set_sensitive(False)
        # done
        self.doneButton = Gtk.Button("Apply")
        self.doneButton.get_style_context().add_class("flat")
        page2Toolbar.pack_end(self.doneButton, True, True, 0)
        self.doneButton.connect("clicked", self.doneButtonOnClick)

        # page 2 toolbar 2
        page2Toolbar2 = Gtk.HBox()
        page2.pack_start(page2Toolbar2, False, False, 0)
        self.deselectButton = SelectButton(False)
        page2Toolbar2.pack_start(self.deselectButton, False, False, 0)
        self.deselectButton.addOnClickMethod(self.deselectButtonOnClick)
        self.selectButton = SelectButton(True)
        page2Toolbar2.pack_end(self.selectButton, False, False, 0)
        self.selectButton.addOnClickMethod(self.selectButtonOnClick)
        self.setMargins(page2Toolbar2, 0, 3, 0, 0)

        # page 2 allAppsContainer
        self.allAppsContainer = Gtk.VBox()
        page2.pack_start(self.allAppsContainer, True, True, 0)
        self.allAppsContentScroll = Gtk.ScrolledWindow(None, None)
        self.allAppsContainer.pack_start(self.allAppsContentScroll, True, True,
                                         0)
        self.allAppsContentScroll.set_overlay_scrolling(True)
        self.allAppsContentScroll.set_policy(Gtk.PolicyType.NEVER,
                                             Gtk.PolicyType.AUTOMATIC)
        self.menuButtonsContainer = Gtk.VBox()
        self.setMargins(self.menuButtonsContainer, 0, 0, 0, 7)
        self.allAppsContentScroll.add(self.menuButtonsContainer)
        # page 2 bottom bar
        page2BottomBar = Gtk.VBox()
        page2.pack_start(page2BottomBar, False, False, 0)
        self.setMargins(page2BottomBar, 10, 3, 3, 3)
        # page2BottomBar show panel Container
        page2BottomBarShowPanelContainer = Gtk.HBox()
        page2BottomBar.pack_start(page2BottomBarShowPanelContainer, False,
                                  False, 0)
        showOnPanelLabel = Gtk.Label("Show on panel", xalign=0)
        page2BottomBarShowPanelContainer.pack_start(showOnPanelLabel, True,
                                                    True, 0)
        showOnPanelLabel.get_style_context().add_class("dim-label")
        self.showOnPanelSpinButton = Gtk.SpinButton()
        self.showOnPanelSpinButton.set_adjustment(
            Gtk.Adjustment(0, 0, 900, 1, 10, 0))
        self.showOnPanelSpinButton.set_value(self.showOnPanel)
        page2BottomBarShowPanelContainer.pack_start(self.showOnPanelSpinButton,
                                                    False, False, 0)
        func = self.showOnPanelSpinButtonOnValueChange
        self.showOnPanelSpinButton.connect("value-changed",
                                           func)
        # page2BottomBar icon size Container
        page2BottomBarIconSizeContainer = Gtk.HBox()
        page2BottomBar.pack_start(page2BottomBarIconSizeContainer, False,
                                  False,
                                  0)
        iconSizeLabel = Gtk.Label("Icon size", xalign=0)
        page2BottomBarIconSizeContainer.pack_start(iconSizeLabel, True, True,
                                                   0)
        iconSizeLabel.get_style_context().add_class("dim-label")
        iconSizeSpinButton = Gtk.SpinButton()
        iconSizeSpinButton.set_adjustment(Gtk.Adjustment(0, 16, 512, 1, 10, 0))
        iconSizeSpinButton.set_value(self.iconSize)
        page2BottomBarIconSizeContainer.pack_start(
            iconSizeSpinButton, False, False, 0,
        )
        iconSizeSpinButton.connect(
            "value-changed", self.iconSizeSpinButtonOnValueChange,
        )

    def openStackPage1(self):
        self.stack.set_visible_child_name("page1")

    def openStackPage2(self):
        self.stack.set_visible_child_name("page2")

    def indicatorBoxOnPress(self, box, e):
        self.openStackPage1()
        if e.button != 1:
            return Gdk.EVENT_PROPAGATE
        if self.popover.get_visible():
            self.popover.hide()
        else:
            self.update()
            self.manager.show_popover(self.indicatorBox)
        return Gdk.EVENT_STOP

    def editButtonOnClick(self, editButton):
        self.currentMenuButton = None
        self.updateSensitiveUpDownButtons()
        self.doneButton.set_sensitive(False)
        self.update()
        self.openStackPage2()

    def upButtonOnClick(self, button):
        if self.currentMenuButton in self.menuButtons:
            newIndex = self.menuButtons.index(self.currentMenuButton) - 1

            if newIndex >= 0:
                self.menuButtonsContainer.reorder_child(self.currentMenuButton,
                                                        newIndex)
                self.menuButtons.remove(self.currentMenuButton)
                self.menuButtons.insert(newIndex, self.currentMenuButton)
                self.activeApps.remove(self.currentMenuButton.getApp())
                self.activeApps.insert(newIndex,
                                       self.currentMenuButton.getApp())
                self.allApps.remove(self.currentMenuButton.getApp())
                self.allApps.insert(newIndex, self.currentMenuButton.getApp())
                self.updateAllAppsIndexes()
            self.updateSensitiveUpDownButtons()

    def downButtonOnClick(self, button):
        if self.currentMenuButton in self.menuButtons:
            newIndex = self.menuButtons.index(self.currentMenuButton) + 1
            self.menuButtonsContainer.reorder_child(self.currentMenuButton,
                                                    newIndex)
            self.menuButtons.remove(self.currentMenuButton)
            self.menuButtons.insert(newIndex, self.currentMenuButton)
            self.activeApps.remove(self.currentMenuButton.getApp())
            self.activeApps.insert(newIndex, self.currentMenuButton.getApp())
            self.allApps.remove(self.currentMenuButton.getApp())
            self.allApps.insert(newIndex, self.currentMenuButton.getApp())
            self.updateAllAppsIndexes()
            self.updateSensitiveUpDownButtons()

    def backButtonOnClick(self, button):
        self.update()
        self.openStackPage1()

    def doneButtonOnClick(self, button):
        self.localHelper.saveApps(self.activeApps)
        self.loadAppButtons()
        self.loadPanelButtons()
        self.loadMenuButtons()
        self.allAppsContentScroll.get_vadjustment().set_value(0)
        self.doneButton.set_sensitive(False)
        self.showOnPanelSpinButton.get_adjustment().set_upper(
            len(self.activeApps))
        self.showOnPanelSpinButton.get_adjustment().set_value(self.showOnPanel)

    def selectButtonOnClick(self, selectButton):
        self.selectAll()

    def deselectButtonOnClick(self, deselectButton):
        self.deselectAll()

    def menuButtonOnToggle(self, toggleButton, *data):
        self.doneButton.set_sensitive(True)
        menuButton = data[0]
        # if current menu button toggled again set current None
        if self.currentMenuButton is not None and \
                self.currentMenuButton is menuButton:
            self.currentMenuButton = None
            self.updateSensitiveUpDownButtons()
            return
        # toggle false  old current button
        if self.currentMenuButton is not None and \
                self.currentMenuButton is not menuButton:
            self.currentMenuButton.setToggled(False)
        # set new currentMenuButton
        self.currentMenuButton = menuButton
        self.updateSensitiveUpDownButtons()

    def menuButtonOnCheck(self, checkButton, *data):
        self.doneButton.set_sensitive(True)
        menuButton = data[0]
        app = menuButton.getApp()
        if not app.getActive():
            app.setActive(True)
            if app in self.inactiveApps:
                self.inactiveApps.remove(app)
                self.activeApps.append(app)
        else:
            app.setActive(False)
            if app in self.activeApps:
                self.activeApps.remove(app)
                self.inactiveApps.insert(0, app)
        self.inactiveApps = self.sortHelper.sortedAppsByName(self.inactiveApps)
        self.allApps = self.activeApps + self.inactiveApps
        self.updateAllAppsIndexes()
        self.updateSensitiveSelectButtons()

    def showOnPanelSpinButtonOnValueChange(self, spinButton):
        # print("value changed : %s" % int(spinButton.get_value()))
        self.showOnPanel = int(spinButton.get_value())
        self.localHelper.saveShowOnPanel(self.showOnPanel)
        self.update()
        self.panelButtonsContainer.set_size_request(0, 0)
        spinButton.get_adjustment().set_upper(len(self.activeApps))

    def iconSizeSpinButtonOnValueChange(self, spinButton):
        # print("value changed : %s" % int(spinButton.get_value()))
        self.iconSize = int(spinButton.get_value())
        self.localHelper.saveIconSize(self.iconSize)
        self.update()

    def searchEntryOnChange(self, searchEntry):

        text = searchEntry.get_text().strip()

        self.filteredActiveApps = self.filterHelper.filteredAppsByName(
            self.activeApps, self.showOnPanel, text)

        if text is "":
            self.loadAppButtons()
        else:
            self.loadFilteredActiveAppButtons()

    def treeOnChange(self, tree):
        # self.log.d(self.TAG, "treeOnChange")
        self.tree = None
        self.update()
        self.localHelper.saveApps(self.activeApps)

    def searchEntryOnActivate(self, searchEntry):
        if len(self.filteredActiveApps) != 0:
            info = self.filteredActiveApps[0].getInfo()
            if info is not None:
                self.hidePopover()
                info.launch(None, None)

    def update(self):
        # self.popover.resize(self.popoverWidth, self.popoverHeight)
        self.searchEntry.set_text("")
        self.loadAllApps()
        self.loadAppButtons()
        self.loadMenuButtons()
        self.loadPanelButtons()
        self.updateSensitiveSelectButtons()
        self.popover.set_size_request(self.popoverWidth, self.popoverHeight)
        self.popover.get_child().show_all()
        self.show_all()

    def do_update_popovers(self, manager):
        self.manager = manager
        self.manager.register_popover(self.indicatorBox, self.popover)

    def updateSensitiveUpDownButtons(self):
        if self.currentMenuButton is not None:
            currentMenuButtonIndex = self.menuButtons.index(
                self.currentMenuButton)
            activeAppsLenght = len(self.activeApps)
            if currentMenuButtonIndex is 0:
                self.upButton.set_sensitive(False)
                self.downButton.set_sensitive(True)
            elif currentMenuButtonIndex is activeAppsLenght - 1:
                self.upButton.set_sensitive(True)
                self.downButton.set_sensitive(False)
            else:
                self.upButton.set_sensitive(True)
                self.downButton.set_sensitive(True)
        else:
            self.upButton.set_sensitive(False)
            self.downButton.set_sensitive(False)

    def updateSensitiveSelectButtons(self):
        if len(self.activeApps) is 0:
            self.selectButton.set_sensitive(True)
            self.deselectButton.set_sensitive(False)
        elif len(self.activeApps) > 0:
            self.selectButton.set_sensitive(True)
            self.deselectButton.set_sensitive(True)
        else:
            self.selectButton.set_sensitive(False)
            self.deselectButton.set_sensitive(True)

    def updateAllAppsIndexes(self):
        tempApps = []
        for app in self.allApps:
            app.setIndex(self.allApps.index(app))
            tempApps.append(app)
        self.allApps = tempApps

    def hidePopover(self):
        if (self.popover is not None):
            if self.popover.get_visible():
                self.popover.hide()

    def loadAllApps(self):
        # self.log.d(self.TAG, "loadAllApps")
        self.iconSize = self.localHelper.retriveIconSize()
        self.showOnPanel = self.localHelper.retriveShowOnPanel()
        # reset all apps lists
        self.allApps = []
        self.activeApps = []
        self.inactiveApps = []
        # load our active apps data from local
        self.activeAppsDict = self.localHelper.retriveAppsDict()
        # load all apps from system all applications
        appsDict = {}
        self.loadAndExtractApps(appsDict)
        # sort and combine active and inactiveApps to build allApps
        self.activeApps = self.sortHelper.sortedAppsByIndex(self.activeApps)
        self.inactiveApps = self.sortHelper.sortedAppsByName(self.inactiveApps)
        self.allApps = self.activeApps + self.inactiveApps

    def loadAndExtractApps(self, appsDict, treeRoot=None):
        # self.log.d(self.TAG, "loadAndExtractApps")
        if self.tree is None:
            # self.log.d(self.TAG, "loadAndExtractApps self.tree is None")
            self.tree = GMenu.Tree.new(self.APPS_ID,
                                       GMenu.TreeFlags.SORT_DISPLAY_NAME)
            self.tree.connect("changed", self.treeOnChange)
            try:
                self.tree.load_sync()
            except Exception as e:
                self.log.e(self.TAG, Error.ERROR_8011, e)
        if treeRoot is None:
            root = self.tree.get_root_directory()
        else:
            root = treeRoot
        it = None
        if root is not None:
            it = root.iter()
        if it is not None:
            while True:
                treeItemType = it.next()
                if treeItemType is GMenu.TreeItemType.INVALID:
                    break
                if treeItemType is GMenu.TreeItemType.DIRECTORY:
                    dir = it.get_directory()
                    # self.log.d(self.TAG, "loadAppList dir %s : " % dir)
                    self.loadAndExtractApps(appsDict, dir)
                elif treeItemType is GMenu.TreeItemType.ENTRY:
                    info = it.get_entry().get_app_info()
                    # self.log.d(self.TAG, info.get_display_name())
                    id = info.get_id()
                    if id not in appsDict:
                        appsDict[id] = info
                        if id in self.activeAppsDict:
                            app = self.activeAppsDict[id]
                            app.setId(id)
                            app.setInfo(info)
                            self.activeApps.insert(app.getIndex(), app)
                        else:
                            app = App(id, info.get_display_name(), False)
                            app.setInfo(info)
                            self.inactiveApps.append(app)

    def loadFilteredActiveAppButtons(self):
        if self.appButtonsContainer is not None:  # empty allAppsContent
            for appButton in self.appButtonsContainer.get_children():
                appButton.destroy()
        for app in self.filteredActiveApps:
            row = Gtk.HBox()
            self.appButtonsContainer.add(row)
            appButton = AppButton(app, 24, self.popover)
            row.pack_start(appButton, True, True, 0)
            appButton.show_all()
            row.show_all()
        self.appButtonsContainer.show_all()

    def loadAppButtons(self):
        if self.appButtonsContainer is not None:  # empty allAppsContent
            for appButton in self.appButtonsContainer.get_children():
                appButton.destroy()
        counter = 0
        for app in self.allApps:
            if counter >= self.showOnPanel and app.getActive():
                row = Gtk.HBox()
                self.appButtonsContainer.add(row)
                appButton = AppButton(app, 24, self.popover)
                row.pack_start(appButton, True, True, 0)
                appButton.show_all()
                row.show_all()
            counter += 1
        self.appButtonsContainer.show_all()

    def loadPanelButtons(self):
        if self.panelButtonsContainer is not None:  # empty allAppsContent
            for panelButton in self.panelButtonsContainer.get_children():
                panelButton.destroy()
        # add the applet's button as first item
        appletbutton = Gtk.Button()
        applet_icon = Gtk.Image.new_from_icon_name(
            "budgie-app-launcher-applet-symbolic", Gtk.IconSize.MENU
        )
        appletbutton.set_image(applet_icon)
        appletbutton.set_relief(Gtk.ReliefStyle.NONE)
        self.panelButtonsContainer.add(appletbutton)
        appletbutton.connect(
            "button-press-event", self.indicatorBoxOnPress
        )
        counter = 0
        for app in self.allApps:
            if counter < self.showOnPanel and app.getActive():
                panelButton = PanelButton(app, self.iconSize, self.popover)
                self.panelButtonsContainer.add(panelButton)
            counter += 1
        self.panelButtonsContainer.show_all()

    def loadMenuButtons(self):
        self.menuButtons = []
        if self.menuButtonsContainer is not None:
            for menuButton in self.menuButtonsContainer.get_children():
                menuButton.destroy()
        for app in self.allApps:
            menuButton = MenuButton(app, 24)
            menuButton.setChecked(app.getActive())
            menuButton.setToggButtonSensitive(app.getActive())
            menuButton.addOnToggleMethod(self.menuButtonOnToggle)
            menuButton.addOnCheckMethod(self.menuButtonOnCheck)
            menuButton.show_all()
            self.menuButtons.append(menuButton)
            self.menuButtonsContainer.add(menuButton)
        self.menuButtonsContainer.show_all()

    def setMargins(self, widget, top, bottom, left, right):
        widget.set_margin_top(top)
        widget.set_margin_bottom(bottom)
        widget.set_margin_left(left)
        widget.set_margin_right(right)

    def selectAll(self):
        self.doneButton.set_sensitive(True)
        for menuButton in self.menuButtons:
            if not menuButton.getChecked():
                menuButton.setChecked(True)

    def deselectAll(self):
        self.doneButton.set_sensitive(True)
        for menuButton in self.menuButtons:
            if menuButton.getChecked():
                menuButton.setChecked(False)
