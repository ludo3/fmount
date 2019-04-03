// Written in the D programming language.

/**
Dlang date and time related utilities.

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
module dutil.time;

import core.time : Duration, seconds;

import std.datetime.date : Date, DateTime, TimeOfDay;
import std.datetime.systime : SysTime;
import std.traits : isSomeString;


/// The default format for `DateTime`, `SysTime` and `TimeOfDay`.
enum string EXT_DATETIME_FMT = "ISOExtString";

/// The alternate and shorter format for `DateTime`, `SysTime` and `TimeOfDay`.
enum string ISO_DATETIME_FMT = "ISOString";

/// The D standard formats, from which date/time/timestamp objects can be built.
enum ISO_FORMATS : string
{
    /// The short ISO format, same as $(LREF ISO_DATETIME_FMT).
    Short = ISO_DATETIME_FMT,

    /// The long ISO format, same as $(LREF EXT_DATETIME_FMT).
    Long = EXT_DATETIME_FMT,
}

/// The default precision for `ApproxTime` related features.
enum Duration DFLT_PRECISION = 1.seconds;


/// Check whether a type has `hour`, `minute` and `second` symbols.
template isTimeType(TT)
{
    import std.traits : hasMember;

    enum isTimeType = hasMember!(TT, "hour")
        && hasMember!(TT, "minute")
        && hasMember!(TT, "second");
}


/// Check whether a type has `year`, `month` and `day` symbols.
template isDateType(TT)
{
    import std.traits : hasMember;

    enum isDateType = hasMember!(TT, "year")
        && hasMember!(TT, "month")
        && hasMember!(TT, "day");
}


/// Tests for `isDateType` and `isTimeType`.
unittest
{
    assert(!isTimeType!Date);
    assert(isTimeType!DateTime);
    assert(isTimeType!SysTime);
    assert(isTimeType!TimeOfDay);
}


/// Create a `SysTime` from a `SysTime` (identity function)
private SysTime toSysTime(const SysTime st) nothrow @safe @nogc { return st; }

/**
 * Create a `SysTime` from a `Date`.
 *
 * The local timezone is attached.
 */
private SysTime toSysTime(const Date date) nothrow @safe
{
    import std.datetime.timezone : LocalTime;
    return SysTime(date, LocalTime());
}

/**
 * Create a `SysTime` from a `DateTime`.
 *
 * The local timezone is attached.
 */
private SysTime toSysTime(const DateTime timestamp) nothrow @safe
{
    import std.datetime.timezone : LocalTime;
    return SysTime(timestamp, LocalTime());
}

/**
 * Create a `SysTime` from a `TimeOfDay`.
 *
 * The current day is implicitly included. The local timezone is attached.
 */
private SysTime toSysTime(const TimeOfDay time) nothrow @safe
{
    import core.time : Duration;
    import std.datetime.systime : Clock;
    import std.datetime.timezone : LocalTime;
    import std.exception : collectException;

    SysTime st;
    collectException(st = Clock.currTime());
    collectException(st.hour = time.hour);
    collectException(st.minute = time.minute);
    collectException(st.second = time.second);

    // No fractional seconds for a TimeOfDay.
    collectException(st.fracSecs = Duration.init);

    return st;
}


/// Convert a date and time value to a date.
Date toDate(T)(T dt)
if (isTimeType!T && isDateType!T)
{
    return Date(dt.year, dt.month, dt.day);
}

/// Convert a date and time value to a time.
TimeOfDay toTime(T)(T dt)
if (isTimeType!T && isDateType!T)
{
    return TimeOfDay(dt.hour, dt.minute, dt.second);
}


import core.time : nsecs, seconds;

/// Retrieve a formatted description of a date/time instance.
string formatTs(T)(string fmt, T timestamp) @trusted
if (isTimeType!T || isDateType!T)
{
    import std.string : leftJustify;

    if (fmt == ISO_DATETIME_FMT)
    {
        string isoString = timestamp.toISOString;
        static if (is(T == SysTime))
        {
            /+
            Expected   "20131221T233257.1234560"
            instead of "20131221T233257.123456"
            +/
            enum isoLen = "20131221T233257.1234560".length;
            return leftJustify(isoString, isoLen, '0');
        }
        else
            return isoString;
    }
    else if (fmt == EXT_DATETIME_FMT)
    {
        string extString = timestamp.toISOExtString;
        static if (is(T == SysTime))
        {
            /+
            Expected   "2013-12-21T23:32:57.1234560"
            instead of "2013-12-21T23:32:57.123456"
            +/
            enum extLen = "2013-12-21T23:32:57.1234560".length;
            return leftJustify(extString, extLen, '0');
        }
        else
            return extString;
    }
    else
    {
        import core.stdc.time : strftime, tm;
        import std.string : toStringz;
        char[160] buffer;

        // create a SysTime from Date, DateTime, TimeOfDay
        // so that toTM is reachable
        tm t = toSysTime(timestamp).toTM;

        // size_t strftime(char* s, size_t maxsize, in char* format,
        //                 in tm* timeptr);
        auto len = strftime(&buffer[0],
                            buffer.length,
                            toStringz(fmt),
                            &t);
        return buffer[0..len].idup;
    }
}


bool isFullFormat(string format)
{
    return format == EXT_DATETIME_FMT
        || format == ISO_DATETIME_FMT;
}
/**
 * A tester for date and time types, with precision for approximative
 * equality comparisons.
 */
struct ApproxTime(TimeType)
if (isTimeType!TimeType)
{
    private TimeType _timestamp;
    private Duration _precision;
    private string _format;

    /**
     * Instanciate an `ApproxTime!TimeType`.
     *
     * Params:
     *   t = A time value.
     *   d = A time rounding precision.
     *   f = An optional format for string conversions.
     */
    static ApproxTime!TimeType opCall(TimeType t,
                                      Duration d,
                                      string f=EXT_DATETIME_FMT)
    {
        ApproxTime!TimeType approx;

        approx.timestamp = round(t, d);
        approx.precision = d;
        approx.format = f;

        return approx;
    }

public:

    /// Compare to another FormattedTimeTest instance.
    bool opEquals(this FFT, OtherFTT)(auto ref OtherFTT other) const
    if (isAssignable!(FFT, OtherFTT))
    {
        return opCmp(other) == 0;
    }

    /// Compare to a raw timestamp value.
    bool opEquals(const TimeType other) const
    {
        return opCmp(other) == 0;
    }

    /// Compare to a formatted timestamp.
    bool opEquals(S)(const auto ref S formatted) const
    if (isSomeString!S)
    {
        return opCmp(formatted) == 0;
    }

    /// Compute a hash function for usage as an associative array key.
    nothrow @trusted size_t toHash() const
    {
        TimeType rounded = round(_timestamp, _precision);
        return thisTypeHash + rounded.toHash;
    }

    /// Compare to another FormattedTimeTest instance.
    int opCmp(this This, FTT)(auto ref FTT other) const
    if (isAssignable!(This, FTT))
    {
        import std.algorithm.comparison : max;

        auto precis = max(precision, other.precision);
        return opCmp(other.timestamp, precis);
    }

    /// Compare to a raw timestamp value.
    int opCmp(const ref TimeType other) const
    {
        return opCmp(other, precision);
    }

    private TimeType fromHardCodedFormat(alias string fromString, S)
    (const auto ref S formatted) const
    if (isSomeString!S)
    {
        static if (is(TimeType == SysTime))
            auto other = mixin
            (`TimeType.` ~ fromString ~ `(formatted, timestamp.timezone)`);
        else
            auto other = mixin(`TimeType.` ~ fromString ~ `(formatted)`);

        return other;
    }

    /**
       Compare to a formatted timestamp value.

       Note: SysTime includes milliseconds, microseconds and hundreds of
       nanoseconds. Such precisions are compatible with `SysTime` only.
       In this single case the ISOExtString format is `yyyymmddTHHMMSS.mmmµµµn`.
       With `DateTime` the format is at most `yyyymmddTHHMMSS`, i.e.
       `%Y%m%dT%H%M%S`.
     */
    int opCmp(S)(const auto ref S formatted) const
    if (isSomeString!S)
    {
        import std.algorithm.comparison : cmp;
        import std.format : _f=format;
        import dutil.src : srcln;

        immutable string fmt = format;
        int result;

        switch(fmt)
        {
            case ISO_FORMATS.Long:
                {
                    auto otherTimestamp =
                        fromHardCodedFormat!"fromISOExtString"(formatted);
                    result = opCmp(otherTimestamp, precision);
                }
                break;

            case ISO_FORMATS.Short:
                {
                    auto otherTimestamp =
                        fromHardCodedFormat!"fromISOString"(formatted);
                    result = opCmp(otherTimestamp, precision);
                }
                break;

            default:
                immutable string thisFormatted = toString();
                result = thisFormatted.cmp(formatted);
        }

        return result;
        /+
        static if (is(TimeType == SysTime))
        {
            import core.time : hnsecs, msecs, usecs;

            enum OneSec = DFLT_PRECISION;
            enum OneMillis = 1.msecs;
            enum OneMicros = 1.usecs;
            enum OneHNanos = 1.hnsecs;

            size_t length = thisFormatted.length;

            /*
            SysTime includes milliseconds, microseconds and hundreds of
            nanoseconds.
            */
            if (precision > OneHNanos)
            {
                size_t getLength(alias string secondsTpl,
                                 alias string millisTpl,
                                 alias string microsTpl,
                                 alias string hNanosTpl)()
                {
                    string tpl = hNanosTpl;

                    if (precision >= OneSec)
                        tpl = secondsTpl;
                    else if (precision >= OneMillis)
                        tpl = millisTpl;
                    else if (precision >= OneMicros)
                        tpl = microsTpl;

                    import dutil.src : dbg;
                    dbg.ln("Using dateTime template '%s' (%d characters).",
                           tpl, tpl.length);
                    return tpl.length;
                }

                if (format == ISO_DATETIME_FMT)
                {
                    // ISOString    looks like 20171231T234759.1234567
                    enum string HNS_TPL = "yyyymmddTHHMMSS.mmmµµµn";
                    enum string US_TPL = HNS_TPL[0..$-1];
                    enum string MS_TPL = US_TPL[0..$-3];
                    enum string S_TPL = MS_TPL[0..$-3-1]; // -1 for the dot

                    length = getLength!(S_TPL, MS_TPL, US_TPL, HNS_TPL)();
                }
                else if (format == EXT_DATETIME_FMT)
                {
                    // ISOExtString looks like 2017-12-31T23:47:59.1234567
                    enum string HNS_TPL = "yyyy-mm-ddTHH:MM:SS.mmmµµµn";
                    enum string US_TPL = HNS_TPL[0..$-1];
                    enum string MS_TPL = US_TPL[0..$-3];
                    enum string S_TPL = MS_TPL[0..$-3-1]; // -1 for the dot

                    length = getLength!(S_TPL, MS_TPL, US_TPL, HNS_TPL)();
                }
            }

            import dutil.src : dbg;
            dbg.ln("Comparing %d characters (%s format) and %s => %s and %s",
                   length, format,
                   thisFormatted, formatted,
                   thisFormatted[0..length], formatted[0..length]);

            return thisFormatted[0..length].cmp(formatted[0..length]);
        }
        else+/
    }

    import std.traits : isAssignable;
    private int opCmp(TT)(const auto ref TT t, const Duration precis) const
    if (isAssignable!(TimeType, TT))
    {
        import core.time : abs;

        auto d = t - timestamp;
        if (abs(d) < precis)
            return 0;

        return timestamp.opCmp(t);
    }

    /// Retrieve a formatted description of the ApproxTime instance.
    string toString(S)(auto ref S fmt) const
    if (isSomeString!S)
    {
        return fmt.formatTs(round(timestamp, precision));
    }

    /// Retrieve a description of the ApproxTime instance.
    @safe string toString() const
    {
        string f = format;

        if (f is null || f.length == 0)
            f = EXT_DATETIME_FMT;

        return toString(f);
    }

    /// Retrieve the remembered timestamp.
    @property TimeType timestamp() const nothrow { return _timestamp; }

    /// Replace the remembered timestamp.
    @property void timestamp(TimeType time) nothrow { _timestamp = time; }

    /// Retrieve the timestamp precision.
    @property Duration precision() const nothrow { return _precision; }

    /// Replace the timestamp precision.
    @property void precision(Duration d) nothrow { _precision = d; }

    /// Retrieve the string format.
    @property string format() const nothrow { return _format.dup; }

    /// Replace the string format.
    @property void format(string f) nothrow { _format = f.dup; }

    /// Hours past midnight.
    @property @safe ubyte hour() const nothrow { return _timestamp.hour; }

    /// Hours past midnight.
    @property @safe void hour(int h) { _timestamp.hour = h; }

    /// Minutes past the current hour.
    @property @safe ubyte minute() const nothrow
    {
        return _timestamp.minute;
    }

    /// Minutes past the current hour.
    @property @safe void minute(int m) { _timestamp.minute = m; }

    /// Seconds past the current minute.
    @property @safe ubyte second() const nothrow
    {
        return _timestamp.second;
    }

    /// Seconds past the current minute.
    @property @safe void second(int s) { _timestamp.second = s; }

    private nothrow @trusted size_t thisTypeHash() const
    {
        return 47 << 2;
    }
}

/// Instanciate an `ApproxTime`.
auto approxTime(T)(T dt, Duration precision=DFLT_PRECISION,
                   string f=EXT_DATETIME_FMT)
if (isTimeType!T)
{
    alias TApproxTime = ApproxTime!T;
    return TApproxTime(dt, precision, f);
}

/// Instanciate an `ApproxTime` for `SysTime` timestamps.
auto approxNow(Duration precision=DFLT_PRECISION, string f=EXT_DATETIME_FMT)
{
    import std.datetime.systime : Clock;
    return approxTime(Clock.currTime, precision, f);
}


/// Instanciate an `ApproxTime` for `TimeOfDay` retrieved from `SysTime`.
auto approxNowTime(Duration precision=DFLT_PRECISION,
                   string f=EXT_DATETIME_FMT)
{
    import std.datetime.systime : Clock;
    return approxTime(toTime(Clock.currTime), precision, f);
}


/// Instanciate an `ApproxTime` for `TimeOfDay` retrieved from `SysTime`.
string formatToday(string f=EXT_DATETIME_FMT)
{
    import std.datetime.systime : Clock;
    return formatTs(f, toDate(Clock.currTime));
}


/// Compute a hash value for a `Date`, `DateTime` or `SysTime` instance.
nothrow @trusted size_t toHash(DT)(DT dt)
{
    static if (is(DT == Date))
    {
        alias d = dt;
        return d.year <<2 + d.dayOfYear;
    }
    else static if (is(DT == TimeOfDay))
    {
        alias t = dt;
        return t.hour << 4 + t.minute << 2 + t.second;
    }
    else
    {
        return Date(dt.year, dt.month, dt.day).toHash << 6
            + TimeOfDay(dt.hour, dt.minute, dt.second).toHash;
    }
}

/**
 * Round a time value to the specified precision.
 */
@trusted nothrow TimeType round(TimeType)(TimeType t, Duration precision)
if (isTimeType!TimeType)
{
    import std.exception : collectException;
    import std.traits : hasMember, Unqual;

    immutable TimeType st1 = t;
    Unqual!TimeType st0 = st1;

    collectException(st0.hour = 0);
    collectException(st0.minute = 0);
    collectException(st0.second = 0);

    Duration stDur = st1 - st0;
    immutable nanos = stDur.split!"nsecs"().nsecs;
    immutable nanoPrecision = precision.split!"nsecs"().nsecs;
    immutable roundedNanos = nanos - (nanos % nanoPrecision);

    immutable roundedStDur = nsecs(roundedNanos);
    return st0 + roundedStDur;
}


/// Sleeps the current thread the specified number of duration units.
void sleep(T, alias unit="msecs")(T nbUnits)
if (isScalarType!(T) && isSomeString!(typeof(unit)))
{
    import core.thread : dur, Thread;
    Thread.sleep( dur!unit(nbUnits) );
}


