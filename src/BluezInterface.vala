
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
    [DBus (name = "GetAll")]
    public abstract HashTable<string, Variant> get_all(string iface)
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
                          HashTable<string, Variant>? props = null) {
        iface_name = name;
        object_path = path;
        bus = Bus.get_proxy_sync (BusType.SYSTEM, "org.bluez", path);
        if (props == null) {
            properties = bus.get_all(iface_name);
        } else
            properties = props;
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

/* http://git.kernel.org/cgit/bluetooth/bluez.git/tree/doc/adapter-api.txt */
public class BluezAdapter : BluezInterface {
    private string[] _uuids;

    public string address {
        get { return base.get("Address").get_string(); }
    }

    public string name {
        get { return base.get("Name").get_string(); }
    }

    public string alias {
        get { return base.get("Alias").get_string(); }
        set { base.set("Alias", value); }
    }

    public uint32 class {
        get { return base.get("Class").get_uint32(); }
    }

    public bool powered {
        get { return base.get("Powered").get_boolean(); }
        set { base.set("Powered", value); }
    }

    public bool discoverable {
        get { return base.get("Discoverable").get_boolean(); }
        set { base.set("Discoverable", value); }
    }

    public bool pairable {
        get { return base.get("Pairable").get_boolean(); }
        set { base.set("Pairable", value); }
    }

    public uint32 pairable_timeout {
        get { return base.get("PairableTimeout").get_uint32(); }
        set { base.set("PairableTimeout", value); }
    }

    public uint32 discoverable_timeout {
        get { return base.get("DiscoverableTimeout").get_uint32(); }
        set { base.set("DiscoverableTimeout", value); }
    }

    public bool discovering {
        get { return base.get("Discovering").get_boolean(); }
    }

    public weak string[] uuids {
        get {
            _uuids = base.get("UUIDs").get_strv();
            return _uuids;
        }
    }

    public BluezAdapter(ObjectPath path,
                        HashTable<string, Variant>? props = null) {
        base("org.bluez.Adapter1", path, props);
    }
}
