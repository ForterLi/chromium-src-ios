// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_COMMANDS_BROWSER_COMMANDS_H_
#define IOS_CHROME_BROWSER_UI_COMMANDS_BROWSER_COMMANDS_H_

// Protocol for commands that will generally be handled by the "current tab",
// which in practice is the BrowserViewController instance displaying the tab.
@protocol BrowserCommands

// Closes the current tab.
- (void)closeCurrentTab;

// Navigates backwards in the current tab's history.
- (void)goBack;

// Navigates forwards in the current tab's history.
- (void)goForward;

// Stops loading the current web page.
- (void)stopLoading;

// Reloads the current web page
- (void)reload;

@end

#endif  // IOS_CHROME_BROWSER_UI_COMMANDS_BROWSER_COMMANDS_H_
