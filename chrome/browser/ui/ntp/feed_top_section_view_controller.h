// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_NTP_FEED_TOP_SECTION_VIEW_CONTROLLER_H_
#define IOS_CHROME_BROWSER_UI_NTP_FEED_TOP_SECTION_VIEW_CONTROLLER_H_

#import <UIKit/UIKit.h>

#import "ios/chrome/browser/ui/authentication/cells/signin_promo_view_delegate.h"
#import "ios/chrome/browser/ui/ntp/feed_top_section_consumer.h"
#import "ios/chrome/browser/ui/ntp/feed_top_section_view_controller_delegate.h"

// View Controller that contains all the elements of the Feed Top section.
@interface FeedTopSectionViewController
    : UIViewController <FeedTopSectionConsumer>

// Delegate to handle interactions related to children views.
@property(nonatomic, weak) id<FeedTopSectionViewControllerDelegate> delegate;

// Delegate to handle interactions of the signin promo.
@property(nonatomic, weak) id<SigninPromoViewDelegate> signinPromoDelegate;

@end

#endif  // IOS_CHROME_BROWSER_UI_NTP_FEED_TOP_SECTION_VIEW_CONTROLLER_H_
