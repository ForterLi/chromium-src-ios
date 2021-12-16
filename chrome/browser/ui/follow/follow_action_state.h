// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_FOLLOW_FOLLOW_ACTION_STATE_H_
#define IOS_CHROME_BROWSER_UI_FOLLOW_FOLLOW_ACTION_STATE_H_

#import <Foundation/Foundation.h>

// The state of the "Follow" action. e.g. The state the Follow button in the
// Overflow menu.
typedef NS_ENUM(NSInteger, FollowActionState) {
  // "Follow" action is hidden.
  FollowActionStateHidden,
  // "Follow" action is shown but disabled.
  FollowActionStateDisabled,
  // "Follow" action is shown and enabled.
  FollowActionStateEnabld,
};

#endif  // IOS_CHROME_BROWSER_UI_FOLLOW_FOLLOW_ACTION_STATE_H_
