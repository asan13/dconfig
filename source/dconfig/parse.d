module dconfig.parse;

import std.stdio;
import std.string;
import std.meta;
import std.traits;
import std.typecons;
import std.json;

import dconfig.meta;
import dconfig.options;


void readOpt(string mem, T)(ref string[] args, ref T t) 
{
    import std.getopt;

    enum m = "t." ~ mem;
    static if (hasUDA!(mixin("T." ~ mem), OptionAttr))
    {
        string descr = getUDAs!(mixin(m), OptionAttr)[0].descr;
    }
    else 
    {
        string descr = mem; 
    }

    getopt( args, 
            std.getopt.config.passThrough,  
            descr.replace("_", "-"),
            &__traits(getMember, t, mem)
    );
}


T readStruct(T)(ref T t, ref string[] args)
{
    foreach (mem; settableMembers!(T))
    {
        enum m   = "t." ~ mem;
        alias mt = typeof(mixin(m));

        static if ( is(mt == struct) || is(mt == class) )
        {
            readStruct(mixin(m), args);
        }
        else
        {
            readOpt!mem(args, t);
        }
    }

    return t;
}

template memberName(T, string mem) {
    static if (hasUDA!(mixin("T."~mem), OptionAttr))
        enum memberName = getUDAs!(mixin("T."~mem), OptionAttr)[0].descr;
    else
        enum memberName = mem;
}


T readStruct(T)(ref T t, JSONValue jval)
{
    import std.range : ElementType;

    foreach (mem; settableMembers!(T))
    {
        enum mname = memberName!(T, mem);
        if (mname !in jval)
            continue;

        enum m   = "t." ~ mem;
        alias mt = typeof(mixin(m));

        static if ( is(mt == struct) || is(mt == class) )
        {
            readStruct!mt(mixin(m), jval[mname]);
        }
        else static if ( !isSomeString!mt && isArray!mt)
        {
            foreach (jv; jval[mname].array)
            {
                alias et = ElementType!mt;
                static if (is(et == struct) || is(et == class))
                {
                    mt el;
                    mixin(m) ~= readStruct(el, jv);
                }
                else
                    mixin(m) ~= jsonToType!et(jv);
            }
        }
        else
        {
            mixin(m) = jsonToType!mt(jval[mname]);
        }
    }

    return t;
}

auto ref T jsonToType(T)(JSONValue jv)
{
    import std.conv : to;

    static if (is(T : string))
        return jv.str;
    else static if (is(T: int))
       return to!int(jv.integer);
    else static if (is(T: uint))
       return jv.uinteger;
    else static if (is(T: double))
       return jv.floating;
    else static if (is(T: bool))
       return tv.type == JSON_TYPE.TRUE;
    else 
        assert(0, "unimplemented for " ~ T.stringof);
}

unittest {
    //import std.file;
    //auto json = "test.json".readText.parseJSON;
    string str = `{"db":{"dbname":"asan","port":5433},"dir":"sql",`
                ~ `"nodes":[1,2,3]}`;
    auto json = str.parseJSON;

    struct Conf {
        struct DB {
            string dbname;
            int port;
        }

        DB db;
        string dir;
        int[] nodes;
        string test = "test";
    }

    Conf c;
    c = readStruct!Conf(c, json);

    assert(c.dir == "sql");
    assert(c.db.port   == 5433);
    assert(c.db.dbname == "asan");
    assert(c.nodes == [1, 2, 3]);

}

JSONValue structToJSON(T)()
{
    import std.range : ElementType;

    JSONValue[string] res;

    foreach (m; settableMembers!T) 
    {
        enum mf = "T." ~ m;
        alias mt = typeof(mixin(mf));
        static if ( is(mt == class) || is(mt == struct) )
        {
            res[m] = structToJSON!mt;
        }
        else static if (isArray!mt)
        {
            alias el = ElementType!mt;
            static if (is(el == class) || is(el == struct))
                res[m] = JSONValue( [ structToJSON!el ] );
            else
                res[m] = JSONValue(mixin(mf).init);
        }
        else
        {
            res[m] = JSONValue(mixin(mf).init);
        }
    }
    
    return JSONValue(res);
}

bool asBool(const ref JSONValue jv)
{
    switch (jv.type) {
        case JSON_TYPE.TRUE:
            return true;
        case JSON_TYPE.FALSE:
            return false;
        default:
            assert(0, "not boolean JSONvalue");
    }
    assert(0);
}

unittest {
    struct Conf {
        struct DB {
            string dbname;
            int port;
        }
        DB db;
        DB[] backs;
        string dir;
        bool   f;
    }

    auto j = structToJSON!Conf;

    assert(j["dir"].str == "");
    assert(j["db"]["port"].integer == 0);
    assert(!j["f"].asBool);
}


/*
 *readOpt
 */
unittest {
    string[] args = ["test", "-D", "tezd", "--port", "42"];

    struct Test {
        @option("dbname", "D")
        string dbname;
        uint port;
    }

    Test t;

    readOpt!("dbname")(args, t);
    assert(t.dbname == "tezd");
    assert(args == ["test", "--port", "42"]);

    readOpt!("port")(args, t);
    assert(t.port == 42);
    assert(args == ["test"]);

}


/*
 *readStruct
 */
unittest {
    struct S {
        struct Z {
            @option("xxx")
            int x;
        }

        int x;
        int y = 42;
        Z z;
    }

    string[] args = ["cmd", "--xxx", "13", "-x", "23"];

    S s;

    auto t = readStruct!S(s, args); 
}


