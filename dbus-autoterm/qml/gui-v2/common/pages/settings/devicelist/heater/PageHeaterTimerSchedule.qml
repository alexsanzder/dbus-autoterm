import QtQuick
import Victron.VenusOS

Page {
	id: root

	required property string bindPrefix
	title: qsTr("Schedule")

	function dayText(mask) {
		if (mask === 127) {
			return qsTr("Each day")
		}
		if (mask === 31) {
			return qsTr("Weekdays")
		}
		if (mask === 96) {
			return qsTr("Weekend")
		}
		return qsTr("Custom")
	}

	function timeText(startHourItem, startMinuteItem) {
		const startMinutes = (startHourItem.valid ? startHourItem.value : 0) * 60
			+ (startMinuteItem.valid ? startMinuteItem.value : 0)
		const fmt = function(m) {
			return String(Math.floor(m / 60)).padStart(2, "0") + ":" + String(m % 60).padStart(2, "0")
		}
		return fmt(startMinutes)
	}

	GradientListView {
		model: VisibleItemModel {
			ListNavigation {
				text: qsTr("Timer 1")

				secondaryText: !nav0scheduleEnabled.valid || nav0scheduleEnabled.value !== 1
					? qsTr("Disabled")
					: root.dayText(nav0scheduleDays.valid ? nav0scheduleDays.value : 0)
						+ " " + root.timeText(nav0scheduleStartHour, nav0scheduleStartMinute)

				onClicked: Global.pageManager.pushPage("/pages/settings/devicelist/heater/PageHeaterScheduleTimer.qml", {
					bindPrefix: root.bindPrefix,
					timerIndex: 0,
				})

				VeQuickItem {
					id: nav0scheduleEnabled
					uid: root.bindPrefix + "/Timers/0/Enabled"
				}

				VeQuickItem {
					id: nav0scheduleDays
					uid: root.bindPrefix + "/Timers/0/Days"
				}

				VeQuickItem {
					id: nav0scheduleStartHour
					uid: root.bindPrefix + "/Timers/0/StartHour"
				}

				VeQuickItem {
					id: nav0scheduleStartMinute
					uid: root.bindPrefix + "/Timers/0/StartMinute"
				}
			}

			ListNavigation {
				text: qsTr("Timer 2")

				secondaryText: !nav1scheduleEnabled.valid || nav1scheduleEnabled.value !== 1
					? qsTr("Disabled")
					: root.dayText(nav1scheduleDays.valid ? nav1scheduleDays.value : 0)
						+ " " + root.timeText(nav1scheduleStartHour, nav1scheduleStartMinute)

				onClicked: Global.pageManager.pushPage("/pages/settings/devicelist/heater/PageHeaterScheduleTimer.qml", {
					bindPrefix: root.bindPrefix,
					timerIndex: 1,
				})

				VeQuickItem {
					id: nav1scheduleEnabled
					uid: root.bindPrefix + "/Timers/1/Enabled"
				}

				VeQuickItem {
					id: nav1scheduleDays
					uid: root.bindPrefix + "/Timers/1/Days"
				}

				VeQuickItem {
					id: nav1scheduleStartHour
					uid: root.bindPrefix + "/Timers/1/StartHour"
				}

				VeQuickItem {
					id: nav1scheduleStartMinute
					uid: root.bindPrefix + "/Timers/1/StartMinute"
				}
			}

			ListNavigation {
				text: qsTr("Timer 3")

				secondaryText: !nav2scheduleEnabled.valid || nav2scheduleEnabled.value !== 1
					? qsTr("Disabled")
					: root.dayText(nav2scheduleDays.valid ? nav2scheduleDays.value : 0)
						+ " " + root.timeText(nav2scheduleStartHour, nav2scheduleStartMinute)

				onClicked: Global.pageManager.pushPage("/pages/settings/devicelist/heater/PageHeaterScheduleTimer.qml", {
					bindPrefix: root.bindPrefix,
					timerIndex: 2,
				})

				VeQuickItem {
					id: nav2scheduleEnabled
					uid: root.bindPrefix + "/Timers/2/Enabled"
				}

				VeQuickItem {
					id: nav2scheduleDays
					uid: root.bindPrefix + "/Timers/2/Days"
				}

				VeQuickItem {
					id: nav2scheduleStartHour
					uid: root.bindPrefix + "/Timers/2/StartHour"
				}

				VeQuickItem {
					id: nav2scheduleStartMinute
					uid: root.bindPrefix + "/Timers/2/StartMinute"
				}
			}
		}
	}
}
