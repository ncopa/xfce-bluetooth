
desktopdir = $(datadir)/applications
desktop_in_files = xfce4-bluetooth.desktop.in xfce4-bluetooth-agent.desktop.in
desktop_DATA = $(desktop_in_files:.desktop.in=.desktop)

%.desktop: %.desktop.in
	 $(SED) -e 's,@@xfce4bluetooth_execdir@@,$(libexecdir),' $< > $@

EXTRA_DIST = $(desktop_in_files)

CLEANFILES = $(desktop_DATA)
