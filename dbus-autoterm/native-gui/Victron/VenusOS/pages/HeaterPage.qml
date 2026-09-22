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
	// Tab to switch to once the heater has stopped (-1 = none). Set when the
	// user accepts stopping the heater from the ventilation-locked dialog.
	property int pendingTabSwitch: -1
	property bool dialEnabled: false
	property string selectedModeKey: ""
	property int heaterTabIndex: 0 // 0 = Heater modes, 1 = Ventilation modes
	property bool telemetryPanelOpen: false

	// Contract for the StatusBar telemetry button (components/StatusBar.qml):
	// the button is visible only on pages exposing these, and forwards clicks here.
	property bool telemetryToggleAvailable: true
	signal telemetryToggleClicked()
	onTelemetryToggleClicked: root.telemetryPanelOpen = !root.telemetryPanelOpen
	property string lastModeKey: ""
	// Last selected Heater-tab mode, so leaving the Ventilation tab can restore it.
	property string lastHeatingModeKey: ""
	property real primaryValueFontScale: 1.5

	// Timer state is owned by the driver countdown (/Timer/... paths), shared
	// with the device settings page (PageHeater.qml). Duration range per
	// Comfort Control manual: 30-720 min in 5-min steps.
	readonly property int timerSelectedMinutes: backendTimerDuration.valid ? backendTimerDuration.value : 0
	readonly property int timerRemainingSeconds: backendTimerRemaining.valid ? backendTimerRemaining.value : 0
	readonly property bool timerRunning: root.isRunning && root.timerRemainingSeconds > 0
	readonly property var timerStepMinutes: backendTimerPreset0.valid
		? [backendTimerPreset0.value, backendTimerPreset1.value, backendTimerPreset2.value]
		: [5, 15, 30]
	readonly property var timerPresetMinutes: backendTimerPreset3.valid
		? [backendTimerPreset3.value, backendTimerPreset4.value, backendTimerPreset5.value]
		: [30, 60, 90]
	readonly property string timerDisplayText: {
		const total = timerRemainingSeconds
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
	// Manual p11-12 warns against heating↔ventilation cross-switch while
	// running; we allow it behind a confirmation dialog instead of locking.
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
			label: qsTr("Power"),
			icon: root.flameIcon,
			description: qsTr("Run the heater at a fixed power level.")
		},
		{
			key: "heat-ventilation",
			modeValue: 3,
			label: qsTr("Heat and Ventilation"),
			icon: root.heaterIcon,
			description: qsTr("Blend heating with ventilation support.")
		},
		{
			key: "ventilation",
			modeValue: 2,
			label: qsTr("Ventilation"),
			icon: "qrc:/images/icon_propeller.svg",
			description: qsTr("Circulate air without active heating.")
		}
	]

	readonly property var heaterTabModes: [
		{ key: "timer", modeValue: -2, label: qsTr("Timer"), icon: root.fanClockIcon },
		{ key: "power", modeValue: 0, label: qsTr("Power"), icon: root.flameIcon },
		{ key: "temperature", modeValue: 1, label: qsTr("Temperature"), icon: "qrc:/images/icon_temp_32.svg" },
		{ key: "thermostat", modeValue: -3, label: qsTr("Thermostat"), icon: "qrc:/images/icon_temp_32.svg" },
		{ key: "heat-ventilation", modeValue: 3, label: qsTr("Heat and Ventilation"), icon: root.heaterIcon },
	]
	readonly property var ventilationTabModes: [
		{ key: "timer", modeValue: -2, label: qsTr("Timer"), icon: root.fanClockIcon },
		{ key: "ventilation", modeValue: 2, label: qsTr("Ventilation"), icon: "qrc:/images/icon_propeller.svg" },
	]
	readonly property var activeTabModes: heaterTabIndex === 0 ? heaterTabModes : ventilationTabModes

	readonly property string activeModeDescription: {
		// When nothing is selected (initial "" or Off chip) show placeholder
		// regardless of the heater's current mode — matches "Select a heater
		// mode..." spec for initial idle state.
		if (root.selectedModeKey === "timer") {
			return qsTr("Run the heater from the configured schedule timers.")
		}
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
		if (selectedModeKey === "timer") {
			return qsTr("Timer")
		}
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
					return qsTr("Heat and Ventilation to")
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


				width: heaterTab.width
				height: heaterTab.height

				// Fixed two-column layout for 7" displays:
				// LEFT  — dial + Heater/Ventilation group tab.
				// RIGHT — mode chips for the selected group, then the panel for
				//         the selected mode (Timer or Status telemetry), the live
				//         status line and the start/stop button at the bottom.
				Row {
					id: cardRow

					anchors {
						top: parent.top
						left: parent.left
						right: parent.right
					}
					// Fixed height: reserve the bottom NavBar permanently. The
					// page height changes when the bar slides in/out on touch,
					// so bottom-pinned items (Start button, mode tabs) must not
					// follow it.
					height: Theme.geometry_screen_height - Theme.geometry_statusBar_height - Theme.geometry_navigationBar_height
					spacing: 32

					// ---------- LEFT column: dial + mode group tabs ----------
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
								bottom: modeGroupTabBar.top
								bottomMargin: 6
							}

							CircularHeaterRing {
								id: ring

								opacity: root.dialEnabled ? 1.0 : 0.5

								width: Math.min(dialArea.width * 0.9, dialArea.height, 280) * 0.95
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

						// Mode group tabs: Heater | Ventilation — under the dial in the left column.
						Item {
							id: modeGroupTabBar

							anchors {
								bottom: parent.bottom
								bottomMargin: 8
								left: parent.left
								right: parent.right
							}
							height: 52

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
									height: modeGroupTabBar.height
									width: modeGroupTabBar.width / 2
									text: qsTr("Heater")
									flat: false
									backgroundColor: root.heaterTabIndex === 0 ? Theme.color_blue : "transparent"
									borderColor: "transparent"
									color: root.heaterTabIndex === 0 ? Theme.color_white : Theme.color_font_secondary
									font.pixelSize: Theme.font_size_body1
									onClicked: root.requestTabChange(0)
								}

								Button {
									height: modeGroupTabBar.height
									width: modeGroupTabBar.width / 2
									text: qsTr("Ventilation")
									flat: false
									backgroundColor: root.heaterTabIndex === 1 ? Theme.color_blue : "transparent"
									borderColor: "transparent"
									color: root.heaterTabIndex === 1 ? Theme.color_white : Theme.color_font_secondary
									font.pixelSize: Theme.font_size_body1
									onClicked: root.requestTabChange(1)
								}
							}
						}

						// Mode group tabs: Heater | Ventilation
						// Mode group selector: dropdown (opens a dialog) instead of tabs.
					}

					// ---------- RIGHT column: mode chips + selected mode panel ----------
					Item {

						id: rightColumn

						width: parent.width - leftColumn.width - cardRow.spacing
						height: parent.height


						// Mode selectors: dropdowns for the heater mode and the timer.
						Row {
							id: modeSelectors

							anchors {
								top: parent.top
								topMargin: 8
								left: parent.left
								right: parent.right
							}
							spacing: 8

							readonly property var currentModeEntry: {
								for (const m of root.activeTabModes) {
									if (m.key === root.selectedModeKey) {
										return m
									}
								}
								return null
							}

							// Heater mode dropdown (Timer excluded; the timer has its own selector).
							// On the Ventilation tab it shows the single auto-selected mode and
							// does not open the dialog.
							Button {
								id: modeSelect

								width: (modeSelectors.width - modeSelectors.spacing) / 2
								height: 52
								text: ""
								flat: false
								backgroundColor: Theme.color_gray1
								borderColor: Theme.color_listItem_secondaryText
								color: Theme.color_white
								font.pixelSize: Theme.font_size_body1
								onClicked: {
								if (root.heaterTabIndex === 1) {
									return // single auto-selected mode, no dialog
								}
								Global.dialogLayer.open(modeSelectDialogComponent)
							}

								Row {
									anchors {
										left: parent.left
										leftMargin: 10
										right: parent.right
										rightMargin: 10
										verticalCenter: parent.verticalCenter
									}
									spacing: 8

									// Column 1: icon.
									CP.ColorImage {
										anchors.verticalCenter: parent.verticalCenter
										width: 22
										height: 22
										source: Qt.resolvedUrl("../images/icon_flame.svg")
										fillMode: Image.PreserveAspectFit
										color: Theme.color_white
									}

									// Column 2: label row + selected option row.
									Column {
										anchors.verticalCenter: parent.verticalCenter
										width: parent.width - 22 - parent.spacing
										spacing: 1

										Label {
											text: qsTr("Mode")
											font.pixelSize: Theme.font_size_caption
											color: Theme.color_font_secondary
										}

										Label {
											width: parent.width
											text: (modeSelectors.currentModeEntry
												? modeSelectors.currentModeEntry.label
												: qsTr("Select mode"))
											font.pixelSize: Theme.font_size_caption
											color: Theme.color_white
											elide: Text.ElideRight
										}
									}
								}
							}

							Component {
								id: modeSelectDialogComponent

								ModalDialog {
									id: modeSelectDialog

									title: qsTr("Heater mode")
									dialogDoneOptions: VenusOS.ModalDialog_DoneOptions_OkAndCancel

									contentItem: ModalDialog.FocusableContentItem {
										Column {
											anchors.centerIn: parent
											spacing: 12

											Repeater {
												model: root.activeTabModes.filter(function(m) { return m.key !== "timer" })

												Button {
													required property var modelData
													readonly property bool isCurrent: modelData.key === root.selectedModeKey

													width: 260
													height: 44
													text: modelData.label
													flat: false
													backgroundColor: isCurrent ? Theme.color_blue : Theme.color_gray1
													borderColor: backgroundColor
													color: Theme.color_white
													font.pixelSize: Theme.font_size_body1
													onClicked: {
														// Close first: DialogLayer holds a single currentDialog,
														// and this dialog's closed handler would otherwise destroy
														// the confirmation dialog opened by requestModeChange.
														modeSelectDialog.close()
														root.requestModeChange(modelData.modeValue, modelData.label, modelData.key)
													}
												}
											}
										}
									}
								}
							}

							// Timer dropdown: picks the countdown duration and opens the Timer panel.
							Button {
								id: timerSelect

								width: (modeSelectors.width - modeSelectors.spacing) / 2
								height: 52
								text: ""
								flat: false
								enabled: root.timerPanelEnabled
								opacity: enabled ? 1.0 : 0.5
								backgroundColor: root.selectedModeKey === "timer" ? Theme.color_blue : Theme.color_gray1
								borderColor: root.selectedModeKey === "timer" ? Theme.color_blue : Theme.color_listItem_secondaryText
								color: Theme.color_white
								font.pixelSize: Theme.font_size_body1
								onClicked: Global.dialogLayer.open(timerSelectDialogComponent)

								Row {
									anchors {
										left: parent.left
										leftMargin: 10
										right: parent.right
										rightMargin: 10
										verticalCenter: parent.verticalCenter
									}
									spacing: 8

									// Column 1: icon.
									CP.ColorImage {
										anchors.verticalCenter: parent.verticalCenter
										width: 22
										height: 22
										source: Qt.resolvedUrl("../images/icon_fan_clock.svg")
										fillMode: Image.PreserveAspectFit
										color: Theme.color_white
									}

									// Column 2: label row + selected option row.
									Column {
										anchors.verticalCenter: parent.verticalCenter
										width: parent.width - 22 - parent.spacing
										spacing: 1

										Label {
											text: qsTr("Timer")
											font.pixelSize: Theme.font_size_caption
											color: Theme.color_font_secondary
										}

										Label {
											width: parent.width
											// Ticking countdown while the armed timer runs; armed duration
											// when set but not yet running; Off when no timer is set.
											text: root.timerRunning
												? root.timerDisplayText
												: (root.timerSelectedMinutes > 0
													? root.timerSelectedMinutes + " " + qsTr("min")
													: qsTr("Off"))
											font.pixelSize: Theme.font_size_caption
											color: Theme.color_white
											elide: Text.ElideRight
										}
									}
								}
							}

							Component {
								id: timerSelectDialogComponent

								ModalDialog {
									id: timerSelectDialog

									title: qsTr("Timer")
									dialogDoneOptions: VenusOS.ModalDialog_DoneOptions_OkAndCancel

									contentItem: ModalDialog.FocusableContentItem {
										Column {
											anchors.centerIn: parent
											spacing: 12

											Repeater {
												model: [0, 30, 60, 90]

												Button {
													required property var modelData
													readonly property bool isCurrent: modelData === root.timerSelectedMinutes

													width: 260
													height: 44
													text: modelData === 0 ? qsTr("Off") : modelData + " " + qsTr("min")
													flat: false
													enabled: modelData === 0 || root.timerPanelEnabled
													opacity: enabled ? 1.0 : 0.5
													backgroundColor: isCurrent ? Theme.color_blue : Theme.color_gray1
													borderColor: backgroundColor
													color: Theme.color_white
													font.pixelSize: Theme.font_size_body1
													onClicked: {
														// Only arm/disarm the countdown. The heater mode selection
														// (e.g. Power) must stay untouched.
														backendTimerDuration.setValue(modelData)
														timerSelectDialog.close()
														}
												}
											}
										}
									}
								}
							}
						}

						// Status telemetry inline under the mode selectors.
						Loader {
							sourceComponent: telemetryGridComponent

							anchors {
								top: modeSelectors.bottom
								topMargin: 6
								left: parent.left
								right: parent.right
							}
						}


						// Status panel: live telemetry, shown for every non-Timer mode.

						// Live status line: always visible, directly above the start/stop button,
						// regardless of the selected mode (Timer or Status).
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
								maximumLineCount: 1
								elide: Text.ElideRight
								verticalAlignment: Text.AlignBottom
								color: root.heaterDisconnected ? Theme.color_red : Theme.color_font_secondary
								font.pixelSize: Theme.font_size_caption
							}
						}

						// Start/stop stays pinned to the bottom of the right column,
						// independent of the selected mode.
						Button {
							id: actionButton

							anchors {
								left: parent.left
								right: parent.right
								bottom: parent.bottom
								// Pinned where it sits while the bottom navigation bar is
								// visible: no movement when the bar hides on idle.
								bottomMargin: 8
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


	// Telemetry overlay panel: opened from the info button in the top-right.
	// Contains the full status grid that used to live in the right column.
	Item {
		id: telemetryPanel

		anchors.fill: parent
		visible: root.telemetryPanelOpen

		// Tap the dimmed backdrop to close.
		Rectangle {
			anchors.fill: parent
			color: Qt.rgba(0, 0, 0, 0.6)

			MouseArea {
				anchors.fill: parent
				onClicked: root.telemetryPanelOpen = false
			}
		}

		Rectangle {
			anchors.centerIn: parent
			width: parent.width - 48
			height: telemetryContent.height + 72
			radius: 12
			color: Theme.color_darkBlue
			border.width: 1.5
			border.color: Theme.color_listItem_secondaryText

			Label {
				id: telemetryTitle
				text: qsTr("Heater status")
				anchors {
					top: parent.top
					topMargin: 16
					horizontalCenter: parent.horizontalCenter
				}
				color: Theme.color_white
				font.pixelSize: Theme.font_size_h3
				font.bold: true
			}

			// Grid contents (extracted from the old right-column status view).
			Loader {
				id: telemetryContent

				anchors {
					top: telemetryTitle.bottom
					topMargin: 12
					left: parent.left
					leftMargin: 16
					right: parent.right
					rightMargin: 16
				}
				height: 120
				sourceComponent: telemetryGridComponent
			}

			// Telemetry grid: shared component (inline under the dropdowns + overlay panel).
			Component {
				id: telemetryGridComponent
			Item {
				id: statusIndicatorHeader
		visible: root.hasHeater
		height: visible ? 120 : 0

		readonly property var cells: [
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
					color: "transparent"

					RowLayout {
						anchors {
							left: parent.left
							leftMargin: 4
							verticalCenter: parent.verticalCenter
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

			Button {
				text: qsTr("Close")
				anchors {
					top: telemetryContent.bottom
					topMargin: 16
					horizontalCenter: parent.horizontalCenter
				}
				height: 40
				width: 120
				backgroundColor: Theme.color_blue
				borderColor: Theme.color_blue
				color: Theme.color_white
				onClicked: root.telemetryPanelOpen = false
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

	// Backend countdown timer, shared with the device settings page.
	VeQuickItem {
		id: backendTimerDuration
		uid: root.bindPrefix + "/Timer/DurationMinutes"
	}

	VeQuickItem {
		id: backendTimerMode
		uid: root.bindPrefix + "/Timer/Mode"
	}

	VeQuickItem {
		id: backendTimerRemaining
		uid: root.bindPrefix + "/Timer/RemainingSeconds"
	}

	VeQuickItem {
		id: backendTimerPreset0
		uid: root.bindPrefix + "/Settings/Timer/Preset/0"
	}

	VeQuickItem {
		id: backendTimerPreset1
		uid: root.bindPrefix + "/Settings/Timer/Preset/1"
	}

	VeQuickItem {
		id: backendTimerPreset2
		uid: root.bindPrefix + "/Settings/Timer/Preset/2"
	}

	VeQuickItem {
		id: backendTimerPreset3
		uid: root.bindPrefix + "/Settings/Timer/Preset/3"
	}

	VeQuickItem {
		id: backendTimerPreset4
		uid: root.bindPrefix + "/Settings/Timer/Preset/4"
	}

	VeQuickItem {
		id: backendTimerPreset5
		uid: root.bindPrefix + "/Settings/Timer/Preset/5"
	}

	// Countdown ticking, expiry auto-stop and freeze-on-stop are owned by the
	// driver; the UI only reads /Timer/RemainingSeconds.

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
			// the driver freezes the countdown at the armed duration, which
			// stays set for the next start.
			if ((heaterState.value === 0 || heaterState.value === 10) && root.pendingTabSwitch >= 0) {
				const tab = root.pendingTabSwitch
				root.pendingTabSwitch = -1
				root.applyTabSelection(tab)
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
			required property string requestedModeKey

			title: qsTr("Change mode?")
			description: qsTr("The heater is running. Switch to %1 now?").arg(requestedModeLabel)
			dialogDoneOptions: VenusOS.ModalDialog_DoneOptions_OkAndCancel
			acceptText: qsTr("Change mode")
			onClosed: {
				if (result === T.Dialog.Accepted) {
					root.applyModeSelection(requestedModeValue, requestedModeKey)
				}
			}
		}
	}

	Component {
		id: ventilationLockedDialogComponent

		ModalWarningDialog {
			required property int targetTabIndex

			title: qsTr("Switch to Heater?")
			description: qsTr("The heater is running in ventilation mode and cannot switch to a heating mode while ventilating. Stop the heater first?")
			dialogDoneOptions: VenusOS.ModalDialog_DoneOptions_OkAndCancel
			acceptText: qsTr("Stop heater")
			onClosed: {
				if (result === T.Dialog.Accepted) {
					// Stop the heater; the tab switch is applied once it is off.
					root.pendingTabSwitch = targetTabIndex
					root.pendingStartStopAction = "stop"
					startStop.setValue(0)
				}
			}
		}
	}

	Component {
		id: tabSwitchDialogComponent

		ModalWarningDialog {
			required property int targetTabIndex

			readonly property string targetLabel: targetTabIndex === 1 ? qsTr("Ventilation") : qsTr("Heater")

			title: qsTr("Switch to %1?").arg(targetLabel)
			description: qsTr("The heater is running. Switch to %1 mode now?").arg(targetLabel)
			dialogDoneOptions: VenusOS.ModalDialog_DoneOptions_OkAndCancel
			acceptText: qsTr("Switch")
			onClosed: {
				if (result === T.Dialog.Accepted) {
					root.applyTabSelection(targetTabIndex)
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

	// Timer setter dialog: shows the armed duration as --:-- (h:mm:ss) with
	// +/- stepping; openable whether or not the timer or heater is running.
	Component {
		id: timerPresetsDialogComponent

		ModalDialog {
			id: timerDialog

			property int minutes: Math.max(0, root.timerSelectedMinutes)
			readonly property string timeText: {
				if (minutes <= 0) {
					return "--:--"
				}
				const total = minutes * 60
				const pad = function(n) { return String(n).padStart(2, "0") }
				const hours = Math.floor(total / 3600)
				return (hours > 0 ? pad(hours) + ":" : "") + pad(Math.floor((total % 3600) / 60)) + ":00"
			}

			title: qsTr("Set timer")
			dialogDoneOptions: VenusOS.ModalDialog_DoneOptions_SetAndCancel
			acceptText: qsTr("Set")

			contentItem: ModalDialog.FocusableContentItem {
				Row {
					anchors.centerIn: parent
					spacing: Theme.geometry_listItem_content_spacing * 2

					Button {
						anchors.verticalCenter: parent.verticalCenter
						width: 64
						height: 64
						text: "−"
						font.pixelSize: Theme.font_size_h2
						flat: false
						backgroundColor: Theme.color_blue
						borderColor: Theme.color_blue
						enabled: timerDialog.minutes > 0
						opacity: enabled ? 1.0 : 0.5
						onClicked: timerDialog.minutes = timerDialog.minutes <= 30 ? 0 : timerDialog.minutes - 5
					}

					Label {
						anchors.verticalCenter: parent.verticalCenter
						text: timerDialog.timeText
						font.pixelSize: Theme.font_size_h1 * root.primaryValueFontScale
						color: Theme.color_white
					}

					Button {
						anchors.verticalCenter: parent.verticalCenter
						width: 64
						height: 64
						text: "+"
						font.pixelSize: Theme.font_size_h2
						flat: false
						backgroundColor: Theme.color_blue
						borderColor: Theme.color_blue
						enabled: timerDialog.minutes < 720
						opacity: enabled ? 1.0 : 0.5
						onClicked: timerDialog.minutes = Math.min(720, timerDialog.minutes === 0 ? 30 : timerDialog.minutes + 5)
					}
				}
			}

			onAccepted: {
				// Direct write: unlike the preset buttons, Set must not
				// toggle the timer off when the value is unchanged.
				backendTimerDuration.setValue(timerDialog.minutes)
			}
		}
	}

	function setTimerDuration(minutes) {
		backendTimerDuration.setValue(timerSelectedMinutes === minutes ? 0 : minutes)
	}

	function addTimerMinutes(minutes) {
		backendTimerDuration.setValue(Math.max(0, Math.min(timerSelectedMinutes + minutes, 720)))
	}

	function resetTimer() {
		backendTimerDuration.setValue(0)
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
		// Manual: impossible to switch to any heating mode while the heater
		// is operating in ventilation mode.
		if (isRunning && isVentilationMode && modeValue !== 2) {
			return
		}
		mode.setValue(modeValue)
	}

	function requestTabChange(tabIndex) {
		if (tabIndex === heaterTabIndex) {
			return
		}
		// Confirm cross-family tab switches while the heater is running
		// (tab 1 = ventilation family, tab 0 = heating family).
		const runningTab = isVentilationMode ? 1 : 0
		if (isRunning && tabIndex !== runningTab) {
			// Manual: heating modes are unreachable while ventilating —
			// explain and offer to stop the heater first.
			if (isVentilationMode) {
				Global.dialogLayer.open(ventilationLockedDialogComponent, {
					targetTabIndex: tabIndex
				})
				return
			}
			Global.dialogLayer.open(tabSwitchDialogComponent, {
				targetTabIndex: tabIndex
			})
			return
		}
		applyTabSelection(tabIndex)
	}

	function applyTabSelection(tabIndex) {
		heaterTabIndex = tabIndex
		if (tabIndex === 1) {
			// Ventilation has a single mode — it is selected by default,
			// no dropdown needed.
			if (mode.valid && mode.value !== 2) {
				applyModeSelection(2, "ventilation")
			} else {
				selectedModeKey = "ventilation"
				lastModeKey = "ventilation"
				dialEnabled = true
			}
		} else if (selectedModeKey === "ventilation" && !(isRunning && isVentilationMode)) {
			// Returning to the Heater tab: restore the previous heating mode.
			const restoreKey = lastHeatingModeKey !== "" ? lastHeatingModeKey : "power"
			const entry = heaterTabModes.find(function(m) { return m.key === restoreKey })
			applyModeSelection(entry ? entry.modeValue : 0, restoreKey)
		}
	}

	function applyModeSelection(modeValue, modeKey) {
		selectedModeKey = modeKey
		lastModeKey = modeKey
		if (modeValue !== 2) {
			lastHeatingModeKey = modeKey
		}
		dialEnabled = true
		selectMode(modeValue)
	}

	function requestModeChange(modeValue, modeLabel, modeKey) {
		if (modeValue < 0 || !mode.valid) {
			return
		}
		if ((modeValue === 1 || modeValue === 3) && !hasRoomTemperatureControl) {
			return
		}
		// Already the active mode (e.g. Power after a fresh restart): no D-Bus
		// write needed, but the UI selection still has to be synced.
		if (mode.value === modeValue) {
			applyModeSelection(modeValue, modeKey)
			return
		}
		// Manual: heating modes cannot be switched to while ventilating —
		// don't even offer the confirmation.
		if (isRunning && isVentilationMode && modeValue !== 2) {
			return
		}
		if (isRunning) {
			Global.dialogLayer.open(modeChangeDialogComponent, {
				requestedModeValue: modeValue,
				requestedModeLabel: modeLabel,
				requestedModeKey: modeKey
			})
			return
		}
		applyModeSelection(modeValue, modeKey)
	}
}