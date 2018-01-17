// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_TOOLBAR_CLEAN_TOOLBAR_TAB_GRID_BUTTON_H_
#define IOS_CHROME_BROWSER_UI_TOOLBAR_CLEAN_TOOLBAR_TAB_GRID_BUTTON_H_

#import "ios/chrome/browser/ui/toolbar/clean/toolbar_button.h"

// ToolbarButton for displaying the number of tab.
@interface ToolbarTabGridButton : ToolbarButton

// Sets the number of tabs displayed by this button to |tabCount|. If |tabCount|
// is more than 99, it shows a smiley instead.
- (void)setTabCount:(int)tabCount;

@end

#endif  // IOS_CHROME_BROWSER_UI_TOOLBAR_CLEAN_TOOLBAR_TAB_GRID_BUTTON_H_
