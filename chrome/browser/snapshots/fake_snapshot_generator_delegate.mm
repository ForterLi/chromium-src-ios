// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/snapshots/fake_snapshot_generator_delegate.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

@implementation FakeSnapshotGeneratorDelegate

@synthesize view = _view;

- (BOOL)snapshotGenerator:(SnapshotGenerator*)snapshotGenerator
    canTakeSnapshotForWebState:(web::WebState*)webState {
  return YES;
}

- (UIEdgeInsets)snapshotGenerator:(SnapshotGenerator*)snapshotGenerator
    snapshotEdgeInsetsForWebState:(web::WebState*)webState {
  return UIEdgeInsetsZero;
}

- (NSArray<SnapshotOverlay*>*)snapshotGenerator:
                                  (SnapshotGenerator*)snapshotGenerator
                    snapshotOverlaysForWebState:(web::WebState*)webState {
  return nil;
}

- (void)snapshotGenerator:(SnapshotGenerator*)snapshotGenerator
    willUpdateSnapshotForWebState:(web::WebState*)webState {
}

- (void)snapshotGenerator:(SnapshotGenerator*)snapshotGenerator
    didUpdateSnapshotForWebState:(web::WebState*)webState
                       withImage:(UIImage*)snapshot {
}

- (UIView*)snapshotGenerator:(SnapshotGenerator*)snapshotGenerator
         baseViewForWebState:(web::WebState*)webState {
  return self.view;
}

@end
