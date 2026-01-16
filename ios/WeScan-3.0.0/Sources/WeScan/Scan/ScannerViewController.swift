//
//  ScannerViewController.swift
//  WeScan
//
//  Created by Boris Emorine on 2/8/18.
//  Copyright © 2018 WeTransfer. All rights reserved.
//
//  swiftlint:disable line_length
/// Màn hình camera scan
//Setup AVCaptureSession
//Hiển thị camera preview
//Vẽ overlay rectangle
//Xử lý user interaction (chụp ảnh, crop lại)
import AVFoundation
import UIKit

/// The `ScannerViewController` offers an interface to give feedback to the user regarding quadrilaterals that are detected. It also gives the user the opportunity to capture an image with a detected rectangle.
public final class ScannerViewController: UIViewController {

    private var captureSessionManager: CaptureSessionManager?
    private let videoPreviewLayer = AVCaptureVideoPreviewLayer()

    /// The view that shows the focus rectangle (when the user taps to focus, similar to the Camera app)
    private var focusRectangle: FocusRectangleView!
    var overlayImageView: UIImageView!

    /// The view that draws the detected rectangles.
    private let quadView = QuadrilateralView()

    /// Whether flash is enabled
    private var flashEnabled = false
    private var isFlashOn = false
    private var torchRetryCount = 0
    private let maxTorchRetries = 5

    /// The original bar style that was set by the host app
    private var originalBarStyle: UIBarStyle?

    private lazy var shutterButton: ShutterButton = {
        let button = ShutterButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(captureImage(_:)), for: .touchUpInside)
        return button
    }()

    private lazy var cancelButton: UIButton = {
        let button = UIButton()
        button.setTitle(NSLocalizedString("wescan.scanning.cancel", tableName: nil, bundle: Bundle(for: ScannerViewController.self), value: "Cancel", comment: "The cancel button"), for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(cancelImageScannerController), for: .touchUpInside)
        return button
    }()

//     private lazy var autoScanButton: UIBarButtonItem = {
//         let title = NSLocalizedString("wescan.scanning.auto", tableName: nil, bundle: Bundle(for: ScannerViewController.self), value: "Auto", comment: "The auto button state")
//         let button = UIBarButtonItem(title: title, style: .plain, target: self, action: #selector(toggleAutoScan))
//         button.tintColor = .white
//
//         return button
//     }()
//
//     private lazy var flashButton: UIBarButtonItem = {
//         let image = UIImage(systemName: "bolt.fill", named: "flash", in: Bundle(for: ScannerViewController.self), compatibleWith: nil)
//         let button = UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(toggleFlash))
//         button.tintColor = .white
//
//         return button
//     }()

    private lazy var activityIndicator: UIActivityIndicatorView = {
        let activityIndicator = UIActivityIndicatorView(style: .gray)
        activityIndicator.hidesWhenStopped = true
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        return activityIndicator
    }()
    /// Helper method để bật flash tự động sau khi camera session đã sẵn sàng
    /// Quan trọng cho iPhone 13 Pro+ để tránh lỗi đơ khi mở camera
    private func enableTorchWhenReady() {
        // Kiểm tra session đã running chưa
        guard let session = videoPreviewLayer.session, session.isRunning else {
            // Nếu chưa running, đợi một chút rồi thử lại (tối đa maxTorchRetries lần)
            guard torchRetryCount < maxTorchRetries else {
                print("Torch: Max retries reached, giving up")
                return
            }
            torchRetryCount += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.enableTorchWhenReady()
            }
            return
        }

        // Reset counter khi thành công
        torchRetryCount = 0
        // Session đã running, bật flash
        toggleTorch(on: true)
    }

    func toggleTorch(on: Bool) {
        // Lấy device từ capture session thay vì default để tránh lỗi trên iPhone 13 Pro+
        guard let session = videoPreviewLayer.session,
              let input = session.inputs.first as? AVCaptureDeviceInput else {
            print("Torch: Cannot get device from capture session")
            return
        }

        let device = input.device

        // Kiểm tra session đang running trước khi bật flash (quan trọng cho iPhone 13 Pro+)
        guard session.isRunning else {
            print("Torch: Session is not running yet, will retry")
            // Nếu session chưa running và muốn bật flash, đợi một chút rồi thử lại
            if on {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.toggleTorch(on: true)
                }
            }
            return
        }

        guard device.hasTorch else {
            print("Torch is not available")
            return
        }
        do {
            try device.lockForConfiguration()
            defer {
                device.unlockForConfiguration()
            }

            if on {
                // Kiểm tra torch có available không (quan trọng cho iPhone 13 Pro+)
                guard device.isTorchAvailable else {
                    print("Torch is not available at this time")
                    return
                }
                // nếu là on thì độ sáng mặc định là 1 là cao nhất của flash (độ sáng của flash từ 0.0 đến 1)
                // Khuong set độ sáng của đèn flash
                try device.setTorchModeOn(level: 1)
                isFlashOn = true
            } else {
                device.torchMode = .off
                isFlashOn = false
            }
        } catch {
            print("Torch could not be used: \(error.localizedDescription)")
        }
    }



    // MARK: - Life Cycle

    override public func viewDidLoad() {
        super.viewDidLoad()

        title = nil
        view.backgroundColor = UIColor.black

        setupViews()
//         setupNavigationBar()
        setupConstraints()

        captureSessionManager = CaptureSessionManager(videoPreviewLayer: videoPreviewLayer, delegate: self)

        originalBarStyle = navigationController?.navigationBar.barStyle

        NotificationCenter.default.addObserver(self, selector: #selector(subjectAreaDidChange), name: Notification.Name.AVCaptureDeviceSubjectAreaDidChange, object: nil)
    }

    public override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "YourSegueIdentifier" {
        let backButton = UIBarButtonItem(title: "Quay lại", style: .plain, target: nil, action: nil)
        navigationItem.backBarButtonItem = backButton
        }
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setNeedsStatusBarAppearanceUpdate()
        //Khuong ẩn thanh navigation màu xám
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
        self.setNeedsStatusBarAppearanceUpdate() // Cập nhật trạng thái thanh trạng thái

        //
        CaptureSession.current.isEditing = false
        quadView.removeQuadrilateral()
        captureSessionManager?.start()
        // Bật flash tự động sau khi camera session đã running
        // Sử dụng helper method để đảm bảo session đã sẵn sàng (quan trọng cho iPhone 13 Pro+)
        enableTorchWhenReady()
        UIApplication.shared.isIdleTimerDisabled = true

        navigationController?.navigationBar.barStyle = .blackTranslucent
    }

    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        videoPreviewLayer.frame = view.layer.bounds
    }
                // ẩn hiển toolbar
    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        UIApplication.shared.isIdleTimerDisabled = false
 //Khuong ẩn thanh navigation màu xám
        self.navigationController?.setNavigationBarHidden(false, animated: animated)
        self.setNeedsStatusBarAppearanceUpdate() // Cập nhật trạng thái thanh trạng thái

        //
        navigationController?.navigationBar.isTranslucent = false
        navigationController?.navigationBar.barStyle = originalBarStyle ?? .default
        toggleTorch(on: false)
        captureSessionManager?.stop()
        // Reset counter khi đóng camera
        torchRetryCount = 0
//         guard let device = AVCaptureDevice.default(for: AVMediaType.video) else { return }
//         if device.torchMode == .on {
//             toggleFlash()
//         }

    }

    // MARK: - Setups

    private func setupViews() {
        view.backgroundColor = .darkGray
        view.layer.addSublayer(videoPreviewLayer)
        quadView.translatesAutoresizingMaskIntoConstraints = false
        quadView.editable = false
        super.viewDidLoad()

//         let overlayView = QRScannerOverlayView(frame: view.bounds)
//         //         Thêm overlayImageView
//         overlayImageView = UIImageView(frame: quadView.frame)
//         //        overlayImageView.image = UIImage(named: "layer", in: Bundle(for: ScannerViewController.self), compatibleWith: nil)
//         overlayImageView.contentMode = .scaleToFill
//         overlayView.backgroundColor = .clear
//
//         view.addSubview(overlayView)
//
//         view.addSubview(overlayImageView)
        view.addSubview(quadView)
        view.addSubview(cancelButton)
        view.addSubview(shutterButton)
        view.addSubview(activityIndicator)
    }

    private func setupNavigationBar() {
//         navigationItem.setLeftBarButton(flashButton, animated: false)
//         navigationItem.setRightBarButton(autoScanButton, animated: false)
//
//         if UIImagePickerController.isFlashAvailable(for: .rear) == false {
//             let flashOffImage = UIImage(systemName: "bolt.slash.fill", named: "flashUnavailable", in: Bundle(for: ScannerViewController.self), compatibleWith: nil)
//             flashButton.image = flashOffImage
//             flashButton.tintColor = UIColor.lightGray
//         }
    }

    private func setupConstraints() {
        var quadViewConstraints = [NSLayoutConstraint]()
        var cancelButtonConstraints = [NSLayoutConstraint]()
        var shutterButtonConstraints = [NSLayoutConstraint]()
        var activityIndicatorConstraints = [NSLayoutConstraint]()

        quadViewConstraints = [
            quadView.topAnchor.constraint(equalTo: view.topAnchor),
            view.bottomAnchor.constraint(equalTo: quadView.bottomAnchor),
            view.trailingAnchor.constraint(equalTo: quadView.trailingAnchor),
            quadView.leadingAnchor.constraint(equalTo: view.leadingAnchor)
        ]

        shutterButtonConstraints = [
            shutterButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            shutterButton.widthAnchor.constraint(equalToConstant: 65.0),
            shutterButton.heightAnchor.constraint(equalToConstant: 65.0)
        ]

        activityIndicatorConstraints = [
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ]

        if #available(iOS 11.0, *) {
            cancelButtonConstraints = [
                cancelButton.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor, constant: 24.0),
                view.safeAreaLayoutGuide.bottomAnchor.constraint(equalTo: cancelButton.bottomAnchor, constant: (65.0 / 2) - 10.0)
            ]

            let shutterButtonBottomConstraint = view.safeAreaLayoutGuide.bottomAnchor.constraint(equalTo: shutterButton.bottomAnchor, constant: 8.0)
            shutterButtonConstraints.append(shutterButtonBottomConstraint)
        } else {
            cancelButtonConstraints = [
                cancelButton.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 24.0),
                view.bottomAnchor.constraint(equalTo: cancelButton.bottomAnchor, constant: (65.0 / 2) - 10.0)
            ]

            let shutterButtonBottomConstraint = view.bottomAnchor.constraint(equalTo: shutterButton.bottomAnchor, constant: 8.0)
            shutterButtonConstraints.append(shutterButtonBottomConstraint)
        }

        NSLayoutConstraint.activate(quadViewConstraints + cancelButtonConstraints + shutterButtonConstraints + activityIndicatorConstraints)
    }

    // MARK: - Tap to Focus

    /// Called when the AVCaptureDevice detects that the subject area has changed significantly. When it's called, we reset the focus so the camera is no longer out of focus.
    @objc private func subjectAreaDidChange() {
        /// Reset the focus and exposure back to automatic
        do {
            try CaptureSession.current.resetFocusToAuto()
        } catch {
            let error = ImageScannerControllerError.inputDevice
            guard let captureSessionManager else { return }
            captureSessionManager.delegate?.captureSessionManager(captureSessionManager, didFailWithError: error)
            return
        }

        /// Remove the focus rectangle if one exists
        // Cái này hiển thị khi ấn vào màn hình tập trung 1 điểm có sẽ ô vuông màu vàng bắt vào
        CaptureSession.current.removeFocusRectangleIfNeeded(focusRectangle, animated: true)
    }

    override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)

        guard  let touch = touches.first else { return }
        let touchPoint = touch.location(in: view)
        let convertedTouchPoint: CGPoint = videoPreviewLayer.captureDevicePointConverted(fromLayerPoint: touchPoint)

// Cái này hiển thị khi ấn vào màn hình tập trung 1 điểm có sẽ ô vuông màu vàng bắt vào

        CaptureSession.current.removeFocusRectangleIfNeeded(focusRectangle, animated: false)

        focusRectangle = FocusRectangleView(touchPoint: touchPoint)
        view.addSubview(focusRectangle)
                //

        do {
            try CaptureSession.current.setFocusPointToTapPoint(convertedTouchPoint)
        } catch {
            let error = ImageScannerControllerError.inputDevice
            guard let captureSessionManager else { return }
            captureSessionManager.delegate?.captureSessionManager(captureSessionManager, didFailWithError: error)
            return
        }
    }

    // MARK: - Actions

    @objc private func captureImage(_ sender: UIButton) {
        (navigationController as? ImageScannerController)?.flashToBlack()
        shutterButton.isUserInteractionEnabled = false
        captureSessionManager?.capturePhoto()
    }

    @objc private func toggleAutoScan() {
        if CaptureSession.current.isAutoScanEnabled {
            CaptureSession.current.isAutoScanEnabled = false
//             autoScanButton.title = NSLocalizedString("wescan.scanning.manual", tableName: nil, bundle: Bundle(for: ScannerViewController.self), value: "Manual", comment: "The manual button state")
        } else {
            CaptureSession.current.isAutoScanEnabled = false
//             autoScanButton.title = NSLocalizedString("wescan.scanning.auto", tableName: nil, bundle: Bundle(for: ScannerViewController.self), value: "Auto", comment: "The auto button state")
        }
    }

//     @objc private func toggleFlash() {
//         let state = CaptureSession.current.toggleFlash()
//
//         let flashImage = UIImage(systemName: "bolt.fill", named: "flash", in: Bundle(for: ScannerViewController.self), compatibleWith: nil)
//         let flashOffImage = UIImage(systemName: "bolt.slash.fill", named: "flashUnavailable", in: Bundle(for: ScannerViewController.self), compatibleWith: nil)
//
//         switch state {
//         case .on:
//             flashEnabled = true
//             flashButton.image = flashImage
//             flashButton.tintColor = .yellow
//         case .off:
//             flashEnabled = false
//             flashButton.image = flashImage
//             flashButton.tintColor = .white
//         case .unknown, .unavailable:
//             flashEnabled = false
//             flashButton.image = flashOffImage
//             flashButton.tintColor = UIColor.lightGray
//         }
//     }

    @objc private func cancelImageScannerController() {
        guard let imageScannerController = navigationController as? ImageScannerController else { return }
        imageScannerController.imageScannerDelegate?.imageScannerControllerDidCancel(imageScannerController)
    }

}

extension ScannerViewController: RectangleDetectionDelegateProtocol {
    func captureSessionManager(_ captureSessionManager: CaptureSessionManager, didFailWithError error: Error) {

        activityIndicator.stopAnimating()
        shutterButton.isUserInteractionEnabled = true

        guard let imageScannerController = navigationController as? ImageScannerController else { return }
        imageScannerController.imageScannerDelegate?.imageScannerController(imageScannerController, didFailWithError: error)
    }

    func didStartCapturingPicture(for captureSessionManager: CaptureSessionManager) {
        activityIndicator.startAnimating()
        captureSessionManager.stop()
        shutterButton.isUserInteractionEnabled = false
    }

    func captureSessionManager(_ captureSessionManager: CaptureSessionManager, didCapturePicture picture: UIImage, withQuad quad: Quadrilateral?) {
        activityIndicator.stopAnimating()

        let editVC = EditScanViewController(image: picture, quad: quad)
        navigationController?.pushViewController(editVC, animated: false)

        shutterButton.isUserInteractionEnabled = true
    }

    func captureSessionManager(_ captureSessionManager: CaptureSessionManager, didDetectQuad quad: Quadrilateral?, _ imageSize: CGSize) {
        guard let quad else {
            // If no quad has been detected, we remove the currently displayed on on the quadView.
            quadView.removeQuadrilateral()
            return
        }

        let portraitImageSize = CGSize(width: imageSize.height, height: imageSize.width)

        let scaleTransform = CGAffineTransform.scaleTransform(forSize: portraitImageSize, aspectFillInSize: quadView.bounds.size)
        let scaledImageSize = imageSize.applying(scaleTransform)

        let rotationTransform = CGAffineTransform(rotationAngle: CGFloat.pi / 2.0)

        let imageBounds = CGRect(origin: .zero, size: scaledImageSize).applying(rotationTransform)

        let translationTransform = CGAffineTransform.translateTransform(fromCenterOfRect: imageBounds, toCenterOfRect: quadView.bounds)

        let transforms = [scaleTransform, rotationTransform, translationTransform]

        let transformedQuad = quad.applyTransforms(transforms)

        quadView.drawQuadrilateral(quad: transformedQuad, animated: true)
    }

}
