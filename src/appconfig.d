// Written in the D programming language.

/**
Application configuration.

This module contains the fmount, fumount and fmkfs configuration.

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
module appconfig;

import std.array : replace, split;
import std.exception : enforce;
import std.file : exists, isDir;
import std.format : _f = format;
import std.path : expandTilde;
import std.stdio : writeln;

// Dependencies
import sdlang : Tag, parseFile, parseSource;

import appargs : verbose;
import config;
import constvals :
    ConfFile, SysCfg, UsrCfg,
    DfltMountRoot, ModePrivateWX, VbLevel;
import dutil : printThChain;
import osutil :
    get_dir, getRealUserAndGroup, getRealUserHome,
    isOwnedBy, jn, join_paths;


// TODO automatic ssd option for btrfs on encrypted SSD physical devices.


/**
 * Retrieve the user configuration file.
 */
private string getUsrCfgFile(string filename = UsrCfg.name)
{
    return join_paths(getCfgDir!("usr", UsrCfg), filename);
}


/**
 * Retrieve the system configuration directory.
 */
private string getSysCfgFile(string filename = SysCfg.name)
{
    return join_paths(getCfgDir!("sys", SysCfg), filename);
}

private string getCfgDir(string unittestDirName, alias ConfFile cf)()
{
    string root;

    version(unittest)
    {
        import std.file : deleteme;
        root = join_paths(deleteme, unittestDirName);
    }
    else
        root = cf.root;

    return get_dir(join_paths(root, cf.dirs), ModePrivateWX);
}


private enum DFLT_SYS_CONFIG_FMT = `#
# The directory containing all mountpoints handled by fmount.
# It is usually /media, sometimes /mnt.
root "${DfltMountRoot}"

# User configurations may use different roots than the default,
# however only few directories should be allowed for security reasons.
# - owner for any directory owned by the real user, or
# - home for any directory in $HOME tree.
allow_root "${DfltMountRoot}" "/mnt" "owner"

# Usual mount options:
#   default = rw,suid,dev,exec,auto,nouser,async,relatime
#   user = (ordinary)user, noexec, nosuid, nodev
#   users = (any)user, noexec, nosuid, nodev
#   group = user(of that group), nosuid, nodev
#   owner = user(owner of the device), nosuid, nodev
#
fs {
    # Notes: below are the fmount options:
    all "user,noatime,noexec,nodev"
    fat "user,dirsync,uid=${uid},gid=${gid},utf8"
    vfat "user,dirsync,uid=${uid},gid=${gid},utf8"
    ntfs "user,nls=utf8,uid=${uid},gid=${gid}"
    iso9660 "user,ro,utf8,unhide"
    btrfs "user,autodefrag,compress"
    udf "user,iocharset=utf8"
    ufs "sync"
    dflt "sync,dirsync"
}
`;


private enum USR_CONFIG_FMT_EXAMPLE = `#
# The directory containing all mountpoints handled by fmount.
# It is usually /media, sometimes /mnt.

# Example of user specific root, if allowed by allow_root
# in the system configuration.
# root "/media/${user}"

# Please note that allow_root is forbidden in user configurations.

# Notes: usual mount options:
#   default = rw, suid, dev, exec, auto, nouser, async, relatime
#   user = (ordinary)user, noexec, nosuid, nodev
#   users = (any)user, noexec, nosuid, nodev
#   group = user(of that group), nosuid, nodev
#   owner = user(owner of the device), nosuid, nodev
#
fs {
    # Please refer to /etc/fmount.conf for the common options.
    # Notes: below are the user-specific fmount options:
    # Explicit "async" specification for all filesystems:
    all "async,noatime,noexec,nodev"

    # Example of overriding btrfs handling:
    btrfs "users,diratime,relatime,autodefrag"
}
`;


/// Retrieve the default system configuration.
string getDfltSysConfig()
{
    return DFLT_SYS_CONFIG_FMT.replace("${DfltMountRoot}", DfltMountRoot);
}

/// Retrieve the default user configuration.
string getDfltUsrConfig()
{
    return USR_CONFIG_FMT_EXAMPLE;
}

private string replaceVars(string path)
{
    auto usrGrp = getRealUserAndGroup().split(":");
    string user = usrGrp[0];
    string group = usrGrp[1];

    return path.expandTilde()
               .replace("${user}", user)
               .replace("${group}", group)
               .replace("${home}", getRealUserHome(user))
               .replace("${DfltMountRoot}", DfltMountRoot);
}

/**
 * Retrieve the directory at which the directories are created.
 */
string getRoot()
{
    import std.functional : toDelegate;
    auto replVars = toDelegate(&replaceVars);
    auto getUserHome = toDelegate(&getRealUserHome);
    auto ownedBy = toDelegate(&isOwnedBy);
    return getRoot(usrcfg, syscfg, replVars, getUserHome, ownedBy);
}

private string getRoot(Config userConfig, Config sysConfig,
                       string delegate(string) replVars,
                       string delegate(string) getUserHome,
                       bool delegate(string, string) ownedBy)
{
    import std.exception : enforce;

    string checkDir(string path)
    {
        enforce!UserConfigException(path.exists, "No such directory: " ~ path);
        enforce!UserConfigException(path.isDir, "Not a directory: " ~ path);
        return path;
    }

    string root = getRoot(userConfig);

    if (!root || !root.length)
        throw new UserConfigException("No root defined for mountpoints.");
    auto admcfg = sysConfig;

    string[] dfltAllowed; // must be empty
    string[] allowedRoots = admcfg.getValues("allow_root", dfltAllowed);

    auto usrGrp = getRealUserAndGroup().split(":");
    string user = usrGrp[0];
    string absRoot = checkDir(replVars(root));

    import dutil : srcln;
    foreach(allowedRoot; allowedRoots)
    {

        switch(allowedRoot)
        {
        case "owner":
            if (ownedBy(absRoot, user))
                return absRoot;
            break;

        case "home":
            {
                string home = getUserHome(user);
                if (absRoot.length >= home.length &&
                    absRoot[0..home.length] == home)
                {
                    // root is at or under home.
                    return absRoot;
                }
            }
            break;

        default:
            if (root == allowedRoot ||
                absRoot == replVars(allowedRoot))
            {
                return absRoot;
            }
            break;
        }
    }

    enum string ErrFmt = "Mount root directory '%s' is not allowed.";
    return enforce!UserConfigException(cast(string) null, _f!ErrFmt(root));
}

private string getRoot(Config cfg) { return cfg.getValue!string("root"); }

/// Retrieve the current system configuration.
@property Config syscfg()
{
    return getConfig(getSysCfgFile(),
                     getDfltSysConfig());
}

/// Retrieve the current user configuration.
@property Config usrcfg()
{
    return getConfig(getUsrCfgFile(),
                     getSysCfgFile(),
                     getDfltSysConfig());
}


/// getRoot unittest
unittest
{
    import std.exception : assertThrown, collectExceptionMsg, enforce;
    import std.file : deleteme, rmdirRecurse, write;
    import std.format : _f = format;
    import dutil : srcln, unused;
    import osutil : removeIfExists;

    string tmpHome = get_dir(deleteme ~ "/testHome");
    scope(exit)
        rmdirRecurse(tmpHome);

    string testReplVars(string path)
    {
        return path.expandTilde()
                   .replace("${user}", "testUser")
                   .replace("${group}", "testGrp")
                   .replace("${home}", tmpHome)
                   .replace("${DfltMountRoot}", DfltMountRoot);
    }

    string testUserHome(string user)
    {
        unused(user);
        return tmpHome;
    }

    bool isTestPathOwner;
    bool testPathOwner(string path, string user)
    {
        import std.path : bn = baseName;
        return isTestPathOwner
            && bn(path) == "testUser";
    }

    get_dir(tmpHome ~ "/media/testUser");
    get_dir(tmpHome ~ "/mnt/testUser");
    void testRoot(string testName,
                  string file=__FILE__, size_t line=__LINE__)
                 (string userCfgContent,
                  string admCfgContent,
                  string expectedRoot,
                  string expExcMsg=null)
    {
        string ucf = userCfgContent;
        string acf = admCfgContent;
        if (expectedRoot)
        {
            string root = getRoot
                (getConfig(ucf, acf, getDfltSysConfig),
                 getConfig(acf, getDfltSysConfig),
                 &testReplVars, &testUserHome, &testPathOwner);
            assert(root == expectedRoot, _f!"%s root is '%s' at:\n\t%s"
                                           (testName, root, srcln));
        }
        else if (expExcMsg)
        {
            auto msg =
                collectExceptionMsg!UserConfigException
                    (getRoot(getConfig(ucf, acf, getDfltSysConfig),
                             getConfig(acf, getDfltSysConfig),
                             &testReplVars, &testUserHome, &testPathOwner));
            assert(msg !is null,
                   _f!"UserConfigException with message '''%s''' was expected"
                        (expExcMsg));
            assert(msg == expExcMsg,
                   _f!("UserConfigException with message '''%s'''" ~
                       " instead of '''%s'''")(msg, expExcMsg));
        }
        else
            assertThrown!UserConfigException
                    (getRoot(getConfig(ucf, acf, getDfltSysConfig),
                             getConfig(acf, getDfltSysConfig),
                             &testReplVars, &testUserHome, &testPathOwner));
    }

    // THE DIRECTORIES MUST EXIST WHEN UNIT TESTS ARE RUN.
    testRoot!"hardCoded"
            (`
                  # root "/mnt"`,
             `
                  # root "/media"
                  allow_root "/media" "/media/${user}"`,
             "/media");

    testRoot!"admin"
            (`
                  # root "/mnt"`,
             `
                  root "/tmp"
                  allow_root "/media" "/media/${user}" "/tmp"`,
             "/tmp");

    testRoot!"user"
            (`
                  root "/mnt"`,
             `
                  root "/tmp"
                  allow_root "/media" "/mnt" "/media/${user}"`,
             "/mnt");

    testRoot!"not allowed hardCoded root"
            (`
                  #root "/mnt"`,
             `
                  #root "/tmp"
                  allow_root "/median" "/media/${user}"`,
             null,
             "Mount root directory '/media' is not allowed.");

    testRoot!"not allowed admin root"
            (`
                  #root "/mnt"`,
             `
                  root "/tmp"
                  allow_root "/media" "/media/${user}"`,
             null,
             "Mount root directory '/tmp' is not allowed.");

    testRoot!"not allowed user root"
            (`
                  root "/mnt"`,
             `
                  root "/tmp"
                  allow_root "/media" "/media/${user}"`,
             null,
             "Mount root directory '/mnt' is not allowed.");

    // THE ALLOWED DIRECTORIES MUST NOT EXIST WHEN UNIT TESTS RUN

    // Note: Not possible to test missing hardcoded directory.

    testRoot!"admin NoSuchDir"
            (`
                  # root "/mnt"`,
             `
                  root "/tmpNotExistingForTest"
                  allow_root "/tmpNotExistingForTest"`,
             null,
             "No such directory: /tmpNotExistingForTest");
    write("/tmp/NotExistingForTest", "please remove this file.");
    scope(exit)
        removeIfExists("/tmp/NotExistingForTest");
    testRoot!"admin NotADir"
            (`
                  # root "/mnt"`,
             `
                  root "/tmp/NotExistingForTest"
                  allow_root "/tmp/NotExistingForTest"`,
             null,
             "Not a directory: /tmp/NotExistingForTest");

    testRoot!"user NoSuchDir"
            (`
                  root "/tmpNotExistingForTest"`,
             `
                  root "/tmp"
                  allow_root "/tmpNotExistingForTest" "/mnt" "/media/${user}"`,
             null,
             "No such directory: /tmpNotExistingForTest");
    testRoot!"user NotADir"
            (`
                  root "/tmp/NotExistingForTest"`,
             `
                  root "/tmp"
                  allow_root "/tmp/NotExistingForTest"`,
             null,
             "Not a directory: /tmp/NotExistingForTest");

    // Note: Not possible to test not allowed missing hardcoded directory.

    testRoot!"not allowed missing admin root"
            (`
                  #root "/mnt"`,
             `
                  root "/tmpNotExistingForTest"
                  allow_root "/media" "/media/${user}"`,
             null,
             "No such directory: /tmpNotExistingForTest");

    testRoot!"not allowed missing user root"
            (`
                  root "/tmpNotExistingForTest"`,
             `
                  root "/tmp"
                  allow_root "/media" "/media/${user}"`,
             null,
             "No such directory: /tmpNotExistingForTest");


    // TESTS WITH SIMPLE ${PATTERN} REPLACEMENTS

    testRoot!("admin home media")
            (`
                  # root "/mnt"`,
             `
                  root "${home}/media"
                  allow_root "${home}/media" "/media/${user}" "/tmp"`,
             tmpHome ~ "/media");

    testRoot!"user home mnt"
            (`
                  root "${home}/mnt"`,
             `
                  root "/tmp"
                  allow_root "/media" "${home}/mnt" "/media/${user}"`,
             tmpHome ~ "/mnt");

    get_dir(tmpHome ~ "/media/testGrp");
    get_dir(tmpHome ~ "/media/testUser");
    get_dir(tmpHome ~ "/mnt/testUser");
    get_dir(tmpHome ~ "/mnt/testGrp");
    testRoot!("admin home media group")
            (`
                  # root "/mnt"`,
             `
                  root "${home}/media/${group}"
                  allow_root "${home}/media/${group}" "/media" "/tmp"`,
             tmpHome ~ "/media/testGrp");

    testRoot!"user home mnt"
            (`
                  root "${home}/mnt/${user}"`,
             `
                  root "/tmp"
                  allow_root "/media" "${home}/mnt/${user}" "/media/${user}"`,
             tmpHome ~ "/mnt/testUser");

    testRoot!"not allowed admin home media"
            (`
                  #root "/mnt"`,
             `
                  root "${home}/media/${group}"
                  allow_root "/media" "/media/${user}"`,
             null,
             "Mount root directory '${home}/media/${group}' is not allowed.");

    testRoot!"not allowed user home mnt"
            (`
                  root "${home}/mnt"`,
             `
                  root "/tmp"
                  allow_root "/media" "/media/${user}"`,
             null,
             "Mount root directory '${home}/mnt' is not allowed.");

    // TESTS WITH (DIS)ALLOWED HOME
    testRoot!"admin home"
            (`
                  # root "/mnt"`,
             `
                  root "${home}"
                  allow_root "/media" "home" "/media/${user}"`,
             tmpHome);
    testRoot!"admin home/media"
            (`
                  # root "/mnt"`,
             `
                  root "${home}/media"
                  allow_root "/media" "home" "/media/${user}"`,
             tmpHome ~ "/media");
    testRoot!"not allowed admin home media"
            (`
                  # root "${home}/mnt"`,
             `
                  root "${home}/media"
                  allow_root "/media" "/media/${user}"`,
             null,
             "Mount root directory '${home}/media' is not allowed.");
    testRoot!"user home/mnt"
            (`
                  root "${home}/mnt/${user}"`,
             `
                  root "${home}/media"
                  allow_root "home" "/media/${user}"`,
             tmpHome ~ "/mnt/testUser");
    testRoot!"not allowed user home/mnt"
            (`
                  root "${home}/mnt/${group}"`,
             `
                  root "${home}/media"
                  allow_root "/media/${user}"`,
             null,
             "Mount root directory '${home}/mnt/${group}' is not allowed.");

    // TESTS WITH (DIS)ALLOWED OWNER
    isTestPathOwner = true;
    testRoot!"admin owner media"
            (`
                  # root "/mnt"`,
             `
                  root "${home}/media/${user}"
                  allow_root "/media" "owner" "/media/${user}"`,
             tmpHome ~ "/media/testUser");
    testRoot!"not allowed admin owner media"
            (`
                  # root "${home}/mnt"`,
             `
                  root "/tmp"
                  allow_root "/media" "home"`,
             null,
             "Mount root directory '/tmp' is not allowed.");
    testRoot!"user owner mnt"
            (`
                  root "${home}/mnt/${user}"`,
             `
                  root "${home}/media"
                  allow_root "/media" "owner"`,
             tmpHome ~ "/mnt/testUser");
    testRoot!"not allowed user owner mnt"
            (`
                  root "${home}/mnt/${group}"`,
             `
                  root "${home}/media"
                  allow_root "/media"`,
             null,
             "Mount root directory '${home}/mnt/${group}' is not allowed.");
}


/**
 * Create a configuration with several configuration sources.
 *
 * The first ones are tried first, the next ones contain default values.
 */
private Config getConfig(string[] sources ...)
{
    auto cp = new Config();

    foreach (source; sources)
    {
        cp.addSource(source);
    }

    return cp;
}


private Config getSysConfig(string sysCfgFile)
{
    auto cp = new Config();

    cp.addSource(sysCfgFile);
    cp.addSource(getDfltSysConfig());

    return cp;
}


// mountroot test
unittest
{
    assert(getRoot() == "/media",
           "getRoot() == " ~ getRoot());
}

// Default filesystem configuration test
unittest
{
    import osutil : removeIfExists;

    auto sysCfg = getSysConfig(getSysCfgFile("fmount.dflt.conf"));

    enum string dflt = "default for missing value";

    // First test the default system configuration.

    assert(sysCfg.get("root", dflt) == "/media",
           "root == " ~ sysCfg.get("root", dflt));

    string[] dfltRoots;
    assert(sysCfg.getValues("allow_root", dfltRoots)
           == ["/media", "/mnt", "owner"],
           _f!"allow_root == %s"
              (sysCfg.getValues!string("allow_root", dfltRoots)));

    auto fs = sysCfg.getSubConfig("fs");
    assert(fs.get("missingValue", dflt) == dflt);
    assert(fs.get("all", dflt) == "user,noatime,noexec,nodev",
           "'fs.all' == " ~ fs.get("all", dflt));
    assert(fs.get("fat", dflt) == "user,dirsync,uid=${uid},gid=${gid},utf8",
           "'fs.fat' == " ~ fs.get("fat", dflt));
    assert(fs.get("vfat", dflt) == "user,dirsync,uid=${uid},gid=${gid},utf8",
           "'fs.vfat' == " ~ fs.get("vfat", dflt));
    assert(fs.get("ntfs", dflt) == "user,nls=utf8,uid=${uid},gid=${gid}",
           "'fs.ntfs' == " ~ fs.get("ntfs", dflt));
    assert(fs.get("iso9660", dflt) == "user,ro,utf8,unhide",
           "'fs.iso9660' == " ~ fs.get("iso9660", dflt));
    assert(fs.get("btrfs", dflt) == "user,autodefrag,compress",
           "'fs.btrfs' == " ~ fs.get("btrfs", dflt));
    assert(fs.get("udf", dflt) == "user,iocharset=utf8",
           "'fs.udf' == " ~ fs.get("udf", dflt));
    assert(fs.get("ufs", dflt) == "sync",
           "'fs.ufs' == " ~ fs.get("ufs", dflt));
    assert(fs.get("dflt", dflt) == "sync,dirsync",
           "'fs.dflt' == " ~ fs.get("dflt", dflt));

    // Then test the default system+user configuration.

    auto usrCfg = getConfig(getUsrCfgFile("fmountrc.dflt"),
                            USR_CONFIG_FMT_EXAMPLE,
                            getSysCfgFile("fmount.dflt.conf"),
                            getDfltSysConfig());
    auto usrFs = usrCfg.getSubConfig("fs");
    assert(usrFs.get("all", dflt) == "async,noatime,noexec,nodev",
           "'fs.all' == " ~ usrFs.get("all", dflt));
    assert(usrFs.get("btrfs", dflt) == "users,diratime,relatime,autodefrag",
           "'fs.btrfs' == " ~ usrFs.get("btrfs", dflt));
}


/**
 * High level exception.
 *
 * `UserConfigExceotion` is raised when a user tries to bypass the system
 * security defined in the administrator or default system configuration.
 */
class UserConfigException : Exception
{
    import std.exception: basicExceptionCtors;
    mixin basicExceptionCtors;
}

