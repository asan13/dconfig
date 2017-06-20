module dconfig.options;


struct OptionAttr {
    string[] opts;
    string descr() {
        import std.array : join;
        return opts.join("|");
    }
}

OptionAttr option(T...)(T opts)
{
    string[] vals;
    foreach (v; opts) {
        static assert( is(typeof(v) == string), "not string");
        vals ~= v;
    }
    return OptionAttr(vals);
}

alias name = option;

enum IgnoreAttr;
alias ignore = IgnoreAttr;

struct HelpAttr {
    string text;
}

HelpAttr help(string text) {
    return HelpAttr(text);
}
