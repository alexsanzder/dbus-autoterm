import QtQuick
import Victron.VenusOS

Page {
	id: root

	required property string bindPrefix
	required property int timerIndex

	title: qsTr("Select days")

	readonly property string timerPrefix: bindPrefix + "/Timers/" + timerIndex

	// Day mask convention: bit 0 = Monday .. bit 6 = Sunday.
	readonly property var dayLabels: ["M", "T", "W", "T", "F", "S", "S"]
	readonly property var presetDays: [
		{ label: qsTr("Each day"), value: 127 },
		{ label: qsTr("Weekdays"), value: 31 },
		{ label: qsTr("Weekends"), value: 96 },
	]
	readonly property int daysMask: scheduleDaysItem.valid ? scheduleDaysItem.value : 0
	readonly property bool customDays: daysMask !== 127 && daysMask !== 31 && daysMask !== 96

	function setDaysMask(mask) {
		scheduleDaysItem.setValue(mask)
	}

	function setTimerDay(dayIndex, selected) {
		const mask = scheduleDaysItem.valid ? scheduleDaysItem.value : 0
		scheduleDaysItem.setValue(selected ? (mask | (1 << dayIndex)) : (mask & ~(1 << dayIndex)))
	}

	GradientListView {
		model: VisibleItemModel {
			ListRadioButton {
				text: qsTr("Each day")
				checked: root.daysMask === 127
				onClicked: root.setDaysMask(127)
			}

			ListRadioButton {
				text: qsTr("Weekdays")
				checked: root.daysMask === 31
				onClicked: root.setDaysMask(31)
			}

			ListRadioButton {
				text: qsTr("Weekends")
				checked: root.daysMask === 96
				onClicked: root.setDaysMask(96)
			}

			ListRadioButton {
				text: qsTr("Custom")
				checked: root.customDays
				onClicked: root.setDaysMask(0)
			}

			ListItem {
				text: qsTr("Days")

				content.children: [
					Row {
						spacing: Theme.geometry_listItem_content_spacing / 2

						Repeater {
							model: root.dayLabels

							Button {
								required property string modelData
								required property int index

								readonly property bool selected: (root.daysMask & (1 << index)) !== 0

								width: 34
								height: 34
								text: modelData
								flat: false
								backgroundColor: selected ? Theme.color_blue : Theme.color_gray1
								borderColor: backgroundColor
								color: Theme.color_white
								font.pixelSize: Theme.font_size_caption
								onClicked: root.setTimerDay(index, !selected)
							}
						}
					}
				]
			}
		}
	}

	VeQuickItem {
		id: scheduleDaysItem
		uid: root.timerPrefix + "/Days"
	}
}
