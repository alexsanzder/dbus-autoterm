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
	property bool dialEnabled: false
	property string selectedModeKey: ""
	property string lastModeKey: ""
	property int rightTabIndex: 0
	property real primaryValueFontScale: 1.5

	// Timer tab state (UI-only until the backend timer paths are wired).
	// Duration range per Comfort Control manual: 30-720 min in 5-min steps.
	property int timerSelectedMinutes: 0
	property int timerRemainingSeconds: 0
	property bool timerRunning: false	
	readonly property var timerStepMinutes: [5, 15, 30]
	readonly property var timerPresetMinutes: [30, 60, 90]
	readonly property string timerDisplayText: {
		const total = timerRunning ? timerRemainingSeconds : timerSelectedMinutes * 60
		if (total <= 0) {
			return "--:--"
		}
		const hours = Math.floor(total / 3600)
		const minutes = Math.floor((total % 3600) / 60)
		const seconds = total % 60
		return (hours > 0 ? String(hours).padStart(2, "0") + ":" : "")
			+ String(minutes).padStart(2, "0") + ":"
			+ String(seconds).padStart(2, "0")
	}
	// TODO: wire to the backend daily-usage counter once it exists.
	readonly property string timerDailyUsageText: "--:--:--"
	// Arming a timer only makes sense once a mode is chosen — same gate as
	// the Start button, with "off" counting as no mode. While the heater
	// runs, keep the panel adjustable for the live countdown — but lock it
	// during start/stop transitions (starting, warming up, cooling down).
	readonly property bool heaterTransitioning: isTransitioning
		|| (stateText.valid && (stateText.value === "starting" || stateText.value === "starting ventilation"
			|| stateText.value === "warming up" || stateText.value === "shutting down"
			|| stateText.value === "stopping ventilation"))
	readonly property bool timerPanelEnabled: !heaterTransitioning
		&& ((root.selectedModeKey !== "" && root.selectedModeKey !== "off") || root.isRunning)

	readonly property int heaterCount: heaterModel ? heaterModel.count : 0
	readonly property var currentHeater: heaterModel ? heaterModel.deviceAt(currentHeaterIndex) : null
	readonly property string bindPrefix: currentHeater ? currentHeater.serviceUid : ""
	readonly property url heaterIcon: Qt.resolvedUrl("../images/heater_bottom_bar.svg")
	readonly property url flameIcon: Qt.resolvedUrl("../images/icon_flame.svg")
	readonly property url infoIcon: Qt.resolvedUrl("../images/icon_info.svg")
	readonly property url powerIcon: Qt.resolvedUrl("../images/icon_power.svg")
	readonly property url pumpIcon: Qt.resolvedUrl("../images/icon_pump.svg")
	readonly property url alertIcon: Qt.resolvedUrl("../images/icon_alert.svg")
	readonly property url timerRemoveIcon: Qt.resolvedUrl("../images/icon_timer_remove.svg")
	readonly property url fanClockIcon: Qt.resolvedUrl("../images/icon_fan_clock.svg")
	readonly property bool hasHeater: !!currentHeater
	readonly property bool heaterDisconnected: communicationAlarm.valid && communicationAlarm.value !== 0
	readonly property bool isRunning: heaterState.valid && heaterState.value !== 0 && heaterState.value !== 10
	readonly property bool isStarting: pendingStartStopAction === "start"
	readonly property bool isStopping: pendingStartStopAction === "stop"
	readonly property bool isTransitioning: pendingStartStopAction !== ""
	readonly property bool hasRoomTemperatureControl: roomTemperatureControl.valid && roomTemperatureControl.value === 1
	readonly property bool isVentilationMode: mode.valid && mode.value === 2
	// Manual p11-12: heating↔ventilation cross-switch while running is forbidden.
	// Lock the opposite family while the heater is operating.
	readonly property bool ventilationLocked: isRunning && !isVentilationMode
	readonly property bool heatingLocked: isRunning && isVentilationMode
	// Preview mode for idle Off state — default disabled chip is Temperature
	// per spec, so ring should show temp not power when heater is off.
	readonly property string previewModeKey: selectedModeKey !== ""
		? selectedModeKey
		: (lastModeKey !== "" ? lastModeKey : "temperature")
	readonly property bool previewShowTemperatureControl: hasRoomTemperatureControl
		&& (previewModeKey === "temperature" || previewModeKey === "heat-ventilation")
	readonly property bool previewShowPowerControl: previewModeKey === "power" || previewModeKey === "ventilation"
	// Ring display mirrors preview without sensor gate — Off should still show temp preview
	readonly property bool previewIsTemperatureForRing: previewModeKey === "temperature" || previewModeKey === "heat-ventilation"
	readonly property bool previewIsPowerForRing: previewModeKey === "power" || previewModeKey === "ventilation"
	readonly property bool showTemperatureControl: hasRoomTemperatureControl && mode.valid && (mode.value === 1 || mode.value === 3)
	readonly property bool showPowerControl: mode.valid && (mode.value === 0 || mode.value === 2)
	readonly property color panelStrokeColor: Theme.color_listItem_secondaryText
	readonly property color ringProgressColor: themeBlueProbe.backgroundColor
	// Home Assistant thermostat card palette: amber while heating, blue while
	// ventilating, gray when idle.
	readonly property color ringStateColor: isVentilationMode
		? Theme.color_blue
		: (!isRunning
			? Qt.rgba(0.62, 0.36, 0.05, 1)  // dark amber while stopped
			: Qt.rgba(1.0, 0.58, 0.08, 1))
	readonly property string actionLabel: isStarting
		? qsTr("Starting...")
		: (isStopping
			? qsTr("Stopping...")
			: (isRunning
				? (isVentilationMode ? qsTr("Stop ventilation") : qsTr("Stop heater"))
				: (isVentilationMode ? qsTr("Start ventilation") : qsTr("Start heater"))))
	readonly property string actionDescription: isRunning
		? (isVentilationMode
			? qsTr("The heater will stop ventilation mode.")
			: qsTr("The heater will begin its shutdown cycle."))
		: (isVentilationMode
			? qsTr("The heater will start in ventilation mode.")
			: qsTr("The heater will start heating with the current settings."))

	readonly property string activeModeCardKey: {
		if (!mode.valid) {
			return "off"
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
			return "off"
		}
	}

	readonly property var modeCards: [
		{
			key: "temperature",
			modeValue: 1,
			label: qsTr("Temperature"),
			icon: "qrc:/images/icon_temp_32.svg",
			description: qsTr("Maintain a target room temperature.")
		},
		{
			key: "power",
			modeValue: 0,
			label: qsTr("Power Mode"),
			icon: root.flameIcon,
			description: qsTr("Run the heater at a fixed power level.")
		},
		{
			key: "heat-ventilation",
			modeValue: 3,
			label: qsTr("Heat & Airflow"),
			icon: root.heaterIcon,
			description: qsTr("Blend heating with ventilation support.")
		},
		{
			key: "thermostat",
			modeValue: -1,
			label: qsTr("Thermostat"),
			icon: "qrc:/images/icon_temp_coolant_32.svg",
			description: qsTr("Thermostat control placeholder for the custom GUI.")
		},
		{
			key: "ventilation",
			modeValue: 2,
			label: qsTr("Ventilation Mode"),
			icon: "qrc:/images/icon_propeller.svg",
			description: qsTr("Circulate air without active heating.")
		}
	]

	readonly property string activeModeDescription: {
		// When nothing is selected (initial "" or Off chip) show placeholder
		// regardless of the heater's current mode — matches "Select a heater
		// mode..." spec for initial idle state.
		if ((root.selectedModeKey === "off" || root.selectedModeKey === "") && !root.isRunning) {
			return qsTr("Select a mode to start the heater.")
		}
		for (let i = 0; i < modeCards.length; ++i) {
			if (modeCards[i].key === activeModeCardKey) {
				return modeCards[i].description
			}
		}
		return qsTr("Select a mode to start the heater.")
	}

	readonly property string selectedModeLabel: {
		for (let i = 0; i < modeCards.length; ++i) {
			if (modeCards[i].key === (selectedModeKey !== "off" ? selectedModeKey : lastModeKey)) {
				return modeCards[i].label
			}
		}
		return qsTr("Idle")
	}

	// Short live status for the dial top: compact form of /StateText.
	readonly property string ringStatusLabel: {
		if (!stateText.valid) {
			return qsTr("Idle")
		}
		switch (stateText.value) {
		case "not connected":
			return qsTr("Not connected")
		case "fault":
			return qsTr("Fault")
		case "starting":
		case "starting ventilation":
			return qsTr("Starting")
		case "warming up":
			return qsTr("Warming up")
		case "shutting down":
		case "stopping ventilation":
			return qsTr("Cooling down")
		case "running":
			if (showTemperatureControl) {
				if (root.activeModeCardKey === "heat-ventilation") {
					return qsTr("Heat & Airflow to")
				}
				return qsTr("Heating to")
			}
			if (showPowerControl) {
				return qsTr("Heating level")
			}
			return qsTr("Running")
		case "ventilation":
			return qsTr("Only Ventilation")
		case "off":
			return root.selectedModeLabel
		default:
			return qsTr("Idle")
		}
	}

	// Live status line: replaces the static description while the heater
	// transitions or runs, showing real telemetry for the active mode.
	readonly property string statusDescription: {
		if (root.heaterDisconnected) {
			return qsTr("Heater not connected.")
		}
		if (!stateText.valid || stateText.value === "off") {
			return activeModeDescription
		}
		const room = root.formatTemperatureValue(roomTemperature)
		if (stateText.value === "not connected") {
			return qsTr("Heater not connected.")
		}
		if (stateText.value === "fault") {
			return errorText.valid && errorText.value !== "" ? errorText.value : qsTr("Heater fault.")
		}
		if (stateText.value === "starting" || stateText.value === "starting ventilation") {
			return qsTr("Starting heater...")
		}
		if (stateText.value === "warming up") {
			return qsTr("Warming up...")
		}
		if (stateText.value === "shutting down" || stateText.value === "stopping ventilation") {
			return qsTr("Cooling down before stopping...")
		}
		if (stateText.value === "running") {
			const target = targetTemperature.valid ? root.formatTemperatureValue(targetTemperature) : "--"
			if (showPowerControl) {
				const level = powerLevel.valid ? powerLevel.value : "--"
				return qsTr("Running at power level %1 · room is %2").arg(level).arg(room)
			}
			return qsTr("Heating to %1 · room is %2").arg(target).arg(room)
		}
		if (stateText.value === "ventilation") {
			return qsTr("Ventilating · room is %1").arg(room)
		}
		return activeModeDescription
	}

	function clamp(value, minValue, maxValue) {
		return Math.max(minValue, Math.min(maxValue, value))
	}

	function formatTemperatureNumber(item) {
		if (!item.valid || item.value === undefined || item.value === null || item.value === "") {
			return "--"
		}
		return String(Number(Units.convert(item.value, VenusOS.Units_Temperature_Celsius, Global.systemSettings.temperatureUnit)).toFixed(0))
	}

	function formatTemperatureValue(item) {
		if (!item.valid || item.value === undefined || item.value === null || item.value === "") {
			return "--"
		}
		return Number(Units.convert(item.value, VenusOS.Units_Temperature_Celsius, Global.systemSettings.temperatureUnit)).toFixed(0)
			+ Global.systemSettings.temperatureUnitSuffix
	}

	// Compact caption inside the dial: the current temperature shown as a number
	// with its unit superscripted separately.
	readonly property string ringCurrentTempValue: formatTemperatureNumber(displayTemperatureItem)
	readonly property string ringCurrentTempUnit: ringCurrentTempValue === "--" ? "" : Global.systemSettings.temperatureUnitSuffix

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
		// Running: reflect actual heater mode; Idle: reflect preview chip (Temperature default)
		if (isRunning) {
			if (showPowerControl && powerLevel.valid) {
				return clamp(powerLevel.value / 9.0, 0.0, 1.0)
			}
			if (showTemperatureControl && targetTemperature.valid) {
				return clamp(targetTemperature.value / 30.0, 0.0, 1.0)
			}
		} else {
			if (previewShowPowerControl && powerLevel.valid) {
				return clamp(powerLevel.value / 9.0, 0.0, 1.0)
			}
			if (previewShowTemperatureControl && targetTemperature.valid) {
				return clamp(targetTemperature.value / 30.0, 0.0, 1.0)
			}
		}
		return 0.0
	}

	readonly property bool canAdjustRingValue: isRunning
		? (showPowerControl ? powerLevel.valid : (showTemperatureControl && targetTemperature.valid))
		: (previewShowPowerControl ? powerLevel.valid : (previewShowTemperatureControl && targetTemperature.valid))

	// Current temperature shown as the dial caption: room temperature when a
	// room source exists, otherwise the heater internal sensor.
	readonly property var displayTemperatureItem: roomTemperature.valid
		? roomTemperature
		: (internalTemperature.valid ? internalTemperature : heaterTemperature)

	// Big center value: the value the ring steppers set — target temperature
	// in temperature modes, power level in power/ventilation modes.
	// Temperature uses the same superscript unit style as the caption (number +
	// raised °C/°F); power level has no unit.
	// Running → actual mode; Idle Off → preview mode (Temperature default).
	// Idle preview should show temp even without room sensor so Off doesn't
	// look like a power value.
	readonly property string ringPrimaryNumber: {
		if (isRunning) {
			if (showPowerControl) {
				return powerLevel.valid ? String(powerLevel.value) : "--"
			}
			if (targetTemperature.valid) {
				return formatTemperatureNumber(targetTemperature)
			}
			return "--"
		}
		if (previewIsPowerForRing) {
			return powerLevel.valid ? String(powerLevel.value) : "--"
		}
		if (targetTemperature.valid) {
			return formatTemperatureNumber(targetTemperature)
		}
		return "--"
	}

	readonly property string ringPrimaryUnit: {
		if (isRunning) {
			if (showPowerControl) {
				return ""
			}
			return ringPrimaryNumber !== "--" && targetTemperature.valid ? Global.systemSettings.temperatureUnitSuffix : ""
		}
		if (previewIsPowerForRing) {
			return ""
		}
		return ringPrimaryNumber !== "--" && targetTemperature.valid ? Global.systemSettings.temperatureUnitSuffix : ""
	}

	topLeftButton: VenusOS.StatusBar_LeftButton_ControlsInactive
	fullScreenWhenIdle: true
	focusPolicy: Qt.TabFocus
	navButtonText: qsTr("Heater")
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
			NumberAnimation {
				duration: Theme.animation_page_idleResize_duration
				easing.type: Easing.InOutQuad
			}
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
			top: parent.top
			topMargin: 4
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

				// When the bottom navigation bar hides (idle/full-screen), slide the mode
				// chips and the start button block down to reclaim some of the freed space.
				readonly property real bottomShift: (Global.pageManager && Global.pageManager.expandLayout) ? 40 : 0
				Behavior on bottomShift {
					enabled: root.animationEnabled && root.isCurrentPage
					NumberAnimation {
						duration: Theme.animation_page_idleResize_duration
						easing.type: Easing.InOutQuad
					}
				}

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

						width: Math.round(parent.width * 0.50)
						height: parent.height

						Item {
							id: dialArea

							anchors {
								top: parent.top
								left: parent.left
								right: parent.right
							}
							height: 280
							CircularHeaterRing {
								id: ring
								opacity: root.dialEnabled ? 1.0 : 0.5

								width: Math.min(dialArea.width * 0.9, dialArea.height, 280)
								height: width
								anchors {
									top: parent.top
									topMargin: 0
									horizontalCenter: parent.horizontalCenter
								}
								valueRatio: root.ringValueRatio
								progressColor: root.ringStateColor
								primaryValue: root.ringPrimaryNumber
								primaryUnit: root.ringPrimaryUnit
								secondaryValue: ""
								captionValue: root.ringCurrentTempValue
								captionUnit: root.ringCurrentTempUnit
								statusValue: root.ringStatusLabel
							}

							// Steppers hug the ring's bottom opening
							Row {
								opacity: root.dialEnabled ? 1.0 : 0.5
								anchors.top: ring.bottom
								anchors.topMargin: -61
								anchors.horizontalCenter: ring.horizontalCenter
								spacing: 12

								Item {
									width: 56
									height: 56

									Button {
										anchors.fill: parent
										text: "–"
										enabled: root.canAdjustRingValue && root.dialEnabled
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
										enabled: root.canAdjustRingValue && root.dialEnabled
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

						Item {
							id: modeBlock

							anchors {
								top: dialArea.bottom
								topMargin: 12 + bottomShift
								horizontalCenter: parent.horizontalCenter
							}
							width: modeBlockRow.width
							height: modeBlockRow.height

							Row {
								id: modeBlockRow
								spacing: 12
								anchors.horizontalCenter: parent.horizontalCenter

								Button {
									id: powerChipButton
									// Off is the default state: active when "off" is selected OR nothing is selected.
									// flat: false is required, otherwise backgroundColor is ignored.
									flat: false
									height: 50
									width: 50
									text: ""

									readonly property bool isDisabled: !root.hasHeater || root.heaterDisconnected
									readonly property bool offActive: !isDisabled
										&& (root.selectedModeKey === "off" || root.selectedModeKey === "")

									enabled: !isDisabled
									backgroundColor: offActive ? Theme.color_blue : Theme.color_gray1
									borderColor: offActive ? Theme.color_blue : Theme.color_gray1
									color: isDisabled ? Theme.color_font_secondary : Theme.color_white
									opacity: isDisabled ? 0.5 : 1.0

									onClicked: {
										if (root.isRunning) {
											if (root.selectedModeKey !== "off") {
												root.lastModeKey = root.selectedModeKey
											}
											root.selectedModeKey = ""
											root.dialEnabled = false
											Global.dialogLayer.open(startStopDialogComponent, {
												startRequested: false
											})
											return
										}
										if (root.selectedModeKey !== "off") {
											root.lastModeKey = root.selectedModeKey
										}
										root.selectedModeKey = "off"
										root.dialEnabled = false
									}

									CP.ColorImage {
										anchors.centerIn: parent
										width: 22
										height: 22
										source: root.powerIcon
										fillMode: Image.PreserveAspectFit
										color: powerChipButton.isDisabled ? Theme.color_font_secondary : Theme.color_white
									}
								}

								Repeater {
									model: root.modeCards

									Button {
										id: chipButton

										required property var modelData

										readonly property bool active: modelData.key === root.selectedModeKey
										readonly property bool roomSensorMode: modelData.modeValue === 1 || modelData.modeValue === 3
										readonly property bool isHeatingMode: modelData.modeValue === 0 || modelData.modeValue === 1 || modelData.modeValue === 3
										readonly property bool isVentilationFamily: modelData.modeValue === 2
										readonly property bool supported: modelData.modeValue >= 0
										readonly property bool noHeater: !root.hasHeater
										readonly property bool disconnected: root.heaterDisconnected
										readonly property bool familyLocked: (root.ventilationLocked && chipButton.isVentilationFamily)
											|| (root.heatingLocked && chipButton.isHeatingMode)
										readonly property bool isDisabled: chipButton.noHeater || chipButton.disconnected
											|| chipButton.familyLocked || !chipButton.supported
										readonly property bool selectable: chipButton.supported && !chipButton.familyLocked
											&& !chipButton.noHeater && !chipButton.disconnected

										height: 50
										width: 50
										text: ""
										flat: false
										enabled: chipButton.selectable
										backgroundColor: chipButton.isDisabled ? Theme.color_gray1
											: (active ? Theme.color_blue : Theme.color_gray1)
										borderColor: chipButton.isDisabled ? Theme.color_gray1
											: (active ? Theme.color_blue : Theme.color_gray1)
										color: chipButton.isDisabled ? Theme.color_font_secondary : Theme.color_white
										opacity: chipButton.isDisabled ? 0.5
											: (chipButton.familyLocked ? 0.35 : 1.0)

										onClicked: {
											root.selectedModeKey = modelData.key
											root.lastModeKey = modelData.key
											root.dialEnabled = true
											root.requestModeChange(modelData.modeValue, modelData.label)
										}

										CP.ColorImage {
											anchors.centerIn: parent
											width: 22
											height: 22
											source: chipButton.modelData.icon
											fillMode: Image.PreserveAspectFit
											color: chipButton.isDisabled ? Theme.color_font_secondary : Theme.color_white
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

						// Segmented tab navigation: Timer | Status (Telemetry)
						Item {
							id: rightTabBar

							anchors {
								top: parent.top
								left: parent.left
								right: parent.right
							}
							height: 40

							Rectangle {
								anchors.fill: parent
								radius: 8
								color: Qt.rgba(1, 1, 1, 0.05)
								border.width: 1.5
								border.color: Theme.color_blue
							}

							Row {
								anchors.fill: parent

								Button {
									height: rightTabBar.height
									width: rightTabBar.width / 2
									text: qsTr("Timer")
									flat: false
									backgroundColor: root.rightTabIndex === 0 ? Theme.color_blue : "transparent"
									borderColor: "transparent"
									color: root.rightTabIndex === 0 ? Theme.color_white : Theme.color_font_secondary
									font.pixelSize: Theme.font_size_body1
									onClicked: root.rightTabIndex = 0
								}

								Button {
									height: rightTabBar.height
									width: rightTabBar.width / 2
									text: qsTr("Status")
									flat: false
									backgroundColor: root.rightTabIndex === 1 ? Theme.color_blue : "transparent"
									borderColor: "transparent"
									color: root.rightTabIndex === 1 ? Theme.color_white : Theme.color_font_secondary
									font.pixelSize: Theme.font_size_body1
									onClicked: root.rightTabIndex = 1
								}
							}
						}

						// TAB 1 — Timer (placeholder until the timer backend is wired)
						Item {
							id: timerTabContent

							anchors {
								top: rightTabBar.bottom
								topMargin: 8
								left: parent.left
								right: parent.right
								bottom: statusInfoRow.top
								bottomMargin: 4
							}
							visible: root.rightTabIndex === 0

							ColumnLayout {
								anchors {
									top: parent.top
									topMargin: 4
									left: parent.left
									right: parent.right
								}
								spacing: 6

								// Big timer display: armed duration or live countdown, centered.
								// Reset button sits at the right of the number.
								Item {
									Layout.fillWidth: true
									Layout.preferredHeight: Math.max(timerValueLabel.implicitHeight, 44)

									Label {
										id: timerValueLabel
										anchors.centerIn: parent
										font.pixelSize: Theme.font_size_h1 * root.primaryValueFontScale
										font.bold: false
										color: Theme.color_white
										text: root.timerDisplayText
										opacity: (root.hasHeater && !root.heaterDisconnected && root.timerPanelEnabled) ? 1.0 : 0.5
									}

									Button {
										id: timerResetButton

										anchors {
											right: parent.right
											verticalCenter: parent.verticalCenter
										}
										width: 44
										height: 44
										text: ""
										flat: false
										visible: root.timerSelectedMinutes > 0 || root.timerRunning
										enabled: root.hasHeater && !root.heaterDisconnected && root.timerPanelEnabled
										opacity: enabled ? 1.0 : 0.5
										backgroundColor: Theme.color_gray1
										borderColor: Theme.color_gray1
										color: Theme.color_white
										onClicked: {
											if (root.isRunning) {
												Global.dialogLayer.open(timerResetDialogComponent)
											} else {
												root.resetTimer()
											}
										}

										CP.ColorImage {
											anchors.centerIn: parent
											width: 28
											height: 28
											source: root.timerRemoveIcon
											fillMode: Image.PreserveAspectFit
											color: Theme.color_white
										}
									}
								}

								// Row 1: add minutes to the armed timer. Row 2: predefined durations.
								GridLayout {
									Layout.fillWidth: true
									columns: 3
									columnSpacing: 8
									rowSpacing: 8

									Repeater {
										model: root.timerStepMinutes

										Button {
											required property var modelData

											Layout.fillWidth: true
											Layout.preferredHeight: 52
											text: "+" + modelData + "\n" + qsTr("min")
											flat: false
											enabled: root.hasHeater && !root.heaterDisconnected && root.timerPanelEnabled
											opacity: enabled ? 1.0 : 0.5
											backgroundColor: Theme.color_gray1
											borderColor: Theme.color_gray1
											color: Theme.color_white
											font.pixelSize: Theme.font_size_body1
											onClicked: root.addTimerMinutes(modelData)
										}
									}

									Repeater {
										model: root.timerPresetMinutes

										Button {
											required property var modelData

											readonly property bool selected: modelData === root.timerSelectedMinutes

											Layout.fillWidth: true
											Layout.preferredHeight: 52
											text: modelData + "\n" + qsTr("min")
											flat: false
											enabled: root.hasHeater && !root.heaterDisconnected && root.timerPanelEnabled
											opacity: enabled ? 1.0 : 0.5
											backgroundColor: selected ? Theme.color_blue : Theme.color_gray1
											borderColor: selected ? Theme.color_blue : Theme.color_gray1
											color: Theme.color_white
											font.pixelSize: Theme.font_size_body1
											font.bold: true
											onClicked: root.setTimerDuration(modelData)
										}
									}
								}
							}

						}

						// TAB 2 — Status (live telemetry, status line, start/stop)
						Item {
							id: statusTabContent

							anchors {
								top: rightTabBar.bottom
								topMargin: 8
								left: parent.left
								right: parent.right
								bottom: statusInfoRow.top
								bottomMargin: 4
							}
							visible: root.rightTabIndex === 1

							// Telemetry grid: 2-column status card, each item in its own cell.
							Item {
								id: statusIndicatorHeader

								anchors {
									top: parent.top
									left: parent.left
									right: parent.right
								}
								visible: root.hasHeater
								height: visible ? 184 : 0

								readonly property var cells: [
									{
										icon: root.fanClockIcon,
										label: qsTr("Timer"),
										value: root.timerDisplayText,
										valueColor: Theme.color_font_primary,
										iconColor: Theme.color_font_secondary
									},
									{
										icon: "qrc:/images/icon_propeller.svg",
										iconSize: 20,
										label: qsTr("Fan"),
										value: root.heaterDisconnected ? "--"
											: (fanRpmActual.valid ? fanRpmActual.value + " " + qsTr("RPM") : "--"),
										valueColor: root.heaterDisconnected
											? Qt.alpha(Theme.color_font_primary, 0.5)
											: Theme.color_font_primary,
										iconColor: root.heaterDisconnected
											? Qt.alpha(Theme.color_font_secondary, 0.5)
											: Theme.color_font_secondary
									},
									{
										icon: "qrc:/images/icon_temp_32.svg",
										label: qsTr("Room temp."),
										value: roomTemperature.valid
											? root.formatTemperatureValue(roomTemperature)
											: (internalTemperature.valid ? internalTemperature.value + "°C" : "--"),
										valueColor: Theme.color_font_primary,
										iconColor: Theme.color_font_secondary
									},
									{
										icon: "qrc:/images/icon_engine_temp_32.svg",
										label: qsTr("Heater temp."),
										value: root.heaterDisconnected ? "--"
											: (heaterTemperature.valid ? heaterTemperature.value + "°C" : "--"),
										valueColor: root.heaterDisconnected
											? Qt.alpha(Theme.color_font_primary, 0.5)
											: Theme.color_font_primary,
										iconColor: root.heaterDisconnected
											? Qt.alpha(Theme.color_font_secondary, 0.5)
											: Theme.color_font_secondary
									},
									{
										icon: root.pumpIcon,
										label: qsTr("Fuel pump freq."),
										value: root.heaterDisconnected ? "--"
											: (fuelPumpFrequency.valid ? fuelPumpFrequency.value.toFixed(1) + " " + qsTr("Hz") : "--"),
										valueColor: root.heaterDisconnected
											? Qt.alpha(Theme.color_font_primary, 0.5)
											: Theme.color_font_primary,
										iconColor: root.heaterDisconnected
											? Qt.alpha(Theme.color_font_secondary, 0.5)
											: Theme.color_font_secondary
									},
									{
										icon: "qrc:/images/icon_temp_32.svg",
										label: qsTr("Internal temp."),
										value: root.heaterDisconnected ? "--"
											: (internalTemperature.valid ? internalTemperature.value + "°C" : "--"),
										valueColor: root.heaterDisconnected
											? Qt.alpha(Theme.color_font_primary, 0.5)
											: Theme.color_font_primary,
										iconColor: root.heaterDisconnected
											? Qt.alpha(Theme.color_font_secondary, 0.5)
											: Theme.color_font_secondary
									}
								]

								GridLayout {
									anchors.fill: parent
									columns: 2
									rowSpacing: 8
									columnSpacing: 8

									Repeater {
										model: statusIndicatorHeader.cells

										Rectangle {
											required property var modelData

											Layout.fillWidth: true
											Layout.preferredHeight: 56
											radius: 8
											color: Qt.rgba(1, 1, 1, 0.05)

											RowLayout {
												anchors {
													fill: parent
													leftMargin: 12
													rightMargin: 12
												}
												spacing: 8

												CP.ColorImage {
													Layout.alignment: Qt.AlignVCenter
													Layout.preferredWidth: modelData.iconSize !== undefined ? modelData.iconSize : 22
													Layout.preferredHeight: modelData.iconSize !== undefined ? modelData.iconSize : 22
													source: modelData.icon
													color: modelData.iconColor
												}

												ColumnLayout {
													Layout.alignment: Qt.AlignVCenter
													spacing: 0

													Label {
														Layout.fillWidth: true
														font.pixelSize: Theme.font_size_caption
														color: Theme.color_font_secondary
														text: modelData.label
													}

													Label {
														Layout.fillWidth: true
														font.pixelSize: Theme.font_size_body1
														font.bold: modelData.valueBold !== undefined ? modelData.valueBold : true
														elide: Label.ElideRight
														color: modelData.valueColor
														text: modelData.value
													}
												}
											}
										}
									}
								}
							}

						}

						// Live status line: always visible, directly above the start/stop button,
						// on both tabs (Timer and Status).
						Row {
							id: statusInfoRow

							anchors {
								left: parent.left
								right: parent.right
								bottom: actionButton.top
								bottomMargin: 4
							}
							spacing: 8

							CP.ColorImage {
								anchors.verticalCenter: parent.verticalCenter
								width: 18
								height: 18
								source: root.heaterDisconnected ? root.alertIcon : root.infoIcon
								fillMode: Image.PreserveAspectFit
								color: root.heaterDisconnected ? Theme.color_red : Theme.color_font_secondary
							}

							Label {
								width: parent.width - 26
								text: root.statusDescription
								wrapMode: Text.WordWrap
								maximumLineCount: 2
								elide: Text.ElideRight
								verticalAlignment: Text.AlignBottom
								color: root.heaterDisconnected ? Theme.color_red : Theme.color_font_secondary
								font.pixelSize: Theme.font_size_body1
							}
						}

						// Start/stop stays visible at the bottom of the right column,
						// independent of the active tab.
						Button {
							id: actionButton

						// Bottom-aligned with the left column mode chips (chips sit at 342px from
						// the column top: dialArea 280 + topMargin 12 + chip height 50). Both
						// columns share the same top/height, so this tracks the chips regardless
						// of page height; when the bottom navbar hides, both slide down by
						// bottomShift to reclaim some of the freed space.
							anchors {
								left: parent.left
								right: parent.right
								bottom: parent.bottom
								bottomMargin: parent.height - 342 - bottomShift
							}
							height: 52
							opacity: enabled ? 1.0 : 0.5
							text: root.actionLabel
							enabled: startStop.valid && !root.isTransitioning
								&& (root.selectedModeKey !== "" || root.isRunning)
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
								startRequested: !root.isRunning
							})
						}

					}
				}
			}
		}
	}

	VeQuickItem {
		id: stateText
		uid: root.bindPrefix + "/StateText"
	}
	VeQuickItem {
		id: errorText
		uid: root.bindPrefix + "/ErrorText"
	}
	VeQuickItem {
		id: errorCode
		uid: root.bindPrefix + "/ErrorCode"
	}
	VeQuickItem {
		id: mode
		uid: root.bindPrefix + "/Mode"
	}
	VeQuickItem {
		id: heaterState
		uid: root.bindPrefix + "/State"
	}
	VeQuickItem {
		id: startStop
		uid: root.bindPrefix + "/StartStop"
	}
	VeQuickItem {
		id: roomTemperatureControl
		uid: root.bindPrefix + "/Capabilities/RoomTemperatureControl"
	}
	VeQuickItem {
		id: roomTemperature
		uid: root.bindPrefix + "/Temperatures/Room"
	}
	VeQuickItem {
		id: targetTemperature
		uid: root.bindPrefix + "/Settings/TargetTemperature"
	}
	VeQuickItem {
		id: powerLevel
		uid: root.bindPrefix + "/Settings/PowerLevel"
	}

	// Live telemetry data
	VeQuickItem {
		id: batteryVoltage
		uid: root.bindPrefix + "/Dc/0/Voltage"
	}
	VeQuickItem {
		id: fanRpmSet
		uid: root.bindPrefix + "/Status/FanRpmSet"
	}
	VeQuickItem {
		id: fanRpmActual
		uid: root.bindPrefix + "/Status/FanRpmActual"
	}
	VeQuickItem {
		id: heaterTemperature
		uid: root.bindPrefix + "/Temperatures/Heater"
	}
	VeQuickItem {
		id: internalTemperature
		uid: root.bindPrefix + "/Temperatures/Internal"
	}
	VeQuickItem {
		id: fuelPumpFrequency
		uid: root.bindPrefix + "/Status/FuelPumpFrequency"
	}
	VeQuickItem {
		id: communicationAlarm
		uid: root.bindPrefix + "/Alarms/Communication"
	}

	// UI-side countdown ticker. TODO: replace with backend timer state once wired.
	Timer {
		id: timerTicker
		interval: 1000
		running: root.timerRunning && root.timerRemainingSeconds > 0
		repeat: true
		onTriggered: {
			root.timerRemainingSeconds -= 1
			if (root.timerRemainingSeconds === 0) {
				root.timerRunning = false
				root.timerSelectedMinutes = 0
				// Timer done: stop the heater immediately.
				root.pendingStartStopAction = "stop"
				startStop.setValue(0)
			}
		}
	}

	Connections {
		target: heaterState

		function onValueChanged() {
			if (root.pendingStartStopAction === "start"
				&& (heaterState.value === 3 || heaterState.value === 0 || heaterState.value === 10)) {
				root.pendingStartStopAction = ""
			} else if (root.pendingStartStopAction === "stop"
				&& (heaterState.value === 0 || heaterState.value === 10)) {
				root.pendingStartStopAction = ""
			}
			// Heater stopped for any reason (manual stop, fault, shutdown):
			// cancel the countdown. The armed value stays for the next start.
			if (heaterState.value === 0 || heaterState.value === 10) {
				root.stopTimer()
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
					// Timer tab: armed countdown starts/stops with the heater.
					if (startRequested) {
						root.startTimer()
					} else {
						root.stopTimer()
					}
				}
			}
		}
	}

	Component {
		id: modeChangeDialogComponent

		ModalWarningDialog {
			required property int requestedModeValue
			required property string requestedModeLabel

			title: qsTr("Change mode?")
			description: qsTr("The heater is running. Switch to %1 now?").arg(requestedModeLabel)
			dialogDoneOptions: VenusOS.ModalDialog_DoneOptions_OkAndCancel
			acceptText: qsTr("Change mode")
			onClosed: {
				if (result === T.Dialog.Accepted) {
					root.selectMode(requestedModeValue)
				}
			}
		}
	}

	Component {
		id: timerResetDialogComponent

		ModalWarningDialog {
			title: qsTr("Reset timer?")
			description: qsTr("The heater is running. The timer will be cancelled and the heater will keep running.")
			dialogDoneOptions: VenusOS.ModalDialog_DoneOptions_OkAndCancel
			acceptText: qsTr("Reset timer")
			onClosed: {
				if (result === T.Dialog.Accepted) {
					root.resetTimer()
				}
			}
		}
	}

	function setTimerDuration(minutes) {
		if (timerSelectedMinutes === minutes) {
			timerSelectedMinutes = 0
			return
		}
		timerSelectedMinutes = minutes
		if (timerRunning) {
			timerRemainingSeconds = minutes * 60
		} else if (isRunning) {
			// Heater already running: start the countdown immediately.
			startTimer()
		}
	}

	function addTimerMinutes(minutes) {
		timerSelectedMinutes = Math.max(0, Math.min(timerSelectedMinutes + minutes, 720))
		if (timerRunning) {
			timerRemainingSeconds = Math.max(0, Math.min(timerRemainingSeconds + minutes * 60, 720 * 60))
		} else if (isRunning && timerSelectedMinutes > 0) {
			// Heater already running: start the countdown immediately.
			startTimer()
		}
	}

	function resetTimer() {
		timerSelectedMinutes = 0
		timerRunning = false
		timerRemainingSeconds = 0
	}

	function startTimer() {
		if (timerSelectedMinutes <= 0) {
			return
		}
		timerRemainingSeconds = timerSelectedMinutes * 60
		timerRunning = true
	}

	function stopTimer() {
		timerRunning = false
		timerRemainingSeconds = 0
	}

	function adjustRingValue(delta) {
		if (showPowerControl && powerLevel.valid) {
			powerLevel.setValue(clamp(powerLevel.value + delta, 1, 9))
			return
		}
		if (showTemperatureControl && targetTemperature.valid) {
			targetTemperature.setValue(clamp(targetTemperature.value + delta, 0, 30))
		}
	}

	function selectMode(modeValue) {
		if (modeValue < 0) {
			return
		}
		if ((modeValue === 1 || modeValue === 3) && !hasRoomTemperatureControl) {
			return
		}
		// Manual p11-12: block cross-family via D-Bus while running.
		if (isRunning) {
			const wantVentilation = modeValue === 2
			const runningHeating = !isVentilationMode
			const runningVentilation = isVentilationMode
			if ((wantVentilation && runningHeating) || (!wantVentilation && runningVentilation)) {
				return
			}
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
		// Manual p11-12: reject cross-family switch while running (defense-in-depth).
		const wantVentilation = modeValue === 2
		const runningHeating = isRunning && !isVentilationMode
		const runningVentilation = isRunning && isVentilationMode
		if ((wantVentilation && runningHeating) || (!wantVentilation && runningVentilation)) {
			return
		}
		if (isRunning) {
			Global.dialogLayer.open(modeChangeDialogComponent, {
				requestedModeValue: modeValue,
				requestedModeLabel: modeLabel
			})
			return
		}
		selectMode(modeValue)
	}
}
