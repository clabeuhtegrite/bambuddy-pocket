// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
@testable import BambuddyPocketDomain

@Suite("LibraryFolder")
struct LibraryFolderTests {
    @Test("Décode l'arbre de dossiers récursif (children)")
    func decodesFolderTree() throws {
        let json = #"""
        [{"id":1,"name":"Parent","parent_id":null,"file_count":0,"is_external":false,
          "children":[{"id":2,"name":"Child","parent_id":1,"file_count":3,"children":[]}]}]
        """#
        let data = try #require(json.data(using: .utf8))
        let folders = try JSONDecoder.bambuddy().decode([FolderTreeItem].self, from: data)
        let parent = try #require(folders.first)
        #expect(parent.name == "Parent")
        #expect(parent.parentID == nil)
        #expect(parent.subfolders.count == 1)
        let child = parent.subfolders[0]
        #expect(child.id == 2)
        #expect(child.parentID == 1)
        #expect(child.fileCount == 3)
        #expect(child.subfolders.isEmpty)
    }

    @Test("Encode FileMoveRequest avec folder_id (déplacement) et null (racine)")
    func encodesMoveRequest() throws {
        let toFolder = try JSONSerialization.jsonObject(
            with: JSONEncoder.bambuddy().encode(FileMoveRequest(fileIDs: [2, 5], folderID: 1))
        ) as? [String: Any]
        #expect(toFolder?["folder_id"] as? Int == 1)
        #expect((toFolder?["file_ids"] as? [Int]) == [2, 5])

        let toRoot = try JSONSerialization.jsonObject(
            with: JSONEncoder.bambuddy().encode(FileMoveRequest(fileIDs: [2], folderID: nil))
        ) as? [String: Any]
        // folder_id doit être présent et nul (NSNull) pour replacer à la racine.
        #expect(toRoot?["folder_id"] is NSNull)
    }

    @Test("Décode la réponse de déplacement")
    func decodesMoveResult() throws {
        let json = #"{"status":"success","moved":1,"skipped":0,"skipped_reasons":[]}"#
        let data = try #require(json.data(using: .utf8))
        let result = try JSONDecoder.bambuddy().decode(FileMoveResult.self, from: data)
        #expect(result.status == "success")
        #expect(result.moved == 1)
        #expect(result.skipped == 0)
    }

    @Test("Décode la corbeille (items + total + rétention)")
    func decodesTrash() throws {
        let json = #"""
        {"items":[{"id":1,"filename":"bracket.gcode.3mf","file_size":2048,"folder_id":null,
          "folder_name":null,"deleted_at":"2026-06-03T21:57:49.603863",
          "auto_purge_at":"2026-07-03T21:57:49.603863"}],"total":1,"retention_days":30}
        """#
        let data = try #require(json.data(using: .utf8))
        let trash = try JSONDecoder.bambuddy().decode(TrashListResponse.self, from: data)
        #expect(trash.total == 1)
        #expect(trash.retentionDays == 30)
        let item = try #require(trash.items.first)
        #expect(item.filename == "bracket.gcode.3mf")
        #expect(item.fileSize == 2048)
    }
}
