using Gtk;

public class XfceBluetoothApp : GLib.Object {
    public Window window;
    public CheckButton discoverable_checkbutton;
    public CheckButton powered_checkbutton;
    public SpinButton discoverable_timeout_spinbutton;

    string? selected_device = null;
    Button device_remove_button;
    TreeView device_treeview;

    DBusObjectManager manager;
    BluezAdapterProperties adapter;
    HashTable<ObjectPath, HashTable<string, HashTable<string, Variant>>> objects;

    ListStore device_store;

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
        ALIAS,
        CONNECTED,
        PAIRED,
        TRUSTED,
        BLOCKED,
        N_COLUMNS
    }

    private void find_devices() {
        device_store = new ListStore(DevCols.N_COLUMNS,
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
                TreeIter iter;
                device_store.append(out iter);
                device_store.set(iter,
                                 DevCols.OBJPATH, path,
                                 DevCols.ALIAS, props.get("Alias").get_string(),
                                 DevCols.CONNECTED, props.get("Connected").get_boolean(),
                                 DevCols.PAIRED, props.get("Paired").get_boolean(),
                                 DevCols.TRUSTED, props.get("Trusted").get_boolean(),
                                 DevCols.BLOCKED, props.get("Blocked").get_boolean());
            }
        });
    }

    public XfceBluetoothApp() {
        try {
            manager = Bus.get_proxy_sync (BusType.SYSTEM, "org.bluez", "/");
            objects = manager.get_managed_objects();
            find_adapter();

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

    private void treeview_add_toggle_col(TreeView v, string title, DevCols col) {
            var toggle = new CellRendererToggle();
            toggle.sensitive = false;
            v.insert_column_with_attributes (-1, title, toggle, "active", col);
    }

    private void build_ui() {
        Builder builder = new Builder();
        try {
            builder.add_from_file("bluetooth.ui");

            window = builder.get_object("window") as Window;
            window.destroy.connect(Gtk.main_quit);

            powered_checkbutton = builder.get_object("powered_checkbutton") as CheckButton;
            powered_checkbutton.set_active(adapter.powered);

            discoverable_checkbutton = builder.get_object("discoverable_checkbutton") as CheckButton;
            discoverable_checkbutton.set_active(adapter.discoverable);
            discoverable_checkbutton.sensitive = adapter.powered
                && !adapter.discoverable;

            discoverable_timeout_spinbutton = builder.get_object("discoverable_timeout_spinbutton") as SpinButton;
            discoverable_timeout_spinbutton.set_value(adapter.discoverable_timeout);
            discoverable_timeout_spinbutton.adjustment.value_changed.connect((a) => {
                adapter.discoverable_timeout = (uint32) a.value;
            });
            device_remove_button = builder.get_object("btn_remove") as Button;

            find_devices();

            device_treeview = builder.get_object("device_treeview") as TreeView;
            device_treeview.set_model(device_store);

            var text = new CellRendererText();
            var col = new TreeViewColumn();
            col.set_title("Device");
            col.pack_start(text, true);
            col.add_attribute(text, "text", DevCols.ALIAS);
            device_treeview.append_column(col);

            treeview_add_toggle_col(device_treeview, "Connected", DevCols.CONNECTED);
            treeview_add_toggle_col(device_treeview, "Paired", DevCols.PAIRED);
            treeview_add_toggle_col(device_treeview, "Trusted", DevCols.TRUSTED);
            treeview_add_toggle_col(device_treeview, "Blocked", DevCols.BLOCKED);

            device_treeview.get_selection().changed.connect(on_device_selection_changed);

        } catch (Error e) {
            stderr.printf("%s\n", e.message);
            return;
        }
        builder.connect_signals(this);
        adapter.powered_changed.connect((a) => {
            powered_checkbutton.set_active(a.powered);
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
    public void on_powered(ToggleButton button) {
        adapter.powered = button.get_active();
        set_widgets_sensibility();
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
            device_store.remove(iter);
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
            device_remove_button.sensitive = true;
        } else {
            selected_device = null;
            device_remove_button.sensitive = false;
        }
    }
}

int main (string[] args) {
    Gtk.init(ref args);
    var app = new XfceBluetoothApp();
    app.window.show_all();
    Gtk.main();
    return 0;
}
