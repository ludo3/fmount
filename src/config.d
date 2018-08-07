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

import std.container.dlist : DList;
import std.container.util : make;
import std.file : exists, FileException, readText, write;
import std.range : InputRange;
import std.regex : matchFirst, regex, Regex;
import std.stdio : writeln;
import std.string : format, splitLines;

import argsutil : fake, verbose;
import constvals : confdir_name, VbLevel;
import dutil : printThChain;
import osutil : chown, get_dir, getRealUserAndGroup, jn;


/// One line of a configuration file.
class Line
{
    /// Construct one empty first line.
    this()
    {
        this(0, "");
    }

    /// Construct one line with its content.
    this(size_t num, string content)
    {
        _num = num;
        _content = content;
    }

    /// Release references to any data.
    ~this()
    {
        _content = null;
    }

    /**
     * Retrieve the line number.
     */
    size_t getNum()
    {
        return _num;
    }

    /**
     * Retrieve the line content.
     */
    string getContent()
    {
        return _content;
    }

    private:
        /// The line number.
        size_t _num;

        /// The line content, without any trailing newline character (sequence).
        string _content;
}


/// A configuration key-value pair.
class KeyValue : Line
{
    /// Default constructor.
    this()
    {
        this("", "");
    }

    /// Constructor with key and value only.
    this(string key, string value)
    {
        super();
        initThis(key, value);
    }

    /// Constructor with full content.
    this(size_t num, string line, string key, string value)
    {
        super(num, line);
        initThis(key, value);
    }

    /// Destructor.
    ~this()
    {
        _value = null;
        _key = null;    }

    /**
     * Retrieve the key.
     */
    string getKey()
    {
        return _key;
    }

    /**
     * Replace the key.
     */
    void setKey(string key)
    {
        _key = key;
    }

    /**
     * Retrieve the value.
     */
    string getValue()
    {
        return _value;
    }

    /**
     * Replace the value.
     */
    void setValue(string value)
    {
        _value = value;
    }

    /**
     * Update a typed value from the configuration.
     */
    void readTypedValue(T)(ref T v)
    {
        v = cast(T)(getValue());
    }

    /**
     * Update the configuration from a typed value.
     */
    void writeTypedValue(T)(T v)
    {
        setValue(v);
    }

    private:

        /// Initialize the key and value.
        void initThis(string key, string value)
        {
            this._key = key;
            this._value = value;
        }

        /// The key of the key-value pair.
        string _key;

        /// The value of the key-value pair.
        string _value;
}


/**
 * A configuration section.
 *
 * Note: the first configuration part without section name is contained within
 * an unnamed section.
 */
class Section : Line
{
    /// Constructor for the first configuration part.
    this()
    {
        super();
        initThis("");
    }

    /// Constructor for a named section.
    this(size_t num, string line, string name)
    {
        super(num, line);
        initThis(_name);
    }

    ~this()
    {
        destroy(_lines);
        _name = null;
    }

    /**
     * Retrieve the section name, or an empty string for the first
     * configuration part.
     */
    string getName()
    {
        return _name;
    }

    /**
     * Replace the section name.
     */
    void setName(string name)
    {
        _name = name;
    }

    /**
     * Retrieve the content.
     */
     ref DList!Line getLines()
     {
        return _lines;
     }

    /**
     * Add a line to the section.
     */
    void addLine(Line line)
    {
        _lines ~= line;
    }

    private:
        void initThis(string name)
        {
            _name = name;
            _lines = make!(DList!Line);
        }

        string _name;

        DList!Line _lines;
}


class Comment : Line
{
    /// Constructor for an empty comment.
    this()
    {
        this(0, "#");
    }

    /// Constructor.
    this(size_t num, string content)
    {
        super(num, content);
    }
}


/**
 * Define the interface for configuration sources : file, content.
 */
interface ConfigSource
{
    /**
     * Retrieve the source name or an empty string when a name is not
     * available.
     */
    string getName();

    /**
     * Retrieve the lines containing the configuration.
     */
    string[] readlines();
}


/**
 * A string containing the configuration.
 */
class StringSource : ConfigSource
{
    /// Constructor.
    this(string content)
    {
        _lines = splitLines(content);
    }

    /// Destructor.
    ~this()
    {
        _lines = null;
    }

    /**
     * Retrieve the source name or an empty string when a name is not
     * available.
     */
    string getName()
    {
        return "";
    }

    /**
     * Retrieve the lines containing the configuration.
     */
    string[] readlines()
    {
        return _lines[];
    }

    private string[] _lines;
}


/**
 * A file containing the configuration.
 */
class FileSource : ConfigSource
{
    /// Constructor.
    this(string name)
    {
        _name = name;
    }

    /// Destructor.
    ~this()
    {
        _name = null;
    }

    /**
     * Retrieve the source name or an empty string when a name is not
     * available.
     */
    string getName()
    {
        return _name;
    }

    /**
     * Retrieve the lines containing the configuration.
     */
    string[] readlines()
    {
        string content = readText(_name);
        return splitLines(content);
    }

    private string _name;
}


private static immutable Regex!char RX_BLANK = regex(`^\s*$`);
private static immutable Regex!char RX_COMMENT = regex(`^\s*#.*$`);

private static immutable Regex!char RX_KV
    = regex(`^\s*(?P<key>\w+)\s*=\s*(?P<value>\S+(?:.*\S))\s*$`);

private static immutable Regex!char RX_SECTION
    = regex(`^\s*\[\s*(?P<name>\w+)\s*\].*$`);


/// The readable/writable configuration.
class Config
{
    /// Constructor.
    this()
    {
    }

    /**
     * Read a configuration contained in memory.
     */
    void readString(string content)
    {
        readSource(new StringSource(content));
    }

    /**
     * Read a configuration contained in a file.
     */
    void readFile(string path)
    {
        readSource(new FileSource(path));
    }

    /**
     * Read a configuration from a custom source.
     */
    void readSource(ConfigSource source)
    {
        clear();
        initThis();

        int lineNum;
        foreach (ref string s; source.readlines())
        {
            parseLine(++lineNum, s);
        }
    }

    /// Retrieve the main (unnamed) section.
    ref Section getMainSection()
    {
        return _mainSection;
    }

    /// Check whether a named section exists.
    bool hasSection(string name) const
    {
        return (name in _namedSections) != null;
    }

    /// Retrieve a named section.
    ref Section getSection(string name)
    {
        return _namedSections[name];
    }

    /// Resets the configuration.
    void clear()
    {
        foreach (Section s; _namedSections.values)
            destroy(s);

        destroy(_mainSection);
        _currentSection = null;
    }

    /// Initialize an empty configuration.
    void initEmpty()
    {
        initThis();
    }

    private:
        void initThis()
        {
            _mainSection = new Section();
            _namedSections.clear();
            _currentSection = _mainSection;
        }

        /**
         * Parse a configuration line as a comment, a section header or a
         * key-value pair.
         *
         * Params:
         *     num     = The one-based line number.
         *     content = The line content, without any trailing newline.
         */
        void parseLine(size_t num, string content)
        {
            const auto bkM = matchFirst(content, RX_BLANK);
            Line line;
            if (!bkM.empty)
                line = new Line(num, content);
            else
            {
                const auto comM = matchFirst(content, RX_COMMENT);
                if (!comM.empty)
                    line = new Comment(num, content);
                else
                {
                    auto kvM = matchFirst(content, RX_KV);
                    if (!kvM.empty)
                    {
                        string k = kvM["key"];
                        string v = kvM["value"];
                        line = new KeyValue(num, content, k, v);
                    }
                    else
                    {
                        auto secM = matchFirst(content, RX_SECTION);
                        if (!secM.empty)
                        {
                            string name = secM["name"];
                            line = new Section(num, content, name);
                        }
                        else
                            throw new ConfigException(num, content);
                    }
                }
            }

            assert(line !is null);
            assert(_currentSection !is null);
            _currentSection.addLine(line);
        }

        Section _mainSection;
        Section[string] _namedSections;
        Section _currentSection;
}


/// The exception raised when an error is found in a configuration file.
class ConfigException : Exception
{
    enum ErrFmt = "Configuration error at line %d : '%s'.";
    this(size_t lineNum, string wrongLine)
    {
        super(format(ErrFmt, lineNum, wrongLine));
        _lineNum = lineNum;
        _wrongLine = wrongLine;
    }

    /// Retrieve the line number in the configuration file.
    @property
    size_t lineNum() const { return _lineNum; }

    /// Retrieve the line with bad content in the configuration file.
    @property
    string wrongLine() const { return _wrongLine; }

    private:
        size_t _lineNum;
        string _wrongLine;
}


/// Create the configuration directory if needed, and return its path.
string get_confdir()
{
    return get_dir(jn("~", confdir_name));
}


/**
 * Retrieve a configuration or create a default one.
 * Params:
 *     filename        = The name of the configuration file.
 *     defaultContent = The default configuration content, to be used if the
 *                       configuration file does not exist yet.
 *
 */
Config get_config(string filename, string defaultContent)
{
    string config_file = jn(get_confdir(), filename);
    Config config;

    if (exists(config_file))
    {
        if (verbose >= VbLevel.More)
            writeln("get_config from ", config_file);
        try
        {
            config.readFile(config_file);
        }
        catch(ConfigException cfx)
        {
            if (verbose >= VbLevel.Warn)
                writeln(cfx.toString());
            if (verbose >= VbLevel.More)
                printThChain(cfx);
        }
        catch(FileException fex)
        {
            if (verbose >= VbLevel.Warn)
            {
                immutable string _s = "Could not read config '%s' : %s";
                writeln(format!_s(config_file, fex.toString()));
                if (verbose >= VbLevel.More)
                    printThChain(fex);
            }
        }
    }
    else if (defaultContent !is null && defaultContent.length > 0)
    {
        config.readString(defaultContent);
        if (!fake)
        {
            try
            {
                write(config_file, defaultContent);
                chown(getRealUserAndGroup(), config_file);
            }
            catch(Exception ex)
            {
                if (verbose >= VbLevel.Warn)
                {
                    immutable string _s = "Could not write config '%s' : %s";
                    writeln(format!_s(config_file, ex.toString()));
                    if (verbose >= VbLevel.More)
                        printThChain(ex);
                }
            }
        }
    }

    return config;
}



