// Authors:   tspike (github.com/tspike2k)
// Copyright: Copyright (c) 2020
// License:   Boost Software License 1.0 (https://www.boost.org/LICENSE_1_0.txt)

module logging;

private nothrow @nogc:

// NOTE: LOG_MIN_SEVERITY can be configured to filter out logging functions with a lower severity. This is done
// by statically checking the minimum severity level and leaving the function body empty if the function's severity 
// level is lower. This is relying on the optimizer to turn calls to empty functions into a no-op. This seems to be 
// true when passing the -inline flag to DMD.
//
// Unfortunately, there doesn't seem to be a way to replace function calls with void, like you can using C macros.
// See here for a discussion on this:
// https://forum.dlang.org/thread/oxtlstdenjqrjoqhkqfi@forum.dlang.org?page=1
//
// For an alternative approach to logging that only works at compile-time (and doesn't allow arguments to be passed
// at runtime) see here:
// https://wiki.dlang.org/Using_string_mixins_for_logging

import std.traits;
import print : printOut, printErr;
public import print : toPrint;

enum LogSeverity
{
    DEBUG,
    INFO,
    WARNING,
    ERROR,
    FATAL,
    NONE,
}

version(testing)
{
    enum LOG_MIN_SEVERITY = LogSeverity.DEBUG;
}
else
{
    enum LOG_MIN_SEVERITY = LogSeverity.WARNING;
}

public:

void logDebug(alias fmt, Args...)(Args args)
if(isSomeString!(typeof(fmt)) || isSomeChar!(typeof(fmt[0])))
{
    pragma(inline, true);
    static if (LOG_MIN_SEVERITY <= LogSeverity.DEBUG)
    {
        printOut!fmt(args);
    }
}

void logInfo(alias fmt, Args...)(Args args)
if(isSomeString!(typeof(fmt)) || isSomeChar!(typeof(fmt[0])))
{
    pragma(inline, true);
    static if (LOG_MIN_SEVERITY <= LogSeverity.INFO)
    {
        printOut!fmt(args);
    }
}

void logWarn(alias fmt, Args...)(Args args)
if(isSomeString!(typeof(fmt)) || isSomeChar!(typeof(fmt[0])))
{
    pragma(inline, true);
    static if (LOG_MIN_SEVERITY <= LogSeverity.WARNING)
    {
        printOut!"WARN: ";
        printOut!fmt(args);
    }
}

void logErr(alias fmt, Args...)(Args args)
if(isSomeString!(typeof(fmt)) || isSomeChar!(typeof(fmt[0])))
{
    pragma(inline, true);
    static if (LOG_MIN_SEVERITY <= LogSeverity.ERROR)
    {
        printErr!"ERR: ";
        printErr!fmt(args);
    }
}

void logFatal(alias fmt, Args...)(Args args)
if(isSomeString!(typeof(fmt)) || isSomeChar!(typeof(fmt[0])))
{
    pragma(inline, true);
    static if (LOG_MIN_SEVERITY <= LogSeverity.ERROR)
    {
        printErr!"FATAL: ";
        printErr!fmt(args);
    }
}