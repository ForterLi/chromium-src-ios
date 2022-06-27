// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_SETTINGS_PASSWORD_PASSWORD_MANAGER_VIEW_CONTROLLER_PRESENTATION_DELEGATE_H_
#define IOS_CHROME_BROWSER_UI_SETTINGS_PASSWORD_PASSWORD_MANAGER_VIEW_CONTROLLER_PRESENTATION_DELEGATE_H_

#import <Foundation/Foundation.h>

// Presentation delegate for `PasswordManagerViewController`.
@protocol PasswordManagerViewControllerPresentationDelegate

// Called when `PasswordManagerViewController` is dismissed.
- (void)PasswordManagerViewControllerDismissed;

@end

#endif  // IOS_CHROME_BROWSER_UI_SETTINGS_PASSWORD_PASSWORD_MANAGER_VIEW_CONTROLLER_PRESENTATION_DELEGATE_H_
