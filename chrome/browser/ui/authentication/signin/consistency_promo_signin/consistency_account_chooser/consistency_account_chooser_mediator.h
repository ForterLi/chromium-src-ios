// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_AUTHENTICATION_SIGNIN_CONSISTENCY_PROMO_SIGNIN_CONSISTENCY_ACCOUNT_CHOOSER_CONSISTENCY_ACCOUNT_CHOOSER_MEDIATOR_H_
#define IOS_CHROME_BROWSER_UI_AUTHENTICATION_SIGNIN_CONSISTENCY_PROMO_SIGNIN_CONSISTENCY_ACCOUNT_CHOOSER_CONSISTENCY_ACCOUNT_CHOOSER_MEDIATOR_H_

#import <Foundation/Foundation.h>

#import "ios/chrome/browser/ui/authentication/signin/consistency_promo_signin/consistency_account_chooser/consistency_account_chooser_view_controller.h"

@class ChromeIdentity;
@protocol ConsistencyAccountChooserConsumer;
@class ConsistencyAccountChooserMediator;

// Mediator for ConsistencyAccountChooserCoordinator.
@interface ConsistencyAccountChooserMediator
    : NSObject <ConsistencyAccountChooserViewControllerModelDelegate>

@property(nonatomic, strong) id<ConsistencyAccountChooserConsumer> consumer;
@property(nonatomic, strong) ChromeIdentity* selectedIdentity;

// See -[SigninPromoViewMediator initWithBrowserState:].
- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithSelectedIdentity:(ChromeIdentity*)selectedIdentity
    NS_DESIGNATED_INITIALIZER;

@end

#endif  // IOS_CHROME_BROWSER_UI_AUTHENTICATION_SIGNIN_CONSISTENCY_PROMO_SIGNIN_CONSISTENCY_ACCOUNT_CHOOSER_CONSISTENCY_ACCOUNT_CHOOSER_MEDIATOR_H_
