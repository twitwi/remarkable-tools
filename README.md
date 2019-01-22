# remarkable-tools
Custom tools for the remarkable tablet.

The following tools are proposed:
- a way to have a liveview of a page without using the cloud, by directly connecting to the tablet via SSH,
- a way to get an annotated pdf from the remarkable cloud (might get deprecated by "rmapi").

# Live view

Need to install python3 and:
~~~
pip install asyncio
pip install websockets
~~~

Then:
~~~
cd liveview
./liveview.sh
~~~

It will:
- connect to the "remarkable" host via SSH using keys (you have to set them up)
- and, locally start a firefox to view the live document

You once need to configure your `~/.ssh/config`:
~~~
Host remarkable
User root
HostName 10.11.99.1
# ^ this is via USB
# or e.g., for a home wifi: HostName 192.168.1.14
~~~


# Attribution
These tools are partly built from the rm2svg tool:
- created here https://github.com/reHackable/maxio/
- forked here https://github.com/lschwetlick/maxio/tree/master/tools
- and made compatible with version 1.6 of the tablet here https://github.com/reHackable/maxio/issues/27

The pdf export script is inspired by https://github.com/jmptable/rm-dl-annotated
and uses https://github.com/juruen/rmapi (which needs to be installed and might even deprecate the current pdf export).

