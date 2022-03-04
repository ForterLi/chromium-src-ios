// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/ntp/feed_management/feed_management_coordinator.h"

#import "ios/chrome/browser/ui/ntp/feed_management/feed_management_delegate.h"
#import "ios/chrome/browser/ui/ntp/feed_management/feed_management_view_controller.h"
#import "ios/chrome/browser/ui/ntp/feed_management/follow_management_mediator.h"
#import "ios/chrome/browser/ui/ntp/feed_management/follow_management_view_controller.h"
#import "ios/chrome/browser/ui/table_view/table_view_navigation_controller.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

@interface FeedManagementCoordinator () <FeedManagementDelegate>

// The navigation controller into which management UI will be placed. This is a
// weak reference because we don't want to keep it in memory if it has been
// dismissed.
@property(nonatomic, weak) TableViewNavigationController* navigationController;

// The mediator for the follow management UI.
@property(nonatomic, strong) FollowManagementMediator* followManagementMediator;

@end

@implementation FeedManagementCoordinator

- (void)start {
  FeedManagementViewController* feedManagementViewController =
      [[FeedManagementViewController alloc]
          initWithStyle:UITableViewStyleInsetGrouped];
  feedManagementViewController.delegate = self;
  TableViewNavigationController* navigationController =
      [[TableViewNavigationController alloc]
          initWithTable:feedManagementViewController];
  self.navigationController = navigationController;
  [self.baseViewController presentViewController:self.navigationController
                                        animated:YES
                                      completion:nil];
}

- (void)stop {
  if (self.baseViewController.presentedViewController) {
    [self.baseViewController dismissViewControllerAnimated:NO completion:nil];
  }
  self.navigationController = nil;
  self.followManagementMediator = nil;
}

#pragma mark - FeedManagementDelegate

- (void)followingTapped {
  if (!self.navigationController) {
    // Tapping on the done button and following button simultaneously may result
    // in the navigation controller being dismissed but the tap being
    // registered. In that case, do nothing since the navigation controller has
    // already been dismissed.
    return;
  }

  FollowManagementViewController* followManagementViewController =
      [[FollowManagementViewController alloc]
          initWithStyle:UITableViewStyleInsetGrouped];
  FollowManagementMediator* mediator = [[FollowManagementMediator alloc] init];
  followManagementViewController.dataSource = mediator;
  followManagementViewController.delegate = mediator;
  self.followManagementMediator = mediator;
  [self.navigationController pushViewController:followManagementViewController
                                       animated:YES];
}

- (void)interestsTapped {
  // TODO(crbug.com/1296745): Complete this method.
}

- (void)hiddenTapped {
  // TODO(crbug.com/1296745): Complete this method.
}

- (void)activityTapped {
  // TODO(crbug.com/1296745): Complete this method.
}

@end