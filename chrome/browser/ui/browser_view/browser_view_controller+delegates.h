// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_BROWSER_VIEW_BROWSER_VIEW_CONTROLLER_DELEGATES_H_
#define IOS_CHROME_BROWSER_UI_BROWSER_VIEW_BROWSER_VIEW_CONTROLLER_DELEGATES_H_

#import "ios/chrome/browser/ui/browser_view/browser_view_controller.h"
#import "ios/chrome/browser/ui/browser_view/common_tab_helper_delegate.h"

// Category on BrowserViewController that
// declares the BVC's conformance to several tab helper delegate protocols
// (enumerated in common_tab_helper_delegate.h) which are used to set up tab
// helpers. This category is scaffolding for refactoring these delegate
// responsibilities out of the BVC; its use should be limited, and the goal is
// to remove properties and protocols from it (and from the BVC).
@interface BrowserViewController (Delegates) <CommonTabHelperDelegate>

@end

#endif  // IOS_CHROME_BROWSER_UI_BROWSER_VIEW_BROWSER_VIEW_CONTROLLER_DELEGATES_H_