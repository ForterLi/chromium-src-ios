// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_UTIL_MULTI_WINDOW_SUPPORT_H_
#define IOS_CHROME_BROWSER_UI_UTIL_MULTI_WINDOW_SUPPORT_H_

// Returns true if multiwindow is supported on this OS version and is enabled in
// the current build configuration. Does not check if this device can actually
// show multiple windows (e.g. on iPhone): use [UIApplication
// supportsMultipleScenes] instead.
bool IsMultiwindowSupported();

// Returns true if the iOS13 UIScene-based startup flow is supported, regardless
// of whether multiple windows are permitted. This always returns true if
// IsMultiwindowSupported() returns true.
bool IsSceneStartupSupported();

// Returns true iff multiple windows can be opened, i.e. when the multiwindow
// build flag is on, the device is running on iOS 13+ and it's a compatible
// iPad.
bool IsMultipleScenesSupported();

#endif  // IOS_CHROME_BROWSER_UI_UTIL_MULTI_WINDOW_SUPPORT_H_
