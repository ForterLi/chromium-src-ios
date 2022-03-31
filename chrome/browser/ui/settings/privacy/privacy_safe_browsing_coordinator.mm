// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/settings/privacy/privacy_safe_browsing_coordinator.h"

#include "base/mac/foundation_util.h"
#import "components/strings/grit/components_strings.h"
#include "ios/chrome/browser/application_context.h"
#include "ios/chrome/browser/browser_state/chrome_browser_state.h"
#include "ios/chrome/browser/chrome_url_constants.h"
#import "ios/chrome/browser/main/browser.h"
#import "ios/chrome/browser/signin/chrome_account_manager_service_factory.h"
#import "ios/chrome/browser/ui/alert_coordinator/alert_coordinator.h"
#import "ios/chrome/browser/ui/commands/application_commands.h"
#import "ios/chrome/browser/ui/commands/browsing_data_commands.h"
#import "ios/chrome/browser/ui/commands/command_dispatcher.h"
#import "ios/chrome/browser/ui/commands/open_new_tab_command.h"
#import "ios/chrome/browser/ui/commands/show_signin_command.h"
#import "ios/chrome/browser/ui/settings/privacy/privacy_safe_browsing_mediator.h"
#import "ios/chrome/browser/ui/settings/privacy/privacy_safe_browsing_navigation_commands.h"
#import "ios/chrome/browser/ui/settings/privacy/privacy_safe_browsing_view_controller.h"
#import "ios/chrome/browser/ui/table_view/table_view_utils.h"
#include "ios/chrome/browser/ui/ui_feature_flags.h"
#import "ios/chrome/browser/web_state_list/web_state_list.h"
#import "ios/chrome/grit/ios_strings.h"
#import "ios/public/provider/chrome/browser/chrome_browser_provider.h"
#include "ui/base/l10n/l10n_util.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

// Currently takes into account a view controller delegate and not a command
// handler to communicate with the mediator since there's currently no needed
// functionality that requires this.
@interface PrivacySafeBrowsingCoordinator () <
    PrivacySafeBrowsingNavigationCommands,
    PrivacySafeBrowsingViewControllerPresentationDelegate>

// View controller presented by this coordinator.
@property(nonatomic, strong) PrivacySafeBrowsingViewController* viewController;
// Safe Browsing settings mediator.
@property(nonatomic, strong) PrivacySafeBrowsingMediator* mediator;
// Coordinator for No Protection Safe Browsing Pop Up.
@property(nonatomic, strong) AlertCoordinator* alertCoordinator;

@end

@implementation PrivacySafeBrowsingCoordinator

@synthesize baseNavigationController = _baseNavigationController;

- (instancetype)initWithBaseNavigationController:
                    (UINavigationController*)navigationController
                                         browser:(Browser*)browser {
  if ([super initWithBaseViewController:navigationController browser:browser]) {
    _baseNavigationController = navigationController;
  }
  return self;
}

- (void)start {
  self.viewController = [[PrivacySafeBrowsingViewController alloc]
      initWithStyle:ChromeTableViewStyle()];
  self.viewController.presentationDelegate = self;
  self.mediator = [[PrivacySafeBrowsingMediator alloc]
      initWithUserPrefService:self.browser->GetBrowserState()->GetPrefs()
             localPrefService:GetApplicationContext()->GetLocalState()];
  self.mediator.consumer = self.viewController;
  self.mediator.handler = self;
  self.viewController.modelDelegate = self.mediator;
  self.viewController.dispatcher = static_cast<
      id<ApplicationCommands, BrowserCommands, BrowsingDataCommands>>(
      self.browser->GetCommandDispatcher());
  DCHECK(self.baseNavigationController);
  [self.baseNavigationController pushViewController:self.viewController
                                           animated:YES];
}

#pragma mark - SafeBrowsingViewControllerPresentationDelegate

- (void)privacySafeBrowsingViewControllerDidRemove:
    (PrivacySafeBrowsingViewController*)controller {
  DCHECK_EQ(self.viewController, controller);
  [self.delegate privacySafeBrowsingCoordinatorDidRemove:self];
}

#pragma mark - PrivacySafeBrowsingNavigationCommands

- (void)showSafeBrowsingEnhancedProtection {
  // TODO(crbug.com/1307395):Implement this function
  NSLog(@"test");
}

- (void)showSafeBrowsingStandardProtection {
  // TODO(crbug.com/1307414):Implement this function
  NSLog(@"test");
}

- (void)showSafeBrowsingNoProtectionPopUp:(TableViewItem*)item {
  DCHECK(!self.alertCoordinator);
  self.alertCoordinator = [[AlertCoordinator alloc]
      initWithBaseViewController:self.viewController
                         browser:self.browser
                           title:
                               l10n_util::GetNSString(
                                   IDS_IOS_SAFE_BROWSING_NO_PROTECTION_CONFIRMATION_DIALOG_TITLE)
                         message:
                             l10n_util::GetNSString(
                                 IDS_IOS_SAFE_BROWSING_NO_PROTECTION_CONFIRMATION_DIALOG_MESSAGE)];

  __weak __typeof__(self) weakSelf = self;
  NSString* actionTitle = l10n_util::GetNSString(
      IDS_IOS_SAFE_BROWSING_NO_PROTECTION_CONFIRMATION_DIALOG_CONFIRM);
  [self.alertCoordinator addItemWithTitle:actionTitle
                                   action:^{
                                     [weakSelf.mediator selectSettingItem:item];
                                     [weakSelf.alertCoordinator stop];
                                     weakSelf.alertCoordinator = nil;
                                   }
                                    style:UIAlertActionStyleDefault];

  [self.alertCoordinator addItemWithTitle:l10n_util::GetNSString(IDS_CANCEL)
                                   action:^{
                                     [weakSelf.mediator selectSettingItem:nil];
                                     [weakSelf.alertCoordinator stop];
                                     weakSelf.alertCoordinator = nil;
                                   }
                                    style:UIAlertActionStyleCancel];

  [self.alertCoordinator start];
}

@end