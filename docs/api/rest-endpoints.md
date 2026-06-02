# Bambuddy REST endpoints (auto-extracted from /openapi.json)

Title: Bambuddy v0.2.4.4 — 621 operations, 346 schemas

## (untagged) (8)

- `GET /` — Serve Frontend
- `GET /gcode-viewer/` — Serve Gcode Viewer Index
- `GET /gcode-viewer/{file_path}` — Serve Gcode Viewer File
- `GET /health` — Health Check
- `GET /manifest.json` — Serve Manifest
- `GET /sw-register.js` — Serve Sw Register
- `GET /sw.js` — Serve Service Worker
- `GET /{full_path}` — Serve Spa

## 2fa (24)

- `DELETE /api/v1/auth/2fa/admin/{user_id}` — Admin Disable 2Fa  _[req:AdminDisable2FARequest, resp:object]_
- `POST /api/v1/auth/2fa/email/disable` — Disable Email Otp  _[req:EmailOTPDisableRequest, resp:object]_
- `POST /api/v1/auth/2fa/email/enable` — Enable Email Otp  _[resp:object]_
- `POST /api/v1/auth/2fa/email/enable/confirm` — Confirm Enable Email Otp  _[req:EmailOTPEnableConfirmRequest, resp:object]_
- `POST /api/v1/auth/2fa/email/send` — Send Email Otp  _[req:EmailOTPSendRequest, resp:object]_
- `GET /api/v1/auth/2fa/status` — Get 2Fa Status  _[resp:TwoFAStatusResponse]_
- `POST /api/v1/auth/2fa/totp/disable` — Disable Totp  _[req:TOTPDisableRequest, resp:object]_
- `POST /api/v1/auth/2fa/totp/enable` — Enable Totp  _[req:TOTPEnableRequest, resp:TOTPEnableResponse]_
- `POST /api/v1/auth/2fa/totp/regenerate-backup-codes` — Regenerate Backup Codes  _[req:TOTPDisableRequest, resp:BackupCodesResponse]_
- `POST /api/v1/auth/2fa/totp/setup` — Setup Totp  _[req:TOTPSetupRequest, resp:TOTPSetupResponse]_
- `POST /api/v1/auth/2fa/verify` — Verify 2Fa  _[req:TwoFAVerifyRequest, resp:TwoFAVerifyResponse]_
- `GET /api/v1/auth/oidc/authorize/{provider_id}` — Oidc Authorize  _[resp:OIDCAuthorizeResponse]_
- `GET /api/v1/auth/oidc/callback` — Oidc Callback
- `POST /api/v1/auth/oidc/exchange` — Oidc Exchange  _[req:OIDCExchangeRequest, resp:LoginResponse]_
- `GET /api/v1/auth/oidc/links` — List Oidc Links  _[resp:OIDCLinkResponse[]]_
- `DELETE /api/v1/auth/oidc/links/{provider_id}` — Remove Oidc Link  _[resp:object]_
- `GET /api/v1/auth/oidc/providers` — List Oidc Providers  _[resp:OIDCProviderResponse[]]_
- `POST /api/v1/auth/oidc/providers` — Create Oidc Provider  _[req:OIDCProviderCreate, resp:OIDCProviderResponse]_
- `GET /api/v1/auth/oidc/providers/all` — List All Oidc Providers  _[resp:OIDCProviderResponse[]]_
- `PUT /api/v1/auth/oidc/providers/{provider_id}` — Update Oidc Provider  _[req:OIDCProviderUpdate, resp:OIDCProviderResponse]_
- `DELETE /api/v1/auth/oidc/providers/{provider_id}` — Delete Oidc Provider  _[resp:object]_
- `GET /api/v1/auth/oidc/providers/{provider_id}/icon` — Get Oidc Provider Icon
- `DELETE /api/v1/auth/oidc/providers/{provider_id}/icon` — Delete Oidc Provider Icon
- `POST /api/v1/auth/oidc/providers/{provider_id}/icon/refresh` — Refresh Oidc Provider Icon  _[resp:OIDCProviderResponse]_

## Local Presets (9)

- `GET /api/v1/local-presets/` — List Local Presets  _[resp:LocalPresetsResponse]_
- `POST /api/v1/local-presets/` — Create Local Preset  _[req:LocalPresetCreate, resp:LocalPresetResponse]_
- `POST /api/v1/local-presets/base-cache/refresh` — Refresh Cache
- `GET /api/v1/local-presets/base-cache/status` — Base Cache Status
- `POST /api/v1/local-presets/import` — Import Presets  _[resp:ImportResponse]_
- `POST /api/v1/local-presets/reclassify` — Reclassify
- `GET /api/v1/local-presets/{preset_id}` — Get Local Preset  _[resp:LocalPresetDetail]_
- `PUT /api/v1/local-presets/{preset_id}` — Update Local Preset  _[req:LocalPresetUpdate, resp:LocalPresetResponse]_
- `DELETE /api/v1/local-presets/{preset_id}` — Delete Local Preset

## Slicer Presets (7)

- `POST /api/v1/slicer/bundles` — Import Slicer Bundle
- `GET /api/v1/slicer/bundles` — List Slicer Bundles
- `GET /api/v1/slicer/bundles/{bundle_id}` — Get Slicer Bundle
- `DELETE /api/v1/slicer/bundles/{bundle_id}` — Delete Slicer Bundle
- `GET /api/v1/slicer/presets` — List Unified Presets  _[resp:UnifiedPresetsResponse]_
- `GET /api/v1/slicer/preview-progress/{request_id}` — Get Preview Slice Progress
- `GET /api/v1/slicer/printer-models` — List Printer Models  _[resp:object]_

## ams-history (2)

- `DELETE /api/v1/ams-history/{printer_id}` — Delete Old History
- `GET /api/v1/ams-history/{printer_id}/{ams_id}` — Get Ams History  _[resp:AMSHistoryResponse]_

## api-keys (5)

- `GET /api/v1/api-keys/` — List Api Keys  _[resp:APIKeyResponse[]]_
- `POST /api/v1/api-keys/` — Create Api Key  _[req:APIKeyCreate, resp:APIKeyCreateResponse]_
- `GET /api/v1/api-keys/{key_id}` — Get Api Key  _[resp:APIKeyResponse]_
- `PATCH /api/v1/api-keys/{key_id}` — Update Api Key  _[req:APIKeyUpdate, resp:APIKeyResponse]_
- `DELETE /api/v1/api-keys/{key_id}` — Delete Api Key

## archives (63)

- `GET /api/v1/archives/` — List Archives  _[resp:ArchiveResponse[]]_
- `GET /api/v1/archives/analysis/failures` — Analyze Failures
- `POST /api/v1/archives/backfill-hashes` — Backfill Content Hashes
- `GET /api/v1/archives/compare` — Compare Archives
- `GET /api/v1/archives/export` — Export Archives
- `POST /api/v1/archives/recalculate-costs` — Recalculate All Costs
- `POST /api/v1/archives/rescan-all` — Rescan All Archives
- `GET /api/v1/archives/search` — Search Archives  _[resp:ArchiveResponse[]]_
- `POST /api/v1/archives/search/rebuild-index` — Rebuild Search Index
- `GET /api/v1/archives/slim` — List Archives Slim  _[resp:ArchiveSlim[]]_
- `GET /api/v1/archives/stats` — Get Archive Stats  _[resp:ArchiveStats]_
- `GET /api/v1/archives/stats/export` — Export Stats
- `GET /api/v1/archives/tags` — Get All Tags
- `PUT /api/v1/archives/tags/{tag_name}` — Rename Tag
- `DELETE /api/v1/archives/tags/{tag_name}` — Delete Tag
- `POST /api/v1/archives/upload` — Upload Archive
- `POST /api/v1/archives/upload-bulk` — Upload Archives Bulk
- `POST /api/v1/archives/upload-source` — Upload Source 3Mf By Name
- `GET /api/v1/archives/{archive_id}` — Get Archive  _[resp:ArchiveResponse]_
- `PATCH /api/v1/archives/{archive_id}` — Update Archive  _[req:ArchiveUpdate, resp:ArchiveResponse]_
- `DELETE /api/v1/archives/{archive_id}` — Delete Archive
- `GET /api/v1/archives/{archive_id}/capabilities` — Get Archive Capabilities
- `GET /api/v1/archives/{archive_id}/dl/{token}/{filename}` — Download Archive For Slicer
- `GET /api/v1/archives/{archive_id}/download` — Download Archive
- `GET /api/v1/archives/{archive_id}/duplicates` — Get Archive Duplicates
- `POST /api/v1/archives/{archive_id}/f3d` — Upload F3D
- `GET /api/v1/archives/{archive_id}/f3d` — Download F3D
- `DELETE /api/v1/archives/{archive_id}/f3d` — Delete F3D
- `POST /api/v1/archives/{archive_id}/favorite` — Toggle Favorite  _[resp:ArchiveResponse]_
- `GET /api/v1/archives/{archive_id}/filament-requirements` — Get Filament Requirements
- `GET /api/v1/archives/{archive_id}/file/{filename}` — Download Archive With Filename
- `GET /api/v1/archives/{archive_id}/gcode` — Get Gcode
- `POST /api/v1/archives/{archive_id}/photos` — Upload Photo
- `GET /api/v1/archives/{archive_id}/photos/{filename}` — Get Photo
- `DELETE /api/v1/archives/{archive_id}/photos/{filename}` — Delete Photo
- `GET /api/v1/archives/{archive_id}/plate-preview` — Get Plate Preview
- `GET /api/v1/archives/{archive_id}/plate-thumbnail/{plate_index}` — Get Plate Thumbnail
- `GET /api/v1/archives/{archive_id}/plates` — Get Archive Plates
- `GET /api/v1/archives/{archive_id}/project-image/{image_path}` — Get Project Image
- `GET /api/v1/archives/{archive_id}/project-page` — Get Project Page
- `PATCH /api/v1/archives/{archive_id}/project-page` — Update Project Page  _[req:object]_
- `GET /api/v1/archives/{archive_id}/qrcode` — Get Qrcode
- `POST /api/v1/archives/{archive_id}/reprint` — Reprint Archive  _[req:ReprintRequest]_
- `POST /api/v1/archives/{archive_id}/rescan` — Rescan Archive  _[resp:ArchiveResponse]_
- `GET /api/v1/archives/{archive_id}/runs` — List Archive Runs  _[resp:PrintLogResponse]_
- `GET /api/v1/archives/{archive_id}/similar` — Find Similar Archives
- `POST /api/v1/archives/{archive_id}/slice` — Slice Archive  _[req:SliceRequest]_
- `POST /api/v1/archives/{archive_id}/slicer-token` — Create Archive Slicer Token
- `POST /api/v1/archives/{archive_id}/source` — Upload Source 3Mf
- `GET /api/v1/archives/{archive_id}/source` — Download Source 3Mf
- `DELETE /api/v1/archives/{archive_id}/source` — Delete Source 3Mf
- `GET /api/v1/archives/{archive_id}/source-dl/{token}/{filename}` — Download Source 3Mf For Slicer With Token
- `POST /api/v1/archives/{archive_id}/source-slicer-token` — Create Source Slicer Token
- `GET /api/v1/archives/{archive_id}/source/{filename}` — Download Source 3Mf For Slicer
- `GET /api/v1/archives/{archive_id}/thumbnail` — Get Thumbnail
- `GET /api/v1/archives/{archive_id}/timelapse` — Get Timelapse
- `DELETE /api/v1/archives/{archive_id}/timelapse` — Delete Timelapse
- `GET /api/v1/archives/{archive_id}/timelapse/info` — Get Timelapse Info
- `POST /api/v1/archives/{archive_id}/timelapse/process` — Process Timelapse
- `POST /api/v1/archives/{archive_id}/timelapse/scan` — Scan Timelapse
- `POST /api/v1/archives/{archive_id}/timelapse/select` — Select Timelapse
- `GET /api/v1/archives/{archive_id}/timelapse/thumbnails` — Get Timelapse Thumbnails
- `POST /api/v1/archives/{archive_id}/timelapse/upload` — Upload Timelapse

## archives-purge (4)

- `POST /api/v1/archives/purge` — Execute Archive Purge  _[req:ArchivePurgeRequest, resp:ArchivePurgeResponse]_
- `GET /api/v1/archives/purge/preview` — Preview Archive Purge  _[resp:ArchivePurgePreviewResponse]_
- `GET /api/v1/archives/purge/settings` — Get Archive Purge Settings  _[resp:ArchivePurgeSettings]_
- `PUT /api/v1/archives/purge/settings` — Update Archive Purge Settings  _[req:ArchivePurgeSettings, resp:ArchivePurgeSettings]_

## authentication (24)

- `POST /api/v1/auth/advanced-auth/disable` — Disable Advanced Auth  _[resp:object]_
- `POST /api/v1/auth/advanced-auth/enable` — Enable Advanced Auth  _[resp:object]_
- `GET /api/v1/auth/advanced-auth/status` — Get Advanced Auth Status
- `POST /api/v1/auth/disable` — Disable Auth  _[resp:object]_
- `GET /api/v1/auth/encryption-status` — Get Encryption Status  _[resp:EncryptionStatusResponse]_
- `POST /api/v1/auth/forgot-password` — Forgot Password  _[req:ForgotPasswordRequest, resp:ForgotPasswordResponse]_
- `POST /api/v1/auth/forgot-password/confirm` — Forgot Password Confirm  _[req:ForgotPasswordConfirmRequest, resp:ForgotPasswordResponse]_
- `POST /api/v1/auth/ldap/provision` — Provision Ldap User  _[req:LDAPProvisionRequest, resp:UserResponse]_
- `GET /api/v1/auth/ldap/search` — Search Ldap Directory  _[resp:LDAPSearchResultResponse[]]_
- `GET /api/v1/auth/ldap/status` — Get Ldap Status
- `POST /api/v1/auth/ldap/test` — Test Ldap
- `POST /api/v1/auth/login` — Login  _[req:LoginRequest, resp:LoginResponse]_
- `POST /api/v1/auth/logout` — Logout
- `GET /api/v1/auth/me` — Get Current User Info  _[resp:UserResponse]_
- `POST /api/v1/auth/reset-password` — Reset User Password  _[req:ResetPasswordRequest, resp:ResetPasswordResponse]_
- `POST /api/v1/auth/setup` — Setup Auth  _[req:SetupRequest, resp:SetupResponse]_
- `GET /api/v1/auth/smtp` — Get Smtp Config  _[resp:SMTPSettings]_
- `POST /api/v1/auth/smtp` — Save Smtp Config  _[req:SMTPSettings, resp:object]_
- `POST /api/v1/auth/smtp/test` — Test Smtp Connection  _[req:TestSMTPRequest, resp:TestSMTPResponse]_
- `GET /api/v1/auth/status` — Get Auth Status
- `POST /api/v1/auth/tokens` — Create Long Lived Camera Token  _[req:object, resp:object]_
- `GET /api/v1/auth/tokens` — List Long Lived Tokens  _[resp:object[]]_
- `GET /api/v1/auth/tokens/all` — List All Long Lived Tokens  _[resp:object[]]_
- `DELETE /api/v1/auth/tokens/{token_id}` — Revoke Long Lived Token

## background-dispatch (1)

- `DELETE /api/v1/background-dispatch/{job_id}` — Cancel Dispatch Job

## bug-report (3)

- `POST /api/v1/bug-report/start-logging` — Start Logging  _[resp:StartLoggingResponse]_
- `POST /api/v1/bug-report/stop-logging` — Stop Logging  _[resp:StopLoggingResponse]_
- `POST /api/v1/bug-report/submit` — Submit Bug Report  _[req:BugReportRequest, resp:BugReportResponse]_

## camera (17)

- `POST /api/v1/printers/camera/stream-token` — Create Stream Token
- `GET /api/v1/printers/{printer_id}/camera/check-plate` — Check Plate Empty
- `POST /api/v1/printers/{printer_id}/camera/diagnose` — Diagnose Camera Route
- `POST /api/v1/printers/{printer_id}/camera/external/test` — Test External Camera
- `POST /api/v1/printers/{printer_id}/camera/plate-detection/calibrate` — Calibrate Plate Detection
- `DELETE /api/v1/printers/{printer_id}/camera/plate-detection/calibrate` — Delete Plate Calibration
- `GET /api/v1/printers/{printer_id}/camera/plate-detection/references` — Get Plate References
- `PUT /api/v1/printers/{printer_id}/camera/plate-detection/references/{index}` — Update Reference Label
- `DELETE /api/v1/printers/{printer_id}/camera/plate-detection/references/{index}` — Delete Reference
- `GET /api/v1/printers/{printer_id}/camera/plate-detection/references/{index}/thumbnail` — Get Reference Thumbnail
- `GET /api/v1/printers/{printer_id}/camera/plate-detection/status` — Get Plate Detection Status
- `GET /api/v1/printers/{printer_id}/camera/snapshot` — Camera Snapshot
- `GET /api/v1/printers/{printer_id}/camera/status` — Camera Status
- `POST /api/v1/printers/{printer_id}/camera/stop` — Stop Camera Stream
- `GET /api/v1/printers/{printer_id}/camera/stop` — Stop Camera Stream
- `GET /api/v1/printers/{printer_id}/camera/stream` — Camera Stream
- `GET /api/v1/printers/{printer_id}/camera/test` — Test Camera

## cloud (18)

- `GET /api/v1/cloud/builtin-filaments` — Get Builtin Filaments
- `GET /api/v1/cloud/devices` — Get Devices  _[resp:CloudDevice[]]_
- `GET /api/v1/cloud/fields` — Get All Preset Fields
- `GET /api/v1/cloud/fields/{preset_type}` — Get Preset Fields
- `GET /api/v1/cloud/filament-id-map` — Get Filament Id Map
- `POST /api/v1/cloud/filament-info` — Get Filament Info  _[req:string[]]_
- `GET /api/v1/cloud/filaments` — Get Filament Presets  _[resp:SlicerSetting[]]_
- `GET /api/v1/cloud/firmware-updates` — Get Firmware Updates  _[resp:backend__app__schemas__cloud__FirmwareUpdatesResponse]_
- `POST /api/v1/cloud/login` — Login  _[req:CloudLoginRequest, resp:CloudLoginResponse]_
- `POST /api/v1/cloud/logout` — Logout
- `GET /api/v1/cloud/settings` — Get Slicer Settings  _[resp:SlicerSettingsResponse]_
- `POST /api/v1/cloud/settings` — Create Setting  _[req:SlicerSettingCreate]_
- `GET /api/v1/cloud/settings/{setting_id}` — Get Setting Detail
- `PUT /api/v1/cloud/settings/{setting_id}` — Update Setting  _[req:SlicerSettingUpdate]_
- `DELETE /api/v1/cloud/settings/{setting_id}` — Delete Setting  _[resp:SlicerSettingDeleteResponse]_
- `GET /api/v1/cloud/status` — Get Auth Status  _[resp:CloudAuthStatus]_
- `POST /api/v1/cloud/token` — Set Token  _[req:CloudTokenRequest, resp:CloudAuthStatus]_
- `POST /api/v1/cloud/verify` — Verify Code  _[req:CloudVerifyRequest, resp:CloudLoginResponse]_

## discovery (8)

- `GET /api/v1/discovery/info` — Get Discovery Info  _[resp:DiscoveryInfo]_
- `GET /api/v1/discovery/printers` — Get Discovered Printers  _[resp:DiscoveredPrinterResponse[]]_
- `POST /api/v1/discovery/scan` — Start Subnet Scan  _[req:SubnetScanRequest, resp:SubnetScanStatus]_
- `GET /api/v1/discovery/scan/status` — Get Scan Status  _[resp:SubnetScanStatus]_
- `POST /api/v1/discovery/scan/stop` — Stop Subnet Scan  _[resp:SubnetScanStatus]_
- `POST /api/v1/discovery/start` — Start Discovery  _[resp:DiscoveryStatus]_
- `GET /api/v1/discovery/status` — Get Discovery Status  _[resp:DiscoveryStatus]_
- `POST /api/v1/discovery/stop` — Stop Discovery  _[resp:DiscoveryStatus]_

## external-links (9)

- `GET /api/v1/external-links/` — List External Links  _[resp:ExternalLinkResponse[]]_
- `POST /api/v1/external-links/` — Create External Link  _[req:ExternalLinkCreate, resp:ExternalLinkResponse]_
- `PUT /api/v1/external-links/reorder` — Reorder External Links  _[req:ExternalLinkReorder, resp:ExternalLinkResponse[]]_
- `GET /api/v1/external-links/{link_id}` — Get External Link  _[resp:ExternalLinkResponse]_
- `PATCH /api/v1/external-links/{link_id}` — Update External Link  _[req:ExternalLinkUpdate, resp:ExternalLinkResponse]_
- `DELETE /api/v1/external-links/{link_id}` — Delete External Link
- `POST /api/v1/external-links/{link_id}/icon` — Upload Icon  _[resp:ExternalLinkResponse]_
- `DELETE /api/v1/external-links/{link_id}/icon` — Delete Icon  _[resp:ExternalLinkResponse]_
- `GET /api/v1/external-links/{link_id}/icon` — Get Icon

## filament-catalog (8)

- `GET /api/v1/filament-catalog/` — List Filaments  _[resp:FilamentResponse[]]_
- `POST /api/v1/filament-catalog/` — Create Filament  _[req:FilamentCreate, resp:FilamentResponse]_
- `GET /api/v1/filament-catalog/by-type/{filament_type}` — Get Filaments By Type  _[resp:FilamentResponse[]]_
- `POST /api/v1/filament-catalog/calculate-cost` — Calculate Cost  _[resp:FilamentCostCalculation]_
- `POST /api/v1/filament-catalog/seed-defaults` — Seed Default Filaments
- `GET /api/v1/filament-catalog/{filament_id}` — Get Filament  _[resp:FilamentResponse]_
- `PATCH /api/v1/filament-catalog/{filament_id}` — Update Filament  _[req:FilamentUpdate, resp:FilamentResponse]_
- `DELETE /api/v1/filament-catalog/{filament_id}` — Delete Filament

## firmware (6)

- `GET /api/v1/firmware/latest` — Get All Latest Firmware  _[resp:LatestFirmwareInfo[]]_
- `GET /api/v1/firmware/updates` — Check Firmware Updates  _[resp:backend__app__api__routes__firmware__FirmwareUpdatesResponse]_
- `GET /api/v1/firmware/updates/{printer_id}` — Check Printer Firmware  _[resp:backend__app__api__routes__firmware__FirmwareUpdateInfo]_
- `GET /api/v1/firmware/updates/{printer_id}/prepare` — Prepare Firmware Upload  _[resp:FirmwareUploadPrepareResponse]_
- `POST /api/v1/firmware/updates/{printer_id}/upload` — Start Firmware Upload  _[resp:FirmwareUploadStartResponse]_
- `GET /api/v1/firmware/updates/{printer_id}/upload/status` — Get Firmware Upload Status  _[resp:FirmwareUploadStatusResponse]_

## github-backup (10)

- `GET /api/v1/github-backup/config` — Get Config  _[resp:GitHubBackupConfigResponse]_
- `POST /api/v1/github-backup/config` — Save Config  _[req:GitHubBackupConfigCreate, resp:GitHubBackupConfigResponse]_
- `PATCH /api/v1/github-backup/config` — Update Config  _[req:GitHubBackupConfigUpdate, resp:GitHubBackupConfigResponse]_
- `DELETE /api/v1/github-backup/config` — Delete Config
- `GET /api/v1/github-backup/logs` — Get Logs  _[resp:GitHubBackupLogResponse[]]_
- `DELETE /api/v1/github-backup/logs` — Clear Logs
- `POST /api/v1/github-backup/run` — Trigger Backup  _[resp:GitHubBackupTriggerResponse]_
- `GET /api/v1/github-backup/status` — Get Status  _[resp:GitHubBackupStatus]_
- `POST /api/v1/github-backup/test` — Test Connection  _[resp:GitHubTestConnectionResponse]_
- `POST /api/v1/github-backup/test-stored` — Test Stored Connection  _[resp:GitHubTestConnectionResponse]_

## groups (10)

- `GET /api/v1/groups` — List Groups  _[resp:GroupResponse[]]_
- `POST /api/v1/groups` — Create Group  _[req:GroupCreate, resp:GroupResponse]_
- `GET /api/v1/groups/` — List Groups  _[resp:GroupResponse[]]_
- `POST /api/v1/groups/` — Create Group  _[req:GroupCreate, resp:GroupResponse]_
- `GET /api/v1/groups/permissions` — List Permissions  _[resp:PermissionsListResponse]_
- `GET /api/v1/groups/{group_id}` — Get Group  _[resp:GroupDetailResponse]_
- `PATCH /api/v1/groups/{group_id}` — Update Group  _[req:GroupUpdate, resp:GroupResponse]_
- `DELETE /api/v1/groups/{group_id}` — Delete Group
- `POST /api/v1/groups/{group_id}/users/{user_id}` — Add User To Group
- `DELETE /api/v1/groups/{group_id}/users/{user_id}` — Remove User From Group

## inventory (43)

- `GET /api/v1/inventory/assignments` — List Assignments  _[resp:SpoolAssignmentResponse[]]_
- `POST /api/v1/inventory/assignments` — Assign Spool  _[req:SpoolAssignmentCreate, resp:SpoolAssignmentResponse]_
- `DELETE /api/v1/inventory/assignments/{printer_id}/{ams_id}/{tray_id}` — Unassign Spool
- `GET /api/v1/inventory/catalog` — Get Spool Catalog  _[resp:CatalogEntryResponse[]]_
- `POST /api/v1/inventory/catalog` — Add Catalog Entry  _[req:CatalogEntryCreate, resp:CatalogEntryResponse]_
- `POST /api/v1/inventory/catalog/bulk-delete` — Bulk Delete Catalog Entries  _[req:BulkDeleteIdsRequest]_
- `POST /api/v1/inventory/catalog/reset` — Reset Spool Catalog
- `PUT /api/v1/inventory/catalog/{entry_id}` — Update Catalog Entry  _[req:CatalogEntryUpdate, resp:CatalogEntryResponse]_
- `DELETE /api/v1/inventory/catalog/{entry_id}` — Delete Catalog Entry
- `GET /api/v1/inventory/colors` — Get Color Catalog  _[resp:ColorEntryResponse[]]_
- `POST /api/v1/inventory/colors` — Add Color Entry  _[req:ColorEntryCreate, resp:ColorEntryResponse]_
- `POST /api/v1/inventory/colors/bulk-delete` — Bulk Delete Color Entries  _[req:BulkDeleteIdsRequest]_
- `GET /api/v1/inventory/colors/lookup` — Lookup Color  _[resp:ColorLookupResult]_
- `GET /api/v1/inventory/colors/map` — Get Color Name Map
- `POST /api/v1/inventory/colors/reset` — Reset Color Catalog
- `GET /api/v1/inventory/colors/search` — Search Colors  _[resp:ColorEntryResponse[]]_
- `POST /api/v1/inventory/colors/sync` — Sync From Filamentcolors
- `PUT /api/v1/inventory/colors/{entry_id}` — Update Color Entry  _[req:ColorEntryUpdate, resp:ColorEntryResponse]_
- `DELETE /api/v1/inventory/colors/{entry_id}` — Delete Color Entry
- `GET /api/v1/inventory/shopping-list` — Get Shopping List  _[resp:ShoppingListItemResponse[]]_
- `POST /api/v1/inventory/shopping-list` — Add To Shopping List  _[req:ShoppingListItemCreate, resp:ShoppingListItemResponse]_
- `DELETE /api/v1/inventory/shopping-list` — Clear Shopping List
- `DELETE /api/v1/inventory/shopping-list/{item_id}` — Remove From Shopping List
- `PATCH /api/v1/inventory/shopping-list/{item_id}/status` — Update Shopping List Status  _[req:ShoppingListItemStatusUpdate, resp:ShoppingListItemResponse]_
- `GET /api/v1/inventory/sku-settings` — List Sku Settings  _[resp:FilamentSkuSettingsResponse[]]_
- `POST /api/v1/inventory/sku-settings` — Upsert Sku Settings  _[req:FilamentSkuSettingsUpsert, resp:FilamentSkuSettingsResponse]_
- `GET /api/v1/inventory/spools` — List Spools  _[resp:SpoolResponse[]]_
- `POST /api/v1/inventory/spools` — Create Spool  _[req:SpoolCreate, resp:SpoolResponse]_
- `POST /api/v1/inventory/spools/bulk` — Bulk Create Spools  _[req:SpoolBulkCreate, resp:SpoolResponse[]]_
- `POST /api/v1/inventory/spools/reset-usage-bulk` — Bulk Reset Spool Usage  _[req:object]_
- `GET /api/v1/inventory/spools/{spool_id}` — Get Spool  _[resp:SpoolResponse]_
- `PATCH /api/v1/inventory/spools/{spool_id}` — Update Spool  _[req:SpoolUpdate, resp:SpoolResponse]_
- `DELETE /api/v1/inventory/spools/{spool_id}` — Delete Spool
- `POST /api/v1/inventory/spools/{spool_id}/archive` — Archive Spool  _[resp:SpoolResponse]_
- `GET /api/v1/inventory/spools/{spool_id}/k-profiles` — List K Profiles  _[resp:SpoolKProfileResponse[]]_
- `PUT /api/v1/inventory/spools/{spool_id}/k-profiles` — Replace K Profiles  _[req:SpoolKProfileBase[], resp:SpoolKProfileResponse[]]_
- `PATCH /api/v1/inventory/spools/{spool_id}/link-tag` — Link Tag To Spool  _[req:LinkTagRequest, resp:SpoolResponse]_
- `POST /api/v1/inventory/spools/{spool_id}/reset-usage` — Reset Spool Usage  _[resp:SpoolResponse]_
- `POST /api/v1/inventory/spools/{spool_id}/restore` — Restore Spool  _[resp:SpoolResponse]_
- `GET /api/v1/inventory/spools/{spool_id}/usage` — Get Spool Usage History  _[resp:SpoolUsageHistoryResponse[]]_
- `DELETE /api/v1/inventory/spools/{spool_id}/usage` — Clear Spool Usage History
- `POST /api/v1/inventory/sync-ams-weights` — Sync Weights From Ams
- `GET /api/v1/inventory/usage` — Get All Usage History  _[resp:SpoolUsageHistoryResponse[]]_

## kprofiles (7)

- `GET /api/v1/printers/{printer_id}/kprofiles/` — Get Kprofiles  _[resp:KProfilesResponse]_
- `POST /api/v1/printers/{printer_id}/kprofiles/` — Set Kprofile  _[req:KProfileCreate, resp:object]_
- `DELETE /api/v1/printers/{printer_id}/kprofiles/` — Delete Kprofile  _[req:KProfileDelete, resp:object]_
- `POST /api/v1/printers/{printer_id}/kprofiles/batch` — Set Kprofiles Batch  _[req:KProfileCreate[], resp:object]_
- `GET /api/v1/printers/{printer_id}/kprofiles/notes` — Get Kprofile Notes  _[resp:KProfileNoteResponse]_
- `PUT /api/v1/printers/{printer_id}/kprofiles/notes` — Set Kprofile Note  _[req:KProfileNote, resp:object]_
- `DELETE /api/v1/printers/{printer_id}/kprofiles/notes/{setting_id}` — Delete Kprofile Note  _[resp:object]_

## labels (2)

- `POST /api/v1/inventory/labels` — Render Local Inventory Labels  _[req:LabelRequest]_
- `POST /api/v1/spoolman/labels` — Render Spoolman Labels  _[req:LabelRequest]_

## library (34)

- `POST /api/v1/library/bulk-delete` — Bulk Delete  _[req:BulkDeleteRequest, resp:BulkDeleteResponse]_
- `GET /api/v1/library/files` — List Files  _[resp:FileListResponse[]]_
- `POST /api/v1/library/files` — Upload File  _[resp:FileUploadResponse]_
- `GET /api/v1/library/files/` — List Files  _[resp:FileListResponse[]]_
- `POST /api/v1/library/files/` — Upload File  _[resp:FileUploadResponse]_
- `POST /api/v1/library/files/add-to-queue` — Add Files To Queue  _[req:AddToQueueRequest, resp:AddToQueueResponse]_
- `POST /api/v1/library/files/extract-zip` — Extract Zip File  _[resp:ZipExtractResponse]_
- `POST /api/v1/library/files/move` — Move Files  _[req:FileMoveRequest]_
- `GET /api/v1/library/files/{file_id}` — Get File  _[resp:FileResponse]_
- `PUT /api/v1/library/files/{file_id}` — Update File  _[req:FileUpdate, resp:FileResponse]_
- `DELETE /api/v1/library/files/{file_id}` — Delete File
- `GET /api/v1/library/files/{file_id}/dl/{token}/{filename}` — Download Library File For Slicer
- `GET /api/v1/library/files/{file_id}/download` — Download File
- `GET /api/v1/library/files/{file_id}/filament-requirements` — Get Library File Filament Requirements
- `GET /api/v1/library/files/{file_id}/gcode` — Get Gcode
- `GET /api/v1/library/files/{file_id}/plate-thumbnail/{plate_index}` — Get Library File Plate Thumbnail
- `GET /api/v1/library/files/{file_id}/plates` — Get Library File Plates
- `POST /api/v1/library/files/{file_id}/print` — Print Library File  _[req:FilePrintRequest]_
- `POST /api/v1/library/files/{file_id}/slice` — Slice Library File  _[req:SliceRequest]_
- `POST /api/v1/library/files/{file_id}/slicer-token` — Create Library Slicer Token
- `GET /api/v1/library/files/{file_id}/thumbnail` — Get Thumbnail
- `GET /api/v1/library/folders` — List Folders  _[resp:FolderTreeItem[]]_
- `POST /api/v1/library/folders` — Create Folder  _[req:FolderCreate, resp:FolderResponse]_
- `GET /api/v1/library/folders/` — List Folders  _[resp:FolderTreeItem[]]_
- `POST /api/v1/library/folders/` — Create Folder  _[req:FolderCreate, resp:FolderResponse]_
- `GET /api/v1/library/folders/by-archive/{archive_id}` — Get Folders By Archive  _[resp:FolderResponse[]]_
- `GET /api/v1/library/folders/by-project/{project_id}` — Get Folders By Project  _[resp:FolderResponse[]]_
- `POST /api/v1/library/folders/external` — Create External Folder  _[req:ExternalFolderCreate, resp:FolderResponse]_
- `GET /api/v1/library/folders/{folder_id}` — Get Folder  _[resp:FolderResponse]_
- `PUT /api/v1/library/folders/{folder_id}` — Update Folder  _[req:FolderUpdate, resp:FolderResponse]_
- `DELETE /api/v1/library/folders/{folder_id}` — Delete Folder
- `POST /api/v1/library/folders/{folder_id}/scan` — Scan External Folder
- `POST /api/v1/library/generate-stl-thumbnails` — Batch Generate Stl Thumbnails  _[req:BatchThumbnailRequest, resp:BatchThumbnailResponse]_
- `GET /api/v1/library/stats` — Get Library Stats

## library-trash (8)

- `POST /api/v1/library/purge` — Execute Purge  _[req:PurgeRequest, resp:PurgeResponse]_
- `GET /api/v1/library/purge/preview` — Preview Purge  _[resp:PurgePreviewResponse]_
- `GET /api/v1/library/trash` — List Trash  _[resp:TrashListResponse]_
- `DELETE /api/v1/library/trash` — Empty Trash  _[resp:EmptyTrashResponse]_
- `GET /api/v1/library/trash/settings` — Get Trash Settings  _[resp:TrashSettings]_
- `PUT /api/v1/library/trash/settings` — Update Trash Settings  _[req:TrashSettings, resp:TrashSettings]_
- `DELETE /api/v1/library/trash/{file_id}` — Hard Delete From Trash
- `POST /api/v1/library/trash/{file_id}/restore` — Restore From Trash

## local-backup (6)

- `GET /api/v1/local-backup/backups` — List Backups
- `DELETE /api/v1/local-backup/backups/{filename}` — Delete Backup
- `GET /api/v1/local-backup/backups/{filename}/download` — Download Backup
- `POST /api/v1/local-backup/backups/{filename}/restore` — Restore Backup
- `POST /api/v1/local-backup/run` — Trigger Backup
- `GET /api/v1/local-backup/status` — Get Status

## maintenance (14)

- `PATCH /api/v1/maintenance/items/{item_id}` — Update Printer Maintenance  _[req:PrinterMaintenanceUpdate, resp:PrinterMaintenanceResponse]_
- `DELETE /api/v1/maintenance/items/{item_id}` — Remove Maintenance Item
- `GET /api/v1/maintenance/items/{item_id}/history` — Get Maintenance History  _[resp:MaintenanceHistoryResponse[]]_
- `POST /api/v1/maintenance/items/{item_id}/perform` — Perform Maintenance  _[req:PerformMaintenanceRequest, resp:MaintenanceStatus]_
- `GET /api/v1/maintenance/overview` — Get All Maintenance Overview  _[resp:PrinterMaintenanceOverview[]]_
- `GET /api/v1/maintenance/printers/{printer_id}` — Get Printer Maintenance  _[resp:PrinterMaintenanceOverview]_
- `POST /api/v1/maintenance/printers/{printer_id}/assign/{type_id}` — Assign Maintenance Type  _[resp:PrinterMaintenanceResponse]_
- `PATCH /api/v1/maintenance/printers/{printer_id}/hours` — Set Printer Hours
- `GET /api/v1/maintenance/summary` — Get Maintenance Summary
- `GET /api/v1/maintenance/types` — Get Maintenance Types  _[resp:MaintenanceTypeResponse[]]_
- `POST /api/v1/maintenance/types` — Create Maintenance Type  _[req:MaintenanceTypeCreate, resp:MaintenanceTypeResponse]_
- `POST /api/v1/maintenance/types/restore-defaults` — Restore Default Maintenance Types
- `PATCH /api/v1/maintenance/types/{type_id}` — Update Maintenance Type  _[req:MaintenanceTypeUpdate, resp:MaintenanceTypeResponse]_
- `DELETE /api/v1/maintenance/types/{type_id}` — Delete Maintenance Type

## makerworld (5)

- `POST /api/v1/makerworld/import` — Import Instance  _[req:MakerWorldImportRequest, resp:MakerWorldImportResponse]_
- `GET /api/v1/makerworld/recent-imports` — Recent Imports  _[resp:MakerWorldRecentImport[]]_
- `POST /api/v1/makerworld/resolve` — Resolve Url  _[req:MakerWorldResolveRequest, resp:MakerWorldResolvedModel]_
- `GET /api/v1/makerworld/status` — Get Status  _[resp:MakerWorldStatus]_
- `GET /api/v1/makerworld/thumbnail` — Proxy Thumbnail

## metrics (1)

- `GET /api/v1/metrics` — Get Metrics

## notification-templates (7)

- `GET /api/v1/notification-templates` — Get Templates  _[resp:NotificationTemplateResponse[]]_
- `GET /api/v1/notification-templates/` — Get Templates  _[resp:NotificationTemplateResponse[]]_
- `POST /api/v1/notification-templates/preview` — Preview Template  _[req:TemplatePreviewRequest, resp:TemplatePreviewResponse]_
- `GET /api/v1/notification-templates/variables` — Get Variables  _[resp:EventVariablesResponse[]]_
- `GET /api/v1/notification-templates/{template_id}` — Get Template  _[resp:NotificationTemplateResponse]_
- `PUT /api/v1/notification-templates/{template_id}` — Update Template  _[req:NotificationTemplateUpdate, resp:NotificationTemplateResponse]_
- `POST /api/v1/notification-templates/{template_id}/reset` — Reset Template  _[resp:NotificationTemplateResponse]_

## notifications (11)

- `GET /api/v1/notifications/` — List Notification Providers  _[resp:NotificationProviderResponse[]]_
- `POST /api/v1/notifications/` — Create Notification Provider  _[req:NotificationProviderCreate, resp:NotificationProviderResponse]_
- `GET /api/v1/notifications/logs` — Get Notification Logs  _[resp:NotificationLogResponse[]]_
- `DELETE /api/v1/notifications/logs` — Clear Notification Logs
- `GET /api/v1/notifications/logs/stats` — Get Notification Log Stats  _[resp:NotificationLogStats]_
- `POST /api/v1/notifications/test-all` — Test All Notification Providers
- `POST /api/v1/notifications/test-config` — Test Notification Config  _[req:NotificationTestRequest, resp:NotificationTestResponse]_
- `GET /api/v1/notifications/{provider_id}` — Get Notification Provider  _[resp:NotificationProviderResponse]_
- `PATCH /api/v1/notifications/{provider_id}` — Update Notification Provider  _[req:NotificationProviderUpdate, resp:NotificationProviderResponse]_
- `DELETE /api/v1/notifications/{provider_id}` — Delete Notification Provider
- `POST /api/v1/notifications/{provider_id}/test` — Test Notification Provider  _[resp:NotificationTestResponse]_

## obico (3)

- `GET /api/v1/obico/cached-frame/{nonce}` — Cached Frame
- `GET /api/v1/obico/status` — Get Status
- `POST /api/v1/obico/test-connection` — Test Connection  _[req:TestConnectionRequest]_

## pending-uploads (7)

- `GET /api/v1/pending-uploads/` — List Pending Uploads  _[resp:PendingUploadResponse[]]_
- `POST /api/v1/pending-uploads/archive-all` — Archive All Pending
- `GET /api/v1/pending-uploads/count` — Get Pending Count
- `DELETE /api/v1/pending-uploads/discard-all` — Discard All Pending
- `GET /api/v1/pending-uploads/{upload_id}` — Get Pending Upload  _[resp:PendingUploadResponse]_
- `DELETE /api/v1/pending-uploads/{upload_id}` — Discard Pending Upload
- `POST /api/v1/pending-uploads/{upload_id}/archive` — Archive Pending Upload  _[req:ArchiveRequest]_

## print-log (3)

- `GET /api/v1/print-log/` — Get Print Log  _[resp:PrintLogResponse]_
- `DELETE /api/v1/print-log/` — Clear Print Log
- `GET /api/v1/print-log/{entry_id}/thumbnail` — Get Print Log Thumbnail

## printers (59)

- `GET /api/v1/printers/` — List Printers  _[resp:PrinterResponse[]]_
- `POST /api/v1/printers/` — Create Printer  _[req:PrinterCreate, resp:PrinterResponse]_
- `GET /api/v1/printers/available-filaments` — Get Available Filaments
- `GET /api/v1/printers/developer-mode-warnings` — Get Developer Mode Warnings
- `POST /api/v1/printers/diagnostic` — Diagnose Connection  _[req:DiagnosticRequest, resp:PrinterDiagnosticResult]_
- `POST /api/v1/printers/test` — Test Printer Connection
- `GET /api/v1/printers/usb-cameras` — List Usb Cameras
- `GET /api/v1/printers/{printer_id}` — Get Printer  _[resp:PrinterResponse]_
- `PATCH /api/v1/printers/{printer_id}` — Update Printer  _[req:PrinterUpdate, resp:PrinterResponse]_
- `DELETE /api/v1/printers/{printer_id}` — Delete Printer
- `POST /api/v1/printers/{printer_id}/airduct-mode` — Set Airduct Mode
- `GET /api/v1/printers/{printer_id}/ams-labels` — Get Ams Labels
- `PUT /api/v1/printers/{printer_id}/ams-labels/{ams_id}` — Save Ams Label  _[req:AmsLabelBody]_
- `DELETE /api/v1/printers/{printer_id}/ams-labels/{ams_id}` — Delete Ams Label
- `POST /api/v1/printers/{printer_id}/ams/load` — Ams Load
- `POST /api/v1/printers/{printer_id}/ams/unload` — Ams Unload
- `POST /api/v1/printers/{printer_id}/ams/{ams_id}/slot/{slot_id}/refresh` — Refresh Ams Slot
- `POST /api/v1/printers/{printer_id}/ams/{ams_id}/tray/{tray_id}/reset` — Reset Ams Slot
- `POST /api/v1/printers/{printer_id}/bed-jog` — Bed Jog
- `POST /api/v1/printers/{printer_id}/calibration` — Start Calibration
- `POST /api/v1/printers/{printer_id}/chamber-light` — Set Chamber Light
- `POST /api/v1/printers/{printer_id}/clear-plate` — Clear Plate
- `POST /api/v1/printers/{printer_id}/connect` — Connect Printer
- `GET /api/v1/printers/{printer_id}/cover` — Get Printer Cover
- `GET /api/v1/printers/{printer_id}/current-print-user` — Get Current Print User
- `POST /api/v1/printers/{printer_id}/debug/simulate-print-complete` — Debug Simulate Print Complete
- `GET /api/v1/printers/{printer_id}/diagnostic` — Diagnose Printer  _[resp:PrinterDiagnosticResult]_
- `POST /api/v1/printers/{printer_id}/disconnect` — Disconnect Printer
- `POST /api/v1/printers/{printer_id}/drying/start` — Start Drying
- `POST /api/v1/printers/{printer_id}/drying/stop` — Stop Drying
- `GET /api/v1/printers/{printer_id}/files` — List Printer Files
- `DELETE /api/v1/printers/{printer_id}/files` — Delete Printer File
- `GET /api/v1/printers/{printer_id}/files/download` — Download Printer File
- `POST /api/v1/printers/{printer_id}/files/download-zip` — Download Printer Files As Zip  _[req:object]_
- `GET /api/v1/printers/{printer_id}/files/gcode` — Get Printer File Gcode
- `GET /api/v1/printers/{printer_id}/files/plate-thumbnail/{plate_index}` — Get Printer File Plate Thumbnail
- `GET /api/v1/printers/{printer_id}/files/plates` — Get Printer File Plates
- `POST /api/v1/printers/{printer_id}/hms/clear` — Clear Hms Errors
- `POST /api/v1/printers/{printer_id}/home-axes` — Home Axes
- `GET /api/v1/printers/{printer_id}/logging` — Get Mqtt Logs
- `DELETE /api/v1/printers/{printer_id}/logging` — Clear Mqtt Logs
- `POST /api/v1/printers/{printer_id}/logging/disable` — Disable Mqtt Logging
- `POST /api/v1/printers/{printer_id}/logging/enable` — Enable Mqtt Logging
- `POST /api/v1/printers/{printer_id}/print-options` — Set Print Option
- `POST /api/v1/printers/{printer_id}/print-speed` — Set Print Speed
- `GET /api/v1/printers/{printer_id}/print/objects` — Get Printable Objects
- `POST /api/v1/printers/{printer_id}/print/pause` — Pause Print
- `POST /api/v1/printers/{printer_id}/print/resume` — Resume Print
- `POST /api/v1/printers/{printer_id}/print/skip-objects` — Skip Objects  _[req:integer[]]_
- `POST /api/v1/printers/{printer_id}/print/stop` — Stop Print
- `POST /api/v1/printers/{printer_id}/refresh-status` — Refresh Printer Status
- `GET /api/v1/printers/{printer_id}/runtime-debug` — Get Runtime Debug
- `GET /api/v1/printers/{printer_id}/slot-presets` — Get Slot Presets
- `GET /api/v1/printers/{printer_id}/slot-presets/{ams_id}/{tray_id}` — Get Slot Preset
- `PUT /api/v1/printers/{printer_id}/slot-presets/{ams_id}/{tray_id}` — Save Slot Preset
- `DELETE /api/v1/printers/{printer_id}/slot-presets/{ams_id}/{tray_id}` — Delete Slot Preset
- `POST /api/v1/printers/{printer_id}/slots/{ams_id}/{tray_id}/configure` — Configure Ams Slot
- `GET /api/v1/printers/{printer_id}/status` — Get Printer Status  _[resp:PrinterStatus]_
- `GET /api/v1/printers/{printer_id}/storage` — Get Printer Storage

## projects (28)

- `GET /api/v1/projects` — List Projects  _[resp:ProjectListResponse[]]_
- `GET /api/v1/projects/` — List Projects  _[resp:ProjectListResponse[]]_
- `POST /api/v1/projects/` — Create Project  _[req:ProjectCreate, resp:ProjectResponse]_
- `POST /api/v1/projects/from-template/{template_id}` — Create Project From Template  _[resp:ProjectResponse]_
- `POST /api/v1/projects/import` — Import Project  _[req:ProjectImport, resp:ProjectResponse]_
- `POST /api/v1/projects/import/file` — Import Project File  _[resp:ProjectResponse]_
- `GET /api/v1/projects/templates` — List Templates  _[resp:ProjectListResponse[]]_
- `GET /api/v1/projects/{project_id}` — Get Project  _[resp:ProjectResponse]_
- `PATCH /api/v1/projects/{project_id}` — Update Project  _[req:ProjectUpdate, resp:ProjectResponse]_
- `DELETE /api/v1/projects/{project_id}` — Delete Project
- `POST /api/v1/projects/{project_id}/add-archives` — Add Archives To Project  _[req:BatchAddArchives]_
- `POST /api/v1/projects/{project_id}/add-queue` — Add Queue Items To Project  _[req:BatchAddQueueItems]_
- `GET /api/v1/projects/{project_id}/archives` — List Project Archives
- `POST /api/v1/projects/{project_id}/attachments` — Upload Attachment
- `GET /api/v1/projects/{project_id}/attachments/{filename}` — Download Attachment
- `DELETE /api/v1/projects/{project_id}/attachments/{filename}` — Delete Attachment
- `GET /api/v1/projects/{project_id}/bom` — List Bom Items  _[resp:BOMItemResponse[]]_
- `POST /api/v1/projects/{project_id}/bom` — Create Bom Item  _[req:BOMItemCreate, resp:BOMItemResponse]_
- `PATCH /api/v1/projects/{project_id}/bom/{item_id}` — Update Bom Item  _[req:BOMItemUpdate, resp:BOMItemResponse]_
- `DELETE /api/v1/projects/{project_id}/bom/{item_id}` — Delete Bom Item
- `POST /api/v1/projects/{project_id}/cover-image` — Upload Project Cover Image
- `GET /api/v1/projects/{project_id}/cover-image` — Get Project Cover Image
- `DELETE /api/v1/projects/{project_id}/cover-image` — Delete Project Cover Image
- `POST /api/v1/projects/{project_id}/create-template` — Create Template From Project  _[resp:ProjectResponse]_
- `GET /api/v1/projects/{project_id}/export` — Export Project
- `GET /api/v1/projects/{project_id}/queue` — List Project Queue
- `POST /api/v1/projects/{project_id}/remove-archives` — Remove Archives From Project  _[req:BatchAddArchives]_
- `GET /api/v1/projects/{project_id}/timeline` — Get Project Timeline  _[resp:TimelineEvent[]]_

## queue (13)

- `GET /api/v1/queue/` — List Queue  _[resp:PrintQueueItemResponse[]]_
- `POST /api/v1/queue/` — Add To Queue  _[req:PrintQueueItemCreate, resp:PrintQueueItemResponse]_
- `GET /api/v1/queue/batches` — List Batches  _[resp:PrintBatchResponse[]]_
- `GET /api/v1/queue/batches/{batch_id}` — Get Batch  _[resp:PrintBatchResponse]_
- `DELETE /api/v1/queue/batches/{batch_id}` — Cancel Batch
- `PATCH /api/v1/queue/bulk` — Bulk Update Queue Items  _[req:PrintQueueBulkUpdate, resp:PrintQueueBulkUpdateResponse]_
- `POST /api/v1/queue/reorder` — Reorder Queue  _[req:PrintQueueReorder]_
- `GET /api/v1/queue/{item_id}` — Get Queue Item  _[resp:PrintQueueItemResponse]_
- `PATCH /api/v1/queue/{item_id}` — Update Queue Item  _[req:PrintQueueItemUpdate, resp:PrintQueueItemResponse]_
- `DELETE /api/v1/queue/{item_id}` — Delete Queue Item
- `POST /api/v1/queue/{item_id}/cancel` — Cancel Queue Item
- `POST /api/v1/queue/{item_id}/start` — Start Queue Item
- `POST /api/v1/queue/{item_id}/stop` — Stop Queue Item

## settings (19)

- `GET /api/v1/settings` — Get Settings  _[resp:AppSettings]_
- `PATCH /api/v1/settings` — Patch Settings  _[req:AppSettingsUpdate, resp:AppSettings]_
- `GET /api/v1/settings/` — Get Settings  _[resp:AppSettings]_
- `PUT /api/v1/settings/` — Update Settings  _[req:AppSettingsUpdate, resp:AppSettings]_
- `PATCH /api/v1/settings/` — Patch Settings  _[req:AppSettingsUpdate, resp:AppSettings]_
- `GET /api/v1/settings/backup` — Create Backup
- `GET /api/v1/settings/check-ffmpeg` — Check Ffmpeg
- `GET /api/v1/settings/default-sidebar-order` — Get Default Sidebar Order
- `POST /api/v1/settings/electricity-price` — Update Electricity Price  _[req:ElectricityPriceUpdate, resp:AppSettings]_
- `GET /api/v1/settings/mqtt/status` — Get Mqtt Status
- `GET /api/v1/settings/network-interfaces` — Get Network Interfaces
- `POST /api/v1/settings/reset` — Reset Settings  _[resp:AppSettings]_
- `POST /api/v1/settings/restore` — Restore Backup
- `GET /api/v1/settings/spoolman` — Get Spoolman Settings
- `PUT /api/v1/settings/spoolman` — Update Spoolman Settings  _[req:object]_
- `GET /api/v1/settings/ui-preferences` — Get Ui Preferences
- `GET /api/v1/settings/virtual-printer` — Get Virtual Printer Settings
- `PUT /api/v1/settings/virtual-printer` — Update Virtual Printer Settings
- `GET /api/v1/settings/virtual-printer/models` — Get Virtual Printer Models

## slice-jobs (1)

- `GET /api/v1/slice-jobs/{job_id}` — Get Slice Job

## smart-plugs (18)

- `GET /api/v1/smart-plugs/` — List Smart Plugs  _[resp:SmartPlugResponse[]]_
- `POST /api/v1/smart-plugs/` — Create Smart Plug  _[req:SmartPlugCreate, resp:SmartPlugResponse]_
- `GET /api/v1/smart-plugs/by-printer/{printer_id}` — Get Smart Plug By Printer  _[resp:SmartPlugResponse]_
- `GET /api/v1/smart-plugs/by-printer/{printer_id}/scripts` — Get Script Plugs By Printer  _[resp:SmartPlugResponse[]]_
- `GET /api/v1/smart-plugs/discover/devices` — Get Discovered Tasmota Devices  _[resp:DiscoveredTasmotaDevice[]]_
- `POST /api/v1/smart-plugs/discover/scan` — Start Tasmota Scan  _[req:TasmotaScanRequest, resp:TasmotaScanStatus]_
- `GET /api/v1/smart-plugs/discover/status` — Get Tasmota Scan Status  _[resp:TasmotaScanStatus]_
- `POST /api/v1/smart-plugs/discover/stop` — Stop Tasmota Scan  _[resp:TasmotaScanStatus]_
- `GET /api/v1/smart-plugs/ha/entities` — List Ha Entities  _[resp:HAEntity[]]_
- `GET /api/v1/smart-plugs/ha/sensors` — List Ha Sensor Entities  _[resp:HASensorEntity[]]_
- `POST /api/v1/smart-plugs/ha/test-connection` — Test Ha Connection  _[req:HATestConnectionRequest, resp:HATestConnectionResponse]_
- `POST /api/v1/smart-plugs/rest/test-connection` — Test Rest Connection  _[req:RESTTestConnectionRequest, resp:RESTTestConnectionResponse]_
- `POST /api/v1/smart-plugs/test-connection` — Test Connection  _[req:SmartPlugTestConnection]_
- `GET /api/v1/smart-plugs/{plug_id}` — Get Smart Plug  _[resp:SmartPlugResponse]_
- `PATCH /api/v1/smart-plugs/{plug_id}` — Update Smart Plug  _[req:SmartPlugUpdate, resp:SmartPlugResponse]_
- `DELETE /api/v1/smart-plugs/{plug_id}` — Delete Smart Plug
- `POST /api/v1/smart-plugs/{plug_id}/control` — Control Smart Plug  _[req:SmartPlugControl]_
- `GET /api/v1/smart-plugs/{plug_id}/status` — Get Plug Status  _[resp:SmartPlugStatus]_

## spoolbuddy (27)

- `GET /api/v1/spoolbuddy/devices` — List Devices  _[resp:DeviceResponse[]]_
- `POST /api/v1/spoolbuddy/devices/register` — Register Device  _[req:DeviceRegisterRequest, resp:DeviceResponse]_
- `DELETE /api/v1/spoolbuddy/devices/{device_id}` — Unregister Device
- `GET /api/v1/spoolbuddy/devices/{device_id}/calibration` — Get Calibration  _[resp:CalibrationResponse]_
- `POST /api/v1/spoolbuddy/devices/{device_id}/calibration/set-factor` — Set Calibration Factor  _[req:SetCalibrationFactorRequest]_
- `POST /api/v1/spoolbuddy/devices/{device_id}/calibration/set-tare` — Set Tare Offset  _[req:SetTareRequest]_
- `POST /api/v1/spoolbuddy/devices/{device_id}/calibration/tare` — Tare Scale
- `POST /api/v1/spoolbuddy/devices/{device_id}/cancel-write` — Cancel Write
- `GET /api/v1/spoolbuddy/devices/{device_id}/display` — Get Display Settings
- `PUT /api/v1/spoolbuddy/devices/{device_id}/display` — Update Display Settings  _[req:DisplaySettingsRequest]_
- `POST /api/v1/spoolbuddy/devices/{device_id}/heartbeat` — Device Heartbeat  _[req:HeartbeatRequest, resp:HeartbeatResponse]_
- `POST /api/v1/spoolbuddy/devices/{device_id}/system/command` — Queue System Command  _[req:SystemCommandRequest]_
- `POST /api/v1/spoolbuddy/devices/{device_id}/system/command-result` — System Command Result  _[req:SystemCommandResultRequest]_
- `POST /api/v1/spoolbuddy/devices/{device_id}/system/config` — Queue System Config Update  _[req:SystemConfigRequest]_
- `POST /api/v1/spoolbuddy/devices/{device_id}/update` — Trigger Daemon Update  _[req:object]_
- `GET /api/v1/spoolbuddy/devices/{device_id}/update-check` — Check Daemon Update
- `POST /api/v1/spoolbuddy/devices/{device_id}/update-status` — Report Update Status  _[req:UpdateStatusRequest]_
- `GET /api/v1/spoolbuddy/diagnostics/{device_id}/result` — Get Diagnostic Result
- `POST /api/v1/spoolbuddy/diagnostics/{device_id}/result` — Report Diagnostic Result  _[req:DiagnosticResultRequest]_
- `POST /api/v1/spoolbuddy/diagnostics/{device_id}/run` — Queue Diagnostic
- `POST /api/v1/spoolbuddy/nfc/tag-removed` — Nfc Tag Removed  _[req:TagRemovedRequest]_
- `POST /api/v1/spoolbuddy/nfc/tag-scanned` — Nfc Tag Scanned  _[req:TagScannedRequest]_
- `POST /api/v1/spoolbuddy/nfc/write-result` — Nfc Write Result  _[req:WriteTagResultRequest]_
- `POST /api/v1/spoolbuddy/nfc/write-tag` — Nfc Write Tag  _[req:WriteTagRequest]_
- `POST /api/v1/spoolbuddy/scale/reading` — Scale Reading  _[req:ScaleReadingRequest]_
- `POST /api/v1/spoolbuddy/scale/update-spool-weight` — Update Spool Weight  _[req:UpdateSpoolWeightRequest]_
- `GET /api/v1/spoolbuddy/ssh/public-key` — Get Ssh Public Key

## spoolman (11)

- `POST /api/v1/spoolman/connect` — Connect Spoolman
- `POST /api/v1/spoolman/disconnect` — Disconnect Spoolman
- `GET /api/v1/spoolman/filaments` — Get Filaments
- `GET /api/v1/spoolman/spools` — Get Spools
- `GET /api/v1/spoolman/spools/linked` — Get Linked Spools
- `GET /api/v1/spoolman/spools/unlinked` — Get Unlinked Spools  _[resp:UnlinkedSpool[]]_
- `POST /api/v1/spoolman/spools/{spool_id}/link` — Link Spool  _[req:LinkSpoolRequest]_
- `POST /api/v1/spoolman/spools/{spool_id}/unlink` — Unlink Spool
- `GET /api/v1/spoolman/status` — Get Spoolman Status  _[resp:SpoolmanStatus]_
- `POST /api/v1/spoolman/sync-all` — Sync All Printers  _[resp:SyncResult]_
- `POST /api/v1/spoolman/sync/{printer_id}` — Sync Printer Ams  _[resp:SyncResult]_

## spoolman-inventory (21)

- `GET /api/v1/spoolman/inventory/filaments` — List Spoolman Filaments  _[resp:NormalizedFilament[]]_
- `PATCH /api/v1/spoolman/inventory/filaments/{filament_id}` — Patch Spoolman Filament  _[req:SpoolmanFilamentPatch, resp:NormalizedFilament]_
- `POST /api/v1/spoolman/inventory/slot-assignments` — Assign Spoolman Slot  _[req:SpoolSlotAssignmentRequest, resp:object]_
- `GET /api/v1/spoolman/inventory/slot-assignments` — Get Spoolman Slot Assignment  _[resp:object]_
- `GET /api/v1/spoolman/inventory/slot-assignments/all` — Get All Spoolman Slot Assignments  _[resp:SpoolmanSlotAssignmentEnriched[]]_
- `DELETE /api/v1/spoolman/inventory/slot-assignments/{spoolman_spool_id}` — Unassign Spoolman Slot  _[resp:object]_
- `GET /api/v1/spoolman/inventory/spools` — List Spools  _[resp:object[]]_
- `POST /api/v1/spoolman/inventory/spools` — Create Spool  _[req:SpoolmanInventoryCreate, resp:object]_
- `POST /api/v1/spoolman/inventory/spools/bulk` — Bulk Create Spools  _[req:SpoolmanInventoryBulkCreate]_
- `POST /api/v1/spoolman/inventory/spools/reset-usage-bulk` — Bulk Reset Spool Usage  _[req:object, resp:object]_
- `GET /api/v1/spoolman/inventory/spools/{spool_id}` — Get Spool  _[resp:object]_
- `PATCH /api/v1/spoolman/inventory/spools/{spool_id}` — Update Spool  _[req:SpoolmanInventoryUpdate, resp:object]_
- `DELETE /api/v1/spoolman/inventory/spools/{spool_id}` — Delete Spool  _[resp:object]_
- `POST /api/v1/spoolman/inventory/spools/{spool_id}/archive` — Archive Spool  _[resp:object]_
- `GET /api/v1/spoolman/inventory/spools/{spool_id}/k-profiles` — Get Spoolman K Profiles  _[resp:object[]]_
- `PUT /api/v1/spoolman/inventory/spools/{spool_id}/k-profiles` — Save Spoolman K Profiles  _[req:SpoolKProfileBase[], resp:object[]]_
- `POST /api/v1/spoolman/inventory/spools/{spool_id}/reset-usage` — Reset Spool Usage  _[resp:object]_
- `POST /api/v1/spoolman/inventory/spools/{spool_id}/restore` — Restore Spool  _[resp:object]_
- `PATCH /api/v1/spoolman/inventory/spools/{spool_id}/tag` — Link Tag To Spoolman Spool  _[req:SpoolTagLinkRequest, resp:object]_
- `PATCH /api/v1/spoolman/inventory/spools/{spool_id}/weight` — Sync Spool Weight  _[req:SpoolWeightUpdate, resp:object]_
- `POST /api/v1/spoolman/inventory/sync-ams-weights` — Sync Spoolman Ams Weights

## support (5)

- `GET /api/v1/support/bundle` — Generate Support Bundle
- `GET /api/v1/support/debug-logging` — Get Debug Logging State  _[resp:DebugLoggingState]_
- `POST /api/v1/support/debug-logging` — Toggle Debug Logging  _[req:DebugLoggingToggle, resp:DebugLoggingState]_
- `GET /api/v1/support/logs` — Get Logs  _[resp:LogsResponse]_
- `DELETE /api/v1/support/logs` — Clear Logs

## system (3)

- `GET /api/v1/system/health` — Get System Health  _[resp:ScanResult]_
- `GET /api/v1/system/info` — Get System Info
- `GET /api/v1/system/storage-usage` — Get Storage Usage

## updates (4)

- `POST /api/v1/updates/apply` — Apply Update
- `GET /api/v1/updates/check` — Check For Updates
- `GET /api/v1/updates/status` — Get Update Status
- `GET /api/v1/updates/version` — Get Version

## user-notifications (2)

- `GET /api/v1/user-notifications/preferences` — Get User Email Preferences  _[resp:UserEmailPreferenceResponse]_
- `PUT /api/v1/user-notifications/preferences` — Update User Email Preferences  _[req:UserEmailPreferenceUpdate, resp:UserEmailPreferenceResponse]_

## users (9)

- `GET /api/v1/users` — List Users  _[resp:UserResponse[]]_
- `POST /api/v1/users` — Create User  _[req:UserCreate, resp:UserResponse]_
- `GET /api/v1/users/` — List Users  _[resp:UserResponse[]]_
- `POST /api/v1/users/` — Create User  _[req:UserCreate, resp:UserResponse]_
- `POST /api/v1/users/me/change-password` — Change Own Password  _[req:ChangePasswordRequest, resp:object]_
- `GET /api/v1/users/{user_id}` — Get User  _[resp:UserResponse]_
- `PATCH /api/v1/users/{user_id}` — Update User  _[req:UserUpdate, resp:UserResponse]_
- `DELETE /api/v1/users/{user_id}` — Delete User
- `GET /api/v1/users/{user_id}/items-count` — Get User Items Count

## virtual-printers (8)

- `GET /api/v1/virtual-printers` — List Virtual Printers
- `POST /api/v1/virtual-printers` — Create Virtual Printer  _[req:VirtualPrinterCreate]_
- `GET /api/v1/virtual-printers/ca-certificate` — Get Ca Certificate
- `GET /api/v1/virtual-printers/tailscale-status` — Get Tailscale Status  _[resp:TailscaleStatusResponse]_
- `GET /api/v1/virtual-printers/{vp_id}` — Get Virtual Printer
- `PUT /api/v1/virtual-printers/{vp_id}` — Update Virtual Printer  _[req:VirtualPrinterUpdate]_
- `DELETE /api/v1/virtual-printers/{vp_id}` — Delete Virtual Printer
- `GET /api/v1/virtual-printers/{vp_id}/diagnostic` — Diagnose Virtual Printer  _[resp:VPDiagnosticResult]_

## webhook (6)

- `POST /api/v1/webhook/printer/{printer_id}/cancel` — Webhook Cancel Print
- `POST /api/v1/webhook/printer/{printer_id}/start` — Webhook Start Print
- `GET /api/v1/webhook/printer/{printer_id}/status` — Webhook Get Printer Status  _[resp:PrinterStatusResponse]_
- `POST /api/v1/webhook/printer/{printer_id}/stop` — Webhook Stop Print
- `GET /api/v1/webhook/queue` — Webhook Get Queue Status  _[resp:QueueStatusResponse[]]_
- `POST /api/v1/webhook/queue/add` — Webhook Add To Queue  _[req:QueueAddRequest, resp:QueueAddResponse]_

