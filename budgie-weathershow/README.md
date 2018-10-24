# WeatherShowII
WeatherShowII is a completely rewritten version of the existing python WeatherShow applet. It merges the functionality of Budgie Weather applet (showing weather in the panel) and WeatherShow. Each of the modules: weather forecast, weather in the panel and weather on the desktop can be switched on and of.

The applet includes many technical improvements under the hood. Weather forecast now has its own thread, therefore the panel should not suffer in any way from possible possible delays or issues in fetching the forecast (e.g. in case of network- related problems). Furthermore, the applet adapts (in three steps) to the monitor's size, for better scaling on high resolutions.

# Install
1. Remove possible previous versions of WeatherShow(!)
2. Run from a terminal: `git clone https://github.com/UbuntuBudgie/experimental.git`
3. From the applet's root folder (NewWeatherShow):

- `mkdir build && cd build`
- `meson --buildtype plain --prefix=/usr --libdir=/usr/lib`
- `ninja`
- `sudo ninja install`

