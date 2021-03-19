// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_COMMON_UI_UTIL_BUTTON_UTIL_H_
#define IOS_CHROME_COMMON_UI_UTIL_BUTTON_UTIL_H_

#import <UIKit/UIKit.h>

extern const CGFloat kButtonVerticalInsets;

// Returns primary action button with rounded corners.
UIButton* PrimaryActionButton(BOOL pointer_interaction_enabled);

#endif  // IOS_CHROME_COMMON_UI_UTIL_BUTTON_UTIL_H_
