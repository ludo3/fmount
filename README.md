# fmount

## *mount or unmount hotpluggable/removable storages.*


## Introduction
fmount is a file system mount/unmount utility, mainly used to mount and unmount file systems
located on hotpluggable/removable storages.

## Requirements
TODO check: Phobos library?

## Features
Mount device(s)
Unmount device(s)
LUKS encrypted device support
Loop device support

## Data security
  * Any local user is authorized to work on local removable devices;
  * Only root is authorized to work on fixed devices;
  * Only the owner of a file or the administrator can work on it;

## User management
The fmount and fumount scripts can either be called with sudo or with super.

