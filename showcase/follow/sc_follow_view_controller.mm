// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/showcase/follow/sc_follow_view_controller.h"

#import "ios/chrome/browser/net/crurl.h"
#import "ios/chrome/browser/ui/follow/first_follow_favicon_data_source.h"
#import "ios/chrome/browser/ui/follow/first_follow_view_controller.h"
#import "ios/chrome/browser/ui/follow/first_follow_view_delegate.h"
#import "ios/chrome/browser/ui/follow/follow_block_types.h"
#import "ios/chrome/browser/ui/follow/followed_web_channel.h"
#import "ios/chrome/browser/ui/ntp/feed_management/feed_management_follow_delegate.h"
#import "ios/chrome/browser/ui/ntp/feed_management/feed_management_navigation_delegate.h"
#import "ios/chrome/browser/ui/ntp/feed_management/feed_management_view_controller.h"
#import "ios/chrome/browser/ui/ntp/feed_management/follow_management_ui_updater.h"
#import "ios/chrome/browser/ui/ntp/feed_management/follow_management_view_controller.h"
#import "ios/chrome/browser/ui/ntp/feed_management/followed_web_channels_data_source.h"
#import "ios/chrome/browser/ui/table_view/table_view_favicon_data_source.h"
#import "ios/chrome/browser/ui/table_view/table_view_navigation_controller.h"
#import "ios/chrome/common/ui/favicon/favicon_attributes.h"
#import "ios/showcase/common/protocol_alerter.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {

// Sets a custom radius for the half sheet presentation.
constexpr CGFloat kHalfSheetCornerRadius = 20;

// An example favicon URL given from the Discover backend.
static NSString* const kExampleFaviconURL =
    @"https://www.google.com/s2/favicons?domain=the-sun.com&sz=48";

}  // namespace

@interface SCFollowViewController () <FirstFollowFaviconDataSource,
                                      FollowedWebChannelsDataSource,
                                      TableViewFaviconDataSource>
// Shows alerts of protocol method calls.
@property(nonatomic, strong) ProtocolAlerter* alerter;
// Called to unfollow/refollow channels in the follow mgmt UI.
@property(nonatomic, weak) id<FollowManagementUIUpdater>
    followManagementUIUpdater;
// An owner of the web channels list is required to test unfollow/refollow.
@property(nonatomic, strong)
    NSArray<FollowedWebChannel*>* strongFollowedWebChannels;
@end

@implementation SCFollowViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  self.view.backgroundColor = UIColor.systemBackgroundColor;

  self.alerter = [[ProtocolAlerter alloc] initWithProtocols:@[
    @protocol(FeedManagementFollowDelegate),
    @protocol(FeedManagementNavigationDelegate),
    @protocol(FirstFollowViewDelegate)
  ]];

  UIButton* button1 = [[UIButton alloc] init];
  [button1 setTitle:@"Show Feed Mgmt UI" forState:UIControlStateNormal];
  [button1 addTarget:self
                action:@selector(handleFeedMgmtButtonTapped)
      forControlEvents:UIControlEventTouchUpInside];

  UIButton* button2 = [[UIButton alloc] init];
  [button2 setTitle:@"Show Follow Mgmt UI" forState:UIControlStateNormal];
  [button2 addTarget:self
                action:@selector(handleFollowMgmtButtonTapped)
      forControlEvents:UIControlEventTouchUpInside];

  UIButton* button3 = [[UIButton alloc] init];
  [button3 setTitle:@"Show First Follow modal" forState:UIControlStateNormal];
  [button3 addTarget:self
                action:@selector(handleFirstFollowButtonTapped)
      forControlEvents:UIControlEventTouchUpInside];

  UIStackView* verticalStack = [[UIStackView alloc]
      initWithArrangedSubviews:@[ button1, button2, button3 ]];
  verticalStack.axis = UILayoutConstraintAxisVertical;
  verticalStack.distribution = UIStackViewDistributionFill;
  verticalStack.alignment = UIStackViewAlignmentCenter;
  verticalStack.spacing = 10;
  verticalStack.translatesAutoresizingMaskIntoConstraints = NO;
  [self.view addSubview:verticalStack];

  [NSLayoutConstraint activateConstraints:@[
    [verticalStack.centerXAnchor
        constraintEqualToAnchor:self.view.centerXAnchor],
    [verticalStack.centerYAnchor
        constraintEqualToAnchor:self.view.centerYAnchor],
  ]];
}

- (void)handleFeedMgmtButtonTapped {
  FeedManagementViewController* feedManagementViewController =
      [[FeedManagementViewController alloc]
          initWithStyle:UITableViewStyleInsetGrouped];
  self.alerter.baseViewController = feedManagementViewController;
  feedManagementViewController.followDelegate =
      static_cast<id<FeedManagementFollowDelegate>>(self.alerter);
  feedManagementViewController.navigationDelegate =
      static_cast<id<FeedManagementNavigationDelegate>>(self.alerter);
  TableViewNavigationController* navigationController =
      [[TableViewNavigationController alloc]
          initWithTable:feedManagementViewController];
  [self presentViewController:navigationController animated:YES completion:nil];
}

- (void)handleFollowMgmtButtonTapped {
  FollowManagementViewController* followManagementViewController =
      [[FollowManagementViewController alloc]
          initWithStyle:UITableViewStyleInsetGrouped];
  self.followManagementUIUpdater =
      (id<FollowManagementUIUpdater>)followManagementViewController;
  followManagementViewController.followedWebChannelsDataSource = self;
  followManagementViewController.faviconDataSource = self;
  TableViewNavigationController* navigationController =
      [[TableViewNavigationController alloc]
          initWithTable:followManagementViewController];
  [self presentViewController:navigationController animated:YES completion:nil];
}

- (void)handleFirstFollowButtonTapped {
  FirstFollowViewController* firstFollowViewController =
      [[FirstFollowViewController alloc] init];

  FollowedWebChannel* ch1 = [[FollowedWebChannel alloc] init];
  ch1.title = @"First Web Channel";
  ch1.available = YES;
  ch1.faviconURL =
      [[CrURL alloc] initWithNSURL:[NSURL URLWithString:kExampleFaviconURL]];

  firstFollowViewController.followedWebChannel = ch1;
  self.alerter.baseViewController = firstFollowViewController;
  firstFollowViewController.delegate =
      static_cast<id<FirstFollowViewDelegate>>(self.alerter);
  firstFollowViewController.faviconDataSource = self;

  if (@available(iOS 15, *)) {
    firstFollowViewController.modalPresentationStyle =
        UIModalPresentationPageSheet;
    UISheetPresentationController* presentationController =
        firstFollowViewController.sheetPresentationController;
    presentationController.prefersEdgeAttachedInCompactHeight = YES;
    presentationController.widthFollowsPreferredContentSizeWhenEdgeAttached =
        YES;
    presentationController.detents = @[
      UISheetPresentationControllerDetent.mediumDetent,
      UISheetPresentationControllerDetent.largeDetent
    ];
    presentationController.preferredCornerRadius = kHalfSheetCornerRadius;
  } else {
    firstFollowViewController.modalPresentationStyle =
        UIModalPresentationFormSheet;
  }

  [self presentViewController:firstFollowViewController
                     animated:YES
                   completion:nil];
}

#pragma mark - FollowedWebChannelsDataSource

- (NSArray<FollowedWebChannel*>*)followedWebChannels {
  NSMutableArray<FollowedWebChannel*>* followedWebChannels =
      [[NSMutableArray alloc] init];
  for (int i = 0; i < 10; i++) {
    NSString* title = [NSString stringWithFormat:@"Channel %d", i];
    [followedWebChannels addObject:[self createWebChannelWithTitle:title]];
  }
  self.strongFollowedWebChannels = followedWebChannels;
  return followedWebChannels;
}

- (FollowedWebChannel*)createWebChannelWithTitle:(NSString*)title {
  FollowedWebChannel* channel = [[FollowedWebChannel alloc] init];
  channel.title = title;
  channel.available = YES;
  channel.faviconURL =
      [[CrURL alloc] initWithNSURL:[NSURL URLWithString:kExampleFaviconURL]];

  __weak FollowedWebChannel* weakChannel = channel;
  channel.unfollowRequestBlock = ^(RequestCompletionBlock completion) {
    // This mimics a successful unfollow on the server.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC),
                   dispatch_get_main_queue(), ^{
                     [self.followManagementUIUpdater
                         removeFollowedWebChannel:weakChannel];
                   });
    // This mimics refollowing after a few seconds.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 13 * NSEC_PER_SEC),
                   dispatch_get_main_queue(), ^{
                     [self.followManagementUIUpdater
                         addFollowedWebChannel:weakChannel];
                   });
  };
  return channel;
}

#pragma mark - TableViewFaviconDataSource & FirstFollowFaviconDataSource

- (void)faviconForURL:(CrURL*)URL
           completion:(void (^)(FaviconAttributes*))completion {
  // This mimics the behavior of favicon loader by immediately returning a
  // default image, then fetching and returning another image.
  UIImage* image1 = [UIImage systemImageNamed:@"globe"];
  UIImage* image2 = [UIImage systemImageNamed:@"globe.americas.fill"];
  completion([FaviconAttributes attributesWithImage:image1]);
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC),
                 dispatch_get_main_queue(), ^{
                   completion([FaviconAttributes attributesWithImage:image2]);
                 });
}

@end