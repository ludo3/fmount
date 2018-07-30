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

import argsutil;
import constvals : ModePrivateRWX, VbLevel;

import std.conv : parse;
import std.file : exists, isDir, mkdirRecurse, readText, setAttributes,
                  FileException;
import std.path : expandTilde;
import std.process : executeShell, thisProcessID;
import std.stdio : writeln;
import std.string : format, indexOf, join, split;
import std.uni : isWhite;


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


private string getRealUserAndGroup()
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
        auto result = executeShell(command);
        if (result.status == 0)
            return result.output;

        throw new CommandFailedException(result.status, command);
    }

    return "";
}


/// The exception raised when a command exits with an error code.
class CommandFailedException : Exception
{
    /// Constructor.
    this(int code, string cmd)
    {
        super(buildMessage(code, cmd));
        _status = code;
        _command = cmd;

        if (status < 0)
            _signal = -status;
    }

    /// Retrieve the return code of the command.
    @property
    int status() const { return _status; }

    /// Retrieve the executed command.
    @property
    string command() const { return _command; }

    private:
        static string buildMessage(int status, string command)
        {
            string msg;
            int code;

            if (status > 0)
            {
                msg = "Command '%s' failed with error code %d.";
                code = status;
            }
            else
            {
                msg = "Command '%s' stopped by signal %d.";
                code = -status;
            }

            return format(msg, command, code);
        }

        int _status;
        int _signal;
        string _command;
}


/**
 * Read a file content as an integer.
 */
int read_int_file(string path)
{
    string content = readText!string(path);
    return parse!int(content);
}

