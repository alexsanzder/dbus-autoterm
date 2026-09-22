import QtQuick
import Victron.VenusOS

Page {
	id: root

	required property string bindPrefix
	required property int timerIndex

	title: qsTr("Timer %1").arg(timerIndex + 1)

	readonly property string timerPrefix: bindPrefix + "/Timers/" + timerIndex
	readonly property int daysMask: scheduleDaysItem.valid ? scheduleDaysItem.value : 0
	readonly property bool customDays: daysMask !== 127 && daysMask !== 31 && daysMask !== 96

	function dayText(mask) {
		if (mask === 127) {
			return qsTr("Each day")
		}
		if (mask === 31) {
			return qsTr("Weekdays")
		}
		if (mask === 96) {
			return qsTr("Weekends")
		}
		return qsTr("Custom")
	}

	GradientListView {
		model: VisibleItemModel {
			ListSwitch {
				text: qsTr("Enabled")
				dataItem.uid: root.timerPrefix + "/Enabled"
			}

			ListRadioButtonGroup {
				text: qsTr("Mode")
				dataItem.uid: root.timerPrefix + "/Mode"
				optionModel: [
					{ display: qsTr("Heat"), value: 0 },
					{ display: qsTr("Heat + ventilation"), value: 3 },
					{ display: qsTr("Ventilation"), value: 2 },
				]
			}

			ListTimeSelector {
				text: qsTr("Start time")
				dataItem.uid: root.timerPrefix + "/StartTime"
			}

			ListSpinBox {
				text: qsTr("Time")
				dataItem.uid: root.timerPrefix + "/DurationMinutes"
				from: 5
				to: 1440
				stepSize: 5
				suffix: "min"
			}

			ListNavigation {
				text: qsTr("Select days")
				secondaryText: root.customDays ? qsTr("Custom") : root.dayText(root.daysMask)
				onClicked: Global.pageManager.pushPage("/pages/settings/devicelist/heater/PageHeaterSelectDays.qml", {
					bindPrefix: root.bindPrefix,
					timerIndex: root.timerIndex,
				})
			}
		}
	}

	VeQuickItem {
		id: scheduleDaysItem
		uid: root.timerPrefix + "/Days"
	}
}
