// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
@testable import BambuddyPocketDomain

@Suite("PrinterCreate")
struct PrinterCreateTests {
    @Test("S'encode en snake_case")
    func encodesSnakeCase() throws {
        let create = PrinterCreate(
            name: "X1C",
            serialNumber: "SER123",
            ipAddress: "1.2.3.4",
            accessCode: "0000"
        )
        let data = try JSONEncoder.bambuddy().encode(create)
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("\"serial_number\""))
        #expect(json.contains("\"ip_address\""))
        #expect(json.contains("\"access_code\""))
    }
}
