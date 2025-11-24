# QuickChar

Quickly find and choose the equivalent locale character for an ascii character

Setup:

- Place all files in one and the same directory
- Run `quickchar`, inside the folder
- Press (at this moment) Super+Alt+C to call the window (Need budgie-extras budgie-extras-daemon)
- Type a character, and all its derivates will appear. Click one (or tab to the targeted character and press Return) and the character will be pasted into the document
- Press again to toggle visibility, or Escape to hide


  ![screenshot](https://github.com/UbuntuBudgie/QuickChar/blob/master/screenshot.png)


- The character data is from: http://www.conlang.info/cgi/dia.cgi

QuickChar depends on:

 - Gtk, Wnck, Gdk, Gio, wmctrl

 - xlib (to run pyautogui)

   `sudo apt install python3-xlib`
