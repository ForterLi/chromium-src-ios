// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_QR_SCANNER_QR_SCANNER_VIEW_H_
#define IOS_CHROME_BROWSER_UI_QR_SCANNER_QR_SCANNER_VIEW_H_

#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

@protocol QRScannerViewDelegate

// Called when the close button is pressed.
- (void)dismissQRScannerView:(id)sender;
// Called when the torch button is pressed.
- (void)toggleTorch:(id)sender;

@end

// The view rendering the QR Scanner UI. The view contains the camera preview,
// a semi-transparent overlay with a transparent viewport, border around the
// viewport, the close and flash controls, and a label instructing the user to
// correctly position the scanned code.
@interface QRScannerView : UIView

// The delegate which receives button events.
@property(nonatomic, weak) id<QRScannerViewDelegate> delegate;

- (instancetype)initWithFrame:(CGRect)frame
                     delegate:(id<QRScannerViewDelegate>)delegate
    NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithFrame:(CGRect)frame NS_UNAVAILABLE;

- (instancetype)initWithCoder:(NSCoder*)coder NS_UNAVAILABLE;

// Returns the displayed preview layer.
- (AVCaptureVideoPreviewLayer*)getPreviewLayer;

// Returns the viewport size which can be overridden in a subclass.
- (CGSize)viewportSize;

// Returns scanner caption which can be overridden in a subclass.
- (NSString*)scannerCaption;

// Sets the state of the torch button to enabled or disabled according to the
// value of |torchIsAvailable|.
- (void)enableTorchButton:(BOOL)torchIsAvailable;

// Sets the torch button icon to on or off based on the value of |torchIsOn|.
- (void)setTorchButtonTo:(BOOL)torchIsOn;

// Resets the frame of the preview layer to a CGRect with origin (0, 0) and
// size equal to |size|.
- (void)resetPreviewFrame:(CGSize)size;

// Rotates the preview layer by |angle|. Used for a transform which prevents the
// preview layer from rotating with the rest of the interface.
- (void)rotatePreviewByAngle:(CGFloat)angle;

// Rounds the parameters of the preview layer's transform.
- (void)finishPreviewRotation;

// Returns the rectangle in camera coordinates in which codes should be
// recognized.
- (CGRect)viewportRectOfInterest;

// Display a flash animation when a result is scanned.
- (void)animateScanningResultWithCompletion:(void (^)(void))completion;

@end

#endif  // IOS_CHROME_BROWSER_UI_QR_SCANNER_QR_SCANNER_VIEW_H_
