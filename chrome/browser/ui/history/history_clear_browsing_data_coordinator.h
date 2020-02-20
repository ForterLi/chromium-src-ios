// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_HISTORY_HISTORY_CLEAR_BROWSING_DATA_COORDINATOR_H_
#define IOS_CHROME_BROWSER_UI_HISTORY_HISTORY_CLEAR_BROWSING_DATA_COORDINATOR_H_

#import "ios/chrome/browser/ui/coordinators/chrome_coordinator.h"
#import "ios/chrome/browser/ui/settings/clear_browsing_data/clear_browsing_data_local_commands.h"

enum class UrlLoadStrategy;

@protocol HistoryLocalCommands;
@protocol HistoryPresentationDelegate;
@protocol HistoryClearBrowsingDataLocalCommands;

// Coordinator that presents Clear Browsing Data Table View from History.
// Delegates are hooked up to History coordinator-specific methods.
@interface HistoryClearBrowsingDataCoordinator
    : ChromeCoordinator<ClearBrowsingDataLocalCommands>

// Unavailable, use -initWithBaseViewController:browser:.
- (instancetype)initWithBaseViewController:(UIViewController*)viewController
    NS_UNAVAILABLE;
// Unavailable, use -initWithBaseViewController:browser:.
- (instancetype)initWithBaseViewController:(UIViewController*)viewController
                              browserState:(ChromeBrowserState*)browserState
    NS_UNAVAILABLE;

// Delegate for this coordinator.
@property(nonatomic, weak) id<HistoryLocalCommands> localDispatcher;

// Opaque instructions on how to open urls.
@property(nonatomic) UrlLoadStrategy loadStrategy;

// Delegate used to make the Tab UI visible.
@property(nonatomic, weak) id<HistoryPresentationDelegate> presentationDelegate;

// Stops this Coordinator then calls |completionHandler|. |completionHandler|
// always will be run.
- (void)stopWithCompletion:(ProceduralBlock)completionHandler;

@end

#endif  // IOS_CHROME_BROWSER_UI_HISTORY_HISTORY_CLEAR_BROWSING_DATA_COORDINATOR_H_
