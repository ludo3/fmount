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
import std.process : environment, execute, executeShell, ProcessException,
                     thisProcessID;
import std.range.primitives : ElementType, isInputRange;
import std.stdio : File, writeln;
import std.string : format, indexOf, join, split, tr;
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
        expanded_path = expandTilde(path);

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

    if (getEffectiveUserAndGroup() == "root:root")
    {
        // Note: should be done on intermediate directories.
        chown(getRealUserAndGroup(), expanded_path);
    }

    return expanded_path;
}


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
    immutable usergroup =
        runCommand(format!"ps --no-headers -o%s %d"(fmt, thisProcessID));

    immutable arr = usergroup.split(" ");

    static bool isFirstCall(inout(string) fmt)
    {
        static bool[string] _knownFormats;
        scope(exit)
            _knownFormats[fmt] = true;

        auto p = (fmt in _knownFormats);
        return (p is null || !_knownFormats[fmt]);
    }

    if (isFirstCall(fmt))
    {
        if (verbose >= VbLevel.More)
            writeln(fmt, "=", join(arr, ":"));
    }
    //TODO create logOnce(statement) and logOnce(name, statement) dutil functions

    return join(arr, ":");
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

/**
 * Retrieve the current real user and real group of the running process.
 *
 * Returns:
 *   A colon-separated string `user:group`.
 */
string getRealUserAndGroup()
{
    /++
     FIXME
       sudo sh -c set
            COLORTERM='truecolor'
            DISPLAY=':0.0'
            HOME='/root'
            IFS='
            '
            LANG='fr_FR.UTF-8'
            LC_CTYPE='fr_FR.UTF-8'
            LOGNAME='root'
            LS_COLORS='rs=0:di=01;34:ln=01;36:mh=00:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:mi=00:su=37;41:sg=30;43:ca=30;41:tw=30;42:ow=34;42:st=37;44:ex=01;32:*.tar=01;31:*.tgz=01;31:*.arc=01;31:*.arj=01;31:*.taz=01;31:*.lha=01;31:*.lz4=01;31:*.lzh=01;31:*.lzma=01;31:*.tlz=01;31:*.txz=01;31:*.tzo=01;31:*.t7z=01;31:*.zip=01;31:*.z=01;31:*.Z=01;31:*.dz=01;31:*.gz=01;31:*.lrz=01;31:*.lz=01;31:*.lzo=01;31:*.xz=01;31:*.zst=01;31:*.tzst=01;31:*.bz2=01;31:*.bz=01;31:*.tbz=01;31:*.tbz2=01;31:*.tz=01;31:*.deb=01;31:*.rpm=01;31:*.jar=01;31:*.war=01;31:*.ear=01;31:*.sar=01;31:*.rar=01;31:*.alz=01;31:*.ace=01;31:*.zoo=01;31:*.cpio=01;31:*.7z=01;31:*.rz=01;31:*.cab=01;31:*.jpg=01;35:*.jpeg=01;35:*.mjpg=01;35:*.mjpeg=01;35:*.gif=01;35:*.bmp=01;35:*.pbm=01;35:*.pgm=01;35:*.ppm=01;35:*.tga=01;35:*.xbm=01;35:*.xpm=01;35:*.tif=01;35:*.tiff=01;35:*.png=01;35:*.svg=01;35:*.svgz=01;35:*.mng=01;35:*.pcx=01;35:*.mov=01;35:*.mpg=01;35:*.mpeg=01;35:*.m2v=01;35:*.mkv=01;35:*.webm=01;35:*.ogm=01;35:*.mp4=01;35:*.m4v=01;35:*.mp4v=01;35:*.vob=01;35:*.qt=01;35:*.nuv=01;35:*.wmv=01;35:*.asf=01;35:*.rm=01;35:*.rmvb=01;35:*.flc=01;35:*.avi=01;35:*.fli=01;35:*.flv=01;35:*.gl=01;35:*.dl=01;35:*.xcf=01;35:*.xwd=01;35:*.yuv=01;35:*.cgm=01;35:*.emf=01;35:*.ogv=01;35:*.ogx=01;35:*.aac=00;36:*.au=00;36:*.flac=00;36:*.m4a=00;36:*.mid=00;36:*.midi=00;36:*.mka=00;36:*.mp3=00;36:*.mpc=00;36:*.ogg=00;36:*.ra=00;36:*.wav=00;36:*.oga=00;36:*.opus=00;36:*.spx=00;36:*.xspf=00;36:'
            MAIL='/var/mail/root'
            OPTIND='1'
            PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
            PPID='23386'
            PS1='# '
            PS2='> '
            PS4='+ '
            PWD='/home/ludo/Documents/work/dev/dlang/fmount'
            SHELL='/bin/bash'
            SUDO_COMMAND='/bin/sh -c set'
            SUDO_GID='1000'
            SUDO_UID='1000'
            SUDO_USER='ludo'
            TERM='xterm-256color'
            USER='root'
            USERNAME='root'
            XAUTHORITY='/home/ludo/.Xauthority'
       super set
            CALLER='ludo'
            CALLER_HOME='/home/ludo'
            HOME='/root'
            IFS='
            '
            LOGNAME='root'
            OPTIND='1'
            ORIG_HOME='/home/ludo'
            ORIG_LOGNAME='ludo'
            ORIG_USER='ludo'
            PATH='/bin:/usr/bin'
            PPID='18793'
            PS1='# '
            PS2='> '
            PS4='+ '
            PWD='/home/ludo/Documents/work/dev/dlang/fmount'
            SUPERCMD='set'
            TERM='xterm-256color'
            USER='root'
       +/

    return getSomeUserAndGroup("ruser,rgroup");
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


/**
 * Execute an executable file with its arguments  and return its output, or
 * raise a CommandFailedException.
 */
string runCommand(string[] command)
{
    if (verbose >= VbLevel.Info)
    {
        writeln(command.join(" "));
    }
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

/**
 * Remove a file if it exists.
 */
void removeIfExists(string path)
{
    if (exists(path))
        remove(path);
}


