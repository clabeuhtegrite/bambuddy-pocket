// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

extension DemoFixtures {
    /// Archives d'impression (`GET /archives/` et `/archives/search`). Données synthétiques
    /// riches : statut, durée, filament, coût/énergie, vignettes, favoris.
    static let archives = """
    [
      {
        "id": 1, "printer_id": 1, "print_name": "Support Bracket — v3",
        "filename": "support_bracket_v3.gcode", "status": "completed",
        "started_at": "2026-06-05T16:03:00Z", "completed_at": "2026-06-05T18:25:00Z",
        "created_at": "2026-06-05T18:25:00Z", "print_time_seconds": 8520,
        "actual_time_seconds": 8490, "total_layers": 251, "filament_used_grams": 42.5,
        "filament_type": "PLA", "filament_color": "F4A300", "cost": 1.28, "energy_kwh": 0.34,
        "is_favorite": true, "designer": "Atelier", "run_count": 7, "object_count": 4,
        "thumbnail_path": "archive/1/thumb.png", "timelapse_path": "archive/1/timelapse.mp4",
        "tags": "fonctionnel,atelier"
      },
      {
        "id": 2, "printer_id": 1, "print_name": "Boîtier capteur",
        "filename": "boitier_capteur.3mf", "status": "completed",
        "started_at": "2026-06-04T09:40:00Z", "completed_at": "2026-06-04T13:28:00Z",
        "created_at": "2026-06-04T13:28:00Z", "print_time_seconds": 13680,
        "actual_time_seconds": 13710, "total_layers": 412, "filament_used_grams": 78.0,
        "filament_type": "PETG", "filament_color": "0F7BC4", "cost": 2.41, "energy_kwh": 0.58,
        "is_favorite": false, "designer": "Atelier", "run_count": 3, "object_count": 2,
        "thumbnail_path": "archive/2/thumb.png",
        "tags": "électronique"
      },
      {
        "id": 3, "printer_id": 2, "print_name": "Crochet mural ×4",
        "filename": "crochet_mural.3mf", "status": "completed",
        "started_at": "2026-06-06T05:40:00Z", "completed_at": "2026-06-06T07:14:00Z",
        "created_at": "2026-06-06T07:14:00Z", "print_time_seconds": 5400,
        "actual_time_seconds": 5380, "total_layers": 96, "filament_used_grams": 28.3,
        "filament_type": "PLA", "filament_color": "1A1A1A", "cost": 0.85, "energy_kwh": 0.21,
        "is_favorite": true, "designer": "Atelier", "run_count": 12, "object_count": 4,
        "thumbnail_path": "archive/3/thumb.png",
        "tags": "maison,rangement"
      },
      {
        "id": 4, "printer_id": 1, "print_name": "Engrenage 32 dents",
        "filename": "engrenage_32.3mf", "status": "completed",
        "started_at": "2026-06-03T11:20:00Z", "completed_at": "2026-06-03T12:31:00Z",
        "created_at": "2026-06-03T12:31:00Z", "print_time_seconds": 4260,
        "actual_time_seconds": 4240, "total_layers": 84, "filament_used_grams": 19.8,
        "filament_type": "PLA", "filament_color": "2A9D8F", "cost": 0.59, "energy_kwh": 0.16,
        "is_favorite": false, "designer": "Atelier", "run_count": 5, "object_count": 1,
        "thumbnail_path": "archive/4/thumb.png",
        "tags": "mécanique"
      },
      {
        "id": 5, "printer_id": 2, "print_name": "Porte-câble",
        "filename": "porte_cable.3mf", "status": "completed",
        "started_at": "2026-06-02T20:05:00Z", "completed_at": "2026-06-02T20:52:00Z",
        "created_at": "2026-06-02T20:52:00Z", "print_time_seconds": 2820,
        "actual_time_seconds": 2810, "total_layers": 52, "filament_used_grams": 11.2,
        "filament_type": "PLA", "filament_color": "E63946", "cost": 0.34, "energy_kwh": 0.10,
        "is_favorite": false, "designer": "Atelier", "run_count": 9, "object_count": 6,
        "thumbnail_path": "archive/5/thumb.png",
        "tags": "bureau"
      }
    ]
    """

    /// Détail d'une archive (`GET /archives/{id}`) — premier élément de la liste.
    static let archiveDetail = """
    {
      "id": 1, "printer_id": 1, "print_name": "Support Bracket — v3",
      "filename": "support_bracket_v3.gcode", "status": "completed",
      "started_at": "2026-06-05T16:03:00Z", "completed_at": "2026-06-05T18:25:00Z",
      "created_at": "2026-06-05T18:25:00Z", "print_time_seconds": 8520,
      "actual_time_seconds": 8490, "total_layers": 251, "filament_used_grams": 42.5,
      "filament_type": "PLA", "filament_color": "F4A300", "cost": 1.28, "energy_kwh": 0.34,
      "is_favorite": true, "designer": "Atelier", "run_count": 7, "object_count": 4,
      "thumbnail_path": "archive/1/thumb.png", "timelapse_path": "archive/1/timelapse.mp4",
      "tags": "fonctionnel,atelier", "notes": "Réimpression série atelier."
    }
    """
}
