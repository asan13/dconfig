module dconfig.config;

import std.stdio;
import core.runtime;

import dconfig.options;
import dconfig.parse;

private string[] g_args;

void initArgs(string[] args = null)
{
    if (args is null && g_args) return;

    if (args is null)
    {
        import core.runtime;
        args = Runtime.args;
    }
        
    g_args = args;
}


T getConfig(T)(string file = null, ref string[] args = null)
{
    static if ( is(T == struct) )
        T cfg;
    else static if ( is(T == class) )
        T cfg = new T;
    else
        static assert(0, "class or struct required");

    return getConfig(cfg, file, args);
}

T getConfig(T)(T cfg, string file = null, ref string[] args = null)
{
    import std.file;
    import std.path;
    import std.json : parseJSON;

    initArgs(args);
    
    if (file.length) {
        file = file.expandTilde.absolutePath;
        enforce(file.isFile, new Exception("config " ~ file ~ " not exist"));

        auto json = file.readText.parseJSON;
    
        readStruct!(T)(cfg, json);
    }

    if (g_args.length > 1)
    {
        readStruct(cfg, g_args);
    }

    return cfg;
}

T getOptions(T)(string[] args = null)
    if (is(T == struct) || is(T == class))
{
    static if (is(T == struct))
        T opts;
    else
        T opts = new T;

    return getOptions(opts, args);
}

T getOptions(T)(T opts, string[] args = null)
    if (is(T == struct) || is(T == class))
{
    if (args)
        readStruct(opts, args);
    else if (g_args)
        readStruct(opts, args);
    else
    {
        initArgs();
        if (g_args)
            readStruct(opts, args);
    }

    return opts;
}

unittest {
    string[] args = ["cmd", "--foo", "bar", "-Z", "42"];

    struct S {
        @option("foo") string x;
        @option("Z")   int    y;
    }

    auto opts = getOptions!S(args);

    assert(opts.x == "bar");
    assert(opts.y == 42);
    //assert(args == ["cmd"], "reduce args");
}

