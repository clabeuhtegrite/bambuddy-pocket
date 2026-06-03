// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
@testable import BambuddyPocketDomain

@Suite("Auth")
struct AuthTests {
    @Test("LoginResponse — défi 2FA")
    func decodesTwoFactorChallenge() throws {
        let json = #"""
        {"token_type":"bearer","requires_2fa":true,"pre_auth_token":"pre123","two_fa_methods":["totp","email"]}
        """#
        let data = try #require(json.data(using: .utf8))
        let response = try JSONDecoder.bambuddy().decode(LoginResponse.self, from: data)
        #expect(response.needsTwoFactor)
        #expect(response.preAuthToken == "pre123")
        #expect(response.twoFaMethods == ["totp", "email"])
        #expect(response.accessToken == nil)
    }

    @Test("LoginResponse — token direct + utilisateur")
    func decodesDirectToken() throws {
        let json = #"""
        {"access_token":"jwt-abc","token_type":"bearer","requires_2fa":false,
         "user":{"id":1,"username":"ad","role":"admin","is_active":true,"is_admin":true,
         "created_at":"2026-01-01T00:00:00Z"}}
        """#
        let data = try #require(json.data(using: .utf8))
        let response = try JSONDecoder.bambuddy().decode(LoginResponse.self, from: data)
        #expect(response.accessToken == "jwt-abc")
        #expect(response.needsTwoFactor == false)
        #expect(response.user?.username == "ad")
        #expect(response.user?.isAdmin == true)
    }

    @Test("LoginRequest s'encode avec username/password")
    func encodesRequest() throws {
        let data = try JSONEncoder.bambuddy().encode(LoginRequest(username: "ad", password: "pw"))
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("\"username\""))
        #expect(json.contains("\"password\""))
    }
}
