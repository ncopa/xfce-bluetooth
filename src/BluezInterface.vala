
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

public abstract class BluezInterface : GLib.Object {
    DBusProperties bus;
    string iface_name;
    HashTable<string, Variant> property_cache;

    public ObjectPath object_path = null;

    public BluezInterface(string name, ObjectPath path,
                          HashTable<string, Variant>? props = null) {
        iface_name = name;
        object_path = path;
        bus = Bus.get_proxy_sync (BusType.SYSTEM, "org.bluez", path);
        if (props == null) {
            property_cache = bus.get_all(iface_name);
        } else
            property_cache = props;
        bus.properties_changed.connect(on_properties_changed);
    }

    public Variant get_cache(string key) {
        return property_cache.get(key);
    }

    public void set_cache(string key, Variant val) {
        property_cache.replace(key, val);
    }

    public void set_bus(string key, Variant val) throws IOError {
        if (val.equal(property_cache.get(key)))
            return;
        try {
            bus.set(iface_name, key, val);
            set_cache(key, val);
        } catch (IOError e) {
            stderr.printf("Failed to set %s=%s: %s", key, val.print(false), e.message);
        }
    }

    public abstract void property_changed(string key, Variant val);

    public void on_properties_changed(string iface,
                                      HashTable <string, Variant> changed,
                                      string[] invalidated) {
        changed.foreach((key, val) => {
            if (val.equal(property_cache.get(key)))
                return; /* continue foreach */
            set_cache(key, val);
            stdout.printf("BluezInterface: %s: %s=%s\n", iface, key, val.print(false));
            property_changed(key, val);
        });
    }
}

/* http://git.kernel.org/cgit/bluetooth/bluez.git/tree/doc/adapter-api.txt */
public class BluezAdapterProperties : BluezInterface {
    private string[] _uuids;

    public string address {
        get { return this.get_cache("Address").get_string(); }
    }

    public string name {
        get { return this.get_cache("Name").get_string(); }
    }

    public string alias {
        get { return this.get_cache("Alias").get_string(); }
        set { this.set_bus("Alias", value); }
    }

    public uint32 class {
        get { return this.get_cache("Class").get_uint32(); }
    }

    public bool powered {
        get { return this.get_cache("Powered").get_boolean(); }
        set { this.set_bus("Powered", value); }
    }

    public bool discoverable {
        get { return this.get_cache("Discoverable").get_boolean(); }
        set { this.set_bus("Discoverable", value); }
    }

    public bool pairable {
        get { return this.get_cache("Pairable").get_boolean(); }
        set { this.set_bus("Pairable", value); }
    }

    public uint32 pairable_timeout {
        get { return this.get_cache("PairableTimeout").get_uint32(); }
        set { this.set_bus("PairableTimeout", value); }
    }

    public uint32 discoverable_timeout {
        get { return this.get_cache("DiscoverableTimeout").get_uint32(); }
        set { this.set_bus("DiscoverableTimeout", value); }
    }

    public bool discovering {
        get { return this.get_cache("Discovering").get_boolean(); }
        private set { /* should alreay been set */ }
    }

    public weak string[] uuids {
        get {
            _uuids = this.get_cache("UUIDs").get_strv();
            return _uuids;
        }
    }

    public BluezAdapterProperties(ObjectPath path,
                        HashTable<string, Variant>? props = null) {
        base("org.bluez.Adapter1", path, props);
    }

    public signal void alias_changed();
    public signal void powered_changed();
    public signal void discoverable_changed();
    public signal void pairable_changed();
    public signal void pairable_timeout_changed();
    public signal void discoverable_timeout_changed();
    public signal void discovering_changed();

    public override void property_changed(string prop, Variant val) {
        switch (prop) {
        case "Alias":
            alias_changed();
            break;
        case "Powered":
            powered_changed();
            break;
        case "Discoverable":
            discoverable_changed();
            break;
        case "Pairable":
            pairable_changed();
            break;
        case "PairableTimeout":
            pairable_timeout_changed();
            break;
        case "DiscoverableTimeout":
            discoverable_timeout_changed();
            break;
        case "Discovering":
            discovering_changed();
            break;
        }
    }
}
