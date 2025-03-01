/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
Provides the class for the text recognition and the structure to create the bounding boxes.
*/

import SwiftUI
import Vision

@Observable
class OCR {
    /// The array of `RecognizedTextObservation` objects to hold the request's results.
    var observations = [RecognizedTextObservation]()

    /// The Vision request.
    var request = RecognizeTextRequest()

    func performOCR(imageData: Data) async throws {
        /// Clear the `observations` array for photo recapture.
        observations.removeAll()

        /// Perform the request on the image data and return the results.
        let results = try await request.perform(on: imageData)

        /// Add each observation to the `observations` array.
        for observation in results {
            observations.append(observation)
        }
    }
}

/// Create and dynamically size a bounding box.
struct Box: Shape {
    private let normalizedRect: NormalizedRect

    init(observation: any BoundingBoxProviding) {
        normalizedRect = observation.boundingBox
    }

    func path(in rect: CGRect) -> Path {
        let rect = normalizedRect.toImageCoordinates(rect.size, origin: .upperLeft)
        return Path(rect)
    }
}

/// NormalizedPointを利用し、手動で矩形を描画したやつ
struct BigBox: Shape {
    private let topLeft: NormalizedPoint
    private let topRight: NormalizedPoint
    private let bottomLeft: NormalizedPoint
    private let bottomRight: NormalizedPoint
    
    init(observation: any QuadrilateralProviding) {
        self.topLeft = observation.topLeft
        self.topRight = observation.topRight
        self.bottomLeft = observation.bottomLeft
        self.bottomRight = observation.bottomRight
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // `NormalizedPoint` は (0.0 ~ 1.0) の範囲なので `rect` のサイズに合わせる
        let tl = CGPoint(
            x: rect.minX + topLeft.x * rect.width,
            y: rect.minY + (1 - topLeft.y) * rect.height
        )
        let tr = CGPoint(
            x: rect.minX + topRight.x * rect.width,
            y: rect.minY + (1 - topRight.y) * rect.height
        )
        let br = CGPoint(
            x: rect.minX + bottomRight.x * rect.width,
            y: rect.minY + (1 - bottomRight.y) * rect.height
        )
        let bl = CGPoint(
            x: rect.minX + bottomLeft.x * rect.width,
            y: rect.minY + (1 - bottomLeft.y) * rect.height
        )

        // 四角形のパスを作成
        path.move(to: tl)
        path.addLine(to: tr)
        path.addLine(to: br)
        path.addLine(to: bl)
        path.closeSubpath() // 閉じる
        
        return path
    }
}

/// 矩形を、丸くしようとした
/// だけど、失敗したやつ
struct CurveBigBox: Shape {
    private let topLeft: NormalizedPoint
    private let topRight: NormalizedPoint
    private let bottomLeft: NormalizedPoint
    private let bottomRight: NormalizedPoint
    private let cornerRadius: CGFloat // 角の丸み
    
    init(observation: any QuadrilateralProviding, cornerRadius: CGFloat = 10) {
        self.topLeft = observation.topLeft
        self.topRight = observation.topRight
        self.bottomLeft = observation.bottomLeft
        self.bottomRight = observation.bottomRight
        self.cornerRadius = cornerRadius
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // `NormalizedPoint` は (0.0 ~ 1.0) の範囲なので `rect` のサイズに合わせる
        let tl = CGPoint(
            x: rect.minX + topLeft.x * rect.width,
            y: rect.minY + (1 - topLeft.y) * rect.height
        )
        let tr = CGPoint(
            x: rect.minX + topRight.x * rect.width,
            y: rect.minY + (1 - topRight.y) * rect.height
        )
        let br = CGPoint(
            x: rect.minX + bottomRight.x * rect.width,
            y: rect.minY + (1 - bottomRight.y) * rect.height
        )
        let bl = CGPoint(
            x: rect.minX + bottomLeft.x * rect.width,
            y: rect.minY + (1 - bottomLeft.y) * rect.height
        )

        // パスの開始
        path.move(to: CGPoint(x: tl.x + cornerRadius, y: tl.y))
        path.addLine(to: CGPoint(x: tr.x - cornerRadius, y: tr.y)) // 上辺
        path.addQuadCurve(to: CGPoint(x: tr.x, y: tr.y + cornerRadius), control: tr) // 右上角のカーブ

        path.addLine(to: CGPoint(x: br.x, y: br.y - cornerRadius)) // 右辺
        path.addQuadCurve(to: CGPoint(x: br.x - cornerRadius, y: br.y), control: br) // 右下角のカーブ

        path.addLine(to: CGPoint(x: bl.x + cornerRadius, y: bl.y)) // 下辺
        path.addQuadCurve(to: CGPoint(x: bl.x, y: bl.y - cornerRadius), control: bl) // 左下角のカーブ

        path.addLine(to: CGPoint(x: tl.x, y: tl.y + cornerRadius)) // 左辺
        path.addQuadCurve(to: CGPoint(x: tl.x + cornerRadius, y: tl.y), control: tl) // 左上角のカーブ

        return path
    }
}

/// 少し大きめの矩形を描画する
struct SuperBigBox: Shape {
    private let topLeft: NormalizedPoint
    private let topRight: NormalizedPoint
    private let bottomLeft: NormalizedPoint
    private let bottomRight: NormalizedPoint
    private let expansionFactor: CGFloat  // 拡大率 (例: 1.1 → 10% 拡大)

    init(observation: any QuadrilateralProviding, expansionFactor: CGFloat = 1.1) {
        self.topLeft = observation.topLeft
        self.topRight = observation.topRight
        self.bottomLeft = observation.bottomLeft
        self.bottomRight = observation.bottomRight
        self.expansionFactor = expansionFactor
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // 矩形の中心を求める
        let centerX = (topLeft.x + topRight.x + bottomLeft.x + bottomRight.x) / 4
        let centerY = (topLeft.y + topRight.y + bottomLeft.y + bottomRight.y) / 4

        // `NormalizedPoint` を `rect` のサイズに変換し、拡大
        func expand(point: NormalizedPoint) -> CGPoint {
            let expandedX = centerX + (point.x - centerX) * expansionFactor
            let expandedY = centerY + (point.y - centerY) * expansionFactor

            return CGPoint(
                x: rect.minX + expandedX * rect.width,
                y: rect.minY + (1 - expandedY) * rect.height
            )
        }

        let tl = expand(point: topLeft)
        let tr = expand(point: topRight)
        let br = expand(point: bottomRight)
        let bl = expand(point: bottomLeft)

        // 四角形のパスを作成
        path.move(to: tl)
        path.addLine(to: tr)
        path.addLine(to: br)
        path.addLine(to: bl)
        path.closeSubpath()

        return path
    }
}
