Budgie Screencast
----

Applet wrapper around gpu-screen-recorder or wf-recorder.
If gpu-screen-recorder is installed it is used automatically, otherwise wf-recorder is used.
The first time gpu-screen-recorder is used, a one-time authentication prompt grants its
gsr-kms-server helper the CAP_SYS_ADMIN capability (setcap) so recording needs no further prompts.
If that is declined, wf-recorder is used when available.

Allows recording of whole screen displays or areas.

Optionally record audio

Can delay recording and can optionally record specific content lengths matching TikTok, youtube and instagram shorts

----

Requires
gpu-screen-recorder or wf-recorder
slurp
libcap2-bin (getcap/setcap) and pkexec, only for the one-time gpu-screen-recorder setup
pactl (pulseaudio-utils)
