// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import <ChromeWebView/ChromeWebView.h>
#import <Foundation/Foundation.h>

#import "base/test/ios/wait_util.h"
#import "ios/web/common/uikit_ui_util.h"
#import "ios/web_view/test/observer.h"
#import "ios/web_view/test/web_view_inttest_base.h"
#import "ios/web_view/test/web_view_test_util.h"
#import "net/base/mac/url_conversions.h"
#include "net/test/embedded_test_server/embedded_test_server.h"
#include "testing/gtest_mac.h"
#include "url/gurl.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace ios_web_view {

// Tests if a CWVWebView can be created from a WKWebViewConfiguration outside
// //ios/web
class WebViewFromWKWebViewConfigurationTest : public WebViewInttestBase {
 public:
  // This method is called by the delegate method called when window.open() is
  // called, and the |webView| argument is the newly opened CWVWebView by the
  // window.open() call in a normal WKWebView. Saves the |webView| for further
  // tests and inserts it into the View Hierarchy tree.
  void SetWebView(CWVWebView* webView) {
    [web_view_ removeFromSuperview];
    web_view_ = webView;
    UIViewController* view_controller = [GetAnyKeyWindow() rootViewController];
    [view_controller.view addSubview:web_view_];
  }

  // This method is called by the delegate method called when window.open() is
  // called, and the |returned_wk_web_view| argument is the internal WKWebView
  // of the newly opened CWVWebView by the window.open() call in a normal
  // WKWebView. Saves the |returned_wk_web_view| for further tests.
  void SetReturnedWKWebView(WKWebView* returned_wk_web_view) {
    returned_wk_web_view_ = returned_wk_web_view;
  }

 protected:
  WebViewFromWKWebViewConfigurationTest() {
    // This |CWVWebView *web_view_| is inherited from the base class, but in
    // this test case I don't hope to use it, because I need to test a newly
    // opened CWVWebView by a window.open() call in a normal WKWebView, instead
    // of this one directly generated by the base class from default
    // configuration.
    [web_view_ removeFromSuperview];
    web_view_ = nil;
  }

  void GenerateTestPageUrls() {
    window1_url_ = GetUrlForPageWithHtmlBody("<p>page1</p>");
    window2_url_ = GetUrlForPageWithHtmlBody("<p>page2</p>");
  }

  WKWebView* returned_wk_web_view_ = nil;
  GURL window1_url_;
  GURL window2_url_;
};

}  // namespace ios_web_view

@interface WKUIDelegateForTest : NSObject <WKUIDelegate>
- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithTest:
    (ios_web_view::WebViewFromWKWebViewConfigurationTest*)test
    NS_DESIGNATED_INITIALIZER;
@end

@implementation WKUIDelegateForTest {
  ios_web_view::WebViewFromWKWebViewConfigurationTest* _test;
}

- (instancetype)initWithTest:
    (ios_web_view::WebViewFromWKWebViewConfigurationTest*)test {
  self = [super init];
  if (self) {
    _test = test;
  }
  return self;
}

- (WKWebView*)webView:(WKWebView*)webView
    createWebViewWithConfiguration:(WKWebViewConfiguration*)configuration
               forNavigationAction:(WKNavigationAction*)action
                    windowFeatures:(WKWindowFeatures*)windowFeatures {
  WKWebView* created_web_view = nil;
  _test->SetWebView([[CWVWebView alloc]
         initWithFrame:UIScreen.mainScreen.bounds
         configuration:[CWVWebViewConfiguration defaultConfiguration]
       WKConfiguration:configuration
      createdWKWebView:&created_web_view]);
  _test->SetReturnedWKWebView(created_web_view);
  return created_web_view;
}
@end

@interface NavigationFinishedObserver
    : NSObject <WKNavigationDelegate, CWVNavigationDelegate>
@property(nonatomic) BOOL navigationFinished;
@end

@implementation NavigationFinishedObserver
- (void)webView:(WKWebView*)webView
    didFinishNavigation:(WKNavigation*)navigation {
  self.navigationFinished = YES;
}
- (void)webViewDidFinishNavigation:(CWVWebView*)webView {
  self.navigationFinished = YES;
}
@end

namespace ios_web_view {

// Tests if a CWVWebView can be created from -[CWVWebView
// initWithFrame:configuration:WKConfiguration:createdWKWebView]
TEST_F(WebViewFromWKWebViewConfigurationTest, FromWKWebViewConfiguration) {
  ASSERT_TRUE(test_server_->Start());

  CGRect frame = UIScreen.mainScreen.bounds;
  WKWebViewConfiguration* config = [[WKWebViewConfiguration alloc] init];
  WKWebView* wk_web_view = [[WKWebView alloc] initWithFrame:frame
                                              configuration:config];
  WKUIDelegateForTest* wk_ui_delegate_for_test =
      [[WKUIDelegateForTest alloc] initWithTest:this];
  wk_web_view.UIDelegate = wk_ui_delegate_for_test;

  NavigationFinishedObserver* observer =
      [[NavigationFinishedObserver alloc] init];
  UIViewController* view_controller = [GetAnyKeyWindow() rootViewController];
  [view_controller.view addSubview:wk_web_view];

  // Loads a page in wk_web_view and waits for its completion
  GenerateTestPageUrls();
  wk_web_view.navigationDelegate = observer;
  [wk_web_view loadRequest:[[NSURLRequest alloc]
                               initWithURL:net::NSURLWithGURL(window1_url_)]];
  using base::test::ios::kWaitForPageLoadTimeout;
  ASSERT_TRUE(
      base::test::ios::WaitUntilConditionOrTimeout(kWaitForPageLoadTimeout, ^{
        return observer.navigationFinished;
      }));
  wk_web_view.navigationDelegate = nil;

  // Checks if the page in window1 (wk_web_view) is loaded, by a line of
  // JavaScript
  __block BOOL is_js_evaluated = NO;
  [wk_web_view evaluateJavaScript:@"document.body.innerText"
                completionHandler:^(NSString* result, NSError* error) {
                  ASSERT_FALSE(error);
                  EXPECT_NSEQ(@"page1", result);
                  is_js_evaluated = YES;
                }];
  using base::test::ios::kWaitForJSCompletionTimeout;
  ASSERT_TRUE(base::test::ios::WaitUntilConditionOrTimeout(
      kWaitForJSCompletionTimeout, ^{
        return is_js_evaluated;
      }));

  // Opens a new CWVWebView from the wk_web_view
  NSString* url_string = net::NSURLWithGURL(window2_url_).absoluteString;
  NSString* script =
      [NSString stringWithFormat:@"window.open('%@')", url_string];
  is_js_evaluated = NO;
  [wk_web_view evaluateJavaScript:script
                completionHandler:^(NSString* result, NSError* error) {
                  is_js_evaluated = YES;
                }];
  ASSERT_TRUE(base::test::ios::WaitUntilConditionOrTimeout(
      kWaitForJSCompletionTimeout, ^{
        return is_js_evaluated;
      }));
  ASSERT_TRUE(returned_wk_web_view_);
  ASSERT_TRUE(web_view_);

  // Waits for the page in window2 (CWVWebView *web_view_) to be loaded
  observer.navigationFinished = NO;
  web_view_.navigationDelegate = observer;
  ASSERT_TRUE(
      base::test::ios::WaitUntilConditionOrTimeout(kWaitForPageLoadTimeout, ^{
        return observer.navigationFinished;
      }));
  web_view_.navigationDelegate = nil;

  // Checks if the page in web_view_ is loaded successfully
  NSString* inner_text =
      test::EvaluateJavaScript(web_view_, @"document.body.innerText", nil);
  EXPECT_NSEQ(@"page2", inner_text);

  [wk_web_view removeFromSuperview];
}

}  // namespace ios_web_view
