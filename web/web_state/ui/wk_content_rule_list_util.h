// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_WEB_WEB_STATE_UI_WK_CONTENT_RULE_LIST_UTIL_H_
#define IOS_WEB_WEB_STATE_UI_WK_CONTENT_RULE_LIST_UTIL_H_

#import <Foundation/Foundation.h>

namespace web {
enum class CookieBlockingMode;

// Creates the rules json as a string for cookie blocking following the format
// expected by the Content Blocker API.
NSString* CreateCookieBlockingJsonRuleList(CookieBlockingMode block_mode);

}  // namespace web

#endif  // IOS_WEB_WEB_STATE_UI_WK_CONTENT_RULE_LIST_UTIL_H_
