// Written in the D programming language.

/**
Dlang application logging.

Copyright: Copyright Ludovic Dordet 2018.
License:   $(HTTP www.gnu.org/licenses/gpl-3.0.md,
             GNU GENERAL PUBLIC LICENSE 3.0).
Authors:   Ludovic Dordet

Macros:
 LINE=$(TR $(TD $1))$(LINE $+)
 LINES=$(TABLE $1 $(LINE $+))
 C099=$(B $1, ($(GREEN C99)))
 C99=$(LINES $(B $1), ($(GREEN C99)))
*/
/*
         Copyright Ludovic Dordet 2018.
Distributed under the GNU GENERAL PUBLIC LICENSE, Version 3.0.
   (See accompanying file LICENSE.md or copy at
         http://www.gnu.org/licenses/gpl-3.0.md)
*/
module logging;
import std.array : array, join;
import std.conv : to;
import std.datetime.date : Date, DateTime, TimeOfDay;
import std.datetime.systime : SysTime;
import std.experimental.logger : CreateFolder, FileLogger, Logger, LogLevel,
                                 MultiLogger;
import std.format : format;
import std.range.primitives : ElementType, hasLength;
import std.stdio : File, LockingTextReader, stderr, writeln;
import std.traits: EnumMembers, hasMember,
                   isAssignable, isOrderingComparable, isSomeString;

import argsutil : VbLevel, verbose;
import dateutil : approxNow;
import dutil: /+mkGlob,+/ RW, srcinfo, SrcInfo, unused;
import core.stdc.stdlib : exit;

/**
   Retrieve the name of the log file.
   For stdout and stderr, `stdout` and `stderr` are returned respectively.
*/
private string getNameFromFile(File f)
{
    import std.stdio : stderr, stdout;

    static foreach(stdname; [ "stdout", "stderr" ])
    {
        mixin(q{
          if (f.fileno == %1$s.fileno)
            return "%1$s";
        }.format(stdname));
    }

    return f.name;
}


/**
 * The `FormattedFileLogger` lets define a format for the logging context.
 *
 * The formatting specification is as follows:
 * $(UL
 *     $(LI $(B %s) The log message)
 *     $(LI $(B %f) `__FILE__`)
 *     $(LI $(B %m) `__MODULE__`)
 *     $(LI $(B %l) `__LINE__`)
 *     $(LI $(B %F) `__FUNCTION__`)
 *     $(LI $(B %p) `__PRETTY_FUNCTION__`)
 *     $(LI $(B %n) $(I $(B timestamp)))
 *     $(LI $(B %d) $(I $(B date)))
 *     $(LI $(B %t) $(I $(B time)))
 * )
 *
 * Usual $(I $(B timestamp), $(B date) and $(B time)) formats:
 * $(TABLE
 * $(TR $(TH Field) $(TH Format name) $(TH Description) $(TH Custom format))
 * $(TR $(TD Timestamp) $(TD SimpleString) $(TD YYYY-Mon-DD HH:MM:SS)
 *                                         $(TD `%Y-%b-%d %T`))
 * $(TR $(TD Timestamp) $(TD ISOString) $(TD YYYYMMDDTHHMMSS)
 *                                      $(TD `%Y%m%dT%H%M%S`))
 * $(TR $(TD Timestamp) $(TD ISOExtString) $(TD YYYY-MM-DDTHH:MM:SS)
 *                                      $(TD `%Y-%m-%dT%T`))
 * $(TR $(TD Timestamp) $(TD SimpleString) $(TD YYYY-Mon-DD HH:MM:SS)
 *                                         $(TD `%Y-%b-%d %T`))
 * $(TR $(TD Date) $(TD ISOString) $(TD YYYYMMDD) $(TD `%Y%m%d`))
 * $(TR $(TD Date) $(TD ISOExtString) $(TD YYYY-MM-DD) $(TD `%Y-%m-%d`))
 * $(TR $(TD Date) $(TD SimpleString) $(TD YYYY-Mon-DD) $(TD `%Y-%b-%d`))
 * $(TR $(TD Time) $(TD ISOString) $(TD HHMMSS) $(TD `%H%M%S`))
 * $(TR $(TD Time) $(TD ISOExtString) $(TD HH:MM:SS) $(TD `%T`))
 * )
 *
 * Other $(I $(B timestamp), $(B date) and $(B time)) formats are transmitted to
 * the `strftime` C function.
 *
 * $(TABLE
 * $(TR $(TH)
        $(TH From $(LINK https://en.cppreference.com/w/c/chrono/strftime))
        $(TH))
 * $(TR $(TH Conversion Specifier) $(TH Explanation) $(TH Used fields))
 * $(TR $(TD $(B %)) $(TD writes literal `%`. The full conversion specification
     must be `%%`.) $(TD))
 * $(TR $(TD $(C99 n)) $(TD writes newline character) $(TD))
 * $(TR $(TD $(C99 t))
        $(TD writes horizontal tab character) $(TD))
 * $(TR $(TD $(B Y))
        $(TD writes $(B year) as a decimal number, e.g. 2017)
        $(TD $(B tm_year)))
 * $(TR $(TD $(C99 EY))
        $(TD writes $(B year) in the alternative representation, e.g.平成23年
             (year Heisei 23) instead of 2011年 (year 2011) in ja_JP locale)
        $(TD $(B tm_year)))
 * $(TR $(TD $(B y))
        $(TD writes last 2 digits of $(B year) as a decimal number
             (range [00,99])) $(TD $(B tm_year)))
 * $(TR $(TD $(C99 Oy))
        $(TD writes last 2 digits of $(B year) using the
             alternative numeric system, e.g. 十一 instead of 11 in ja_JP
             locale)
        $(TD $(B tm_year)))
 * $(TR $(TD $(C99 Ey))
        $(TD writes $(B year) as offset from locale's alternative calendar
             period %EC (locale-dependent))
        $(TD $(B tm_year)))
 * $(TR $(TD $(C99 C))
        $(TD writes first 2 digits of $(B year) as a decimal
             number (range [00,99]))
        $(TD $(B tm_year)))
 * $(TR $(TD $(C99 EC))
        $(TD writes name of the base year (period) in the
             locale's alternative representation, e.g. 平成 (Heisei era) in
             ja_JP)
        $(TD $(B tm_year)))
 * $(TR $(TD $(C99 G))
        $(TD writes $(B ISO 8601 week-based year), i.e. the year that contains
             the specified week.

             In IS0 8601 weeks begin with Monday and the first week of the year
             must satisfy the following requirements:
             $(UL
                 $(LI Includes January 4)
                 $(LI Includes first Thursday of the year)
             ))
        $(TD $(B tm_year, tm_wday, tm_yday)))
 * $(TR $(TD $(C99 g))
        $(TD writes last 2 digits of $(B ISO 8601 week-based year), i.e. the
             year that contains the specified week (range [00,99]).

             In IS0 8601 weeks begin with Monday and the first week of the year
             must satisfy the following requirements:
             $(UL
                 $(LI Includes January 4)
                 $(LI Includes first Thursday of the year)
             ))
        $(TD $(B tm_year, tm_wday, tm_yday)))
 * $(TR $(TD $(B b))
        $(TD writes $(B abbreviated month) name, e.g. Oct (locale dependent))
        $(TD $(B tm_mon)))
 * $(TR $(TD $(C99 h)) $(TD synonym of b) $(TD $(B tm_mon)))
 * $(TR $(TD $(B B))
        $(TD writes $(B full month) name, e.g. October (locale dependent))
        $(TD $(B tm_mon)))
 * $(TR $(TD $(B m))
        $(TD writes $(B month) as a decimal number (range [01,12]))
        $(TD $(B tm_mon)))
 * $(TR $(TD $(C99 Om))
        $(TD writes month using the alternative numeric system, e.g. 十二
             instead of 12 in ja_JP locale)
        $(TD $(B tm_mon)))
 * $(TR $(TD $(B U))
        $(TD writes $(B week of the year) as a decimal number (Sunday is the
             first day of the week) (range [00,53]))
        $(TD $(B tm_year, tm_wday, tm_yday)))
 * $(TR $(TD $(C99 OU))
        $(TD writes $(B week of the year), as by %U, using the alternative
             numeric system, e.g. 五十二 instead of 52 in ja_JP locale)
        $(TD $(B tm_year, tm_wday, tm_yday)))
 * $(TR $(TD $(B W))
        $(TD writes $(B week of the year) as a decimal number (Monday is the
             first day of the week) (range [00,53]))
        $(TD $(B tm_year, tm_wday, tm_yday)))
 * $(TR $(TD $(C99 OW))
        $(TD writes week of the year, as by %W, using the alternative numeric
             system, e.g. 五十二 instead of 52 in ja_JP locale)
        $(TD $(B tm_year, tm_wday, tm_yday)))
 * $(TR $(TD $(C99 V))
        $(TD writes $(B ISO 8601 week of the year) (range [01,53]).

             In IS0 8601 weeks begin with Monday and the first week of the year
             must satisfy the following requirements:
             $(UL
                 $(LI Includes January 4)
                 $(LI Includes first Thursday of the year)
             ))
        $(TD $(B tm_year, tm_wday, tm_yday)))
 * $(TR $(TD $(C99 OV))
        $(TD writes $(B week of the year), as by %V, using the alternative
             numeric system, e.g. 五十二 instead of 52 in ja_JP locale)
        $(TD $(B tm_year, tm_wday, tm_yday)))
 * $(TR $(TD $(B j))
        $(TD writes $(B day of the year) as a decimal number (range [001,366]))
        $(TD $(B tm_yday)))
 * $(TR $(TD $(B d))
        $(TD writes $(B day of the month) as a decimal number (range [01,31]))
        $(TD $(B tm_mday)))
 * $(TR $(TD $(C99 Od))
        $(TD writes zero-based $(B day of the month) using the alternative
             numeric system, e.g 二十七 instead of 23 in ja_JP locale

             Single character is preceded by a space.) $(TD $(B tm_mday)))
 * $(TR $(TD $(C99 e))
        $(TD writes day of the month as a decimal number (range [1,31]).

             Single digit is preceded by a space.) $(TD $(B tm_mday)))
 * $(TR $(TD $(C99 Oe))
        $(TD writes one-based day of the month using the alternative numeric
             system, e.g. 二十七 instead of 27 in ja_JP locale

             Single character is preceded by a space. ) $(TD $(B tm_mday)))
 * $(TR $(TD $(B a))
        $(TD writes $(B abbreviated weekday) name, e.g. Fri (locale dependent))
        $(TD $(B tm_wday)))
 * $(TR $(TD $(B A))
        $(TD writes $(B full weekday) name, e.g. Friday (locale dependent))
        $(TD $(B tm_wday)))
 * $(TR $(TD $(B w))
        $(TD writes $(B weekday) as a decimal number, where Sunday is 0 (range [0-6]))
        $(TD $(B tm_wday)))
 * $(TR $(TD $(C99 Ow))
        $(TD writes $(B weekday), where Sunday is 0, using the alternative
             numeric system, e.g. 二 instead of 2 in ja_JP locale)
        $(TD $(B tm_wday)))
 * $(TR $(TD $(C99 u) )
        $(TD writes $(B weekday) as a decimal number, where Monday is 1
             (ISO 8601 format) (range [1-7]))
        $(TD $(B tm_wday)))
 * $(TR $(TD $(C99 Ou))
        $(TD writes $(B weekday), where Monday is 1, using the alternative
             numeric system, e.g. 二 instead of 2 in ja_JP locale)
        $(TD $(B tm_wday)))
 * $(TR $(TD $(B H))
        $(TD writes $(B hour) as a decimal number, 24 hour clock
             (range [00-23]))
        $(TD $(B tm_hour)))
 * $(TR $(TD $(C99 OH))
        $(TD writes $(B hour) from 24-hour clock using the alternative numeric
             system, e.g. 十八 instead of 18 in ja_JP locale)
        $(TD $(B tm_hour)))
 * $(TR $(TD $(B I))
        $(TD writes $(B hour) as a decimal number, 12 hour clock
             (range [01,12]))
        $(TD $(B tm_hour)))
 * $(TR $(TD $(C99 OI))
        $(TD writes $(B hour) from 12-hour clock using the alternative numeric
             system, e.g. 六 instead of 06 in ja_JP locale)
        $(TD $(B tm_hour)))
 * $(TR $(TD $(B M))
        $(TD writes $(B minute) as a decimal number (range [00,59]))
        $(TD $(B tm_min)))
 * $(TR $(TD $(B OM))
        $(TD writes $(B minute) using the alternative numeric system, e.g.
             二十五 instead of 25 in ja_JP locale)
        $(TD $(B tm_min)))
 * $(TR $(TD $(B S))
        $(TD writes $(B second) as a decimal number (range [00,60]))
        $(TD $(B tm_sec)))
 * $(TR $(TD $(C99 OS))
        $(TD writes $(B second) using the alternative numeric system, e.g.
             二十四 instead of 24 in ja_JP locale)
        $(TD $(B tm_sec)))
 * $(TR $(TD $(B c))
        $(TD writes $(B standard date and time) string, e.g.
             Sun Oct 17 04:41:13 2010 (locale dependent))
        $(TD all))
 * $(TR $(TD $(C99 Ec))
        $(TD writes $(B alternative date and time) string, e.g. using 平成23年
             (year Heisei 23) instead of 2011年 (year 2011) in ja_JP locale)
        $(TD all))
 * $(TR $(TD $(B x))
        $(TD writes $(B localized date representation) (locale dependent))
        $(TD all))
 * $(TR $(TD $(C99 Ex))
        $(TD writes $(B alternative date representation), e.g. using 平成23年
             (year Heisei 23) instead of 2011年 (year 2011) in ja_JP locale)
        $(TD all))
 * $(TR $(TD $(B X))
        $(TD writes localized $(B time representation) (locale dependent))
        $(TD all))
 * $(TR $(TD $(C99 EX))
        $(TD writes $(B alternative time representation) (locale dependent))
        $(TD all))
 * $(TR $(TD $(C99 D))
        $(TD equivalent to $(B "%m/%d/%y"))
        $(TD $(B tm_mon, tm_mday, tm_year)))
 * $(TR $(TD $(C99 F))
        $(TD equivalent to $(B "%Y-%m-%d" (the ISO 8601 date format)))
        $(TD $(B tm_mon, tm_mday, tm_year)))
 * $(TR $(TD $(C99 r))
        $(TD writes localized $(B 12-hour clock) time (locale dependent))
        $(TD $(B tm_hour, tm_min, tm_sec)))
 * $(TR $(TD $(C99 R))
        $(TD equivalent to $(B "%H:%M"))
        $(TD $(B tm_hour, tm_min)))
 * $(TR $(TD $(C99 T))
        $(TD equivalent to $(B "%H:%M:%S") (the ISO 8601 time format))
        $(TD $(B tm_hour, tm_min, tm_sec)))
 * $(TR $(TD $(B p))
        $(TD writes localized $(B a.m. or p.m.) (locale dependent))
        $(TD $(B tm_hour)))
 * $(TR $(TD $(C99 z))
        $(TD writes $(B offset from UTC) in the ISO 8601 format (e.g. -0430),
             or no characters if the time zone information is not available)
        $(TD $(B tm_isdst)))
 * $(TR $(TD $(B Z))
        $(TD writes locale-dependent $(B time zone name or abbreviation), or no
             characters if the time zone information is not available)
        $(TD $(B tm_isdst)))
 * )
 */
class FormattedFileLogger : FileLogger
{
    import std.concurrency : Tid;

    /// The default open mode for files is "create or append".
    enum string OPEN_MODE = "a+";

    /// The default format for log messages.
    enum string DFLT_LOG_FORMAT = "@%f(%l) %n : %s";

    /// The default format for timestamps, i.e. date+time.
    enum string DFLT_TIMESTAMP_FORMAT = "%Y-%m-%dT%T";

    /// The default format for dates without time.
    enum string DFLT_DATE_FORMAT = "%Y-%m-%d";

    /// The default format for times without date.
    enum string DFLT_TIME_FORMAT = "%T";

    private alias Entry = Logger.LogEntry;

    private string _fileName;
    private string _logFormat;
    private string _beginLogFormat;
    private string _endLogFormat;
    private string _dateFormat;
    private string _timeFormat;
    private string _timestampFormat;

    /**
       A constructor for the `FormattedFileLogger` Logger.

    Params:
      fn = The file used for logging.
      lv = The `LogLevel` for the `FileLogger`. By default the
      `LogLevel` for `FileLogger` is `LogLevel.all`.
      createFileNameFolder = if yes (the default) and fn contains a folder name,
      this folder will be created recursively.

    Example:
    -------------
    auto file = File("logFile.log", "w");
    auto l1 = new FileLogger(file);
    auto l2 = new FileLogger("logFile.log", LogLevel.fatal, CreateFolder.no);
    -------------
    */
    @safe this(in string fn,
               const LogLevel lv = LogLevel.all,
               CreateFolder createFileNameFolder = CreateFolder.yes)
    {
        import std.file : mkdirRecurse;
        import std.path : dirName;

        if (createFileNameFolder)
        {
            auto d = dirName(fn);
            mkdirRecurse(d);
        }
        this(File(fn, OPEN_MODE), lv);
    }

    /**
       A constructor for the `FileLogger` Logger that takes a reference to
    a `File`.

    The `File` passed must be open for all the log call to the
    `FileLogger`. If the `File` gets closed, using the `FileLogger`
    for logging will result in undefined behaviour.

    Params:
      fn = The file used for logging.
      lv = The `LogLevel` for the `FileLogger`. By default the
      `LogLevel` for `FileLogger` is `LogLevel.all`.
      createFileNameFolder = if yes and fn contains a folder name, this
      folder will be created.

    Example:
    -------------
    auto file = File("logFile.log", "w");
    auto l1 = new FileLogger(file);
    auto l2 = new FileLogger(file, LogLevel.fatal);
    -------------
    */
    @trusted this(File file, const LogLevel lv = LogLevel.all)
    {
        _fileName = getNameFromFile(file);

        super(file, lv);

        logFormat = DFLT_LOG_FORMAT;
        dateFormat = DFLT_DATE_FORMAT;
        timeFormat = DFLT_TIME_FORMAT;
        timestampFormat = DFLT_TIMESTAMP_FORMAT;

        _initSrcProps;
    }

    /// Describe the log writer.
    override string toString() const @safe
    {
        import std.array : appender;

        auto app = appender!string();
        app.put("FormattedFileLogger[");
        app.put(to!string(fileName));
        app.put(' ');
        app.put(logLevel);
        app.put("]");

        return app.data;
    }

    /**
       Retrieve the name of the log file.
       For stdout and stderr, `stdout` and `stderr` are returned respectively.
    */
    @property string fileName() const @safe { return _fileName; }

    /// The format for log context and message.
    @property string logFormat() @safe pure { return _logFormat.dup; }

    /// Replace the format for log context and message.
    @property void logFormat(string s) @safe pure
    {
        import std.algorithm.searching : findSplit;

        _logFormat = s.dup;
        auto parts = _logFormat.findSplit(getMsgSpec!string());
        _beginLogFormat = parts[0];
        _endLogFormat = parts[2];
    }

    /// The format for dates without time.
    @property  string dateFormat() @safe pure { return _dateFormat.dup; }

    /// Replace the format for dates without time.
    @property void dateFormat(string s) @safe pure { _dateFormat = s.dup; }

    /// The format for times without dates.
    @property  string timeFormat() @safe pure { return _timeFormat.dup; }

    /// Replace the format for times without dates.
    @property void timeFormat(string s) @safe pure { _timeFormat = s.dup; }

    /// The format for timestamps, i.e. date+time.
    @property  string timestampFormat() @safe pure
    {
        return _timestampFormat.dup;
    }

    /// Replace the format for timestamps, i.e. date.time .
    @property void timestampFormat(string s) @safe pure
    {
        _timestampFormat = s.dup;
    }

    private enum DTSpecs : string
    {
        Date = "%d",
        Time = "%t",
        Timestamp = "%n"
    }

    /// Replace one of the date, time or timestamp formats.
    void setDateTimeFormat(string spec, string fmt) @safe pure
    {
        import dutil : dbg;

        with (DTSpecs)
        {
            switch(spec)
            {
                case Date:
                    dateFormat = fmt;
                    break;

                case Time:
                    timeFormat = fmt;
                    break;

                case Timestamp:
                    timestampFormat = fmt;
                    break;

                default:
                    break;
            }
        }
    }

    /**
       This method overrides the base class method in order to log to a file
       without requiring heap allocated memory.
     */
    override protected void beginLogMsg(string file, int line, string funcName,
        string prettyFuncName, string moduleName, LogLevel logLevel,
        Tid threadId, SysTime timestamp, Logger logger)
        @safe
    {
        import std.experimental.logger : Logger;

        header = Entry(file, line, funcName, prettyFuncName, moduleName,
                       logLevel, threadId, timestamp, null, this);
        formatContext(_beginLogFormat);
    }

    /**
       Finalize the active log call. This requires flushing the `File` and
       releasing the `FileLogger` local mutex.
     */
    override protected void finishLogMsg()
    {
        formatContext(_endLogFormat);
        file.lockingTextWriter().put("\n");
        file.flush();
    }


    private alias GetInfo = string delegate() @safe;
    private GetInfo[string] _srcProps;

    private void _initSrcProps() @safe
    {
        GetInfo[string] sp;

        sp["%%"] = &getEscape;

        sp["%f"] = &getSrcFile;
        sp["%m"] = &getSrcModuleName;
        sp["%l"] = &getSrcLine;
        sp["%F"] = &getSrcFuncName;
        sp["%p"] = &getSrcFuncDets;

        // Current date time information, not related to the source info
        sp[DTSpecs.Date] = &formatDate;
        sp[DTSpecs.Time] = &formatTime;
        sp[DTSpecs.Timestamp] = &formatTimestamp;

        // To be replaced by the template write function.
        sp["%s"] = &getMessageSpec;

        _srcProps = sp.dup;
    }

    private string getEscape() @safe
    {
        return "%";
    }

    private F getMsgSpec(F)() @safe
    if (isSomeString!F)
    {
        return to!F("%s");
    }

    private string getMessageSpec() @safe
    {
        return getMsgSpec!string();
    }

    private string getSrcFile() @safe
    {
        return header.file;
    }

    private string getSrcModuleName() @safe
    {
        return header.moduleName;
    }

    private string getSrcFuncName() @safe
    {
        return header.funcName;
    }

    private string getSrcFuncDets() @safe
    {
        return header.prettyFuncName;
    }

    private string getSrcLine() @safe
    {
        return to!string(header.line);
    }

    private string formatDate() @safe
    {
        import std.datetime : Date;
        import dateutil : formatTs;
        immutable ts = header.timestamp;
        return dateFormat.formatTs(Date(ts.year, ts.month, ts.day));
    }

    private string formatTime() @safe
    {
        import std.datetime : TimeOfDay;
        import dateutil : formatTs;
        immutable ts = header.timestamp;
        return timeFormat.formatTs(TimeOfDay(ts.hour, ts.minute, ts.second));
    }

    private string formatTimestamp() @safe
    {
        import dateutil : formatTs;
        return timestampFormat.formatTs(header.timestamp);
    }

    private string formatInfo(string spec)
    @trusted
    {
        try
        {
            return _srcProps[spec]();
        }
        catch(Exception ex)
        {
            stderr.writefln!"Unknown SrcInfo specification '%s'."(spec);
            return spec;
        }
    }

    private void formatContext(F)(ref F logFmtPart) @safe
    if (isSomeString!(typeof(logFmtPart)))
    {
        import std.algorithm.searching : findSplit;
        import std.array : replace;
        import std.range : appender;

        auto writer = file.lockingTextWriter();

        F remLogFormat = to!F(logFmtPart);
        immutable F specMark = to!F(getEscape());
        bool finished;

        do
        {
            immutable findRes = remLogFormat.findSplit(specMark);
            auto before = findRes[0];
            immutable match = findRes[1];
            auto after = findRes[2];

            finished = match.length == 0;
            remLogFormat = after;

            writer.put(before);
            if (!finished)
            {
                auto spec = specMark ~ after[0];
                writer.put(formatInfo(spec));
                remLogFormat = remLogFormat[1..$];
            }
        }
        while (!finished);
    }

    /+
    private F formatContext(F)(SrcInfo ctx, lazy F fmt) @safe
    if (isSomeString!(typeof(fmt)))
    {
        import std.algorithm.searching : findSplit;
        import std.array : replace;
        import std.range : appender;

        auto logMsg = appender!F();

        F remLogFormat = to!F(logFormat);
        immutable F specMark = to!F(getEscape(ctx));
        bool finished;

        do
        {
            immutable findRes = remLogFormat.findSplit(specMark);
            auto before = findRes[0];
            immutable match = findRes[1];
            auto after = findRes[2];

            finished = match.length == 0;
            remLogFormat = after;

            logMsg.put(before);
            if (!finished)
            {
                auto spec = specMark ~ after[0];
                logMsg.put(formatInfo(spec, ctx));
                remLogFormat = remLogFormat[1..$];
            }
        }
        while (!finished);

        return to!F(logMsg.data).replace(getMsgSpec!F(), fmt);
    }
    +/

    private @trusted void errln(F, Args...)(F fmt, Args args)
    {
        stderr.writefln(fmt, args);
    }

    /+
    /**
     * Write unconditionally a formatted logging information to the backend.
     *
     * Params:
     *   F                =  the format type.
     *   srcFile          =  the source file.
     *   line             =  the 1-based line number in the source file.
     *   func             =  the function name.
     *   prettyFunc       =  the full function name and parameters.
     *   modName          =  the module name of the source file.
     *   Args             =  the types for the optional arguments
     *   fmt              =  the message or its format
     *   args             =  the optional message arguments
     */
    void write(F, string srcFile=__FILE__,
               size_t line=__LINE__,
               string func=__FUNCTION__,
               string prettyFunc=__PRETTY_FUNCTION__,
               string modName=__MODULE__,
               Args...)
              (lazy F fmt, lazy Args args) @safe
    if (isSomeString!(typeof(fmt)))
    {
        write(srcinfo(srcFile, line, func, prettyFunc, modName), fmt, args);
    }

    /**
     * Flush each written file.
     *
     * This method should be called before any written data is retrieved.
     */
    void flush() @safe
    {
        if (file.isOpen)
            file.flush;

        if (_writers.length > 0)
        {
            foreach (w; _writers)
                w.flush;
        }
    }
    +/

    /**
     * Retrieve the file's content, if available, i.e. if opened in an append
     * mode.
     *
     * Params:
     *     nbLines = The number of last lines to retrieve. If zero, then the
     *     full content is retrieved.
     */
    string getContent(size_t nbLines=1)()
    {
        import fileutil : getText;

        if (file.isOpen)
            return file.getText!nbLines();
        else if (_logger.length > 0)
        {
            foreach(name; _logger.names)
            {
                Logger l = _logger[name];
                auto ffl = cast(FormattedFileLogger) l;

                if (ffl)
                    return ffl.getContent;
            }
        }

        return "";
    }

}

/// Instanciate a `FormattedFileLogger` with an opened file and minimum level.
FormattedFileLogger ffLogger(File file, LogLevel lv=LogLevel.all)
{
    return new FormattedFileLogger(file, lv);
}

/// Instanciate a `FormattedFileLogger` with an opened file and minimum level.
FormattedFileLogger ffLogger(string fileName,
                             LogLevel lv=LogLevel.all,
                             CreateFolder createFileNameFolder=CreateFolder.yes)
{
    return new FormattedFileLogger(fileName, lv, createFileNameFolder);
}


/**
   Let retrieve a logger from its registration name.
*/
class MLogger : MultiLogger
{
    /// Constructor.
    @safe this(const LogLevel lv = LogLevel.all)
    {
        super(lv);
    }

    /**
       Retrieve a logger which had been added with $(LREF
       std.experimental.logger.MultiLogger.insertLogger).

       Params:
           name = The name with which the logger was inserted.
    */
    @safe ref Logger opIndex(string name)
    {
        foreach (i; 0..logger.length)
        {
            if (name == logger[i].name)
                return logger[i].logger;
        }

        throw new Exception("No '" ~ name ~ "' logger.");
    }

    /**
       Retrieve a logger which had been added with $(LREF
       std.experimental.logger.MultiLogger.insertLogger).

       The result is typed as requested by the template name. If the result is
       not compatible, `null` is returned.

       Params:
           name = The name with which the logger was inserted.
     */
    @safe L named(L : Logger = FormattedFileLogger)(string name)
    {
        return cast(L)(opIndex(name));
    }

    /// Retrieve the number of registered loggers.
    @property size_t length() const { return logger.length; }

    /// Retrieve the name of registered loggers.
    @property string[] names() const
    {
        string[] res;

        foreach (i, registered; logger)
        {
            res ~= registered.name;
        }

        return res;
    }

    /// Check whether a name matches a registered logger.
    bool opBinaryRight(string op)(string name)
    if (op == "in")
    {
        foreach (i, registered; logger)
        {
            if (registered.name == name)
                return true;
        }

        return false;
    }

    /**
     * Retrieve the file's content, if available, i.e. if opened in an append
     * mode.
     */
    string getContent()
    {
        foreach (i, registered; logger)
        {
            auto ffl = cast(FormattedFileLogger) registered.logger;

            if (ffl)
                return ffl.getContent;
        }

        return "";
    }
}

/// Instanciate a multi logger.
MLogger mLogger(const LogLevel lv=LogLevel.all)
{
    return new MLogger(lv);
}

private MLogger _logger;

/**
 * Retrieve a named log writer.
 *
 * The name is usually either a standard name: `stderr`, `stdout`; or a file
 * path.
 */
public ref Logger logger(string name)
{
    return _logger[name];
}

/**
 * Register a logger. The name is automatically guessed from the log file.
 */
public void addLogger(FormattedFileLogger log)
{
    import std.format : format;
    import std.stdio : stdout;

    string name = getNameFromFile(log.file);
    if (name is null || name.length == 0)
    {
        // unnamed files, such as some temporary files.
        static immutable string tpl = "unnamed%03d";
        for (uint i; i < uint.max / 2; ++i)
        {
            name = format!tpl(i);
            if (!(name in _logger))
                break;
        }

        name = "TooManyNamedLoggers";
    }

    version(unittest)
        stderr.writeln(srcinfo, " addLogger named " ~ name);

    _logger.insertLogger(name, log);
}

// FIXME initialize and use a global variable instead
/// The (should be global) (default) multi logger.
ref MLogger logger()
{
    return _logger;
}


/// Module destructor for named `FormattedFileLogger` instances.
static this()
{
    _logger = mLogger();
    assert(_logger.length == 0);
    initLogging();
    assert(_logger.length >= 1);
}

/**
   Module destructor for named `FormattedFileLogger` and default
   `FormattedFileLogger`instances.
 */
static ~this()
{
    cleanupLogging();
    assert(_logger.length == 0);
}


/**
 * Initialize the logging module with the default stderr writer.
 *
 * An `initLogging` function must be called before any logging is done.
 */
void initLogging()
{
    static bool initialized;
    if (!initialized)
    {
        addLogger(ffLogger(stderr));
        initialized = true;
    }
}

/**
 * Release any registered log writer.
 *
 * This method should be called upon program termination, but is systematically
 * called when the module destructors are called.
 */
void cleanupLogging()
{
    import std.array : array;

    immutable(string)[] names = array(_logger.names).idup;
    foreach (string name; names)
    {
        FormattedFileLogger log = _logger.named(name);
        immutable string sFile = to!string(log.file);

        _logger.removeLogger(name);
        destroy(log);
    }

    assert(_logger.length == 0);
}


/// AssociativeArray with struct data
unittest
{
    struct DataCont(T)
    {
        static size_t _nbDtorCalls;
        static @property size_t nbDtorCalls() { return _nbDtorCalls; }

        ~this() { ++_nbDtorCalls; }

        private T _x;
        @property ref inout(T) x() inout { return _x; }

        @property void x(U=T)(auto ref U x_)
        if (isAssignable(T, U))
        { _x = _x; }

        string toString() const { return to!string(x); }
        alias x this;
    }
    auto dataCont(T)(auto ref inout(T) value) {
        return inout(DataCont!T)(value);
    }

    void cleanup(K, V)(V[K] aa)
    {
        foreach(k; aa.keys.idup)
        {
            destroy(aa[k]);
            aa.remove(k);
        }
    }

    /// test associative array with DataCont
    {
        string[] datarray;
        datarray ~= "stderr";
        datarray ~= "stdout";

        DataCont!string[string] dcByName;
        size_t dtors0 = (DataCont!string).nbDtorCalls;
        {
            foreach(s; datarray)
                dcByName[s] = dataCont(s);
            scope(exit) cleanup(dcByName);

            assert(dcByName.length == 2, "dcByName = " ~ to!string(dcByName));
            stderr.writeln(srcinfo, dcByName);
        }
        size_t dtors1 = (DataCont!string).nbDtorCalls;
        assert(dtors1 == dtors0 + 4, // for 2 DataCont, 2 copies.
               format("dtors0=%d dtors1=%d", dtors0, dtors1));
    }

}


/// unit tests for `FormattedFileLogger`
unittest
{
    import core.time : seconds;
    import std.file : deleteme;
    import std.stdio : stdout;

    import dutil : assertEqBySteps, assertEquals, bkv, sleep, srcln;
    import osutil : removeIfExists;


    void runFormattedFileLoggerTests()
    {
        // write some lines to stderr
        stderr.writeln(srcinfo, " DEBUG first call to Logger.logf.");
        logger.logf("LogWriter to stderr Int(%d) Float(%f)", 19, 1.8);

        // write some lines to stdout
        {
            auto stdout0 = bkv(stdout);
            unused(stdout0);
            stdout = File(deleteme ~ ".stdout.1", "a+");
            auto w = ffLogger(stdout);
            w.logf("LogWriter to stdout Int(%d) Float(%f)", 20, 1.9);
            stdout.flush;
            auto content = w.getContent;
            assertEqBySteps("w.getContent", content,
                            // expected
                            "@" ~ __FILE__ ~ "(" ~ to!string(__LINE__-5) ~ ") ",
                            approxNow(1.seconds, "%Y-%m-%dT%H:%M:%S"),
                            " : LogWriter to stdout Int(20) Float(1.900000)");
            removeIfExists(stdout.name);
        }
        assert(stdout.name is null, "stdout.name is '" ~ stdout.name
                                  ~ "' but should be null.");

        // test LogWriter(path)
        immutable path = deleteme ~ "LogWriter.out";
        scope(exit)
            removeIfExists(path);
        logger.log("LogWriter to '" ~ path ~ "' ...");
        {
            auto lg = ffLogger(path);
            lg.logf("LogWriter to "~path~" Int(%d) Float(%f)", 22, 1.6);
            auto content = lg.getContent;
            assertEqBySteps("w.getContent", content,
                            // expected
                            "@" ~ __FILE__ ~ "(" ~ to!string(__LINE__-4) ~ ") ",
                            approxNow(1.seconds, "%Y-%m-%dT%H:%M:%S"),
                            " : LogWriter to " ~path
                                ~ " Int(22) Float(1.600000)");
        }
        logger.log("... LogWriter to '" ~ path ~ "' done.");

        // test LogWriter(File)
        immutable path2 = path ~ "2";
        scope(exit)
            removeIfExists(path2);
        size_t line;
        {
            auto lg = ffLogger(File(path2, "w+"));
            lg.logf("LogWriter to "~path2~" Int(%d) Float(%f)", 23, 1.5);
            line = __LINE__ - 1;
        }
        {
            import std.file : readText;
            import std.format : _f=format;
            import std.string : strip;
            immutable content = readText(path2).strip;
            immutable inf0 = srcinfo.withLine(line);

            assertEqBySteps(_f!"'%s' content"(path2), content,
                            // expected
                            "@" ~ __FILE__ ~ "(" ~ inf0.sLine ~ ") ",
                            approxNow(1.seconds, "%Y-%m-%dT%H:%M:%S"),
                            " : LogWriter to " ~path2
                                ~ " Int(23) Float(1.500000)");
        }
    }

    runFormattedFileLoggerTests();
    stderr.writeln(srcinfo, " LogWriter tests finished.");
}


/// MLogger
unittest
{
    import core.time : seconds;

    import std.algorithm : map;
    import std.file : deleteme, readText;
    import std.format : _f=format;
    import std.range : iota;
    import std.string : strip;

    import dutil : assertEquals, assertEqBySteps, bkv, sleep, srcln;
    import osutil : removeIfExists;

    enum nameTpl = "LogWriter.%d.out";
    enum names = iota(1, 5).map!(a => format!nameTpl(a))();

    auto lg = mLogger();
    static foreach(name; names)
    {
        lg.insertLogger(name, ffLogger(deleteme ~ name));
        scope(exit)
            removeIfExists(deleteme ~ name);
    }

    lg.logf("%s(%d) formatted line.", "One", 1); immutable inf = srcinfo;
    //lg.flush;
    assertEqBySteps("lg.getContent", lg.getContent,
                    // expected
                    "@" ~ __FILE__ ~ "(" ~ inf.sLine ~ ") ",
                    approxNow(1.seconds, "%Y-%m-%dT%H:%M:%S"),
                    " : One(1) formatted line.");

    foreach(name; names)
    {
        immutable act = readText(deleteme ~ name).strip;
        assertEqBySteps(_f!"readText(%s)"(name), act,
                        // expected
                        "@" ~ __FILE__ ~ "(" ~ inf.sLine ~ ") ",
                        approxNow(1.seconds, "%Y-%m-%dT%H:%M:%S"),
                        " : One(1) formatted line.");
    }

}


/// Formatting
unittest
{
    import core.time : Duration, days, hours, minutes, seconds, msecs,
                       nsecs, usecs;

    import std.algorithm : map;
    import std.array : replace;
    import std.datetime.date : Date, DateTime, TimeOfDay;
    import std.datetime.systime : Clock, SysTime;
    import std.file : deleteme, readText;
    import std.format : _f=format;
    import std.range : iota;
    import std.string : strip;
    import std.traits : isTypeTuple;

    import dutil : assertEqBySteps, assertEquals, bkv, sleep,
                   srcinfo, SrcInfo, srcln, varArgs;
    import osutil : removeIfExists;

    enum name = "FormattedLogWriter.out";

    auto lg = ffLogger(deleteme ~ name);
    scope(exit)
        removeIfExists(deleteme ~ name);

    stderr.writeln(srcinfo, " logFormat tests started.");

    // Test default formats.
    assertEquals(lg.logFormat, "@%f(%l) %n : %s", "default logFormat");
    assertEquals(lg.dateFormat, "%Y-%m-%d", "default dateFormat");
    assertEquals(lg.timeFormat, "%T", "default timeFormat");
    assertEquals(lg.timestampFormat, "%Y-%m-%dT%T", "default timestampFormat");

    string aliasSeqString(Args...)(Args args)
    {
        import std.array : appender;
        auto buf = appender!string;

        buf ~= "AliasSeq[";

        foreach (i, v; args)
        {
            if (i >= 1)
                buf ~= ", ";
            buf ~= to!string(v);
        }

        buf ~= "]";

        return buf.data;
    }

    int testLogFormat_callCount;

    import dutil : from, isSrcLoc, SrcLoc, srcloc, strToTuple;
    void testLogFormat(L, ExpectedArgs, LogArgs...)
                      (ref FormattedFileLogger lg, L loc,
                       string logFmt, auto ref ExpectedArgs expArgs,
                       lazy string msgFmt, lazy LogArgs msgArgs)
    if (isTypeTuple!ExpectedArgs && isSrcLoc!L)
    {
        import core.exception : AssertError;
        import std.algorithm.comparison : min;

        import dateutil : isTimeType;
        import dutil : dbg;

        lg.logFormat = logFmt;
        lg.logf!(loc.LINE, loc.FILE, loc.FUNCTION, loc.SIGNATURE, loc.MODULE)
               (msgFmt, msgArgs);
        string content = lg.getContent;

        immutable si = loc.toSrcInfo;

        try
        {
            assertEqBySteps(si, "Log content", content, expArgs.expand);
        }
        catch(Throwable th)
        {
            dbg.ln("While testing logFormat '%s', dateFormat '%s', " ~
                   "timeFormat '%s', timestampFormat '%s':",
                   lg.logFormat,
                   lg.dateFormat,
                   lg.timeFormat,
                   lg.timestampFormat);
            throw th;
        }
    }

    with(FormattedFileLogger)
    {
        lg.timestampFormat = DFLT_TIMESTAMP_FORMAT;
        testLogFormat(lg, srcloc, DFLT_LOG_FORMAT,
                      varArgs("@", __FILE__, "(", __LINE__-1, ") ",
                              approxNow(1.seconds, "%Y-%m-%dT%H:%M:%S"),
                              " : One(1) formatted line."),
                      "%s(%d) formatted line.", "One", 1);

        lg.dateFormat = DFLT_DATE_FORMAT;
        testLogFormat(lg, srcloc, DFLT_LOG_FORMAT.replace("%n", "%d"),
                      varArgs("@", __FILE__, "(", __LINE__-1, ") ",
                              approxNow(1.seconds, "%Y-%m-%d"),
                              " : One(1) formatted line."),
                      "%s(%d) formatted line.", "One", 1);

        lg.timeFormat = DFLT_TIME_FORMAT;
        testLogFormat(lg, srcloc, DFLT_LOG_FORMAT.replace("%n", "%t"),
                      varArgs("@", __FILE__, "(", __LINE__-1, ") ",
                              approxNow(1.seconds, "%H:%M:%S"),
                              " : One(1) formatted line."),
                      "%s(%d) formatted line.", "One", 1);

        testLogFormat(lg, srcloc, "%s %f",
                      strToTuple!"%s %f"
                          (from!"%f"(__FILE__),
                           from!"%n"(approxNow(1.seconds, lg.timestampFormat)),
                           from!"%s"("One(1) again formatted line.")),
                      "%s(%d) again formatted line.", "One", 1);
    }

    enum string[] singleLogFormats =
        [ "%s", "%f", "%m", "%l", "%F", "%p", "%n", "%d", "%t"  ];

    import std.typecons : isTuple;
    bool atMostOnce(T, alias s)(auto ref T data)
    if (isSomeString!(typeof(s)) && isTuple!T)
    {
        import std.algorithm.searching : find;

        return (data[0] != s || data[1] != s);
    }

    enum string[] logFormats =
    {
        import std.array : join;
        import std.algorithm.iteration : filter;
        import std.algorithm.setops : cartesianProduct;
        import std.typecons : Tuple;

        return singleLogFormats.dup ~
            cartesianProduct(singleLogFormats,
                             singleLogFormats)
            .filter!(a => atMostOnce!(Tuple!(string, string), "%s")(a))
            .map!`[a.expand].join(" ")`
            .array;
    }();

    enum string[] genDateFormats =
    {
        import std.algorithm.setops : cartesianProduct;
        import std.algorithm.iteration : map;
        import std.array : array, join;

        enum /+string[] not implemented in CTFE, dmd v2.081.1 +/ Years =
            [ "%Y", "%G" ];

        enum /+ string[] not implemented in CTFE, dmd v2.081.1 +/ Months =
            [ "%B", "%m" ];

        enum /+ string[] not implemented in CTFE, dmd v2.081.1 +/ Weeks =
            [ "%W", "%V" ];

        enum /+ string[] not implemented in CTFE, dmd v2.081.1 +/ Days =
            [ "%j", "%d %A" ];

        /+
        enum /+ string[] not implemented in CTFE, dmd v2.081.1 +/ Years =
            [ "%Y", "%EY", "%G", "%C | %y", "%EC | %Ey", "%C | %Oy", "%g" ];

        enum /+ string[] not implemented in CTFE, dmd v2.081.1 +/ Months =
            [ "%b", "%h", "%B", "%m", "%Om" ];

        enum /+ string[] not implemented in CTFE, dmd v2.081.1 +/ Weeks =
            [ "%U", "OU", "%W", "%OW", "%V", "%OV" ];

        enum /+ string[] not implemented in CTFE, dmd v2.081.1 +/ Days =
            [ "%j", "%d", "%Od", "%e", "%Oe", "%a", "%A",
              "%w", "%Ow", "%u", "%Ou"
            ];
        +/

        return
            cartesianProduct(Years, Months, Days)
                .map!(a => [ a.expand ].join(","))
                .array
            ~
            cartesianProduct(Years, Weeks)
                .map!(a => [ a.expand ].join(","))
                .array;

    }();

    enum /+ string[] not implemented in CTFE, dmd v2.081.1 +/ DateFormats =
        ([ "ISOString", "ISOExtString", "SimpleString" ] ~
         [ "%x", "%F" ] ~
         genDateFormats).idup;

    enum /+ string[]  not implemented in CTFE, dmd v2.081.1 +/ genTimeFormats =
    {
        import std.algorithm.setops : cartesianProduct;
        import std.algorithm.iteration : map;
        import std.array : array, join;
        /+
        enum /+ string[] not implemented in CTFE, dmd v2.081.1 +/ Hours =
            [ "%H", "%OH", "%I %p", "%OI %p" ];
        +/
        enum /+ string[] not implemented in CTFE, dmd v2.081.1 +/ Hours =
            [ "%H:%M", "%I %p : %M" ];

        /+
        enum /+ string[] not implemented in CTFE, dmd v2.081.1 +/ minutes =
            [ "%M", "%OM" ];
        +/
        enum /+ string[] not implemented in CTFE, dmd v2.081.1 +/ Minutes = [];

        /+
        enum /+ string[] not implemented in CTFE, dmd v2.081.1 +/ seconds =
            [ "%S", "%OS" ];
        +/
        enum /+ string[] not implemented in CTFE, dmd v2.081.1 +/ Seconds = [];

        return
            /+
            cartesianProduct(Hours, Minutes)
                .map!(a => [ a.expand ].join(","))
                .array
            ~
            cartesianProduct(Hours, Minutes, Seconds)
                .map!(a => [ a.expand ].join(","))
                .array
            +/
            Hours;

    }();

    enum /+ string[]  not implemented in CTFE, dmd v2.081.1 +/ TimeFormats =
        ([ "ISOString", "ISOExtString" ] ~
         [ "[%X / %R]", "[%R / %T]" ] ~
         genTimeFormats).idup;

    enum /+ string[] not implemented in CTFE, dmd v2.081.1 +/
         genTimestampFormats =
    {
        import std.algorithm.setops : cartesianProduct;
        import std.algorithm.iteration : map;
        import std.array : array, join;

        string[] fmtsNoTz = cartesianProduct(DateFormats, TimeFormats)
                .map!(a => [ a.expand ].join(" at "))
                .array;

        version(none)
            return
                cartesianProduct(fmtsNoTz, [ "", "_%z", "_%Z" ])
                    .map!(a => [ a.expand ].join(""))
                    .array
                    .idup;
        else
            return fmtsNoTz.idup;
    }();

    enum /+ string[] not implemented in CTFE, dmd v2.081.1 +/ TimestampFormats =
        ([ "ISOString", "ISOExtString", "SimpleString" ] ~
         [ "%c", "%Ec" ] ~
         genTimestampFormats).idup;

    import std.algorithm.searching : canFind, findSplit;
    import std.array : array;
    import std.range : only;
    import std.string : indexOf;
    import std.typecons : tuple;

    import dateutil : approxNowTime, formatToday;
    import dutil : dbg, from, strToTuple;

    alias SpecAndFormat = typeof(tuple("", DateFormats));
    alias DTK = SpecAndFormat.Types[0];
    alias DTV = SpecAndFormat.Types[1];

    void testManyFmts(string logFmt)
                     (string[] logFmtSpecs,
                      DTV[DTK] dtFmtsBySpec)
    {
        foreach(dtSpec, formats; dtFmtsBySpec)
        {
            // Recursive call for each date/time/timestamp used in logFmt
            auto foundSpecs = logFmtSpecs.findSplit(only(dtSpec));

            if (foundSpecs[1].length > 0)
            {
                foreach(dtsFmt; formats)
                {
                    lg.setDateTimeFormat(dtSpec, dtsFmt);
                    DTV[DTK] dtFmtsBySpec1 = dtFmtsBySpec.dup;
                    dtFmtsBySpec1[dtSpec] = [dtsFmt];

                    testManyFmts!logFmt
                                (foundSpecs[0].array ~ foundSpecs[2].array,
                                 dtFmtsBySpec1);
                }
                return;
            }
        }

        immutable line = __LINE__ + 1;
        testLogFormat(lg, srcloc, logFmt,
                      strToTuple!logFmt
                          (from!"%f"(__FILE__),
                           from!"%l"(line),
                           from!"%m"( __MODULE__),
                           from!"%F"(__FUNCTION__),
                           from!"%p"(__PRETTY_FUNCTION__),
                           from!"%n"(approxNow(1.seconds, lg.timestampFormat)),
                           from!"%d"(formatToday(lg.dateFormat)),
                           from!"%t"(approxNowTime(1.seconds, lg.timeFormat)),
                           from!"%s"("One(1) new formatted line.")),
                      "%s(%d) new formatted line.", "One", 1);
    }

    string[] extractSpecs(string logFormat)
    {
        import std.array : appender;
        long pos;
        auto res = appender!(string[]);
        do
        {
            pos = logFormat.indexOf("%", pos);
            if ( pos >= 0L && pos < logFormat.length - 1L)
            {
                immutable long nxt = pos + 2L;
                res ~= logFormat[pos .. nxt];
                pos = nxt;
            }
        }
        while (pos >= 0L && pos < logFormat.length);

        return res.data.dup;
    }

    void testManyFormats(string logFmt, Args...)(Args specAndFormats)
    in
    {
        import std.traits : Unqual;
        import std.typecons : isTuple;
        alias SF = SpecAndFormat;
        static foreach(a, Arg; Args)
        {
            static assert(is(Arg : SF),
                          "Argument[" ~ to!string(a) ~ "] : " ~
                          Arg.stringof ~ " instead of " ~ SF.stringof);
        }
    }
    do
    {
        DTV[DTK] dtFmtsBySpec;
        foreach(i, sf; specAndFormats)
        {
            dtFmtsBySpec[sf[0]] = sf[1].dup;
        }

        testManyFmts!logFmt(extractSpecs(logFmt), dtFmtsBySpec);
    }

    static foreach(logFmt; logFormats)
    {
        testManyFormats!logFmt(tuple("%d", DateFormats),
                               tuple("%t", TimeFormats),
                               tuple("%n", TimestampFormats));
    }

    stderr.writeln(srcinfo, " logFormat tests finished.");
}

