// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_SETTINGS_PASSWORD_DETAILS_TABLE_VIEW_CONTROLLER_H_
#define IOS_CHROME_BROWSER_UI_SETTINGS_PASSWORD_DETAILS_TABLE_VIEW_CONTROLLER_H_

#import "ios/chrome/browser/ui/settings/password_details_table_view_controller_delegate.h"
#import "ios/chrome/browser/ui/settings/settings_root_table_view_controller.h"

namespace autofill {
struct PasswordForm;
}  // namespace autofill

// The accessibility identifier of the password details table view.
extern NSString* _Nonnull const kPasswordDetailsTableViewId;
extern NSString* _Nonnull const kPasswordDetailsDeletionAlertViewId;

@protocol ReauthenticationProtocol;

// Displays details of a password item, including URL of the site, username and
// password in masked state as default. User can copy the URL and username,
// pass the iOS security check to see and copy the password , or delete the
// password item.
@interface PasswordDetailsTableViewController : SettingsRootTableViewController

// The designated initializer.
- (nullable instancetype)
      initWithPasswordForm:(const autofill::PasswordForm&)passwordForm
                  delegate:
                      (nonnull id<PasswordDetailsTableViewControllerDelegate>)
                          delegate
    reauthenticationModule:
        (nonnull id<ReauthenticationProtocol>)reauthenticationModule
    NS_DESIGNATED_INITIALIZER;

- (nullable instancetype)initWithTableViewStyle:(UITableViewStyle)style
                                    appBarStyle:(ChromeTableViewControllerStyle)
                                                    appBarStyle NS_UNAVAILABLE;

@end

#endif  // IOS_CHROME_BROWSER_UI_SETTINGS_PASSWORD_DETAILS_TABLE_VIEW_CONTROLLER_H_
