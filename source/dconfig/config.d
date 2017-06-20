module dconfig.config;

import std.stdio;
import std.exception;
import core.runtime;

public import dconfig.options;
import dconfig.parse;

mixin template defVar(T) {

    static if ( is(T == struct) )
        T var;
    else static if ( is(T == class) )
        T var = new T;
    else
        static assert(0, "class or struct required");
}

T readFromFile(T)(string file)
{
    mixin defVar!T;
    return readFromFile(var, file);
}

T readFromFile(T)(ref T cfg, string file) 
{
    import std.file;
    import std.path;
    import std.json : parseJSON;

    if (file.length) {
        file = file.expandTilde.absolutePath;
        enforce(file.isFile, 
                new Exception("config " ~ file ~ " not exist")
        );

        auto json = file.readText.parseJSON;
    
        readStruct!(T)(cfg, json);
    }

    return cfg;
}

T readFromArgs(T)(ref string[] args)
{
    mixin defVar!T;
    return readFromArgs(var, args);
}


T readFromArgs(T)(ref T cfg, string[] args) 
{
    readStruct!T(cfg, args);
    return cfg;
}

T getConfig(T)(string file, string[] args)
{
    T cfg = readFromFile!T(file);
    cfg   = readFromArgs(cfg, args);
    return cfg;
}

mixin template MyConfig() {
    alias Type = typeof(this);

    static private string[] g_args;
    static private Type _cfg;
    static private bool _initialized;
    static private bool _needHelp;

    static bool needHelp() @property { return _needHelp; }

    static auto ref get()
    {
        return _cfg;
    }

    void dumpConfig() {

    }

    static auto ref getCommandOpts(T)()
    {
        return readFromArgs!T(g_args);
    }

    static Type init(string file = null, string[] args = null)
    {
        import std.getopt;

        static if (is(Type == class))
            Type cfg = new Type;
        else 
            Type cfg;

        if (!args.length)
        {
            import core.runtime;
            args = Runtime.args;
        }

        _cfg   = cfg;
        g_args = args;

        if (args.length > 1) 
        {
            getopt(g_args, std.getopt.config.passThrough, "help|h", &_needHelp);

            if (needHelp) return _cfg;
        }

        if (args.length > 1)
        {
            getopt(g_args, std.getopt.config.passThrough, "config", &file);
        }

        if (!file.length)
        {
            import std.path;
            import std.file;

            string defFile = args[0].baseName.stripExtension ~ ".json";
            if (defFile.exists && defFile.isFile)
                file = defFile;
        }

        if (file.length) 
            readFromFile!Type(_cfg, file);


        if (args.length > 1)
            readFromArgs!Type(_cfg, g_args);

        return _cfg;
    }

}

version (unittest) {
    struct TestConfig {
        mixin MyConfig;
        struct DB {
            string dbname;
            int port;
        }

        string dir;
        DB     db;
        int[]  nodes;
        string table;
    }
}

unittest {

    auto cfg = readFromFile!TestConfig("test.json");
    assert(cfg.dir     == "sql");
    assert(cfg.db.port == 5433);

    string[] args = ["cmd", "--dir", "dump", "--port", "123", "--foo", "bar"];
    cfg = readFromArgs(cfg, args);
    assert(cfg.dir     == "dump");
    assert(cfg.db.port == 123);

    args ~= ["--table", "zzz"];
    cfg = TestConfig.init("test.json", args);
    assert(cfg.table == "zzz");

    struct S {
        string foo;
    }
    auto s = cfg.getCommandOpts!S();
    assert(s.foo == "bar");
}
