
[DBus (name = "org.freedesktop.DBus.ObjectManager")]
interface DBusObjectManager : GLib.Object {
    [DBus (name = "GetManagedObjects")]
    public abstract HashTable<ObjectPath, HashTable<string, HashTable<string, Variant>>> get_managed_objects() throws DBusError, IOError;
}

[DBus (name = "org.freedesktop.DBus.Properties")]
interface DBusProperties : GLib.Object {
    [DBus (name = "Set")]
    public abstract void set(string iface, string name, Variant val)
                            throws DBusError, IOError;
    [DBus (name = "Get")]
    public abstract Variant get(string iface, string name)
                               throws DBusError, IOError;
    public signal void properties_changed(string iface,
                                          HashTable <string, Variant> changed,
                                          string[] invalidated);
}

[DBus (name = "org.bluez.AgentManager1")]
interface BluezAgentManager : GLib.Object {
    [DBus (name = "RegisterAgent")]
    public abstract void register_agent(ObjectPath agent, string capability) throws DBusError, IOError;
    [DBus (name = "RequestDefaultAgent")]
    public abstract void request_default_agent(ObjectPath agent) throws DBusError, IOError;
}

public class BluezInterface : GLib.Object {
    DBusProperties bus;
    string iface_name;
    HashTable<string, Variant> properties;

    public ObjectPath object_path = null;

    public BluezInterface(string name, ObjectPath path,
                          HashTable<string, Variant> props) {
        properties = props;
        iface_name = name;
        object_path = path;
        bus = Bus.get_proxy_sync (BusType.SYSTEM, "org.bluez", path);
        bus.properties_changed.connect(on_properties_changed);
    }

    public new Variant get(string property) {
        return properties.get(property);
    }

    public new void set(string property, Variant val) throws IOError {
        bus.set(iface_name, property, val);
    }

    public signal void property_changed(string prop, Variant val);

    public void on_properties_changed(string iface,
                                      HashTable <string, Variant> changed,
                                      string[] invalidated) {
        changed.foreach((key, val) => {
            properties.replace(key, val);
            stdout.printf("%s: %s: %s\n", iface, key, val.print(false));
            property_changed(key, val);
        });
    }
}
