// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_OVERLAYS_TEST_TEST_OVERLAY_PRESENTATION_CONTEXT_H_
#define IOS_CHROME_BROWSER_UI_OVERLAYS_TEST_TEST_OVERLAY_PRESENTATION_CONTEXT_H_

#import "ios/chrome/browser/ui/overlays/overlay_presentation_context_impl.h"

// OverlayPresentationContextImpl for OverlayModality::kTesting.
class TestOverlayPresentationContext : public OverlayPresentationContextImpl {
 public:
  explicit TestOverlayPresentationContext(Browser* browser);
  ~TestOverlayPresentationContext() override;
};

#endif  // IOS_CHROME_BROWSER_UI_OVERLAYS_TEST_TEST_OVERLAY_PRESENTATION_CONTEXT_H_
