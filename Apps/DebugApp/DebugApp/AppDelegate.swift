import UIKit

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = FingertipWindow(frame: UIScreen.main.bounds)
        window.rootViewController = DebugViewController()
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}

final class FingertipWindow: UIWindow {

    var strokeColor: UIColor = .black

    var fillColor: UIColor = .white

    var touchAlpha: CGFloat = 0.5

    private var _overlayWindow: UIWindow!
    private var overlayWindow: UIWindow {
        if _overlayWindow == nil {
            _overlayWindow = FingertipOverlayWindow(frame: frame)
            _overlayWindow.isUserInteractionEnabled = false
            _overlayWindow.windowLevel = .statusBar
            _overlayWindow.backgroundColor = .clear
            _overlayWindow.isHidden = false
        }
        return _overlayWindow
    }

    private var _touchImage: UIImage!
    var touchImage: UIImage {
        get {
            if _touchImage == nil {
                let clipPath = UIBezierPath(rect: CGRect(x: 0, y: 0, width: 50, height: 50))
                UIGraphicsBeginImageContextWithOptions(clipPath.bounds.size, false, 0)

                let drawPath = UIBezierPath(arcCenter: CGPoint(x: 25, y: 25), radius: 22, startAngle: 0, endAngle: 2 * .pi, clockwise: true)

                drawPath.lineWidth = 2

                strokeColor.setStroke()
                fillColor.setFill()

                drawPath.stroke()
                drawPath.fill()

                clipPath.addClip()

                _touchImage = UIGraphicsGetImageFromCurrentImageContext()

                UIGraphicsEndImageContext()
            }
            return _touchImage
        }
        set {
            _touchImage = newValue
        }
    }

    override func sendEvent(_ event: UIEvent) {
        let allTouches = event.allTouches ?? []

        for touch in allTouches {
            switch touch.phase {
            case .began, .moved, .stationary:
                var touchView = overlayWindow.viewWithTag(touch.hash) as? FingertipView

                if touchView == nil, touch.phase != .stationary {
                    touchView = FingertipView(image: touchImage)
                    overlayWindow.addSubview(touchView!)
                }

                if let touchView = touchView {
                    touchView.alpha = touchAlpha
                    touchView.center = touch.location(in: overlayWindow)
                    touchView.tag = touch.hash
                    touchView.timestamp = touch.timestamp
                    touchView.shouldAutomaticallyRemoveAfterTimeout = shouldAutomaticallyRemoveFingerTip(for: touch)
                }
            case .ended, .cancelled:
                removeFingertip(withHash: touch.hash)
            case .regionEntered, .regionMoved, .regionExited:
                break
            @unknown default:
                break
            }
        }

        super.sendEvent(event)

        scheduleFingertipRemoval()
    }

    var fingertipRemovalScheduled = false
    func scheduleFingertipRemoval() {
        if fingertipRemovalScheduled {
            return
        }

        fingertipRemovalScheduled = true
        perform(#selector(removeInactiveFingertips), with: nil, afterDelay: 0.1)
    }

    func cancelScheduledFingertipRemoval() {
        fingertipRemovalScheduled = true
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(removeInactiveFingertips), object: nil)
    }

    @objc func removeInactiveFingertips() {
        fingertipRemovalScheduled = false

        let now = ProcessInfo.processInfo.systemUptime
        let removalDelay = 0.2

        for view in overlayWindow.subviews {
            guard let touchView = view as? FingertipView else {
                continue
            }
            if touchView.shouldAutomaticallyRemoveAfterTimeout, now > touchView.timestamp + removalDelay {
                removeFingertip(withHash: touchView.tag)
            }
        }

        if !overlayWindow.subviews.isEmpty {
            scheduleFingertipRemoval()
        }
    }

    func removeFingertip(withHash hash: Int) {
        guard let touchView = overlayWindow.viewWithTag(hash) as? FingertipView else {
            return
        }

        touchView.removeFromSuperview()

    }

    func shouldAutomaticallyRemoveFingerTip(for touch: UITouch) -> Bool {
        // We don't reliably get UITouchPhaseEnded or UITouchPhaseCancelled
        // events via -sendEvent: for certain touch events. Known cases
        // include swipe-to-delete on a table view row, and tap-to-cancel
        // swipe to delete. We automatically remove their associated
        // fingertips after a suitable timeout.
        //
        // It would be much nicer if we could remove all touch events after
        // a suitable time out, but then we'll prematurely remove touch and
        // hold events that are picked up by gesture recognizers (since we
        // don't use UITouchPhaseStationary touches for those. *sigh*). So we
        // end up with this more complicated setup.

        var view = touch.view
        view = view?.hitTest(touch.location(in: view), with: nil)

        while let v = view {
            if v.isKind(of: UITableViewCell.self) {
                for recognizer in touch.gestureRecognizers ?? [] {
                    if recognizer.isKind(of: UISwipeGestureRecognizer.self) {
                        return true
                    }
                }
            }

            if v.isKind(of: UITableView.self) {
                if (touch.gestureRecognizers?.count ?? 0) == 0 {
                    return true
                }
            }

            view = v.superview;
        }

        return false
    }

}

final class FingertipOverlayWindow: UIWindow {

    // UIKit tries to get the rootViewController from the overlay window. Use the Fingertips window instead. This fixes
    // issues with status bar behavior, as otherwise the overlay window would control the status bar.

    override var rootViewController: UIViewController? {
        get {
            let mainWindow = UIApplication.shared.windows.compactMap { $0 as? FingertipWindow }.first
            return mainWindow?.rootViewController ?? super.rootViewController
        }
        set {
            super.rootViewController = newValue
        }
    }
}

final class FingertipView: UIImageView {
    var timestamp: TimeInterval = 0
    var shouldAutomaticallyRemoveAfterTimeout: Bool = false
}
