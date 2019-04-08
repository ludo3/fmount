// Written in the D programming language.

/**
Constants for the `devices` section of the `fmount` project.

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
module devices.constvals;


/// The device directories.
enum DevDir : string {
    /// Device root directory.
    Root = "/dev",

    /// Disk root directory.
    Disk = Root ~ "/disk",

    /// Device mapper directory.
    Dm = Root ~ "/mapper",

    /// Device label directory.
    Label = Disk ~ "/by-label",

    /// Device (short) partition UUID directory.
    PartUuid = Disk ~ "/by-partuuid",

    /// Device hwardware path directory.
    Path = Disk ~ "/by-path",

    /// Device (long) UUID directory.
    Uuid = Disk ~ "/by-uuid",
}

/// The device mapper directory used by cryptsetup.
static immutable string DevMapperDir = DevDir.Root ~ "/mapper";


