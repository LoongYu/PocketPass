app_path = defines["app"]
background_path = defines["background"]

files = [app_path]
symlinks = {"Applications": "/Applications"}

window_rect = ((120, 120), (720, 440))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False

background = background_path
icon_size = 112
text_size = 14
label_pos = "bottom"
icon_locations = {
    "口袋密码.app": (180, 225),
    "Applications": (540, 225),
}

format = "UDZO"
filesystem = "HFS+"
compression_level = 9
