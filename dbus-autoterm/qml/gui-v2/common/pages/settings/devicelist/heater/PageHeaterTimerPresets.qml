import QtQuick
import Victron.VenusOS

Page {
	id: root

	required property string bindPrefix
	title: qsTr("Presets")

	GradientListView {
		model: VisibleItemModel {
			SectionHeader {
				text: qsTr("Timer button steps")
			}

			TimerStepSpinBox {
				text: "+" + (dataItem.valid ? dataItem.value : "--") + "min"
				dataItem.uid: root.bindPrefix + "/Settings/Timer/Preset/0"
				from: 5
				to: 720
				stepSize: 5
			}

			TimerStepSpinBox {
				text: "+" + (dataItem.valid ? dataItem.value : "--") + "min"
				dataItem.uid: root.bindPrefix + "/Settings/Timer/Preset/1"
				from: 5
				to: 720
				stepSize: 5
			}

			TimerStepSpinBox {
				text: "+" + (dataItem.valid ? dataItem.value : "--") + "min"
				dataItem.uid: root.bindPrefix + "/Settings/Timer/Preset/2"
				from: 5
				to: 720
				stepSize: 5
			}

			SectionHeader {
				text: qsTr("Timer button presets")
			}

			ListSpinBox {
				text: qsTr("Preset 1")
				dataItem.uid: root.bindPrefix + "/Settings/Timer/Preset/3"
				from: 30
				to: 720
				stepSize: 5
				suffix: "min"
			}

			ListSpinBox {
				text: qsTr("Preset 2")
				dataItem.uid: root.bindPrefix + "/Settings/Timer/Preset/4"
				from: 30
				to: 720
				stepSize: 5
				suffix: "min"
			}

			ListSpinBox {
				text: qsTr("Preset 3")
				dataItem.uid: root.bindPrefix + "/Settings/Timer/Preset/5"
				from: 30
				to: 720
				stepSize: 5
				suffix: "min"
			}
		}
	}
}
