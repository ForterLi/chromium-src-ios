// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_POPUP_MENU_PUBLIC_FEATURE_FLAGS_H_
#define IOS_CHROME_BROWSER_UI_POPUP_MENU_PUBLIC_FEATURE_FLAGS_H_

#include "base/feature_list.h"

// Feature to enable the new overflow menu;
extern const base::Feature kNewOverflowMenu;

// Whether the NewOverflowMenu feature is enabled.
bool IsNewOverflowMenuEnabled();

#endif  // IOS_CHROME_BROWSER_UI_POPUP_MENU_PUBLIC_FEATURE_FLAGS_H_
