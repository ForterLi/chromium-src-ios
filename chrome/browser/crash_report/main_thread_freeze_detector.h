// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_CRASH_REPORT_MAIN_THREAD_FREEZE_DETECTOR_H_
#define IOS_CHROME_BROWSER_CRASH_REPORT_MAIN_THREAD_FREEZE_DETECTOR_H_

#import <Foundation/Foundation.h>

#import "base/ios/block_types.h"

// Detects freezes of the main thread.
// This class that the main thread runloop is run at least every
// |TimeoutForMainThreadFreezeDetection|. If this is not the case, a
// NSUserDefault flag is raised and a crash report is generated capturing the
// stack of the main frame at that time.
// The report is deleted if the main thread recovers.
// This class uses NSUserDefault as persistent storage as profile may not be
// available (both because initialization is too early and because main thread
// is often frozen at the point the class is used).
@interface MainThreadFreezeDetector : NSObject
// Returns the sharedInstance of the watchdog.
// Note that on first access, the instance is immediately started without
// checking the new preferences values. This is necessary to detect freezes
// during applicationDidFinishLaunching.
+ (instancetype)sharedInstance;
// The result of the previous session. If this is true, the last time the
// application was terminated, main thread was not responding.
@property(nonatomic, readonly) BOOL lastSessionEndedFrozen;
// Whether the UTE report from last session has been processed and it is now
// possible to start crash report upload.
@property(nonatomic, readonly) BOOL canUploadBreakpadCrashReports;
// Starts the watchdog of the main thread.
- (void)start;
// Stops the watchdog of the main thread.
- (void)stop;
// Enables or disables the main thread watchdog. This will also start or stop
// the monitoring of the main thread.
- (void)setEnabled:(BOOL)enabled;
// Prepare the UTE report before the crash handler starts to uploading them.
// If using Breakpad:
// Call completion on main thread when complete. If this is called multiple
// times before |completion| is called, only the latest |completion| block will
// be called. The function will queue the UTE report to be uploaded if there is
// no newer crash report in the Breakpad directory.
// If using Crashpad:
// Completion unused by Crashpad. Because -prepareCrashReportsForUpload is
// called early enough on startup, Crashpad has not processed crash intermediate
// dumps yet.  Since the UTE directory should be cleared to avoid duplicate UTE
// reports, move any UTE reports from the previous session to a to-be-processed
// location to be used by -processIntermediateDumps.
- (void)prepareCrashReportsForUpload:(ProceduralBlock)completion;
// Crashpad only. Tell Crashpad to process UTE intermediate dumps if there are
// no newer crash reports. This should only be called after
// crash_reporter::ProcessIntermediateDumps(), otherwise there would be no
// way to see if a crash happened after the UTE report was generated.
- (void)processIntermediateDumps;
@end

#endif  // IOS_CHROME_BROWSER_CRASH_REPORT_MAIN_THREAD_FREEZE_DETECTOR_H_
