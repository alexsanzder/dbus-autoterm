/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.impl as CP
import QtQuick.Templates as T
import Victron.VenusOS

SwipeViewPage {
	id: root

	required property var heaterModel

	property int currentHeaterIndex: 0
	property string pendingStartStopAction: ""

	readonly property int heaterCount: heaterModel ? heaterModel.count : 0
	readonly property var currentHeater: heaterModel ? heaterModel.deviceAt(currentHeaterIndex) : null
	readonly property string bindPrefix: currentHeater ? currentHeater.serviceUid : ""
	readonly property url heaterIcon: Qt.resolvedUrl("../images/heater_bottom_bar.svg")
	readonly property url flameIcon: Qt.resolvedUrl("../images/icon_flame.svg")
	readonly property bool hasHeater: !!currentHeater
	readonly property bool isRunning: heaterState.valid && heaterState.value !== 0 && heaterState.value !== 10
	readonly property bool isStarting: pendingStartStopAction === "start"
	readonly property bool isStopping: pendingStartStopAction === "stop"
	readonly property bool isTransitioning: pendingStartStopAction !== ""
	readonly property bool hasRoomTemperatureControl: roomTemperatureControl.valid && roomTemperatureControl.value === 1
	readonly property bool isVentilationMode: mode.valid && mode.value === 2
	readonly property bool showTemperatureControl: hasRoomTemperatureControl && mode.valid && (mode.value === 1 || mode.value === 3)
	readonly property bool showPowerControl: mode.valid && (mode.value === 0 || mode.value === 2)
	readonly property color panelStrokeColor: Theme.color_listItem_secondaryText
	readonly property color ringProgressColor: themeBlueProbe.backgroundColor
	// Home Assistant thermostat card palette: amber while heating, blue while
	// ventilating, gray when idle.
	readonly property color ringStateColor: !isRunning
		? Qt.rgba(0.62, 0.36, 0.05, 1)  // dark amber while stopped
		: (isVentilationMode ? Theme.color_blue : Qt.rgba(1.0, 0.58, 0.08, 1))
	readonly property string actionLabel: isStarting
		? "Starting..."
		: (isStopping
			? "Stopping..."
			: (isRunning
				? (isVentilationMode ? "Stop ventilation" : "Stop heater")
				: (isVentilationMode ? "Start ventilation" : "Start heater")))
	readonly property string actionDescription: isRunning
		? (isVentilationMode
			? "The heater will stop ventilation mode."
			: "The heater will begin its shutdown cycle.")
		: (isVentilationMode
			? "The heater will start in ventilation mode."
			: "The heater will start heating with the current settings.")
	readonly property string activeModeCardKey: {
		if (!mode.valid) {
			return ""
		}
		switch (mode.value) {
		case 0:
			return "power"
		case 1:
			return "temperature"
		case 2:
			return "ventilation"
		case 3:
			return "heat-ventilation"
		default:
			return ""
		}
	}
	readonly property var modeCards: [
		{ key: "temperature", modeValue: 1, label: "Temperature", icon: "qrc:/images/icon_temp_32.svg", description: "Maintain a target room temperature." },
		{ key: "power", modeValue: 0, label: "Power", icon: root.flameIcon, description: "Run the heater at a fixed power level." },
		{ key: "heat-ventilation", modeValue: 3, label: "Heat & Vent", icon: root.heaterIcon, description: "Blend heating with ventilation support." },
		{ key: "thermostat", modeValue: -1, label: "Thermostat", icon: "qrc:/images/icon_temp_coolant_32.svg", description: "Thermostat control placeholder for the custom GUI." },
		{ key: "ventilation", modeValue: 2, label: "Ventilation", icon: "qrc:/images/icon_propeller.svg", description: "Circulate air without active heating." },
	]
	readonly property string activeModeDescription: {
		for (let i = 0; i < modeCards.length; ++i) {
			if (modeCards[i].key === activeModeCardKey) {
				return modeCards[i].description
			}
		}
		return "Select a heater mode to see more details here."
	}
	// Short live status for the dial top: compact form of /StateText.
	readonly property string ringStatusLabel: {
		if (!stateText.valid) {
			return "Idle"
		}
		switch (stateText.value) {
			case "not connected":
				return "Not connected"
			case "fault":
				return "Fault"
			case "starting":
			case "starting ventilation":
				return "Starting"
			case "warming up":
				return "Warming up"
			case "shutting down":
			case "stopping ventilation":
				return "Cooling down"
			case "running":
				if (showTemperatureControl) {
					return "Heating to"
				}
				if (showPowerControl) {
					return "Heating level"
				}
				return "Running"
			case "ventilation":
				return "Only Ventilation"
			case "off":
				return "Idle"
			default:
				return "Idle"
		}
	}
	// Live status line: replaces the static description while the heater
	// transitions or runs, showing real telemetry for the active mode.
	readonly property string statusDescription: {
		if (!stateText.valid) {
			return activeModeDescription
		}
		const room = root.formatTemperatureValue(roomTemperature)
		if (stateText.value === "not connected") {
			return "Heater not connected."
		}
		if (stateText.value === "fault") {
			return errorText.valid && errorText.value !== "" ? errorText.value : "Heater fault."
		}
		if (stateText.value === "starting" || stateText.value === "starting ventilation") {
			return "Starting heater..."
		}
		if (stateText.value === "warming up") {
			return "Warming up..."
		}
		if (stateText.value === "shutting down" || stateText.value === "stopping ventilation") {
			return "Cooling down before stopping..."
		}
		if (stateText.value === "running") {
			const target = targetTemperature.valid ? root.formatTemperatureValue(targetTemperature) : "--"
			if (showPowerControl) {
				const level = powerLevel.valid ? powerLevel.value : "--"
				return "Running at power level " + level + " \u00B7 room " + room
			}
			return "Heating to " + target + " \u00B7 room " + room
		}
		if (stateText.value === "ventilation") {
			return "Ventilating \u00B7 room " + room
		}
		return activeModeDescription
	}
	// Compact caption inside the dial: the current temperature.
	readonly property string ringCurrentTempCaption: formatTemperatureValue(displayTemperatureItem)

	readonly property var tabModel: {
		const tabs = []
		if (!heaterModel) {
			return tabs
		}
		for (let i = 0; i < heaterModel.count; ++i) {
			const device = heaterModel.deviceAt(i)
			tabs.push({ value: device && device.name ? device.name : "Heater " + (i + 1) })
		}
		return tabs
	}
	readonly property real ringValueRatio: {
		if (showPowerControl && powerLevel.valid) {
			return clamp(powerLevel.value / 9.0, 0.0, 1.0)
		}
		if (showTemperatureControl && targetTemperature.valid) {
			return clamp((targetTemperature.value - 5.0) / 30.0, 0.0, 1.0)
		}
		return 1.0
	}
	readonly property bool canAdjustRingValue: showPowerControl
		? powerLevel.valid
		: (showTemperatureControl && targetTemperature.valid)
	// Current temperature shown as the dial caption: room temperature when a
	// room source exists, otherwise the heater internal sensor.
	readonly property var displayTemperatureItem: roomTemperature.valid
		? roomTemperature
		: (internalTemperature.valid ? internalTemperature : heaterTemperature)
	// Big center value: the value the ring steppers set — target temperature
	// in temperature modes, power level in power/ventilation modes.
	readonly property string ringPrimaryValue: showPowerControl
		? (powerLevel.valid ? powerLevel.value : "--")
		: (targetTemperature.valid ? formatTemperatureValue(targetTemperature) : "--")

	topLeftButton: VenusOS.StatusBar_LeftButton_ControlsInactive
	fullScreenWhenIdle: true
	focusPolicy: Qt.TabFocus
	navButtonText: "Heater"
	navButtonIcon: heaterIcon
	url: Qt.resolvedUrl("HeaterPage.qml")

	onHeaterCountChanged: {
		if (heaterCount === 0 || currentHeaterIndex >= heaterCount) {
			currentHeaterIndex = 0
		}
	}

	TabBar {
		id: tabBar

		visible: root.heaterCount > 1
		anchors {
			top: parent.top
			topMargin: Global.pageManager?.expandLayout ? -tabBar.height : 0
			horizontalCenter: parent.horizontalCenter
		}
		opacity: Global.pageManager?.interactivity === VenusOS.PageManager_InteractionMode_Interactive
				 || Global.pageManager?.interactivity === VenusOS.PageManager_InteractionMode_ExitIdleMode
				 ? 1.0
				 : 0.0

		Behavior on opacity {
			enabled: root.animationEnabled && root.isCurrentPage
			OpacityAnimator { duration: Theme.animation_page_idleOpacity_duration }
		}

		Behavior on anchors.topMargin {
			enabled: root.animationEnabled && root.isCurrentPage
			NumberAnimation { duration: Theme.animation_page_idleResize_duration; easing.type: Easing.InOutQuad }
		}

		model: root.tabModel
		currentIndex: root.currentHeaterIndex
		KeyNavigation.down: contentScope
		onButtonClicked: function(buttonIndex) {
			root.currentHeaterIndex = buttonIndex
		}
	}

	Button {
		id: themeBlueProbe
		visible: false
	}



	FocusScope {
		id: contentScope

		anchors {
			top: tabBar.visible ? tabBar.bottom : parent.top
			topMargin: 12
			left: parent.left
			leftMargin: Theme.geometry_page_content_horizontalMargin
			right: parent.right
			rightMargin: Theme.geometry_page_content_horizontalMargin
			bottom: parent.bottom
			bottomMargin: Theme.geometry_page_content_verticalMargin
		}

		EmptyPageItem {
			visible: !root.hasHeater
			anchors.centerIn: parent
			width: Math.min(parent.width, Theme.geometry_screen_width * 0.7)
			titleText: "Heater"
			imageSource: root.heaterIcon
			imageColor: Theme.color_font_primary
			primaryText: "No heaters available."
			secondaryText: "No heater service detected."
		}

		HeaterTab {
			id: heaterTab

			anchors.fill: parent
			animationEnabled: root.animationEnabled
			visible: root.hasHeater
			focus: visible
			model: root.hasHeater ? [root.currentHeater] : []

			delegate: Item {
				required property var modelData

				width: heaterTab.width
				height: heaterTab.height

				// Fixed two-column card for 7" displays: dial + start/stop on the left,
				// telemetry, status, and mode selection on the right. No scrolling.
				Row {
					id: cardRow

					anchors.fill: parent
					spacing: 24

					// LEFT column
					Item {
						id: leftColumn

						width: Math.round(parent.width * 0.52)
						height: parent.height

						Item {
							id: dialArea

							anchors {
								top: parent.top
								left: parent.left
								right: parent.right
								bottom: modeBlock.top
								bottomMargin: 20
							}

							CircularHeaterRing {
								id: ring

								width: Math.min(dialArea.width * 0.9, dialArea.height, 340)
								height: width
								anchors {
									top: parent.top
									horizontalCenter: parent.horizontalCenter
									topMargin: 0
								}

								valueRatio: root.ringValueRatio
								progressColor: root.ringStateColor
								primaryValue: root.ringPrimaryValue
								secondaryValue: ""
								captionValue: root.ringCurrentTempCaption
								statusValue: root.ringStatusLabel
							}

							// Steppers hug the ring's bottom opening
							Row {
								anchors.top: ring.bottom
								anchors.topMargin: -56
								anchors.horizontalCenter: ring.horizontalCenter
								spacing: 12

								Item {
									width: 56
									height: 56

									Button {
										anchors.fill: parent
										text: "\u2013"
										enabled: root.canAdjustRingValue
										font.pixelSize: Theme.font_size_h2 - 5
										color: Theme.color_font_secondary
										onClicked: root.adjustRingValue(-1)
									}

									// Gray circular 1.5px border overlay
									Rectangle {
										anchors.fill: parent
										radius: width / 2
										color: "transparent"
										border.width: 1.5
										border.color: Theme.color_font_secondary
									}
								}

								Item {
									width: 56
									height: 56

									Button {
										anchors.fill: parent
										text: "+"
										enabled: root.canAdjustRingValue
										font.pixelSize: Theme.font_size_h2 - 5
										color: Theme.color_font_secondary
										onClicked: root.adjustRingValue(1)
									}

									// Gray circular 1.5px border overlay
									Rectangle {
										anchors.fill: parent
										radius: width / 2
										color: "transparent"
										border.width: 1.5
										border.color: Theme.color_font_secondary
									}
								}
							}
						}

						Column {
							id: modeBlock

							anchors {
								bottom: parent.bottom
								horizontalCenter: parent.horizontalCenter
							}
							spacing: 10

							Row {
								spacing: 12
								anchors.horizontalCenter: parent.horizontalCenter

								Repeater {
									model: root.modeCards

									Button {
										id: chipButton

										required property var modelData

										readonly property bool active: modelData.key === root.activeModeCardKey
										readonly property bool roomSensorMode: modelData.modeValue === 1 || modelData.modeValue === 3
										readonly property bool supported: modelData.modeValue >= 0
										readonly property bool selectable: supported && (!roomSensorMode || root.hasRoomTemperatureControl)

										height: 58
										width: 58

										text: ""
										flat: false
										enabled: selectable
										backgroundColor: active ? Theme.color_blue : Theme.color_gray1
										borderColor: active ? Theme.color_blue : Theme.color_gray1
										color: Theme.color_white

										onClicked: root.requestModeChange(modelData.modeValue, modelData.label)

										CP.ColorImage {
											anchors.centerIn: parent
											width: 26
											height: 26
											source: chipButton.modelData.icon
											fillMode: Image.PreserveAspectFit
											color: Theme.color_white
										}
									}
								}
							}
						}
					}

					// RIGHT column
					Item {
						id: rightColumn

						width: parent.width - leftColumn.width - cardRow.spacing
						height: parent.height

	// Live telemetry strip (transparent, theme-friendly)
	Item {
		id: statusIndicatorHeader

		anchors {
			top: parent.top
			left: parent.left
			right: parent.right
		}
		// Telemetry strip spans the top of the fixed two-column card.
		visible: root.hasHeater
		height: visible ? 64 : 0

		readonly property var cells: [
			{
				icon: "qrc:/images/icon_checkmark_32.svg",
				label: qsTr("Connection"),
				value: (communicationAlarm.valid && communicationAlarm.value !== 0) ? qsTr("Alarm") : qsTr("Connected"),
				valueColor: (communicationAlarm.valid && communicationAlarm.value !== 0) ? Theme.color_red : Theme.color_green,
				iconColor: (communicationAlarm.valid && communicationAlarm.value !== 0) ? Theme.color_red : Theme.color_green
			},
			{
				icon: "qrc:/images/icon_battery_24.svg",
				label: qsTr("Battery"),
				value: batteryVoltage.valid ? batteryVoltage.value.toFixed(1) + " V" : "--",
				valueColor: Theme.color_font_primary,
				iconColor: Theme.color_font_secondary
			},
			{
				icon: "qrc:/images/icon_propeller.svg",
				iconSize: 20,
				label: qsTr("Fan"),
				value: fanRpmActual.valid ? fanRpmActual.value + " " + qsTr("RPM") : "--",
				valueColor: Theme.color_font_primary,
				iconColor: Theme.color_font_secondary
			},
			{
				icon: "qrc:/images/icon_engine_temp_32.svg",
				label: qsTr("Heater"),
				value: heaterTemperature.valid ? heaterTemperature.value + "\u00B0C" : "--",
				valueColor: Theme.color_font_primary,
				iconColor: Theme.color_font_secondary
			},
			{
				icon: "qrc:/images/icon_temp_32.svg",
				label: qsTr("Room"),
				value: roomTemperature.valid
						? root.formatTemperatureValue(roomTemperature)
						: (internalTemperature.valid ? internalTemperature.value + "\u00B0C" : "--"),
				valueColor: Theme.color_font_primary,
				iconColor: Theme.color_font_secondary
			}
		]

		RowLayout {
			anchors {
				fill: parent
				leftMargin: 0
				rightMargin: 0
			}
			spacing: 0

			Repeater {
				model: statusIndicatorHeader.cells

				RowLayout {
					id: statusCell

					required property var modelData
					required property int index

					Layout.fillWidth: true
					Layout.fillHeight: true
					spacing: 10

					Rectangle {
						Layout.preferredWidth: 1
						Layout.fillHeight: true
						Layout.topMargin: 12
						Layout.bottomMargin: 12
						visible: statusCell.index > 0
						color: Qt.rgba(1, 1, 1, 0.15)
					}

					CP.ColorImage {
						Layout.alignment: Qt.AlignVCenter
						Layout.preferredWidth: statusCell.modelData.iconSize !== undefined ? statusCell.modelData.iconSize : 22
						Layout.preferredHeight: statusCell.modelData.iconSize !== undefined ? statusCell.modelData.iconSize : 22
						source: statusCell.modelData.icon
						color: statusCell.modelData.iconColor
					}

					ColumnLayout {
						Layout.alignment: Qt.AlignVCenter
						spacing: 0

						Label {
							Layout.fillWidth: true
							font.pixelSize: Theme.font_size_caption
							color: Theme.color_font_secondary
							text: statusCell.modelData.label
						}

						Label {
							Layout.fillWidth: true
							font.pixelSize: Theme.font_size_body1
							font.bold: true
							elide: Label.ElideRight
							color: statusCell.modelData.valueColor
							text: statusCell.modelData.value
						}
					}
				}
			}
		}
	}

						Rectangle {
							id: statusCard

							anchors {
								top: statusIndicatorHeader.bottom
						topMargin: 12
								left: parent.left
								right: parent.right
							}
							height: 128
							radius: 8
							color: Qt.rgba(1, 1, 1, 0.05)


							Label {
								anchors {
									fill: parent
									margins: 12
								}
								text: root.statusDescription
								wrapMode: Text.WordWrap
								maximumLineCount: 4
								elide: Text.ElideRight
								verticalAlignment: Text.AlignVCenter
								color: Theme.color_font_primary
								font.pixelSize: Theme.font_size_body1
							}
						}

						Button {
							id: actionButton

							anchors {
								left: parent.left
								right: parent.right
								bottom: parent.bottom
							}
							height: 64
							text: root.actionLabel
							enabled: startStop.valid && !root.isTransitioning
							flat: false
							backgroundColor: root.pendingStartStopAction === "start"
								? Theme.color_darkBlue
								: (root.pendingStartStopAction === "stop"
									? Theme.color_darkRed
									: (root.isRunning ? Theme.color_red : Theme.color_blue))
							borderColor: root.pendingStartStopAction === "start"
								? Theme.color_darkBlue
								: (root.pendingStartStopAction === "stop"
									? Theme.color_darkRed
									: (root.isRunning ? Theme.color_red : Theme.color_blue))
							color: Theme.color_white
							font.pixelSize: Theme.font_size_body1
							font.bold: true
							onClicked: Global.dialogLayer.open(startStopDialogComponent, {
								startRequested: !root.isRunning,
							})
						}
					}
				}
			}
		}
	}

	VeQuickItem { id: stateText; uid: root.bindPrefix + "/StateText" }
	VeQuickItem { id: errorText; uid: root.bindPrefix + "/ErrorText" }
	VeQuickItem { id: mode; uid: root.bindPrefix + "/Mode" }
	VeQuickItem { id: heaterState; uid: root.bindPrefix + "/State" }
	VeQuickItem { id: startStop; uid: root.bindPrefix + "/StartStop" }
	VeQuickItem { id: roomTemperatureControl; uid: root.bindPrefix + "/Capabilities/RoomTemperatureControl" }
	VeQuickItem { id: roomTemperature; uid: root.bindPrefix + "/Temperatures/Room" }
	VeQuickItem { id: targetTemperature; uid: root.bindPrefix + "/Settings/TargetTemperature" }
	VeQuickItem { id: powerLevel; uid: root.bindPrefix + "/Settings/PowerLevel" }
	// Live telemetry data
	VeQuickItem { id: batteryVoltage; uid: root.bindPrefix + "/Dc/0/Voltage" }
	VeQuickItem { id: fanRpmSet; uid: root.bindPrefix + "/Status/FanRpmSet" }
	VeQuickItem { id: fanRpmActual; uid: root.bindPrefix + "/Status/FanRpmActual" }
	VeQuickItem { id: heaterTemperature; uid: root.bindPrefix + "/Temperatures/Heater" }
	VeQuickItem { id: internalTemperature; uid: root.bindPrefix + "/Temperatures/Internal" }
	VeQuickItem { id: fuelPumpFrequency; uid: root.bindPrefix + "/Status/FuelPumpFrequency" }
	VeQuickItem { id: communicationAlarm; uid: root.bindPrefix + "/Alarms/Communication" }

	Connections {
		target: heaterState

		function onValueChanged() {
			if (root.pendingStartStopAction === "start" && (heaterState.value === 3 || heaterState.value === 0 || heaterState.value === 10)) {
				root.pendingStartStopAction = ""
			} else if (root.pendingStartStopAction === "stop" && (heaterState.value === 0 || heaterState.value === 10)) {
				root.pendingStartStopAction = ""
			}
		}
	}

	Component {
		id: startStopDialogComponent

		ModalWarningDialog {
			required property bool startRequested

			title: root.actionLabel + "?"
			description: root.actionDescription
			dialogDoneOptions: VenusOS.ModalDialog_DoneOptions_OkAndCancel
			acceptText: root.actionLabel
			onClosed: {
				if (result === T.Dialog.Accepted) {
					root.pendingStartStopAction = startRequested ? "start" : "stop"
					startStop.setValue(startRequested ? 1 : 0)
				}
			}
		}
	}

	Component {
		id: modeChangeDialogComponent

		ModalWarningDialog {
			required property int requestedModeValue
			required property string requestedModeLabel

			title: "Change mode?"
			description: "The heater is running. Switch to " + requestedModeLabel + " now?"
			dialogDoneOptions: VenusOS.ModalDialog_DoneOptions_OkAndCancel
			acceptText: "Change mode"
			onClosed: {
				if (result === T.Dialog.Accepted) {
					root.selectMode(requestedModeValue)
				}
			}
		}
	}

	function clamp(value, minValue, maxValue) {
		return Math.max(minValue, Math.min(maxValue, value))
	}

	function formatTemperatureValue(item) {
		if (!item.valid || item.value === undefined || item.value === null || item.value === "") {
			return "--"
		}
		return Number(Units.convert(item.value, VenusOS.Units_Temperature_Celsius, Global.systemSettings.temperatureUnit)).toFixed(0)
			+ Global.systemSettings.temperatureUnitSuffix
	}

	function adjustRingValue(delta) {
		if (showPowerControl && powerLevel.valid) {
			powerLevel.setValue(clamp(powerLevel.value + delta, 1, 9))
			return
		}
		if (showTemperatureControl && targetTemperature.valid) {
			targetTemperature.setValue(clamp(targetTemperature.value + delta, 5, 35))
		}
	}

	function selectMode(modeValue) {
		if (modeValue < 0) {
			return
		}
		if ((modeValue === 1 || modeValue === 3) && !hasRoomTemperatureControl) {
			return
		}
		mode.setValue(modeValue)
	}

	function requestModeChange(modeValue, modeLabel) {
		if (modeValue < 0 || !mode.valid || mode.value === modeValue) {
			return
		}
		if ((modeValue === 1 || modeValue === 3) && !hasRoomTemperatureControl) {
			return
		}
		if (isRunning) {
			Global.dialogLayer.open(modeChangeDialogComponent, {
				requestedModeValue: modeValue,
				requestedModeLabel: modeLabel,
			})
			return
		}
		selectMode(modeValue)
	}
}
