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
module dutil.os;

import core.stdc.errno : ENOENT, ENOTDIR;
import std.array : replace;
import std.conv : parse, text, to;
import std.file : exists, isDir, mkdirRecurse, readText, remove, rmdirRecurse,
                  setAttributes, thisExePath, FileException ;
import std.format : _f = format;
import std.path : baseName, dirSeparator, expandTilde, pathSeparator;
import std.process : environment, execute, executeShell, ProcessException,
                     thisProcessID;
import std.range.primitives : ElementType, isInputRange;
import std.regex : Regex, regex, split;
import std.stdio : File;
import std.string : indexOf, join, split, strip, tr;
import std.traits : isSomeString, Unqual;
import std.uni : isWhite;

import dutil.appargs : fake;
import dutil.constvals : ModePrivateRWX, VbLevel;
import dutil.ui : info_, trace, tracef;


/// Retrieve the name part of the program path.
@property string program_name()
{
    return baseName(thisExePath);
}


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

    tracef("No '%s' in PATH=%s", name, environment.get(env_var, ""));
    throw new FileException(name, ENOENT);
}


private immutable static string[] HOME_VARS = [
    "~",
    "~$USER",
    "~${USER}",
    "~$USERNAME",
    "~${USERNAME}",
    "$HOME",
    "${HOME}",
];


private immutable static string[] USER_VARS = [
    "$USER",
    "${USER}",
    "$USERNAME",
    "${USERNAME}",
];


/**
 * Expand the real user's name and/or home in a path, using the real user's
 * path.
 * SUDO's SUDO_USER variable, then SUPER's CALLER_HOME then CALLER variable,
 * then the process ruser variable are used to retrieve the user name and/or
 * home directory.
 */
string expandRealUserPath(string path)
{
    string expandedPath = path.dup;
    string ruser = "";
    string ruserHome = "";

    ruser = environment.get("SUDO_USER", "");
    if (ruser.length == 0)
        ruser = environment.get("CALLER", "");

    if (ruser.length == 0)
        ruser = getRealUserAndGroup().split(":")[0];

    ruserHome = environment.get("CALLER_HOME", "");
    if (ruserHome.length == 0)
        ruserHome = getUserHome(ruser);

    foreach (homeVar; HOME_VARS)
    {
        expandedPath = expandedPath.replace(homeVar, ruserHome);
    }

    foreach (userVar; USER_VARS)
    {
        expandedPath = expandedPath.replace(userVar, ruser);
    }

    return expandedPath;
}


/**
 * Create a directory if needed, and return its path with user and environment
 * variables expanded.
 *
 * Params:
 *     path = the directory to be created if needed.
 *     mode = the access control list to be applied to the directory on creation
 *     autoCreate = true if any missing directory must be created.
 */
string get_dir(string path, ushort mode=ModePrivateRWX, bool autoCreate=false,
               bool allowMissing=false)
{
    string expanded_path = path;
    if (indexOf(path, "~") >= 0)
        expanded_path = expandRealUserPath(path);

    if (!exists(expanded_path))
    {
        if (expanded_path != path)
            trace(_f!"Creating directory %s => %s"(path, expanded_path));
        else
            trace(_f!"Creating directory %s"(path));

        if (!fake)
        {
            if (autoCreate)
            {
                auto dir = expanded_path;
                mkdirRecurse(dir);
                dir.setAttributes(mode);
            }
            else if (!allowMissing)
            {
                enum string msg = "The directory %s does not exist";
                throw new FileException(expanded_path, _f!msg(expanded_path));
            }
        }
    }
    else if (!isDir(expanded_path))
    {
        enum string msg = "The path %s is not a directory";
        throw new FileException(expanded_path, _f!msg(expanded_path));
    }

    if (getEffectiveUserAndGroup() == "root:root")
    {
        // Note: should be done on intermediate directories.
        chown(getRealUserAndGroup(), expanded_path);
    }

    return expanded_path;
}


private Regex!char spaces = regex(`\s+`);

/**
 * Retrieve a current effective/filesystem/real/saved user and group pair of the
 * running process.
 *
 * Params:
 *   fmt = A comma-separated pair of user and group format, such as
 *         `ruser,sgroup`.
 * Returns:
 *   A colon-separated string `user:group`.
 */
private string getSomeUserAndGroup(string fmt)
{
    import std.string : strip;

    immutable usergroup =
        runCommand(_f!"ps --no-headers -o%s %d"(fmt, thisProcessID));

    immutable arr = usergroup.strip.split(spaces).idup;

    static bool isFirstCall(inout(string) fmt)
    {
        static bool[string] _knownFormats;
        scope(exit)
            _knownFormats[fmt] = true;

        auto p = (fmt in _knownFormats);
        return (p is null || !_knownFormats[fmt]);
    }

    string result = arr.join(":");

    if (isFirstCall(fmt))
        trace(fmt, "=", arr.join(":"));
    //TODO create logOnce(statement) and logOnce(name, statement) dutil functions

    return result;
}

/**
 * Retrieve the current effective user and effective group of the running
 * process.
 *
 * Returns:
 *   A colon-separated string `user:group`.
 */
string getEffectiveUserAndGroup()
{
    return getSomeUserAndGroup("euser,egroup");
}

private string _realUserAndGroup;

static this()
{
    _realUserAndGroup = getSomeUserAndGroup("ruser,rgroup");
}

/**
 * Retrieve the current real user and real group of the running process.
 *
 * Returns:
 *   A colon-separated string `user:group`.
 */
string getRealUserAndGroup()
{
    return _realUserAndGroup;
}

/**
 * Retrieve the HOME directory of the current real user of the running process.
 *
 * Please note that calling `fmount` from `super` lets the process retrieve a
 * custom `HOME` while `sudo` does not provide such informations and thus only
 * the value from `/etc/passwd` can be retrieved.
 *
 * Params:
 *   realUser = The login of the real user running the process.
 *
 * Returns:
 *   An absolute path to a home directory.
 */
string getRealUserHome(string realUser)
{
    import std.process : env = environment;

    //home transmitted by `super`
    string home = env.get("CALLER_HOME", "");

    if (home.length == 0)
    {
        if (env.get("SUDO_USER", "").length > 0)
        {
            //home not transmitted by `sudo`
            string passwdLine = getUserEtcPasswdLine(realUser);
            home = getUserHome(realUser);
        }
        else
            home = env.get("HOME");
    }

    return home;
}

private string getUserHome(string login)
{
    return getUserEtcPasswdLine(login).split(":")[5];
}

private string getUserEtcPasswdLine(string user)
{
    enum PasswdPath = "/etc/passwd";

    File passwd = File(PasswdPath);
    string line;

    while ((line = passwd.readln()) !is null)
    {
        if (line[0 .. user.length] == user
            && line[user.length] == ':')
        {
            return line;
        }
    }

    throw new Exception(_f!"User '%s' not found in %s"(user, PasswdPath));
}

private string getGidEtcGroupLine(string gid)
{
    enum GroupPath = "/etc/group";

    File groupFile = File(GroupPath);
    string line;

    while ((line = groupFile.readln()) !is null)
    {
        string gidInEtcgroup = line.split(":")[2];
        if (gidInEtcgroup == gid)
        {
            return line;
        }
    }

    throw new Exception(_f!"GID '%s' not found in %s"(gid, GroupPath));
}

unittest
{
    import std.algorithm.iteration : filter;
    import std.array : array, split;
    import std.format : _f = format;
    import std.process : env = environment;
    import std.string : join;

    string expectedUser = env.get("USER", "user");

    string expectedGID = env.get("GID", "");
    if (expectedGID.length == 0)
        expectedGID = getUserEtcPasswdLine(expectedUser)
            .split(":")[3];
    immutable string groupLine = getGidEtcGroupLine(expectedGID);
    immutable string expectedGroup = groupLine.split(":")[0];
    string expectedUserGroup = expectedUser ~ ":" ~ expectedGroup;

    string actual = getRealUserAndGroup();
    assert(actual == expectedUserGroup,
           _f!"Real user and group '%s' instead of '%s'.\nenv is:%(\n  %s: %)"
           (actual, expectedUserGroup, env.toAA));
}

/**
 * Replace the owner of a file or directory.
 * Params:
 *     user = the name or ID of the new owner, or a <user>:<group> pair.
 *     path = the file or directory for which the user and/or group is changed.
 */
void chown(string user, string path)
{
    runCommand(_f!"chown %s '%s'"(user, path));
}

/**
 * Check whether a file or directory is owned by the specified user.
 *
 * Params:
 *   path = A path to a file or directory.
 *   user = The login of the expected owner.
 */
bool isOwnedBy(string path, string user)
{
    import std.algorithm.comparison : equal;
    return equal(runCommand(_f!"stat -c %%U '%s'"(path)), user);
}


/**
 * Execute a shell command and return its output, or raise a
 * CommandFailedException.
 */
string runCommand(string command)
{
    trace(command);
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


/**
 * Execute an executable file with its arguments  and return its output, or
 * raise a CommandFailedException.
 */
string runCommand(string[] command)
{
    info_(command.join(" "));

    if (!fake)
    {
        try
        {
            auto result = execute(command);
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

    /// Constructor with a shell command and a non-zero return code.
    this(string cmd,
         int code,
         string output = null,
         string file = __FILE__,
         size_t line = __LINE__)
    {
        super(buildMessage(cmd, code, output), file, line);
    }

    /// Constructor with an executable command and a non-zero return code.
    this(string[] cmd,
         int code,
         string output = null,
         string file = __FILE__,
         size_t line = __LINE__)
    {
        super(buildMessage(cmd.join(" "), code, output), file, line);
    }

    /// Constructor with a causing exception.
    this(string cmd,
         Throwable reason = null)
    {
        this(cmd, __FILE__, __LINE__, reason);
    }

    /// Constructor with a causing exception.
    this(string[] args,
         Throwable reason = null)
    {
        this(args.join(" "), __FILE__, __LINE__, reason);
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

            return _f(msg, output, command, code);
        }

        static string buildMessage(string command, Throwable reason)
        {
            string msg;
            string sReason;

            if(reason)
            {
                msg = "Command '%s' failed : %s";
                sReason = text(reason.message());
            }
            else
            {
                msg = "Command '%s' failed.%s";
                sReason = "";
            }

            return _f(msg, command, sReason);
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
    return to!int(readText(path).strip);
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

/**
 * Remove a file if it exists.
 */
void removeIfExists(string path)
{
    if (exists(path))
    {
        if (isDir(path))
        {
            trace(_f!"Removing directory %s"(path));
            rmdirRecurse(path);
        }
        else
        {
            trace(_f!"Removing file %s"(path));
            remove(path);
        }
    }
}


