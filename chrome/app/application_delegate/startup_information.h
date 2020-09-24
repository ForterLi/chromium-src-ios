// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_APP_APPLICATION_DELEGATE_STARTUP_INFORMATION_H_
#define IOS_CHROME_APP_APPLICATION_DELEGATE_STARTUP_INFORMATION_H_

@class CrashRestoreHelper;
class FirstUserActionRecorder;

namespace base {
class TimeTicks;
}

// Contains information about the startup.
@protocol StartupInformation<NSObject>

// Whether First Run UI (terms of service & sync sign-in) is being presented
// in a modal dialog.
@property(nonatomic, readonly) BOOL isPresentingFirstRunUI;
// Whether the current session began from a cold start. NO if the app has
// entered the background at least once since start up.
@property(nonatomic) BOOL isColdStart;
// Start of the application, used for UMA.
@property(nonatomic, assign) base::TimeTicks appLaunchTime;
// An object to record metrics related to the user's first action.
@property(nonatomic, readonly) FirstUserActionRecorder* firstUserActionRecorder;

// Keeps track of the restore state during startup.
@property(nonatomic, strong) CrashRestoreHelper* restoreHelper;

- (BOOL)canLaunchInIncognito;

// Only for iOS 12 compat.
- (NSDictionary*)launchOptions;

// Disables the FirstUserActionRecorder.
- (void)resetFirstUserActionRecorder;

// Expire the FirstUserActionRecorder and disable it.
- (void)expireFirstUserActionRecorder;

// Expire the FirstUserActionRecorder and disable it after a delay.
- (void)expireFirstUserActionRecorderAfterDelay:(NSTimeInterval)delay;

// Enable the FirstUserActionRecorder with the time spent in background.
- (void)activateFirstUserActionRecorderWithBackgroundTime:
    (NSTimeInterval)backgroundTime;

// Teardown that is needed by common Chrome code. This should not be called if
// Chrome code is still on the stack.
- (void)stopChromeMain;

@end

#endif  // IOS_CHROME_APP_APPLICATION_DELEGATE_STARTUP_INFORMATION_H_
