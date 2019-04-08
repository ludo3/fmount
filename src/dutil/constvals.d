// Written in the D programming language.

/**
Constants for the `DLang utilities` section of the `fmount` project.

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
module dutil.constvals;

import std.algorithm.searching : minElement;
import std.conv : octal;


/// verbose type
enum VbLevel
{
    /// Print errors.
    None,

    /// Print errors and warnings.
    Warn,

    /// Print errors, warnings and informations.
    Info,

    /// Print more informations in order to check small issues.
    More,

    /// Print as much informations as possible, for debugging purpose.
    Dbug
}


/// The mode for user-only read-write files.
static immutable ushort ModePrivateRW = octal!600;

/// The mode for user-only read-write directories.
static immutable ushort ModePrivateRWX = octal!700;

/// The mode for user-only write directories.
static immutable ushort ModePrivateWX = octal!300;


/// Switch (enable or disable) some values
struct With(string InstanceName)
{
    /// The instance name.
    enum string Name = InstanceName;

    /// The instance type.
    alias Type = With!Name;

    /// Disabling value.
    enum Type No = Type(false);

    /// Enabling value.
    enum Type Yes = Type(true);

    /// Constructor.
    this(bool boo)
    {
        _value = boo;
    }

    private bool _value;
}


