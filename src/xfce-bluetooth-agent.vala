using Gtk;

public class BluetoothPinDialog : Xfce.TitledDialog {
    private Entry entry;
    private string label_text;
    
    public BluetoothPinDialog(string title, string subtitle, string label) {
        this.title = title;
        this.label_text = label;
        this.subtitle = subtitle;
        create_widgets();
    }
    public string get_pin() {
        return entry.get_text();
    }
    
    private void create_widgets() {
        entry = new Entry();
        Label label = new Label(this.label_text);
        VBox content = this.get_content_area() as VBox;
        HBox hbox = new HBox(false, 20);
        hbox.pack_start(label, false, true, 0);
        hbox.pack_start(entry, false, true, 0);
        content.pack_start(hbox, false, true, 0);
        
        add_button(Stock.CANCEL, ResponseType.CANCEL);
        add_button(Stock.OK, ResponseType.OK);
        show_all();
    }
}

[DBus(name = "org.bluez.Agent1")]
public class BluezAgent : GLib.Object {
    public void release() {
        stdout.printf("BluezAgent: release()\n");
    }
    public string request_pin_code(ObjectPath device) {
        stdout.printf("BluezAgent: request_pin_code(%s)\n", device);
        BluetoothPinDialog dlg = new BluetoothPinDialog("Device pairing", device, "Enter PIN:");
        dlg.show();
        string pin = "";
        dlg.response.connect((source, id) => {
            switch (id) {
            case ResponseType.OK:
                pin = dlg.get_pin();
                stdout.printf("got pin: %s\n", pin);
                break;
            case ResponseType.CANCEL:
                stdout.printf("cancelled\n");
                break;
            }
            source.destroy();
        });
        dlg.run();
        return pin;
    }
    public void display_pin_code(ObjectPath device, string pincode) {
        stdout.printf("BluezAgent: display_pin_code(%s, %s)\n", device, pincode);
        Gtk.MessageDialog dlg = new Gtk.MessageDialog(null, Gtk.DialogFlags.MODAL,
                                                      Gtk.MessageType.INFO,
                                                      Gtk.ButtonsType.OK, "Pincode for %s: %s", device, pincode);
        dlg.run();
    }
    public uint32 request_pass_key(ObjectPath device) {
        stdout.printf("BluezAgent: request_pass_key(%s)\n", device);
        return 0;
    }
    public void display_pass_key(ObjectPath device, uint32 passkey, uint16 entered) {
        stdout.printf("BluezAgent: display_pass_key(%s, %ui, %ui)\n", device, passkey, entered);
    }
    public void request_confirmation(ObjectPath device, uint32 passkey) {
        stdout.printf("BluezAgent: request_confirmation(%s, %ui)\n", device, passkey);
    }
    public void request_authorization(ObjectPath device) {
        stdout.printf("BluezAgent: request_authorization(%s)\n", device);
    }
    public void authorize_service(ObjectPath device, string uuid) {
        stdout.printf("BluezAgent: authorize_service(%s, %s)\n", device, uuid);
    }
    public void cancel() {
        stdout.printf("BluezAgent: cancel()\n");
    }
}

public class XfceBluetoothAgent : GLib.Object {
    Gtk.StatusIcon trayicon;
    BluezAgentManagerBus manager;
    BluezAgent agent;
    string busname;
    DBusConnection bus;
    string agent_path;
    uint reg_id;
	private Gtk.Menu menu;

    public XfceBluetoothAgent() {
		menu = new Gtk.Menu();
		var menu_quit = new ImageMenuItem.from_stock(Stock.QUIT, null);
		menu_quit.activate.connect(Gtk.main_quit);
		menu.append(menu_quit);
		menu.show_all();

        trayicon = new Gtk.StatusIcon.from_icon_name("bluetooth");

        trayicon.popup_menu.connect((button, time) => {
			menu.popup(null, null, null, button, time);
		});
        try {
            bus = Bus.get_sync(BusType.SYSTEM, null);
            Bus.watch_name_on_connection(bus, "org.bluez",
                                         BusNameWatcherFlags.NONE,
                                         (conn, name, name_owner) => {
                                             busname = name;
                                             register();
                                         },
                                         (conn, name) => {
                                             busname = null;
                                         });
        } catch (IOError e) {
            stderr.printf ("%s\n", e.message);
        }
    }

    public void register() {
        try {
            ObjectPath path = new ObjectPath("/org/bluez/xfce/agent");
            agent = new BluezAgent();
            reg_id = bus.register_object("/org/bluez/xfce/agent", agent);
            manager = Bus.get_proxy_sync(BusType.SYSTEM, "org.bluez",
                                         "/org/bluez");
            manager.register_agent(path, "KeyboardDisplay");
            manager.request_default_agent(path);
            stdout.printf("Agent registered\n");
        } catch (IOError e) {
            stderr.printf("Error when register: %s", e.message);
        }
    }
}

int main (string[] args) {
    Gtk.init(ref args);
    var agent = new XfceBluetoothAgent();
    Gtk.main();
    return 0;
}
