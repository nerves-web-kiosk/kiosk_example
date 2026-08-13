<!--
  SPDX-FileCopyrightText: None
  SPDX-License-Identifier: CC0-1.0
-->
# Changelog

## v0.4.2

* Changes
  * Replace screensaver implementation with Myelin. Myelin is a library that
    uses WPE WebKit's web extension to add functionality to web pages. This
    simplifies the screensaver and also makes it work when browsing the general
    internet. (Thanks to @tomfarm for this library)
  * Update Nerves systems to Erlang 29.0.4

## v0.4.1

This release include dependency updates and a fix for RPi5 WPA3 SAE users.

## v0.4.0

This release brings in quite a few updates and experiments with using D-Bus to
control Cog rather than relying on restarting it to reset the URL.

* Changes
  * Update Nerves systems to use OTP 29, GCC 15.3, and Linux 6.18
  * Fix font rendering when using system fonts
  * Several supervision tree simplifications

## v0.3.0

This is a major update to the Nerves systems used for this demo that adjusts the
on-disk layout. As such, once upgraded, it's not possible to downgrade to v0.2.2
without reprogramming the entire MicroSD.

* Changes
  * Fix hardware cursor issue affecting Mesa3D on Raspberry Pis that would cause
    Weston to crash when using a mouse. This didn't affect touchscreen use.
  * Update Nerves systems to 2.0.1 versions. See Nerves systems for details, but
    the main update is that the demo now uses the Raspberry Pi tryboot feature
    so that early boot issues (like Linux kernel and Erlang boot script crashes)
    revert to previous good firmware rather than cycling.

## v0.2.2

* Changes
  * Update Nerves systems to 0.6.1 versions

## v0.2.1

* Fixes
  * Fix firmware release build script

## v0.2.0

* Changes
  * Changed project focus from being a barebones example to a web kiosk demo
  * Added a new home screen to provide general info and show features
  * Refreshed GPIO screen

## v0.1.0

Initial release
