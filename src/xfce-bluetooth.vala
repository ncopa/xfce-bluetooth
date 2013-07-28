using Gtk;

[DBus (name = "org.freedesktop.DBus.ObjectManager")]
interface DBusObjectManager : GLib.Object {
    [DBus (name = "GetManagedObjects")]
    public abstract GLib.HashTable<GLib.ObjectPath, GLib.HashTable<string, GLib.HashTable<string, GLib.Variant>>> get_managed_objects() throws DBusError, IOError;
}

[DBus (name = "org.freedesktop.DBus.Properties")]
interface DBusProperties : GLib.Object {
    [DBus (name = "Set")]
    public abstract void set(string iface, string name, GLib.Variant val) throws DBusError, IOError;
    [DBus (name = "Get")]
    public abstract GLib.Variant get(string iface, string name) throws DBusError, IOError;
    public signal void properties_changed(string iface, GLib.HashTable <string, GLib.Variant> changed, string[] invalidated);
}

public class BluezAdapter {
    DBusProperties bus;
    public GLib.ObjectPath object_path = null;
    public GLib.HashTable<string, GLib.Variant> props = null;
    private XfceBluetoothApp app = null;

    public BluezAdapter(GLib.ObjectPath path,
                        ref GLib.HashTable<string, GLib.Variant> initprops,
                        XfceBluetoothApp initapp) {
        object_path = path;
        props = initprops;
        app = initapp;
        bus = Bus.get_proxy_sync (BusType.SYSTEM, "org.bluez",
                                          path);
        bus.properties_changed.connect(on_properties_changed);
    }

    public GLib.Variant get_property(string property) throws IOError {
        return bus.get("org.bluez.Adapter1", property);
    }

    public void set_property(string property, GLib.Variant val) throws IOError {
        bus.set("org.bluez.Adapter1", property, val);
    }

    public void property_changed(string prop, GLib.Variant val) {
        stdout.printf("\t%s: %s\n", prop, val.print(false));
        switch (prop) {
            case "Discoverable":
                app.discoverable_checkbutton.set_active(val.get_boolean());
                break;
            case "Powered":
                app.powered_checkbutton.set_active(val.get_boolean());
                break;
        }
    }

    public void on_properties_changed(string iface, GLib.HashTable <string, GLib.Variant> changed, string[] invalidated) {
        stdout.printf("properties changed: [ %s ]\n", iface);
        changed.foreach((key, val) => {
            property_changed(key, val);
        });
    }
}

public class XfceBluetoothApp {
    public Window window;
    public CheckButton discoverable_checkbutton;
    public CheckButton powered_checkbutton;

    private Entry name_entry;

    DBusObjectManager manager;
    BluezAdapter adapter;
    GLib.HashTable<GLib.ObjectPath, GLib.HashTable<string, GLib.HashTable<string, GLib.Variant>>> objects;

    ListStore device_store;

    private void find_adapter() {
        objects.foreach((path, ifaces) => {
            GLib.HashTable<string, GLib.Variant>? props;
            props = ifaces.get("org.bluez.Adapter1");
            if (props == null)
                return; /* continue */
            adapter = new BluezAdapter(path, ref props, this);
        });
    }

    private void find_devices() {
        objects.foreach((path, ifaces) => {
            GLib.HashTable<string, GLib.Variant>? props;
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

            stdout.printf("Find adapter: %s\n", adapter.object_path);
            objects.foreach((path ,interfaces)=> {
                stdout.printf("[ %s ]\n", path);
                interfaces.foreach((iface, props) => {
                    if (iface.has_prefix("org.freedesktop.DBus"))
                        return;
                    stdout.printf("\t%s\n", iface);
                    props.foreach((key, val) => {
                        stdout.printf("\t\t%s: %s\n", key, val.print(false));
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
            powered_checkbutton.set_active(adapter.props.get("Powered").get_boolean());

            discoverable_checkbutton = builder.get_object("discoverable_checkbutton") as CheckButton;
            discoverable_checkbutton.set_active(adapter.props.get("Discoverable").get_boolean());
            discoverable_checkbutton.sensitive = powered_checkbutton.get_active();

            name_entry = builder.get_object("name_entry") as Entry;
            name_entry.set_text(adapter.props.get("Alias").get_string());

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
    }

    [CCode (instance_pos = -1)]
    public void on_close(Button source) {
        Gtk.main_quit();
    }

    private void set_checkbutton_from_adapter_property(ToggleButton button, string property) {
        try {
            button.set_active(adapter.get_property(property).get_boolean());
        } catch (Error e) {
            stderr.printf("%s\n", e.message);
        }
    }

    private void set_adapter_property_from_checkbutton(string property, ToggleButton button) {
        try {
            adapter.set_property(property, button.get_active());
        } catch (Error e) {
            stderr.printf("%s\n", e.message);
            /* reset checkbutton if failed */
            set_checkbutton_from_adapter_property(button, property);
        }
    }

    [CCode (instance_pos = -1)]
    public void on_discoverable(ToggleButton button) {
        set_adapter_property_from_checkbutton("Discoverable", button);
    }

    [CCode (instance_pos = -1)]
    public void on_powered(ToggleButton button) {
        set_adapter_property_from_checkbutton("Powered", button);
        discoverable_checkbutton.sensitive = button.get_active();
        set_checkbutton_from_adapter_property(discoverable_checkbutton, "Discoverable");
    }
}

int main (string[] args) {
    Gtk.init(ref args);
    var app = new XfceBluetoothApp();
    app.window.show_all();
    Gtk.main();
    return 0;
}
