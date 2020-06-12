// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_PAGE_INFO_PAGE_INFO_COOKIES_MEDIATOR_H_
#define IOS_CHROME_BROWSER_UI_PAGE_INFO_PAGE_INFO_COOKIES_MEDIATOR_H_

#import <Foundation/Foundation.h>

#import "ios/web/public/web_state_observer_bridge.h"

class HostContentSettingsMap;
@protocol PageInfoCookiesConsumer;
@class PageInfoCookiesDescription;
class PrefService;

// The mediator is pushing the data for the page info Cookies section to the
// consumer.
@interface PageInfoCookiesMediator : NSObject

- (instancetype)init NS_UNAVAILABLE;

// Designated initializer.
- (instancetype)initWithWebState:(web::WebState*)webState
                     prefService:(PrefService*)prefService
                     settingsMap:(HostContentSettingsMap*)settingsMap
    NS_DESIGNATED_INITIALIZER;

// The consumer for this mediator.
@property(nonatomic, weak) id<PageInfoCookiesConsumer> consumer;

// Returns a configuration for the page info Cookies section to the coordinator.
- (PageInfoCookiesDescription*)cookiesDescription;

@end

#endif  // IOS_CHROME_BROWSER_UI_PAGE_INFO_PAGE_INFO_COOKIES_MEDIATOR_H_
