// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/web/public/test/web_state_test_util.h"

#include "base/logging.h"
#include "base/run_loop.h"
#include "base/strings/sys_string_conversions.h"
#import "base/test/ios/wait_util.h"
#import "ios/web/navigation/crw_wk_navigation_states.h"
#import "ios/web/public/navigation/navigation_manager.h"
#import "ios/web/public/web_state.h"
#import "ios/web/web_state/ui/crw_web_controller.h"
#import "ios/web/web_state/web_state_impl.h"
#include "url/gurl.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

using base::test::ios::WaitUntilConditionOrTimeout;
using base::test::ios::kWaitForJSCompletionTimeout;
using base::test::ios::kWaitForPageLoadTimeout;

namespace web {
namespace test {

id ExecuteJavaScript(NSString* script, web::WebState* web_state) {
  __block id execution_result = nil;
  __block bool execution_completed = false;
  [GetWebController(web_state)
      executeJavaScript:script
      completionHandler:^(id result, NSError* error) {
        // Most of executed JS does not return the result, and there is no need
        // to log WKErrorJavaScriptResultTypeIsUnsupported error code.
        if (error && error.code != WKErrorJavaScriptResultTypeIsUnsupported) {
          DLOG(WARNING) << "Script execution of:"
                        << base::SysNSStringToUTF8(script)
                        << "\nfailed with error: "
                        << base::SysNSStringToUTF8(error.description);
        }
        execution_result = [result copy];
        execution_completed = true;
      }];
  if (!WaitUntilConditionOrTimeout(kWaitForJSCompletionTimeout, ^{
        return execution_completed;
      })) {
    LOG(ERROR) << "Timed out trying to execute: " << script;
  }

  return execution_result;
}

CRWWebController* GetWebController(web::WebState* web_state) {
  web::WebStateImpl* web_state_impl =
      static_cast<web::WebStateImpl*>(web_state);
  return web_state_impl->GetWebController();
}

void LoadHtml(NSString* html, const GURL& url, web::WebState* web_state) {
  // Initiate asynchronous HTML load.
  CRWWebController* web_controller = GetWebController(web_state);
  CHECK_EQ(web::WKNavigationState::FINISHED, web_controller.navigationState);

  // If the underlying WKWebView is empty, first load a placeholder to create a
  // WKBackForwardListItem to store the NavigationItem associated with the
  // |-loadHTML|.
  // TODO(crbug.com/777884): consider changing |-loadHTML| to match WKWebView's
  // |-loadHTMLString:baseURL| that doesn't create a navigation entry.
  if (!web_state->GetNavigationManager()->GetItemCount()) {
    GURL placeholder_url(url::kAboutBlankURL);

    web::NavigationManager::WebLoadParams params(placeholder_url);
    web_state->GetNavigationManager()->LoadURLWithParams(params);

    CHECK(WaitUntilConditionOrTimeout(kWaitForPageLoadTimeout, ^{
      return web_controller.navigationState == web::WKNavigationState::FINISHED;
    }));
  }

  [web_controller loadHTML:html forURL:url];
  CHECK_EQ(web::WKNavigationState::REQUESTED, web_controller.navigationState);

  // Wait until the page is loaded.
  CHECK(WaitUntilConditionOrTimeout(kWaitForPageLoadTimeout, ^{
    base::RunLoop().RunUntilIdle();
    return web_controller.navigationState == web::WKNavigationState::FINISHED;
  }));

  // Wait until the script execution is possible. Script execution will fail if
  // WKUserScript was not jet injected by WKWebView.
  CHECK(WaitUntilConditionOrTimeout(kWaitForPageLoadTimeout, ^bool {
    return [ExecuteJavaScript(@"0;", web_state) isEqual:@0];
  }));
}

void LoadHtml(NSString* html, web::WebState* web_state) {
  GURL url("https://chromium.test/");
  LoadHtml(html, url, web_state);
}

}  // namespace test
}  // namespace web