// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

public extension PrinterStatus {
    /// Fusionne un delta (souvent partiel, poussé par le WebSocket) sur l'état courant : chaque
    /// champ présent dans `delta` remplace la valeur courante ; les champs absents (`nil`) sont
    /// conservés. Voir `docs/bambuddy-api.md` §4.3.
    func merged(with delta: PrinterStatus) -> PrinterStatus {
        var result = self
        result.name = delta.name ?? result.name
        result.model = delta.model ?? result.model
        result.connected = delta.connected ?? result.connected
        result.state = delta.state ?? result.state

        result.currentPrint = delta.currentPrint ?? result.currentPrint
        result.subtaskName = delta.subtaskName ?? result.subtaskName
        result.gcodeFile = delta.gcodeFile ?? result.gcodeFile
        result.progress = delta.progress ?? result.progress
        result.remainingTime = delta.remainingTime ?? result.remainingTime
        result.layerNum = delta.layerNum ?? result.layerNum
        result.totalLayers = delta.totalLayers ?? result.totalLayers
        result.coverUrl = delta.coverUrl ?? result.coverUrl
        result.currentArchiveId = delta.currentArchiveId ?? result.currentArchiveId
        result.currentPlateId = delta.currentPlateId ?? result.currentPlateId

        result.temperatures = delta.temperatures ?? result.temperatures
        result.hmsErrors = delta.hmsErrors ?? result.hmsErrors
        result.ams = delta.ams ?? result.ams
        result.vtTray = delta.vtTray ?? result.vtTray
        result.wifiSignal = delta.wifiSignal ?? result.wifiSignal
        result.wiredNetwork = delta.wiredNetwork ?? result.wiredNetwork
        result.doorOpen = delta.doorOpen ?? result.doorOpen

        result.coolingFanSpeed = delta.coolingFanSpeed ?? result.coolingFanSpeed
        result.bigFan1Speed = delta.bigFan1Speed ?? result.bigFan1Speed
        result.bigFan2Speed = delta.bigFan2Speed ?? result.bigFan2Speed
        result.heatbreakFanSpeed = delta.heatbreakFanSpeed ?? result.heatbreakFanSpeed

        result.chamberLight = delta.chamberLight ?? result.chamberLight
        result.activeExtruder = delta.activeExtruder ?? result.activeExtruder
        result.speedLevel = delta.speedLevel ?? result.speedLevel
        result.stgCur = delta.stgCur ?? result.stgCur
        result.stgCurName = delta.stgCurName ?? result.stgCurName
        result.printableObjectsCount = delta.printableObjectsCount ?? result.printableObjectsCount
        result.awaitingPlateClear = delta.awaitingPlateClear ?? result.awaitingPlateClear
        result.supportsDrying = delta.supportsDrying ?? result.supportsDrying
        result.firmwareVersion = delta.firmwareVersion ?? result.firmwareVersion
        result.sdcard = delta.sdcard ?? result.sdcard
        result.timelapse = delta.timelapse ?? result.timelapse
        result.ipcam = delta.ipcam ?? result.ipcam
        result.printOptions = delta.printOptions ?? result.printOptions
        result.airductMode = delta.airductMode ?? result.airductMode
        return result
    }
}
