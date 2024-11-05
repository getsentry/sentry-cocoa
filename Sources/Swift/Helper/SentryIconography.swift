import CoreGraphics

struct SentryIconography {
    static let logo = {
        let svg = """
<svg class="css-lfbo6j e1igk8x04" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 72 66" width="400" height="367"><path d="M29,2.26a4.67,4.67,0,0,0-8,0L14.42,13.53A32.21,32.21,0,0,1,32.17,40.19H27.55A27.68,27.68,0,0,0,12.09,17.47L6,28a15.92,15.92,0,0,1,9.23,12.17H4.62A.76.76,0,0,1,4,39.06l2.94-5a10.74,10.74,0,0,0-3.36-1.9l-2.91,5a4.54,4.54,0,0,0,1.69,6.24A4.66,4.66,0,0,0,4.62,44H19.15a19.4,19.4,0,0,0-8-17.31l2.31-4A23.87,23.87,0,0,1,23.76,44H36.07a35.88,35.88,0,0,0-16.41-31.8l4.67-8a.77.77,0,0,1,1.05-.27c.53.29,20.29,34.77,20.66,35.17a.76.76,0,0,1-.68,1.13H40.6q.09,1.91,0,3.81h4.78A4.59,4.59,0,0,0,50,39.43a4.49,4.49,0,0,0-.62-2.28Z" transform="translate(11, 11)" fill="#362d59"></path></svg>
"""
        let path = CGMutablePath()

        // M 29,2.26
        // Pick up the pen and Move it to { x: 29, y: 2.26 }
        path.move(to: CGPoint(x: 29, y: 2.26))

        // a 4.67,4.67 0 0 0 -8,0
        // Put down the pen and Draw an Arc curve from the current point to a new point { x: previous point - 8, y: previous point + 0 }
        // Its radii are { x: 4.67, y: 4.67 }, and with no rotation
        // Out of the 4 possible arcs described by the above parameters, this arc is the one lesser than 180 degrees and moving at negative angles
        path.addArc(center: CGPoint(x: 21, y: 2.26), radius: 4.67, startAngle: CGFloat.pi, endAngle: 0, clockwise: false)

        // L 14.42,13.53
        // Draw a line to { x: 14.42, y: 13.53 }
        path.addLine(to: CGPoint(x: 14.42, y: 13.53))

        // A 32.21,32.21 0 0 1 32.17,40.19
        // Draw an Arc curve from the current point to a new point { x: 32.17, y: 40.19 }
        // Its radii are { x: 32.21, y: 32.21 }, and with no rotation
        // Out of the 4 possible arcs described by the above parameters, this arc is the one lesser than 180 degrees and moving at positive angles
        path.addArc(center: CGPoint(x: 32.17, y: 26.53), radius: 32.21, startAngle: CGFloat.pi, endAngle: 0, clockwise: true)

        // H 27.55
        // Move horizontally to 27.55
        path.addLine(to: CGPoint(x: 27.55, y: 26.53))

        // A 27.68,27.68 0 0 0 12.09,17.47
        // Draw an Arc curve from the current point to a new point { x: 12.09, y: 17.47 }
        // Its radii are { x: 27.68, y: 27.68 }, and with no rotation
        // Out of the 4 possible arcs described by the above parameters, this arc is the one lesser than 180 degrees and moving at negative angles
        path.addArc(center: CGPoint(x: 19.62, y: 17.47), radius: 27.68, startAngle: CGFloat.pi, endAngle: 0, clockwise: false)

        // L 6,28
        // Draw a line to { x: 6, y: 28 }
        path.addLine(to: CGPoint(x: 6, y: 28))

        // a 15.92,15.92 0 0 1 9.23,12.17
        // Draw an Arc curve from the current point to a new point { x: previous point + 9.23, y: previous point + 12.17 }
        // Its radii are { x: 15.92, y: 15.92 }, and with no rotation
        // Out of the 4 possible arcs described by the above parameters, this arc is the one lesser than 180 degrees and moving at positive angles
        path.addArc(center: CGPoint(x: 15.23, y: 40.17), radius: 15.92, startAngle: 0, endAngle: CGFloat.pi / 2, clockwise: true)

        // H 4.62
        // Move horizontally to 4.62
        path.addLine(to: CGPoint(x: 4.62, y: 40.17))

        // A 0.76,0.76 0 0 1 4,39.06
        // Draw an Arc curve from the current point to a new point { x: 4, y: 39.06 }
        // Its radii are { x: 0.76, y: 0.76 }, and with no rotation
        // Out of the 4 possible arcs described by the above parameters, this arc is the one lesser than 180 degrees and moving at positive angles
        path.addArc(center: CGPoint(x: 4, y: 39.06), radius: 0.76, startAngle: 0, endAngle: CGFloat.pi / 2, clockwise: true)

        // l 2.94,-5
        // Move right 2.94 and top 5 from the current position
        path.addLine(to: CGPoint(x: 7.56, y: 34.06))

        // a 10.74,10.74 0 0 0 -3.36,-1.9
        // Draw an Arc curve from the current point to a new point { x: previous point - 3.36, y: previous point - 1.9 }
        // Its radii are { x: 10.74, y: 10.74 }, and with no rotation
        // Out of the 4 possible arcs described by the above parameters, this arc is the one lesser than 180 degrees and moving at negative angles
        path.addArc(center: CGPoint(x: 4.2, y: 32.16), radius: 10.74, startAngle: CGFloat.pi, endAngle: 0, clockwise: false)

        // l -2.91,5
        // Move left 2.91 and bottom 5 from the current position
        path.addLine(to: CGPoint(x: 4.62, y: 39.06))

        // a 4.54,4.54 0 0 0 1.69,6.24
        // Draw an Arc curve from the current point to a new point { x: previous point + 1.69, y: previous point + 6.24 }
        // Its radii are { x: 4.54, y: 4.54 }, and with no rotation
        // Out of the 4 possible arcs described by the above parameters, this arc is the one lesser than 180 degrees and moving at negative angles
        path.addArc(center: CGPoint(x: 4.62, y: 44), radius: 4.54, startAngle: 0, endAngle: CGFloat.pi / 2, clockwise: false)

        // A 4.66,4.66 0 0 0 4.62,44
        // Draw an Arc curve from the current point to a new point { x: 4.62, y: 44 }
        // Its radii are { x: 4.66, y: 4.66 }, and with no rotation
        // Out of the 4 possible arcs described by the above parameters, this arc is the one lesser than 180 degrees and moving at negative angles
        path.addArc(center: CGPoint(x: 4.62, y: 44), radius: 4.66, startAngle: 0, endAngle: CGFloat.pi / 2, clockwise: false)

        // H 19.15
        // Move horizontally to 19.15
        path.addLine(to: CGPoint(x: 19.15, y: 44))

        // a 19.4,19.4 0 0 0 -8,-17.31
        // Draw an Arc curve from the current point to a new point { x: previous point - 8, y: previous point - 17.31 }
        // Its radii are { x: 19.4, y: 19.4 }, and with no rotation
        // Out of the 4 possible arcs described by the above parameters, this arc is the one lesser than 180 degrees and moving at negative angles
        path.addArc(center: CGPoint(x: 11.15, y: 26.69), radius: 19.4, startAngle: CGFloat.pi, endAngle: 0, clockwise: false)

        // l 2.31,-4
        // Move right 2.31 and top 4 from the current position
        path.addLine(to: CGPoint(x: 21.46, y: 40.69))

        // A 23.87,23.87 0 0 1 23.76,44
        // Draw an Arc curve from the current point to a new point { x: 23.76, y: 44 }
        // Its radii are { x: 23.87, y: 23.87 }, and with no rotation
        // Out of the 4 possible arcs described by the above parameters, this arc is the one lesser than 180 degrees and moving at positive angles
        path.addArc(center: CGPoint(x: 23.76, y: 44), radius: 23.87, startAngle: CGFloat.pi, endAngle: 0, clockwise: true)

        // H 36.07
        // Move horizontally to 36.07
        path.addLine(to: CGPoint(x: 36.07, y: 44))

        // a 35.88,35.88 0 0 0 -16.41,-31.8
        // Draw an Arc curve from the current point to a new point { x: previous point - 16.41, y: previous point - 31.8 }
        // Its radii are { x: 35.88, y: 35.88 }, and with no rotation
        // Out of the 4 possible arcs described by the above parameters, this arc is the one lesser than 180 degrees and moving at negative angles
        path.addArc(center: CGPoint(x: 19.66, y: 12.2), radius: 35.88, startAngle: CGFloat.pi, endAngle: 0, clockwise: false)

        // l 4.67,-8
        // Move right 4.67 and top 8 from the current position
        path.addLine(to: CGPoint(x: 40.74, y: 36.07))

        // a 0.77,0.77 0 0 1 1.05,-0.27
        // Draw an Arc curve from the current point to a new point { x: previous point + 1.05, y: previous point - 0.27 }
        // Its radii are { x: 0.77, y: 0.77 }, and with no rotation
        // Out of the 4 possible arcs described by the above parameters, this arc is the one lesser than 180 degrees and moving at positive angles
        path.addArc(center: CGPoint(x: 41.81, y: 35.8), radius: 0.77, startAngle: CGFloat.pi, endAngle: 0, clockwise: true)

        // c 0.53,0.29 20.29,34.77 20.66,35.17
        // Draw a Bézier curve from the current point to a new point { x: previous point + 20.66, y: previous point + 35.17 }
        // The start control point is { x: previous point + 0.53, y: previous point + 0.29 } and the end control point is { x: previous point + 20.29, y: previous point + 34.77 }
        path.addCurve(to: CGPoint(x: 20.66, y: 35.17), control1: CGPoint(x: 21.34, y: 36.09), control2: CGPoint(x: 20.29, y: 34.77))

        // a 0.76,0.76 0 0 1 -0.68,1.13
        // Draw an Arc curve from the current point to a new point { x: previous point - 0.68, y: previous point + 1.13 }
        // Its radii are { x: 0.76, y: 0.76 }, and with no rotation
        // Out of the 4 possible arcs described by the above parameters, this arc is the one lesser than 180 degrees and moving at positive angles
        path.addArc(center: CGPoint(x: 40.6, y: 40.6), radius: 0.76, startAngle: 0, endAngle: CGFloat.pi / 2, clockwise: true)

        // H 40.6
        // Move horizontally to 40.6
        path.addLine(to: CGPoint(x: 40.6, y: 44.41))

        // q 0.09,1.91 0,3.81
        // Draw a quadratic Bézier curve from the current point to a new point { x: previous point + 0, y: previous point + 3.81 }
        // The control point is { x: previous point + 0.09, y: previous point + 1.91 }
        path.addQuadCurve(to: CGPoint(x: 40.6, y: 48.22), control: CGPoint(x: 40.69, y: 46.32))

        // h 4.78
        // Move right 4.78 from the current position
        path.addLine(to: CGPoint(x: 45.38, y: 48.22))

        // A 4.59,4.59 0 0 0 50,39.43
        // Draw an Arc curve from the current point to a new point { x: 50, y: 39.43 }
        // Its radii are { x: 4.59, y: 4.59 }, and with no rotation
        // Out of the 4 possible arcs described by the above parameters, this arc is the one lesser than 180 degrees and moving at negative angles
        path.addArc(center: CGPoint(x: 50, y: 39.43), radius: 4.59, startAngle: 0, endAngle: CGFloat.pi / 2, clockwise: false)

        // a 4.49,4.49 0 0 0 -0.62,-2.28
        // Draw an Arc curve from the current point to a new point { x: previous point - 0.62, y: previous point - 2.28 }
        // Its radii are { x: 4.49, y: 4.49 }, and with no rotation
        // Out of the 4 possible arcs described by the above parameters, this arc is the one lesser than 180 degrees and moving at negative angles
        path.addArc(center: CGPoint(x: 49.38, y: 37.15), radius: 4.49, startAngle: 0, endAngle: CGFloat.pi / 2, clockwise: false)

        // Z
        // Draw a line straight back to the start
        path.closeSubpath()

        return path
    }()
    
    static let megaphone = {
        let path = CGMutablePath()
                
        path.move(to: CGPoint(x: 1, y: 3))
        path.addLine(to: CGPoint(x: 7, y: 3))
        path.addLine(to: CGPoint(x: 10, y: 1))
        path.addLine(to: CGPoint(x: 12, y: 1))
        path.addLine(to: CGPoint(x: 12, y: 11))
        path.addLine(to: CGPoint(x: 10, y: 11))
        path.addLine(to: CGPoint(x: 7, y: 9))
        path.addLine(to: CGPoint(x: 1, y: 9))
        path.closeSubpath()
        
        path.addRect(CGRect(x: 2, y: 9, width: 3.5, height: 6))
        
        path.move(to: CGPoint(x: 12, y: 6))
        path.addRelativeArc(center: CGPoint(x: 12, y: 6), radius: 3, startAngle: -(.pi / 2), delta: .pi)
        
        return path
    }()
}
