//
//  MapPoint.swift
//  DungeonMapBuilder
//
//  Created by Brian Arnold on 3/28/15.
//  Copyright © 2015-2025 Brian Arnold. Licensed under the MIT License.
//

import Foundation


/// A point in 2D space representing a location on a dungeon map.
///
/// `MapPoint` provides basic vector operations for 2D geometry, including
/// addition, subtraction, negation, and scalar multiplication. It also supports
/// common vector operations like computing length, normalization, perpendicular
/// vectors, and dot products.
///
/// ## Topics
///
/// ### Creating a Point
/// - ``x``
/// - ``y``
///
/// ### Vector Operations
/// - ``length()``
/// - ``normalized()``
/// - ``perpendicular()``
/// - ``dot(_:)``
///
/// ### Operators
/// Use `+` and `-` to add or subtract points, prefix `-` to negate, and `*` to scale by a scalar value.
public struct MapPoint: Codable, Hashable, Sendable, CustomStringConvertible {
    public let x: Double
    public let y: Double
    
    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
    
    public var description: String { "(\(self.x), \(self.y))" }

    public static func +(lhs: MapPoint, rhs: MapPoint) -> MapPoint {
        MapPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }
    
    public static func -(lhs: MapPoint, rhs: MapPoint) -> MapPoint {
        MapPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }
    
    public static prefix func -(point: MapPoint) -> MapPoint {
        MapPoint(x: -point.x, y: -point.y)
    }
    
    public static func *(lhs: MapPoint, rhs: Double) -> MapPoint {
        MapPoint(x: lhs.x * rhs, y: lhs.y * rhs)
    }
    
    public func length() -> Double {
        sqrt(x * x + y * y)
    }
    
    public func normalized() -> MapPoint {
        let len = length()
        guard len > 0 else { return MapPoint(x: 0, y: 0) }
        return MapPoint(x: x / len, y: y / len)
    }
    
    public func perpendicular() -> MapPoint {
        MapPoint(x: -y, y: x)
    }
    
    public func dot(_ other: MapPoint) -> Double {
        x * other.x + y * other.y
    }
}

/// A size in 2D space representing dimensions on a dungeon map.
///
/// `MapSize` provides a simple representation of width and height dimensions,
/// commonly used to describe the bounds of map elements.
///
/// ## Topics
///
/// ### Creating a Size
/// - ``width``
/// - ``height``
public struct MapSize: Codable, Equatable, Hashable, Sendable, CustomStringConvertible {
    public let width: Double
    public let height: Double
    
    public var description: String { "(\(self.width), \(self.height))" }

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

/// A rectangle in 2D space, defined by its origin (minimum corner) and dimensions.
///
/// `MapRect` is used to describe bounding boxes in map units, such as
/// ``DungeonMap/bounds``.
public struct MapRect: Codable, Equatable, Hashable, Sendable {
    public var origin: MapPoint
    public var size: MapSize

    public init(origin: MapPoint, size: MapSize) {
        self.origin = origin
        self.size = size
    }
}

extension Array where Element == MapPoint {
    
    /// Computes the bounding box for this array of map points.
    ///
    /// This method iterates through all points in the array to find the minimum
    /// and maximum x and y coordinates, then returns the origin (minimum corner)
    /// and the size of the bounding rectangle.
    ///
    /// - Returns: A tuple containing:
    ///   - `location`: The minimum corner point of the bounding box (smallest x and y values).
    ///   - `size`: The dimensions of the bounding box computed as the difference between
    ///     the maximum and minimum coordinates.
    ///
    /// - Note: If the array is empty, returns a location and size of zero.
    func computeLocationAndSize() -> (location: MapPoint, size: MapSize) {
        var location = MapPoint(x: 0, y: 0)
        var maxLocation = MapPoint(x: 0, y: 0)
        
        var firstTime = true
        for edge in self {
            if firstTime {
                location = edge
                maxLocation = edge
                firstTime = false
            } else {
                location = MapPoint(x: Swift.min(location.x, edge.x), y: Swift.min(location.y, edge.y))
                maxLocation = MapPoint(x: Swift.max(maxLocation.x, edge.x), y: Swift.max(maxLocation.y, edge.y))
            }
        }
        
        let size = MapSize(width: maxLocation.x - location.x, height: maxLocation.y - location.y)
        return (location, size)
    }
    
    /// Creates an array of four map points representing the corners of a rectangle.
    ///
    /// The points are generated in clockwise order starting from the given location:
    /// 1. Bottom-left (origin)
    /// 2. Bottom-right
    /// 3. Top-right
    /// 4. Top-left
    ///
    /// - Parameters:
    ///   - location: The origin point (bottom-left corner) of the rectangle.
    ///   - size: The dimensions of the rectangle.
    init(location: MapPoint, size: MapSize) {
        self = [
            location,
            MapPoint(x: location.x + size.width, y: location.y),
            MapPoint(x: location.x + size.width, y: location.y + size.height),
            MapPoint(x: location.x, y: location.y + size.height)
        ]
    }

    /// Ray-casting point-in-polygon test, treating `self` as a closed polygon.
    func containsPoint(_ point: MapPoint) -> Bool {
        var inside = false
        var j = count - 1
        for i in 0..<count {
            let xi = self[i].x, yi = self[i].y
            let xj = self[j].x, yj = self[j].y
            if (yi > point.y) != (yj > point.y),
               point.x < (xj - xi) * (point.y - yi) / (yj - yi) + xi {
                inside.toggle()
            }
            j = i
        }
        return inside
    }
}
