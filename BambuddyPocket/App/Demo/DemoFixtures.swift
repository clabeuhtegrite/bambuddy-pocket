// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Fixtures JSON du **mode démo** (captures marketing App Store). Toutes les valeurs sont
/// synthétiques et anonymes : aucune donnée réelle, aucun secret, aucune adresse exploitable.
/// Le statut détaillé d'imprimante est dans `DemoFixturesStatus`, les archives dans
/// `DemoFixturesArchives` pour respecter la limite de 500 lignes par fichier.
enum DemoFixtures {
    /// Liste des imprimantes (`GET /printers/`). Deux imprimantes : une en cours, une au repos.
    static let printers = """
    [
      {
        "id": 1, "name": "Atelier — X1 Carbon", "model": "X1C",
        "location": "Atelier", "ip_address": "10.0.1.42",
        "serial_number": "00M00A000000001", "is_active": true,
        "nozzle_count": 1, "auto_archive": true, "external_camera_enabled": false
      },
      {
        "id": 2, "name": "Bureau — A1 mini", "model": "A1MINI",
        "location": "Bureau", "ip_address": "10.0.1.51",
        "serial_number": "00M00A000000002", "is_active": true,
        "nozzle_count": 1, "auto_archive": true, "external_camera_enabled": false
      }
    ]
    """

    /// File d'attente (`GET /queue/`). Un travail en impression, deux en attente, un planifié.
    static let queue = """
    [
      {
        "id": 101, "position": 1, "status": "printing",
        "printer_name": "Atelier — X1 Carbon", "archive_name": "Support Bracket — v3",
        "library_file_name": null, "print_time_seconds": 8520, "filament_used_grams": 42.5,
        "printer_id": 1, "use_ams": true, "timelapse": true
      },
      {
        "id": 102, "position": 2, "status": "waiting",
        "printer_name": "Atelier — X1 Carbon", "archive_name": "Boîtier capteur",
        "library_file_name": null, "print_time_seconds": 13680, "filament_used_grams": 78.0,
        "waiting_reason": "Imprimante occupée", "printer_id": 1, "use_ams": true
      },
      {
        "id": 103, "position": 3, "status": "waiting",
        "printer_name": "Bureau — A1 mini", "archive_name": "Crochet mural ×4",
        "library_file_name": null, "print_time_seconds": 5400, "filament_used_grams": 28.3,
        "printer_id": 2, "use_ams": false
      },
      {
        "id": 104, "position": 4, "status": "scheduled",
        "printer_name": "Atelier — X1 Carbon", "archive_name": "Engrenage 32 dents",
        "library_file_name": null, "print_time_seconds": 4260, "filament_used_grams": 19.8,
        "scheduled_time": "2026-06-07T08:30:00Z", "printer_id": 1, "use_ams": true
      }
    ]
    """

    /// Bibliothèque de modèles (`GET /library/files/`).
    static let libraryFiles = """
    [
      {
        "id": 201, "filename": "support_bracket_v3.3mf", "file_type": "3mf",
        "file_size": 1843200, "print_name": "Support Bracket — v3", "print_count": 7,
        "print_time_seconds": 8520, "filament_used_grams": 42.5,
        "created_at": "2026-05-28T14:12:00Z", "sliced_for_model": "X1C"
      },
      {
        "id": 202, "filename": "boitier_capteur.3mf", "file_type": "3mf",
        "file_size": 2560000, "print_name": "Boîtier capteur", "print_count": 3,
        "print_time_seconds": 13680, "filament_used_grams": 78.0,
        "created_at": "2026-05-22T09:40:00Z"
      },
      {
        "id": 203, "filename": "crochet_mural.stl", "file_type": "stl",
        "file_size": 512000, "print_name": "Crochet mural", "print_count": 12,
        "created_at": "2026-04-30T18:05:00Z"
      },
      {
        "id": 204, "filename": "engrenage_32.3mf", "file_type": "3mf",
        "file_size": 921600, "print_name": "Engrenage 32 dents", "print_count": 5,
        "print_time_seconds": 4260, "filament_used_grams": 19.8,
        "created_at": "2026-05-15T11:20:00Z", "sliced_for_model": "A1MINI"
      }
    ]
    """

    /// Flux d'activité (`GET /notifications/logs`).
    static let activityLog = """
    [
      {
        "id": 9001, "event_type": "print_finished", "title": "Impression terminée",
        "message": "Crochet mural ×4 — Bureau — A1 mini", "success": true,
        "printer_name": "Bureau — A1 mini", "created_at": "2026-06-06T07:14:00Z"
      },
      {
        "id": 9002, "event_type": "archive_created", "title": "Archive créée",
        "message": "Boîtier capteur ajouté aux archives", "success": true,
        "printer_name": "Atelier — X1 Carbon", "created_at": "2026-06-05T19:42:00Z"
      },
      {
        "id": 9003, "event_type": "print_started", "title": "Impression démarrée",
        "message": "Support Bracket — v3 — Atelier — X1 Carbon", "success": true,
        "printer_name": "Atelier — X1 Carbon", "created_at": "2026-06-05T16:03:00Z"
      }
    ]
    """

    /// Réglages serveur (`GET /settings/`) — minimal, l'app tolère les champs absents.
    static let settings = """
    { "language": "fr", "currency": "EUR", "default_printer_id": 1 }
    """

    /// État serveur (`GET /system/info`).
    static let systemInfo = """
    {
      "app": { "version": "0.1.0" },
      "system": { "platform": "Linux", "hostname": "bambuddy" },
      "memory": { "total": 8589934592, "used": 3221225472 },
      "cpu": { "percent": 12.0 },
      "storage": { "total": 274877906944, "used": 96636764160 },
      "database": { "size_bytes": 18874368 }
    }
    """
}
