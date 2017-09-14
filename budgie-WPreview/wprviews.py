import gi.repository
gi.require_version('Budgie', '1.0')
from gi.repository import Budgie, GObject, Gtk, Gdk
import subprocess
    

class WPrviews(GObject.GObject, Budgie.Plugin):
    """ This is simply an entry point into your Budgie Applet implementation.
        Note you must always override Object, and implement Plugin.
    """

    # Good manners, make sure we have unique name in GObject type system
    __gtype_name__ = "WPrviews"

    def __init__(self):
        """ Initialisation is important.
        """
        GObject.Object.__init__(self)
        
    def do_get_panel_widget(self, uuid):
        """ This is where the real fun happens. Return a new Budgie.Applet
            instance with the given UUID. The UUID is determined by the
            BudgiePanelManager, and is used for lifetime tracking.
        """
        return WPrviewsApplet(uuid)
    

class WPrviewsApplet(Budgie.Applet):
    """ Budgie.Applet is in fact a Gtk.Bin """
    manager = None

    def __init__(self, uuid):
        Budgie.Applet.__init__(self)
        self.box = Gtk.EventBox()
        icon = Gtk.Image.new_from_icon_name("wprviews-panel", Gtk.IconSize.MENU)
        self.box.add(icon)        
        self.add(self.box)
        self.popover = Budgie.Popover.new(self.box)
        self.hello = Gtk.Label("Window Previews is active")
        self.popover.add(self.hello)        
        self.popover.get_child().show_all()
        self.box.show_all()
        self.show_all()
        self.box.connect("button-press-event", self.on_press)
        subprocess.Popen("/opt/budgie-extras/wprviews/code/wprviews_panelrunner")

    def	on_press(self, box, arg):
        self.manager.show_popover(self.box)

    def do_update_popovers(self, manager):
    	self.manager = manager
    	self.manager.register_popover(self.box, self.popover)

