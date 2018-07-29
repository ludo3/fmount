// Written in the D programming language.

/**
Definition of project-specific command line options.

The module args defines command line parsing functions and variables which are
specific to this project.

Currently this module relies on std.getopt module.

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
module mnt.umount;

import std.stdio : writeln;

void fumount(string[] args) {
    writeln("running fumount");
}

