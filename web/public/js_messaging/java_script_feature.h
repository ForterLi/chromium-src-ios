// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_WEB_PUBLIC_JS_MESSAGING_JAVA_SCRIPT_FEATURE_H_
#define IOS_WEB_PUBLIC_JS_MESSAGING_JAVA_SCRIPT_FEATURE_H_

#import <Foundation/Foundation.h>

#include <string>
#include <vector>

#include "base/callback.h"
#include "base/memory/weak_ptr.h"
#include "third_party/abseil-cpp/absl/types/optional.h"

namespace base {
class Value;
}  // namespace base

namespace web {

class ScriptMessage;
class WebState;
class WebFrame;

// Describes a feature implemented in Javascript and native<->JS communication
// (if any). It is intended to be instantiated directly for simple features
// requiring injection only, but should subclassed into feature specific classes
// to handle JS<->native communication.
// NOTE: As implemented within //ios/web, JavaScriptFeature instances holds no
// state itself and can be used application-wide across browser states. However,
// this is not guaranteed of JavaScriptFeature subclasses.
class JavaScriptFeature {
 public:
  // The content world which this feature supports.
  // NOTE: Features should use kAnyContentWorld whenever possible to allow for
  // isolation between the feature and the loaded webpage JavaScript.
  enum class ContentWorld {
    // Represents any content world.
    kAnyContentWorld = 0,
    // Represents the page content world which is shared by the JavaScript of
    // the webpage. This value should only be used if the feature provides
    // JavaScript which needs to be accessible to the client JavaScript. For
    // example, JavaScript polyfills.
    kPageContentWorld,
    // Represents an isolated world that is not accessible to the JavaScript of
    // the webpage. This value should be used when it is important from a
    // security standpoint to make a feature's JavaScript inaccessible to
    // client JavaScript. Isolated worlds are supported only on iOS 14+, so
    // using the value on earlier iOS versions will trigger a DCHECK.
    kIsolatedWorldOnly,
  };

  // A script to be injected into webpage frames which support this feature.
  class FeatureScript {
   public:
    // The time at which this script will be injected into the page.
    enum class InjectionTime {
      kDocumentStart = 0,
      kDocumentEnd,
    };

    // Describes whether or not this script should be re-injected when the
    // document is re-created.
    enum class ReinjectionBehavior {
      // The script will only be injected once per window.
      kInjectOncePerWindow = 0,
      // The script will be re-injected when the document is re-created.
      // NOTE: This is necessary to re-add event listeners and to re-inject
      // modifications to the DOM and |document| JS object. Note, however, that
      // this option can also overwrite or duplicate state which was already
      // previously added to the window's state.
      kReinjectOnDocumentRecreation,
    };

    // The frames which this script will be injected into.
    enum class TargetFrames {
      kAllFrames = 0,
      kMainFrame,
    };

    // Mapping of placeholder to their replacement value.
    using PlaceholderReplacements = NSDictionary<NSString*, NSString*>*;

    // Callback used to perform placeholder replacement in the script. The
    // returned value is a dictionary mapping "placeholder" to the "value"
    // that needs it to be substituted by with in the script.
    using PlaceholderReplacementsCallback =
        base::RepeatingCallback<PlaceholderReplacements()>;

    // Creates a FeatureScript with the script file from the application bundle
    // with |filename| to be injected at |injection_time| into |target_frames|
    // using |reinjection_behavior|. If |replacements| is provided, it will be
    // used to replace placeholder with the corresponding string values.
    static FeatureScript CreateWithFilename(
        const std::string& filename,
        InjectionTime injection_time,
        TargetFrames target_frames,
        ReinjectionBehavior reinjection_behavior =
            ReinjectionBehavior::kInjectOncePerWindow,
        const PlaceholderReplacementsCallback& replacements_callback =
            PlaceholderReplacementsCallback());

    FeatureScript(const FeatureScript& other);
    FeatureScript& operator=(const FeatureScript&);

    FeatureScript(FeatureScript&&);
    FeatureScript& operator=(FeatureScript&&);

    // Returns the JavaScript string of the script with |script_filename_|.
    NSString* GetScriptString() const;

    InjectionTime GetInjectionTime() const { return injection_time_; }
    TargetFrames GetTargetFrames() const { return target_frames_; }

    ~FeatureScript();

   private:
    FeatureScript(const std::string& filename,
                  InjectionTime injection_time,
                  TargetFrames target_frames,
                  ReinjectionBehavior reinjection_behavior,
                  const PlaceholderReplacementsCallback& replacements_callback);

    // Returns |script| after swapping the placeholders with their value as
    // instructed by |replacements_callback_|.
    NSString* ReplacePlaceholders(NSString* script) const;

    std::string script_filename_;
    InjectionTime injection_time_;
    TargetFrames target_frames_;
    ReinjectionBehavior reinjection_behavior_;
    PlaceholderReplacementsCallback replacements_callback_;
  };

  JavaScriptFeature(ContentWorld supported_world,
                    std::vector<const FeatureScript> feature_scripts);
  JavaScriptFeature(ContentWorld supported_world,
                    std::vector<const FeatureScript> feature_scripts,
                    std::vector<const JavaScriptFeature*> dependent_features);
  virtual ~JavaScriptFeature();

  // Returns the supported content world for this feature.
  ContentWorld GetSupportedContentWorld() const;

  // Returns a vector of scripts used by this feature.
  virtual const std::vector<const FeatureScript> GetScripts() const;
  // Returns a vector of features which this one depends upon being available.
  virtual const std::vector<const JavaScriptFeature*> GetDependentFeatures()
      const;

  // Returns the script message handler name which this feature will receive
  // messages from JavaScript. Returning null will not register any handler.
  virtual absl::optional<std::string> GetScriptMessageHandlerName() const;

  using ScriptMessageHandler =
      base::RepeatingCallback<void(WebState* web_state,
                                   const ScriptMessage& message)>;
  // Returns the script message handler callback if
  // |GetScriptMessageHandlerName()| returns a handler name.
  absl::optional<ScriptMessageHandler> GetScriptMessageHandler() const;

  JavaScriptFeature(const JavaScriptFeature&) = delete;

 protected:
  explicit JavaScriptFeature(ContentWorld supported_world);

  bool CallJavaScriptFunction(WebFrame* web_frame,
                              const std::string& function_name,
                              const std::vector<base::Value>& parameters);

  bool CallJavaScriptFunction(
      WebFrame* web_frame,
      const std::string& function_name,
      const std::vector<base::Value>& parameters,
      base::OnceCallback<void(const base::Value*)> callback,
      base::TimeDelta timeout);

  // Callback for script messages registered through |GetScriptMessageHandler|.
  // |ScriptMessageReceived| is called when |web_state| receives a |message|.
  // |web_state| will always be non-null.
  virtual void ScriptMessageReceived(WebState* web_state,
                                     const ScriptMessage& message);

 private:
  ContentWorld supported_world_;
  std::vector<const FeatureScript> scripts_;
  std::vector<const JavaScriptFeature*> dependent_features_;
  base::WeakPtrFactory<JavaScriptFeature> weak_factory_;
};

}  // namespace web

#endif  // IOS_WEB_PUBLIC_JS_MESSAGING_JAVA_SCRIPT_FEATURE_H_
