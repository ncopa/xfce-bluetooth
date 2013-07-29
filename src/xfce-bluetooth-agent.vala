using Gtk;

[DBus(name = "org.bluez.Agent1")]
public class BluezAgent : GLib.Object {
    public void release() {
        stdout.printf("BluezAgent: release()\n");
    }
    public string request_pin_code(ObjectPath device) {
        stdout.printf("BluezAgent: request_pin_code(%s)\n", device);
        return "";
    }
    public void display_pin_code(ObjectPath device, string pincode) {
        stdout.printf("BluezAgent: display_pin_code(%s, %s)\n", device, pincode);
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
    BluezAgentManager manager;
    BluezAgent agent;
    string busname;
    DBusConnection bus;
    string agent_path;
    uint reg_id;

    public XfceBluetoothAgent() {
        trayicon = new Gtk.StatusIcon.from_icon_name("bluetooth");
        trayicon.button_press_event.connect((evt) => {
            switch (evt.button) {
                case 1:    // left-click
                    print("clicked.\n");
                    break;
                default:   // middle & right click
                    Gtk.main_quit();
                    break;
            }
            return true;
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