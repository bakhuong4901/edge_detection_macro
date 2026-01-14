import UIKit

class QRScannerOverlayView: UIView {

    var borderColor: UIColor = UIColor.cyan
    var borderRadius: CGFloat = 50
    var borderLength: CGFloat = 20
    var borderWidth: CGFloat = 4
    var cutOutSize: CGFloat = UIScreen.main.bounds.width * 0.6
    var cornerRadius: CGFloat = 2// Độ cong của các góc

    override func draw(_ rect: CGRect) {
        super.draw(rect)

        guard let context = UIGraphicsGetCurrentContext() else { return }

        // Kích thước của ô vuông cắt ở giữa
        let cutOutRect = CGRect(
            x: (rect.width - cutOutSize) / 2,
            y: (rect.height - cutOutSize - 100) / 2,
            width: cutOutSize,
            height: cutOutSize
        )

        // Vẽ nền tối xung quanh ô vuông
        context.setFillColor(UIColor.black.withAlphaComponent(0.5).cgColor)
        context.fill(rect)

        // Xóa vùng ô vuông ở giữa
        context.clear(cutOutRect)

        // Thiết lập màu và độ dày cho viền
        context.setStrokeColor(borderColor.cgColor)
        context.setLineWidth(borderWidth)

        // Vẽ các đường viền ở 4 góc
        drawCornerBorders(in: context, cutOutRect: cutOutRect)
    }

    private func drawCornerBorders(in context: CGContext, cutOutRect: CGRect) {
        // 4 góc: trên trái, trên phải, dưới trái, dưới phải
        let corners = [
            CGPoint(x: cutOutRect.minX, y: cutOutRect.minY),
            CGPoint(x: cutOutRect.maxX, y: cutOutRect.minY),
            CGPoint(x: cutOutRect.minX, y: cutOutRect.maxY),
            CGPoint(x: cutOutRect.maxX, y: cutOutRect.maxY)
        ]

        for corner in corners {
            drawCorner(context: context, at: corner, cutOutRect: cutOutRect)
        }
    }
    private func drawCorner(context: CGContext, at corner: CGPoint, cutOutRect: CGRect) {
            let path = UIBezierPath()

            let isLeft = corner.x == cutOutRect.minX
            let isTop = corner.y == cutOutRect.minY

            // Đoạn viền dọc với độ cong
            path.move(to: corner)
            path.addLine(to: CGPoint(
                x: corner.x,
                y: corner.y + (isTop ? borderLength - cornerRadius : -(borderLength - cornerRadius))
            ))
            path.addQuadCurve(
                to: CGPoint(
                    x: corner.x + (isLeft ? cornerRadius : -cornerRadius),
                    y: corner.y + (isTop ? borderLength : -borderLength)
                ),
                controlPoint: CGPoint(
                    x: corner.x + (isLeft ? 0 : 0),
                    y: corner.y + (isTop ? borderLength : -borderLength)
                )
            )

            // Đoạn viền ngang với độ cong
            path.move(to: corner)
            path.addLine(to: CGPoint(
                x: corner.x + (isLeft ? borderLength - cornerRadius : -(borderLength - cornerRadius)),
                y: corner.y
            ))
            path.addQuadCurve(
                to: CGPoint(
                    x: corner.x + (isLeft ? borderLength : -borderLength),
                    y: corner.y + (isTop ? cornerRadius : -cornerRadius)
                ),
                controlPoint: CGPoint(
                    x: corner.x + (isLeft ? borderLength : -borderLength),
                    y: corner.y
                )
            )

            context.addPath(path.cgPath)
            context.strokePath()
        }

//    private func drawCorner(context: CGContext, at corner: CGPoint, cutOutRect: CGRect) {
//        // Điều chỉnh hướng của góc để vẽ viền xung quanh ô vuông
//        let isLeft = corner.x == cutOutRect.minX
//        let isTop = corner.y == cutOutRect.minY
//
//        // Đoạn viền dọc
//        context.move(to: corner)
//        context.addLine(to: CGPoint(
//            x: corner.x,
//            y: corner.y + (isTop ? borderLength : -borderLength)
//        ))
//
//        // Đoạn viền ngang
//        context.move(to: corner)
//        context.addLine(to: CGPoint(
//            x: corner.x + (isLeft ? borderLength : -borderLength),
//            y: corner.y
//        ))
//
//        context.strokePath()
//
//
//    }
}
