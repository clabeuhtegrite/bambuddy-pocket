// SPDX-License-Identifier: AGPL-3.0-or-later
#if DEBUG

    import Foundation

    extension DemoFixtures {
        /// Statut riche d'une imprimante **en cours d'impression** (47 %, buse/plateau chauds, deux
        /// unités AMS pleines, aucune erreur HMS). Structure calquée sur une réponse `/status` réelle
        /// pour garantir le décodage. Toutes les valeurs sont synthétiques (aucune donnée réelle).
        static let printerStatus = """
        {
          "id": 1,
          "name": "Atelier — X1 Carbon",
          "connected": true,
          "state": "RUNNING",
          "current_print": "support_bracket.3mf",
          "subtask_name": "Support Bracket — v3",
          "gcode_file": "/data/Metadata/plate_1.gcode",
          "progress": 47.0,
          "remaining_time": 78,
          "layer_num": 118,
          "total_layers": 251,
          "temperatures": {
            "bed": 60.0, "bed_target": 60.0,
            "nozzle": 220.0, "nozzle_target": 220.0, "nozzle_heating": false,
            "chamber": 38.0, "chamber_target": 0.0, "chamber_heating": false,
            "bed_heating": false
          },
          "cover_url": null,
          "hms_errors": [],
          "ams": [
            {
              "id": 0, "humidity": 18, "temp": 28.4, "is_ams_ht": false,
              "tray": [
                {
                  "id": 0, "tray_color": "F4A300FF", "tray_type": "PLA",
                  "tray_sub_brands": "PLA Matte", "tray_id_name": "A00-Y", "tray_info_idx": "GFA00",
                  "remain": 82, "k": null, "cali_idx": -1, "tag_uid": "ANON000000000000",
                  "tray_uuid": "ANON0000000000000000000000000000",
                  "nozzle_temp_min": 190, "nozzle_temp_max": 230,
                  "drying_temp": 55, "drying_time": 8, "state": 11
                },
                {
                  "id": 1, "tray_color": "1A1A1AFF", "tray_type": "PLA",
                  "tray_sub_brands": "PLA Basic", "tray_id_name": "A00-K", "tray_info_idx": "GFA00",
                  "remain": 64, "k": null, "cali_idx": -1, "tag_uid": "ANON000000000000",
                  "tray_uuid": "ANON0000000000000000000000000000",
                  "nozzle_temp_min": 190, "nozzle_temp_max": 230,
                  "drying_temp": 55, "drying_time": 8, "state": 11
                },
                {
                  "id": 2, "tray_color": "0F7BC4FF", "tray_type": "PETG",
                  "tray_sub_brands": "PETG HF", "tray_id_name": "G02-B", "tray_info_idx": "GFG02",
                  "remain": 45, "k": null, "cali_idx": -1, "tag_uid": "ANON000000000000",
                  "tray_uuid": "ANON0000000000000000000000000000",
                  "nozzle_temp_min": 230, "nozzle_temp_max": 260,
                  "drying_temp": 65, "drying_time": 8, "state": 11
                },
                {
                  "id": 3, "tray_color": "E63946FF", "tray_type": "PLA",
                  "tray_sub_brands": "PLA Basic", "tray_id_name": "A00-R", "tray_info_idx": "GFA00",
                  "remain": 91, "k": null, "cali_idx": -1, "tag_uid": "ANON000000000000",
                  "tray_uuid": "ANON0000000000000000000000000000",
                  "nozzle_temp_min": 190, "nozzle_temp_max": 230,
                  "drying_temp": 55, "drying_time": 8, "state": 11
                }
              ],
              "serial_number": "ANONAMS0", "sw_ver": "04.01.21.95",
              "dry_time": 0, "dry_status": 0, "dry_sub_status": 0,
              "dry_sf_reason": [], "module_type": "n3f"
            },
            {
              "id": 1, "humidity": 22, "temp": 27.1, "is_ams_ht": false,
              "tray": [
                {
                  "id": 0, "tray_color": "FFFFFFFF", "tray_type": "PLA",
                  "tray_sub_brands": "PLA Basic", "tray_id_name": "A00-W", "tray_info_idx": "GFA00",
                  "remain": 73, "k": null, "cali_idx": -1, "tag_uid": "ANON000000000000",
                  "tray_uuid": "ANON0000000000000000000000000000",
                  "nozzle_temp_min": 190, "nozzle_temp_max": 230,
                  "drying_temp": 55, "drying_time": 8, "state": 11
                },
                {
                  "id": 1, "tray_color": "2A9D8FFF", "tray_type": "PETG",
                  "tray_sub_brands": "PETG Basic", "tray_id_name": "G01-G", "tray_info_idx": "GFG01",
                  "remain": 58, "k": null, "cali_idx": -1, "tag_uid": "ANON000000000000",
                  "tray_uuid": "ANON0000000000000000000000000000",
                  "nozzle_temp_min": 230, "nozzle_temp_max": 260,
                  "drying_temp": 65, "drying_time": 8, "state": 11
                },
                {
                  "id": 2, "tray_color": null, "tray_type": null, "tray_sub_brands": null,
                  "tray_id_name": null, "tray_info_idx": null, "remain": 0, "k": null,
                  "cali_idx": null, "tag_uid": null, "tray_uuid": null,
                  "nozzle_temp_min": null, "nozzle_temp_max": null,
                  "drying_temp": null, "drying_time": null, "state": 9
                },
                {
                  "id": 3, "tray_color": "6A4C93FF", "tray_type": "PLA",
                  "tray_sub_brands": "PLA Silk", "tray_id_name": "A01-P", "tray_info_idx": "GFA01",
                  "remain": 39, "k": null, "cali_idx": -1, "tag_uid": "ANON000000000000",
                  "tray_uuid": "ANON0000000000000000000000000000",
                  "nozzle_temp_min": 190, "nozzle_temp_max": 230,
                  "drying_temp": 55, "drying_time": 8, "state": 11
                }
              ],
              "serial_number": "ANONAMS1", "sw_ver": "04.01.21.95",
              "dry_time": 0, "dry_status": 0, "dry_sub_status": 0,
              "dry_sf_reason": [], "module_type": "n3f"
            }
          ],
          "ams_exists": true,
          "vt_tray": [],
          "sdcard": true, "store_to_sdcard": true, "timelapse": true, "ipcam": true,
          "wifi_signal": -42, "wired_network": false, "door_open": false,
          "nozzles": [{ "nozzle_type": "HS01", "nozzle_diameter": "0.4" }],
          "nozzle_rack": [],
          "print_options": {
            "spaghetti_detector": true, "print_halt": true, "halt_print_sensitivity": "medium",
            "first_layer_inspector": true, "printing_monitor": true,
            "buildplate_marker_detector": true, "allow_skip_parts": true,
            "nozzle_clumping_detector": true, "nozzle_clumping_sensitivity": "medium",
            "pileup_detector": true, "pileup_sensitivity": "medium",
            "airprint_detector": true, "airprint_sensitivity": "medium",
            "auto_recovery_step_loss": true, "filament_tangle_detect": true
          },
          "stg_cur": -1, "stg_cur_name": null, "stg": [],
          "airduct_mode": 0, "speed_level": 2, "chamber_light": true,
          "active_extruder": 0, "ams_mapping": [], "ams_extruder_map": {},
          "tray_now": 0, "ams_status_main": 0, "ams_status_sub": 0,
          "mc_print_sub_stage": 0, "printable_objects_count": 4,
          "cooling_fan_speed": 80, "big_fan1_speed": 100, "big_fan2_speed": 60,
          "heatbreak_fan_speed": 100, "firmware_version": "01.08.00.00",
          "developer_mode": false, "awaiting_plate_clear": false,
          "supports_drying": true, "current_archive_id": null, "current_plate_id": 1
        }
        """

        /// Statut d'une imprimante **au repos** (prête), une seule unité AMS. Sert à différencier la
        /// seconde imprimante de démo.
        static let printerStatusIdle = """
        {
          "id": 2, "name": "Bureau — A1 mini", "connected": true, "state": "IDLE",
          "current_print": null, "subtask_name": null, "gcode_file": null,
          "progress": 0.0, "remaining_time": 0, "layer_num": 0, "total_layers": 0,
          "temperatures": {
            "bed": 24.0, "bed_target": 0.0,
            "nozzle": 26.0, "nozzle_target": 0.0, "nozzle_heating": false,
            "chamber": 24.0, "chamber_target": 0.0, "chamber_heating": false, "bed_heating": false
          },
          "cover_url": null, "hms_errors": [],
          "ams": [
            {
              "id": 0, "humidity": 20, "temp": 25.0, "is_ams_ht": false,
              "tray": [
                {
                  "id": 0, "tray_color": "2A9D8FFF", "tray_type": "PLA",
                  "tray_sub_brands": "PLA Basic", "tray_id_name": "A00-G", "tray_info_idx": "GFA00",
                  "remain": 88, "k": null, "cali_idx": -1, "tag_uid": "ANON000000000000",
                  "tray_uuid": "ANON0000000000000000000000000000",
                  "nozzle_temp_min": 190, "nozzle_temp_max": 230,
                  "drying_temp": 55, "drying_time": 8, "state": 11
                },
                {
                  "id": 1, "tray_color": "F4A300FF", "tray_type": "PLA",
                  "tray_sub_brands": "PLA Matte", "tray_id_name": "A00-Y", "tray_info_idx": "GFA00",
                  "remain": 51, "k": null, "cali_idx": -1, "tag_uid": "ANON000000000000",
                  "tray_uuid": "ANON0000000000000000000000000000",
                  "nozzle_temp_min": 190, "nozzle_temp_max": 230,
                  "drying_temp": 55, "drying_time": 8, "state": 11
                },
                {
                  "id": 2, "tray_color": null, "tray_type": null, "tray_sub_brands": null,
                  "tray_id_name": null, "tray_info_idx": null, "remain": 0, "k": null,
                  "cali_idx": null, "tag_uid": null, "tray_uuid": null,
                  "nozzle_temp_min": null, "nozzle_temp_max": null,
                  "drying_temp": null, "drying_time": null, "state": 9
                },
                {
                  "id": 3, "tray_color": null, "tray_type": null, "tray_sub_brands": null,
                  "tray_id_name": null, "tray_info_idx": null, "remain": 0, "k": null,
                  "cali_idx": null, "tag_uid": null, "tray_uuid": null,
                  "nozzle_temp_min": null, "nozzle_temp_max": null,
                  "drying_temp": null, "drying_time": null, "state": 9
                }
              ],
              "serial_number": "ANONAMS2", "sw_ver": "04.01.21.95",
              "dry_time": 0, "dry_status": 0, "dry_sub_status": 0,
              "dry_sf_reason": [], "module_type": "n3f"
            }
          ],
          "ams_exists": true, "vt_tray": [],
          "sdcard": true, "store_to_sdcard": true, "timelapse": false, "ipcam": true,
          "wifi_signal": -50, "wired_network": false, "door_open": false,
          "nozzles": [{ "nozzle_type": "HS01", "nozzle_diameter": "0.4" }], "nozzle_rack": [],
          "stg_cur": -1, "stg_cur_name": null, "stg": [],
          "airduct_mode": 0, "speed_level": 2, "chamber_light": false,
          "active_extruder": 0, "ams_mapping": [], "ams_extruder_map": {},
          "tray_now": 0, "ams_status_main": 0, "ams_status_sub": 0,
          "mc_print_sub_stage": 0, "printable_objects_count": 0,
          "cooling_fan_speed": 0, "big_fan1_speed": 0, "big_fan2_speed": 0,
          "heatbreak_fan_speed": 0, "firmware_version": "01.08.00.00",
          "developer_mode": false, "awaiting_plate_clear": false,
          "supports_drying": true, "current_archive_id": null, "current_plate_id": null
        }
        """
    }
#endif
