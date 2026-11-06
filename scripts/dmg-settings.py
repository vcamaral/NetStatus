# dmgbuild settings. Icon positions must match scripts/make-dmg-background.swift.
app = "build/NetStatus.app"

files = [app]
symlinks = {"Applications": "/Applications"}

format = "UDZO"
filesystem = "HFS+"
icon = "build/NetStatus.app/Contents/Resources/AppIcon.icns"
background = "build/dmg-background.tiff"

window_rect = ((200, 200), (600, 400))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False

icon_size = 112
text_size = 13
icon_locations = {
    "NetStatus.app": (150, 190),
    "Applications": (450, 190),
}
