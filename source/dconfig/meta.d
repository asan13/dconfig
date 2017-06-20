module dconfig.meta;

import std.meta;
import std.traits;

import dconfig.options;


//enum IgnoreAttr;
//alias ignore = IgnoreAttr;

template settableMembers(T) {
    alias settableMembers = filterSettables!(
            T, __traits(allMembers, T));
}

template filterSettables(T, M...) {
    static if (M.length == 0)
        alias filterSettables = AliasSeq!();
    else 
    {
        static if (isSettable!(T, M[0]))
        {
            static if (hasUDA!(mixin("T." ~ M[0]), IgnoreAttr))
                alias filterSettables = filterSettables!(T, M[1..$]);
            else
                alias filterSettables = AliasSeq!( 
                        M[0], 
                        filterSettables!(T, M[1..$])
                );
        }
        else
            alias filterSettables = filterSettables!(T, M[1..$]);
    }
}



template isAlias(T, string mem) {

    static if ( is(AliasSeq!(__traits(getMember, T, mem))) )
        enum isAlias = !(mem == mixin("T." ~ mem).stringof);
    else
        enum isAlias = !(mem == __traits(identifier, mixin("T." ~ mem)));
}


template isSettable(T, string M) {
    
    static if (is(AliasSeq!(__traits(getMember, T, M))))
        enum isSettable = false;
    else static if (!is(typeof(__traits(getMember, T, M))))
        enum isSettable = false;
    else static if ( __traits(getProtection, mixin("T." ~ M)) != "public")
        enum isSettable = false;
    else static if (__traits(isTemplate, __traits(getMember, T, M)))
        enum isSettable = false;
    //else static if (is(typeof(__traits(getMember, T, M)) == void))
        //enum isSettable = false;
    else static if ( isAlias!(T, M) )
        enum isSettable = false;
    else static if (isFunction!(__traits(getMember, T, M)))
        enum isSettable = false;
    else static if (hasUDA!(mixin("T." ~ M), IgnoreAttr))
        enum isSettable = false;
    else static if (M[0] == '_')
        enum isSettable = false;
    else
        enum isSettable = true;

    // TODO
}


unittest {
    struct S {
        struct Z { }
        int x;
        alias y = x;
        alias z = Z;
        alias I = int;
        void f() {}
        alias b = f;
    }

    assert( isAlias!(S, "x") == false );
    assert( isAlias!(S, "y") == true  );
    assert( isAlias!(S, "Z") == false );
    assert( isAlias!(S, "z") == true  );
    assert( isAlias!(S, "I") == true  );
    assert( isAlias!(S, "f") == false );
    assert( isAlias!(S, "b") == true  );
}

unittest {
    struct S {
        int x;
        int y;
        struct R { }
        void f() { }
        alias z = x;
        private int h;
    }

    assert( isSettable!(S, "x") == true  );
    assert( isSettable!(S, "y") == true  );
    assert( isSettable!(S, "R") == false );
    assert( isSettable!(S, "f") == false );
    assert( isSettable!(S, "z") == false );
    assert( isSettable!(S, "h") == false );

    alias mems = settableMembers!S;
    assert(AliasSeq!("x", "y") == mems);
}
