//
//  GradientLineView.swift
//  Vitals
//
//  Created by Алексей on 7/29/26.
//

import SwiftUI

struct GradientLineView: View {
    let segments: [Segment]
    let namespace: String
    @AppStorage var lineWidth: Double
    @AppStorage var height: Double
    @AppStorage var transitionWidth: Double
    
    init(segments: [Segment], namespace: String) {
            self.segments = segments
            self.namespace = namespace
            _lineWidth = AppStorage(wrappedValue: 1.5, "\(namespace).lineWidth")
            _height = AppStorage(wrappedValue: 60.0, "\(namespace).height")
            _transitionWidth = AppStorage(wrappedValue: 20.0, "\(namespace).transitionWidth")
        }

    private var sortedSegments: [Segment] {
        segments
            .map { segment in
                var copy = segment
                copy.points.sort { $0.index < $1.index }
                return copy
            }
            .filter { !$0.points.isEmpty }
            .sorted {
                ($0.points.first?.index ?? .max) <
                ($1.points.first?.index ?? .max)
            }
    }

    var body: some View {
        Canvas { context, size in
            let sorted = sortedSegments
            let sourcePoints = sorted.flatMap(\.points)


            guard sourcePoints.count > 1,
                  let indexRange = makeIndexRange(points: sourcePoints)
            else {
                return
            }

            let points = makePoints(
                from: sourcePoints,
                size: size,
                indexRange: indexRange
            )

            guard points.count > 1 else {
                return
            }

            let categoryGradient = makeCategoryGradient(
                segments: sorted,
                indexRange: indexRange,
                transitionWidth: transitionWidth,
                canvasWidth: size.width
            )

            drawArea(
                context: context,
                points: points,
                size: size,
                categoryGradient: categoryGradient
            )

            let linePath = makePath(points: points)

            context.stroke(
                linePath,
                with: .linearGradient(
                    categoryGradient,
                    startPoint: CGPoint(
                        x: 0,
                        y: size.height / 2
                    ),
                    endPoint: CGPoint(
                        x: size.width,
                        y: size.height / 2
                    )
                ),
                style: StrokeStyle(
                    lineWidth: lineWidth,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
        }
        .frame(height: height)
    }


    private func drawArea(context: GraphicsContext, points: [CGPoint], size: CGSize, categoryGradient: Gradient) {
        let areaPath = makeAreaPath(
            points: points,
            bottomY: size.height
        )

        context.drawLayer { layer in
            /*
             Сначала рисуем горизонтальный градиент категорий:
             normal → warning → critical.
             */
            layer.fill(
                areaPath,
                with: .linearGradient(
                    categoryGradient,
                    startPoint: CGPoint(
                        x: 0,
                        y: size.height / 2
                    ),
                    endPoint: CGPoint(
                        x: size.width,
                        y: size.height / 2
                    )
                )
            )

            layer.blendMode = .destinationIn

            layer.fill(
                areaPath,
                with: .linearGradient(
                    Gradient(stops: [
                        .init(
                            color: .white.opacity(0.35),
                            location: 0
                        ),
                        .init(
                            color: .white.opacity(0.10),
                            location: 0.7
                        ),
                        .init(
                            color: .clear,
                            location: 1
                        )
                    ]),
                    startPoint: CGPoint(
                        x: 0,
                        y: 0
                    ),
                    endPoint: CGPoint(
                        x: 0,
                        y: size.height
                    )
                )
            )
        }
    }

    // MARK: - Gradient

    private func makeCategoryGradient(
        segments: [Segment],
        indexRange: ClosedRange<Int>,
        transitionWidth: CGFloat,
        canvasWidth: CGFloat
    ) -> Gradient {

        guard let firstSegment = segments.first else {
            return Gradient(colors: [
                .clear,
                .clear
            ])
        }

        let minIndex = indexRange.lowerBound
        let maxIndex = indexRange.upperBound
        let indexDistance = maxIndex - minIndex

        guard indexDistance > 0 else {
            let segmentColor = firstSegment.category.color

            return Gradient(colors: [
                segmentColor,
                segmentColor
            ])
        }

        func location(for index: Int) -> CGFloat {
            let normalized =
                CGFloat(index - minIndex) /
                CGFloat(indexDistance)

            return min(max(normalized, 0), 1)
        }

        let normalizedTransitionWidth =
            transitionWidth / max(canvasWidth, 1)

        var stops: [Gradient.Stop] = []

        for segmentIndex in segments.indices {
            let segment = segments[segmentIndex]

            guard let segmentFirstPoint = segment.points.first,
                  let segmentLastPoint = segment.points.last
            else {
                continue
            }

            let currentColor = segment.category.color

            let segmentStart = location(for: segmentFirstPoint.index)

            let segmentEnd = location(for: segmentLastPoint.index)

            if segmentIndex == segments.startIndex {
                stops.append(Gradient.Stop(color: currentColor, location: segmentStart))
            }

            let nextIndex = segments.index(
                after: segmentIndex
            )

            if nextIndex < segments.endIndex {
                let nextSegment = segments[nextIndex]

                guard let nextFirstPoint =
                        nextSegment.points.first
                else {
                    continue
                }

                let nextColor = nextSegment.category.color

                let transitionStart = max(0, segmentEnd - normalizedTransitionWidth / 2)

                let transitionEnd = min(1, segmentEnd + normalizedTransitionWidth / 2)

                stops.append(Gradient.Stop(color: currentColor,location: transitionStart))

                stops.append(Gradient.Stop(color: nextColor, location: transitionEnd))
            } else {
                stops.append(Gradient.Stop( color: currentColor, location: segmentEnd))
            }
        }

        let sortedStops = stops.sorted {
            $0.location < $1.location
        }

        guard sortedStops.count >= 2 else {
            let segmentColor = firstSegment.category.color

            return Gradient(colors: [segmentColor, segmentColor])
        }

        return Gradient(stops: sortedStops)
    }

    private func makeIndexRange(points: [(index: Int, value: Float)]) -> ClosedRange<Int>? {
        guard let minIndex = points.min(by: { $0.index < $1.index })?.index,
              let maxIndex = points.max(by: { $0.index < $1.index })?.index,
              minIndex < maxIndex
        else { return nil }
        return minIndex...maxIndex
    }

    private func makePoints(from sourcePoints: [(index: Int, value: Float)], size: CGSize, indexRange: ClosedRange<Int>) -> [CGPoint] {
        let minIndex = indexRange.lowerBound
        let maxIndex = indexRange.upperBound
        let indexDistance = maxIndex - minIndex
        
        guard indexDistance > 0 else {
            return []
        }
        
        return sourcePoints.map { point in
            let normalizedX = CGFloat(point.index - minIndex) / CGFloat(indexDistance)
            
            let clampedValue = min(max(CGFloat(point.value), 0), 100)
            
            let normalizedY = clampedValue / 100
            
            return CGPoint(x: normalizedX * size.width, y: (1 - normalizedY) * size.height)
        }
    }

    private func makePath(points: [CGPoint]) -> Path {
        guard let firstPoint = points.first else {
            return Path()
        }

        var path = Path()
        path.move(to: firstPoint)

        appendSmoothCurve(to: &path,points: points)

        return path
    }

    private func makeAreaPath(points: [CGPoint], bottomY: CGFloat) -> Path {
        guard let firstPoint = points.first,
              let lastPoint = points.last
        else {
            return Path()
        }

        var path = Path()
        path.move(to: firstPoint)

        appendSmoothCurve(to: &path,points: points)

        path.addLine(to: CGPoint(x: lastPoint.x, y: bottomY))

        path.addLine(to: CGPoint(x: firstPoint.x, y: bottomY))

        path.closeSubpath()

        return path
    }

    private func appendSmoothCurve(to path: inout Path, points: [CGPoint]) {
        guard points.count > 1 else {
            return
        }

        for index in 0..<(points.count - 1) {
            let current = points[index]
            let next = points[index + 1]

            let middleX = (current.x + next.x) / 2

            path.addCurve(to: next, control1: CGPoint(x: middleX, y: current.y), control2: CGPoint(x: middleX,y: next.y))
        }
    }
}
