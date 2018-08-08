// Written in the D programming language.

/**
Operating System related functions.

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
module osutil;

import core.stdc.errno : ENOENT, ENOTDIR;
import std.conv : parse, text, to;
import std.file : exists, isDir, mkdirRecurse, readText, remove,
                  setAttributes, FileException;
import std.path : dirSeparator, expandTilde, pathSeparator;
import std.process : environment, executeShell, ProcessException, thisProcessID;
import std.range.primitives : ElementType, isInputRange;
import std.stdio : File, writeln;
import std.string : format, indexOf, join, split;
import std.traits : isSomeString, Unqual;
import std.uni : isWhite;

import argsutil;
import constvals : ModePrivateRWX, VbLevel;


/**
 * Retrieve the path of an executable file.
 *
 * The path is looked in the `PATH` environment variable by default.
 *
 * Params:
 *     name      = The name (and extension, if any) of the executable file.
 *     exec_dirs = Additional  directories in which the file is searched.
 *     env_var   = The name of the environment variable (default : `PATH`).
 */
string get_exec_path(string name, string[] exec_dirs=[],
                     string env_var="PATH")
{
    string[] dirs = exec_dirs.dup;
    if (env_var !is null && env_var.length > 0)
        dirs ~= split(environment.get(env_var, ""), pathSeparator);

    foreach (string exec_dir; dirs)
    {
        auto exec_path = jn(exec_dir , name);

        if (exists(exec_path))
            return exec_path;
    }

    throw new FileException(name, ENOENT);
}


/**
 * Create a directory if needed, and return its path with user and environment
 * variables expanded.
 *
 * Params:
 *     path = the directory to be created if needed.
 *     mode = the access control list to be applied to the directory on creation
 */
string get_dir(string path, ushort mode=ModePrivateRWX)
{
    string expanded_path = path;
    if (indexOf(path, "~") >= 0)
    {
        expanded_path = expandTilde(path);
    }

    if (!exists(expanded_path))
    {
        if (verbose >= VbLevel.Info)
        {
            if (expanded_path != path)
            {
                string fmt = "Creating directory %s => %s";
                writeln(format(fmt, path, expanded_path));
            }
            else
            {
                string fmt = "Creating directory %s";
                writeln(format(fmt, path));
            }
        }

        if (!fake)
        {
            mkdirRecurse(expanded_path);
            auto dir = expanded_path;
            dir.setAttributes(mode);
        }
    }
    else if (!isDir(expanded_path))
    {
        string msg = "The path %s is not a directory";
        throw new FileException(expanded_path, msg.format(expanded_path));
    }

    // Note: should be done on intermediate directories.
    chown(getRealUserAndGroup(), expanded_path);

    return expanded_path;
}


/**
 * Retrieve the current real user and real group of the running process.
 *
 * Returns:
 *   A colon-separated string `user:group`.
 */
string getRealUserAndGroup()
{
    auto real_ug =
        runCommand(format!"ps --no-headers -oruser,group %d"(thisProcessID));

    auto arr = real_ug.split(" ");
    return join(arr, ":");
}


/**
 * Replace the owner of a file or directory.
 * Params:
 *     user = the name or ID of the new owner, or a <user>:<group> pair.
 *     path = the file or directory for which the user and/or group is changed.
 */
void chown(string user, string path)
{
    runCommand(format("chown %s '%s'", user, path));
}


/**
 * Execute a shell command and return its output, or raise a
 * CommandFailedException.
 */
string runCommand(string command)
{
    if (verbose >= VbLevel.Info)
    {
        writeln(command);
    }
    if (!fake)
    {
        try
        {
            auto result = executeShell(command);
            if (result.status == 0)
                return result.output;
            else
                throw new CommandFailedException(command,
                                                 result.status,
                                                 result.output);
        }
        catch(ProcessException pex)
        {
            throw new CommandFailedException(command, pex);
        }
    }

    return "";
}


/// The exception raised when a command exits with an error code.
class CommandFailedException : Exception
{
    import std.exception : basicExceptionCtors;
    mixin basicExceptionCtors;

    /// Constructor with a non-zero return code.
    this(string cmd,
         int code,
         string output = null,
         string file = __FILE__,
         size_t line = __LINE__)
    {
        super(buildMessage(cmd, code, output), file, line);
    }

    /// Constructor with a causing exception.
    this(string cmd,
         Throwable reason = null)
    {
        this(cmd, __FILE__, __LINE__, reason);
    }

    /// Constructor with file, line and a causing exception.
    this(string cmd,
         string file = __FILE__,
         size_t line = __LINE__,
         Throwable reason = null)
    {
        super(buildMessage(cmd, reason), file, line, reason);
    }

    private:
        static string buildMessage(string command, int status, string output)
        {
            string msg;
            int code;

            if (output is null)
                output = "";
            else
                output ~= "\n";

            if (status > 0)
            {
                msg = "%sCommand '%s' failed with error code %d.";
                code = status;
            }
            else
            {
                msg = "%sCommand '%s' stopped by signal %d.";
                code = -status;
            }

            return format(msg, output, command, code);
        }

        static string buildMessage(string command, Throwable reason)
        {
            string msg;
            string sReason;

            if (reason !is null)
            {
                msg = "Command '%s' failed : %s";
                sReason = text(reason.message());
            }
            else
            {
                msg = "Command '%s' failed.%s";
                sReason = "";
            }

            return format(msg, command, sReason);
        }
}


/**
 * Read a file content as an integer.
 */
int read_int_file(string path)
{
    string content = readText!string(path);
    return parse!int(content);
}


/**
 * Join the path components with the path separator `std.path.dirSeparator`.
 * Params:
 *     paths = The paths to be joined with `dirSeparator`.
 */
string join_paths(string[] paths ...)
{
    return join(paths, dirSeparator);
}

/**
 * Join the path components with the path separator `std.path.dirSeparator`.
 * Params:
 *     paths = An array of paths to be joined with `dirSeparator`.
 */
string join_paths(string[] paths)
{
    return join(paths, dirSeparator);
}

/// A short alias for join_path.
alias jn = join_paths;


/**
 * Check whether a path points to an existing directory.
 * Throws: std.file.FileException if no entry exists at `path` or if it exists
 *         but is not a directory.
 */
void assertDirExists(S)(S path)
if (isSomeString!S)
{
    auto errno = 0;

    if ( !exists(path) )
        errno = ENOENT;
    else if ( !isDir(path) )
        errno = ENOTDIR;

    if (errno)
        throw new FileException(path, errno);
}


/**
 * Read a text file containing only an integer.
 */
int readIntFile(S)(S path)
if (isSomeString!S)
{
    return to!int(readText(path));
}


/**
 * Close and delete a file immediately after.
 * Params:
 *     tobeRemoved = A `File` object to be closed and then removed.
 */
void closeAndRemove(File tobeRemoved)
{
    tobeRemoved.close();
    remove(tobeRemoved.name);
}

