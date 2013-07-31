using Gtk;

public class XfceBluetoothApp : GLib.Object {
    public Window window;
    public CheckButton discoverable_checkbutton;
    public CheckButton powered_checkbutton;
    public SpinButton discoverable_timeout_spinbutton;

    private Entry name_entry;

    DBusObjectManager manager;
    BluezAdapter adapter;
    HashTable<ObjectPath, HashTable<string, HashTable<string, Variant>>> objects;

    ListStore device_store;

    private void find_adapter() {
        objects.foreach((path, ifaces) => {
            HashTable<string, Variant>? props;
            props = ifaces.get("org.bluez.Adapter1");
            if (props == null)
                return; /* continue */
            adapter = new BluezAdapter(path, props);
        });
    }

    private void find_devices() {
        objects.foreach((path, ifaces) => {
            HashTable<string, Variant>? props;
            props = ifaces.get("org.bluez.Device1");
            if (props != null) {
                TreeIter iter;
                device_store.append(out iter);
                device_store.set(iter,
                                 0, props.get("Alias").get_string(),
                                 1, props.get("Connected").get_boolean());
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

            TreeView device_treeview = builder.get_object("device_treeview") as TreeView;
            device_treeview.insert_column_with_attributes (-1, "Device", new CellRendererText (), "text", 0);
            var toggle = new CellRendererToggle();
            toggle.sensitive = false;
            device_treeview.insert_column_with_attributes (-1, "Connected", toggle, "active", 1);

            device_store = builder.get_object("device_store") as ListStore;

            find_devices();

        } catch (Error e) {
            stderr.printf("%s\n", e.message);
            return;
        }
        builder.connect_signals(this);
        adapter.notify["powered"].connect((s, p) => {
            stdout.printf("adapter.notify[powered]\n");
            powered_checkbutton.set_active(adapter.powered);
            discoverable_checkbutton.sensitive = adapter.powered
                && !adapter.discoverable;
        });
        adapter.notify["discoverable"].connect((s, p) => {
            stdout.printf("adapter.notify[discoverable]\n");
            discoverable_checkbutton.set_active(adapter.discoverable);
            discoverable_checkbutton.sensitive = !adapter.discoverable;
        });
        adapter.notify["discoverable_timeout"].connect((s, p) => {
            stdout.printf("adapter.notify[discoverable_timeout]\n");
            discoverable_timeout_spinbutton.adjustment.value = adapter.discoverable_timeout;
        });
    }

    [CCode (instance_pos = -1)]
    public void on_close(Button source) {
        Gtk.main_quit();
    }

    [CCode (instance_pos = -1)]
    public void on_discoverable(ToggleButton button) {
        adapter.discoverable = button.get_active();
    }

    [CCode (instance_pos = -1)]
    public void on_powered(ToggleButton button) {
        adapter.powered = button.get_active();
    }

    [CCode (instance_pos = -1)]
    public void on_remove(Button button) {
        stdout.printf("Button remove\n");
    }

    [CCode (instance_pos = -1)]
    public void on_device_cursor_changed(TreeView view, TreePath path, TreeViewColumn column){
        stdout.printf("device cursor changed\n");
    }
}

int main (string[] args) {
    Gtk.init(ref args);
    var app = new XfceBluetoothApp();
    app.window.show_all();
    Gtk.main();
    return 0;
}
