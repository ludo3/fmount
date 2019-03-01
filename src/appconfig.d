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
import std.format;
import std.stdio : writeln;

// Dependencies
import sdlang : Tag, parseFile, parseSource;

import argsutil : VbLevel, verbose;
import config;
import constvals : confdir_name, conffile_name;
import dutil : printThChain;
import osutil : get_dir, getRealUserAndGroup, jn, join_paths;

/// The default directory under which mountpoints are created.
enum DfltMountRoot = "/media";

/++
From mountpy:

default_options = 'users,noatime,sync,dirsync'
default_options2 = 'users,noatime,dirsync'

# ('filesystem_name', 'filesystem_options')
fs_options = {
'vfat': default_options2+',uid=%(uid)s,gid=%(gid)s,utf8',
'msdos': default_options2+',uid=%(uid)s,gid=%(gid)s,utf8',
'iso9660': 'users,ro,utf8,unhide',
'ntfs': 'users,ro,nls=utf8,uid=%(uid)s,gid=%(gid)s',
'auto': default_options
}

try_filesystems = ['vfat','msdos','iso9660','ntfs','auto']
+/

// TODO automatic ssd option for btrfs on encrypted SSD physical devices.


/**
 * Retrieve the configuration directory.
 */
string get_confdir()
{
    string root;

    version(unittest)
    {
        import std.file : deleteme;
        root = deleteme;
    }
    else
        root = "~";

    return get_dir(join_paths(root, confdir_name));
}


private enum DFLT_CONFIG_FMT = `#!/usr/bin/env fmount --config
# The directory containing all mountpoints handled by fmount.
# It is usually /media, sometimes /mnt.
mountroot "${DfltMountRoot}"

# Notes: usual mount options:
#   default = rw, suid, dev, exec, auto, nouser, async, relatime
#   user = (ordinary)user, noexec, nosuid, nodev
#   users = (any)user, noexec, nosuid, nodev
#   group = user(of that group), nosuid, nodev
#   owner = user(owner of the device), nosuid, nodev
#
fs {
    # Notes: below are the fmount options:
    all "noatime,noexec,nodev"
    fat "users,dirsync,uid=${uid},gid=${gid},utf8"
    vfat "users,dirsync,uid=${uid},gid=${gid},utf8"
    ntfs "users,nls=utf8,uid=${uid},gid=${gid}"
    iso9660 "users,ro,utf8,unhide"
    btrfs "users,autodefrag,compress"
    udf "users,iocharset=utf8"
    ufs "sync"
    dflt "sync,dirsync"
}
`;


/// Retrieve the default configuration.
string getDfltConfig()
{
    string[] uid_gid = getRealUserAndGroup().split(":");

    return DFLT_CONFIG_FMT
           .replace("${DfltMountRoot}", DfltMountRoot)
           .replace("${uid}", uid_gid[0])
           .replace("${gid}", uid_gid[1]);
}

/**
 * Retrieve the directory at which the directories are created.
 */
string get_mountroot()
{
    return appcfg.get!string("mountroot");
}

/// Retrieve the current configuration.
@property Config appcfg() { return getConfig(get_confdir(), "fmount.conf"); }


private Config getConfig(string confdir, string filename)
{
    // FIXME split configuration into system and user.
    immutable config_file = jn(confdir, filename);

    auto cp = new Config();
    cp.addSource(config_file);
    // FIXME manage both system and user configuration files.
    cp.addSource(getDfltConfig());
    return cp;
}


// mountroot test
unittest
{
    assert(get_mountroot() == "/media");
}

// TODO finish default configuration test
unittest
{
    import osutil : removeIfExists;

    auto cfg = getConfig(get_confdir(), "fmount.dflt.conf");

    auto fs = cfg.getSubConfig("fs");

    assert(fs.get("missingValue", "default for missing value")
           ==
           "default for missing value");
    assert(fs.get("all", "default for missing value")
           ==
           "noatime,noexec,nodev",
           "'fs.all' == " ~ fs.get("all", ""));
           /+
    fat "users,dirsync,uid=${uid},gid=${gid},utf8"
    vfat "users,dirsync,uid=${uid},gid=${gid},utf8"
    ntfs "users,nls=utf8,uid=${uid},gid=${gid}"
    iso9660 "users,ro,utf8,unhide"
    btrfs "users,autodefrag,compress"
    udf "users,iocharset=utf8"
    ufs "sync"
    dflt "sync,dirsync"
           +/
}


