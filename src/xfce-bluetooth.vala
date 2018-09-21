using Gtk;

public class XfceBluetoothApp : GLib.Object {
    public Window window;
    public CheckButton discoverable_checkbutton;
    public Switch powered_switch;
    public SpinButton discoverable_timeout_spinbutton;

    string? selected_device = null;
    ToolButton device_remove_button;
    ToolButton device_connect_button;
    ToolButton adapter_start_discovery_button;
    TreeView device_treeview;
    Label alias_label;

    DBusObjectManager manager;
    BluezAdapterProperties adapter;
    HashTable<ObjectPath, HashTable<string, HashTable<string, Variant>>> objects;

    Gtk.ListStore device_store;

    private void find_adapter() {
        objects.foreach((path, ifaces) => {
            HashTable<string, Variant>? props;
            props = ifaces.get("org.bluez.Adapter1");
            if (props == null)
                return; /* continue */
            adapter = new BluezAdapterProperties(path, props);
        });
    }

    private enum DevCols {
        OBJPATH,
        ICON,
        ALIAS,
        CONNECTED,
        PAIRED,
        TRUSTED,
        BLOCKED,
        N_COLUMNS
    }

    private void add_device(ObjectPath path, HashTable<string, Variant> props) {
        TreeIter iter;
        device_store.append(out iter);
        device_store.set(iter,
                         DevCols.OBJPATH, path,
                         DevCols.ICON, props.get("Icon").get_string(),
                         DevCols.ALIAS, props.get("Alias").get_string(),
                         DevCols.CONNECTED, props.get("Connected").get_boolean(),
                         DevCols.PAIRED, props.get("Paired").get_boolean(),
                         DevCols.TRUSTED, props.get("Trusted").get_boolean(),
                         DevCols.BLOCKED, props.get("Blocked").get_boolean());
    }

    private void find_devices() {
        device_store = new Gtk.ListStore(DevCols.N_COLUMNS,
                                     typeof(string),
                                     typeof(string),
                                     typeof(string),
                                     typeof(bool),
                                     typeof(bool),
                                     typeof(bool),
                                     typeof(bool));
        objects.foreach((path, ifaces) => {
            HashTable<string, Variant>? props;
            props = ifaces.get("org.bluez.Device1");
            if (props != null) {
	        add_device(path, props);
            }
        });
    }

    public XfceBluetoothApp() {
        try {
            manager = Bus.get_proxy_sync (BusType.SYSTEM, "org.bluez", "/");
            objects = manager.get_managed_objects();
            find_adapter();
            manager.interfaces_added.connect(on_interfaces_added);

            stdout.printf("Find adapter: %s (%s)\n", adapter.alias, adapter.address);
            objects.foreach((path ,interfaces)=> {
                stdout.printf("[ %s ]\n", path);
                interfaces.foreach((iface, props) => {
                    if (iface.has_prefix("org.freedesktop.DBus"))
                        return;
                    stdout.printf("\t%s\n", iface);
                    props.foreach((key, val) => {
                        stdout.printf("\t\t%s: %s\n", key,
                                      val.print(false));
                    });
                });
            });
        } catch (IOError e) {
            stderr.printf ("%s\n", e.message);
        }
        build_ui();
    }

    private BluezDevice device_from_tree_iter(TreeIter iter) {
		Value objpath = Value(typeof(string));
        device_store.get_value(iter, DevCols.OBJPATH, out objpath);
        return new BluezDevice(new ObjectPath(objpath.get_string()));
    }


    private void treeview_add_toggle_col(TreeView v, string title, DevCols col, bool sensitive) {
            var toggle = new CellRendererToggle();
            toggle.sensitive = sensitive;
            toggle.toggled.connect((toggle, treepathstr) => {
				bool newvalue = !toggle.active;
				TreePath treepath = new Gtk.TreePath.from_string (treepathstr);
				TreeIter iter;
				device_store.get_iter(out iter, treepath);

				BluezDevice device = device_from_tree_iter(iter);

                switch (col) {
					case DevCols.TRUSTED:
						device.trusted = newvalue;
						break;
					case DevCols.BLOCKED:
					    device.blocked = newvalue;
					    break;
			    }

				device_store.set(iter, col, newvalue);
				stderr.printf("tree path: %s\tobject path: %s\n", treepathstr, device.object_path);
			});
            v.insert_column_with_attributes (-1, title, toggle, "active", col);
    }

    private void build_ui() {
        Builder builder = new Builder();
        try {
            builder.add_from_file("bluetooth-devices.ui");

            window = builder.get_object("dialog") as Window;
            window.destroy.connect(Gtk.main_quit);

            powered_switch = builder.get_object("powered_switch") as Gtk.Switch;
            powered_switch.set_active(adapter.powered);

			alias_label = builder.get_object("friendly_name") as Gtk.Label;
			alias_label.set_label(adapter.alias);
            find_devices();

            device_treeview = builder.get_object("device_treeview") as TreeView;
            device_treeview.set_model(device_store);

			var iconcell = new CellRendererPixbuf();
			iconcell.set_property("stock-size", Gtk.IconSize.DIALOG);
            var col = new TreeViewColumn();
            col.pack_start(iconcell, true);
            col.add_attribute(iconcell, "icon-name", DevCols.ICON);
            col.set_sort_column_id(DevCols.ICON);
            device_treeview.append_column(col);

            var text = new CellRendererText();
            col = new TreeViewColumn();
            col.set_title("Device");
            col.pack_start(text, true);
            col.add_attribute(text, "text", DevCols.ALIAS);
            col.set_sort_column_id(DevCols.ALIAS);
            device_treeview.append_column(col);

            treeview_add_toggle_col(device_treeview, "Connected", DevCols.CONNECTED, false);
            treeview_add_toggle_col(device_treeview, "Paired", DevCols.PAIRED, false);
            treeview_add_toggle_col(device_treeview, "Trusted", DevCols.TRUSTED, true);
            treeview_add_toggle_col(device_treeview, "Blocked", DevCols.BLOCKED, true);

            device_treeview.get_selection().changed.connect(on_device_selection_changed);

        } catch (Error e) {
            stderr.printf("%s\n", e.message);
            return;
        }
        builder.connect_signals(this);
        adapter.alias_changed.connect((a) => {
			alias_label.set_label(a.alias);
		});
        adapter.discovering_changed.connect((a) => {
            adapter_start_discovery_button.sensitive = !a.discovering;
        });
        adapter.powered_changed.connect((a) => {
            powered_switch.set_active(a.powered);
            set_widgets_sensibility();
        });
        adapter.discoverable_changed.connect((a) => {
            discoverable_checkbutton.set_active(a.discoverable);
            set_widgets_sensibility();
        });
        adapter.discoverable_timeout_changed.connect((a) => {
            discoverable_timeout_spinbutton.adjustment.value = a.discoverable_timeout;
        });
    }

    void set_widgets_sensibility() {
        discoverable_checkbutton.sensitive = adapter.powered && !adapter.discoverable;
    }

    [CCode (instance_pos = -1)]
    public void on_close(Button source) {
        Gtk.main_quit();
    }

    [CCode (instance_pos = -1)]
    public void on_discoverable(ToggleButton button) {
        adapter.discoverable = button.get_active();
        set_widgets_sensibility();
    }

    [CCode (instance_pos = -1)]
    public void on_powered(Switch button) {
		stdout.printf("bluetooth state set to %s\n", button.get_active() ? "on":"off");
        adapter.powered = button.get_active();
        set_widgets_sensibility();
    }

    [CCode (instance_pos = -1)]
    public void on_start_discovery(Button button) {
        adapter.start_discovery();
    }

    [CCode (instance_pos = -1)]
    public void on_remove(Button button) {
        stdout.printf("Remove %s\n", selected_device);
        TreeSelection selection = device_treeview.get_selection();
        TreeModel model;
        TreeIter iter;
        if (selection.get_selected(out model, out iter)) {
            Value objpath = Value(typeof(string));
            model.get_value(iter, DevCols.OBJPATH, out objpath);
            adapter.remove_device(new ObjectPath(objpath.get_string()));
            device_store.remove(ref iter);
        }
    }

    [CCode (instance_pos = -1)]
    public void on_connect(Button button) {
        stdout.printf("connect %s\n", selected_device);
        TreeSelection selection = device_treeview.get_selection();
        TreeModel model;
        TreeIter iter;
        if (selection.get_selected(out model, out iter)) {
			BluezDevice device = device_from_tree_iter(iter);
            device.connect();
        }
    }

    [CCode (instance_pos = -1)]
    public void on_device_selection_changed(TreeSelection selection) {
        TreeModel model;
        TreeIter iter;
        if (selection.get_selected(out model, out iter)) {
            Value objpath = Value(typeof(string));
            model.get_value(iter, DevCols.OBJPATH, out objpath);
            selected_device = objpath.get_string();
            stdout.printf("Selected %s\n", selected_device);
            device_remove_button.sensitive = true;
            device_connect_button.sensitive = true;
        } else {
            selected_device = null;
            device_remove_button.sensitive = false;
            device_connect_button.sensitive = false;
        }
    }

    [CCode (instance_pos = -1)]
    public void on_interfaces_added(ObjectPath path,
				   HashTable<string, HashTable<string, Variant>> interfaces) {
        objects.insert(path, interfaces);

        HashTable<string, Variant>? props;
        props = interfaces.get("org.bluez.Device1");
        if (props != null)
            add_device(path, props);

        stdout.printf("interfaces added: %s\n", path);
        interfaces.foreach((key, val) => {
            stdout.printf("\t%s\n", key);
        });
    }

}

int main (string[] args) {
    Gtk.init(ref args);
    var app = new XfceBluetoothApp();
    app.window.show_all();
    Gtk.main();
    return 0;
}
