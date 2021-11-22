// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_WEB_WEB_PERFORMANCE_METRICS_WEB_PERFORMANCE_METRICS_JAVA_SCRIPT_FEATURE_H_
#define IOS_CHROME_BROWSER_WEB_WEB_PERFORMANCE_METRICS_WEB_PERFORMANCE_METRICS_JAVA_SCRIPT_FEATURE_H_

#include "ios/web/public/js_messaging/java_script_feature.h"

/**
 * A feature which captures Web Vitals metrics that determine
 * JavaScript injected logic's affect on a user's perception
 * of web performance.
 **/
class WebPerformanceMetricsJavaScriptFeature : public web::JavaScriptFeature {
 public:
  WebPerformanceMetricsJavaScriptFeature();
  ~WebPerformanceMetricsJavaScriptFeature() override;
  // This feature holds no state. Thus, a single static instance
  // suffices.
  static WebPerformanceMetricsJavaScriptFeature* GetInstance();

  // JavaScriptFeature:
  absl::optional<std::string> GetScriptMessageHandlerName() const override;
  void ScriptMessageReceived(web::WebState* web_state,
                             const web::ScriptMessage& message) override;
};

#endif  // IOS_CHROME_BROWSER_WEB_WEB_PERFORMANCE_METRICS_WEB_PERFORMANCE_METRICS_JAVA_SCRIPT_FEATURE_H_