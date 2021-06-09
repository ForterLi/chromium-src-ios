// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_COMMANDS_POLICY_SIGNOUT_COMMANDS_H_
#define IOS_CHROME_BROWSER_UI_COMMANDS_POLICY_SIGNOUT_COMMANDS_H_

@protocol PolicySignoutPromptCommands <NSObject>

// Command to show the full-screen prompt to warn the user they have been signed
// out due to a policy change. The prompt is shown immediately and stays
// on-screen until the user dismisses it.
- (void)showPolicySignoutPrompt;

@end

#endif  // IOS_CHROME_BROWSER_UI_COMMANDS_POLICY_SIGNOUT_COMMANDS_H_
