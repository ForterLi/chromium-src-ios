// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/web/web_state/ui/crw_context_menu_element_fetcher.h"

#import <WebKit/WebKit.h>

#include "base/macros.h"
#import "base/test/ios/wait_util.h"
#include "ios/testing/scoped_block_swizzler.h"
#import "ios/web/js_features/context_menu/context_menu_constants.h"
#import "ios/web/public/test/web_view_content_test_util.h"
#import "ios/web/test/web_test_with_web_controller.h"
#import "ios/web/web_state/ui/crw_legacy_context_menu_controller.h"
#import "ios/web/web_state/ui/crw_web_controller.h"
#import "ios/web/web_state/web_state_impl.h"
#include "testing/gtest/include/gtest/gtest.h"
#include "testing/gtest_mac.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {
// This is the timeout used while waiting for the JavaScript to complete. The
// general kWaitForJSCompletionTimeout isn't used because one of the test is
// supposed to not complete and so will wait for the whole duration of the
// timeout. This constant is smaller to speed tests up. This constant is used in
// both the "successful" JavaScript calls and the "failing" JavaScript calls. It
// ensures that in the context of this test, the JavaScript completes in the
// given timespan (and so it ensures that if the "failing" JavaScript tests
// pass, it is because the JavaScript isn't called and not because it didn't
// have time to complete).
const CGFloat kFetcherJSTimeout = 1.0;
}  // namespace

namespace web {
class CRWContextMenuElementFetcherTest : public WebTestWithWebController {
 public:
  CRWContextMenuElementFetcherTest() {
    // Disable the existing long press handling to avoid duplicating message
    // handlers.
    swizzler_ = std::make_unique<ScopedBlockSwizzler>(
        [CRWLegacyContextMenuController class],
        @selector(initWithWebView:webState:), ^id(id self) {
          return nil;
        });
  }

  void SetUp() override {
    WebTestWithWebState::SetUp();
    WKWebView* web_view = [web_controller() ensureWebViewCreated];
    fetcher_ =
        [[CRWContextMenuElementFetcher alloc] initWithWebView:web_view
                                                     webState:web_state()];
  }

  // Loads a page containing a link and waits until the link is present on the
  // page, making sure that the HTML is correctly injected.
  bool LoadHtmlPage() WARN_UNUSED_RESULT {
    NSString* html =
        @"<html><head>"
         "<style>body { font-size:14em; }</style>"
         "<meta name=\"viewport\" content=\"user-scalable=no, width=100\">"
         "</head><body><p><a id=\"linkID\" "
         "href=\"http://destination/\">link</a></p></body></html>";

    LoadHtml(html);

    bool element_present = test::WaitForWebViewContainingElement(
        web_state(), [ElementSelector selectorWithElementID:"linkID"]);
    if (element_present) {
      // If the element is present, we still need a small delay to let all the
      // scripts be injected in the page.
      base::test::ios::SpinRunLoopWithMinDelay(
          base::TimeDelta::FromSecondsD(0.5));
    }
    return element_present;
  }

  CRWContextMenuElementFetcher* GetFetcher() { return fetcher_; }

 private:
  std::unique_ptr<ScopedBlockSwizzler> swizzler_;
  CRWContextMenuElementFetcher* fetcher_;
};

// Tests that the fetcher is triggering a callback for one element.
TEST_F(CRWContextMenuElementFetcherTest, FetchOneElement) {
  EXPECT_TRUE(LoadHtmlPage());

  CRWContextMenuElementFetcher* fetcher = GetFetcher();
  __block bool callback_called = false;
  [fetcher fetchDOMElementAtPoint:CGPointMake(10, 10)
                completionHandler:^(const web::ContextMenuParams&) {
                  callback_called = true;
                }];

  EXPECT_TRUE(base::test::ios::WaitUntilConditionOrTimeout(kFetcherJSTimeout, ^{
    return callback_called;
  }));
}

// Tests that cancelled fetches don't trigger callback.
TEST_F(CRWContextMenuElementFetcherTest, CancelFetch) {
  EXPECT_TRUE(LoadHtmlPage());

  CRWContextMenuElementFetcher* fetcher = GetFetcher();
  __block bool callback_called = false;
  [fetcher fetchDOMElementAtPoint:CGPointMake(10, 10)
                completionHandler:^(const web::ContextMenuParams&) {
                  callback_called = true;
                }];
  [fetcher cancelFetches];

  // The callback should never be called.
  EXPECT_FALSE(
      base::test::ios::WaitUntilConditionOrTimeout(kFetcherJSTimeout, ^{
        return callback_called;
      }));
}

}  // namespace web
