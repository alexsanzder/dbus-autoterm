import QtQuick
import Victron.VenusOS

Page {
	id: root

	required property string bindPrefix
	title: "Timer settings"

	GradientListView {
		model: VisibleItemModel {
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

			ListSpinBox {
				text: "Preset 1"
				dataItem.uid: root.bindPrefix + "/Settings/Timer/Preset/3"
				from: 30
				to: 720
				stepSize: 5
				suffix: "min"
			}

			ListSpinBox {
				text: "Preset 2"
				dataItem.uid: root.bindPrefix + "/Settings/Timer/Preset/4"
				from: 30
				to: 720
				stepSize: 5
				suffix: "min"
			}

			ListSpinBox {
				text: "Preset 3"
				dataItem.uid: root.bindPrefix + "/Settings/Timer/Preset/5"
				from: 30
				to: 720
				stepSize: 5
				suffix: "min"
			}
		}
	}
}
