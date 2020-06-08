// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/web/web_state/ui/wk_content_rule_list_util.h"

#include "ios/web/public/browsing_data/cookie_blocking_mode.h"
#include "testing/gtest/include/gtest/gtest.h"
#import "testing/gtest_mac.h"
#include "testing/platform_test.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace web {
namespace {

using WKContentRuleListUtilTest = PlatformTest;

// Tests that the JSON created for block mode contains the correct keys.
TEST_F(WKContentRuleListUtilTest, JSONBlock) {
  NSString* rules_string =
      CreateCookieBlockingJsonRuleList(CookieBlockingMode::kBlock);
  NSData* rules_data = [rules_string dataUsingEncoding:NSUTF8StringEncoding];
  id json = [NSJSONSerialization JSONObjectWithData:rules_data
                                            options:0
                                              error:nil];

  // The Apple API says Content Blocker rules must be an array of rules.
  ASSERT_TRUE([json isKindOfClass:[NSArray class]]);

  id block_rule = json[0];
  ASSERT_TRUE([block_rule isKindOfClass:[NSDictionary class]]);
  ASSERT_NSEQ(@".*", block_rule[@"trigger"][@"url-filter"]);
  ASSERT_NSEQ(@"block-cookies", block_rule[@"action"][@"type"]);
}

// Tests that the JSON created for block third party mode contains the correct
// keys.
TEST_F(WKContentRuleListUtilTest, JSONBlockThirdParty) {
  NSString* rules_string =
      CreateCookieBlockingJsonRuleList(CookieBlockingMode::kBlockThirdParty);
  NSData* rules_data = [rules_string dataUsingEncoding:NSUTF8StringEncoding];
  id json = [NSJSONSerialization JSONObjectWithData:rules_data
                                            options:0
                                              error:nil];

  // The Apple API says Content Blocker rules must be an array of rules.
  ASSERT_TRUE([json isKindOfClass:[NSArray class]]);

  id block_rule = json[0];
  ASSERT_TRUE([block_rule isKindOfClass:[NSDictionary class]]);
  ASSERT_NSEQ(@".*", block_rule[@"trigger"][@"url-filter"]);
  ASSERT_NSEQ(@"third-party", block_rule[@"trigger"][@"load-type"][0]);
  ASSERT_NSEQ(@"block-cookies", block_rule[@"action"][@"type"]);
}

}  // namespace
}  // namespace web
