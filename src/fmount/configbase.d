// Written in the D programming language.

/**
Configuration file manager for the `fmount` project.

Copyright: Copyright Ludovic Dordet 2018.
License:   $(HTTP www.gnu.org/licenses/gpl-3.0.md,
             GNU GENERAL PUBLIC LICENSE 3.0).
Authors:   Ludovic Dordet
*/
/*
         Copyright Ludovic Dordet 2018.
Distributed under the GNU GENERAL PUBLIC LICENSE, Version 3.0.
   (See accompanying file LICENSE.md or copy at
         http://www.gnu.org/licenses/gpl-3.0.md)
*/
module config;

import std.file : exists, isDir, isFile, write;
import std.path : dirName;
import std.stdio : writefln;
import std.string : indexOf;

import appargs : verbose;
import sdlang : parseFile, parseSource, SDLangException, Tag, Value;
import ui : tracef, warnf;


/**
 * A simple SDLang-formatted configuration wrapper, using one or several
 * configuration sources.
 */
class Config
{
    public:
        /// Destructor.
        ~this()
        {
            clearParsed();
            clearTags();
            clearSources();
        }

        /**
         * Add a configuration source.
         *
         * First sources are preferred, thus sources should be added in that
         * typical order: user's config, local config, system config.
         *
         * No source should be added after a `get` method has been called at
         * least once, or you should know what you are doing.
         *
         *  Parameters:
         *    source = either a file path or a configuration content.
         */
        void addSource(inout(string) source)
        {
            _sources ~= source;

            if (parsed)
            {
                /**
                 * At least one configuration source has been parsed, thus this
                 * new source must be parsed immediately before any further
                 * `get` call.
                 */
                parseOneSource(source);
            }
        }

        /**
         * Retrieve a configuration attribute or value, or the default value
         * if the name could not be found in any configuration source.
         */
        T get(T)(string name, T defaultValue = T.init)
        {
            ensureParsed();

            T getImpl(Tag tag)
            {
                scope(failure)
                    return tag.expectTagValue!T(name);

                return tag.expectAttribute!T(name);
            }

            return getInCfg!T(&getImpl, defaultValue);
        }

        /**
         * Retrieve a configuration attribute, or the default if the name
         * could not be found in any configuration source.
         */
        T getAttribute(T)(string name, T defaultAttr = T.init)
        {
            ensureParsed();

            T getAttributeImpl(Tag tag)
            {
                return tag.expectAttribute!T(name);
            }

            return getInCfg!T(&getAttributeImpl, defaultAttr);
        }

        /**
         * Retrieve a configuration value, or the default if the name
         * could not be found in any configuration source.
         */
        T getValue(T)(string name, T defaultValue = T.init)
        {
            ensureParsed();

            T getValueImpl(Tag tag)
            {
                return tag.expectTagValue!T(name);
            }

            return getInCfg!T(&getValueImpl, defaultValue);
        }

        /**
         * Retrieve the named configuration values with the specified type.
         */
        T[] getValues(T)(string name, T[] defaultValues = [])
        {
            ensureParsed();

            T[] getValuesImpl(Tag tag)
            {
                Value[] tagVals = tag.getTagValues(name);
                if (tagVals != null)
                {
                    T[] values;

                    foreach (tv; tagVals)
                    {
                        if (tv.type == typeid(T))
                            values ~= tv.get!T();
                    }

                    return values;
                }

                return defaultValues;
            }

            return getInCfg!(T[])(&getValuesImpl, defaultValues);
        }

        /**
         * Parse the available configuration sources.
         */
        void parse()
        {
            ensureParsed();
        }

        /**
         * Retrieve the configuration sources, in the same order as they have
         * been added.
         */
        @property string[] sources() { return _sources; }

        /// Check whether the sources have been read.
        @property bool parsed() const { return _parsed; }

        /// Retrieve a named tag in each configuration.
        Config getSubConfig(string name)
        {
            ensureParsed();

            Tag[] subTags;

            foreach (Tag tag; tags)
            {
                Tag st = tag.getTag(name);
                if (st !is null)
                    subTags ~= st;
            }

            Config subCfg = new Config;
            subCfg.initSubConfig(parsed, subTags);
            return subCfg;
        }

        /**
         * Load or reload the configuration.
         *
         * Note: calling this method from
         * subconfigurations will result in unexpected behavior.
         */
        void reload()
        {
            clearParsed();
            clearTags();
            ensureParsed();
        }

    private:

        /**
         * The configuration sources, each one being either a file path or a
         * configuration content.
         */
        string[] _sources;

        /**
         * The parsed configurations.
         */
        Tag[] _tags;

        /**
         * `true` when at least one configuration value has been retrieved.
         */
        bool _parsed;

        /// Retrieve the list of parsed configurations.
        @property Tag[] tags()
        {
            return _tags.dup;
        }

        /// Add the root of a newly parsed source.
        void appendParsed(Tag root)
        {
            _tags ~= root;
        }

        /**
         * Ensure that all sources have been parsed.
         */
        void ensureParsed()
        {
            if (!parsed)
            {
                foreach(string source; _sources)
                {
                    parseOneSource(source);
                }
            }
        }

        /**
         * Parse one configuration file or content.
         */
        void parseOneSource(inout(string) src)
        {
            if (exists(src) && isFile(src))
                appendParsed(parseFile(src));
            else if (indexOf(src, "\n") >= 0)
                appendParsed(parseSource(src));
            else
            {
                immutable string parent = dirName(src);

                if (exists(parent))
                {
                    if (isDir(parent))
                        tracef("No config file '%s'", src);
                    else
                        warnf("'%s' should be a directory.", parent);
                }
            }
        }

        /**
         * Retrieve one configured value : tag value or attribute value.
         */
        T getInCfg(T)(T delegate(Tag) getVal, T dflt)
        {
            ensureParsed();

            foreach(Tag tag; tags)
            {
                scope(failure)
                    continue;

                return getVal(tag);
            }

            return dflt;
        }

        /// Initialize a sub-config.
        void initSubConfig(bool subParsed, Tag[] subTags)
        {
            _parsed = subParsed;
            _tags = subTags.dup;
        }

        void clearParsed()
        {
            _parsed = false;
        }

        void clearTags()
        {
            foreach (tag; _tags)
                destroy(tag);

            _tags.length = 0;
        }

        void clearSources()
        {
            _sources.length = 0;
        }
}


/// Unit tests
unittest
{
    import std.conv : to;
    import std.file : deleteme;
    import std.format : format;

    import dutil.src : SrcLn, srcln;

    immutable int MISSING_INT = -9876;
    immutable string MISSING_STRING = "MISSING STRING IN CONFIG";

    void doTest(Config cfg)
    {
        // test attributes-or-values
        template t1(T)
        {
            void t1(string file=__FILE__, size_t line=__LINE__)
                   (inout(string) name, inout(T) dflt, inout(T) exp,
                    SrcLn fl=srcln(file, line))
            {
                immutable _f = "\n%sUnexpected %s = '%s'";
                T v = cfg.get!T(name, dflt);
                assert(v == exp, _f.format(fl, name, to!string(v)));
            }
            void t1(string file=__FILE__, size_t line=__LINE__)
                   (inout(string) subName, inout(string) name,
                    inout(T) dflt, inout(T) exp,
                    SrcLn fl=srcln(file, line))
            {
                immutable _f = "\n%sUnexpected %s.%s = '%s'";
                T v = cfg.getSubConfig(subName).get!T(name, dflt);
                assert(v == exp, _f.format(fl, subName, name, to!string(v)));
            }
        }

        // test attributes
        template a1(T)
        {
            void a1(string file=__FILE__, size_t line=__LINE__)
                   (inout(string) name, inout(T) dflt, inout(T) exp,
                    SrcLn fl=srcln(file, line))
            {
                immutable _f = "\n%sUnexpected %s attribute = '%s'";
                T v = cfg.getAttribute!T(name, dflt);
                assert(v == exp, _f.format(fl, name, to!string(v)));
            }
            void a1(string file=__FILE__, size_t line=__LINE__)
                   (inout(string) subName, inout(string) name,
                    inout(T) dflt, inout(T) exp,
                    SrcLn fl=srcln(file, line))
            {
                immutable _f = "\n%sUnexpected %s.%s attribute = '%s'";
                T v = cfg.getSubConfig(subName).getAttribute!T(name, dflt);
                assert(v == exp, _f.format(fl, subName, name, to!string(v)));
            }
        }

        // test values
        template v1(T)
        {
            void v1(string file=__FILE__, size_t line=__LINE__)
                   (inout(string) name, inout(T) dflt, inout(T) exp,
                    SrcLn fl=srcln(file, line))
            {
                immutable _f = "\n%sUnexpected %s value = '%s'";
                T v = cfg.getValue!T(name, dflt);
                assert(v == exp, _f.format(fl, name, to!string(v)));
            }
            void v1(string file=__FILE__, size_t line=__LINE__)
                   (inout(string) subName, inout(string) name,
                    inout(T) dflt, inout(T) exp,
                    SrcLn fl=srcln(file, line))
            {
                immutable _f = "\n%sUnexpected %s.%s value = '%s'";
                T v = cfg.getSubConfig(subName).getValue!T(name, dflt);
                assert(v == exp, _f.format(fl, subName, name, to!string(v)));
            }
        }

        t1!int("iv0", MISSING_INT, 10);
        v1!int("iv0", MISSING_INT, 10);
        t1!string("sv0", MISSING_STRING, "Zero");
        v1!string("sv0", MISSING_STRING, "Zero");

        t1!int("sub1", "iv1", MISSING_INT, 1);
        a1!int("sub1", "iv1", MISSING_INT, 1);
        v1!int("sub1", "iv1", MISSING_INT, 11);
        t1!int("sub1", "iv2", MISSING_INT, -2);
        v1!int("sub1", "iv2", MISSING_INT, -2);

        t1!string("sub2", "sv1", MISSING_STRING, "one");
        a1!string("sub2", "sv1", MISSING_STRING, "eleven");
        v1!string("sub2", "sv1", MISSING_STRING, "one");
        t1!string("sub2", "sv2", MISSING_STRING, "two");
        a1!string("sub2", "sv2", MISSING_STRING, "two");
        v1!string("sub2", "sv2", MISSING_STRING, MISSING_STRING);

        t1!int("sub3", "iv3", MISSING_INT, 3);
        a1!int("sub3", "iv3", MISSING_INT, 3);
        v1!int("sub3", "iv3", MISSING_INT, MISSING_INT);
        t1!int("sub4", "iv4", MISSING_INT, -4);
        a1!int("sub4", "iv4", MISSING_INT, MISSING_INT);
        v1!int("sub4", "iv4", MISSING_INT, -4);
        t1!string("sub4", "sv3", MISSING_STRING, "three");
        a1!string("sub4", "sv3", MISSING_STRING, MISSING_STRING);
        v1!string("sub4", "sv3", MISSING_STRING, "three");
        t1!string("sub4", "sv4", MISSING_STRING, "four");
        a1!string("sub4", "sv4", MISSING_STRING, "four");
        v1!string("sub4", "sv4", MISSING_STRING, MISSING_STRING);

        t1!int("iv5", MISSING_INT, MISSING_INT);
        v1!int("iv5", MISSING_INT, MISSING_INT);
        t1!int("sub4", "iv6", MISSING_INT, MISSING_INT);
        a1!int("sub4", "iv6", MISSING_INT, MISSING_INT);
        v1!int("sub4", "iv6", MISSING_INT, MISSING_INT);
        t1!string("sub4", "sv6", MISSING_STRING, MISSING_STRING);
        a1!string("sub4", "sv6", MISSING_STRING, MISSING_STRING);
        v1!string("sub4", "sv6", MISSING_STRING, MISSING_STRING);
    }

    immutable string content1 = `
iv0 10
# no-sv0

sub1 iv1=1 {

    # comment
    iv2 -2
}

sub2 sv2="two" {
    sv1 "one"
}

sub3 {
}

# no-sub4 no-iv4 no-sv3 no-sv4
`;

immutable string content2 = `
#no-iv0
sv0 "Zero"

sub1 {
    iv1 11   # unused;  no-iv2 either
}

sub2 sv1="eleven"   # no-sv2

sub3 iv3=3

#comment too
sub4 sv4="four" {
    iv4 -4
    sv3 "three"
}
`;

    immutable string file1 = deleteme ~ ".config-unittest-f1.cfg";
    immutable string file2 = deleteme ~ ".config-unittest-f2.cfg";

    scope(exit)
    {
        import std.file : exists, remove;

        foreach (file; [file1, file2])
        {
            if (file.exists)
                file.remove;
        }
    }

    string writeToFile(string fileName, string content)
    {
        write(fileName, content);
        return fileName;
    }

    void testConfigWithTwoSourceFiles()
    {
        Config cfg = new Config;
        cfg.addSource(writeToFile(file1, content1));
        cfg.addSource(writeToFile(file2, content2));
        doTest(cfg);
    }

    void testConfigWithTwoSourceContents()
    {
        Config cfg = new Config;
        cfg.addSource(content1);
        cfg.addSource(content2);
        doTest(cfg);
    }

    void testConfigWithFileThenContent()
    {
        Config cfg = new Config;
        cfg.addSource(writeToFile(file1, content1));
        cfg.addSource(content2);
        doTest(cfg);
    }

    void testConfigWithContentThenFile()
    {
        Config cfg = new Config;
        cfg.addSource(content1);
        cfg.addSource(writeToFile(file2, content2));
        doTest(cfg);
    }

}


// default configuration test: missing configuration file, missing subconfig.
unittest
{
    import osutil : get_dir, jn, removeIfExists;
    import std.file : deleteme, write;

    immutable config_file = jn(get_dir(deleteme), "app.dfltSubCfg.conf");
    auto cfg = new Config();

    enum DFLT_CONFIG = `
    stringConf "stringValue"

    severalData {
        data1 "Español"
        data2 "English"
        data3 "Français"
    }
    `;

    void doTest()
    {
        auto severalData = cfg.getSubConfig("severalData");

        assert(severalData.get("missingValue", "default for missing value")
               ==
               "default for missing value");
        assert(severalData.get("data1", "default for missing value")
               ==
               "Español",
               "'severalData.data1' == " ~ severalData.get("data1", ""));
    }

    cfg.addSource(config_file);
    cfg.addSource(DFLT_CONFIG);

    // Missing configuration file
    doTest();

    scope(exit)
        removeIfExists(config_file);

    write(config_file, `stringConf "stringValue"`);
    cfg.reload();

    // Missing subconfig in configuration file
    doTest();

}

// Source order test
unittest
{
    auto cfg = new Config();
    cfg.addSource(`
                    stringConf "userValue"`);
    cfg.addSource(`
                    stringConf "adminValue"`);
    string stringConf = cfg.getValue("stringConf", "not set");
    assert(stringConf == "userValue", "stringConf is " ~ stringConf);
}

