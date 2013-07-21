using Gtk;

[DBus (name = "org.bluez.Manager")]
interface BluezManager : GLib.Object {
    public abstract GLib.ObjectPath default_adapter() throws IOError;
}

[DBus (name = "org.bluez.Adapter")]
interface BluezAdapter : GLib.Object {
    public abstract GLib.HashTable<string, GLib.Variant> get_properties() throws IOError;
    public abstract void set_property(string name, GLib.Variant val) throws IOError;
}

public class XfceBluetoothApp {
    public Window window;
    private CheckButton discoverable_checkbox;
    private Entry name_entry;

	BluezManager manager;
	BluezAdapter adapter;
	GLib.ObjectPath adapter_path;
    
    public XfceBluetoothApp() {
		try {
			manager = Bus.get_proxy_sync (BusType.SYSTEM, "org.bluez", "/");
			adapter_path = manager.default_adapter();
			stdout.printf("Default adapter = %s\n", adapter_path);
			adapter = Bus.get_proxy_sync (BusType.SYSTEM, "org.bluez", adapter_path);
		} catch (IOError e) {
			stderr.printf ("%s\n", e.message);
		}
		build_ui();
    }

	private void build_ui() {
		try {
			Builder builder = new Builder();
			builder.add_from_file("bluetooth.ui");
			window = builder.get_object("window") as Window;
			window.destroy.connect(Gtk.main_quit);
			discoverable_checkbox = builder.get_object("discoverable_checkbox") as CheckButton;
			name_entry = builder.get_object("name_entry") as Entry;
			builder.connect_signals(this);

			GLib.HashTable<string, GLib.Variant> properties;
			properties = adapter.get_properties();
			name_entry.set_text(properties.get("Name").get_string());
			discoverable_checkbox.set_active(properties.get("Discoverable").get_boolean());
		} catch (Error e) {
			stderr.printf("%s\n", e.message);
		}

	}

    [CCode (instance_pos = -1)]
    public void on_close(Button source) {
		Gtk.main_quit();
    }
    
    [CCode (instance_pos = -1)]
    public void on_discoverable(Button source) {
		bool discoverable = discoverable_checkbox.get_active();
		adapter.set_property("Discoverable", discoverable);
		stdout.printf("Setting discoverable to %s\n", discoverable ? "true" : "false");
    }
}

int main (string[] args) {
	Gtk.init(ref args);
	var app = new XfceBluetoothApp();
	app.window.show_all();
	Gtk.main();
    return 0;
}
