import UIKit

/// The `ReviewViewController` offers an interface to review the image after it has been cropped and enhanced.

final class ReviewViewController: UIViewController {
    private var rotationAngle = Measurement<UnitAngle>(value: 0, unit: .degrees)
    private var enhancedImageIsAvailable = false
    private var isCurrentlyDisplayingEnhancedImage = false

    lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.clipsToBounds = true
        imageView.isOpaque = true
        imageView.image = results.croppedScan.image
        imageView.backgroundColor = .black
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private lazy var doneButton: UIBarButtonItem = {
        let button = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector (finishScan))
        button.tintColor = navigationController?.navigationBar.tintColor
        return button
    }()

    private var results: ImageScannerResults

    // MARK: - Life Cycle

    init(results: ImageScannerResults) {
        self.results = results
        super.init(nibName: nil, bundle: nil)
    }

    required init ? (coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Your review screen UI and logic goes here.
        // For example, you can display the cropped image.
//        let imageView = UIImageView(image: results.croppedScan.image)
//        imageView.frame = view.bounds
//        imageView.contentMode = .scaleAspectFit
//        view.addSubview(imageView)
        enhancedImageIsAvailable = results.enhancedScan != nil
        setupViews()
        //setupToolbar()
        setupConstraints()

        title = NSLocalizedString("wescan.review.title", tableName: nil, bundle: Bundle(for: ReviewViewController.self), value: "Review", comment: "The review title of the ReviewController")
        navigationItem.rightBarButtonItem = doneButton
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // We only show the toolbar (with the enhance button) if the enhanced image is available.
        //        if enhancedImageIsAvailable {
        //            navigationController?.setToolbarHidden(false, animated: true)
        //        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        //navigationController?.setToolbarHidden(true, animated: true)
    }

    // MARK: Setups

    private func setupViews() {
        view.addSubview(imageView)
    }

    //    private func setupToolbar() {
    //        guard enhancedImageIsAvailable else { return }
    //
    //        navigationController?.toolbar.barStyle = .blackTranslucent
    //
    //        let fixedSpace = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
    //        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
    //        toolbarItems = [fixedSpace, enhanceButton, flexibleSpace, rotateButton, fixedSpace]
    //    }

    private func setupConstraints() {
        imageView.translatesAutoresizingMaskIntoConstraints = false

        var imageViewConstraints: [NSLayoutConstraint] = []
        if #available(iOS 11.0, *) {
            imageViewConstraints = [
                view.safeAreaLayoutGuide.topAnchor.constraint(equalTo: imageView.safeAreaLayoutGuide.topAnchor),
                view.safeAreaLayoutGuide.trailingAnchor.constraint(equalTo: imageView.safeAreaLayoutGuide.trailingAnchor),
                view.safeAreaLayoutGuide.bottomAnchor.constraint(equalTo: imageView.safeAreaLayoutGuide.bottomAnchor),
                view.safeAreaLayoutGuide.leadingAnchor.constraint(equalTo: imageView.safeAreaLayoutGuide.leadingAnchor)
            ]
        } else {
            imageViewConstraints = [
                view.topAnchor.constraint(equalTo: imageView.topAnchor),
                view.trailingAnchor.constraint(equalTo: imageView.trailingAnchor),
                view.bottomAnchor.constraint(equalTo: imageView.bottomAnchor),
                view.leadingAnchor.constraint(equalTo: imageView.leadingAnchor)
            ]
        }

        NSLayoutConstraint.activate(imageViewConstraints)
    }

    // MARK: - Actions

    @objc private func reloadImage() {
        if enhancedImageIsAvailable, isCurrentlyDisplayingEnhancedImage {
            imageView.image = results.enhancedScan?.image.rotated(by: rotationAngle) ?? results.enhancedScan?.image
        } else {
            imageView.image = results.croppedScan.image.rotated(by: rotationAngle) ?? results.croppedScan.image
        }
    }

    //    @objc func toggleEnhancedImage() {
    //        guard enhancedImageIsAvailable else { return }
    //
    //        isCurrentlyDisplayingEnhancedImage.toggle()
    //        reloadImage()
    //
    //        if isCurrentlyDisplayingEnhancedImage {
    //            enhanceButton.tintColor = .yellow
    //        } else {
    //            enhanceButton.tintColor = .white
    //        }
    //    }

    //    @objc func rotateImage() {
    //        rotationAngle.value += 90
    //
    //        if rotationAngle.value == 360 {
    //            rotationAngle.value = 0
    //        }
    //
    //        reloadImage()
    //    }

    @objc private func finishScan() {
        guard let imageScannerController = navigationController as? ImageScannerController else { return }

        print("tl: \(results.detectedRectangle.topLeft)")
        print("tr: \(results.detectedRectangle.topRight)")
        print("bl: \(results.detectedRectangle.bottomLeft)")
        print("br: \(results.detectedRectangle.bottomRight)")

        print("dmmmmmmmmmmm")
        //top left
        results.detectedRectangle.topLeft.x += 200;
        results.detectedRectangle.topLeft.y -= 200;

        //top right
        results.detectedRectangle.topRight.x -= 200;
        results.detectedRectangle.topRight.y -= 200;

        //bottom left
        results.detectedRectangle.bottomLeft.x += 200;
        results.detectedRectangle.bottomLeft.y += 200;

        //bottom right
        results.detectedRectangle.bottomRight.x -= 200;
        results.detectedRectangle.bottomRight.y += 200;


        var newResults = results

        print("tl: \(newResults.detectedRectangle.topLeft)")
        print("tr: \(newResults.detectedRectangle.topRight)")
        print("bl: \(newResults.detectedRectangle.bottomLeft)")
        print("br: \(newResults.detectedRectangle.bottomRight)")

        newResults.croppedScan.resizeByCorners(topLeft: newResults.detectedRectangle.topLeft, topRight: newResults.detectedRectangle.topRight, bottomLeft: newResults.detectedRectangle.bottomLeft, bottomRight: newResults.detectedRectangle.bottomRight)
        //        newResults.croppedScan.rotate(by: rotationAngle)
        //        newResults.enhancedScan?.rotate(by: rotationAngle)
        //        newResults.doesUserPreferEnhancedScan = isCurrentlyDisplayingEnhancedImage
        imageScannerController.imageScannerDelegate?.imageScannerController(imageScannerController, didFinishScanningWithResults: newResults)
    }

}
