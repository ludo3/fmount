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

import std.format;
import std.stdio : writeln;

import argsutil : VbLevel, verbose;
import config;
import constvals : conffile_name;
import dutil : printThChain;
import osutil : jn;


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

private enum DFLT_CONFIG_FMT = q"MULTILINE
# The directory containing all mountpoints handled by fmount.
# It is usually /media, sometimes /mnt.
mountroot=%s

[system]
# Notes: usual mount options:
#   default = rw, suid, dev, exec, auto, nouser, async, relatime
#   user = (ordinary)user, noexec, nosuid, nodev
#   users = (any)user, noexec, nosuid, nodev
#   group = user(of that group), nosuid, nodev
#   owner = user(owner of the device), nosuid, nodev
# Notes: below are the fmount options:
all=noatime,noexec,nodev
fat=users,dirsync,uid=%(uid)s,gid=%(gid)s,utf8
vfat=users,dirsync,uid=%(uid)s,gid=%(gid)s,utf8
ntfs=users,nls=utf8,uid=%(uid)s,gid=%(gid)s
iso9660=users,ro,utf8,unhide
btrfs=users,autodefrag,compress
udf=users,iocharset=utf8
ufs=sync
dflt=sync,dirsync
MULTILINE";


/// Retrieve the default configuration.
string getDfltConfig()
{
    return format(DFLT_CONFIG_FMT, DfltMountRoot);
}

/**
 * Retrieve the directory at which the directories are created.
 */
string get_mountroot()
{
    // FIXME split configuration into system and user.
    auto config_file = jn(get_confdir(), "fmount.conf");
    auto cp = get_config(conffile_name, getDfltConfig());
    auto section_name = "common";

    if (!cp.hasSection(section_name))
        cp.addSection(new Section(0, "["~section_name~"]", section_name));

    auto section = cp.getSection(section_name);
    if (section.hasKey("mountroot"))
        return section.getString("mountroot");

    return DfltMountRoot;
}

