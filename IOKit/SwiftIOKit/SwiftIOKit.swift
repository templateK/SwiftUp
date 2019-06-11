//
//  SwiftIOKit.swift
//  SwiftIOKit
//
//  Created by Jeong YunWon on 2018. 9. 1..
//  Copyright © 2018 youknowone.org. All rights reserved.
//

import Foundation
import IOKit
import IOKit.hid
import IOKit.hidsystem

public enum SIOError: Error {
    case kernel(kern_return_t)
}

public class SIOConnect {
    public let rawValue: io_connect_t

    public init(rawValue: io_connect_t) {
        self.rawValue = rawValue
    }

    deinit {
        _ = close()
        IOObjectRelease(rawValue)
    }

    public struct Selector {
        public let rawValue: Int32

        public static let capsLock = Selector(rawValue: Int32(kIOHIDCapsLockState))
        public static let numLock = Selector(rawValue: Int32(kIOHIDNumLockState))
        public static let activityUserIdle = Selector(rawValue: Int32(kIOHIDActivityUserIdle))
        public static let activityDisplayOn = Selector(rawValue: Int32(kIOHIDActivityDisplayOn))
    }

    @discardableResult
    public func close() -> Result<Void, SIOError> {
        let kr = IOServiceClose(rawValue)
        guard kr == KERN_SUCCESS else {
            return .failure(SIOError.kernel(kr))
        }
        return .success(())
    }

    public func getState(selector: Selector) -> Result<UInt32, SIOError> {
        var state: UInt32 = 0
        let kr = IOHIDGetStateForSelector(rawValue, selector.rawValue, &state)
        if kr != KERN_SUCCESS {
            return .failure(SIOError.kernel(kr))
        }
        return .success(state)
    }

    @discardableResult
    public func setState(selector: Selector, state: UInt32) -> Result<Void, SIOError> {
        let kr = IOHIDSetStateForSelector(rawValue, selector.rawValue, state)
        if kr != KERN_SUCCESS {
            return .failure(SIOError.kernel(kr))
        }
        return .success(())
    }

    public func getModifierLock(selector: Selector) -> Result<Bool, SIOError> {
        var state: Bool = false
        let kr = IOHIDGetModifierLockState(rawValue, selector.rawValue, &state)
        if kr != KERN_SUCCESS {
            return .failure(SIOError.kernel(kr))
        }
        return .success(state)
    }

    @discardableResult
    public func setModifierLock(selector: Selector, state: Bool) -> Result<Void, SIOError> {
        let kr = IOHIDSetModifierLockState(rawValue, selector.rawValue, state)
        if kr != KERN_SUCCESS {
            return .failure(SIOError.kernel(kr))
        }
        return .success(())
    }
}

public class SIOService {
    public let rawValue: io_service_t

    public init?(port: mach_port_t, matching: NSDictionary?) {
        rawValue = IOServiceGetMatchingService(port, matching)
        guard rawValue != 0 else {
            return nil
        }
    }

    public convenience init?(name: String) {
        self.init(port: kIOMasterPortDefault, matching: SIOService.matching(name: name))
    }

    deinit {
        IOObjectRelease(rawValue)
    }

    public static func matching(name: String) -> NSDictionary? {
        return IOServiceMatching(name)
    }

    public func open(owningTask: mach_port_t, type: Int) -> Result<SIOConnect, SIOError> {
        var connect: io_connect_t = 0
        let kr = IOServiceOpen(rawValue, owningTask, UInt32(type), &connect)
        guard kr == KERN_SUCCESS else {
            return .failure(SIOError.kernel(kr))
        }
        return .success(SIOConnect(rawValue: connect))
    }
}

public extension IOHIDValueScaleType {
    static let Calibrated = kIOHIDValueScaleTypeCalibrated
    static let Physical = kIOHIDValueScaleTypePhysical
    static let Exponent = kIOHIDValueScaleTypeExponent
}

public extension IOHIDValue {
    typealias ScaleType = IOHIDValueScaleType
    typealias Callback = IOHIDValueCallback
    typealias MultipleCallback = IOHIDValueMultipleCallback

    var element: IOHIDElement {
        return IOHIDValueGetElement(self)
    }

    var timestamp: UInt64 {
        return IOHIDValueGetTimeStamp(self)
    }

    var length: CFIndex {
        return IOHIDValueGetLength(self)
    }

    var integerValue: CFIndex {
        return IOHIDValueGetIntegerValue(self)
    }

    func scaledValue(ofType type: ScaleType) -> Double {
        return IOHIDValueGetScaledValue(self, type)
    }
}

public extension IOHIDManager {
    class func create(options: IOOptionBits) -> IOHIDManager {
        return IOHIDManagerCreate(kCFAllocatorDefault, options)
    }

    class func create() -> IOHIDManager {
        return create(options: IOOptionBits(kIOHIDOptionsTypeNone))
    }

    func open() -> IOReturn {
        return open(options: IOOptionBits(kIOHIDOptionsTypeNone))
    }

    func open(options: IOOptionBits) -> IOReturn {
        return IOHIDManagerOpen(self, options)
    }

    func close() -> IOReturn {
        return close(options: IOOptionBits(kIOHIDOptionsTypeNone))
    }

    func close(options: IOOptionBits) -> IOReturn {
        return IOHIDManagerClose(self, options)
    }

    func schedule(runloop: RunLoop, mode: RunLoop.Mode) {
        IOHIDManagerScheduleWithRunLoop(self, runloop.getCFRunLoop(), mode.rawValue as CFString)
    }

    func unschedule(runloop: RunLoop, mode: RunLoop.Mode) {
        IOHIDManagerUnscheduleFromRunLoop(self, runloop.getCFRunLoop(), mode.rawValue as CFString)
    }

    func setDeviceMatching(page: Int, usage: Int) {
        let deviceMatching = IOHIDManager.deviceMatching(page: page, usage: usage)
        IOHIDManagerSetDeviceMatching(self, deviceMatching)
    }

    func setInputValueMatching(min: Int, max: Int) {
        let inputValueMatching = IOHIDManager.inputValueMatching(min: min, max: max)
        IOHIDManagerSetInputValueMatching(self, inputValueMatching)
    }

    func registerInputValueCallback(_ callback: @escaping IOHIDValue.Callback, context: UnsafeMutableRawPointer?) {
        IOHIDManagerRegisterInputValueCallback(self, callback, context)
    }

    func unregisterInputValueCallback() {
        IOHIDManagerRegisterInputValueCallback(self, nil, nil)
    }

    private class func deviceMatching(page: Int, usage: Int) -> NSDictionary {
        return [
            kIOHIDDeviceUsagePageKey as NSString: NSNumber(value: page),
            kIOHIDDeviceUsageKey as NSString: NSNumber(value: usage),
        ]
    }

    private class func inputValueMatching(min: Int, max: Int) -> NSDictionary {
        return [
            kIOHIDElementUsageMinKey as NSString: NSNumber(value: min),
            kIOHIDElementUsageMaxKey as NSString: NSNumber(value: max),
        ]
    }
}
