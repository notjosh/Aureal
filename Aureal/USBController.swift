//
//  AddressableDevice.swift
//  Aureal
//
//  Created by joshua on 29/7/20.
//  Copyright © 2020 nojo, inc. All rights reserved.
//

import Foundation

import IOKit
import IOKit.hid
import IOKit.hidsystem

enum USBControllerError: Error {
    case InterfaceUnavailable
    case CommandTooLong
    case InvalidResponse(code: IOReturn)
}

private let CommandLength = 65

struct AuraUSBController {
    private(set) var device: HIDDevice

    init(_ device: HIDDevice) {
        self.device = device
    }
    
    func send(command: Command) throws {
        // FIXME: this shouldn't need to know directly about EffectCommand
        // TODO: add `DirectCommand` support
        if let effectCommand = command as? EffectCommand {
            try setEffect(command: effectCommand)
            try setColors(command: command)
        }

        try commit()
    }
    
    func setEffect(command: EffectCommand) throws {
        try send(commandBytes: [
            AuraCommand,
            0x35, // "effect control mode"
            0x0, // TODO: channels
            0x0, // unknown
            0x0, // unknown
            command.effect.code,
        ])
    }
    
    func setColors(command: Command) throws {
        let rgbs = command.rgbs
        
        if rgbs.count == 0 {
            return
        }
        
        try send(commandBytes: [
            AuraCommand,
            0x36,
            0x0, // TODO: channels
            0xff, // TODO: only mainboard channel, so fixed it is!
            0x0, // dunno
        ] + rgbs.flatMap { [$0.r, $0.g, $0.b] })
    }
    
    func commit() throws {
        try send(commandBytes: [
            AuraCommand,
            0x3f,
            0x55
        ])
    }
        
    private func send(commandBytes: [UInt8]) throws {
        guard commandBytes.count <= CommandLength else {
            throw USBControllerError.CommandTooLong
        }

        var bytes = commandBytes + [UInt8](repeating: 0, count: CommandLength - commandBytes.count)

        let response = IOHIDDeviceSetReport(
            device.device,
            kIOHIDReportTypeOutput,
            CFIndex(AuraCommand),
            &bytes,
            bytes.count
        )

        if response != kIOReturnSuccess {
            let systemError = String(format:"%02X", ((response >> 26) & 0x3f))
            let subError =  String(format:"%02X", ((response >> 14) & 0xfff))
            let codeError = String(format:"%02X",  ( response & 0x3fff))

            print("HID error: \(systemError), \(subError), \(codeError)")

            throw USBControllerError.InvalidResponse(code: response)
        }
    }
}
