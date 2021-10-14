// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/web/web_state/ui/crw_wk_ui_handler.h"

#include "base/logging.h"
#include "base/strings/sys_string_conversions.h"
#import "ios/web/navigation/wk_navigation_action_util.h"
#import "ios/web/navigation/wk_navigation_util.h"
#import "ios/web/public/ui/context_menu_params.h"
#import "ios/web/public/ui/java_script_dialog_type.h"
#import "ios/web/public/web_client.h"
#import "ios/web/web_state/ui/crw_legacy_context_menu_controller.h"
#import "ios/web/web_state/ui/crw_wk_ui_handler_delegate.h"
#import "ios/web/web_state/user_interaction_state.h"
#import "ios/web/web_state/web_state_impl.h"
#import "ios/web/web_view/wk_security_origin_util.h"
#import "ios/web/webui/mojo_facade.h"
#import "net/base/mac/url_conversions.h"
#include "url/gurl.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

@interface CRWWKUIHandler () {
  // Backs up property with the same name.
  std::unique_ptr<web::MojoFacade> _mojoFacade;
}

@property(nonatomic, assign, readonly) web::WebStateImpl* webStateImpl;

// Facade for Mojo API.
@property(nonatomic, readonly) web::MojoFacade* mojoFacade;

@end

@implementation CRWWKUIHandler

#pragma mark - CRWWebViewHandler

- (void)close {
  [super close];
  _mojoFacade.reset();
}

#pragma mark - Property

- (web::WebStateImpl*)webStateImpl {
  return [self.delegate webStateImplForWebViewHandler:self];
}

- (web::MojoFacade*)mojoFacade {
  if (!_mojoFacade)
    _mojoFacade = std::make_unique<web::MojoFacade>(self.webStateImpl);
  return _mojoFacade.get();
}

#pragma mark - WKUIDelegate

- (WKWebView*)webView:(WKWebView*)webView
    createWebViewWithConfiguration:(WKWebViewConfiguration*)configuration
               forNavigationAction:(WKNavigationAction*)action
                    windowFeatures:(WKWindowFeatures*)windowFeatures {
  // Do not create windows for non-empty invalid URLs.
  GURL requestURL = net::GURLWithNSURL(action.request.URL);
  if (!requestURL.is_empty() && !requestURL.is_valid()) {
    DLOG(WARNING) << "Unable to open a window with invalid URL: "
                  << requestURL.possibly_invalid_spec();
    return nil;
  }

  NSString* referrer = [action.request
      valueForHTTPHeaderField:web::wk_navigation_util::kReferrerHeaderName];
  GURL openerURL = referrer.length
                       ? GURL(base::SysNSStringToUTF8(referrer))
                       : [self.delegate documentURLForWebViewHandler:self];

  // There is no reliable way to tell if there was a user gesture, so this code
  // checks if user has recently tapped on web view. TODO(crbug.com/809706):
  // Remove the usage of -userIsInteracting when rdar://19989909 is fixed.
  bool initiatedByUser = [self.delegate UIHandler:self
                            isUserInitiatedAction:action];

  if (UIAccessibilityIsVoiceOverRunning()) {
    // -userIsInteracting returns NO if VoiceOver is On. Inspect action's
    // description, which may contain the information about user gesture for
    // certain link clicks.
    initiatedByUser = initiatedByUser ||
                      web::GetNavigationActionInitiationTypeWithVoiceOverOn(
                          action.description) ==
                          web::NavigationActionInitiationType::kUserInitiated;
  }

  web::WebState* childWebState = self.webStateImpl->CreateNewWebState(
      requestURL, openerURL, initiatedByUser);
  if (!childWebState)
    return nil;

  // WKWebView requires WKUIDelegate to return a child view created with
  // exactly the same |configuration| object (exception is raised if config is
  // different). |configuration| param and config returned by
  // WKWebViewConfigurationProvider are different objects because WKWebView
  // makes a shallow copy of the config inside init, so every WKWebView
  // owns a separate shallow copy of WKWebViewConfiguration.
  return [self.delegate UIHandler:self
      createWebViewWithConfiguration:configuration
                         forWebState:childWebState];
}

- (void)webViewDidClose:(WKWebView*)webView {
  if (self.webStateImpl && self.webStateImpl->HasOpener())
    self.webStateImpl->CloseWebState();
}

- (void)webView:(WKWebView*)webView
    runJavaScriptAlertPanelWithMessage:(NSString*)message
                      initiatedByFrame:(WKFrameInfo*)frame
                     completionHandler:(void (^)())completionHandler {
  [self runJavaScriptDialogOfType:web::JAVASCRIPT_DIALOG_TYPE_ALERT
                 initiatedByFrame:frame
                          message:message
                      defaultText:nil
                       completion:^(BOOL, NSString*) {
                         completionHandler();
                       }];
}

- (void)webView:(WKWebView*)webView
    runJavaScriptConfirmPanelWithMessage:(NSString*)message
                        initiatedByFrame:(WKFrameInfo*)frame
                       completionHandler:
                           (void (^)(BOOL result))completionHandler {
  [self runJavaScriptDialogOfType:web::JAVASCRIPT_DIALOG_TYPE_CONFIRM
                 initiatedByFrame:frame
                          message:message
                      defaultText:nil
                       completion:^(BOOL success, NSString*) {
                         if (completionHandler) {
                           completionHandler(success);
                         }
                       }];
}

- (void)webView:(WKWebView*)webView
    runJavaScriptTextInputPanelWithPrompt:(NSString*)prompt
                              defaultText:(NSString*)defaultText
                         initiatedByFrame:(WKFrameInfo*)frame
                        completionHandler:
                            (void (^)(NSString* result))completionHandler {
  GURL origin(web::GURLOriginWithWKSecurityOrigin(frame.securityOrigin));
  if (web::GetWebClient()->IsAppSpecificURL(origin)) {
    std::string mojoResponse =
        self.mojoFacade->HandleMojoMessage(base::SysNSStringToUTF8(prompt));
    completionHandler(base::SysUTF8ToNSString(mojoResponse));
    return;
  }

  [self runJavaScriptDialogOfType:web::JAVASCRIPT_DIALOG_TYPE_PROMPT
                 initiatedByFrame:frame
                          message:prompt
                      defaultText:defaultText
                       completion:^(BOOL, NSString* input) {
                         if (completionHandler) {
                           completionHandler(input);
                         }
                       }];
}

#if !defined(__IPHONE_13_0) || __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_13_0

// TODO(crbug.com/1131852): Preview depracted is iOS13+
- (BOOL)webView:(WKWebView*)webView
    shouldPreviewElement:(WKPreviewElementInfo*)elementInfo {
  return NO;
}

#endif  // End of >iOS13 deprecated block.

- (void)webView:(WKWebView*)webView
    contextMenuConfigurationForElement:(WKContextMenuElementInfo*)elementInfo
                     completionHandler:
                         (void (^)(UIContextMenuConfiguration* _Nullable))
                             completionHandler {
  web::WebStateDelegate* delegate = self.webStateImpl->GetDelegate();
  if (!delegate) {
    completionHandler(nil);
    return;
  }

  web::ContextMenuParams params;
  params.link_url = net::GURLWithNSURL(elementInfo.linkURL);

  delegate->ContextMenuConfiguration(self.webStateImpl, params,
                                     completionHandler);
}

- (void)webView:(WKWebView*)webView
     contextMenuForElement:(WKContextMenuElementInfo*)elementInfo
    willCommitWithAnimator:
        (id<UIContextMenuInteractionCommitAnimating>)animator {
  web::WebStateDelegate* delegate = self.webStateImpl->GetDelegate();
  if (!delegate) {
    return;
  }

  delegate->ContextMenuWillCommitWithAnimator(self.webStateImpl, animator);
}

#pragma mark - Helper

// Helper to respond to |webView:runJavaScript...| delegate methods.
// |completionHandler| must not be nil.
- (void)runJavaScriptDialogOfType:(web::JavaScriptDialogType)type
                 initiatedByFrame:(WKFrameInfo*)frame
                          message:(NSString*)message
                      defaultText:(NSString*)defaultText
                       completion:(void (^)(BOOL, NSString*))completionHandler {
  DCHECK(completionHandler);

  // JavaScript dialogs should not be presented if there is no information about
  // the requesting page's URL.
  GURL requestURL = net::GURLWithNSURL(frame.request.URL);
  if (!requestURL.is_valid()) {
    completionHandler(NO, nil);
    return;
  }

  if (self.webStateImpl->GetVisibleURL().DeprecatedGetOriginAsURL() !=
          requestURL.DeprecatedGetOriginAsURL() &&
      frame.mainFrame) {
    // Dialog was requested by web page's main frame, but visible URL has
    // different origin. This could happen if the user has started a new
    // browser initiated navigation. There is no value in showing dialogs
    // requested by page, which this WebState is about to leave. But presenting
    // the dialog can lead to phishing and other abusive behaviors.
    completionHandler(NO, nil);
    return;
  }

  self.webStateImpl->RunJavaScriptDialog(
      requestURL, type, message, defaultText,
      base::BindOnce(^(bool success, NSString* input) {
        completionHandler(success, input);
      }));
}

@end
