# Budgie Fuzzy Clock applet
Shows the time in a Fuzzy Way.

* Supports 24-hour format
* Supports Dates
* Supports Horizontal Panels

![Operational](./menu.png)

![Settings](./settings.png)

Logic
-------
The current minute is chopped into 1 of 12 rules using this equation: **Math.floor((minute + 2) / 5)**.  Each rule corresponds to a different format text applied to the hour

for example)

| Pulse minute | Rule | Fuzzed formatter       |
| ----------   | ---- | ---------------------- |
| 00           | 0    | '%s-ish'               |
| 03           | 1    | 'a bit past %s'        |
| 33           | 6    | 'half-past %s'         |
| 57           | 11   | 'almost %s'            |

Finally the hour's text is formatted into the rule-string.  The app supports 12-hour or 24-hour formatting.

Update Freq
----------------
Currently, the app gets updated once a second at a low priority.

Worst Case w/ 5 min pulse lags nearly 5 minutes behind:

| Pulse Time | Last Second in Rule | Rule | Fuzzed                 |
| ---------- | ------------------- | ---- | ---------------------- |
| 12:12:59   | 12:17:58            |  2   | ten past noon          |
| 12:17:59   | 12:22:58            |  3   | quarter after noon     |
| 12:22:59   | 12:27:58            |  4   | twenty past noon       |

Worst case w/ 2.5 min pulse still lags a bit  

| Pulse Time | Last Second in Rule | Rule | Fuzzed                 |
| ---------- | ------------------- | ---- | ---------------------- |
| 12:12:59   | 12:15:28            | 2    | ten past noon          |
| 12:15:29   | 12:17:58            | 3    | quarter after noon     |
| 12:17:59   | 12:20:28            | 3    | quarter after noon     |
| 12:20:29   | 12:22:58            | 4    | twenty past noon       |
| 12:22:59   | 12:25:28            | 4    | twenty past noon       |

Worst case w/ 30 sec pulse isn't noticeable  

| Pulse Time | Last Second in Rule | Rule | Fuzzed                 |
| ---------- | ------------------- | ---- | ---------------------- |
| 12:12:59   | 12:13:28            | 2    | ten past noon          |
| 12:13:29   | 12:13:58            | 3    | quarter after noon     |
| 12:13:59   | 12:14:28            | 3    | quarter after noon     |
| 12:14:29   | 12:14:58            | 3    | quarter after noon     |
| 12:14:59   | 12:15:28            | 3    | quarter after noon     |
| 12:15:29   | 12:15:58            | 3    | quarter after noon     |
| 12:15:59   | 12:16:28            | 3    | quarter after noon     |
| 12:16:29   | 12:16:58            | 3    | quarter after noon     |
| 12:16:59   | 12:17:28            | 3    | quarter after noon     |
| 12:17:29   | 12:17:58            | 3    | quarter after noon     |
| 12:17:59   | 12:18:28            | 3    | quarter after noon     |
| 12:18:29   | 12:18:58            | 4    | twenty past noon       |
