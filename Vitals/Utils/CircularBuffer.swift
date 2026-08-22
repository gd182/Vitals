//
//  CircularBuffer.swift
//  Vitals
//
//  Created by Алексей on 6/23/26.
//

struct CircularBuffer<T> {
    private var buffer: [T?]
    private var head: Int
    var count: Int
    
    init(initialCapacity: Int) {
        buffer = [T?](repeating: nil, count: initialCapacity)
        head = 0
        count = 0
    }
    
    mutating func append(value: T) {
        buffer[(head + count) % buffer.count] = value
        if count == buffer.count {
            head = (head + 1) % buffer.count
        }
        else {
            count += 1
        }
    }
    
    func get(index: Int) -> T? {
        return buffer[(head + index) % buffer.count]
    }
    
    func toArray() -> [T] {
        (0..<count).compactMap { i in get(index: i) }
    }
}
